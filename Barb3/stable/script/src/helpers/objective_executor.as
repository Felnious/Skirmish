#include "objective_helpers.as"
#include "unit_helpers.as"
#include "../manager/builder.as"
#include "../global.as"

namespace ObjectiveExecutor {
    // Map objective type to build type; extend as needed
    Task::BuildType ResolveBuildTypeForStep(Objectives::BuildingType t)
    {
        // Factories
        if (t == Objectives::BuildingType::SEAPLANE_FACTORY) return Task::BuildType::FACTORY;

        // Sensors
        if (t == Objectives::BuildingType::T1_RADAR || t == Objectives::BuildingType::T2_RADAR) return Task::BuildType::RADAR;

    // Energy
    if (t == Objectives::BuildingType::T1_ENERGY || t == Objectives::BuildingType::T1_TIDAL || t == Objectives::BuildingType::T2_ENERGY) return Task::BuildType::ENERGY;

    // Economy spots
    if (t == Objectives::BuildingType::T1_MEX) return Task::BuildType::MEX;
    if (t == Objectives::BuildingType::T1_GEO) return Task::BuildType::GEO;

    // Big guns
    if (t == Objectives::BuildingType::LRPC || t == Objectives::BuildingType::LRPC_HEAVY || t == Objectives::BuildingType::T2_ARTY) return Task::BuildType::BIG_GUN;

        // Default defensive build
        return Task::BuildType::DEFENCE;
    }

    // Helper: does this objective target SEA or HOVER_SEA roles?
    bool IsSeaOrHoverObjective(const Objectives::StrategicObjective@ objective)
    {
        if (objective is null) return false;
        for (uint r = 0; r < objective.roles.length(); ++r) {
            auto role = objective.roles[r];
            if (role == AiRole::SEA || role == AiRole::HOVER_SEA) return true;
        }
        return false;
    }

