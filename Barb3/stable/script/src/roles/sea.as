// role: SEA
#include "../helpers/unit_helpers.as"
#include "../helpers/economy_helpers.as"
#include "../helpers/unitdef_helpers.as"
#include "../types/role_config.as"
#include "../global.as"
#include "../types/terrain.as"
#include "../helpers/objective_helpers.as"

namespace RoleSea {

    // Donation helper state and functions (mirror TECH pattern but for T2 sea constructors)
    namespace Donate {
        // Count of T2 constructor submarines ever produced by SEA role
        int T2SeaCtorEverBuilt = 0;
        // Ensure we donate only once per game
        bool DonatedThird = false;

        // Return true if the def represents a T2 sea constructor submarine
        bool IsT2SeaConstructor(const CCircuitDef@ d) {
            if (d is null) return false;
            const string n = d.GetName();
            // T2 sea constructors (BAR): armacsub/coracsub; Legion reuses Cortex variant
            return (n == "armacsub" || n == "coracsub");
        }

        // Attempt to donate a unit to the lead team; logs and guards
        void TryDonate(CCircuitUnit@ u) {
            if (u is null) return;
            const int leader = ai.GetLeadTeamId();
            if (ai.teamId == leader) {
                GenericHelpers::LogUtil("[SEA][Donate] We are the leader team; skip donation for unit id=" + u.id, 3);
                return; // no-op when this AI is the leader
            }

            array<CCircuitUnit@> give(1);
            @give[0] = u; // valid handle this frame
            ai.GiveUnits(give, leader);
            GenericHelpers::LogUtil("[SEA][Donate] Transferred unit id=" + u.id + " to team " + leader, 2);
        }
    }

    /******************************************************************************

    INITIALIZATION

    ******************************************************************************/

    void Sea_Init() {
        GenericHelpers::LogUtil("Sea role initialization logic executed", 2);

        // Apply SEA role settings
        aiTerrainMgr.SetAllyZoneRange(Global::RoleSettings::Sea::AllyRange);
        // Change scout cap (unit count)
        aiMilitaryMgr.quota.scout = Global::RoleSettings::Sea::MilitaryScoutCap;

        // Change attack gate (power threshold, not a headcount)
        aiMilitaryMgr.quota.attack = Global::RoleSettings::Sea::MilitaryAttackThreshold;

        // Change raid thresholds (power)
        aiMilitaryMgr.quota.raid.min = Global::RoleSettings::Sea::MilitaryRaidMinPower; 
        aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::Sea::MilitaryRaidAvgPower; 

        Sea_ApplyStartLimits();

        // SEA-only: Set default fire state for all T1 naval combat units to 3 (fire at everything)
        // Aligns with FRONT role pattern for T1 land units.
        {
            array<string> t1Naval = UnitHelpers::GetAllT1NavalCombatUnits();
            for (uint i = 0; i < t1Naval.length(); ++i) {
                CCircuitDef@ d = ai.GetCircuitDef(t1Naval[i]);
                if (d is null) continue;
                d.SetFireState(3);
            }
            GenericHelpers::LogUtil("[SEA] Applied default fire state=3 to T1 naval combat units", 3);
        }

        // Log all strategic objectives with distance from start
        ObjectiveHelpers::LogAllObjectivesFromStart(AiRole::SEA, "SEA");
    }

    void Sea_ApplyStartLimits() {
        dictionary startLimits; 

        startLimits.set("armbanth", 0);
        startLimits.set("armmar", 0);
        startLimits.set("armcroc", 0);

        startLimits.set("armsilo", 0);
        startLimits.set("corsilo", 0);
        startLimits.set("legsilo", 0);

        UnitHelpers::ApplyUnitLimits(startLimits);

        GenericHelpers::LogUtil("HoverSea start limits applied", 3);
    }

    /******************************************************************************

    MAIN HOOKS

    ******************************************************************************/

    void Sea_MainUpdate() {
        //LogUtil("Sea update logic executed", 5);
    }

    /******************************************************************************

    ECONOMY HOOKS

    ******************************************************************************/

    void Sea_EconomyUpdate() {
    float metalIncome = aiEconomyMgr.metal.income;
        Sea_IncomeLimits(metalIncome);
    }

