#include "define.as"
// Strategies enum and helpers
#include "types/strategy.as"
//#include "types/profile.as"
#include "types/profile_controller.as"

namespace Global {

    namespace Map {
        StartSpot@ NearestMapStartPosition;

        // Commander start capture state (populated via Main::AiUnitAdded)
        bool HasStart = false;
        AIFloat3 StartPos(0,0,0);
        AiRole StartRole = AiRole::FRONT;
    
        const float BASE_RADIUS = 1400.0f; // tune
        

        bool MapResolved;
        string MapName;
        bool LandLocked;

        MapConfig Config;

        // Merged map + role unit limits for this game
        // Populated during Setup::setupMap via LimitsHelpers
        dictionary MergedUnitLimits;
    }

    namespace Economy {
        float MetalIncome = 0.0f;
	    float EnergyIncome = 0.0f;

        float MetalCurrent = 0.0f;
	    float EnergyCurrent = 0.0f;

        float MetalStorage = 0.0f;
	    float EnergyStorage = 0.0f;

        // Convenience accessors
        float GetMetalIncome() { return MetalIncome; }
        float GetEnergyIncome() { return EnergyIncome; }
    }

    namespace Lookups {
        dictionary LabTerrainDict = UnitHelpers::GetLabsTerrainDict();
    }

    namespace AISettings {
        AiRole Role;
        string Side; // faction side (armada/cortex/legion)
        string StartFactory;
        RoleConfig@ RoleCfg;
    }

    namespace Units {
        
    }

    namespace Tasks {
        dictionary queuedReclaimTasks;
    }

    namespace Statistics {
        int FactoriesBuilt = 0;
    }

    // Mod options pulled from engine/lobby; set during Setup::CheckModOptions
    namespace ModOptions {
        bool ExperimentalLegionFaction = false;
        int MapWaterLevel = 0;
        bool MapWaterIsLava = false;
        int MaxUnits = 0;
    }

	ProfileController profileController;

    dictionary mapConfigFactoryWeights;    

    // Role-specific overrideable variables in a dedicated namespace
    namespace RoleSettings {        
       

        // Max number of workers assigned as guards to a single leader (primary or secondary)
        // Applies to builder guard distribution logic (bots/veh/air/sea). Can be tuned per-profile.
        int BuilderMaxGuardsPerLeader = 10;

        // Max number of workers assigned as guards to a tactical constructor (per category)
        // Independent from primary/secondary caps. Default 0 disables tactical guarding.
        int BuilderMaxGuardsPerTacticalLeader = 0;

    // (moved below into specific role namespaces)

        namespace Tech {
            // Role switch cadence (seconds)
            int MinAiSwitchTime = 400;
            int MaxAiSwitchTime = 500;

            // NukeLimit: maximum number of nukes allowed for TECH role
            int NukeLimit = 20;

            /******************** TECH BASE SETTINGS ********************/
            // All settings applied to tech role at game start, logic can change throughout game
            float AllyRange = 1000.0f;

            /******************** TECH STRATEGY TOGGLES ********************/
            // Bitmask of enabled high-level strategies for TECH role.
            // Use Strategy enum values as bit indices. Multiple strategies can be enabled simultaneously.
            uint StrategyMask = 0;

            // Enable a strategy flag (wrapper forwards to StrategyUtil)
            void EnableStrategy(const Strategy s) { StrategyMask = StrategyUtil::Enable(StrategyMask, s); }

            // Disable a strategy flag (wrapper forwards to StrategyUtil)
            void DisableStrategy(const Strategy s) { StrategyMask = StrategyUtil::Disable(StrategyMask, s); }

            // Check if a strategy is enabled (wrapper forwards to StrategyUtil)
            bool HasStrategy(const Strategy s) { return StrategyUtil::Has(StrategyMask, s); }

            // Enable default TECH strategies (can be adjusted per-profile)
            void EnableDefaultStrategies() {
                EnableStrategy(Strategy::T2_RUSH);
                EnableStrategy(Strategy::T3_RUSH);
                EnableStrategy(Strategy::NUKE_RUSH);
            }

            // Legacy knob used across TECH logic for rush count; keep for compatibility.
            // Consider reconciling with strategies in future refactors.
            int NukeRush = 1;

