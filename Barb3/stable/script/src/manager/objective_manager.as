#include "../helpers/objective_helpers.as"
#include "../global.as"
#include "../types/strategic_objectives.as"

namespace ObjectiveManager {
    // Local state: assignment and completion tracking
    // NOTE: "assignment" replaces older "claim" terminology to avoid ambiguity with reclaim
    dictionary _assigned; // id -> assignee (string)
    dictionary _done;     // id -> true

    // Optional high-level state per objective (simple enum)
    enum ObjectiveState { UNKNOWN = 0, ASSIGNED = 1, DEFENSE_QUEUED = 2, DEFENSE_BUILT = 3, COMPLETED = 4 }
    dictionary _state; // id -> int(ObjectiveState)

    // Per-objective defense tracking: counts per defense type
    // _defenseQueued[id] -> dictionary(type -> int count)
    // _defenseBuilt[id]  -> dictionary(type -> int count)
    dictionary _defenseQueued;
    dictionary _defenseBuilt;

    // Per-role selected objective by builder group
    // key: role + ":" + int(group) -> @StrategicObjective
    dictionary _selectedPerRoleGroup;

    string _makeRoleGroupKey(AiRole role, Objectives::BuilderGroup group) {
        return "" + int(role) + ":" + int(group);
    }

    void SetSelectedForGroup(AiRole role, Objectives::BuilderGroup group, Objectives::StrategicObjective@ obj) {
        string key = _makeRoleGroupKey(role, group);
        if (@obj is null) {
            if (_selectedPerRoleGroup.exists(key)) _selectedPerRoleGroup.delete(key);
            return;
        }
        _selectedPerRoleGroup.set(key, @obj);
    }

    Objectives::StrategicObjective@ GetSelectedForGroup(AiRole role, Objectives::BuilderGroup group) {
        string key = _makeRoleGroupKey(role, group);
        Objectives::StrategicObjective@ obj = null;
        if (_selectedPerRoleGroup.get(key, @obj)) {
            return obj;
        }
        return null;
    }

    // Default objective base range when not specified per-objective
    const float DEFAULT_OBJECTIVE_BASE_RANGE = 2500.0f;

    // State accessors
    bool IsAssigned(const string &in id) { return _assigned.exists(id); }
    bool IsCompleted(const string &in id) { return _done.exists(id); }

    bool TryAssign(const string &in id, const string &in who) {
        if (IsAssigned(id) || IsCompleted(id)) return false;
        _assigned.set(id, who);
        _state.set(id, int(ObjectiveState::ASSIGNED));
        return true;
    }
    string GetAssignee(const string &in id) {
        if (!_assigned.exists(id)) return "";
        string who; _assigned.get(id, who); return who;
    }
    void Unassign(const string &in id) {
        if (_assigned.exists(id)) _assigned.delete(id);
        // If unassigned and not otherwise advanced, fall back to UNKNOWN
        if (!_done.exists(id)) {
            _state.set(id, int(ObjectiveState::UNKNOWN));
        }
    }
    void Complete(const string &in id) {
        if (_assigned.exists(id)) _assigned.delete(id);
        _done.set(id, true);
        _state.set(id, int(ObjectiveState::COMPLETED));
    }

    // High-level state management
    void SetState(const string &in id, int state) { _state.set(id, state); }
    int GetState(const string &in id) {
        if (_state.exists(id)) {
            int s = 0; _state.get(id, s); return s;
        }
        return int(ObjectiveState::UNKNOWN);
    }

    // ---- Defense tracking APIs ----
    // Internal: fetch or create nested dictionary for a given objective id
    dictionary@ _ensureMap(dictionary &inout root, const string &in id) {
        dictionary@ m = null;
        if (root.get(id, @m) && m !is null) {
            return m;
        }
        // Create and store a handle to the nested dictionary
        dictionary@ created = dictionary();
        root.set(id, @created);
        // Retrieve handle back
        dictionary@ m2 = null; root.get(id, @m2);
        return m2;
    }

    // Increment queued defenses for objective id/type by count (default 1)
    void IncrementDefenseQueued(const string &in id, const string &in defType, int count = 1) {
        if (count <= 0) return;
        dictionary@ m = _ensureMap(_defenseQueued, id);
        int currentCount = 0; if (m.exists(defType)) m.get(defType, currentCount);
        m.set(defType, currentCount + count);
        // State hint
        if (!_done.exists(id)) _state.set(id, int(ObjectiveState::DEFENSE_QUEUED));
    }

    // Increment built defenses for objective id/type by count (default 1)
    void IncrementDefenseBuilt(const string &in id, const string &in defType, int count = 1) {
        if (count <= 0) return;
        dictionary@ m = _ensureMap(_defenseBuilt, id);
        int currentCount = 0; if (m.exists(defType)) m.get(defType, currentCount);
        m.set(defType, currentCount + count);
        // State hint
        if (!_done.exists(id)) _state.set(id, int(ObjectiveState::DEFENSE_BUILT));
    }

