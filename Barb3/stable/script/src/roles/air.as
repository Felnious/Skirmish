// role: AIR
#include "../helpers/unit_helpers.as"
#include "../helpers/unitdef_helpers.as"
#include "../helpers/objective_helpers.as"
#include "../helpers/economy_helpers.as"
#include "../types/role_config.as"
#include "../global.as"
#include "../types/terrain.as"

namespace RoleAir {
    // Track pending T2 bombers created while the bomber gate is closed
    array<string> g_pendingT2Bombers; // store unitdef names as placeholders
    bool g_bomberGateOpen = false;
    // Track actual T2 bomber units so we can update attributes on already-created units when gate flips
    array<CCircuitUnit@> g_t2BomberUnits;
    // Support fighters that should remain near base (always treated as support group)
    array<CCircuitUnit@> g_supportFighterUnits;
    // Track last applied tier for bomber gate open threshold to avoid redundant writes
    int g_lastBomberOpenTier = -1; // -1 = unset, 0:<100, 1:100-250, 2:>250

    // Helper: return canonical T2 bomber unitdef names for all sides
    array<string> GetAllT2BomberNames()
    {
        array<string> names;
        names.insertLast("armpnix");     // Armada strategic bomber
        names.insertLast("corhurc");     // Cortex heavy strategic bomber
        names.insertLast("legphoenix");  // Legion heatray bomber
        return names;
    }

    // Helper: set mainRole for all T2 bomber defs
    void SetMainRoleForAllT2Bombers(const string &in mainRole)
    {
        array<string> names = GetAllT2BomberNames();
        UnitDefHelpers::SetMainRoleFor(names, mainRole);
        GenericHelpers::LogUtil("[Air][Bombers] Set mainRole=" + mainRole + " for T2 bombers", 3);
    }

    // Helper: resolve T2 fighter unit name per side
    string GetT2FighterNameForSide(const string &in side)
    {
        if (side == "armada") return "armhawk";
        if (side == "cortex") return "corvamp";
        if (side == "legion") return "legvenator"; // Legion T2 fighter
        return "armhawk";
    }

    // Helper: current count of tracked support fighters (prune nulls defensively)
    int GetSupportFighterCount()
    {
        int n = 0;
        for (uint i = 0; i < g_supportFighterUnits.length(); ++i) {
            CCircuitUnit@ u = g_supportFighterUnits[i];
            if (u !is null) ++n;
        }
        return n;
    }

    // Helper: compute total team count of T2 bombers across all factions
    int GetTotalT2BomberCount()
    {
        array<string> names = GetAllT2BomberNames();
        return UnitDefHelpers::SumUnitDefCounts(names);
    }

    // Apply defaults to T2 bomber defs: support role, fire state 3, siege attribute (if available)
    void ApplyT2BomberDefDefaults()
    {
        array<string> names = GetAllT2BomberNames();
        for (uint i = 0; i < names.length(); ++i) {
            CCircuitDef@ d = ai.GetCircuitDef(names[i]);
            if (d is null) continue;
            d.SetFireState(3);
            // TODO: Missing constant for siege attribute in repo. If available, uncomment the next line.
            // d.AddAttribute(Main::ATTR_SIEGE);
        }
        SetMainRoleForAllT2Bombers("support");
    }

    // Apply dynamic raid/attack quotas as game progresses
    bool g_appliedLateQuotas = false;
    // (Removed bomber wave cooldown/coordination; using simple top-up policy instead)
    void Air_UpdateDynamicQuotas()
    {
        // After 10 minutes, bump attack and raid thresholds to 100.0f (power-based)
        // Note: These settings do not appear to work for bombers
        const int LATE_GAME_FRAMES = 10 * 60 * SECOND;
        if (!g_appliedLateQuotas && ai.frame >= LATE_GAME_FRAMES) {
            aiMilitaryMgr.quota.attack = 100.0f;
            aiMilitaryMgr.quota.raid.min = 100.0f;
            aiMilitaryMgr.quota.raid.avg = 100.0f;
            g_appliedLateQuotas = true;
            GenericHelpers::LogUtil("[Air][Quota] Late-game thresholds applied: attack=100 raid.min=100 raid.avg=100", 3);
        }
    }

    /******************************************************************************

    INITIALIZATION

    ******************************************************************************/
    void Air_Init() {
        GenericHelpers::LogUtil("Air role initialization logic executed", 2);

        // Apply AIR role settings
        aiTerrainMgr.SetAllyZoneRange(Global::RoleSettings::Air::AllyRange);
        // Change scout cap (unit count)
        aiMilitaryMgr.quota.scout = Global::RoleSettings::Air::MilitaryScoutCap;

        // Change attack gate (power threshold, not a headcount)
        aiMilitaryMgr.quota.attack = Global::RoleSettings::Air::MilitaryAttackThreshold;

        // Change raid thresholds (power)
        aiMilitaryMgr.quota.raid.min = Global::RoleSettings::Air::MilitaryRaidMinPower; 
        aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::Air::MilitaryRaidAvgPower; 

        GenericHelpers::LogUtil("[Air][Quota] scout=" + aiMilitaryMgr.quota.scout +
            " attack=" + aiMilitaryMgr.quota.attack +
            " raid.min=" + aiMilitaryMgr.quota.raid.min +
            " raid.avg=" + aiMilitaryMgr.quota.raid.avg, 3);

        Air_ApplyStartLimits();

        // Initialize T2 bomber defaults (support role, aggressive fire state, siege attr if available)
        ApplyT2BomberDefDefaults();

        // Log all strategic objectives with distance from start
        ObjectiveHelpers::LogAllObjectivesFromStart(AiRole::AIR, "AIR");
    }

