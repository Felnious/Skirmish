// Map configuration definitions (unit limits + optional start spots)
// Extended 2025-09: added StartSpots support for map-aware logic (e.g., Supreme Isthmus)
// Extended 2025-10: optional FactoryWeights per role enabling weighted random selection of opening factory.
// FactoryWeights schema (v2 side-specific):
//   FactoryWeights["FRONT"] = dictionary{ "armada" => dict{factory->weight}, "cortex" => dict{...}, "legion" => dict{...} }
//     Example: FactoryWeights["FRONT"].get("armada", @dict) where dict["armlab"] = 5, dict["armvp"] = 2
// Backward compatible (v1 flat) still supported:
//   FactoryWeights["FRONT"] = dictionary{ factoryName -> weight(int) } (legacy prefix-filter path)
// Roles keys: FRONT, FRONT_TECH, AIR, SEA, TECH
// Selection order:
//   1. If role dictionary contains a side key ("armada"/"cortex"/"legion"), use only that nested dictionary (strict side filtering).
//   2. Else, treat role dictionary as flat factory->weight table and filter by factory name prefix (legacy behavior).
//   3. If invalid/empty, fallback to legacy deterministic mapping.
#include "../helpers/map_helpers.as"
#include "../helpers/generic_helpers.as"
#include "start_spot.as"
#include "strategic_objectives.as"

class MapConfig {  
    string _mapNameMatch;
    dictionary UnitLimits;
    // Optional: per-role unit limit overlays (roleKey -> dictionary of unitName->limit)
    dictionary RoleUnitLimitOverlays;
    StartSpot@[] StartSpots; // optional list of predefined start spots (may be empty)
    dictionary FactoryWeights; // optional: role -> (dictionary of factoryName -> weight)
    array<Objectives::StrategicObjective@> Objectives;  // optional list of strategic objectives

    MapConfig(string mapNameMatch, dictionary unitLimits) {
        _mapNameMatch = mapNameMatch;
        UnitLimits = unitLimits;
    }

    // Extended constructor with start spots
    MapConfig(string mapNameMatch, dictionary unitLimits, StartSpot@[]@ startSpots) {
        _mapNameMatch = mapNameMatch;
        UnitLimits = unitLimits;
        if (startSpots !is null) {
            for (uint i = 0; i < startSpots.length(); ++i) {
                StartSpots.insertLast(startSpots[i]);
            }
        }
    }

    // Full constructor with start spots and factory weight table
    MapConfig(string mapNameMatch, dictionary unitLimits, StartSpot@[]@ startSpots, dictionary@ factoryWeights) {
        _mapNameMatch = mapNameMatch;
        UnitLimits = unitLimits;
        if (startSpots !is null) {
            for (uint i = 0; i < startSpots.length(); ++i) {
                StartSpots.insertLast(startSpots[i]);
            }
        }
        if (factoryWeights !is null) {
            array<string>@ keys = factoryWeights.getKeys();
            for (uint i = 0; i < keys.length(); ++i) {
                // store nested role weight dictionaries by reference
                dictionary@ roleDict;
                if (factoryWeights.get(keys[i], @roleDict)) {
                    FactoryWeights.set(keys[i], @roleDict);
                }
            }
        }
    }

    // Constructor with role-specific unit limit overlays
    MapConfig(string mapNameMatch, dictionary unitLimits, dictionary@ roleUnitLimitOverlays) {
        _mapNameMatch = mapNameMatch;
        UnitLimits = unitLimits;
        SetRoleUnitLimitOverlays(roleUnitLimitOverlays);
    }

    // Full constructor with start spots, factory weights, and role overlays
    MapConfig(string mapNameMatch, dictionary unitLimits, StartSpot@[]@ startSpots, dictionary@ factoryWeights, dictionary@ roleUnitLimitOverlays) {
        _mapNameMatch = mapNameMatch;
        UnitLimits = unitLimits;
        if (startSpots !is null) {
            for (uint i = 0; i < startSpots.length(); ++i) {
                StartSpots.insertLast(startSpots[i]);
            }
        }
        if (factoryWeights !is null) {
            array<string>@ keys = factoryWeights.getKeys();
            for (uint i = 0; i < keys.length(); ++i) {
                dictionary@ roleDict;
                if (factoryWeights.get(keys[i], @roleDict)) {
                    FactoryWeights.set(keys[i], @roleDict);
                }
            }
        }
        SetRoleUnitLimitOverlays(roleUnitLimitOverlays);
    }