    // Get count for specific type
    // Count of buildings queued for a specific objective and unit type
    int GetObjectiveBuildingsQueuedCount(const string &in id, const string &in defType) {
        dictionary@ m = null; if (_defenseQueued.get(id, @m) && m !is null) {
            if (m.exists(defType)) { int v = 0; m.get(defType, v); return v; }
        }
        return 0;
    }
    // Count of buildings completed for a specific objective and unit type
    int GetObjectiveBuildingsBuiltCount(const string &in id, const string &in defType) {
        dictionary@ m = null; if (_defenseBuilt.get(id, @m) && m !is null) {
            if (m.exists(defType)) { int v = 0; m.get(defType, v); return v; }
        }
        return 0;
    }

    // Get totals across all types
    int GetDefenseQueuedTotal(const string &in id) {
        int total = 0; dictionary@ m = null; if (_defenseQueued.get(id, @m) && m !is null) {
            array<string>@ keys = m.getKeys();
            if (keys !is null) {
                for (uint i = 0; i < keys.length(); ++i) { int v = 0; m.get(keys[i], v); total += v; }
            }
        }
        return total;
    }
    int GetDefenseBuiltTotal(const string &in id) {
        int total = 0; dictionary@ m = null; if (_defenseBuilt.get(id, @m) && m !is null) {
            array<string>@ keys = m.getKeys();
            if (keys !is null) {
                for (uint i = 0; i < keys.length(); ++i) { int v = 0; m.get(keys[i], v); total += v; }
            }
        }
        return total;
    }

    // Get list of defense types tracked (keys)
    array<string> GetDefenseQueuedTypes(const string &in id) {
        array<string> types;
        dictionary@ m = null; if (_defenseQueued.get(id, @m) && m !is null) {
            array<string>@ keys = m.getKeys();
            if (keys !is null) { for (uint i = 0; i < keys.length(); ++i) types.insertLast(keys[i]); }
        }
        return types;
    }
    array<string> GetDefenseBuiltTypes(const string &in id) {
        array<string> types;
        dictionary@ m = null; if (_defenseBuilt.get(id, @m) && m !is null) {
            array<string>@ keys = m.getKeys();
            if (keys !is null) { for (uint i = 0; i < keys.length(); ++i) types.insertLast(keys[i]); }
        }
        return types;
    }

    // Reset all defense tracking for an objective
    void ResetDefenseState(const string &in id) {
        if (_defenseQueued.exists(id)) _defenseQueued.delete(id);
        if (_defenseBuilt.exists(id)) _defenseBuilt.delete(id);
    }

    // Retrieve all objectives from current map config
    array<Objectives::StrategicObjective@>@ GetAll() {
        return Global::Map::Config.Objectives;
    }

    // Determine the effective base range for an objective (per-objective or default)
    float EffectiveBaseRange(const Objectives::StrategicObjective@ o) {
        if (o is null) return DEFAULT_OBJECTIVE_BASE_RANGE;
        return (o.objectiveBaseRange > 0.0f ? o.objectiveBaseRange : DEFAULT_OBJECTIVE_BASE_RANGE);
    }

    // Filter objectives by base range from Global::Map::StartPos
    array<Objectives::StrategicObjective@> FilterByBaseRange(array<Objectives::StrategicObjective@>@ src = null) {
        array<Objectives::StrategicObjective@>@ all = (src is null ? GetAll() : src);
        array<Objectives::StrategicObjective@> filtered;
        if (all is null) return filtered;
        const AIFloat3 base = Global::Map::StartPos;
        for (uint i = 0; i < all.length(); ++i) {
            Objectives::StrategicObjective@ o = all[i];
            float d = ObjectiveHelpers::DistanceFrom(base, o);
            if (d <= EffectiveBaseRange(o)) {
                filtered.insertLast(o);
            }
        }
        return filtered;
    }

    // Optional: filter by desired builder group
    array<Objectives::StrategicObjective@> FilterByBuilderGroup(array<Objectives::StrategicObjective@>@ src, Objectives::BuilderGroup group)
    {
        array<Objectives::StrategicObjective@> filtered;
        if (src is null) return filtered;
        for (uint i = 0; i < src.length(); ++i) {
            Objectives::StrategicObjective@ o = src[i];
            if (o is null) continue;
            if (o.builderGroup == group) filtered.insertLast(o);
        }
        return filtered;
    }

    // Utility: textual label for a builder group
    string GetBuilderGroupLabel(Objectives::BuilderGroup group)
    {
        if (group == Objectives::BuilderGroup::TACTICAL) return "TACTICAL";
        if (group == Objectives::BuilderGroup::PRIMARY) return "PRIMARY";
        if (group == Objectives::BuilderGroup::SECONDARY) return "SECONDARY";
        return "UNKNOWN";
    }
}
