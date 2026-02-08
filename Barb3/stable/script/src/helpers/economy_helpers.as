#include "unit_helpers.as"
#include "unitdef_helpers.as"
#include "generic_helpers.as"
#include "../global.as"

namespace EconomyHelpers {
    // Compute desired nano count from an income value, a rate (incomePerNano), and a cap.
    // Returns clamped non-negative count.
    int _DesiredNanoCountGeneric(float income, float incomePerNano, int maxNanos)
    {
        if (incomePerNano <= 0.0f) return 0; // defensive
        if (income <= 0.0f) return 0;
        int want = int(floor(income / incomePerNano));
        if (want < 0) want = 0;
        if (want > maxNanos) want = maxNanos;
        return want;
    }

    // - T2 Shipyard: depends on economy thresholds and current T2 shipyard count vs max allowed
    // Require presence of a primary T1 shipyard (hasPrimaryFactory) before attempting T2
    bool ShouldBuildT2Shipyard(float mi, float ei, float metalCurrent,
                               float requiredMetalIncome, float requiredMetalCurrent, float requiredEnergyIncome,
                               int t2ShipyardCount, int maxAllowed,
                               bool hasPrimaryFactory)
    {
        if (!hasPrimaryFactory) {
            GenericHelpers::LogUtil("[Econ] ShouldBuildT2Shipyard: blocked, no primary T1 shipyard", 4);
            return false;
        }
        bool miOk = (mi >= requiredMetalIncome);
        bool mcOk = true;//(metalCurrent >= requiredMetalCurrent);
        bool eiOk = (ei >= requiredEnergyIncome);
        bool econOk = (miOk && mcOk && eiOk);
        bool countOk = (t2ShipyardCount < maxAllowed);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2Shipyard: mi=" + mi + "/" + requiredMetalIncome + " ok=" + (miOk ? "true" : "false") +
            " ei=" + ei + "/" + requiredEnergyIncome + " ok=" + (eiOk ? "true" : "false") +
            " metalCurrent=" + metalCurrent + "/" + requiredMetalCurrent + " ok=" + (mcOk ? "true" : "false") +
            " count=" + t2ShipyardCount + "/max=" + maxAllowed + " ok=" + (countOk ? "true" : "false") +
            " => result=" + ((econOk && countOk) ? "true" : "false"),
            3
        );
        return econOk && countOk;
    }

    /******************** GENERAL ECONOMY RULES (PURE OR PARAMETERIZED) ********************/
    // Simple energy check for basic solar builds.
    bool ShouldBuildT1Solar(float energyIncome, float minEnergyIncome)
    {
        return (energyIncome < minEnergyIncome);
    }

    // Should a primary worker be assisted based on energy income threshold?
    // Generic helper used by roles to decide when to assign guards to the primary constructor.
    bool ShouldAssistPrimaryWorker(float energyIncome, float minEnergyIncome)
    {
        return (energyIncome < minEnergyIncome);
    }

    // Decide building an advanced T2 energy converter (MMM).
    bool ShouldBuildT2EnergyConverter(
        float metalIncome,
        float energyIncome,
        bool isEnergyLessThan90Percent,
        bool isEnergyFull,
        float requiredMetalIncome,
        float requiredEnergyIncome
    ) {
        return (
            metalIncome > requiredMetalIncome &&
            energyIncome > requiredEnergyIncome &&
            (!isEnergyLessThan90Percent || isEnergyFull)
        );
    }

    // Decide building an Advanced Fusion Reactor now.
    bool ShouldBuildAdvancedFusionReactor(
        float metalIncome,
        float energyIncome,
        bool isEnergyLessThan90Percent,
        int nukeRush,
        int nukeSiloCount,
        float requiredMetalIncome,
        float requiredEnergyIncome
    ) {
        if (nukeRush > 0 && nukeSiloCount < 1) {
            return false;
        }
        return (
            metalIncome > requiredMetalIncome &&
            energyIncome > requiredEnergyIncome &&
            isEnergyLessThan90Percent
        );
    }

    // Decide building a Fusion Reactor now.
    bool ShouldBuildFusionReactor(
        float metalIncome,
        float energyIncome,
        bool isEnergyLessThan90Percent,
        float requiredMetalIncome,
        float requiredEnergyIncome,
        float maxEnergyIncome
    ) {
        return (
            metalIncome > requiredMetalIncome &&
            energyIncome > requiredEnergyIncome &&
            energyIncome < maxEnergyIncome &&
            isEnergyLessThan90Percent
        );
    }

    // Compute allowed gantry count from incomes and per-gantry income requirements.
    // Returns min(floor(mi / metalIncomePerGantry), floor(ei / energyIncomePerGantry)), clamped to >= 0.
    int AllowedGantryCountFromIncome(
        float mi,
        float ei,
        float metalIncomePerGantry,
        float energyIncomePerGantry
    ) {
        if (metalIncomePerGantry <= 0.0f || energyIncomePerGantry <= 0.0f) return 0; // defensive
        int allowedByMetal = int(mi / metalIncomePerGantry);
        int allowedByEnergy = int(ei / energyIncomePerGantry);
        if (allowedByMetal < 0) allowedByMetal = 0;
        if (allowedByEnergy < 0) allowedByEnergy = 0;
        return (allowedByMetal < allowedByEnergy) ? allowedByMetal : allowedByEnergy;
    }

    // Compute allowed T1 aircraft plants from incomes and per-plant income requirements.
    // Returns min(floor(mi / metalIncomePerPlant), floor(ei / energyIncomePerPlant)), clamped to >= 0.
    int AllowedT1AircraftPlantCountFromIncome(
        float mi,
        float ei,
        float metalIncomePerPlant,
        float energyIncomePerPlant
    ) {
        if (metalIncomePerPlant <= 0.0f || energyIncomePerPlant <= 0.0f) return 0; // defensive
        int allowedByMetal = int(mi / metalIncomePerPlant);
        int allowedByEnergy = int(ei / energyIncomePerPlant);
        if (allowedByMetal < 0) allowedByMetal = 0;
        if (allowedByEnergy < 0) allowedByEnergy = 0;
        return (allowedByMetal < allowedByEnergy) ? allowedByMetal : allowedByEnergy;
    }

    // Compute allowed T2 aircraft plants from incomes and per-plant income requirements.
    // Returns min(floor(mi / metalIncomePerPlant), floor(ei / energyIncomePerPlant)), clamped to >= 0.
    int AllowedT2AircraftPlantCountFromIncome(
        float mi,
        float ei,
        float metalIncomePerPlant,
        float energyIncomePerPlant
    ) {
        if (metalIncomePerPlant <= 0.0f || energyIncomePerPlant <= 0.0f) return 0; // defensive
        int allowedByMetal = int(mi / metalIncomePerPlant);
        int allowedByEnergy = int(ei / energyIncomePerPlant);
        if (allowedByMetal < 0) allowedByMetal = 0;
        if (allowedByEnergy < 0) allowedByEnergy = 0;
        return (allowedByMetal < allowedByEnergy) ? allowedByMetal : allowedByEnergy;
    }

    // Compute allowed T2 bot labs from incomes and per-lab income requirements.
    // Returns min(floor(mi / metalIncomePerLab), floor(ei / energyIncomePerLab)), clamped to >= 0.
    int AllowedT2BotLabCountFromIncome(
        float mi,
        float ei,
        float metalIncomePerLab,
        float energyIncomePerLab
    ) {
        if (metalIncomePerLab <= 0.0f || energyIncomePerLab <= 0.0f) return 0; // defensive
        int allowedByMetal = int(mi / metalIncomePerLab);
        int allowedByEnergy = int(ei / energyIncomePerLab);
        if (allowedByMetal < 0) allowedByMetal = 0;
        if (allowedByEnergy < 0) allowedByEnergy = 0;
        return (allowedByMetal < allowedByEnergy) ? allowedByMetal : allowedByEnergy;
    }

    // Compute allowed T1 resurrection submarine count from metal income and per-unit income requirement.
    // Returns floor(mi / metalIncomePerRezSub), clamped to >= 0.
    int AllowedT1ResurrectionSubCountFromIncome(float mi, float metalIncomePerRezSub)
    {
        if (metalIncomePerRezSub <= 0.0f) return 0; // defensive
        int allowed = int(mi / metalIncomePerRezSub);
        if (allowed < 0) allowed = 0;
        return allowed;
    }

    // Decide building a gantry given economy and existing count.
    // metalIncomePerGantry and energyIncomePerGantry are passed explicitly to allow role-specific tuning
    bool ShouldBuildGantry(
        float mi,
        float ei,
        float metalStored,
        int currentGantryCount,
        float metalIncomePerGantry,
        float energyIncomePerGantry
    )
    {
        if (metalStored <= 1000.0f) return false;
        int allowed = AllowedGantryCountFromIncome(mi, ei, metalIncomePerGantry, energyIncomePerGantry);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildGantry: mi=" + mi + " ei=" + ei + " metalStored=" + metalStored +
            " metalIncomePerGantry=" + metalIncomePerGantry + " energyIncomePerGantry=" + energyIncomePerGantry +
            " allowed=" + allowed + " currentGantryCount=" + currentGantryCount,
            3
        );
        return currentGantryCount < allowed;
    }

    // Should the AI request factory assist? (parameterized to avoid globals inside helper)
    bool ShouldAssistFactory(
        bool hasT2Lab,
        float energyIncome,
        int t2ConstructionBotCount,
        bool hasT1Lab,
        int t1ConstructionBotCount,
        float metalCurrent,
        float metalIncome,
        float t2EnergyIncomeRequired,
        int t1CtorMin,
        float t1MetalCurrentReq,
        float t1MetalIncomeReq
    ) {
        bool result = (
            (hasT2Lab && energyIncome > t2EnergyIncomeRequired && t2ConstructionBotCount < 1)
            ||
            (hasT1Lab && t1ConstructionBotCount < t1CtorMin && metalCurrent > t1MetalCurrentReq && metalIncome > t1MetalIncomeReq)
        );
        GenericHelpers::LogUtil("[Econ] ShouldAssistFactory result=" + (result ? "true" : "false"), 2);
        return result;
    }

    // Should the freelance T2 constructor assist a nearby mex upgrade? Parameterized for reuse.
    bool ShouldAssignFreelanceMexAssist(
        const AIFloat3& in anchor,
        float energyIncome,
        float minEnergyIncome,
        float metalIncome,
        float maxMetalIncome,
        int nearRadius,
        CCircuitUnit@ freelanceT2BotConstructor
    ) {
        return (
            Global::MexUpgrades::AnyNear(anchor, nearRadius)
            && energyIncome > minEnergyIncome
            && metalIncome < maxMetalIncome
            && @freelanceT2BotConstructor !is null
        );
    }

    /******************** BUILDER CAP HELPERS (PURE) ********************/
    // Calculate T1 builder cap from metal income using the existing policy:
    // cap = 3 + 3 * floor(metalIncome / 15), clamped to [minCap, maxCap]
    int CalculateT1BuilderCap(float metalIncome, int minCap, int maxCap)
    {
        int cap = 3 + 3 * int(metalIncome / 15.0f);
        if (cap < minCap) cap = minCap;
        if (cap > maxCap) cap = maxCap;
        GenericHelpers::LogUtil("[Econ] CalculateT1BuilderCap: mi=" + metalIncome + " => " + cap + " (min=" + minCap + ", max=" + maxCap + ")", 4);
        return cap;
    }

    // Calculate T2 builder cap from metal income using the existing policy:
    // cap = 3 + 3 * floor(metalIncome / 40), clamped to [minCap, maxCap]
    int CalculateT2BuilderCap(float metalIncome, int minCap, int maxCap)
    {
        int cap = 3 + 3 * int(metalIncome / 40.0f);
        if (cap < minCap) cap = minCap;
        if (cap > maxCap) cap = maxCap;
        GenericHelpers::LogUtil("[Econ] CalculateT2BuilderCap: mi=" + metalIncome + " => " + cap + " (min=" + minCap + ", max=" + maxCap + ")", 4);
        return cap;
    }

    /******************** ASSIST POLICY HELPERS ********************/
    // Should a secondary T2 constructor assist the primary?
    // Decides purely from inputs to avoid global reads in callers.
    bool ShouldSecondaryT2AssistPrimary(
        float metalIncome,
        float maxIncomeThreshold,
        bool hasPrimaryT2BotConstructor
    ) {
        bool result = (metalIncome < maxIncomeThreshold && hasPrimaryT2BotConstructor);
        GenericHelpers::LogUtil("[Econ] ShouldSecondaryT2AssistPrimary mi=" + metalIncome + "/" + maxIncomeThreshold + " hasPrimary=" + (hasPrimaryT2BotConstructor ? "true" : "false") + " => " + (result ? "true" : "false"), 3);
        return result;
    }

    // Should a secondary T1 constructor assist the primary?
    bool ShouldSecondaryT1AssistPrimary(
        float metalIncome,
        float threshold
    ) {
        bool result = (metalIncome < threshold);
        GenericHelpers::LogUtil("[Econ] ShouldSecondaryT1AssistPrimary mi=" + metalIncome + " < thr=" + threshold + " => " + (result ? "true" : "false"), 3);
        return result;
    }

    // Unified predicate for deciding whether to build T1 Advanced Solar generators.
    // Parameters:
    // - energyIncome: current energy income
    // - metalIncome: current metal income
    // - energyIncomeMinimumThreshold: continue building advanced solars if energyIncome is below this threshold
    // - energyIncomeMaximumThreshold: do not build advanced solars if energyIncome is at or above this threshold (unless fallback condition triggers)
    // - t2ConstructorCount: count of relevant T2 constructors for the role (0 if not applicable)
    // - t2FactoryCount: count of relevant T2 factories/plants for the role (0 if not applicable)
    // - isT2FactoryQueued: whether a relevant T2 factory task is currently queued
    // - enableT2ProgressGate: when true, primary condition requires no T2 progress (constructors/factories/queued)
    // - metalIncomeFallbackMinimum: fallback minimum metal income to allow advanced solar when energy is very low
    bool ShouldBuildT1AdvancedSolar(
        float energyIncome,
        float metalIncome,
        float energyIncomeMinimumThreshold,
        float energyIncomeMaximumThreshold,
        int t2ConstructorCount,
        int t2FactoryCount,
        bool isT2FactoryQueued,
        bool enableT2ProgressGate,
        float metalIncomeFallbackMinimum
    ) {
        bool primaryOk = false;
        if (enableT2ProgressGate) {
            primaryOk = (
                energyIncome < energyIncomeMaximumThreshold &&
                t2ConstructorCount < 1 &&
                t2FactoryCount < 1 &&
                !isT2FactoryQueued
            );
        } else {
            primaryOk = (energyIncome < energyIncomeMaximumThreshold);
        }

        bool fallbackOk = (energyIncome < energyIncomeMinimumThreshold && metalIncome > metalIncomeFallbackMinimum);

        bool result = (primaryOk || fallbackOk);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT1AdvancedSolar: energyIncome=" + energyIncome +
            " (min=" + energyIncomeMinimumThreshold + ", max=" + energyIncomeMaximumThreshold + ")" +
            " metalIncome=" + metalIncome + " (fallbackMin=" + metalIncomeFallbackMinimum + ")" +
            " t2Constr=" + t2ConstructorCount + " t2Factory=" + t2FactoryCount +
            " queuedT2=" + (isT2FactoryQueued ? "true" : "false") +
            " gate=" + (enableT2ProgressGate ? "true" : "false") +
            " => result=" + (result ? "true" : "false"),
            4
        );
        return result;
    }
    // Energy-based policy (e.g., 1 nano per 200 energy, capped at 10)
    int DesiredNanoCountFromEnergy(float energyIncome, float incomePerNano, int maxNanos)
    {
        return _DesiredNanoCountGeneric(energyIncome, incomePerNano, maxNanos);
    }

    // Metal-based policy (e.g., 1 nano per 10 metal, capped at 10)
    int DesiredNanoCountFromMetal(float metalIncome, float incomePerNano, int maxNanos)
    {
        return _DesiredNanoCountGeneric(metalIncome, incomePerNano, maxNanos);
    }

    // Parameterized rule: build a T1 energy converter when energy is sufficiently full,
    // energy income is above a minimum, and metal income is below a cap.
    // Note: This helper does not access globals; all values are passed in.
    bool ShouldBuildT1EnergyConverter(
        float metalIncome,
        float energyIncome,
        float energyCurrent,
        float energyStorage,
        float untilMetalIncome,
        float minEnergyIncome,
        float minEnergyCurrentPercent
    ) {
        // Compute energy fullness percent if storage is positive; otherwise assume not full
        bool energyPctOk = false;
        if (energyStorage > 0.0f) {
            float pct = energyCurrent / energyStorage;
            energyPctOk = (pct >= minEnergyCurrentPercent);
        }
        bool result = (metalIncome < untilMetalIncome) && (energyIncome >= minEnergyIncome) && energyPctOk;
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT1EnergyConverter: metalIncome=" + metalIncome + "/until=" + untilMetalIncome
            + " energyIncome=" + energyIncome + "/min=" + minEnergyIncome
            + " energyCurrentPercent=" + (energyStorage > 0.0f ? (energyCurrent / energyStorage) : 0.0f)
            + "/min=" + minEnergyCurrentPercent
            + " => result=" + (result ? "true" : "false"),
            4
        );
        return result;
    }

    // Distinct condition: build a nano when reserves are high enough.
    // Returns true if current metal is above a threshold and energy reserves are sufficiently full.
    // Parameters:
    // - metalCurrent: current metal amount (reserve), not income
    // - buildWhenOverMetal: threshold at/over which we allow nano by reserves
    // - energyPercent: current energy fullness in [0,1]
    bool ShouldBuildT1Nano_ByReserves(float metalCurrent, float buildWhenOverMetal, float energyPercent)
    {
        // Require both: enough stored metal and at least 90% energy reserves
        return (metalCurrent >= buildWhenOverMetal) && (energyPercent >= 0.90f);
    }

    // Decide whether to build another T1 nano caretaker based on both income-derived desired counts
    // and a separate reserves-based condition. Callers must provide reserve context explicitly.
    // Returns true if either:
    //  - have < min(desired from energy, desired from metal), or
    //  - reserves condition passes (metalCurrent >= buildWhenOverMetal && energyPercent >= 0.90)
    bool ShouldBuildT1Nano(
        float energyIncome,
        float metalIncome,
        float energyPerNano,
        float metalPerNano,
        int maxNanos,
        float metalCurrent,
        float buildWhenOverMetal,
        float energyPercent
    )
    {
        int have = UnitDefHelpers::SumUnitDefCounts(UnitHelpers::GetT1NanoUnitNames());
        int wantEnergy = DesiredNanoCountFromEnergy(energyIncome, energyPerNano, maxNanos);
        int wantMetal = DesiredNanoCountFromMetal(metalIncome, metalPerNano, maxNanos);
        int want = (wantEnergy < wantMetal ? wantEnergy : wantMetal);

        // Second, reserve-driven path: if reserves are healthy, also permit nano.
        bool reservesOk = ShouldBuildT1Nano_ByReserves(metalCurrent, buildWhenOverMetal, energyPercent);

        bool result = (have < want) || reservesOk;
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT1Nano: have=" + have + " want(E,M)=" + wantEnergy + "," + wantMetal + " => use=" + want +
            " reservesOk=" + (reservesOk ? "true" : "false") +
            " (metalCurrent=" + metalCurrent + "/thr=" + buildWhenOverMetal +
            ", energy%=" + energyPercent + ") => result=" + (result ? "true" : "false"),
            4
        );
        return result;
    }

    // Aircraft plant gating (generic):
    // - T1: depends on economy thresholds and current T1 count vs max allowed
    bool ShouldBuildT1AircraftPlant(float mi, float ei, float metalCurrent,
                                    float requiredMetalIncome, float requiredMetalCurrent, float requiredEnergyIncome,
                                    int t1AirPlantCount, int maxAllowed)
    {
        // Verbose diagnostics to understand why T1 air plant isn’t being built
        bool econOk = (mi >= requiredMetalIncome && ei >= requiredEnergyIncome);
        bool miOk = (mi >= requiredMetalIncome);
        bool mcOk = true;//(metalCurrent >= requiredMetalCurrent);
        bool eiOk = (ei >= requiredEnergyIncome);
        bool countOk = (t1AirPlantCount < maxAllowed);

        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT1AircraftPlant: mi=" + mi + "(req=" + requiredMetalIncome + ", ok=" + (miOk ? "true" : "false") + ")"
            + " ei=" + ei + "(req=" + requiredEnergyIncome + ", ok=" + (eiOk ? "true" : "false") + ")"
            + " metalCurrent=" + metalCurrent + "(req=" + requiredMetalCurrent + ", ok=" + (mcOk ? "true" : "false") + ")"
            + " count=" + t1AirPlantCount + "/max=" + maxAllowed + "(ok=" + (countOk ? "true" : "false") + ")"
            + " => econOk=" + (econOk ? "true" : "false") + ", result=" + ((econOk && countOk) ? "true" : "false"),
            3
        );

        return econOk && countOk;
    }

    // - T2: depends on economy thresholds, constructor being an air constructor, and current T2 count vs max allowed
    bool ShouldBuildT2AircraftPlant(float mi, 
                                    float ei, 
                                    float metalCurrent,
                                    float requiredMetalIncome, 
                                    float requiredMetalCurrent, 
                                    float requiredEnergyIncome,
                                    const CCircuitDef@ constructorDef, 
                                    int t2AirPlantCount, 
                                    int maxAllowed)
    {
        bool isAirCtor = UnitHelpers::IsAirConstructor(constructorDef);
        if (!isAirCtor) {
            GenericHelpers::LogUtil("[Econ] ShouldBuildT2AircraftPlant: constructor is not air-capable", 4);
            return false;
        }
        bool miOk = (mi >= requiredMetalIncome);
        bool mcOk = true;//(metalCurrent >= requiredMetalCurrent);
        bool eiOk = (ei >= requiredEnergyIncome);
        bool econOk = (miOk && mcOk && eiOk);
        bool countOk = (t2AirPlantCount < maxAllowed);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2AircraftPlant: mi=" + mi + "/" + requiredMetalIncome + " ok=" + (miOk ? "true" : "false") +
            " ei=" + ei + "/" + requiredEnergyIncome + " ok=" + (eiOk ? "true" : "false") +
            " metalCurrent=" + metalCurrent + "/" + requiredMetalCurrent + " ok=" + (mcOk ? "true" : "false") +
            " count=" + t2AirPlantCount + "/max=" + maxAllowed + " ok=" + (countOk ? "true" : "false") +
            " => result=" + ((econOk && countOk) ? "true" : "false"),
            3
        );
        return econOk && countOk;
    }

    // - T2 Bot Lab: depends on economy thresholds and current T2 bot lab count vs max allowed
    // Signature mirrors ShouldBuildT2AircraftPlant for consistency across roles/callers.
    bool ShouldBuildT2BotLab(float mi, float ei, float metalCurrent,
                             float requiredMetalIncome, float requiredMetalCurrent, float requiredEnergyIncome,
                             const CCircuitDef@ constructorDef, int t2BotLabCount, int maxAllowed,
                             bool hasPrimaryFactory)
    {
        // Require a primary factory before attempting to build T2 lab
        if (!hasPrimaryFactory) {
            GenericHelpers::LogUtil("[Econ] ShouldBuildT2BotLab: blocked, no primary factory", 4);
            return false;
        }
        // For bot labs, we generally allow any ground-capable constructor; keep constructorDef for signature parity and future filtering.
        bool miOk = (mi >= requiredMetalIncome);
        bool mcOk = true;//(metalCurrent >= requiredMetalCurrent);
        bool eiOk = (ei >= requiredEnergyIncome);
        bool econOk = (miOk && mcOk && eiOk);
        bool countOk = (t2BotLabCount < maxAllowed);

        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2AircraftPlant: mi=" + mi + "/" + requiredMetalIncome + " ok=" + (miOk ? "true" : "false") +
            " ei=" + ei + "/" + requiredEnergyIncome + " ok=" + (eiOk ? "true" : "false") +
            " metalCurrent=" + metalCurrent + "/" + requiredMetalCurrent + " ok=" + (mcOk ? "true" : "false") +
            " count=" + t2BotLabCount + "/max=" + maxAllowed + " ok=" + (countOk ? "true" : "false") +
            " => result=" + ((econOk && countOk) ? "true" : "false"),
            3
        );
        return econOk && countOk;
    }

    // New income-scaled T2 bot lab decision (preserve old ShouldBuildT2BotLab above for reference).
    // Policy: compute allowed count from incomes using per-lab income requirements, enforce a minimum of 'minAllowed'
    // and build if current count is below allowed. This mirrors the gantry logic style.
    bool ShouldBuildT2BotLabFromIncome(
        float mi,
        float ei,
        int currentT2BotLabCount,
        float metalIncomePerLab,
        float energyIncomePerLab,
        int minAllowed
    ) {
        if (minAllowed < 1) minAllowed = 1; // ensure at least one T2 lab is always permitted by policy
        int allowed = AllowedT2BotLabCountFromIncome(mi, ei, metalIncomePerLab, energyIncomePerLab);
        if (allowed < minAllowed) allowed = minAllowed;
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2BotLabFromIncome: mi=" + mi + " ei=" + ei +
            " metalPerLab=" + metalIncomePerLab + " energyPerLab=" + energyIncomePerLab +
            " allowed=" + allowed + " current=" + currentT2BotLabCount,
            3
        );
        return currentT2BotLabCount < allowed;
    }

    // Decide if we should build a T1 resurrection submarine now.
    // Policy: if feature is enabled and current count < allowed-by-income(mi / metalIncomePerRezSub), build one.
    bool ShouldBuildT1ResurrectionSub(
        float metalIncome,
        int currentRezSubCount,
        float metalIncomePerRezSub,
        bool earlyEnabled
    ) {
        if (!earlyEnabled) return false;
        int allowed = AllowedT1ResurrectionSubCountFromIncome(metalIncome, metalIncomePerRezSub);
        bool result = (currentRezSubCount < allowed);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT1ResurrectionSub: mi=" + metalIncome + " per=" + metalIncomePerRezSub +
            " allowed=" + allowed + " current=" + currentRezSubCount + " enabled=" + (earlyEnabled ? "true" : "false") +
            " => result=" + (result ? "true" : "false"), 3);
        return result;
    }

    // Hybrid policy: require minimum income gates for the first T2 lab, then scale by income-per-lab for additional labs.
    // Reference: legacy ShouldBuildT2BotLab (threshold-based) for first-gate semantics; income-scaling mirrors gantry logic.
    bool ShouldBuildT2BotLabFromIncomeWithFirstGate(
        float mi,
        float ei,
        int currentT2BotLabCount,
        float metalIncomePerLab,
        float energyIncomePerLab,
        float firstLabRequiredMetalIncome,
        float firstLabRequiredEnergyIncome,
        int maxAllowed
    ) {
        // Compute allowed by income per lab
        int allowed = AllowedT2BotLabCountFromIncome(mi, ei, metalIncomePerLab, energyIncomePerLab);

        if (currentT2BotLabCount < 1) {
            // First lab requires minimal economy gate before 'min 1' can apply
            bool firstGateOk = (mi >= firstLabRequiredMetalIncome) && (ei >= firstLabRequiredEnergyIncome);
            GenericHelpers::LogUtil(
                "[Econ] T2Lab FirstGate: mi=" + mi + "/" + firstLabRequiredMetalIncome +
                " ei=" + ei + "/" + firstLabRequiredEnergyIncome +
                " ok=" + (firstGateOk ? "true" : "false"), 3);
            if (!firstGateOk) {
                return false;
            }
            // After gate, at least 1 is allowed
            if (allowed < 1) allowed = 1;
        }
        // Apply max cap if provided (>0)
        if (maxAllowed > 0 && allowed > maxAllowed) allowed = maxAllowed;

        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2BotLabFromIncomeWithFirstGate: allowed=" + allowed +
            " current=" + currentT2BotLabCount + " (miPerLab=" + metalIncomePerLab +
            ", eiPerLab=" + energyIncomePerLab + ")", 3);
        return currentT2BotLabCount < allowed;
    }

    // - T2 Vehicle Lab: minimal, pure predicate for building an advanced vehicle plant
    // Parameters:
    // - mi: current metal income
    // - requiredMetalIncome: threshold to allow building
    // - t2VehPlantCount: current number of built T2 vehicle plants
    // - maxAllowed: maximum allowed T2 vehicle plants
    // - isT2VehPlantQueued: whether a T2 vehicle plant build task is already queued
    bool ShouldBuildT2VehicleLab(
        float mi,
        float requiredMetalIncome,
        int t2VehPlantCount,
        int maxAllowed,
        bool isT2VehPlantQueued
    ) {
        bool econOk = (mi >= requiredMetalIncome);
        bool capOk = (t2VehPlantCount < maxAllowed);
        bool notQueued = !isT2VehPlantQueued;
        bool result = (econOk && capOk && notQueued);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildT2VehicleLab: mi=" + mi + "/" + requiredMetalIncome +
            " count=" + t2VehPlantCount + "/max=" + maxAllowed +
            " queued=" + (isT2VehPlantQueued ? "true" : "false") +
            " => result=" + (result ? "true" : "false"),
            3
        );
        return result;
    }

    // Friendly alias used in some roles/configs
    bool ShouldBuildAdvancedVehiclePlant(
        float mi,
        float requiredMetalIncome,
        int t2VehPlantCount,
        int maxAllowed,
        bool isT2VehPlantQueued
    ) {
        return ShouldBuildT2VehicleLab(mi, requiredMetalIncome, t2VehPlantCount, maxAllowed, isT2VehPlantQueued);
    }

    /******************** NUCLEAR SILO HELPERS ********************/
    // Count all known nuclear silos across all factions (by definition names list)
    int GetNukeSiloCount()
    {
        array<string> nukes = UnitHelpers::GetAllNukeSilos();
        return UnitDefHelpers::SumUnitDefCounts(nukes);
    }

    // Rush policy: attempt to build up to 'rushCount' silos as soon as economy meets thresholds.
    // Returns true if:
    // - rushCount > 0, and
    // - (built + queued) < rushCount, and
    // - metal/energy income meet the required thresholds.
    bool ShouldRushNuke(
        float metalIncome,
        float energyIncome,
        int queuedCount,
        int totalCount,
        int rushCount,
        float requiredMetalIncomeRush,
        float requiredEnergyIncomeRush
    ) {
        bool econOk = (metalIncome >= requiredMetalIncomeRush && energyIncome >= requiredEnergyIncomeRush);
        int planned = totalCount + queuedCount;
        bool underCap = (rushCount > 0 && planned < rushCount);
        bool result = (underCap && econOk);
        GenericHelpers::LogUtil(
            "[Econ] ShouldRushNuke: mi=" + metalIncome + "/req=" + requiredMetalIncomeRush +
            " ei=" + energyIncome + "/req=" + requiredEnergyIncomeRush +
            " total=" + totalCount + " queued=" + queuedCount + " rushCount=" + rushCount +
            " => result=" + (result ? "true" : "false"),
            3
        );
        return result;
    }

    // General policy: build a nuclear silo when economy meets thresholds and we either
    // - are in rush mode (ShouldRushNuke true), or
    // - have none built or queued yet (first-silo policy).
    bool ShouldBuildNuclearSilo(
        float metalIncome,
        float energyIncome,
        int queuedCount,
        int totalCount,
        int rushCount,
        float requiredMetalIncomeRush,
        float requiredEnergyIncomeRush,
        float requiredMetalIncomeRegular,
        float requiredEnergyIncomeRegular
    ) {
        // First consider rush policy
        if (ShouldRushNuke(metalIncome, energyIncome, queuedCount, totalCount, rushCount, requiredMetalIncomeRush, requiredEnergyIncomeRush)) {
            return true;
        }

        // Default: only build a first silo if none exist and none are queued and econ OK
        bool econOk = (metalIncome >= requiredMetalIncomeRegular && energyIncome >= requiredEnergyIncomeRegular);
        bool nonePlanned = (totalCount <= 0 && queuedCount <= 0);
        bool result = (econOk && nonePlanned);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildNuclearSilo: mi=" + metalIncome + "/rushReq=" + requiredMetalIncomeRush + ", regReq=" + requiredMetalIncomeRegular +
            " ei=" + energyIncome + "/rushReq=" + requiredEnergyIncomeRush + ", regReq=" + requiredEnergyIncomeRegular +
            " total=" + totalCount + " queued=" + queuedCount + " rushCount=" + rushCount +
            " => result=" + (result ? "true" : "false"),
            3
        );
        return result;
    }

    /******************** ANTI-NUKE HELPERS ********************/
    // Count all known anti-nuke structures across all factions (by definition names list)
    int GetAntiNukeCount()
    {
        array<string> amd = UnitHelpers::GetAllAntiNukes();
        return UnitDefHelpers::SumUnitDefCounts(amd);
    }

    // Compute allowed anti-nuke structures from metal income and per-anti-nuke income requirement.
    // Returns floor(mi / metalIncomePerAntiNuke), clamped to >= 0.
    int AllowedAntiNukesFromIncome(float metalIncome, float metalIncomePerAntiNuke)
    {
        if (metalIncomePerAntiNuke <= 0.0f) return 0; // defensive
        int allowed = int(metalIncome / metalIncomePerAntiNuke);
        if (allowed < 0) allowed = 0;
        return allowed;
    }

    // Decide building an anti-nuke when economy meets thresholds and below target count
    // Parameters:
    // - metalIncome, energyIncome: current incomes
    // - currentAntiNukeCount: number of anti-nuke structures already built
    // - requiredMetalIncome, requiredEnergyIncome: economy gates
    // - minimumAntiNukeCount: target minimum to maintain (build until reached)
    bool ShouldBuildAntiNuke(
        float metalIncome,
        float energyIncome,
        int currentAntiNukeCount,
        float requiredMetalIncome,
        float requiredEnergyIncome,
        int minimumAntiNukeCount,
        int allowedAntiNukeCount
    ) {
        bool econOk = (metalIncome >= requiredMetalIncome && energyIncome >= requiredEnergyIncome);
        // Target is the max of policy minimum and income-based allowance
        int target = (minimumAntiNukeCount > allowedAntiNukeCount ? minimumAntiNukeCount : allowedAntiNukeCount);
        bool underTarget = (currentAntiNukeCount < target);
        bool result = (econOk && underTarget);
        GenericHelpers::LogUtil(
            "[Econ] ShouldBuildAntiNuke: mi=" + metalIncome + "/req=" + requiredMetalIncome +
            " ei=" + energyIncome + "/req=" + requiredEnergyIncome +
            " current=" + currentAntiNukeCount + " min=" + minimumAntiNukeCount +
            " allowed=" + allowedAntiNukeCount + " target=" + target +
            " => result=" + (result ? "true" : "false"),
            3
        );
        return result;
    }
}