            /******************** TECH MILITARY QUOTAS ********************/
            // Scout unit cap for TECH role
            int MilitaryScoutCap = 0;
            // Attack gate (required power to trigger attack waves)
            float MilitaryAttackThreshold = 1.0f;
            // Raid thresholds (power)
            float MilitaryRaidMinPower = 30.0f;
            float MilitaryRaidAvgPower = 30.0f;

            /******************** TECH ECONOMY SETTINGS ********************/
            //Minimum incomes levels before T2 bot lab will be built
            float MinimumMetalIncomeForT2Lab = 18.0f; 
            float MinimumEnergyIncomeForT2Lab = 600.0f;
            // Additional gating: require at least this much stored metal and cap total T2 bot labs
            float RequiredMetalCurrentForT2Lab = 1000.0f;
            int MaxT2BotLabs = 1;

            //Minimum incomes levels before normal Fusion will be built
            float MinimumMetalIncomeForFUS = 20.0f; 
            float MinimumEnergyIncomeForFUS = 700.0f;
            float MaxEnergyIncomeForFUS = 2000.0f;

            //Minimum incomes levels before Advanced Fusion will be built
            float MinimumMetalIncomeForAFUS = 70.0f; 
            float MinimumEnergyIncomeForAFUS = 2000.0f;

            //Continue building normal solars if ever below this energy income level
            float SolarEnergyIncomeMinimum = 160.0f; 

            //Stop building advanced solar if above this energy income level
            float AdvancedSolarEnergyIncomeMaximum = 1000.0f; 
            //Continue building advanced solars if ever below this energy income level
            float AdvancedSolarEnergyIncomeMinimum = 600.0f; 
            
            // Consider energy storage "low" when current < storage * percent
            float EnergyStorageLowPercent = 0.90f;

            // Radius used to consider mex-upgrade tasks "near base"
            float MexUpgradesNearBaseRadius = 400.0f;

            // Minimum energy income to allow assisting freelance T2 near mex upgrades
            float MexUpAssistMinEnergyIncome = 500.0f;

            // Minimum incomes for building advanced energy converter (moho maker)
            float MinimumMetalIncomeForAdvConverter = 18.0f;
            float MinimumEnergyIncomeForAdvConverter = 1200.0f;

            /******************** GANTRY THRESHOLDS ********************/
            // Income required per allowed Gantry (experimental superfactory)
            float MetalIncomePerGantry = 250.0f;
            float EnergyIncomePerGantry = 6000.0f;

            /******************** T2 BOT LAB THRESHOLDS (income-scaled) ********************/
            // Income required per allowed T2 Bot Lab (mirrors gantry logic). Allowed labs =
            // min(floor(mi / MetalIncomePerT2Lab), floor(ei / EnergyIncomePerT2Lab)), with a minimum of 1.
            // Defaults mirror legacy single-lab thresholds.
            float MetalIncomePerT2Lab = 100.0f;
            float EnergyIncomePerT2Lab = 1000.0f;

            /******************** TECH ECO PHASE THRESHOLDS ********************/
            // Metal income thresholds for bot-lab expansion behavior.
            // Default gate (affects both T1 and T2 expansion behaviors)
            float MetalIncomeThresholdForBotLabExpansion = 200.0f;
            // Early gate: used when the early-expansion strategy is enabled (formerly "rush")
            float MetalIncomeThresholdForEarlyBotLabExpansion = 100.0f; // TODO: tune per profile

            // T1 Energy converter policy (configurable thresholds)
            // Build converters while metal income is below this threshold
            float BuildT1ConvertersUntilMetalIncome = 18.0f;
            // Require at least this much energy income
            float BuildT1ConvertersMinimumEnergyIncome = 250.0f;
            // Require current energy to be at least this fraction of storage (e.g., 0.90 = 90%)
            float BuildT1ConvertersMinimumEnergyCurrentPercent = 0.90f;

            // If metal income is below this, secondary T2 will assist primary T2
            float SecondaryT2AssistMetalIncomeMax = 160.0f;

            /******************** AIRCRAFT PLANT THRESHOLDS ********************/
            // Economy thresholds for building aircraft plants (used by generic rules)
            float RequiredMetalIncomeForAirPlant = 60.0f;
            float RequiredMetalCurrentForAirPlant = 1000.0f;
            float RequiredEnergyIncomeForAirPlant = 2000.0f;

