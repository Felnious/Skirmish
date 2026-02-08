#include "../define.as"
#include "../unit.as"
#include "../task.as"
#include "generic_helpers.as"

namespace GuardHelpers {

    // Assign a worker to guard another worker.
    // Returns a created task handle on success; null on failure.
    IUnitTask@ AssignWorkerGuard(CCircuitUnit@ guard, CCircuitUnit@ target,
                                 Task::Priority prio = Task::Priority::HIGH,
                                 bool interrupt = true,
                                 int timeout = 15 * SECOND)
    {
        if (guard is null || target is null) {
            GenericHelpers::LogUtil("[Guard] guard or target is null", 2);
            return null;
        }
        if (guard is target) {
            GenericHelpers::LogUtil("[Guard] refusing to guard self id=" + guard.id, 3);
            return null;
        }

        const CCircuitDef@ gdef = guard.circuitDef;
        const CCircuitDef@ tdef = target.circuitDef;
        if (gdef is null || tdef is null) {
            GenericHelpers::LogUtil("[Guard] missing circuitDef for guard/target", 2);
            return null;
        }

        // Ensure both are builders (workers)
        if (!gdef.IsRoleAny(Unit::Role::BUILDER.mask)) {
            GenericHelpers::LogUtil("[Guard] guard unit is not a builder: id=" + guard.id + " name=" + gdef.GetName(), 3);
            return null;
        }
        // if (!tdef.IsRoleAny(Unit::Role::BUILDER.mask)) {
        //     GenericHelpers::LogUtil("[Guard] target unit is not a builder: id=" + target.id + " name=" + tdef.GetName(), 3);
        //     return null;
        // }

        IUnitTask@ task = aiBuilderMgr.Enqueue(
            TaskB::Guard(prio, target, interrupt, timeout)
        );
        if (task is null) {
            GenericHelpers::LogUtil("[Guard] failed to enqueue guard task for guard id=" + guard.id + " -> target id=" + target.id, 2);
            return null;
        }

        GenericHelpers::LogUtil("[Guard] assigned guard id=" + guard.id + " -> target id=" + target.id +
                                " prio=" + prio + " timeoutFrames=" + timeout, 2);
        return task;
    }

    // ---------------------------
    // Generic guard distribution
    // ---------------------------

    // A generic bucket representing a guard target (leader) and its assigned guards.
    class GuardBucket {
        string name;
        CCircuitUnit@ leader;      // Target to guard
        dictionary@ guards;        // Map: worker.id -> CCircuitUnit@ worker
        float weight;              // Desired relative weight (>= 0). Will be normalized across eligible buckets.

        GuardBucket() {}

        GuardBucket(const string &in name, CCircuitUnit@ leader, dictionary@ guards, float weight)
        {
            this.name = name;
            @this.leader = leader;
            @this.guards = guards;
            this.weight = weight;
        }
    }

    int CountDict(dictionary@ d)
    {
        if (d is null) return 0;
        array<string>@ keys = d.getKeys();
        return (keys is null ? 0 : keys.length());
    }

    // Remove a worker from all provided buckets
    void RemoveFromAllBuckets(CCircuitUnit@ worker, array<GuardBucket@>@ buckets)
    {
        if (worker is null || buckets is null) return;
        string key = "" + worker.id;
        for (uint i = 0; i < buckets.length(); ++i) {
            GuardBucket@ b = buckets[i];
            if (b is null || b.guards is null) continue;
            b.guards.delete(key);
        }
    }

    // Assign a worker to a bucket to move observed shares toward target weights.
    void DistributeGuardsByWeights(CCircuitUnit@ worker, array<GuardBucket@>@ buckets)
    {
        if (worker is null || buckets is null || buckets.length() == 0) return;

        // Collect eligible buckets (must have a leader and a guards map)
        array<int> eligible;
        float weightSum = 0.0f;
        for (uint i = 0; i < buckets.length(); ++i) {
            GuardBucket@ b = buckets[i];
            if (b is null || b.leader is null || b.guards is null) continue;
            eligible.insertLast(i);
            float w = (b.weight < 0.0f ? 0.0f : b.weight);
            weightSum += w;
        }
        if (eligible.length() == 0) return;

        // Compute target shares (normalized weights or equal split if sum is zero)
        array<float> targetShare(buckets.length(), 0.0f);
        if (weightSum <= 0.0f) {
            float eq = 1.0f / float(eligible.length());
            for (uint k = 0; k < eligible.length(); ++k) targetShare[eligible[k]] = eq;
        } else {
            for (uint k = 0; k < eligible.length(); ++k) {
                int idx = eligible[k];
                float w = (buckets[idx].weight < 0.0f ? 0.0f : buckets[idx].weight);
                targetShare[idx] = w / weightSum;
            }
        }

        // Current counts and total
        array<int> counts(buckets.length(), 0);
        int total = 0;
        for (uint k = 0; k < eligible.length(); ++k) {
            int idx2 = eligible[k];
            int c = CountDict(buckets[idx2].guards);
            counts[idx2] = c;
            total += c;
        }

        // Pick bucket with highest deficit (target - currentShare); if none assigned yet, pick highest target share
        int chosen = eligible[0];
        if (total == 0) {
            float best = -1.0f;
            for (uint k = 0; k < eligible.length(); ++k) {
                int idx3 = eligible[k];
                if (targetShare[idx3] > best) { best = targetShare[idx3]; chosen = idx3; }
            }
        } else {
            float bestDeficit = -9999.0f;
            for (uint k = 0; k < eligible.length(); ++k) {
                int idx4 = eligible[k];
                float currentShare = (total > 0 ? float(counts[idx4]) / float(total) : 0.0f);
                float deficit = targetShare[idx4] - currentShare;
                if (deficit > bestDeficit) { bestDeficit = deficit; chosen = idx4; }
            }
        }

        // Move worker to the chosen bucket
        RemoveFromAllBuckets(worker, buckets);
        GuardBucket@ target = buckets[chosen];
        if (target !is null && target.guards !is null) {
            string key = "" + worker.id;
            target.guards.set(key, @worker);
        }
    }

    // Convenience for two-bucket ratio (primary vs secondary)
    void DistributeGuardsByRatio2(CCircuitUnit@ worker, float primaryRatio,
        CCircuitUnit@ primary, dictionary@ primaryGuards,
        CCircuitUnit@ secondary, dictionary@ secondaryGuards)
    {
        if (primaryRatio < 0.0f) primaryRatio = 0.0f;
        if (primaryRatio > 1.0f) primaryRatio = 1.0f;

        GuardBucket p("primary", primary, primaryGuards, primaryRatio);
        GuardBucket s("secondary", secondary, secondaryGuards, 1.0f - primaryRatio);
        array<GuardBucket@> buckets = { @p, @s };
        DistributeGuardsByWeights(worker, buckets);
    }
}
