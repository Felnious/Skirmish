// role: FRONT_TECH
#include "../helpers/unit_helpers.as"
#include "../helpers/unitdef_helpers.as"
#include "../helpers/economy_helpers.as"
#include "../helpers/guard_helpers.as"
#include "../types/role_config.as"
#include "../global.as"
#include "../types/terrain.as"
#include "../helpers/objective_helpers.as"

namespace RoleFrontTech {

    /******************************************************************************

    INITIALIZATION

    ******************************************************************************/

    void FrontTech_Init() {
        GenericHelpers::LogUtil("FrontTech role initialization logic executed", 2);

        // Apply FRONT_TECH role settings
        aiTerrainMgr.SetAllyZoneRange(Global::RoleSettings::FrontTech::AllyRange);
        // Change scout cap (unit count)
        aiMilitaryMgr.quota.scout = Global::RoleSettings::FrontTech::MilitaryScoutCap;

        // Change attack gate (power threshold, not a headcount)
        aiMilitaryMgr.quota.attack = Global::RoleSettings::FrontTech::MilitaryAttackThreshold;

        // Change raid thresholds (power)
        aiMilitaryMgr.quota.raid.min = Global::RoleSettings::FrontTech::MilitaryRaidMinPower; 
        aiMilitaryMgr.quota.raid.avg = Global::RoleSettings::FrontTech::MilitaryRaidAvgPower; 

        FrontTech_ApplyStartLimits();

        // Log all strategic objectives with distance from start
        ObjectiveHelpers::LogAllObjectivesFromStart(AiRole::FRONT_TECH, "FRONT_TECH");
    }

    void FrontTech_ApplyStartLimits() {
        dictionary startLimits; 

        startLimits.set("armap", 0);
        startLimits.set("corap", 0);
        startLimits.set("legap", 0);

        startLimits.set("armsilo", 0);
        startLimits.set("corsilo", 0);
        startLimits.set("legsilo", 0);
        
        startLimits.set("armrectr", 5);
        startLimits.set("cornecro", 5);

        RoleLimitHelpers::DisableT1Combat(startLimits, Global::AISettings::Side);

        UnitHelpers::ApplyUnitLimits(startLimits);

        GenericHelpers::LogUtil("FrontTech start limits applied", 3);
    }

    /******************************************************************************

    MAIN HOOKS

    ******************************************************************************/

    void FrontTech_MainUpdate() {
        //LogUtil("FrontTech update logic executed", 5);
    }

    /******************************************************************************

    ECONOMY HOOKS

    ******************************************************************************/

    void FrontTech_EconomyUpdate() {
        // Apply income-based unit caps similar to TECH
    float metalIncome = aiEconomyMgr.metal.income;
        FrontTech_IncomeBuilderLimits(metalIncome);
    }

    /******************************************************************************

    FACTORY HOOKS

    ******************************************************************************/

    string FrontTech_SelectFactoryHandler(const AIFloat3& in pos, bool isStart, bool isReset) {
        if(isStart) {
            if(Global::Map::NearestMapStartPosition !is null) {
                return FactoryHelpers::SelectStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            } else {
                GenericHelpers::LogUtil("[FrontTech_SelectFactoryHandler] nearestMapPosition is null", 2);
                return FactoryHelpers::GetFallbackStartFactoryForRole(Global::AISettings::Role, Global::AISettings::Side);
            }
        }

        return "";
    } 

    // Factory unit lifecycle hooks (FrontTech role)
    void FrontTech_FactoryAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        if (unit is null) {
            GenericHelpers::LogUtil("[FRONT_TECH] FactoryAiUnitAdded: unit=<null>", 2);
            return;
        }

        if (usage != Unit::UseAs::FACTORY)
		return;

        const CCircuitDef@ facDef = unit.circuitDef;
        if (Factory::userData[facDef.id].attr & Factory::Attr::T3 != 0) {
            array<string> spam = {"armpw", "corak", "armflea", "armfav", "corfav"};
            for (uint i = 0; i < spam.length(); ++i)
                ai.GetCircuitDef(spam[i]).SetIgnore(true);
        }