    void Air_ApplyStartLimits() {
        dictionary startLimits; 

        //Limit gantries to 0

        startLimits.set("armshltx", 0);
        startLimits.set("armshltxuw", 0);
        startLimits.set("corgant", 0);
        startLimits.set("corgantuw", 0);
        startLimits.set("leggant", 0);

        startLimits.set("armvp", 0);
        startLimits.set("corvp", 0);
        startLimits.set("legvp", 0);
        startLimits.set("armlab", 0);
        startLimits.set("corlab", 0);
        startLimits.set("leglab", 0);

        startLimits.set("armsilo", 0);
        startLimits.set("corsilo", 0);
        startLimits.set("legsilo", 0);

        UnitHelpers::ApplyUnitLimits(startLimits);

        GenericHelpers::LogUtil("Air start limits applied", 3);
    }

    /******************************************************************************

    MAIN HOOKS

    ******************************************************************************/

    void Air_MainUpdate() {
        // Periodically update dynamic military quotas based on game time
        Air_UpdateDynamicQuotas();
        // Bomber gate logic (poll-based): open/close based on total T2 bomber count
        int totalBombers = GetTotalT2BomberCount();
        int openThresh = Global::RoleSettings::Air::BomberGateOpenThreshold;
        int closeThresh = Global::RoleSettings::Air::BomberGateCloseThreshold;
        GenericHelpers::LogUtil("[Air][Bombers] GateCheck: total=" + totalBombers + " openT=" + openThresh + " closeT=" + closeThresh + " state=" + (g_bomberGateOpen ? "OPEN" : "CLOSED"), 5);
        if (!g_bomberGateOpen && totalBombers >= openThresh) {
            g_bomberGateOpen = true;
            SetMainRoleForAllT2Bombers("bomber");
            g_pendingT2Bombers.resize(0);
            // Upgrade attributes on any already-created T2 bombers we've tracked while gate was closed
            // Note: per-unit FireState API isn't exposed here; we apply SIEGE attribute as the behavioral cue
            // Compact the list defensively to avoid stale handles
            array<CCircuitUnit@> compact;
            for (uint i = 0; i < g_t2BomberUnits.length(); ++i) {
                CCircuitUnit@ bu = g_t2BomberUnits[i];
                if (bu is null) continue;
                compact.insertLast(bu);
            }
            for (uint i = 0; i < compact.length(); ++i) {
                CCircuitUnit@ bu = compact[i];
                if (bu !is null) {
                    bu.AddAttribute(Unit::Attr::SIEGE.type);
                }
            }
            g_t2BomberUnits.resize(0);
            GenericHelpers::LogUtil("[Air][Bombers] Gate OPEN: total=" + totalBombers + ", switching defs to bomber role and clearing pending", 3);
        } else if (g_bomberGateOpen && totalBombers < closeThresh) {
            g_bomberGateOpen = false;
            SetMainRoleForAllT2Bombers("support");
            GenericHelpers::LogUtil("[Air][Bombers] Gate CLOSED: total=" + totalBombers + ", reverting defs to support role", 3);
        }
        //LogUtil("Air update logic executed", 5);
    }

    /******************************************************************************

    ECONOMY HOOKS

    ******************************************************************************/

    void Air_EconomyUpdate() {
        // Tiered dynamic open-threshold for bomber gate based on 10s min metal income
        // Close threshold remains unchanged.
        float miMin10s = Economy::GetMinMetalIncomeLast10s();
        int tier = 0; // 0:<100, 1:100-250, 2:>250
        if (miMin10s < 100.0f) {
            tier = 0;
        } else if (miMin10s <= 150.0f) {
            tier = 1;
        } else {
            tier = 2;
        }
        if (tier != g_lastBomberOpenTier) {
            int newOpen = (tier == 0 ? 1 : (tier == 1 ? 40 : 100));
            Global::RoleSettings::Air::BomberGateOpenThreshold = newOpen;
            g_lastBomberOpenTier = tier;
            GenericHelpers::LogUtil("[Air][Economy] Bomber open threshold set to " + newOpen + " (miMin10s=" + miMin10s + ")", 4);
        }
    }

    /******************************************************************************

    FACTORY HOOKS

    ******************************************************************************/

    IUnitTask@ Air_FactoryAiMakeTask(CCircuitUnit@ u) {
        const CCircuitDef@ facDef = (u is null ? null : u.circuitDef);
        if (facDef is null) {
            return aiFactoryMgr.DefaultMakeTask(u);
        }

        // Only customize for aircraft plants; otherwise fallback
        const string fname = facDef.GetName();
        if (!UnitHelpers::IsT1AircraftPlant(fname) && !UnitHelpers::IsT2AircraftPlant(fname)) {
            return aiFactoryMgr.DefaultMakeTask(u);
        }

        const AIFloat3 pos = u.GetPos(ai.frame);
        const string side = UnitHelpers::GetSideForUnitName(fname);
        // Use the sliding-window minimum metal income across all checks in this factory make task
        const float metalIncome = Economy::GetMinMetalIncomeLast10s();

        // Determine plant tier first and only queue T1 builders from T1 plants.
        bool isT1Plant = UnitHelpers::IsT1AircraftPlant(fname);
        bool isT2Plant = (!isT1Plant && UnitHelpers::IsT2AircraftPlant(fname));

        if (isT1Plant) {
            // Priority: maintain a minimum number of air scouts before anything else
            int scoutTarget = Global::RoleSettings::Air::MinAirScoutCount;
            if (scoutTarget > 0) {
                array<string> allScouts = UnitHelpers::GetAllT1AirScouts();
                int haveScouts = UnitDefHelpers::SumUnitDefCounts(allScouts);
                if (haveScouts < scoutTarget) {
                    string scoutName = UnitHelpers::GetT1AirScoutForSide(side);
                    CCircuitDef@ scoutDef = ai.GetCircuitDef(scoutName);
                    if (scoutDef !is null && scoutDef.IsAvailable(ai.frame)) {
                        // Use HIGH priority to ensure scouts are produced ahead of other unit types
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::HIGH, scoutDef, pos, 64.f)
                        );
                    }
                }
            }

