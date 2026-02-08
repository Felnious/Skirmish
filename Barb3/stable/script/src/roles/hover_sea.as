// role: HOVER_SEA
#include "../helpers/unit_helpers.as"
#include "../types/role_config.as"
#include "../helpers/economy_helpers.as"
#include "../global.as"
#include "../types/terrain.as"
#include "../helpers/objective_helpers.as"
#include "../helpers/objective_executor.as"
#include "../types/strategic_objectives.as"

namespace RoleHoverSea {

    /******************************************************************************

    INITIALIZATION

    ******************************************************************************/

    void HoverSea_Init() {
        GenericHelpers::LogUtil("HoverSea role initialization logic executed", 2);

        // Apply HOVER_SEA role settings
        aiTerrainMgr.SetAllyZoneRange(Global::RoleSettings::HoverSea::AllyRange);
        // Change scout cap (unit count)
        aiMilitaryMgr.quota.scout = Global::RoleSettings::HoverSea::MilitaryScoutCap;

        // Change attack gate (power threshold, not a headcount)
        aiMilitaryMgr.quota.attack = Global::RoleSettings::HoverSea::MilitaryAttackThreshold;

        // Change raid thresholds (power)
        aiMilitaryMgr.quota.raid.min = Global::RoleSettings::HoverSea::MilitaryRaidMinPower; 
        aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::HoverSea::MilitaryRaidAvgPower; 

        HoverSea_ApplyStartLimits();

        // HOVER_SEA-only: Set default fire state for T1 HOVER combat units to 3 (fire at everything),
        // mirroring FRONT role behavior but scoped to hover units so they aggressively shoot walls/obstacles.
        // Note: 2 = fire at will, 3 = fire at everything
        {
            array<string> t1Combat = UnitHelpers::GetAllT1HoverCombatUnits();
            for (uint i = 0; i < t1Combat.length(); ++i) {
                CCircuitDef@ d = ai.GetCircuitDef(t1Combat[i]);
                if (d is null) continue;
                d.SetFireState(3);
            }
            GenericHelpers::LogUtil("[HOVER_SEA] Applied default fire state=3 to T1 HOVER combat units", 3);
        }

        // Log all strategic objectives with distance from start once at init
        ObjectiveHelpers::LogAllObjectivesFromStart(AiRole::HOVER_SEA, "HOVER_SEA");

        // At init, find and log matching objectives for this role (no assignment)
        ObjectiveHelpers::LogMatchingObjectivesForRole(
            AiRole::HOVER_SEA,
            "HOVER_SEA",
            Global::AISettings::Side,
            Objectives::ConstructorClass::HOVER,
            Global::Map::StartPos,
            ai.frame,
            5
        );

        // Select initial objectives per group for hover T1
        HoverSea_SelectObjectiveForGroup(Objectives::BuilderGroup::TACTICAL);

        // Enable tactical constructor for HoverSea role
        Builder::SetTacticalEnabled(true);
    }