    MapConfig() {
        _mapNameMatch = "";
    }

    // Helper: convert AiRole to canonical string key used in FactoryWeights
    string RoleKey(AiRole role) const {
        if (role == AiRole::FRONT) return "FRONT";
        if (role == AiRole::AIR) return "AIR";
        if (role == AiRole::TECH) return "TECH";
        if (role == AiRole::FRONT_TECH) return "FRONT_TECH";
        if (role == AiRole::SEA) return "SEA";
        if (role == AiRole::HOVER_SEA) return "HOVER_SEA";
        return "UNKNOWN";
    }

    bool HasFactoryWeights(AiRole role) {
        string key = RoleKey(role);
        dictionary@ dummy;
        return FactoryWeights.get(key, @dummy);
    }

    dictionary@ GetSideFactoryWeightsByRole(AiRole role) {
        string key = RoleKey(role);
        dictionary@ roleDict;
        if (FactoryWeights.get(key, @roleDict)) return roleDict;
        return null;
    }

    void AddObjective(Objectives::StrategicObjective@ o) {
        if (o !is null) Objectives.insertLast(o);
    }

    // Configure per-role unit limit overlays: input is a dictionary of roleKey -> dictionary(unitName->limit)
    void SetRoleUnitLimitOverlays(dictionary@ overlaysByRole) {
        if (overlaysByRole is null) return;
        array<string>@ keys = overlaysByRole.getKeys();
        for (uint i = 0; i < keys.length(); ++i) {
            dictionary@ limits;
            if (overlaysByRole.get(keys[i], @limits)) {
                // store the limits dictionary handle for that role key
                RoleUnitLimitOverlays.set(keys[i], @limits);
            }
        }
    }

    // Back-compat setter: forward to new API
    void SetRoleUnitLimits(dictionary@ byRole) { SetRoleUnitLimitOverlays(byRole); }

    // Get per-role unit limit overlay for a given role; may return null if none set
    dictionary@ GetRoleUnitLimitOverlayFor(AiRole role) {
        string key = RoleKey(role);
        dictionary@ limits;
        if (RoleUnitLimitOverlays.get(key, @limits)) return limits;
        return null;
    }

    // Back-compat getter: forward to new API
    dictionary@ GetRoleUnitLimitsFor(AiRole role) { return GetRoleUnitLimitOverlayFor(role); }

    // Check if the provided map name contains the _mapNameMatch as a prefix
    bool CheckMatch(string mapName) {
        GenericHelpers::LogUtil("CheckMatch:MapName:" + mapName, 5);
        GenericHelpers::LogUtil("CheckMatch:_mapNameMatch:" + _mapNameMatch, 5);
        return mapName.findFirst(_mapNameMatch) == 0;
    }
}

class MapConfigManager {  
    // Array to store MapConfig objects
    array<MapConfig> mapConfigs;

    // Default MapConfig
    MapConfig defaultMapConfig;

    // Constructor with default MapConfig
    MapConfigManager(MapConfig defaultConfig) {
        defaultMapConfig = defaultConfig;
    }

    // Default constructor
    MapConfigManager() {
        defaultMapConfig = MapConfig();
    }

    // Register a MapConfig by adding it to the array
    void RegisterMapConfig(MapConfig mapConfig) {
        mapConfigs.insertLast(mapConfig);
        GenericHelpers::LogUtil("Registered MapConfig for map match: " + mapConfig._mapNameMatch, 1);
    }

    // Retrieve a MapConfig by map name (partial match)
	// Input parameter has full name, while map config uses a partial
    MapConfig getMapConfig(string mapName) {
        GenericHelpers::LogUtil("getMapConfig() Input Map Name: " + mapName, 1);

        for (uint i = 0; i < mapConfigs.length(); i++) {
			if (mapConfigs[i] is null) {
				GenericHelpers::LogUtil("getMapConfig() mapConfigs[" + i + "] is null!", 4);
				continue;
			}
			MapConfig mapConfig = mapConfigs[i];

			GenericHelpers::LogUtil("getMapConfig() mapConfigs[i]: " + mapConfig._mapNameMatch, 1);
			
            if (mapConfigs[i].CheckMatch(mapName)) {
				GenericHelpers::LogUtil("getMapConfig() return mapConfigs[i]; " + mapName, 4);
                return mapConfig;
            }
        }

        GenericHelpers::LogUtil("No match found, returning default configuration", 1);
        return defaultMapConfig;
    }
}