            // T2 Aircraft Plant thresholds (TECH role)
            // Mirrors AIR role defaults; scoped to TECH so roles don't cross-reference
            float RequiredMetalIncomeForT2AircraftPlant = 200.0f;
            float RequiredMetalCurrentForT2AircraftPlant = 1000.0f;
            float RequiredEnergyIncomeForT2AircraftPlant = 2000.0f;

            /******************** WORKFORCE MINIMUMS ********************/
            // Minimum desired numbers of constructor bots by tech tier
            int MinimumT1ConstructorBots = 2;
            int MinimumT2ConstructorBots = 1;

            /******************** BUILDER CAP LIMITS ********************/
            // Hard caps for T1/T2 land builders used when computing income-based limits
            int MaxT1Builders = 5;
            int MaxT2Builders = 5;

            /******************** TECH START LIMIT CAPS ********************/
            // Initial caps applied at game start for the TECH role
            int StartCapRezBots = 0;
            int StartCapFastAssistBots = 0;

            int StartCapT1BotLabs = 1;
            int StartCapT2BotLabs = 1;
            int StartCapT1VehiclePlants = 0;

            // Aircraft plants (separate in case behavior diverges later)
            int StartCapT1AircraftPlants = 0;
            int StartCapT2AircraftPlants = 0;

            // Max allowed aircraft plants for TECH policy
            int MaxT1AircraftPlants = 1;
            int MaxT2AircraftPlants = 1;

            // Air combat units (non-construction aircraft)
            int StartCapT1AirCombatUnits = 0;
            int StartCapT2AirCombatUnits = 0;

            // Shipyards (water)
            int StartCapT1Shipyards = 0;
            int StartCapT2Shipyards = 0;

            // Energy structures
            int StartCapT1Solar = 4;
            int StartCapFusionReactors = 0;
            int StartCapAdvancedFusionReactors = 0;

            // Combat unit caps at start (TECH role disables T1/T2 combat by default)
            int StartCapT1CombatUnits = 0;
            int StartCapT2CombatUnits = 0;

            /******************** AIR NANO POLICY ********************/
            // How much income per additional T1 nano caretaker; and cap
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 200;  
            // Reserves-based nano condition: build when metalCurrent >= threshold
            float NanoBuildWhenOverMetal = 1000.0f;


            /******************** NUCLEAR SILO THRESHOLDS ********************/
            // Separate economy thresholds for rush vs regular nuclear silo builds
            // Rush thresholds: used when rushing up to NukeRush silos
            float MinimumMetalIncomeForNukeRush = 50.0f;
            float MinimumEnergyIncomeForNukeRush = 2000.0f;
            // Regular thresholds: used for non-rush nuking policy
            float MinimumMetalIncomeForNuke = 600.0f;
            float MinimumEnergyIncomeForNuke = 10000.0f;
            
            /******************** ANTI-NUKE THRESHOLDS ********************/
            // Minimum economy thresholds to allow building anti-nuke defenses
            // and the minimum number of anti-nuke structures to maintain
            float MinimumMetalIncomeForAntiNuke = 80.0f;
            float MinimumEnergyIncomeForAntiNuke = 3000.0f;
            int MinimumAntiNukeCount = 1;
            // Income-scaling for anti-nukes: allowed count = floor(metalIncome / MetalIncomePerAntiNuke)
            float MetalIncomePerAntiNuke = 80.0f;
            
        }

        namespace Air {
            // Role switch cadence (seconds)
            int MinAiSwitchTime = 20;
            int MaxAiSwitchTime = 60;

            // NukeLimit: maximum number of nukes allowed for AIR role
            int NukeLimit = 0;
            /******************** AIR BASE SETTINGS ********************/
            // All settings applied to air role at game start, logic can change throughout game
            float AllyRange = 1600.0f;

            /******************** AIR MILITARY QUOTAS ********************/
            // Scout unit cap for AIR role
            int MilitaryScoutCap = 10;
            // Attack gate (required power to trigger attack waves)
            float MilitaryAttackThreshold = 40.0f;
            // Raid thresholds (power)
            float MilitaryRaidMinPower = 40.0f;
            float MilitaryRaidAvgPower = 80.0f;

            /******************** AIR ECONOMY SETTINGS ********************/
            // Mostly delegate economy to AI for air, but give it an early start