        GenericHelpers::LogUtil("[FRONT_TECH] FactoryAiUnitAdded id=" + unit.id + " usage=" + usage, 3);
    }

    void FrontTech_FactoryAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
    {
        //GenericHelpers::LogUtil("[FRONT_TECH] FactoryAiUnitRemoved id=" + (unit is null ? -1 : unit.id) + " usage=" + usage, 3);
        // No FrontTech-specific cleanup required; Factory manager handles primaries/anchors.
    }

    bool FrontTech_AiIsSwitchTime(int lastSwitchFrame) {
        int interval = (30 * SECOND);
        return (lastSwitchFrame + interval) <= ai.frame;
    }

    bool FrontTech_AiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 0.4f * facDef.costM * float(factoryCount)) || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }

    int FrontTech_MakeSwitchInterval() {
        return AiRandom(Global::RoleSettings::Front::MinAiSwitchTime, Global::RoleSettings::Front::MaxAiSwitchTime) * SECOND;
    }

    /******************************************************************************

    MILITARY HOOKS

    ******************************************************************************/
    

    /******************************************************************************

    BUILDER HOOKS

    ******************************************************************************/ 

    IUnitTask@ FrontTech_BuilderAiMakeTask(CCircuitUnit@ u) {
        GenericHelpers::LogUtil("[FrontTech_BuilderAiMakeTask] called for builder", 3);
        if (u is null) return null; // Defensive; expected non-null

        // Pre-create and cache a default task instance; never recreate inside this function.
        IUnitTask@ defaultTask = Builder::MakeDefaultTaskWithLog(u.id, "FRONT_TECH");

        const CCircuitDef@ udef = u.circuitDef;
        if (udef is null) return defaultTask;

        // If the default task is a BUILDER and its build type is MEX/MEXUP/GEO/GEOUP, don't override it; return immediately.
        if (defaultTask !is null && defaultTask.GetType() == Task::Type::BUILDER) {
            Task::BuildType dbt = Task::BuildType(defaultTask.GetBuildType());
            if (dbt == Task::BuildType::MEX || dbt == Task::BuildType::MEXUP
                || dbt == Task::BuildType::GEO || dbt == Task::BuildType::GEOUP) {
                GenericHelpers::LogUtil("[FRONT_TECH] defaultTask is MEX/MEXUP/GEO/GEOUP; returning early", 3);
                return defaultTask;
            }
        }

        // Route T1 bot constructors to FrontTech logic; others may guard or fall back
        int ctorTier = UnitHelpers::GetConstructorTier(udef);
        if (ctorTier == 1) {
            if (u is Builder::primaryT1BotConstructor || u is Builder::secondaryT1BotConstructor) {
                return FrontTech_T1Constructor_AiMakeTask(u, defaultTask);
            } else {
                string key = "" + u.id;
                CCircuitUnit@ tmp = null;
                if (Builder::primaryT1BotConstructor !is null
                    && Builder::primaryT1BotConstructor.id != u.id
                    && Builder::primaryT1BotConstructorGuards.get(key, @tmp)) {
                    return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT1BotConstructor, Task::Priority::HIGH, true, 200 * SECOND);
                }
                @tmp = null;
                if (Builder::secondaryT1BotConstructor !is null
                    && Builder::secondaryT1BotConstructor.id != u.id
                    && Builder::secondaryT1BotConstructorGuards.get(key, @tmp)) {
                    return GuardHelpers::AssignWorkerGuard(u, Builder::secondaryT1BotConstructor, Task::Priority::HIGH, true, 200 * SECOND);
                }
            }
        }
        // Fallback to cached default task
        return defaultTask;
    }

    CCircuitUnit@ energizer1 = null;
	CCircuitUnit@ energizer2 = null;

    void FrontTech_BuilderAiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
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

    void FrontTech_BuilderAiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		if (energizer1 is unit)
			@energizer1 = null;
		else if (energizer2 is unit)
			@energizer2 = null;
	}

    void FrontTech_BuilderAiTaskAdded(IUnitTask@ task) {
            GenericHelpers::LogUtil("[FrontTech_BuilderAiTaskAdded] called for task", 3);
    }

    void FrontTech_BuilderAiTaskRemoved(IUnitTask@ task, bool done) {

    }

    /******************************************************************************

    BUILDER LOGIC

    ******************************************************************************/ 

    IUnitTask@ FrontTech_T1Constructor_AiMakeTask(CCircuitUnit@ u, IUnitTask@ defaultTask) {
        // Econ snapshot
    float mi = aiEconomyMgr.metal.income;
    float ei = aiEconomyMgr.energy.income;
        bool stall = aiEconomyMgr.isEnergyStalling;
        bool isEnergyFull = aiEconomyMgr.isEnergyFull;

        AIFloat3 conLocation = u.GetPos(ai.frame);
        string unitSide = UnitHelpers::GetSideForUnitName(u.circuitDef.GetName());

        // Primary constructor branch
        if (u is Builder::primaryT1BotConstructor) {
            int t2ConstructionBotCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2BotConstructors());
            int t2LabCount = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetAllT2BotLabs());

            // Try T2 lab if eco allows
            bool shouldT2Lab = EconomyHelpers::ShouldBuildT2BotLab(
                /*mi*/ mi,
                /*ei*/ ei,
                /*metalCurrent*/ aiEconomyMgr.metal.current,
                /*requiredMetalIncome*/ Global::RoleSettings::FrontTech::MinimumMetalIncomeForT2Lab,
                /*requiredMetalCurrent*/ Global::RoleSettings::FrontTech::RequiredMetalCurrentForT2Lab,
                /*requiredEnergyIncome*/ Global::RoleSettings::FrontTech::MinimumEnergyIncomeForT2Lab,
                /*constructorDef*/ u.circuitDef,
                /*t2BotLabCount*/ t2LabCount,
                /*maxAllowed*/ Global::RoleSettings::FrontTech::MaxT2BotLabs,
                /*hasPrimaryFactory*/ (Factory::primaryT1BotLab !is null)
            );
            if (shouldT2Lab) {
                IUnitTask@ tLab = Builder::EnqueueT2LabIfNeeded(unitSide, Factory::GetT2BotLabPos(), SQUARE_SIZE * 20, SECOND * 300);
                if (tLab !is null) return tLab;
            }

            // Energy converter via shared economy helper with FrontTech thresholds
            if (EconomyHelpers::ShouldBuildT1EnergyConverter(
                /*metalIncome*/ mi,
                /*energyIncome*/ ei,
                /*energyCurrent*/ aiEconomyMgr.energy.current,
                /*energyStorage*/ aiEconomyMgr.energy.storage,
                /*untilMetalIncome*/ Global::RoleSettings::FrontTech::BuildT1ConvertersUntilMetalIncome,
                /*minEnergyIncome*/ Global::RoleSettings::FrontTech::BuildT1ConvertersMinimumEnergyIncome,
                /*minEnergyCurrentPercent*/ Global::RoleSettings::FrontTech::BuildT1ConvertersMinimumEnergyCurrentPercent
            )) {
                IUnitTask@ tConv = Builder::EnqueueT1EnergyConverter(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tConv !is null) return tConv;
            }

            // Basic solar
            if (EconomyHelpers::ShouldBuildT1Solar(
                /*energyIncome*/ ei,
                /*minEnergyIncome*/ Global::RoleSettings::FrontTech::SolarEnergyIncomeMinimum
            )) {
                IUnitTask@ tSolar = Builder::EnqueueT1Solar(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tSolar !is null) return tSolar;
            }

            // Build a T1 nano caretaker if income-based target or reserves-based condition is met
            float energyPercent = (aiEconomyMgr.energy.storage > 0.0f)
                ? (aiEconomyMgr.energy.current / aiEconomyMgr.energy.storage)
                : 0.0f;
            // Only build nanos if we have a preferred factory to anchor around
            if (Factory::GetPreferredFactory() !is null && EconomyHelpers::ShouldBuildT1Nano(
                ei,
                mi,
                Global::RoleSettings::FrontTech::NanoEnergyPerUnit,
                Global::RoleSettings::FrontTech::NanoMetalPerUnit,
                Global::RoleSettings::FrontTech::NanoMaxCount,
                aiEconomyMgr.metal.current,
                Global::RoleSettings::FrontTech::NanoBuildWhenOverMetal,
                energyPercent
            )) {
                // Centralized selection with per-factory nano caps and prioritization
                CCircuitUnit@ targetFactory = Factory::SelectFactoryNeedingNano();
                if (targetFactory !is null) {
                    IUnitTask@ tNano = Factory::EnqueueNanoForFactory(targetFactory, Task::Priority::NORMAL);
                    if (tNano !is null) return tNano;
                }
            }

            // Advanced solar with FrontTech thresholds and T2 gating (unified helper)
            if (EconomyHelpers::ShouldBuildT1AdvancedSolar(
                /*energyIncome*/ ei,
                /*metalIncome*/ mi,
                /*energyIncomeMinimumThreshold*/ Global::RoleSettings::FrontTech::AdvancedSolarEnergyIncomeMinimum,
                /*energyIncomeMaximumThreshold*/ Global::RoleSettings::FrontTech::AdvancedSolarEnergyIncomeMaximum,
                /*t2ConstructorCount*/ t2ConstructionBotCount,
                /*t2FactoryCount*/ t2LabCount,
                /*isT2FactoryQueued*/ Factory::IsT2LabBuildQueued(),
                /*enableT2ProgressGate*/ true,
                /*metalIncomeFallbackMinimum*/ 6.0f
            )) {
                IUnitTask@ tAdvSolar = Builder::EnqueueT1AdvancedSolar(unitSide, conLocation, SQUARE_SIZE * 32, SECOND * 30);
                if (tAdvSolar !is null) return tAdvSolar;
            }

            // If a T2 constructor exists, assist it briefly
            if (Builder::primaryT2BotConstructor !is null) {
                return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT2BotConstructor, Task::Priority::HIGH, true, 120 * SECOND);
            }
        }
        else if (u is Builder::secondaryT1BotConstructor) {
            // Optional: specialize recycle here if desired, currently no-op
            if (EconomyHelpers::ShouldSecondaryT1AssistPrimary(
                /*metalIncome*/ mi,
                /*threshold*/ Global::RoleSettings::FrontTech::SecondaryT1AssistMetalIncomeMax
            )) {
                return GuardHelpers::AssignWorkerGuard(u, Builder::primaryT1BotConstructor, Task::Priority::HIGH, true, 20 * SECOND);
            }
        }

    return defaultTask;
    }

    /******************************************************************************

    ECONOMY LOGIC

    ******************************************************************************/ 

    void FrontTech_IncomeBuilderLimits(float metalIncome) {
        // Determine and apply caps for T1/T2 land builders based on economy, honoring FrontTech hard caps
        string side = Global::AISettings::Side;

        // T1 builder cap via economic helper; honor min and global max
        int t1BuilderCap = EconomyHelpers::CalculateT1BuilderCap(
            /*metalIncome*/ metalIncome,
            /*minCap*/ 5,
            /*maxCap*/ Global::RoleSettings::FrontTech::MaxT1Builders
        );
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetT1LandBuilders(side), t1BuilderCap);

        // T2 builder cap via economic helper; honor min and global max
        int t2BuilderCap = EconomyHelpers::CalculateT2BuilderCap(
            /*metalIncome*/ metalIncome,
            /*minCap*/ 3,
            /*maxCap*/ Global::RoleSettings::FrontTech::MaxT2Builders
        );
        UnitHelpers::BatchApplyUnitCaps(UnitHelpers::GetT2LandBuilders(side), t2BuilderCap);

        // Re-apply merged map+role unit limits so map constraints always prevail
        if (Global::Map::MergedUnitLimits.getKeys().length() > 0) {
            GenericHelpers::LogUtil("[FRONT_TECH][Limits] Re-applying merged map+role unit limits (economy update)", 4);
            UnitHelpers::ApplyUnitLimits(Global::Map::MergedUnitLimits);
        }
    }

    /******************************************************************************

    ROLE CONFIGURATION

    ******************************************************************************/

    bool FrontTech_RoleMatch(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        bool match = false;

        if (preferredMapRole == AiRole::FRONT_TECH) match = true;

        if (match) { 
            GenericHelpers::LogUtil("[RoleMatch] FRONT_TECH", 2); 
        }
  
        return match;
    }

    void Register() {
        if (RoleConfigs::Get(AiRole::FRONT_TECH) !is null) return;
        RoleConfig@ cfg = RoleConfig(AiRole::FRONT_TECH, cast<MainUpdateDelegate@>(@FrontTech_MainUpdate));

        @cfg.InitHandler = cast<InitDelegate@>(@FrontTech_Init);

        @cfg.AiIsSwitchTimeHandler = cast<AiIsSwitchTimeDelegate@>(@FrontTech_AiIsSwitchTime);
        @cfg.AiIsSwitchAllowedHandler = cast<AiIsSwitchAllowedDelegate@>(@FrontTech_AiIsSwitchAllowed);
        @cfg.MakeSwitchIntervalHandler = cast<MakeSwitchIntervalDelegate@>(@FrontTech_MakeSwitchInterval);

        @cfg.BuilderAiMakeTaskHandler = cast<AiMakeTaskDelegate@>(@FrontTech_BuilderAiMakeTask);

        @cfg.BuilderAiUnitAdded = cast<AiUnitAddedDelegate@>(@FrontTech_BuilderAiUnitAdded);
        @cfg.BuilderAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@FrontTech_BuilderAiUnitRemoved);

        @cfg.BuilderAiTaskAddedHandler = cast<AiTaskAddedDelegate@>(@FrontTech_BuilderAiTaskAdded);
        @cfg.BuilderAiTaskRemovedHandler = cast<AiTaskRemovedDelegate@>(@FrontTech_BuilderAiTaskRemoved);

        @cfg.SelectFactoryHandler = cast<SelectFactoryDelegate@>(@FrontTech_SelectFactoryHandler);
        @cfg.EconomyUpdateHandler = cast<EconomyUpdateDelegate@>(@FrontTech_EconomyUpdate);
        @cfg.FactoryAiUnitAdded = cast<AiUnitAddedDelegate@>(@FrontTech_FactoryAiUnitAdded);
        @cfg.FactoryAiUnitRemoved = cast<AiUnitRemovedDelegate@>(@FrontTech_FactoryAiUnitRemoved);
            

        @cfg.RoleMatchHandler = cast<RoleMatchDelegate@>(@FrontTech_RoleMatch);

        //RoleLimitHelpers::DisableT1Combat(cfg.UnitMaxOverrides, side);
        RoleConfigs::Register(cfg);
    }
}