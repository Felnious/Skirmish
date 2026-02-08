// role: FRONT
#include "../types/role_config.as"
#include "../helpers/unit_helpers.as"
#include "../helpers/factory_helpers.as"
#include "../helpers/economy_helpers.as"
#include "../helpers/guard_helpers.as"
#include "../helpers/unitdef_helpers.as"
#include "../helpers/objective_helpers.as"
#include "../helpers/role_limit_helpers.as"
#include "../global.as"
#include "../types/terrain.as"
// Builder state and helpers for enqueueing structures like nanos
#include "../manager/builder.as"

namespace RoleFront {

    /******************************************************************************

    INITIALIZATION

    ******************************************************************************/

    void Front_Init() {
        GenericHelpers::LogUtil("Front role initialization logic executed", 2);

        // Apply FRONT role settings
        aiTerrainMgr.SetAllyZoneRange(Global::RoleSettings::Front::AllyRange);

        // FRONT-only: Set default fire state for all T1 combat units to 3 (fire at everything)
        // Note: 2 = fire at will, 3 = fire at everything
        array<string> t1Combat = UnitHelpers::GetAllT1CombatUnits();
        for (uint i = 0; i < t1Combat.length(); ++i) {
            CCircuitDef@ d = ai.GetCircuitDef(t1Combat[i]);
            if (d is null) continue;
            // Best-effort: if engine exposes fire-state setter, apply it
            // TODO: If SetFireState is not available, consider moving this to behaviour config for this profile only.
            d.SetFireState(3);
        }

        // Default to bot thresholds in Front init
        aiMilitaryMgr.quota.scout = Global::RoleSettings::Front::MilitaryScoutCapBots;
        aiMilitaryMgr.quota.attack = Global::RoleSettings::Front::MilitaryAttackThresholdBots;
        aiMilitaryMgr.quota.raid.min = Global::RoleSettings::Front::MilitaryRaidMinPowerBots; 
        aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::Front::MilitaryRaidAvgPowerBots; 
        g_frontVehicleThresholdsApplied = false;

        Front_ApplyStartLimits();

        // Log all strategic objectives with distance from start
        ObjectiveHelpers::LogAllObjectivesFromStart(AiRole::FRONT, "FRONT");
    }

    void Front_ApplyStartLimits() {
        dictionary startLimits; 

        startLimits.set("armrectr", 10);
        startLimits.set("cornecro", 10);

        startLimits.set("armap", 0);
        startLimits.set("corap", 0);
        startLimits.set("legap", 0);

        startLimits.set("armsilo", 0);
        startLimits.set("corsilo", 0);
        startLimits.set("legsilo", 0);

        UnitHelpers::ApplyUnitLimits(startLimits);

        GenericHelpers::LogUtil("Front start limits applied", 3);
    }

    /******************************************************************************

    MAIN HOOKS

    ******************************************************************************/

    void Front_MainUpdate() {

    }

    /******************************************************************************

    ECONOMY HOOKS

    ******************************************************************************/

    void Front_EconomyUpdate() {
    float metalIncome = aiEconomyMgr.metal.income;
        Front_IncomeLimits(metalIncome);
    }

    /******************************************************************************

    FACTORY HOOKS

    ******************************************************************************/

    // Track if vehicle thresholds have been applied (to avoid reapplying repeatedly)
    bool g_frontVehicleThresholdsApplied = false;

    // One-time scout rush state for the very first T1 land factory (bot or vehicle)
    bool g_frontScoutRushFinished = false;
    int g_frontScoutRushFactoryId = -1;