            //Continue building normal solars if ever below this energy income level
            float SolarEnergyIncomeMinimum = 160.0f; 

            // T1 Energy converter policy (Air-specific thresholds)
            // Build converters while metal income is below this threshold
            float BuildT1ConvertersUntilMetalIncome = 20.0f;
            // Require at least this much energy income
            float BuildT1ConvertersMinimumEnergyIncome = 250.0f;
            // Require current energy to be at least this fraction of storage (e.g., 0.90 = 90%)
            float BuildT1ConvertersMinimumEnergyCurrentPercent = 0.90f;

            //Continue building advanced solars if ever below this energy income level
            float AdvancedSolarEnergyIncomeMinimum = 1100.0f; 

            //Stop building advanced solar if above this energy income level
            float AdvancedSolarEnergyIncomeMaximum = 1200.0f; 

            float AssistPrimaryWorkerEnergyIncomeMinimum = 1000.0f;

            /******************** T2 AIRCRAFT PLANT THRESHOLDS (AIR role) ********************/
            // Economy thresholds and caps for building a T2 Aircraft Plant when in AIR role
            // Defaults mirror TECH thresholds but are scoped to AIR so air.as does not reference TECH settings.
            float RequiredMetalIncomeForT2AircraftPlant = 30.0f;
            float RequiredMetalCurrentForT2AircraftPlant = 50.0f;
            float RequiredEnergyIncomeForT2AircraftPlant = 1200.0f;
            int MaxT2AircraftPlants = 1;

            /******************** AIR NANO POLICY ********************/
            // How much income per additional T1 nano caretaker; and cap
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 200;            // cap
            // Reserves-based nano condition threshold
            float NanoBuildWhenOverMetal = 1000.0f;

            // Minimum number of T1 air constructors to maintain globally
            int MinT1AirConstructorCount = 3;
            // Minimum number of T2 air constructors (advanced construction aircraft) to maintain globally
            int MinT2AirConstructorCount = 2;

            // Minimum number of air scouts to maintain globally for early map vision
            int MinAirScoutCount = 2;

            /******************** AIR T2 BOMBER TOP-UP POLICY ********************/
            // Maintain up to this many T2 bombers globally; factories will enqueue 5 at a time until this target is met.
            int TargetT2BomberCount = 200;

            /******************** HEAVY AIR STRIKE POLICY (Legion/Cortex) ********************/
            // When metal income exceeds this threshold, each T2 air plant may enqueue a small batch of heavy air units
            // Legion -> Tyrannus (legfort), Cortex -> Dragon (corcrw). Only applies to Legion/Cortex.
            float T2HeavyAirIncomeThreshold = 250.0f;
            int T2HeavyAirBatchPerFactory = 3;

            /******************** T2 BOMBER ROLE SWITCH GATE ********************/
            // When total T2 bombers >= this value, gate opens: all bombers get mainRole=bomber and future creations do too
            int BomberGateOpenThreshold = 20;
            // When total T2 bombers < this value, gate closes: default mainRole for T2 bombers reverts to support
            int BomberGateCloseThreshold = 10;

            /******************** SUPPORT FIGHTER GROUP ********************/
            // Maintain a home-defense wing of T2 fighters that stays near base
            int TargetSupportFighterCount = 40;
            // Per-factory enqueue cap when topping up support fighters
            int SupportFighterBatchPerFactory = 5;

        }

        namespace Front {
            // Role switch cadence (seconds)
            int MinAiSwitchTime = 20;
            int MaxAiSwitchTime = 60;

            // NukeLimit: maximum number of nukes allowed for FRONT role
            int NukeLimit = 0;
            /******************** FRONT BASE SETTINGS ********************/
            // All settings applied to front role at game start, logic can change throughout game
            float AllyRange = 900.0f;

            /******************** FRONT MILITARY QUOTAS ********************/
            // Scout unit cap for FRONT role (defaults)
            int MilitaryScoutCap = 2;
            // Attack gate (required power to trigger attack waves) (defaults)
            float MilitaryAttackThreshold = 20.0f;
            // Raid thresholds (power) (defaults)
            float MilitaryRaidMinPower = 40.0f;
            float MilitaryRaidAvgPower = 180.0f;