            // New: Income-scaled T1 air constructors (use min metal income over last 10s)
            // Target at least floor(mi/5) total T1 air constructors across the team.
            {
                if (metalIncome > 0.0f) {
                    // Guard against pathological divisor values (defensive, though constant here)
                    const float perCtorIncome = 5.0f;
                    float divisor = (perCtorIncome <= 0.0f ? 5.0f : perCtorIncome);
                    int desiredT1AirCons = int(floor(metalIncome / divisor));
                    if (desiredT1AirCons > 0) {
                        array<string> allT1AirCons2 = UnitHelpers::GetAllT1AirConstructors();
                        int haveT1AirCons = UnitDefHelpers::SumUnitDefCounts(allT1AirCons2);
                        int needT1AirCons = desiredT1AirCons - haveT1AirCons;
                        if (needT1AirCons > 0) {
                            string t1CtorName = (side == "armada" ? "armca" : side == "cortex" ? "corca" : side == "legion" ? "legca" : "armca");
                            CCircuitDef@ t1CtorDef = ai.GetCircuitDef(t1CtorName);
                            if (t1CtorDef !is null && t1CtorDef.IsAvailable(ai.frame)) {
                                IUnitTask@ firstTask = null;
                                for (int i = 0; i < needT1AirCons; ++i) {
                                    IUnitTask@ t = aiFactoryMgr.Enqueue(
                                        TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, t1CtorDef, pos, 64.f)
                                    );
                                    if (firstTask is null) @firstTask = t;
                                }
                                if (firstTask !is null) return firstTask;
                            }
                        }
                    }
                }
            }

            // Keep at least MinT1AirConstructorCount T1 construction aircraft across all sides
            array<string> allT1AirCons = UnitHelpers::GetAllT1AirConstructors();
            int t1BuildersTotal = UnitDefHelpers::SumUnitDefCounts(allT1AirCons);
            if (t1BuildersTotal < Global::RoleSettings::Air::MinT1AirConstructorCount) {
                string t1BuilderName = (side == "armada" ? "armca" : side == "cortex" ? "corca" : side == "legion" ? "legca" : "armca");
                CCircuitDef@ t1b = ai.GetCircuitDef(t1BuilderName);
                if (t1b !is null && t1b.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, t1b, pos, 64.f));
                }
            }

            // After constructors: ensure T1 fighters are produced until count >= 100
            {
                string fighterName = (side == "armada" ? "armfig" : side == "cortex" ? "corveng" : side == "legion" ? "legfig" : "armfig");
                int haveFighters = UnitDefHelpers::GetUnitDefCount(fighterName);
                if (haveFighters < 100) {
                    CCircuitDef@ fighterDef = ai.GetCircuitDef(fighterName);
                    if (fighterDef !is null && fighterDef.IsAvailable(ai.frame)) {
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::HIGH, fighterDef, pos, 64.f)
                        );
                    }
                }
            }
        }

        // If T2 plant: ensure advanced constructor targets, then apply T2-specific strategy
        if (isT2Plant) {
            // 1) Ensure at least MinT2AirConstructorCount advanced air constructors exist globally
            int minT2Cons = Global::RoleSettings::Air::MinT2AirConstructorCount;
            if (minT2Cons > 0) {
                array<string> t2AirCons; t2AirCons = { "armaca", "coraca", "legaca" };
                int haveT2Cons = UnitDefHelpers::SumUnitDefCounts(t2AirCons);
                if (haveT2Cons < minT2Cons) {
                    string advCtorName = (side == "armada" ? "armaca" : side == "cortex" ? "coraca" : side == "legion" ? "legaca" : "armaca");
                    CCircuitDef@ advCtor = ai.GetCircuitDef(advCtorName);
                    if (advCtor !is null && advCtor.IsAvailable(ai.frame)) {
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, advCtor, pos, 64.f)
                        );
                    }
                }
            }

            // 2) Maintain a base-defense wing of T2 fighters (after constructors, before heavy air and bombers)
            {
                int targetSupport = Global::RoleSettings::Air::TargetSupportFighterCount;
                int haveSupport = GetSupportFighterCount();
                if (targetSupport > 0 && haveSupport < targetSupport) {
                    string fighterName = GetT2FighterNameForSide(side);
                    CCircuitDef@ fighterDef = ai.GetCircuitDef(fighterName);
                    if (fighterDef !is null && fighterDef.IsAvailable(ai.frame)) {
                        int deficit = targetSupport - haveSupport;
                        int batch = Global::RoleSettings::Air::SupportFighterBatchPerFactory;
                        int toQueue = (deficit < batch ? deficit : batch);
                        GenericHelpers::LogUtil("[Air][SupportFighters] Enqueue request: target=" + targetSupport + " have=" + haveSupport + " deficit=" + deficit + " toQueue=" + toQueue, 4);
                        IUnitTask@ firstTask = null;
                        for (int i = 0; i < toQueue; ++i) {
                            IUnitTask@ t = aiFactoryMgr.Enqueue(
                                TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::HIGH, fighterDef, pos, 64.f)
                            );
                            if (firstTask is null) @firstTask = t;
                        }
                        if (firstTask !is null) return firstTask; // ensure support fighters are built before heavy air/bombers
                    }
                }
            }

            // 3) Heavy air strike (Legion/Cortex only): enqueue Tyrannus/Dragon when income is high
            {
                float mi = metalIncome;
                float incomeThresh = Global::RoleSettings::Air::T2HeavyAirIncomeThreshold;
                int batch = Global::RoleSettings::Air::T2HeavyAirBatchPerFactory;
                if (batch > 0 && mi > incomeThresh && (side == "legion" || side == "cortex")) {
                    // Legion -> Tyrannus (legfort), Cortex -> Dragon (corcrw)
                    string heavyName = (side == "legion" ? "legfort" : "corcrwh");
                    CCircuitDef@ heavyDef = ai.GetCircuitDef(heavyName);
                    if (heavyDef !is null && heavyDef.IsAvailable(ai.frame)) {
                        IUnitTask@ firstTask = null;
                        for (int i = 0; i < batch; ++i) {
                            IUnitTask@ t = aiFactoryMgr.Enqueue(
                                TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, heavyDef, pos, 64.f)
                            );
                            if (firstTask is null) @firstTask = t;
                        }
                        if (firstTask !is null) return firstTask;
                    }
                }
            }

            // 4) Post-constructor strategy: top-up T2 bombers to a global target.
            // Remove cooldown; whenever current count is below target, enqueue up to 5.
            int targetBombers = Global::RoleSettings::Air::TargetT2BomberCount;
            if (targetBombers > 0) {
                // If the start position is land-locked by water, prefer torpedo bombers over standard T2 bombers
                const bool landLocked = Global::Map::LandLocked;
                string bomberName;
                if (landLocked) {
                    // Torpedo bomber IDs per side: armada=armlance, cortex=cortitan, legion=legatorpbomber
                    bomberName = (side == "armada" ? "armlance" : (side == "cortex" ? "cortitan" : "legatorpbomber"));
                    GenericHelpers::LogUtil("[Air][Bombers] LandLocked start: using torpedo bomber '" + bomberName + "' for side=" + side, 3);
                } else {
                    bomberName = UnitHelpers::GetT2BomberNameForSide(side);
                }
                int haveBombers = UnitDefHelpers::GetUnitDefCount(bomberName);
                if (haveBombers >= 0 && haveBombers < targetBombers) {
                    CCircuitDef@ bomberDef = ai.GetCircuitDef(bomberName);
                    if (bomberDef !is null && bomberDef.IsAvailable(ai.frame)) {
                        int deficit = targetBombers - haveBombers;
                        int toQueue = (deficit < 5 ? deficit : 5);
                        IUnitTask@ firstTask = null;
                        for (int i = 0; i < toQueue; ++i) {
                            IUnitTask@ t = aiFactoryMgr.Enqueue(
                                TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, bomberDef, pos, 64.f)
                            );
                            if (firstTask is null) @firstTask = t;
                            // Track bombers while gate is closed; when gate opens, don't track
                            if (!g_bomberGateOpen) {
                                g_pendingT2Bombers.insertLast(bomberName);
                            }
                        }
                        // If pending exceeds open threshold, switch all bombers to bomber role and clear
                        if (!g_bomberGateOpen && int(g_pendingT2Bombers.length()) >= Global::RoleSettings::Air::BomberGateOpenThreshold) {
                            g_bomberGateOpen = true;
                            SetMainRoleForAllT2Bombers("bomber");
                            // Upgrade attributes on any already-created T2 bombers we've tracked
                            for (uint k = 0; k < g_t2BomberUnits.length(); ++k) {
                                CCircuitUnit@ bu = g_t2BomberUnits[k];
                                if (bu !is null) {
                                    bu.AddAttribute(Unit::Attr::SIEGE.type);
                                }
                            }
                            g_pendingT2Bombers.resize(0);
                            g_t2BomberUnits.resize(0);
                            GenericHelpers::LogUtil("[Air][Bombers] Gate OPEN via queue: switched defs to bomber role", 3);
                        }
                        if (firstTask !is null) return firstTask;
                    }
                }
            }
        }
        // If T2 plant but no specific action above, do NOT enqueue T1 construction aircraft here to avoid blocking advanced queues.

        // Economy snapshot for simple gating
        // float mi = Global::Economy::MetalIncome;
        // float ei = Global::Economy::EnergyIncome;

        // Simple air roster per side (T1)
    // string scout = (side == "armada" ? "armpeep" : side == "cortex" ? "corfink" : "legfig" );
        // string fighter = (side == "armada" ? "armfig" : side == "cortex" ? "corveng" : "legfig" );
        // string bomber = (side == "armada" ? "armthund" : side == "cortex" ? "corhurc" : "legbmb" );
        // // Prefer fighters early, sprinkle scouts and bombers

        // // Maintain a small scout presence
        // int scouts = UnitDefHelpers::SumUnitDefCounts({ scout });
        // if (scouts < 2 && ei > 150.0f) {
        //     CCircuitDef@ d = ai.GetCircuitDef(scout);
        //     if (d !is null && d.IsAvailable(ai.frame))
        //         return aiFactoryMgr.Enqueue(TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, d, pos, 64.f));
        // }

        // // Fighters: mainline AA/air control
        // int fighters = UnitDefHelpers::SumUnitDefCounts({ fighter });
        // if (fighters < 8 && mi > 8.0f && ei > 220.0f) {
        //     CCircuitDef@ d = ai.GetCircuitDef(fighter);
        //     if (d !is null && d.IsAvailable(ai.frame))
        //         return aiFactoryMgr.Enqueue(TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::HIGH, d, pos, 64.f));
        // }

        // // Bombers: gated heavier by eco
        // int bombers = UnitDefHelpers::SumUnitDefCounts({ bomber });
        // if (bombers < 4 && mi > 10.0f && ei > 300.0f) {
        //     CCircuitDef@ d = ai.GetCircuitDef(bomber);
        //     if (d !is null && d.IsAvailable(ai.frame))
        //         return aiFactoryMgr.Enqueue(TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, d, pos, 64.f));
        // }

        // Fallback to default when no specific recruit fired
        return aiFactoryMgr.DefaultMakeTask(u);
    }

    /******************************************************************************

    MILITARY UNIT TRACKING (for bomber gate)

    ******************************************************************************/

    // Track newly created military units; record T2 bombers while the gate is closed
    void Air_MilitaryAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        if (unit is null) return;
        if (usage != Unit::UseAs::COMBAT) return; // bombers are military/combat
        const CCircuitDef@ cdef = unit.circuitDef;
        if (cdef is null) return;
        // Only track T2 bombers when the gate is closed
        string uname = cdef.GetName();
        if (!g_bomberGateOpen) {
            array<string> t2Names = GetAllT2BomberNames();
            for (uint i = 0; i < t2Names.length(); ++i) {
                if (uname == t2Names[i]) {
                    g_t2BomberUnits.insertLast(unit);
                    GenericHelpers::LogUtil("[Air][Bombers] Tracking T2 bomber unit id=" + unit.id + " ('" + uname + "') while gate closed", 4);
                    break;
                }
            }
        }
        // Track support fighters and mark them to stay near base
        string side = UnitHelpers::GetSideForUnitName(uname);
        string t2Fighter = GetT2FighterNameForSide(side);
        if (uname == t2Fighter) {
            int targetSupport = Global::RoleSettings::Air::TargetSupportFighterCount;
            int haveSupport = GetSupportFighterCount();
            if (haveSupport < targetSupport) {
                g_supportFighterUnits.insertLast(unit);
                // Give a base/defensive hint so these hover near our start area
                unit.AddAttribute(Unit::Attr::BASE.type);
                // Ensure primary role is set to support for these fighters (def-level)
                Type supportRole = aiRoleMasker.GetTypeMask("support").type;
                CCircuitDef@ defw = ai.GetCircuitDef(uname);
                if (defw !is null) {
                    defw.SetMainRole(supportRole);
                    GenericHelpers::LogUtil("[Air][SupportFighters] Set mainRole=support for '" + uname + "'", 3);
                } else {
                    GenericHelpers::LogUtil("[Air][SupportFighters] WARNING: Could not resolve def for '" + uname + "' to set mainRole", 2);
                }
                GenericHelpers::LogUtil("[Air][SupportFighters] Added unit id=" + unit.id + " to support wing (count=" + GetSupportFighterCount() + ")", 3);
            }
        }
    }

    void Air_MilitaryAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        if (unit is null) return;
        // Remove from tracking if present
        for (uint i = 0; i < g_t2BomberUnits.length(); ++i) {
            if (g_t2BomberUnits[i] is unit) {
                g_t2BomberUnits.removeAt(i);
                GenericHelpers::LogUtil("[Air][Bombers] Tracked bomber removed id=" + unit.id, 4);
                break;
            }
        }
        for (uint j = 0; j < g_supportFighterUnits.length(); ++j) {
            if (g_supportFighterUnits[j] is unit) {
                g_supportFighterUnits.removeAt(j);
                GenericHelpers::LogUtil("[Air][SupportFighters] Removed unit id=" + unit.id + " from support wing (count=" + GetSupportFighterCount() + ")", 3);
                break;
            }
        }
    }

    string Air_SelectFactoryHandler(const AIFloat3& in pos, bool isStart, bool isReset) {
        if(isStart) {
            if(Global::Map::NearestMapStartPosition !is null) {
                return FactoryHelpers::SelectStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            } else {
                GenericHelpers::LogUtil("[Air_SelectFactoryHandler] nearestMapPosition is null", 2);
                return FactoryHelpers::GetFallbackStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            }
        }
   
        return "";
    }

    void Air_FactoryAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
    {       
        // Build up to 3x T1 construction aircraft when a NEW AIRCRAFT PLANT comes online.
        // Previously this ran on ANY unit add, flooding the queue and starving combat units.
        const CCircuitDef@ cdef = (unit is null ? null : unit.circuitDef);
        if (cdef is null) return;

        // Only react to factories, and specifically aircraft plants (T1 or T2)
        if (usage != Unit::UseAs::FACTORY) return;
        const string uname = cdef.GetName();
        // FIX: Only seed T1 construction aircraft from T1 aircraft plants (not from T2 plants)
        if (!UnitHelpers::IsT1AircraftPlant(uname)) return;

        // Cap initial constructors to target per global setting; enqueue only the deficit.
        // Count ALL T1 air constructors across sides using helper.
        array<string> t1AirCons = UnitHelpers::GetAllT1AirConstructors();
        int have = UnitDefHelpers::SumUnitDefCounts(t1AirCons);
        int target = Global::RoleSettings::Air::MinT1AirConstructorCount;
        int need = target - have;
        if (need <= 0) return;

        // Resolve side-specific T1 air constructor only if we need to enqueue
        string side = UnitHelpers::GetSideForUnitName(uname);
        string builderName;
        if (side == "armada")      builderName = "armca"; // T1 construction aircraft
        else if (side == "cortex") builderName = "corca";
        else if (side == "legion") builderName = "legca";
        else                        builderName = "armca"; // default fallback

        CCircuitDef@ buildDef = ai.GetCircuitDef(builderName);
        if (buildDef is null || !buildDef.IsAvailable(ai.frame)) return;

        const AIFloat3 pos = unit.GetPos(ai.frame);
        for (int j = 0; j < need; ++j) {
            aiFactoryMgr.Enqueue(
                TaskS::Recruit(
                    Task::RecruitType::BUILDPOWER,
                    Task::Priority::NORMAL,
                    buildDef,
                    pos,
                    64.f
                )
            );
        }
    }

    void Air_FactoryAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
	}


    // Local default implementations (ready to customize per-role)
    bool Air_AiIsSwitchTime(int lastSwitchFrame) {
        int interval = (30 * SECOND);
        return (lastSwitchFrame + interval) <= ai.frame;
    }
    bool Air_AiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 1.2f * facDef.costM * float(factoryCount)) || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }
    int Air_MakeSwitchInterval() {
        return AiRandom(Global::RoleSettings::Air::MinAiSwitchTime, Global::RoleSettings::Air::MaxAiSwitchTime) * SECOND;
    }
    
    
    /******************************************************************************

    MILITARY HOOKS

    ******************************************************************************/
    
    bool Air_AiIsAirValid() {
        //GenericHelpers::LogUtil("[AIR] Enter Air_AiIsAirValid", 4);
        return true;
    }

    // If the unit is a bomber and we have fewer than a minimum bomber count globally,
    // return null to defer making a task (avoid trickling in solo bombers).
    // IUnitTask@ Air_MilitaryAiMakeTask(CCircuitUnit@ u)
    // {
    //     const CCircuitDef@ cdef = (u is null ? null : u.circuitDef);
    //     if (cdef is null) {
    //         return aiMilitaryMgr.DefaultMakeTask(u);
    //     }

    //     // Detect bomber units via role mask (engine-provided)
    // const bool isBomber = cdef.IsRoleAny(Unit::Role::BOMBER.mask);

    //     if (isBomber) {
    //         // Count total bombers across all factions we field (T1 + T2 canonical bombers)
    //         // Keep this list minimal and explicit; extend if we add more bomber variants later.
    //         array<string> bomberIds;
    //         bomberIds.insertLast("armthund");   // ARM T1 bomber
    //         bomberIds.insertLast("corshad");    // CORE T1 bomber
    //         bomberIds.insertLast("legmos");     // LEG T1 bomber
    //         bomberIds.insertLast("armpnix");    // ARM T2 bomber
    //         bomberIds.insertLast("corhurc");    // CORE T2 bomber
    //         bomberIds.insertLast("legphoenix"); // LEG T2 bomber

    //         const int totalBombers = UnitDefHelpers::SumUnitDefCounts(bomberIds);
    //         if (totalBombers < 10) {
    //             // Gate early: hold off on issuing tasks to bombers until we have a small pack
    //             // to reduce ineffective trickle attacks.
    //             return null;
    //         }
    //     }

    //     // Fallback to default military behavior for non-bombers or when threshold met
    //     return aiMilitaryMgr.DefaultMakeTask(u);
    // }

    /******************************************************************************

    BUILDER HOOKS

    ******************************************************************************/ 

    IUnitTask@ Air_BuilderAiMakeTask(CCircuitUnit@ builder) {
        GenericHelpers::LogUtil("[Air_BuilderAiMakeTask] called for builder", 3);
    // Create default task only at return sites via Builder helper (no pre-creation)
        const CCircuitDef@ udef = (builder is null ? null : builder.circuitDef);
    if (udef is null) return Builder::MakeDefaultTaskWithLog(builder.id, "AIR");

        // For now, only specialize T1 construction aircraft; everything else falls back
        string uname = udef.GetName();
        bool isAir = udef.IsAbleToFly();
        bool isT1AirConstructor = (isAir && uname.length() >= 2 && uname.substr(uname.length() - 2, 2) == "ca");

        if (isT1AirConstructor) {
            return Air_T1Constructor_AiMakeTask(builder);
        }

    // Fallback to default with logging
    return Builder::MakeDefaultTaskWithLog(builder.id, "AIR");
    }

    CCircuitUnit@ energizer1 = null;
	CCircuitUnit@ energizer2 = null;
    void Air_BuilderAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		//LogUtil("BUILDER::AiUnitAdded:" + unit.circuitDef, 2);
		const CCircuitDef@ cdef = unit.circuitDef;
		if (usage != Unit::UseAs::BUILDER || cdef.IsRoleAny(Unit::Role::COMM.mask))
			return;

        // New policy: apply BASE attribute broadly to air constructors when global counts are below thresholds.
        string uname = cdef.GetName();
        bool isT1AirConstructor = (uname == "armca" || uname == "corca" || uname == "legca");
        bool isT2AirConstructor = (uname == "armaca" || uname == "coraca" || uname == "legaca");

        if (isT1AirConstructor) {
            array<string> allT1AirCons = UnitHelpers::GetAllT1AirConstructors();
            int totalT1 = UnitDefHelpers::SumUnitDefCounts(allT1AirCons);
            if (totalT1 < 50) {
                unit.AddAttribute(Unit::Attr::BASE.type);
                GenericHelpers::LogUtil("[Air][Builder] T1 air constructor id=" + unit.id + " given BASE (totalT1=" + totalT1 + " < 50)", 3);
                // Preserve previous energizer tracking for backward compatibility
                if (energizer1 is null) { @energizer1 = unit; }
            }
        }
        else if (isT2AirConstructor) {
            array<string> allT2AirCons; allT2AirCons = { "armaca", "coraca", "legaca" };
            int totalT2 = UnitDefHelpers::SumUnitDefCounts(allT2AirCons);
            if (totalT2 < 5) {
                unit.AddAttribute(Unit::Attr::BASE.type);
                GenericHelpers::LogUtil("[Air][Builder] T2 air constructor id=" + unit.id + " given BASE (totalT2=" + totalT2 + " < 5)", 3);
                if (energizer2 is null) { @energizer2 = unit; }
            }
        }

	}

    void Air_BuilderAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		if (energizer1 is unit)
			@energizer1 = null;
		else if (energizer2 is unit)
			@energizer2 = null;
	}

    void Air_BuilderAiTaskAdded(IUnitTask@ task) {
        GenericHelpers::LogUtil("[Air_BuilderAiTaskAdded] called for task", 3);
    }

    void Air_BuilderAiTaskRemoved(IUnitTask@ task, bool done) {

    }

    /******************************************************************************

    BUILDER LOGIC

    ******************************************************************************/

    IUnitTask@ Air_T1Constructor_AiMakeTask(CCircuitUnit@ u) {
        // Snapshot economy
        //float mi = Global::Economy::MetalIncome;
        //float ei = Global::Economy::EnergyIncome;
        const SResourceInfo@ metal = aiEconomyMgr.metal;
		const SResourceInfo@ energy = aiEconomyMgr.energy;
		
		float mi  = metal.income;
		float ei  = energy.income;
        // Deprecated: avoid writing to Global::Economy shadow; rely on aiEconomyMgr instead
        bool isEnergyFull = aiEconomyMgr.isEnergyFull;

        AIFloat3 conLocation = u.GetPos(ai.frame);
        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());
        if (u is Builder::primaryT1AirConstructor) {

            // Consider upgrading to a T2 Aircraft Plant if economy and prerequisites allow
            //if (!Builder::IsT2AirPlantQueued) {
                int t2AirPlantCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2AircraftPlants());
                bool hasPrimaryT1AirPlant = (Factory::primaryT1AirPlant !is null);
                if (EconomyHelpers::ShouldBuildT2AircraftPlant(
                    /*mi*/ mi,
                    /*ei*/ ei,
                    /*metalCurrent*/ aiEconomyMgr.metal.current,
                    /*requiredMetalIncome*/ Global::RoleSettings::Air::RequiredMetalIncomeForT2AircraftPlant,
                    /*requiredMetalCurrent*/ Global::RoleSettings::Air::RequiredMetalCurrentForT2AircraftPlant,
                    /*requiredEnergyIncome*/ Global::RoleSettings::Air::RequiredEnergyIncomeForT2AircraftPlant,
                    /*constructorDef*/ u.circuitDef,
                    /*t2AirPlantCount*/ t2AirPlantCount,
                    /*maxAllowed*/ Global::RoleSettings::Air::MaxT2AircraftPlants
                ) && hasPrimaryT1AirPlant) {
                    AIFloat3 anchor = Factory::GetT1AirPlantPos();
                    IUnitTask@ tT2Air = Builder::EnqueueT2AirPlant(unitSide, anchor, SQUARE_SIZE * 30, 600 * SECOND);
                    if (tT2Air !is null) return tT2Air;
                }
                // Reserve-trigger: if metal reserves exceed 1300 and we have zero T2 air plants, force-queue one
                // regardless of income thresholds. Avoid duplicate enqueue if a build is already queued.
                if (hasPrimaryT1AirPlant && t2AirPlantCount <= 0 && aiEconomyMgr.metal.current > 1300.0f) {
                    AIFloat3 anchor2 = Factory::GetT1AirPlantPos();
                    IUnitTask@ tForceT2 = Builder::EnqueueT2AirPlant(unitSide, anchor2, SQUARE_SIZE * 40, 600 * SECOND);
                    if (tForceT2 !is null) return tForceT2;
                }
           // }

            // Build Energy Converter?
            if (EconomyHelpers::ShouldBuildT1EnergyConverter(
                /*metalIncome*/ mi,
                /*energyIncome*/ ei,
                /*energyCurrent*/ aiEconomyMgr.energy.current,
                /*energyStorage*/ aiEconomyMgr.energy.storage,
                /*untilMetalIncome*/ Global::RoleSettings::Air::BuildT1ConvertersUntilMetalIncome,
                /*minEnergyIncome*/ Global::RoleSettings::Air::BuildT1ConvertersMinimumEnergyIncome,
                /*minEnergyCurrentPercent*/ Global::RoleSettings::Air::BuildT1ConvertersMinimumEnergyCurrentPercent
            )) {
                IUnitTask@ tConv = Builder::EnqueueT1EnergyConverter(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tConv !is null) return tConv;
            }

            // Build regular solar?
            if (EconomyHelpers::ShouldBuildT1Solar(
                /*energyIncome*/ ei,
                /*minEnergyIncome*/ Global::RoleSettings::Air::SolarEnergyIncomeMinimum
            )) {
                IUnitTask@ tSolar = Builder::EnqueueT1Solar(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tSolar !is null) return tSolar;
            }

            // Build a T1 nano caretaker if under desired target (income-based) or reserves allow
            float energyPercent = (aiEconomyMgr.energy.storage > 0.0f)
                ? (aiEconomyMgr.energy.current / aiEconomyMgr.energy.storage)
                : 0.0f;

            // Only build nanos if we have a preferred factory to anchor around
            if (Factory::GetPreferredFactory() !is null && EconomyHelpers::ShouldBuildT1Nano(
                ei,
                mi,
                Global::RoleSettings::Air::NanoEnergyPerUnit,
                Global::RoleSettings::Air::NanoMetalPerUnit,
                Global::RoleSettings::Air::NanoMaxCount,
                aiEconomyMgr.metal.current,
                Global::RoleSettings::Air::NanoBuildWhenOverMetal,
                energyPercent
            )) {
                // Centralized selection with per-factory nano caps and prioritization
                CCircuitUnit@ targetFactory = Factory::SelectFactoryNeedingNano();
                if (targetFactory !is null) {
                    IUnitTask@ tNano = Factory::EnqueueNanoForFactory(targetFactory, Task::Priority::NORMAL);
                    if (tNano !is null) return tNano;
                }
            }

            // Build advanced T1 solar using Air predicate
            // Compute current T2 air-related counts
            array<string> t2AirCons; t2AirCons = { "armaca", "coraca", "legaca" };
            int t2ConstructionAircraftCount = UnitDefHelpers::SumUnitDefCounts(t2AirCons);
            array<string> t2AirPlants = UnitHelpers::GetAllT2AircraftPlants();
            int t2AircraftPlantCount = UnitDefHelpers::SumUnitDefCounts(t2AirPlants);

            if (EconomyHelpers::ShouldBuildT1AdvancedSolar(
                /*energyIncome*/ ei,
                /*metalIncome*/ mi,
                /*energyIncomeMinimumThreshold*/ Global::RoleSettings::Air::AdvancedSolarEnergyIncomeMinimum,
                /*energyIncomeMaximumThreshold*/ Global::RoleSettings::Air::AdvancedSolarEnergyIncomeMaximum,
                /*t2ConstructorCount*/ t2ConstructionAircraftCount,
                /*t2FactoryCount*/ t2AircraftPlantCount,
                /*isT2FactoryQueued*/ Factory::IsT2AirPlantBuildQueued(),
                /*enableT2ProgressGate*/ true,
                /*metalIncomeFallbackMinimum*/ 6.0f
            )) {
                IUnitTask@ tAdvSolar = Builder::EnqueueT1AdvancedSolar(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tAdvSolar !is null) return tAdvSolar;
            } 
        } else if (EconomyHelpers::ShouldAssistPrimaryWorker(
            /*energyIncome*/ ei,
            /*minEnergyIncome*/ Global::RoleSettings::Air::AssistPrimaryWorkerEnergyIncomeMinimum
        )) {
            return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT1AirConstructor, Task::Priority::HIGH, true, 160 * SECOND);
        }

        // Default: allow null to propagate to central fallback
        return null;
    }


    /******************************************************************************

    ROLE CONFIGURATION

    ******************************************************************************/
   

    bool Air_RoleMatch(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        bool match = false;

        if (preferredMapRole == AiRole::AIR) match = true;
       
        if (match) { 
            GenericHelpers::LogUtil("[RoleMatch] AIR", 2); 
        }

        return match;
    }

    void Register() {
        if (RoleConfigs::Get(AiRole::AIR) !is null) return;
        RoleConfig@ cfg = RoleConfig(AiRole::AIR, cast<MainUpdateDelegate@>(@Air_MainUpdate));

        @cfg.InitHandler = cast<InitDelegate@>(@Air_Init);

        @cfg.AiIsSwitchTimeHandler = cast<AiIsSwitchTimeDelegate@>(@Air_AiIsSwitchTime);
        @cfg.AiIsSwitchAllowedHandler = cast<AiIsSwitchAllowedDelegate@>(@Air_AiIsSwitchAllowed);
        @cfg.MakeSwitchIntervalHandler = cast<MakeSwitchIntervalDelegate@>(@Air_MakeSwitchInterval);

        @cfg.FactoryAiUnitAdded = cast<AiUnitAddedDelegate@>(@Air_FactoryAiUnitAdded);
        @cfg.FactoryAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Air_FactoryAiUnitRemoved);

        @cfg.BuilderAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Air_BuilderAiMakeTask);
        @cfg.FactoryAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Air_FactoryAiMakeTask);
        
        @cfg.BuilderAiUnitAdded = cast<AiUnitAddedDelegate@>(@Air_BuilderAiUnitAdded);
        @cfg.BuilderAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Air_BuilderAiUnitRemoved);

        @cfg.BuilderAiTaskAddedHandler = cast<AiTaskAddedDelegate@>(@Air_BuilderAiTaskAdded);
        @cfg.BuilderAiTaskRemovedHandler = cast<AiTaskRemovedDelegate@>(@Air_BuilderAiTaskRemoved);

        @cfg.SelectFactoryHandler = cast<SelectFactoryDelegate@>(@Air_SelectFactoryHandler);
        @cfg.EconomyUpdateHandler = cast<EconomyUpdateDelegate@>(@Air_EconomyUpdate);

        @cfg.AiIsAirValidHandler = cast<AiIsAirValidDelegate@>(@Air_AiIsAirValid);
        //@cfg.MilitaryAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Air_MilitaryAiMakeTask);
        // Track military unit creation/removal so we can upgrade existing bombers when the gate opens
        @cfg.MilitaryAiUnitAdded = cast<AiUnitAddedDelegate@>(@Air_MilitaryAiUnitAdded);
        @cfg.MilitaryAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Air_MilitaryAiUnitRemoved);
        

        @cfg.RoleMatchHandler = cast<RoleMatchDelegate@>(@Air_RoleMatch);

        RoleConfigs::Register(cfg);
    }
}