    // Attempt to enqueue a scout for the one-time scout rush from the first T1 land factory.
    // Returns a task if a scout was enqueued, otherwise null.
    IUnitTask@ Front_TryScoutRush(CCircuitUnit@ u, const string &in factoryName, const string &in side)
    {
        if (u is null) return null;
        if (g_frontScoutRushFinished) return null;
        if (!UnitHelpers::IsT1BotLab(factoryName) && !UnitHelpers::IsT1VehicleLab(factoryName)) return null;

        // Lock to the first T1 land factory encountered
        if (g_frontScoutRushFactoryId == -1) {
            g_frontScoutRushFactoryId = u.id;
            GenericHelpers::LogUtil("[FRONT] ScoutRush locked to factory id=" + g_frontScoutRushFactoryId + " (" + factoryName + ")", 2);
        }
        if (u.id != g_frontScoutRushFactoryId) return null; // only the locked factory performs the rush

        int target = Global::RoleSettings::Front::ScoutRushCount;
        if (target <= 0) { g_frontScoutRushFinished = true; return null; }

        string scoutName = UnitHelpers::GetFrontT1ScoutForFactory(factoryName, side);
        if (scoutName == "") { g_frontScoutRushFinished = true; return null; }

        CCircuitDef@ sdef = ai.GetCircuitDef(scoutName);
        if (sdef is null || !sdef.IsAvailable(ai.frame)) {
            // If unavailable, complete rush to avoid perpetual attempts
            g_frontScoutRushFinished = true;
            return null;
        }

        const AIFloat3 pos = u.GetPos(ai.frame);
        IUnitTask@ last = null;
        for (int i = 0; i < target; ++i) {
            @last = aiFactoryMgr.Enqueue(
                TaskS::Recruit(Task::RecruitType::FIREPOWER, Task::Priority::HIGH, sdef, pos, 64.f)
            );
        }
        g_frontScoutRushFinished = true;
        GenericHelpers::LogUtil("[FRONT] ScoutRush enqueued count=" + target, 2);
        return last;
    }

    // Ensure T1 labs recruit a minimum number of constructors
    // - T1 Bot Lab: at least 2 T1 bot constructors (ck)
    // - T1 Vehicle Plant: at least 2 T1 vehicle constructors (cv)
    IUnitTask@ Front_FactoryAiMakeTask(CCircuitUnit@ u)
    {
        if (u is null) return aiFactoryMgr.DefaultMakeTask(u);
        const CCircuitDef@ facDef = u.circuitDef;
        if (facDef is null) return aiFactoryMgr.DefaultMakeTask(u);

        string factoryName = facDef.GetName();
        string side = UnitHelpers::GetSideForUnitName(factoryName);

        // T1 Bot Lab enforcement
        if (UnitHelpers::IsT1BotLab(factoryName)) {
            array<string> botConstructorNames = UnitHelpers::GetT1BotConstructors(side);
            if (botConstructorNames.length() > 0) {
                string botConstructorName = botConstructorNames[0];
                int existingBotConstructors = UnitDefHelpers::GetUnitDefCount(botConstructorName);
                if (existingBotConstructors < Global::RoleSettings::Front::MinT1BotConstructorCount) {
                    CCircuitDef@ ctorDef = ai.GetCircuitDef(botConstructorName);
                    if (ctorDef !is null && ctorDef.IsAvailable(ai.frame)) {
                        const AIFloat3 pos = u.GetPos(ai.frame);
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, ctorDef, pos, 64.f)
                        );
                    }
                }
            }