    /******************************************************************************

    FACTORY HOOKS

    ******************************************************************************/

    IUnitTask@ Sea_FactoryAiMakeTask(CCircuitUnit@ u)
    {
        const CCircuitDef@ facDef = (u is null ? null : u.circuitDef);
        if (facDef is null) {
            return aiFactoryMgr.DefaultMakeTask(u);
        }

        const string fname = facDef.GetName();
        // Only specialize for shipyards; otherwise fallback
        bool isT1Shipyard = UnitHelpers::IsT1Shipyard(fname);
        bool isT2Shipyard = (!isT1Shipyard && UnitHelpers::IsT2Shipyard(fname));
        if (!isT1Shipyard && !isT2Shipyard) {
            return aiFactoryMgr.DefaultMakeTask(u);
        }

        const AIFloat3 pos = u.GetPos(ai.frame);
        const string side = UnitHelpers::GetSideForUnitName(fname);

        // Resolve side-specific constructor unit names (with safe fallbacks)
        string t1Ctor = (side == "armada" ? "armcs" : side == "cortex" ? "corcs" : side == "legion" ? "legnavyconship" : "armcs");
        string t2Ctor = (side == "armada" ? "armacsub" : side == "cortex" ? "coracsub" : side == "legion" ? "coracsub" : "armacsub");

        if (isT1Shipyard) {
            // Ensure at least two T1 construction ships exist before producing other units
            int have = UnitDefHelpers::GetUnitDefCount(t1Ctor);
            if (have < 2) {
                CCircuitDef@ d = ai.GetCircuitDef(t1Ctor);
                if (d !is null && d.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, d, pos, 64.f)
                    );
                }
            }