            // Split thresholds by opening: bots vs vehicles.
            // These default to the baseline values above; tweak per-profile as needed.
            int MilitaryScoutCapBots = 7;
            int MilitaryScoutCapVehicles = 2;
            float MilitaryAttackThresholdBots = 10.0f;
            float MilitaryAttackThresholdVehicles = 30.0f;
            float MilitaryRaidMinPowerBots = 10.0f;
            float MilitaryRaidMinPowerVehicles = 40.0f;
            float MilitaryRaidAvgPowerBots = 60.0f;
            float MilitaryRaidAvgPowerVehicles = 180.0f;

            // Number of T1 scouts/raiders to rush from the very first T1 land factory
            // Only applies to the first T1 Bot Lab or Vehicle Plant built; subsequent factories use normal logic
            int ScoutRushCount = 1;

             /******************** FRONT NANO POLICY ********************/
            // How much income per additional T1 nano caretaker; and cap
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 200; 
            // Reserves-based nano condition threshold
            float NanoBuildWhenOverMetal = 1000.0f;

            // Minimum constructor maintenance targets for factory recruitment
            int MinT1BotConstructorCount = 1;
            int MinT1VehicleConstructorCount = 1;

            /******************** FRONT T2 LAB THRESHOLDS ********************/
            // Economy thresholds and caps for building a T2 Bot Lab when in FRONT role
            // Mirrors FrontTech defaults but scoped to Front so front.as does not reference FrontTech settings.
            // Special-case: first T2 lab/plant fast-track threshold (bot or vehicle) when none exist yet
            // If total T2 labs (bot + vehicle) < 1 and metal income >= this, FRONT will attempt to build one.
            float MinimumMetalIncomeForFirstT2Lab = 50.0f;
            float MinimumMetalIncomeForT2Lab = 40.0f;
            float MinimumEnergyIncomeForT2Lab = 2000.0f;
            float RequiredMetalCurrentForT2Lab = 200.0f;

            int MaxT2BotLabs = 1;
        }

        namespace FrontTech {
            /******************** FRONT TECH BASE SETTINGS ********************/
            // All settings applied to front tech role at game start, logic can change throughout game
            float AllyRange = 1300.0f;

            /******************** FRONT TECH MILITARY QUOTAS ********************/
            // Scout unit cap for FRONT TECH role
            int MilitaryScoutCap = 2;
            // Attack gate (required power to trigger attack waves)
            float MilitaryAttackThreshold = 40.0f;
            // Raid thresholds (power)
            float MilitaryRaidMinPower = 60.0f;
            float MilitaryRaidAvgPower = 80.0f;

            /******************** FRONT TECH ECONOMY SETTINGS ********************/
            // Continue building normal solars if ever below this energy income level
            float SolarEnergyIncomeMinimum = 160.0f;
            // T1 Energy converter policy (FrontTech-specific thresholds)
            // Build converters while metal income is below this threshold
            float BuildT1ConvertersUntilMetalIncome = 18.0f;
            // Require at least this much energy income
            float BuildT1ConvertersMinimumEnergyIncome = 250.0f;
            // Require current energy to be at least this fraction of storage (e.g., 0.90 = 90%)
            float BuildT1ConvertersMinimumEnergyCurrentPercent = 0.90f;
            // Continue building advanced solars if ever below this energy income level
            float AdvancedSolarEnergyIncomeMinimum = 600.0f;
            // Stop building advanced solars if above this energy income level
            float AdvancedSolarEnergyIncomeMaximum = 1000.0f;

            // T2 lab build thresholds for FrontTech role
            float MinimumMetalIncomeForT2Lab = 17.0f;
            float MinimumEnergyIncomeForT2Lab = 550.0f;
            float RequiredMetalCurrentForT2Lab = 800.0f;

            int MaxT2BotLabs = 1;

            /******************** BUILDER CAP LIMITS ********************/
            // Hard caps for T1/T2 land builders used when computing income-based limits
            int MaxT1Builders = 5;
            int MaxT2Builders = 5;

            /******************** FRONT TECH NANO POLICY ********************/
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 200;            // cap
            // Reserves-based nano condition threshold
            float NanoBuildWhenOverMetal = 1000.0f;

            /******************** FRONT TECH ASSIST POLICY ********************/
            // If metal income is below this, secondary T1 will assist primary T1
            float SecondaryT1AssistMetalIncomeMax = 80.0f;
        }