    // Try to enqueue a specific step. Handles assignment, build-type resolution, and queue bookkeeping.
    IUnitTask@ TryEnqueueStep(
        Objectives::StrategicObjective@ currentObjective,
        const string &in side,
        const AIFloat3 &in anchor,
        const string &in label,
        uint stepIndex,
        const Objectives::ObjectiveStep@ s,
        const string &in resolvedUnitName,
        bool isSeaRole
    )
    {
        if (currentObjective is null || s is null) return null;
        GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Trying to enqueue step " + stepIndex + " for objective '" + currentObjective.id + "' unit='" + resolvedUnitName + "'", 2);
        CCircuitDef@ def = ai.GetCircuitDef(resolvedUnitName);
        if (def is null) {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": def is null for unit '" + resolvedUnitName + "'", 3);
            return null;
        }
        if (!def.IsAvailable(ai.frame)) {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": def not available this frame for unit '" + resolvedUnitName + "'", 3);
            return null;
        }

        string token = "OBJ_STEP_" + stepIndex;
        if (!ObjectiveHelpers::TryAssign(currentObjective.id, token)) {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": objective already assigned (token='" + token + "')", 3);
            return null;
        }

    Task::BuildType btype = ResolveBuildTypeForStep(s.type);
    GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Enqueuing unit '" + resolvedUnitName + "' (btype=" + int(btype) + ") for objective '" + currentObjective.id + "'", 2);
        float shake = (currentObjective.radius > 0.0f ? currentObjective.radius : (SQUARE_SIZE * 32.0f));

    IUnitTask@ task = null;
    string unitNameForCount = resolvedUnitName;
        if (btype == Task::BuildType::FACTORY && s.type == Objectives::BuildingType::SEAPLANE_FACTORY) {
            // Special factory path for seaplanes using Builder helper
            @task = Builder::EnqueueSeaplanePlatform(side, anchor, shake, 600 * SECOND, s.priority);
        } else if (s.type == Objectives::BuildingType::T1_TIDAL) {
            // Explicit tidal objective
            @task = Builder::EnqueueT1Tidal(side, anchor, shake, 300 * SECOND, s.priority);
            unitNameForCount = UnitHelpers::GetTidalNameForSide(side);
        } else if (s.type == Objectives::BuildingType::T1_ENERGY && isSeaRole) {
            // Prefer tidal for sea/hover-sea energy
            @task = Builder::EnqueueT1Tidal(side, anchor, shake, 300 * SECOND, s.priority);
            unitNameForCount = UnitHelpers::GetTidalNameForSide(side); // ensure counters track tidal units
        } else if (s.type == Objectives::BuildingType::T1_ENERGY) {
            @task = Builder::EnqueueT1Solar(side, anchor, shake, 300 * SECOND, s.priority);
        } else if (s.type == Objectives::BuildingType::T1_MEX) {
            // Minimal: enqueue a MEX at anchor. TODO: integrate metal spot selection if available.
            @task = aiBuilderMgr.Enqueue(
                TaskB::Common(Task::BuildType::MEX, s.priority, def, anchor, /*shake*/ SQUARE_SIZE * 8, /*active*/ true, /*timeout*/ 800 * SECOND)
            );
            unitNameForCount = UnitHelpers::GetObjectiveUnitNameForSide(side, s.type);
        } else if (s.type == Objectives::BuildingType::T1_GEO) {
            // Minimal: enqueue a GEO at anchor. TODO: select nearest valid geo spot to anchor.
            @task = aiBuilderMgr.Enqueue(
                TaskB::Common(Task::BuildType::GEO, s.priority, def, anchor, /*shake*/ SQUARE_SIZE * 16, /*active*/ true, /*timeout*/ 1200 * SECOND)
            );
            unitNameForCount = UnitHelpers::GetObjectiveUnitNameForSide(side, s.type);
        } else if (
            s.type == Objectives::BuildingType::T1_LIGHT_AA ||
            s.type == Objectives::BuildingType::T1_MEDIUM_AA ||
            s.type == Objectives::BuildingType::T1_LIGHT_TURRET ||
            s.type == Objectives::BuildingType::T1_MED_TURRET ||
            s.type == Objectives::BuildingType::T1_ARTY ||
            s.type == Objectives::BuildingType::T1_TORP ||
            s.type == Objectives::BuildingType::T2_FLAK_AA ||
            s.type == Objectives::BuildingType::T2_RANGE_AA ||
            s.type == Objectives::BuildingType::T2_MED_TURRET ||
            s.type == Objectives::BuildingType::T2_ARTY ||
            s.type == Objectives::BuildingType::LRPC ||
            s.type == Objectives::BuildingType::LRPC_HEAVY
        ) {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Using BUILDER enqueue for defence unit '" + resolvedUnitName + "'", 2);
            @task = Builder::EnqueueByBuildingType(side, s.type, anchor, /*shake*/ shake, /*timeout*/ 800 * SECOND, s.priority);
        } else {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Using generic build enqueue for unit '" + resolvedUnitName + "' (btype=" + int(btype) + ")", 2);
            @task = aiBuilderMgr.Enqueue(
                TaskB::Common(btype, s.priority, def, anchor, /*shake*/ shake, /*active*/ true, /*timeout*/ 800 * SECOND)
            );
        }

        GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Enqueued unit '" + resolvedUnitName + "' for objective '" + currentObjective.id + "' (step " + stepIndex + ")", 2);

        if (task is null) {
            ObjectiveHelpers::Unassign(currentObjective.id);
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Failed to enqueue task for unit '" + resolvedUnitName + "' (step " + stepIndex + ")", 3);
            return null;
        }

        ObjectiveHelpers::IncrementDefenseQueued(currentObjective.id, unitNameForCount, 1);
        ObjectiveHelpers::Unassign(currentObjective.id);
        GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Enqueued End/Return '" + unitNameForCount + "' for objective '" + currentObjective.id + "' (step " + stepIndex + ")", 2);
        // Note: per-builder task mapping is handled centrally in Builder::AiMakeTask; do not set here


        return task;
    }

    // Determine whether all chain steps are satisfied for an objective.
    // Returns 'true' if all steps (that exist) are satisfied; 'hasAnyStep' is set to true if at least one step exists.
    bool AreAllChainStepsSatisfied(const Objectives::StrategicObjective@ objective, const string &in side, bool &out hasAnyStep)
    {
        hasAnyStep = false;
        if (objective is null) return false;

        bool allSatisfied = true;
        // Determine if this objective is intended for sea/hover-sea roles (to prefer tidal for T1 energy)
        bool isSeaRole = IsSeaOrHoverObjective(objective);
        for (uint stepIndex = 0; stepIndex < objective.steps.length(); ++stepIndex) {
            auto@ step = objective.steps[stepIndex];
            if (step is null) continue;
            hasAnyStep = true;

            // Resolve the concrete unit name to track progress for this step
            string unitNameToCheck = UnitHelpers::GetObjectiveUnitNameForSide(side, step.type);
            // if (isSeaRole) {
            //     if (step.type == Objectives::BuildingType::T1_ENERGY) {
            //         unitNameToCheck = UnitHelpers::GetTidalNameForSide(side);
            //     } else if (step.type == Objectives::BuildingType::T1_LIGHT_AA) {
            //         unitNameToCheck = UnitHelpers::GetFloatingAALightNameForSide(side);
            //     } else if (step.type == Objectives::BuildingType::T1_MEDIUM_AA) {
            //         unitNameToCheck = UnitHelpers::GetFloatingAARangeNameForSide(side);
            //     } else if (step.type == Objectives::BuildingType::T2_FLAK_AA || step.type == Objectives::BuildingType::T2_RANGE_AA) {
            //         unitNameToCheck = UnitHelpers::GetFloatingAARangeNameForSide(side);
            //     } else if (step.type == Objectives::BuildingType::T1_LIGHT_TURRET || step.type == Objectives::BuildingType::T1_MED_TURRET) {
            //         unitNameToCheck = UnitHelpers::GetFloatingHeavyLaserNameForSide(side);
            //     } else if (step.type == Objectives::BuildingType::T2_MED_TURRET) {
            //         unitNameToCheck = UnitHelpers::GetFloatingHeavyTurretNameForSide(side);
            //     }
            // }
            if (unitNameToCheck.length() == 0) { allSatisfied = false; break; }

            // Satisfaction uses BUILT count only; queued does not count as satisfied.
            int queuedCount = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(objective.id, unitNameToCheck);
            int builtCount  = ObjectiveHelpers::GetObjectiveBuildingsBuiltCount(objective.id, unitNameToCheck);

            if (builtCount < step.count || !ObjectiveHelpers::StepEcoSatisfied(step)) { allSatisfied = false; break; }

            GenericHelpers::LogUtil("[ObjectiveExecutor] Step " + stepIndex + " satisfied for objective '" + objective.id + "'", 2);
        }
        return allSatisfied;
    }

    // Execute next chain step if possible; returns a task when one is enqueued, else null
    IUnitTask@ ExecuteNextChainStep(Objectives::StrategicObjective@ currentObjective, const string &in side, const AIFloat3 &in anchor, const string &in label)
    {
        GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Executing next chain step for objective '" + (currentObjective is null ? "<null>" : currentObjective.id) + "'", 2);
        IUnitTask@ result = null;
        if (currentObjective is null) return result;

        // Determine if this objective is intended for sea/hover-sea roles (to prefer tidal for T1 energy)
        bool isSeaRole = IsSeaOrHoverObjective(currentObjective);

        // Completion check: all steps satisfied by progress (max of built/queued)
        bool hasStep = false;
        bool allSatisfied = AreAllChainStepsSatisfied(currentObjective, side, hasStep);

        GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Objective '" + currentObjective.id + "' hasStep=" + hasStep + " allSatisfied=" + allSatisfied, 2);
        
        if (!(hasStep && allSatisfied)) {
            // Find and enqueue the next actionable step
            @result = EnqueueNextActionableStep(currentObjective, side, anchor, label, isSeaRole);
        } else {
            // All steps satisfied
            ObjectiveHelpers::Complete(currentObjective.id);
        }

        return result;
    }
    // Removed ExecuteFirstTypeStep: callers should use ExecuteNextChainStep which handles single-step objectives too.

    // Scan objective steps and enqueue the first actionable one. Returns the created task or null.
    IUnitTask@ EnqueueNextActionableStep(
        Objectives::StrategicObjective@ objective,
        const string &in side,
        const AIFloat3 &in anchor,
        const string &in label,
        bool isSeaRole
    )
    {
        if (objective is null) return null;
        for (uint stepIndex = 0; stepIndex < objective.steps.length(); ++stepIndex) {
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Checking step " + stepIndex + " for objective '" + objective.id + "'", 2);

            const Objectives::ObjectiveStep@ step = objective.steps[stepIndex];
            if (step is null) continue;

            if (!ObjectiveHelpers::StepEcoSatisfied(step)) {
                GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": eco gate not satisfied (minM=" + step.minMetalIncome + ", minE=" + step.minEnergyIncome + ")", 3);
                continue;
            }

            // Resolve unit name for this step. For SEA/HOVER, prefer floating variants for defences and tidal for energy.
            string unitName = UnitHelpers::GetObjectiveUnitNameForSide(side, step.type);
            // if (isSeaRole) {
            //     if (step.type == Objectives::BuildingType::T1_ENERGY) {
            //         string tidalName = UnitHelpers::GetTidalNameForSide(side);
            //         if (tidalName.length() > 0) unitName = tidalName;
            //     }
            //     // AA & Turrets: map to floating counterparts when operating over sea/hover.
            //     else if (step.type == Objectives::BuildingType::T1_LIGHT_AA) {
            //         string fl = UnitHelpers::GetFloatingAALightNameForSide(side);
            //         if (fl.length() > 0) unitName = fl;
            //     }
            //     else if (step.type == Objectives::BuildingType::T1_MEDIUM_AA) {
            //         // No distinct floating heavy AA; use floating missile battery as a stronger AA
            //         string fr = UnitHelpers::GetFloatingAARangeNameForSide(side);
            //         if (fr.length() > 0) unitName = fr;
            //     }
            //     else if (step.type == Objectives::BuildingType::T2_FLAK_AA || step.type == Objectives::BuildingType::T2_RANGE_AA) {
            //         // Prefer floating long-range AA to ensure placement over water
            //         string fr2 = UnitHelpers::GetFloatingAARangeNameForSide(side);
            //         if (fr2.length() > 0) unitName = fr2;
            //     }
            //     else if (step.type == Objectives::BuildingType::T1_LIGHT_TURRET || step.type == Objectives::BuildingType::T1_MED_TURRET) {
            //         string fllt = UnitHelpers::GetFloatingHeavyLaserNameForSide(side);
            //         if (fllt.length() > 0) unitName = fllt;
            //     }
            //     else if (step.type == Objectives::BuildingType::T2_MED_TURRET) {
            //         string fheavy = UnitHelpers::GetFloatingHeavyTurretNameForSide(side);
            //         if (fheavy.length() > 0) unitName = fheavy;
            //     }
            // }
            
            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Resolved unit name for step " + stepIndex + ": '" + unitName + "'", 2);
            if (unitName.length() == 0) {
                GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": unresolved unit name for type=" + int(step.type), 3);
                continue;
            }

            // For actionable step selection: built defines satisfaction; queued gates further enqueues.
            int queued = ObjectiveHelpers::GetObjectiveBuildingsQueuedCount(objective.id, unitName);
            int built  = ObjectiveHelpers::GetObjectiveBuildingsBuiltCount(objective.id, unitName);

            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Step " + stepIndex + " progress check: queued=" + queued + " built=" + built + " required=" + step.count, 2);

            // If we've built enough, this step is satisfied.
            if (built >= step.count) {
                GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Skip step " + stepIndex + ": satisfied by built count (" + built + "/" + step.count + ") for unit='" + unitName + "'", 3);
                continue;
            }
            // If we've already queued enough, hold and wait for completion (do not advance to later steps).
            if (queued >= step.count) {
                GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Hold step " + stepIndex + ": queued meets requirement (" + queued + "/" + step.count + ") awaiting construction for unit='" + unitName + "'", 2);
                return null; // don't enqueue more, don't move to next steps
            }

            GenericHelpers::LogUtil("[ObjectiveExecutor][" + label + "] Processing step " + stepIndex + " for objective '" + objective.id + "' unit='" + unitName + "' progress=" + built + "/" + step.count, 2);

            IUnitTask@ task = TryEnqueueStep(objective, side, anchor, label, stepIndex, step, unitName, isSeaRole);
            if (task is null) continue;
            return task;
        }
        return null;
    }
}