            // Early resurrection submarine policy (configurable)
            // Gate by global setting and income-scaling helper, similar to early bot-lab expansion in TECH
            if (Global::RoleSettings::Sea::EnableEarlyRezSub) {
                float mi = aiEconomyMgr.metal.income;
                // Side IDs: armada -> armrecl, cortex -> correcl, legion -> legnavyrezsub (Dionysus)
                string rezSub = (side == "armada" ? "armrecl" : side == "cortex" ? "correcl" : "legnavyrezsub");
                int haveRez = UnitDefHelpers::GetUnitDefCount(rezSub);
                bool shouldRez = EconomyHelpers::ShouldBuildT1ResurrectionSub(
                    /*metalIncome*/ mi,
                    /*currentRezSubCount*/ haveRez,
                    /*metalIncomePerRezSub*/ Global::RoleSettings::Sea::MetalIncomePerRezSub,
                    /*earlyEnabled*/ Global::RoleSettings::Sea::EnableEarlyRezSub
                );
                if (shouldRez) {
                    CCircuitDef@ dRez = ai.GetCircuitDef(rezSub);
                    if (dRez !is null && dRez.IsAvailable(ai.frame)) {
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dRez, pos, 64.f)
                        );
                    }
                }
            }
        }

        if (isT2Shipyard) {
            // Ensure at least one T2 sea constructor exists early
            int t2conSubCount = UnitDefHelpers::GetUnitDefCount(t2Ctor);
            if (t2conSubCount < 2) {
                CCircuitDef@ d2 = ai.GetCircuitDef(t2Ctor);
                if (d2 !is null && d2.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, d2, pos, 64.f)
                    );
                }
            }

            // T2 shipyard production policy (configurable counts per class)
            // 1) Destroyers (T2/cruiser-tier): if below target, enqueue a batch at NORMAL priority
            string destroyerName = UnitHelpers::GetNavalT2DestroyerNameForSide(side);
            int haveDestroyers = UnitDefHelpers::GetUnitDefCount(destroyerName);
            int minDestroyers = Global::RoleSettings::Sea::MinT2DestroyerCount;
            int destroyerBatch = Global::RoleSettings::Sea::T2DestroyerBatchSize;
            if (minDestroyers > 0 && haveDestroyers >= 0 && haveDestroyers < minDestroyers && destroyerBatch > 0) {
                CCircuitDef@ d = ai.GetCircuitDef(destroyerName);
                if (d !is null && d.IsAvailable(ai.frame)) {
                    IUnitTask@ first = null;
                    int toQueue = destroyerBatch;
                    for (int i = 0; i < toQueue; ++i) {
                        IUnitTask@ t = aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, d, pos, 64.f)
                        );
                        if (first is null) @first = t;
                    }
                    if (first !is null) return first;
                }
            }

            // 2) AA ships (flak/escort): if below 2, enqueue 2
            string aaShipName = UnitHelpers::GetNavalAAShipNameForSide(side);
            int haveAA = UnitDefHelpers::GetUnitDefCount(aaShipName);
            if (haveAA >= 0 && haveAA < 2) {
                CCircuitDef@ dAA = ai.GetCircuitDef(aaShipName);
                if (dAA !is null && dAA.IsAvailable(ai.frame)) {
                    IUnitTask@ firstAA = null;
                    for (int i = 0; i < 2; ++i) {
                        IUnitTask@ tAA = aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dAA, pos, 64.f)
                        );
                        if (firstAA is null) @firstAA = tAA;
                    }
                    if (firstAA !is null) return firstAA;
                }
            }

            // 3) Jammer ship: ensure at least 1
            string jammerName = UnitHelpers::GetNavalJammerShipNameForSide(side);
            int haveJammers = UnitDefHelpers::GetUnitDefCount(jammerName);
            if (haveJammers >= 0 && haveJammers < 1) {
                CCircuitDef@ dJam = ai.GetCircuitDef(jammerName);
                if (dJam !is null && dJam.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dJam, pos, 64.f)
                    );
                }
            }

            // 4) Radar ship (MLS utility): ensure at least 1
            string radarShipName = UnitHelpers::GetNavalRadarShipNameForSide(side);
            int haveRadar = UnitDefHelpers::GetUnitDefCount(radarShipName);
            if (haveRadar >= 0 && haveRadar < 1) {
                CCircuitDef@ dRad = ai.GetCircuitDef(radarShipName);
                if (dRad !is null && dRad.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dRad, pos, 64.f)
                    );
                }
            }

            // 5) Missile ships: if below 5, enqueue 5
            string mShipName = UnitHelpers::GetNavalMissileShipNameForSide(side);
            int haveMissile = UnitDefHelpers::GetUnitDefCount(mShipName);
            if (haveMissile >= 0 && haveMissile < 5) {
                CCircuitDef@ dMs = ai.GetCircuitDef(mShipName);
                if (dMs !is null && dMs.IsAvailable(ai.frame)) {
                    IUnitTask@ firstMs = null;
                    for (int i = 0; i < 5; ++i) {
                        IUnitTask@ tMs = aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dMs, pos, 64.f)
                        );
                        if (firstMs is null) @firstMs = tMs;
                    }
                    if (firstMs !is null) return firstMs;
                }
            }

            // 6) Anti-nuke ship: ensure at least 1 (skip gracefully if not available in profile)
            string antiNukeShip = UnitHelpers::GetNavalAntiNukeShipNameForSide(side);
            int haveAnti = UnitDefHelpers::GetUnitDefCount(antiNukeShip);
            if (haveAnti >= 0 && haveAnti < 1) {
                CCircuitDef@ dAnti = ai.GetCircuitDef(antiNukeShip);
                if (dAnti !is null && dAnti.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dAnti, pos, 64.f)
                    );
                }
            }

            // 7) Flagship (capital ship): ensure at least 1, placed last in sequence
            // Side IDs: armada -> armepoch, cortex -> corblackhy; Legion falls back to Cortex variant
            string flagshipName = (side == "armada" ? "armepoch" : (side == "cortex" ? "corblackhy" : "corblackhy"));
            int haveFlagship = UnitDefHelpers::GetUnitDefCount(flagshipName);
            if (haveFlagship >= 0 && haveFlagship < 1) {
                CCircuitDef@ dFlag = ai.GetCircuitDef(flagshipName);
                if (dFlag !is null && dFlag.IsAvailable(ai.frame)) {
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::NORMAL, dFlag, pos, 64.f)
                    );
                }
            }
        }

        // Fallback to default when nothing triggers
        return aiFactoryMgr.DefaultMakeTask(u);
    }

    string Sea_SelectFactoryHandler(const AIFloat3& in pos, bool isStart, bool isReset) {

        if(isStart) {
            if(Global::Map::NearestMapStartPosition !is null) {
                return FactoryHelpers::SelectStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            } else {
                GenericHelpers::LogUtil("[Sea_SelectFactoryHandler] nearestMapPosition is null", 2);
                return FactoryHelpers::GetFallbackStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            }
        }
        
        return "";
    }

    bool Sea_AiIsSwitchTime(int lastSwitchFrame) {
        int interval = (30 * SECOND);
        return (lastSwitchFrame + interval) <= ai.frame;
    }

    bool Sea_AiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 1.2f * facDef.costM * float(factoryCount)) || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }

    int Sea_MakeSwitchInterval() {
        return AiRandom(Global::RoleSettings::Sea::MinAiSwitchTime, Global::RoleSettings::Sea::MaxAiSwitchTime) * SECOND;
    }

    /******************************************************************************

    MILITARY HOOKS

    ******************************************************************************/
    

    /******************************************************************************

    BUILDER HOOKS

    ******************************************************************************/ 

    IUnitTask@ Sea_BuilderAiMakeTask(CCircuitUnit@ builder) {
        GenericHelpers::LogUtil("[Sea_BuilderAiMakeTask] called for builder", 3);
        if (builder is null) return null; // Defensive

        // Pre-create and cache a single default task instance; never recreate.
        IUnitTask@ defaultTask = Builder::MakeDefaultTaskWithLog(builder.id, "SEA");

        const CCircuitDef@ udef = builder.circuitDef;
        if (udef is null) return defaultTask;

        // Early resource-expansion return: preserve MEX/GEO build tasks
        if (defaultTask !is null && defaultTask.GetType() == Task::Type::BUILDER) {
            Task::BuildType dbt = Task::BuildType(defaultTask.GetBuildType());
            if (dbt == Task::BuildType::MEX || dbt == Task::BuildType::MEXUP ||
                dbt == Task::BuildType::GEO || dbt == Task::BuildType::GEOUP) {
                GenericHelpers::LogUtil("[SEA] defaultTask is MEX/MEXUP/GEO/GEOUP; returning early", 3);
                return defaultTask;
            }
        }

        // Specialize only sea constructors; everything else falls back to cached default
        string uname = udef.GetName();
        // Include Legion's non-standard T1 constructor name explicitly (no 'cs' suffix)
        bool isT1SeaConstructor = (uname == "armcs" || uname == "corcs" || uname == "legnavyconship");
        // T2 sea constructors typically use the 'acsub' suffix (e.g., armacsub/coracsub)
        bool isT2SeaConstructor = (uname.length() >= 5 && uname.substr(uname.length() - 5, 5) == "acsub");

        if (isT1SeaConstructor) {
            return Sea_T1Constructor_AiMakeTask(builder, defaultTask);
        } else if (isT2SeaConstructor) {
            return Sea_T2Constructor_AiMakeTask(builder, defaultTask);
        }

        // Fallback to cached default task
        return defaultTask;
    }

    void Sea_BuilderAiTaskAdded(IUnitTask@ task) {
        GenericHelpers::LogUtil("[Sea_BuilderAiTaskAdded] called for task", 3);
    }

    void Sea_BuilderAiTaskRemoved(IUnitTask@ task, bool done) {
        //GenericHelpers::LogUtil("[Sea_BuilderAiTaskRemoved] called for task", 3);
    }

    CCircuitUnit@ energizer1 = null;
	CCircuitUnit@ energizer2 = null;
    void Sea_BuilderAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		//LogUtil("BUILDER::AiUnitAdded:" + unit.circuitDef, 2);
		const CCircuitDef@ cdef = unit.circuitDef;
		if (usage != Unit::UseAs::BUILDER || cdef.IsRoleAny(Unit::Role::COMM.mask))
			return;

        // Donation hook: when the 3rd T2 sea constructor is created, donate it to the team leader (once per game)
        if (Donate::IsT2SeaConstructor(cdef)) {
            Donate::T2SeaCtorEverBuilt += 1;
            GenericHelpers::LogUtil("[SEA][Donate] T2 sea constructor observed (" + cdef.GetName() + ") count=" + Donate::T2SeaCtorEverBuilt + " id=" + unit.id, 3);
            if (!Donate::DonatedThird && Donate::T2SeaCtorEverBuilt == 3) {
                Donate::DonatedThird = true; // lock before attempt to avoid re-entry
                GenericHelpers::LogUtil("[SEA][Donate] Triggering donation of 3rd T2 sea constructor (id=" + unit.id + ")", 2);
                Donate::TryDonate(unit);
            }
        }

		// constructor with BASE attribute is assigned to tasks near base
		if (cdef.costM < 200.f) {
			if (energizer1 is null
				&& (uint(cdef.count) > aiMilitaryMgr.GetGuardTaskNum() || cdef.IsAbleToFly()))
			{
				@energizer1 = unit;
				unit.AddAttribute(Unit::Attr::BASE.type);
			}
		} else {
			if (energizer2 is null) {
				@energizer2 = unit;
				unit.AddAttribute(Unit::Attr::BASE.type);
			}
		}
	}

    void Sea_BuilderAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		if (energizer1 is unit)
			@energizer1 = null;
		else if (energizer2 is unit)
			@energizer2 = null;
	}

    /******************************************************************************

    ECONOMY LOGIC

    ******************************************************************************/

    void Sea_IncomeLimits(float metalIncome) {
        // Determine cap: 35 metal income per lab (e.g., 70 -> 2 labs)
        int cap = int(metalIncome / 35.0f);

       Sea_IncomeLabLimits(metalIncome);
       Sea_IncomeBuilderLimits(metalIncome);

       //Always apply map limits, regardless of how eco changes labs limits
       dictionary mapLimits = Global::Map::Config.UnitLimits;
       UnitHelpers::ApplyUnitLimits(mapLimits);
    }

    void Sea_IncomeLabLimits(float metalIncome) {
        // Determine cap: 50 metal income per lab (e.g., 100 -> 2 labs)
        int seaLabCap = int(metalIncome / 75.0f);

        string side = Global::AISettings::Side;
        array<string> labs;
        labs = { "armasy", "corasy" };
            
        UnitHelpers::BatchApplyUnitCaps(labs, seaLabCap);
    }

    void Sea_IncomeBuilderLimits(float metalIncome) {
        
    }

    /******************************************************************************

    BUILDER LOGIC

    ******************************************************************************/

    IUnitTask@ Sea_T1Constructor_AiMakeTask(CCircuitUnit@ u, IUnitTask@ defaultTask) {
        // Snapshot economy
    float mi = aiEconomyMgr.metal.income;
    float ei = aiEconomyMgr.energy.income;
        bool isEnergyFull = aiEconomyMgr.isEnergyFull;

        AIFloat3 conLocation = u.GetPos(ai.frame);
        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());
        // First, try to satisfy any SEA PRIMARY objectives (e.g., seaplane platform then tidal spam)
        IUnitTask@ objTask = Sea_TryHandleObjective(u, conLocation, unitSide, mi, ei);
        if (objTask !is null) return objTask;
        if (u is Builder::primaryT1SeaConstructor) {
            

            // Consider upgrading to a T2 Shipyard if economy and prerequisites allow
           // if (!Builder::IsT2ShipyardQueued) {
            int t2ShipyardCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2Shipyards());
            bool hasPrimaryT1Shipyard = (Factory::primaryT1Shipyard !is null);
            if (EconomyHelpers::ShouldBuildT2Shipyard(
                mi,
                ei,
                aiEconomyMgr.metal.current,
                Global::RoleSettings::Sea::MinimumMetalIncomeForT2Shipyard,
                Global::RoleSettings::Sea::RequiredMetalCurrentForT2Shipyard,
                Global::RoleSettings::Sea::MinimumEnergyIncomeForT2Shipyard,
                t2ShipyardCount,
                Global::RoleSettings::Sea::MaxT2Shipyards,
                hasPrimaryT1Shipyard
            )) {
                AIFloat3 anchor = Factory::GetT1ShipyardPos();
                IUnitTask@ tT2Sy = Builder::EnqueueT2Shipyard(unitSide, anchor, SQUARE_SIZE * 60, 600 * SECOND);
                if (tT2Sy !is null) return tT2Sy;
            }
           // }

            // Build Naval Energy Converter?
            if (EconomyHelpers::ShouldBuildT1EnergyConverter(
                mi,
                ei,
                aiEconomyMgr.energy.current,
                aiEconomyMgr.energy.storage,
                Global::RoleSettings::Sea::BuildT1ConvertersUntilMetalIncome,
                Global::RoleSettings::Sea::BuildT1ConvertersMinimumEnergyIncome,
                Global::RoleSettings::Sea::BuildT1ConvertersMinimumEnergyCurrentPercent
            )) {
                IUnitTask@ tConv = Builder::EnqueueT1NavalEnergyConverter(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tConv !is null) return tConv;
            }

            // Build a T1 naval nano caretaker if income-based target or reserves-based condition is met
            float energyPercent = (aiEconomyMgr.energy.storage > 0.0f)
                ? (aiEconomyMgr.energy.current / aiEconomyMgr.energy.storage)
                : 0.0f;
            // Only build nanos if we have a preferred factory to anchor around
            if (Factory::GetPreferredFactory() !is null && EconomyHelpers::ShouldBuildT1Nano(
                ei,
                mi,
                Global::RoleSettings::Sea::NanoEnergyPerUnit,
                Global::RoleSettings::Sea::NanoMetalPerUnit,
                Global::RoleSettings::Sea::NanoMaxCount,
                aiEconomyMgr.metal.current,
                Global::RoleSettings::Sea::NanoBuildWhenOverMetal,
                energyPercent
            )) {
                // Centralized selection with per-factory nano caps; water labs use naval nanos automatically
                CCircuitUnit@ targetFactory = Factory::SelectFactoryNeedingNano();
                if (targetFactory !is null) {
                    IUnitTask@ tNano = Factory::EnqueueNanoForFactory(targetFactory, Task::Priority::NORMAL);
                    if (tNano !is null) return tNano;
                }
            }

            // Prefer tidals at sea instead of solars
            if (EconomyHelpers::ShouldBuildT1Solar(ei, Global::RoleSettings::Sea::TidalEnergyIncomeMinimum)) {
                IUnitTask@ tTidal = Builder::EnqueueT1Tidal(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tTidal !is null) return tTidal;
            }
            
        } else if (EconomyHelpers::ShouldAssistPrimaryWorker(ei, Global::RoleSettings::Sea::AssistPrimaryWorkerEnergyIncomeMinimum)) {
            return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT1SeaConstructor, Task::Priority::HIGH, true, 160 * SECOND);
        }

    // Default fallback
    return defaultTask;
    }

    IUnitTask@ Sea_T2Constructor_AiMakeTask(CCircuitUnit@ u, IUnitTask@ defaultTask) {
        // Snapshot economy
    float mi = aiEconomyMgr.metal.income;
    float ei = aiEconomyMgr.energy.income;
        bool isEnergyFull = aiEconomyMgr.isEnergyFull;

        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());
        AIFloat3 conLocation = u.GetPos(ai.frame);

        if (u is Builder::freelanceT2SeaConstructor) {
            // Freelance T2 sea constructors do default tasks for now
            return defaultTask;
        }

        if (u is Builder::primaryT2SeaConstructor) {
            bool isEnergyLessThan90Percent = aiEconomyMgr.energy.current < aiEconomyMgr.energy.storage * Global::RoleSettings::Sea::EnergyStorageLowPercent;

            // Advanced naval energy converter (underwater MMM) when energy is healthy
            if (EconomyHelpers::ShouldBuildT2EnergyConverter(
                mi,
                ei,
                isEnergyLessThan90Percent,
                isEnergyFull,
                Global::RoleSettings::Sea::MinimumMetalIncomeForAdvConverter,
                Global::RoleSettings::Sea::MinimumEnergyIncomeForAdvConverter
            )) {
                AIFloat3 anchorConv = Factory::GetT2ShipyardPos();
                IUnitTask@ tConv2 = Builder::EnqueueAdvNavalEnergyConverter(unitSide, anchorConv, SQUARE_SIZE * 32, SECOND * 60);
                if (tConv2 !is null) return tConv2;
            }
            // Build a naval fusion reactor if fusion policy allows and none exist yet
            if (EconomyHelpers::ShouldBuildFusionReactor(
                mi,
                ei,
                isEnergyLessThan90Percent,
                Global::RoleSettings::Sea::MinimumMetalIncomeForFUS,
                Global::RoleSettings::Sea::MinimumEnergyIncomeForFUS,
                Global::RoleSettings::Sea::MaxEnergyIncomeForFUS
            )) {
                string navalFusName = UnitHelpers::GetNavalFusionNameForSide(unitSide);
                CCircuitDef@ navalFus = (navalFusName.length() == 0 ? null : ai.GetCircuitDef(navalFusName));
                int have = (navalFus is null ? 0 : navalFus.count);
                if (navalFus !is null && have < 1) {
                    AIFloat3 anchor = Factory::GetT2ShipyardPos();
                    IUnitTask@ tNF = Builder::EnqueueNavalFUS(unitSide, anchor, SQUARE_SIZE * 32, SECOND * 300);
                    if (tNF !is null) return tNF;
                }
            }

            // Consider assisting the primary T1 sea worker when energy is low
            if (EconomyHelpers::ShouldAssistPrimaryWorker(ei, Global::RoleSettings::Sea::AssistPrimaryWorkerEnergyIncomeMinimum) && Builder::primaryT1SeaConstructor !is null) {
                return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT1SeaConstructor, Task::Priority::HIGH, true, 120 * SECOND);
            }
        }

        // Default fallback
        return defaultTask;
    }



    /******************************************************************************

    OBJECTIVE LOGIC

    ******************************************************************************/

    AIFloat3 Sea_GetObjectiveBuildPos(const Objectives::StrategicObjective@ o, const AIFloat3 &in fallback)
    {
        if (o is null) return fallback;
        if (o.pos.x != 0.0f || o.pos.z != 0.0f) return o.pos;
        if (o.line.length() > 0) return o.line[0];
        return fallback;
    }

    IUnitTask@ Sea_TryHandleObjective(CCircuitUnit@ builder, const AIFloat3 &in conLocation, const string &in unitSide, float mi, float ei)
    {
        // Find primary-group SEA objectives near base for T1 SEA constructors
        array<Objectives::StrategicObjective@> candidates = ObjectiveHelpers::Find(
            AiRole::SEA, unitSide, Objectives::ConstructorClass::SEA, 1, conLocation, ai.frame, Objectives::BuilderGroup::PRIMARY
        );
        if (candidates.length() == 0) return null;

        Objectives::StrategicObjective@ currentObjective = candidates[0];
        // Determine next step based on types present and eco
        bool wantsSeaplane = false;
        bool wantsTidal = false;
        for (uint i = 0; i < currentObjective.types.length(); ++i) {
            auto t = currentObjective.types[i];
            if (t == Objectives::BuildingType::SEAPLANE_FACTORY) wantsSeaplane = true;
            // Treat both explicit T1_TIDAL and legacy T1_ENERGY as tidal candidates
            if (t == Objectives::BuildingType::T1_TIDAL || t == Objectives::BuildingType::T1_ENERGY) wantsTidal = true;
        }

        string label = "PRIMARY";

        // If we've met end-state (platform at least queued once and energy threshold reached), mark complete
        if (wantsTidal) {
            float tidalTarget = Global::RoleSettings::Sea::TidalEnergyIncomeMinimum;
            bool platformSatisfied = !wantsSeaplane; // if not required, treat as satisfied
            if (wantsSeaplane) {
                string platNameCheck = UnitHelpers::GetSeaplanePlatformNameForSide(unitSide);
                platformSatisfied = (ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, platNameCheck) > 0);
            }
            if (platformSatisfied && ei >= tidalTarget) {
                ObjectiveHelpers::Complete(currentObjective.id);
                GenericHelpers::LogUtil("[SEA][" + label + "] Objective '" + currentObjective.id + "' complete: seaplane queued and energy >= " + tidalTarget, 2);
                return null;
            }
        }

        // If seaplane is desired and not yet queued for this objective, build one when metal income gate is met
        if (wantsSeaplane && mi >= 30.0f) {
            string platName = UnitHelpers::GetSeaplanePlatformNameForSide(unitSide);
            int alreadyQueued = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, platName);
            if (alreadyQueued <= 0) {
                // Attempt to assign and build platform
                if (!ObjectiveHelpers::TryAssign(currentObjective.id, "SEA_" + label)) return null;
                AIFloat3 pos = Sea_GetObjectiveBuildPos(currentObjective, Factory::GetPreferredFactoryPos());
                IUnitTask@ tFac = Builder::EnqueueSeaplanePlatform(unitSide, pos, SQUARE_SIZE * 24, 600 * SECOND);
                if (tFac is null) { ObjectiveHelpers::Unassign(currentObjective.id); return null; }
                ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, platName, 1);
                // Release assignment so follow-up stages (tidals) can proceed later
                ObjectiveHelpers::Unassign(currentObjective.id);
                GenericHelpers::LogUtil("[SEA][" + label + "] Enqueued seaplane platform '" + platName + "' for objective '" + currentObjective.id + "'", 2);
                return tFac;
            }
        }

        // After seaplane (or if not required), if energy below threshold and tidal desired, enqueue tidal
        if (wantsTidal && ei < Global::RoleSettings::Sea::TidalEnergyIncomeMinimum) {
            AIFloat3 pos2 = Sea_GetObjectiveBuildPos(currentObjective, conLocation);
            // Assign to avoid multiple builders colliding on the same tidal in one frame
            if (!ObjectiveHelpers::TryAssign(currentObjective.id, "SEA_" + label + "_TIDAL")) return null;
            IUnitTask@ tTidal = Builder::EnqueueT1Tidal(unitSide, pos2, SQUARE_SIZE * 32, SECOND * 30, Task::Priority::NOW);
            if (tTidal !is null) {
                ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, UnitHelpers::GetTidalNameForSide(unitSide), 1);
                ObjectiveHelpers::Unassign(currentObjective.id);
                GenericHelpers::LogUtil("[SEA][" + label + "] Enqueued tidal for objective '" + currentObjective.id + "'", 2);
                return tTidal;
            }
            ObjectiveHelpers::Unassign(currentObjective.id);
        }

        return null;
    }

    /******************************************************************************

    ROLE CONFIGURATION

    ******************************************************************************/

    bool Sea_RoleMatch(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        bool match = false;

        if (preferredMapRole == AiRole::SEA) match = true;
 
        if (match) { 
            GenericHelpers::LogUtil("[RoleMatch] SEA", 2); 
        }

        return match;
    }

    void Register() {
        if (RoleConfigs::Get(AiRole::SEA) !is null) return;
        RoleConfig@ cfg = RoleConfig(AiRole::SEA, cast<MainUpdateDelegate@>(@Sea_MainUpdate));

        @cfg.InitHandler = cast<InitDelegate@>(@Sea_Init);

        @cfg.AiIsSwitchTimeHandler = cast<AiIsSwitchTimeDelegate@>(@Sea_AiIsSwitchTime);
        @cfg.AiIsSwitchAllowedHandler = cast<AiIsSwitchAllowedDelegate@>(@Sea_AiIsSwitchAllowed);
        @cfg.MakeSwitchIntervalHandler = cast<MakeSwitchIntervalDelegate@>(@Sea_MakeSwitchInterval);

        @cfg.BuilderAiUnitAdded = cast<AiUnitAddedDelegate@>(@Sea_BuilderAiUnitAdded);
        @cfg.BuilderAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Sea_BuilderAiUnitRemoved);

        @cfg.BuilderAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Sea_BuilderAiMakeTask);
        @cfg.FactoryAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Sea_FactoryAiMakeTask);

        @cfg.BuilderAiTaskAddedHandler = cast<AiTaskAddedDelegate@>(@Sea_BuilderAiTaskAdded);
        @cfg.BuilderAiTaskRemovedHandler = cast<AiTaskRemovedDelegate@>(@Sea_BuilderAiTaskRemoved);

        @cfg.SelectFactoryHandler = cast<SelectFactoryDelegate@>(@Sea_SelectFactoryHandler);
        @cfg.EconomyUpdateHandler = cast<EconomyUpdateDelegate@>(@Sea_EconomyUpdate);
       

        @cfg.RoleMatchHandler = cast<RoleMatchDelegate@>(@Sea_RoleMatch);
        
        RoleConfigs::Register(cfg);
    }
}