        namespace Sea {
            // Role switch cadence (seconds)
            int MinAiSwitchTime = 20;
            int MaxAiSwitchTime = 60;

            // NukeLimit: maximum number of nukes allowed for SEA role
            int NukeLimit = 0;
            /******************** SEA BASE SETTINGS ********************/
            // All settings applied to sea role at game start, logic can change throughout game
            float AllyRange = 2000.0f;

            /******************** SEA MILITARY QUOTAS ********************/
            // Scout unit cap for SEA role
            int MilitaryScoutCap = 3;
            // Attack gate (required power to trigger attack waves)
            float MilitaryAttackThreshold = 30.0f;
            // Raid thresholds (power)
            float MilitaryRaidMinPower = 20.0f;
            float MilitaryRaidAvgPower = 60.0f;

            /******************** SEA ECONOMY SETTINGS ********************/
            // Prefer tidals over solars at sea; consider adding tidals if energy income is below this
            float TidalEnergyIncomeMinimum = 1200.0f; // tune per map; tidals vary
            // If energy is low, allow assisting the primary T1 sea worker
            float AssistPrimaryWorkerEnergyIncomeMinimum = 500.0f;

            // Early resurrection-sub policy toggle and tuning
            // When enabled, T1 shipyards may produce resurrection submarines early based on income scaling
            bool EnableEarlyRezSub = false;
            // Income scaling: allowed rez-sub count = floor(metalIncome / MetalIncomePerRezSub)
            float MetalIncomePerRezSub = 60.0f;

            // Consider energy storage "low" when current < storage * percent (SEA scope)
            float EnergyStorageLowPercent = 0.90f;

            // Minimum incomes for building advanced (T2) energy converter at sea
            float MinimumMetalIncomeForAdvConverter = 18.0f;
            float MinimumEnergyIncomeForAdvConverter = 1200.0f;

            // T1 Energy converter policy (SEA-specific thresholds)
            // Build converters while metal income is below this threshold
            float BuildT1ConvertersUntilMetalIncome = 40.0f;
            // Require at least this much energy income
            float BuildT1ConvertersMinimumEnergyIncome = 250.0f;
            // Require current energy to be at least this fraction of storage (e.g., 0.90 = 90%)
            float BuildT1ConvertersMinimumEnergyCurrentPercent = 0.90f;

            // Fusion Reactor thresholds (SEA scope)
            float MinimumMetalIncomeForFUS = 30.0f; 
            float MinimumEnergyIncomeForFUS = 1200.0f;
            float MaxEnergyIncomeForFUS = 999999.0f;

            /******************** SEA BUILDER GUARD CAPS ********************/
            // Max number of workers assigned as guards to a single leader (primary or secondary) for SEA
            // Defaults mirror global caps; tune down to limit construction ships guarding.
            int BuilderMaxGuardsPerLeader = 2;
            // Max number of workers assigned as guards to a tactical SEA constructor
            int BuilderMaxGuardsPerTacticalLeader = 0;

            /******************** SEA NANO POLICY ********************/
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 200;            // cap
            // Reserves-based nano condition threshold
            float NanoBuildWhenOverMetal = 1000.0f;

            /******************** SEA T2 SHIPYARD THRESHOLDS ********************/
            // Economy thresholds and caps for building an Advanced Shipyard (T2)
            // Require primary T1 shipyard to exist before attempting T2
            float MinimumMetalIncomeForT2Shipyard = 40.0f;
            float MinimumEnergyIncomeForT2Shipyard = 800.0f;
            float RequiredMetalCurrentForT2Shipyard = 800.0f;
            int MaxT2Shipyards = 1;

            /******************** SEA FACTORY OUTPUT TARGETS ********************/
            // Maintain at least this many T2 destroyers; when below, enqueue in batches
            int MinT2DestroyerCount = 5;
            int T2DestroyerBatchSize = 5;

        
        }

        namespace HoverSea {
            /******************** SEA BASE SETTINGS ********************/
            // All settings applied to sea role at game start, logic can change throughout game
            float AllyRange = 3000.0f;

            /******************** SEA MILITARY QUOTAS ********************/
            // Scout unit cap for SEA role
            int MilitaryScoutCap = 4;
            // Attack gate (required power to trigger attack waves)
            float MilitaryAttackThreshold = 20.0f;
            // Raid thresholds (power)
            float MilitaryRaidMinPower = 30.0f;
            float MilitaryRaidAvgPower = 60.0f;