            // After constructor enforcement, try one-time scout rush for T1 bot lab
            IUnitTask@ rushTask = Front_TryScoutRush(u, factoryName, side);
            if (rushTask !is null) return rushTask;
        }

        // T1 Vehicle Plant enforcement
        if (UnitHelpers::IsT1VehicleLab(factoryName)) {
            array<string> vehicleConstructorNames = UnitHelpers::GetT1VehicleConstructors(side);
            if (vehicleConstructorNames.length() > 0) {
                string vehicleConstructorName = vehicleConstructorNames[0];
                int existingVehicleConstructors = UnitDefHelpers::GetUnitDefCount(vehicleConstructorName);
                if (existingVehicleConstructors < Global::RoleSettings::Front::MinT1VehicleConstructorCount) {
                    CCircuitDef@ vdef = ai.GetCircuitDef(vehicleConstructorName);
                    if (vdef !is null && vdef.IsAvailable(ai.frame)) {
                        const AIFloat3 pos2 = u.GetPos(ai.frame);
                        return aiFactoryMgr.Enqueue(
                            TaskS::Recruit(Task::RecruitType::BUILDPOWER, Task::Priority::HIGH, vdef, pos2, 64.f)
                        );
                    }
                }
            }

            // After constructor enforcement, try one-time scout rush for T1 vehicle plant
            IUnitTask@ rushTask2 = Front_TryScoutRush(u, factoryName, side);
            if (rushTask2 !is null) return rushTask2;
        }

        // Fall back to default when no rule triggers
        return aiFactoryMgr.DefaultMakeTask(u);
    }

    string Front_SelectFactoryHandler(const AIFloat3& in pos, bool isStart, bool isReset) {
        if(isStart) {
            if(Global::Map::NearestMapStartPosition !is null) {
                return FactoryHelpers::SelectStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            } else {
                GenericHelpers::LogUtil("[Front_SelectFactoryHandler] nearestMapPosition is null", 2);
                return FactoryHelpers::GetFallbackStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            }
        }
   
        return "";
    }

    // Factory unit lifecycle hooks (Front role)
    void Front_FactoryAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        if (unit is null) {
            GenericHelpers::LogUtil("[FRONT] FactoryAiUnitAdded: unit=<null>", 2);
            return;
        }

        if (usage != Unit::UseAs::FACTORY)
		return;

        const CCircuitDef@ facDef = unit.circuitDef;
        string factoryName = (facDef is null ? "" : facDef.GetName());

        // If we build a vehicle lab at any point, switch to vehicle thresholds
        if (!g_frontVehicleThresholdsApplied && factoryName != "" && UnitHelpers::IsT1VehicleLab(factoryName)) {
            aiMilitaryMgr.quota.scout = Global::RoleSettings::Front::MilitaryScoutCapVehicles;
            aiMilitaryMgr.quota.attack = Global::RoleSettings::Front::MilitaryAttackThresholdVehicles;
            aiMilitaryMgr.quota.raid.min = Global::RoleSettings::Front::MilitaryRaidMinPowerVehicles;
            aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::Front::MilitaryRaidAvgPowerVehicles;
            g_frontVehicleThresholdsApplied = true;
            GenericHelpers::LogUtil("[FRONT] Vehicle lab built; applied vehicle raid/attack thresholds", 2);
        }
        if (Factory::userData[facDef.id].attr & Factory::Attr::T3 != 0) {
            array<string> spam = {"armpw", "corak", "armflea", "armfav", "corfav"};
            for (uint i = 0; i < spam.length(); ++i)
                ai.GetCircuitDef(spam[i]).SetIgnore(true);
        }

        GenericHelpers::LogUtil("[FRONT] FactoryAiUnitAdded id=" + unit.id + " usage=" + usage, 3);
        // Note: Factory registration and preferred anchors are centralized in Factory manager.
        // Front role currently has no additional per-factory behavior here.
    }

    void Front_FactoryAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        //GenericHelpers::LogUtil("[FRONT] FactoryAiUnitRemoved id=" + (unit is null ? -1 : unit.id) + " usage=" + usage, 3);
        // No Front-specific cleanup required; Factory manager handles primary/anchor clearing.
    }

    bool Front_AiIsSwitchTime(int lastSwitchFrame) {
        int interval = (30 * SECOND);
        return (lastSwitchFrame + interval) <= ai.frame;
    }

    bool Front_AiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 1.2f * facDef.costM * float(factoryCount)) || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }

    int Front_MakeSwitchInterval() {
        return AiRandom(Global::RoleSettings::Front::MinAiSwitchTime, Global::RoleSettings::Front::MaxAiSwitchTime) * SECOND;
    }

    /******************************************************************************

    MILITARY HOOKS

    ******************************************************************************/
    

    /******************************************************************************

    BUILDER HOOKS

    ******************************************************************************/ 

    IUnitTask@ Front_BuilderAiMakeTask(CCircuitUnit@ builder) {
        GenericHelpers::LogUtil("[Front_BuilderAiMakeTask] called for builder", 3);
        if (builder is null) return null; // Defensive check

        // Pre-create and cache a single default task instance; never recreate.
        IUnitTask@ defaultTask = Builder::MakeDefaultTaskWithLog(builder.id, "FRONT");

        const CCircuitDef@ udef = builder.circuitDef;
        if (udef is null) return defaultTask;

        // Early return: if the default task represents a resource expansion (MEX/GEO variants), keep it.
        if (defaultTask !is null && defaultTask.GetType() == Task::Type::BUILDER) {
            Task::BuildType dbt = Task::BuildType(defaultTask.GetBuildType());
            if (dbt == Task::BuildType::MEX || dbt == Task::BuildType::MEXUP ||
                dbt == Task::BuildType::GEO || dbt == Task::BuildType::GEOUP) {
                GenericHelpers::LogUtil("[FRONT] defaultTask is MEX/MEXUP/GEO/GEOUP; returning early", 3);
                return defaultTask;
            }
        }

        // Route T1 land constructors (bot or vehicle) to FRONT logic; others fallback
        int ctorTier = UnitHelpers::GetConstructorTier(udef);
        if (ctorTier == 1) {
            if (builder is Builder::primaryT1BotConstructor || builder is Builder::secondaryT1BotConstructor
             || builder is Builder::primaryT1VehConstructor || builder is Builder::secondaryT1VehConstructor) {
                // Use same economy snapshot style as T2: min over last 10s for incomes
                bool isEnergyFull = aiEconomyMgr.isEnergyFull;
                bool isEnergyStalling = aiEconomyMgr.isEnergyStalling;
                float metalIncome = Economy::GetMinMetalIncomeLast10s();
                float energyIncome = Economy::GetMinEnergyIncomeLast10s();
                return Front_T1Constructor_AiMakeTask(builder, defaultTask, metalIncome, energyIncome, isEnergyStalling, isEnergyFull);
            }
        } else if (ctorTier == 2) {
            // Mirror TECH role routing: handle primary/secondary T2 bot constructors explicitly
            bool isEnergyFull = aiEconomyMgr.isEnergyFull;
            float metalIncome = Economy::GetMinMetalIncomeLast10s();
            float energyIncome = Economy::GetMinEnergyIncomeLast10s();
            float metalCurrent = aiEconomyMgr.metal.current;
            bool isEnergyLessThan90Percent = aiEconomyMgr.energy.current < aiEconomyMgr.energy.storage * Global::RoleSettings::Tech::EnergyStorageLowPercent;
            if (builder is Builder::primaryT2BotConstructor || builder is Builder::secondaryT2BotConstructor || builder is Builder::freelanceT2BotConstructor) {
                return Front_T2Constructor_AiMakeTask(builder, defaultTask, isEnergyFull, metalIncome, energyIncome, metalCurrent, isEnergyLessThan90Percent);
            }
        }
        // Fallback to cached default task
        return defaultTask;
    }

    CCircuitUnit@ energizer1 = null;
	CCircuitUnit@ energizer2 = null;

    void Front_BuilderAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		//LogUtil("BUILDER::AiUnitAdded:" + unit.circuitDef, 2);
		const CCircuitDef@ cdef = unit.circuitDef;
		if (usage != Unit::UseAs::BUILDER || cdef.IsRoleAny(Unit::Role::COMM.mask))
			return;

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

    void Front_BuilderAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		if (energizer1 is unit)
			@energizer1 = null;
		else if (energizer2 is unit)
			@energizer2 = null;
	}

    void Front_BuilderAiTaskAdded(IUnitTask@ task) {
        GenericHelpers::LogUtil("[Front_BuilderAiTaskAdded] called for task", 3);
    }

    void Front_BuilderAiTaskRemoved(IUnitTask@ task, bool done) {

    }

    /******************************************************************************

    ECONOMY LOGIC

    ******************************************************************************/ 

    void Front_IncomeLimits(float metalIncome) {
        // Determine cap: 35 metal income per lab (e.g., 70 -> 2 labs)
        int cap = int(metalIncome / 35.0f);

        // Scale Tier 2 bot/vehicle lab caps by economy: 35 metal income per lab
        Front_IncomeLabLimits(metalIncome);
        Front_IncomeBuilderLimits(metalIncome);

        //Always apply map limits, regardless of how eco changes labs limits
        dictionary mapLimits = Global::Map::Config.UnitLimits;
        UnitHelpers::ApplyUnitLimits(mapLimits);
    }

    void Front_IncomeLabLimits(float metalIncome) {
        // Determine cap: 45 metal income per lab (e.g., 90 -> 2 labs)
        int landLabCap = int(metalIncome / 45.0f);

        string side = Global::AISettings::Side;
        array<string> labs;
        if (side == "armada") {
            labs = { "armalab", "armavp" };
        } else if (side == "cortex") {
            labs = { "coralab", "coravp" };
        } else if (side == "legion") {
            labs = { "legalab", "legavp" };
        } else {
            labs = { "armalab", "armavp", "coralab", "coravp", "legalab", "legavp" };
        }

        UnitHelpers::BatchApplyUnitCaps(labs, landLabCap);

        array<string> gantries = { "armshltx", "armshltxuw", "corgant", "corgantuw", "leggant", "legapt3" };
        if(metalIncome >= 250.0f) {
            UnitHelpers::BatchApplyUnitCaps(gantries, 1);
        } else {
            UnitHelpers::BatchApplyUnitCaps(gantries, 0);
        }

        //RoleLimitHelpers::GateGantriesByIncome(temp, side, 250.0f, 1);
    }

    void Front_IncomeBuilderLimits(float metalIncome) {
        // Determine cap: 35 metal income per lab (e.g., 70 -> 2 labs)
        int t1BuilderCap = 5 * int(metalIncome / 20.0f);
        if (t1BuilderCap < 5) t1BuilderCap = 5;

        string side = Global::AISettings::Side;
        array<string> t1Builders;
        if (side == "armada") {
            t1Builders = { "armck", "armcv" };
        } else if (side == "cortex") {
            t1Builders = { "corck", "corcv" };
        } else if (side == "legion") {
            t1Builders = { "legck", "legcv" };
        } else {
            t1Builders = { "armck", "armcv", "corck", "corcv", "legck", "legcv" };
        }

        UnitHelpers::BatchApplyUnitCaps(t1Builders, t1BuilderCap);

        //T2 Builder Cap Logic
        int t2BuilderCap = 5 * int(metalIncome / 40.0f);
        if (t2BuilderCap < 5) t2BuilderCap = 5;

        array<string> t2Builders;
        if (side == "armada") {
            t2Builders = { "armack", "armacv" };
        } else if (side == "cortex") {
            t2Builders = { "corack", "coracv" };
        } else if (side == "legion") {
            t2Builders = { "legack", "legacv" };
        } else {
            t2Builders = { "armack", "armavp", "corack", "coracv", "legack", "legacv" };
        }

        UnitHelpers::BatchApplyUnitCaps(t2Builders, t2BuilderCap);
    }

    /******************************************************************************

    BUILDER LOGIC

    ******************************************************************************/ 

    IUnitTask@ Front_T1Constructor_AiMakeTask(CCircuitUnit@ u, IUnitTask@ defaultTask, float metalIncome, float energyIncome, bool isEnergyStalling, bool isEnergyFull) {
        // Econ snapshot is passed by caller (min over last 10s for incomes)

        AIFloat3 conLocation = u.GetPos(ai.frame);
        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());

        // Primary constructor branch (Bots)
        if (u is Builder::primaryT1BotConstructor) {
            int t2ConstructionBotCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2BotConstructors());
            int t2LabCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2BotLabs());

            // Fast-track: if we have zero T2 bot labs and ANY trigger is met, build a T2 Bot Lab now.
            // Triggers (OR):
            //  1) metal income >= configured threshold
            //  2) game time >= 22 minutes
            //  3) stored metal >= T2 bot lab cost
            if (t2LabCount < 1) {
                const float incomeTrigger = Global::RoleSettings::Front::MinimumMetalIncomeForFirstT2Lab;
                const bool timeTriggerMet = (ai.frame >= (22 * 60 * SECOND));
                const bool incomeTriggerMet = (metalIncome >= incomeTrigger);
                // Resolve T2 lab cost for stored-metal trigger
                bool storedMetalTriggerMet = false;
                string t2LabName = UnitHelpers::GetT2BotLabForSide(unitSide);
                CCircuitDef@ t2LabDef = ai.GetCircuitDef(t2LabName);
                if (t2LabDef !is null) {
                    storedMetalTriggerMet = (aiEconomyMgr.metal.current >= t2LabDef.costM);
                }
                if (incomeTriggerMet || timeTriggerMet || storedMetalTriggerMet) {
                    AIFloat3 anchor2 = Factory::GetT1BotLabPos();
                    IUnitTask@ t2b = Builder::EnqueueT2LabIfNeeded(unitSide, anchor2, SQUARE_SIZE * 30, SECOND * 300);
                    if (t2b !is null) return t2b;
                }
            }

            // Try T2 lab if eco allows
            bool shouldT2Lab = EconomyHelpers::ShouldBuildT2BotLab(
                /*mi*/ metalIncome,
                /*ei*/ energyIncome,
                /*metalCurrent*/ aiEconomyMgr.metal.current,
                /*requiredMetalIncome*/ Global::RoleSettings::Front::MinimumMetalIncomeForT2Lab,
                /*requiredMetalCurrent*/ Global::RoleSettings::Front::RequiredMetalCurrentForT2Lab,
                /*requiredEnergyIncome*/ Global::RoleSettings::Front::MinimumEnergyIncomeForT2Lab,
                /*constructorDef*/ u.circuitDef,
                /*t2BotLabCount*/ t2LabCount,
                /*maxAllowed*/ Global::RoleSettings::Front::MaxT2BotLabs,
                /*hasPrimaryFactory*/ (Factory::primaryT1BotLab !is null)
            );

            if (shouldT2Lab) {
                // Place near our T1 Bot Lab (or commander fallback via Factory)
                AIFloat3 anchor = Factory::GetT1BotLabPos();
                IUnitTask@ tLab = Builder::EnqueueT2LabIfNeeded(unitSide, anchor, SQUARE_SIZE * 30, SECOND * 300);
                if (tLab !is null) return tLab;
            }

            // After T2 lab attempt: build a T1 nano caretaker when reserves allow
            // Route through centralized per-factory nano selection and enqueue helpers
            {
                float energyPercent = (aiEconomyMgr.energy.storage > 0.0f)
                    ? (aiEconomyMgr.energy.current / aiEconomyMgr.energy.storage)
                    : 0.0f;
                if (EconomyHelpers::ShouldBuildT1Nano_ByReserves(
                    /*metalCurrent*/ aiEconomyMgr.metal.current,
                    /*buildWhenOverMetal*/ 500.0f,
                    /*energyPercent*/ energyPercent
                )) {
                    CCircuitUnit@ targetFactory = Factory::SelectFactoryNeedingNano();
                    if (targetFactory !is null) {
                        IUnitTask@ tNano = Factory::EnqueueNanoForFactory(targetFactory, Task::Priority::HIGH);
                        if (tNano !is null) return tNano;
                    }
                }
            }

        }

        // Primary constructor branch (Vehicles)
        if (u is Builder::primaryT1VehConstructor) {
            int t2VehLabCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2VehicleLabs());
            // Fast-track first T2 vehicle plant via centralized builder helper
            if (t2VehLabCount < 1 && metalIncome >= Global::RoleSettings::Front::MinimumMetalIncomeForFirstT2Lab && Builder::IsT2VehFactoryOffCooldown()) {
                IUnitTask@ tVeh2 = Builder::EnqueueT2VehiclePlant(Global::AISettings::Side, Factory::GetPreferredFactoryPos(), SQUARE_SIZE * 24, 600 * SECOND);
                if (tVeh2 !is null) return tVeh2;
            }
            // No special vehicle-only eco tasks for now; default
            return defaultTask;
        }

    return defaultTask;
    }

    IUnitTask@ Front_T2Constructor_AiMakeTask(CCircuitUnit@ u, IUnitTask@ defaultTask, bool isEnergyFull, float metalIncome, float energyIncome, float metalCurrent, bool isEnergyLessThan90Percent) {
        // Copy of TECH T2 constructor logic with Front-specific gating:
        // - Before 20 minutes of game time, force eco: only build energy converter/AFUS/FUS (skip gantry/nuke/anti-nuke)
        // - After 20 minutes, allow full TECH-style sequence (gantry, nuke, anti-nuke, etc.)

        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());

        // Freelance T2 constructors just do default tasks
        if (u is Builder::freelanceT2BotConstructor) {
            return defaultTask;
        }

        const bool isPrimary = (u is Builder::primaryT2BotConstructor || u is Builder::primaryT2VehConstructor);
        const bool isSecondary = (u is Builder::secondaryT2BotConstructor);

        AIFloat3 anchor = Factory::GetT2BotLabPos();

        // Eco gating: force economy builds for the first 20 minutes
        const bool forceEco = (ai.frame < (20 * 60 * SECOND));

        if (isPrimary) {
            // Fusion Reactor
            if (EconomyHelpers::ShouldBuildFusionReactor(
                /*mi*/ metalIncome,
                /*ei*/ energyIncome,
                /*energy<90%*/ isEnergyLessThan90Percent,
                /*reqMi*/ Global::RoleSettings::Tech::MinimumMetalIncomeForFUS,
                /*reqEi*/ Global::RoleSettings::Tech::MinimumEnergyIncomeForFUS,
                /*maxEi*/ Global::RoleSettings::Tech::MaxEnergyIncomeForFUS
            )) {
                IUnitTask@ tFus2 = Builder::EnqueueFUS(unitSide, anchor, SQUARE_SIZE * 32, SECOND * 300);
                if (tFus2 !is null) return tFus2;
            }
        } 

        return defaultTask;
    }

    /******************************************************************************

    ROLE CONFIGURATION

    ******************************************************************************/

    bool Front_RoleMatch(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        bool match = false;

        if (preferredMapRole == AiRole::FRONT) match = true;
       
        if (match) { 
            GenericHelpers::LogUtil("[RoleMatch] FRONT", 2); 
        }

        return match;
    }

    void Register() {
        if (RoleConfigs::Get(AiRole::FRONT) !is null) return; // already
        RoleConfig@ cfg = RoleConfig(AiRole::FRONT, cast<MainUpdateDelegate@>(@Front_MainUpdate));

        @cfg.InitHandler = cast<InitDelegate@>(@Front_Init);
       
        @cfg.AiIsSwitchTimeHandler = cast<AiIsSwitchTimeDelegate@>(@Front_AiIsSwitchTime);
        @cfg.AiIsSwitchAllowedHandler = cast<AiIsSwitchAllowedDelegate@>(@Front_AiIsSwitchAllowed);
        @cfg.MakeSwitchIntervalHandler = cast<MakeSwitchIntervalDelegate@>(@Front_MakeSwitchInterval);

        @cfg.BuilderAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Front_BuilderAiMakeTask);
        @cfg.FactoryAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@Front_FactoryAiMakeTask);

        @cfg.BuilderAiUnitAdded = cast<AiUnitAddedDelegate@>(@Front_BuilderAiUnitAdded);
        @cfg.BuilderAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Front_BuilderAiUnitRemoved);

        @cfg.BuilderAiTaskAddedHandler = cast<AiTaskAddedDelegate@>(@Front_BuilderAiTaskAdded);
        @cfg.BuilderAiTaskRemovedHandler = cast<AiTaskRemovedDelegate@>(@Front_BuilderAiTaskRemoved);

        @cfg.EconomyUpdateHandler = cast<EconomyUpdateDelegate@>(@Front_EconomyUpdate);
       
        @cfg.SelectFactoryHandler = cast<SelectFactoryDelegate@>(@Front_SelectFactoryHandler);
        @cfg.FactoryAiUnitAdded = cast<AiUnitAddedDelegate@>(@Front_FactoryAiUnitAdded);
        @cfg.FactoryAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@Front_FactoryAiUnitRemoved);

        @cfg.RoleMatchHandler = cast<RoleMatchDelegate@>(@Front_RoleMatch);

        RoleConfigs::Register(cfg);
    }
}