    void HoverSea_ApplyStartLimits() {
        
        // ****************** LAB LIMITS ****************** //
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT1BotLabs(), Global::RoleSettings::HoverSea::StartCapT1BotLabs);
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT2BotLabs(), Global::RoleSettings::HoverSea::StartCapT2BotLabs);

        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT1VehicleLabs(), Global::RoleSettings::HoverSea::StartCapT1VehiclePlants);

        // ****************** Aircraft Plant LIMITS ****************** //
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT1AircraftPlants(), Global::RoleSettings::HoverSea::StartCapT1AircraftPlants);
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT2AircraftPlants(), Global::RoleSettings::HoverSea::StartCapT2AircraftPlants);

        // ****************** Shipyard LIMITS ****************** //
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT1Shipyards(), Global::RoleSettings::HoverSea::StartCapT1Shipyards);
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetAllT2Shipyards(), Global::RoleSettings::HoverSea::StartCapT2Shipyards);

        GenericHelpers::LogUtil("HoverSea start limits applied", 3);
    }

    /******************************************************************************

    MAIN HOOKS

    ******************************************************************************/
 
    void HoverSea_MainUpdate() {
        // MainUpdate: no periodic objective scanning (performance). Selection occurs at Init.
    }

    /******************************************************************************

    ECONOMY HOOKS

    ******************************************************************************/

    void HoverSea_EconomyUpdate() {
        // No hover_sea-specific economy adjustments yet
    }

    /******************************************************************************

    FACTORY HOOKS

    ******************************************************************************/

    IUnitTask@ HoverSea_FactoryAiMakeTask(CCircuitUnit@ u)
    {
        // Single null/def guard to avoid repeated checks
        const CCircuitDef@ facDef = (u is null ? null : u.circuitDef);
        if (facDef is null) {
            return aiFactoryMgr.DefaultMakeTask(u);
        }

        const string facName = facDef.GetName();
        const string side = UnitHelpers::GetSideForUnitName(facName);

        // First: ensure a baseline of T2 vehicle construction capability.
        // If this is a T2 Vehicle Plant and we have zero T2 vehicle constructors for our side,
        // enqueue the side-specific T2 vehicle constructor (armacv/coracv/legacv).
        if (UnitHelpers::IsT2VehicleLab(facName)) {
            string vehCtor = (side == "armada" ? "armacv" : (side == "cortex" ? "coracv" : "legacv"));
            int haveVehCtors = UnitDefHelpers::GetUnitDefCount(vehCtor);
            if (haveVehCtors < 1) {
                CCircuitDef@ ctorDef = ai.GetCircuitDef(vehCtor);
                if (ctorDef !is null && ctorDef.IsAvailable(ai.frame)) {
                    const AIFloat3 pos = u.GetPos(ai.frame);
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, ctorDef, pos, 64.f)
                    );
                }
            }
        }

        // Only enforce for hover plants; fall back to role/default otherwise
        bool isHoverPlant = UnitHelpers::IsT1HoverPlant(facName) || UnitHelpers::IsFloatingHoverPlant(facName);
        if (isHoverPlant) {
            string hoverCtorName = UnitHelpers::GetT1HoverConstructor(side);
            int haveHoverCtors = UnitDefHelpers::GetUnitDefCount(hoverCtorName);
            if (haveHoverCtors < Global::RoleSettings::HoverSea::MinHoverConstructorCount) {
                CCircuitDef@ ctorDef2 = ai.GetCircuitDef(hoverCtorName);
                if (ctorDef2 !is null && ctorDef2.IsAvailable(ai.frame)) {
                    const AIFloat3 pos2 = u.GetPos(ai.frame);
                    return aiFactoryMgr.Enqueue(
                        TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, ctorDef2, pos2, 64.f)
                    );
                }
            }
        }

        // No special case triggered, use default factory make task
        return aiFactoryMgr.DefaultMakeTask(u);
    }

    string HoverSea_SelectFactoryHandler(const AIFloat3& in pos, bool isStart, bool isReset) {
        if (isStart) {
            // Explicitly start with a land hover plant for HOVER_SEA role to avoid bot labs
            string side = Global::AISettings::Side;
            string hoverFac = UnitHelpers::GetT1HoverPlantForSide(side); // armhp/corhp/leghp

            if (hoverFac.length() > 0) {
                GenericHelpers::LogUtil("[HoverSea][SelectFactory] Start: choosing land hover plant '" + hoverFac + "' (side=" + side + ")", 2);
                return hoverFac;
            }

            // As a last resort, defer to generic role-based selection
            if (Global::Map::NearestMapStartPosition !is null) {
                GenericHelpers::LogUtil("[HoverSea][SelectFactory] WARNING: hover plant unresolved; deferring to role-based selector", 2);
                return FactoryHelpers::SelectStartFactoryForRole(Global::AISettings::Role, side);
            } else {
                GenericHelpers::LogUtil("[HoverSea_SelectFactoryHandler] nearestMapPosition is null; using generic fallback selector", 2);
                return FactoryHelpers::GetFallbackStartFactoryForRole(Global::AISettings::Role, side);
            }
        }

        return "";
    }

    bool HoverSea_AiIsSwitchTime(int lastSwitchFrame) {
        int interval = (30 * SECOND);
        return (lastSwitchFrame + interval) <= ai.frame;
    }

    bool HoverSea_AiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 1.2f * facDef.costM * float(factoryCount)) || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }

    int HoverSea_MakeSwitchInterval() {
        return AiRandom(Global::RoleSettings::Sea::MinAiSwitchTime, Global::RoleSettings::Sea::MaxAiSwitchTime) * SECOND;
    }

    /******************************************************************************

    MILITARY HOOKS

    ******************************************************************************/
    
    bool HoverSea_AiIsAirValid() {
        //GenericHelpers::LogUtil("[HoverSea] Enter HoverSea_AiIsAirValid", 4);
        return true;
    }


    /******************************************************************************

    BUILDER HOOKS

    ******************************************************************************/ 

    void HoverSea_BuilderAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
	{

	}

    void HoverSea_BuilderAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{

	}

    IUnitTask@ HoverSea_BuilderAiMakeTask(CCircuitUnit@ builder) {
        GenericHelpers::LogUtil("[HoverSea_BuilderAiMakeTask] called for builder", 3);
    // Create default task only at return sites via Builder helper (no pre-creation)
        // Try builder-group objectives first in order: TACTICAL -> PRIMARY -> SECONDARY
        CCircuitUnit@ tactical = Builder::GetTacticalConstructor();
        if (tactical !is null && builder is tactical) {
            // if(Builder::currentTacticalObjective !is null) {
            //     return null;
            // }
            IUnitTask@ t = HoverSea_TryHandleObjective(builder, Objectives::BuilderGroup::TACTICAL);
            if (t !is null) return t;

            return Builder::MakeDefaultTaskWithLog(builder.id, "HOVER_SEA");
        }

        if (builder is Builder::primaryT1HoverConstructor) {
            IUnitTask@ t1 = HoverSea_TryHandleObjective(builder, Objectives::BuilderGroup::PRIMARY);
            if (t1 !is null) return t1;
            // After objectives, consider advancing to vehicles when economy supports it.
            // Build a T2 Vehicle Lab at 25+ metal income using preferred factory placement.
            {
                float mi = aiEconomyMgr.metal.income;
                // Enforce single plant and avoid duplicate queueing
                int t2VehCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2VehicleLabs());
                bool queued = Factory::IsT2VehPlantBuildQueued();
                if (EconomyHelpers::ShouldBuildAdvancedVehiclePlant(
                    mi,
                    /*requiredMetalIncome*/ Global::RoleSettings::HoverSea::RequiredMetalIncomeForT2VehiclePlant,
                    t2VehCount,
                    /*maxAllowed*/ 1,
                    queued
                )) {
                    string side = Global::AISettings::Side;
                    string labName = (side == "armada" ? "armavp" : (side == "cortex" ? "coravp" : (side == "legion" ? "legavp" : "armavp")));
                    CCircuitDef@ labDef = ai.GetCircuitDef(labName);
                    if (labDef !is null && labDef.IsAvailable(ai.frame)) {
                        AIFloat3 pos = Factory::GetPreferredFactoryPos();
                        return aiBuilderMgr.Enqueue(
                            TaskB::Factory(Task::Priority::NOW, labDef, pos, labDef, /*shake*/ SQUARE_SIZE * 24, /*active*/ false, /*mustBeBuilt*/ true, /*timeout*/ 600 * SECOND)
                        );
                    }
                }
            }

            // Income-scaled Hover Plant expansion: 1 base + 1 per 50 metal income
            // Place near preferred factory. Prefer land hover plant; fallback to floating variant if needed.
            {
                float mi2 = aiEconomyMgr.metal.income;
                // Allow 1 base plant + one per income step; clamp to configured maximum
                const float step = Global::RoleSettings::HoverSea::MetalIncomePerExtraHoverPlant;
                int allowedHoverPlants = 1 + int(step > 0.0f ? (mi2 / step) : 0);
                const int maxHoverPlants = Global::RoleSettings::HoverSea::MaxHoverPlants;
                if (allowedHoverPlants > maxHoverPlants) { allowedHoverPlants = maxHoverPlants; }

                int t1HoverCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT1HoverPlants());
                int floatHoverCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllFloatingHoverPlants());
                int totalHoverPlants = t1HoverCount + floatHoverCount;

                if (totalHoverPlants < allowedHoverPlants) {
                    string side2 = Global::AISettings::Side;
                    AIFloat3 pos2 = Factory::GetPreferredFactoryPos();

                    // Try land hover plant first via builder helper (90s cooldown)
                    IUnitTask@ thp = Builder::EnqueueT1HoverPlant(side2, pos2, /*shake*/ SQUARE_SIZE * 24, /*timeout*/ 600 * SECOND, Task::Priority::NOW);
                    if (thp !is null) return thp;

                    // Fallback to floating hover plant (shares cooldown)
                    IUnitTask@ tfhp = Builder::EnqueueFloatingHoverPlant(side2, pos2, /*shake*/ SQUARE_SIZE * 24, /*timeout*/ 600 * SECOND, Task::Priority::NOW);
                    if (tfhp !is null) return tfhp;
                }
            }
            // Fallback: simple eco structures if no objective was actionable
            return HoverSea_FallbackEcoTask(builder);
        }

        if (builder is Builder::secondaryT1HoverConstructor) {
            IUnitTask@ t2 = HoverSea_TryHandleObjective(builder, Objectives::BuilderGroup::SECONDARY);
            if (t2 !is null) return t2;
            // Secondary fallback: assist primary if energy is very low, else default
            Objectives::StrategicObjective@ secObj = ObjectiveManager::GetSelectedForGroup(AiRole::HOVER_SEA, Objectives::BuilderGroup::SECONDARY);
            bool pending = _HoverSea_HasPendingChain(secObj, Global::AISettings::Side);
            if (!pending && aiEconomyMgr.energy.income < Global::RoleSettings::Sea::AssistPrimaryWorkerEnergyIncomeMinimum) {
                return GuardHelpers::AssignWorkerGuard(builder, Builder::primaryT1HoverConstructor, Task::Priority::HIGH, true, 160 * SECOND);
            }
        }

    // Fallback to default with logging
    return Builder::MakeDefaultTaskWithLog(builder.id, "HOVER_SEA");
    }

    void HoverSea_BuilderAiTaskAdded(IUnitTask@ task) {
        GenericHelpers::LogUtil("[HoverSea_BuilderAiTaskAdded] called for task", 3);
    }

    void HoverSea_BuilderAiTaskRemoved(IUnitTask@ task, bool done) {

    }


    /******************************************************************************

    BUILDER LOGIC

    ******************************************************************************/

    IUnitTask@ HoverSea_FallbackEcoTask(CCircuitUnit@ builder)
    {
        if (builder is null || builder.circuitDef is null) return null;
        float mi = aiEconomyMgr.metal.income;
        float ei = aiEconomyMgr.energy.income;
        bool isEnergyFull = aiEconomyMgr.isEnergyFull;
        AIFloat3 pos = builder.GetPos(ai.frame);
        string side = UnitHelpers::GetSideForUnitName(builder.circuitDef.GetName());

        // Energy converter first if needed
        if (isEnergyFull && mi >= 1.0f && ei < Global::RoleSettings::Sea::TidalEnergyIncomeMinimum) {
            IUnitTask@ tConv = Builder::EnqueueT1EnergyConverter(side, pos, SQUARE_SIZE * 32, SECOND * 30);
            if (tConv !is null) return tConv;
        }

        // Nano caretaker: income-based OR reserves-based
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
            AIFloat3 nanoPos = Factory::GetPreferredFactoryPos();
            IUnitTask@ tNano = Builder::EnqueueT1Nano(side, nanoPos, /*shake*/ SQUARE_SIZE * 16, /*timeout*/ 30);
            if (tNano !is null) return tNano;
        }

        // Prefer advanced solar when within HoverSea thresholds; otherwise fallback to basic solar if energy remains low
        if (EconomyHelpers::ShouldBuildT1AdvancedSolar(
            /*energyIncome*/ ei,
            /*metalIncome*/ mi,
            /*energyIncomeMinimumThreshold*/ Global::RoleSettings::HoverSea::AdvancedSolarEnergyIncomeMinimum,
            /*energyIncomeMaximumThreshold*/ Global::RoleSettings::HoverSea::AdvancedSolarEnergyIncomeMaximum,
            /*t2ConstructorCount*/ 0,
            /*t2FactoryCount*/ 0,
            /*isT2FactoryQueued*/ false,
            /*enableT2ProgressGate*/ false,
            /*metalIncomeFallbackMinimum*/ 6.0f
        )) {
            IUnitTask@ tAdv = Builder::EnqueueT1AdvancedSolar(side, pos, SQUARE_SIZE * 32, SECOND * 30);
            if (tAdv !is null) return tAdv;
        } else if (EconomyHelpers::ShouldBuildT1Solar(
            /*energyIncome*/ ei,
            /*minEnergyIncome*/ Global::RoleSettings::HoverSea::SolarEnergyIncomeMinimum
        )) {
            IUnitTask@ tSolar = Builder::EnqueueT1Solar(side, pos, SQUARE_SIZE * 32, SECOND * 30);
            if (tSolar !is null) return tSolar;
        }
        return null;
    }

    /******************************************************************************

    OBJECTIVES

    ******************************************************************************/

    // Objectives are assigned on MakeTask time; store per-group references here
    // Stored tactical objective for this role (selected once; may be refreshed if invalid)
    Objectives::StrategicObjective@ tacticalObjective = null;
    // Track per-group objectives to allow PRIMARY and SECONDARY to also act on strategic objectives
    Objectives::StrategicObjective@ primaryObjective = null;
    Objectives::StrategicObjective@ secondaryObjective = null;

    // Return true if the objective has at least one eco-satisfied step with remaining count
    bool _HoverSea_HasPendingChain(const Objectives::StrategicObjective@ currentObjective, const string &in side)
    {
        if (currentObjective is null || currentObjective.steps.length() == 0) return false;
        for (uint i = 0; i < currentObjective.steps.length(); ++i) {
            auto@ s = currentObjective.steps[i]; if (s is null) continue;
            if (!ObjectiveHelpers::StepEcoSatisfied(s)) continue;
            string unitName = UnitHelpers::GetObjectiveUnitNameForSide(side, s.type);
            if (unitName.length() == 0) continue;
            int q = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, unitName);
            if (q < s.count) return true;
        }
        return false;
    }

    void HoverSea_SelectObjectiveForGroup(Objectives::BuilderGroup group)
    {
        string side = Global::AISettings::Side;
        const AIFloat3 ref = Global::Map::StartPos;
        array<Objectives::StrategicObjective@> candidates = ObjectiveHelpers::Find(
            AiRole::HOVER_SEA, side, Objectives::ConstructorClass::HOVER, 1, ref, ai.frame, group
        );
        string label = ObjectiveManager::GetBuilderGroupLabel(group);
        if (candidates.length() > 0) {
            Objectives::StrategicObjective@ chosen = candidates[0];
            ObjectiveManager::SetSelectedForGroup(AiRole::HOVER_SEA, group, chosen);
            float d = ObjectiveHelpers::DistanceFrom(ref, chosen);
            GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] selected id=" + chosen.id + " prio=" + chosen.priority + " d=" + d, 2);
        } else {
            ObjectiveManager::SetSelectedForGroup(AiRole::HOVER_SEA, group, null);
            GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] no objective candidates found", 2);
        }
    }

    // Back-compat wrapper used earlier
    void HoverSea_SelectTacticalObjective() { HoverSea_SelectObjectiveForGroup(Objectives::BuilderGroup::TACTICAL); }

    IUnitTask@ HoverSea_TryHandleObjective(CCircuitUnit@ builder, Objectives::BuilderGroup group)
    {
        // 1) Acquire or refresh the objective for the group
        Objectives::StrategicObjective@ currentObjective = _HoverSea_GetOrRefreshObjective(group);
        string label = ObjectiveManager::GetBuilderGroupLabel(group);
        if (currentObjective is null || ObjectiveHelpers::IsAssigned(currentObjective.id)) return null;

        GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Handling objective '" + currentObjective.id + "'", 2);
            // 2) Execute chain steps first if present (shared logic)
        if (currentObjective.steps.length() > 0) {
            string sideC = Global::AISettings::Side;
            AIFloat3 anchorC = ObjectiveHelpers::PreferredBuildPos(currentObjective, builder.GetPos(ai.frame));

            GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Attempting to execute chain step for objective '" + currentObjective.id + "'", 2);

            IUnitTask@ chainTask = ObjectiveExecutor::ExecuteNextChainStep(currentObjective, sideC, anchorC, "HoverSea_" + label);
            if (chainTask !is null) return chainTask;
        }

        // All single-step logic is now handled via ObjectiveExecutor; no local first-type handling

        GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Objective not handled'" + currentObjective.id, 2);

        // // 4) Gather common context
        // string side = Global::AISettings::Side;
        // AIFloat3 pos = ObjectiveHelpers::PreferredBuildPos(currentObjective, builder.GetPos(ai.frame));
        // GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Evaluating objective '" + currentObjective.id + "' type=" + int(t) + " at (" + currentObjective.pos.x + "," + currentObjective.pos.z + ")", 2);

        // 5) Seaplane factory and sensors are handled centrally by ObjectiveExecutor
        // Shared standard executor for first-type handling
        return null;
        //return ObjectiveExecutor::ExecuteFirstTypeStep(currentObjective, side, pos, "HoverSea_" + label);
    }

    // Acquire the current objective for a group; refresh if missing or completed
    Objectives::StrategicObjective@ _HoverSea_GetOrRefreshObjective(Objectives::BuilderGroup group)
    {
        Objectives::StrategicObjective@ currentObjective = ObjectiveManager::GetSelectedForGroup(AiRole::HOVER_SEA, group);
        if (currentObjective is null || ObjectiveHelpers::IsCompleted(currentObjective.id)) {
            HoverSea_SelectObjectiveForGroup(group);
            @currentObjective = ObjectiveManager::GetSelectedForGroup(AiRole::HOVER_SEA, group);
        }
        return currentObjective;
    }

    // Try to get the first actionable type on the objective
    bool _HoverSea_TryGetNextType(Objectives::StrategicObjective@ currentObjective, Objectives::BuildingType &out t)
    {
        if (currentObjective is null) return false;
        if (!ObjectiveHelpers::HasAnyTypes(currentObjective)) return false;
        t = ObjectiveHelpers::GetFirstType(currentObjective);
        return true;
    }

    // Handle seaplane platform step with assignment and queued count management
    IUnitTask@ _HoverSea_TryHandleSeaplaneFactory(Objectives::StrategicObjective@ currentObjective, const string &in label, const string &in side, const AIFloat3 &in pos)
    {
        string platName = UnitHelpers::GetSeaplanePlatformNameForSide(side);
        int alreadyQueued = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, platName);
        if (alreadyQueued > 0) return null; // ensure only one platform
        string token = "HoverSea_" + label + "_SEAPLANE";
        if (!ObjectiveHelpers::TryAssign(currentObjective.id, token)) return null;
        IUnitTask@ tFac = Builder::EnqueueSeaplanePlatform(side, pos, SQUARE_SIZE * 24, 600 * SECOND);
        if (tFac is null) { ObjectiveHelpers::Unassign(currentObjective.id); return null; }
        ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, platName, 1);
        ObjectiveHelpers::Unassign(currentObjective.id);
        GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Enqueued seaplane platform '" + platName + "' for objective '" + currentObjective.id + "'", 2);
        return tFac;
    }

    // Handle standard defensive structure build based on objective type
    IUnitTask@ _HoverSea_TryHandleStandardBuild(Objectives::StrategicObjective@ currentObjective, const string &in label, const string &in side, const AIFloat3 &in pos, Objectives::BuildingType t)
    {
        string unitToBuild = _HoverSea_GetDefNameFor(side, t);
        if (unitToBuild.length() == 0) return null;

        CCircuitDef@ def = ai.GetCircuitDef(unitToBuild);
        if (def is null || !def.IsAvailable(ai.frame)) return null;

        string assignTag = "HoverSea_" + label;
        if (!ObjectiveHelpers::TryAssign(currentObjective.id, assignTag)) return null;

        Task::Priority prio = Task::Priority::NORMAL; // priority is now chain-driven
        Task::BuildType btype = ObjectiveExecutor::ResolveBuildTypeForStep(t);
        IUnitTask@ task = aiBuilderMgr.Enqueue(
            TaskB::Common(btype, prio, def, pos, /*shake*/ SQUARE_SIZE * 16, /*active*/ true, /*timeout*/ 800)
        );
        if (task is null) { ObjectiveHelpers::Unassign(currentObjective.id); return null; }
        ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, unitToBuild, 1);
        GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Enqueued '" + unitToBuild + "' for objective '" + currentObjective.id + "' at (" + pos.x + "," + pos.z + ")", 2);
        return task;
    }

    // Choose a build position for an objective: prefer explicit point; else first polyline point; else fallback
    AIFloat3 _HoverSea_GetObjectiveBuildPos(const Objectives::StrategicObjective@ objective, const AIFloat3 &in fallback)
    {
        if (objective is null) return fallback;
        if (objective.pos.x != 0.0f || objective.pos.z != 0.0f) return objective.pos;
        if (objective.line.length() > 0) return objective.line[0];
        return fallback;
    }

    // Minimal side->unit mapping for key defence types used by tactical objectives
    string _HoverSea_GetDefNameFor(const string &in side, Objectives::BuildingType t)
    {
        return UnitHelpers::GetObjectiveUnitNameForSide(side, t);
    }

    IUnitTask@ _HoverSea_TryExecuteChain(Objectives::StrategicObjective@ currentObjective, CCircuitUnit@ builder, const string &in label)
    {
        string side = Global::AISettings::Side;
        AIFloat3 anchor = _HoverSea_GetObjectiveBuildPos(currentObjective, builder.GetPos(ai.frame));
        // Before executing, check if all steps are satisfied; if so, complete the objective
        bool allSatisfied = true;
        bool hasStep = false;
        for (uint iCheck = 0; iCheck < currentObjective.steps.length(); ++iCheck) {
            auto@ sc = currentObjective.steps[iCheck]; if (sc is null) continue;
            hasStep = true;
            string unitCheck = UnitHelpers::GetObjectiveUnitNameForSide(side, sc.type);
            // For tidal, count via tidal unit name
            // All unit names now resolved via UnitHelpers for the new typed schema
            if (unitCheck.length() == 0) { allSatisfied = false; break; }
            int q = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, unitCheck);
            int b = ObjectiveHelpers::GetObjectiveBuildingsBuiltCount(currentObjective.id, unitCheck);
            int progress = (b > q ? b : q);
            if (progress < sc.count || !ObjectiveHelpers::StepEcoSatisfied(sc)) {
                allSatisfied = false;
                GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain check step " + iCheck + ": unit='" + unitCheck + "' progress=" + progress + "/" + sc.count + " ecoOK=" + ObjectiveHelpers::StepEcoSatisfied(sc), 3);
                break;
            }
        }
        if (hasStep && allSatisfied) {
            ObjectiveHelpers::Complete(currentObjective.id);
            GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Objective '" + currentObjective.id + "' chain completed", 2);
            return null;
        }

        // Find the next step (eco-satisfied) and whether remaining count exists by checking queued counts of resolved unit
        for (uint i = 0; i < currentObjective.steps.length(); ++i) {
            auto@ s = currentObjective.steps[i]; if (s is null) continue;
            if (!ObjectiveHelpers::StepEcoSatisfied(s)) continue;
            // Special step: TIDAL uses a dedicated helper and counts by tidal unit
            if (false) {
                string tidalName = UnitHelpers::GetTidalNameForSide(side);
                int tq = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, tidalName);
                if (tq >= s.count) continue;
                string tokenT = "HoverSea_" + label + "_STEP_" + i + "_TIDAL";
                if (!ObjectiveHelpers::TryAssign(currentObjective.id, tokenT)) continue;
                IUnitTask@ tTidal = Builder::EnqueueT1Tidal(side, anchor, SQUARE_SIZE * 32, SECOND * 30);
                if (tTidal is null) { ObjectiveHelpers::Unassign(currentObjective.id); continue; }
                ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, tidalName, 1);
                ObjectiveHelpers::Unassign(currentObjective.id);
                GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain step " + i + ": enqueued tidal for objective '" + currentObjective.id + "'", 2);
                return tTidal;
            }

            // Standard unit-based step
            string unitName = UnitHelpers::GetObjectiveUnitNameForSide(side, s.type);
            if (unitName.length() == 0) { GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain step " + i + ": unresolved unit for type=" + int(s.type), 3); continue; }
            int queued = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(currentObjective.id, unitName);
            int built = ObjectiveHelpers::GetObjectiveBuildingsBuiltCount(currentObjective.id, unitName);
            int progress = (built > queued ? built : queued);
            if (progress >= s.count) { GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain step " + i + ": already satisfied progress=" + progress + "/" + s.count, 4); continue; }
            // Enqueue this step
            CCircuitDef@ def = ai.GetCircuitDef(unitName);
            if (def is null || !def.IsAvailable(ai.frame)) continue;
            string token = "HoverSea_" + label + "_STEP_" + i;
            if (!ObjectiveHelpers::TryAssign(currentObjective.id, token)) continue;
            // Factory step uses Factory task for correct behavior
            if (s.type == Objectives::BuildingType::SEAPLANE_FACTORY) {
                float fshake = (currentObjective.radius > 0.0f ? currentObjective.radius : (SQUARE_SIZE * 32.0f));
                IUnitTask@ tFac = aiBuilderMgr.Enqueue(TaskB::Factory(Task::Priority::NOW, def, anchor, def, fshake, false, true, 600 * SECOND));
                if (tFac is null) { ObjectiveHelpers::Unassign(currentObjective.id); continue; }
                ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, unitName, 1);
                ObjectiveHelpers::Unassign(currentObjective.id);
                GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain step " + i + ": enqueued factory '" + unitName + "' for objective '" + currentObjective.id + "'", 2);
                return tFac;
            }

            Task::BuildType btype = ObjectiveExecutor::ResolveBuildTypeForStep(s.type);
            // Use objective radius as shake if provided to allow multiple placements within area
            float shake = (currentObjective.radius > 0.0f ? currentObjective.radius : (SQUARE_SIZE * 48.0f));
            IUnitTask@ task = aiBuilderMgr.Enqueue(
                TaskB::Common(btype, Task::Priority::NOW, def, anchor, /*shake*/ shake, /*active*/ true, /*timeout*/ 800)
            );
            if (task is null) { ObjectiveHelpers::Unassign(currentObjective.id); continue; }
            ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, unitName, 1);
            ObjectiveHelpers::Unassign(currentObjective.id);
            GenericHelpers::LogUtil("[HOVER_SEA][" + label + "] Chain step " + i + ": enqueued '" + unitName + "' (queued=" + queued + "/" + s.count + ") for objective '" + currentObjective.id + "'", 2);
            return task;
        }
        return null;
    }

    /******************************************************************************

    ROLE CONFIGURATION

    ******************************************************************************/

    bool HoverSea_RoleMatch(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        bool match = false;

        if (preferredMapRole == AiRole::HOVER_SEA) match = true;
     
        if (match) { 
            GenericHelpers::LogUtil("[RoleMatch] HOVER_SEA", 2); 
        }

        return match;
    }

    void Register() {
        if (RoleConfigs::Get(AiRole::HOVER_SEA) !is null) return;
        RoleConfig@ cfg = RoleConfig(AiRole::HOVER_SEA, cast<MainUpdateDelegate@>(@HoverSea_MainUpdate));

        @cfg.InitHandler = cast<InitDelegate@>(@HoverSea_Init);

        @cfg.AiIsSwitchTimeHandler = cast<AiIsSwitchTimeDelegate@>(@HoverSea_AiIsSwitchTime);
        @cfg.AiIsSwitchAllowedHandler = cast<AiIsSwitchAllowedDelegate@>(@HoverSea_AiIsSwitchAllowed);
        @cfg.MakeSwitchIntervalHandler = cast<MakeSwitchIntervalDelegate@>(@HoverSea_MakeSwitchInterval);

        @cfg.BuilderAiUnitAdded = cast<AiUnitAddedDelegate@>(@HoverSea_BuilderAiUnitAdded);
        @cfg.BuilderAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@HoverSea_BuilderAiUnitRemoved);

        @cfg.BuilderAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@HoverSea_BuilderAiMakeTask);
        @cfg.FactoryAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@HoverSea_FactoryAiMakeTask);

        @cfg.BuilderAiTaskAddedHandler = cast<AiTaskAddedDelegate@>(@HoverSea_BuilderAiTaskAdded);
        @cfg.BuilderAiTaskRemovedHandler = cast<AiTaskRemovedDelegate@>(@HoverSea_BuilderAiTaskRemoved);

        @cfg.SelectFactoryHandler = cast<SelectFactoryDelegate@>(@HoverSea_SelectFactoryHandler);
        @cfg.EconomyUpdateHandler = cast<EconomyUpdateDelegate@>(@HoverSea_EconomyUpdate);

        @cfg.AiIsAirValidHandler = cast<AiIsAirValidDelegate@>(@HoverSea_AiIsAirValid);

        @cfg.RoleMatchHandler = cast<RoleMatchDelegate@>(@HoverSea_RoleMatch);

        RoleConfigs::Register(cfg);
    }
}