            /******************** HOVER SEA NANO POLICY ********************/
            // How much income per additional T1 nano caretaker; and cap
            float NanoEnergyPerUnit = 200.0f; // energy per nano
            float NanoMetalPerUnit = 10.0f;   // metal per nano
            int NanoMaxCount = 300; 
            // Reserves-based nano condition threshold
            float NanoBuildWhenOverMetal = 1000.0f;


            /******************** HOVER_SEA ECONOMY SETTINGS ********************/
            
            //Continue building normal solars if ever below this energy income level
            float SolarEnergyIncomeMinimum = 160.0f; 
            // Continue building advanced solars if ever below this energy income level
            float AdvancedSolarEnergyIncomeMinimum = 1200.0f;
            // Stop building advanced solars if above this energy income level
            float AdvancedSolarEnergyIncomeMaximum = 3000.0f;

            // Minimum metal income to trigger building an Advanced Vehicle Plant (T2 Vehicle Lab)
            float RequiredMetalIncomeForT2VehiclePlant = 25.0f;

            // Minimum number of T1 hover constructors to maintain via Hover plant production
            int MinHoverConstructorCount = 10;

            // Income-scaled Hover Plant policy
            // Build allowance: 1 base plant + floor(metalIncome / MetalIncomePerExtraHoverPlant),
            // clamped to MaxHoverPlants. Defaults: +1 per 50 metal income, max 3 plants total.
            float MetalIncomePerExtraHoverPlant = 50.0f;
            int MaxHoverPlants = 3;

            /******************** HOVER SEA START LIMIT CAPS ********************/
            // Initial caps applied at game start for the HOVER_SEA role
            int StartCapT1BotLabs = 0;
            int StartCapT2BotLabs = 0;
            int StartCapT1VehiclePlants = 0;

            // Aircraft plants
            int StartCapT1AircraftPlants = 0;
            int StartCapT2AircraftPlants = 0;

            // Shipyards (water)
            int StartCapT1Shipyards = 0;
            int StartCapT2Shipyards = 0;
        }

        // --- End role-specific settings ---
    }

    namespace MexUpgrades {
        // key: "gx,gz" grid cell; value: AIFloat3 spot
        dictionary spots;

        // Snap pos to build grid (~16 elmos = 2 * SQUARE_SIZE)
        string Key(const AIFloat3 &in p) {
            const float step = 2.0f * SQUARE_SIZE;
            const int gx = int(floor((p.x + 0.5f * step) / step));
            const int gz = int(floor((p.z + 0.5f * step) / step));
            return gx + "," + gz;
        }

        void Add(IUnitTask@ t) {
            if (t is null) return;
            if (t.GetType() != Task::Type::BUILDER) return;
            if (Task::BuildType(t.GetBuildType()) != Task::BuildType::MEXUP) return;
            AIFloat3 p = t.GetBuildPos();
            spots.set(Key(p), p);
        }

        void Remove(IUnitTask@ t) {
            if (t is null) return;
            if (t.GetType() != Task::Type::BUILDER) return;
            if (Task::BuildType(t.GetBuildType()) != Task::BuildType::MEXUP) return;
            AIFloat3 p = t.GetBuildPos();
            spots.delete(Key(p));
        }

        bool AnyNearBase(float radius) {
            const AIFloat3 base = Global::Map::StartPos;
            if (base.x == 0.0f && base.z == 0.0f) return false; // not set
            const float r2 = radius * radius;
            array<string>@ ks = spots.getKeys();
            for (uint i = 0; i < ks.length(); ++i) {
                AIFloat3 pos;
                if (spots.get(ks[i], pos)) {
                    if (MapHelpers::SqDist(pos, base) <= r2) return true;
                }
            }
            return false;
        }

        bool AnyNear(const AIFloat3 &in pos, float radius) {
            if (pos.x == 0.0f && pos.z == 0.0f) return false; // not set
            const float r2 = radius * radius;
            array<string>@ ks = spots.getKeys();
            for (uint i = 0; i < ks.length(); ++i) {
            AIFloat3 spotPos;
            if (spots.get(ks[i], spotPos)) {
                if (MapHelpers::SqDist(spotPos, pos) <= r2) return true;
            }
            }
            return false;
        }
    }

}