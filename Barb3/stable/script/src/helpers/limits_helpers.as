#include "../global.as"
#include "generic_helpers.as"
#include "../types/map_config.as"
#include "../types/ai_role.as"

namespace LimitsHelpers {
    // Clear all keys from a dictionary
    void ClearDictionary(dictionary@ d) {
        if (d is null) return;
        array<string>@ keys = d.getKeys();
        for (uint i = 0; i < keys.length(); ++i) {
            d.delete(keys[i]);
        }
    }

    // Copy unit limit value as int
    void CopyUnitLimitInt(dictionary@ src, const string &in key, dictionary@ dst) {
        if (src is null || dst is null) return;
        int value = 0;
        if (src.get(key, value)) {
            dst.set(key, value);
        }
    }

    // Merge base UnitLimits with a role overlay and store in Global::Map::MergedUnitLimits
    dictionary@ ComputeAndStoreMergedUnitLimits(MapConfig@ mapCfg, AiRole role) {
        ClearDictionary(@Global::Map::MergedUnitLimits);

        if (mapCfg is null) {
            GenericHelpers::LogUtil("[Limits] No MapConfig; merged limits remain empty", 2);
            return Global::Map::MergedUnitLimits;
        }

        // Copy base limits
        dictionary baseLimits = mapCfg.UnitLimits;
        array<string>@ baseKeys = baseLimits.getKeys();
        for (uint i = 0; i < baseKeys.length(); ++i) {
            CopyUnitLimitInt(@baseLimits, baseKeys[i], @Global::Map::MergedUnitLimits);
        }

        // Overlay role-specific limits (if any)
        dictionary@ roleOverlay = mapCfg.GetRoleUnitLimitsFor(role);
        if (roleOverlay !is null) {
            array<string>@ roleKeys = roleOverlay.getKeys();
            for (uint j = 0; j < roleKeys.length(); ++j) {
                CopyUnitLimitInt(@roleOverlay, roleKeys[j], @Global::Map::MergedUnitLimits);
            }
        }

        GenericHelpers::LogUtil("[Limits] Merged unit limits applied for role=" + int(role) + " entries=" + Global::Map::MergedUnitLimits.getKeys().length(), 3);
        return Global::Map::MergedUnitLimits;
    }
}
