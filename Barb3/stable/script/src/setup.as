// Helpers & Role Handlers
#include "helpers/generic_helpers.as"
#include "helpers/map_helpers.as"
#include "helpers/unit_helpers.as"
#include "helpers/role_helpers.as"
#include "helpers/limits_helpers.as"
#include "global.as"
#include "maps.as"
#include "maps/factory_mapping.as"

// Role Handlers (renamed folder)
#include "roles/front.as"
#include "roles/front_tech.as"
#include "roles/air.as"
#include "roles/tech.as"
#include "roles/sea.as"
#include "roles/hover_sea.as"

// Role configuration (unit caps / behavior tuning)
#include "types/role_config.as"

//managers
#include "manager/military.as"
#include "manager/builder.as"
#include "manager/factory.as"
#include "manager/economy.as"

namespace Factory {
	CCircuitDef@ AiGetFactoryToBuild(const AIFloat3& in pos, bool isStart, bool isReset) {
		CCircuitDef@ result = null;

		@result = GetDefaultFactory(pos, isStart, isReset);

		string factoryName = (result is null) ? "<null>" : result.GetName();
		//int factoryCount = (result is null) ? 0 : result.count;
		
		// Pre-log context
		GenericHelpers::LogUtil("[Factory] isStart=" + isStart + " isReset=" + isReset +
			" side=" + Global::AISettings::Side + " role=" + Global::AISettings::Role +
			" landLocked=" + Global::Map::LandLocked +
			" pos=(" + pos.x + "," + pos.z + ")" +
			" factoryName=" + factoryName + 
			" factoriesBuilt=" + Global::Statistics::FactoriesBuilt, 2);
		

		// Lazy initialize map/profile when real start position first known
		if (isStart && !Global::Map::MapResolved) {
			Setup::setupMap(pos);
		}

		// Select opening factory once
		if (isStart) {
			if (Global::profileController.RoleCfg !is null && Global::profileController.RoleCfg.SelectFactoryHandler !is null) {
				string fac = Global::profileController.RoleCfg.SelectFactoryHandler(pos, isStart, isReset);
				GenericHelpers::LogUtil("[Factory] Role handler returned '" + fac + "'", 2);
				CCircuitDef@ def = (fac != "") ? ai.GetCircuitDef(fac) : null;
				if (def !is null && def.IsAvailable(ai.frame)) {
					Global::AISettings::StartFactory = fac;
					@result = def;
				}
			}
		}

		if (result !is null) {
			// Safe properties: name, id, availability
			const string name = result.GetName();
			const Id id = result.id;
			const bool available = result.IsAvailable(ai.frame);
			GenericHelpers::LogUtil("[Factory] Chosen factory: name='" + name + "' id=" + id + " available=" + available, 2);
		}

		Global::Statistics::FactoriesBuilt += (result !is null) ? 1 : 0;
		return result;
	}


	CCircuitDef@ GetDefaultFactory(const AIFloat3& in pos, bool isStart, bool isReset) {
		GenericHelpers::LogUtil("call GetDefaultFactory pos=(" + pos.x + "," + pos.z + ")" + " isStart=" + isStart + " isReset=" + isReset, 4);
		return aiFactoryMgr.DefaultGetFactoryToBuild(pos, isStart, isReset);
	}
}

namespace Setup {
	ProfileController createProfileController() {
		
		ProfileController _profileController = ProfileController();
		
		return _profileController;
	}

	// Utility: conservative string -> int parser (decimal, optional leading '-')
	int ToInt(const string &in s, int fallback = 0) {
		if (s.length() == 0) return fallback;
		int sign = 1;
		uint i = 0;
		// Compare first character by ASCII code (45 = '-') to avoid char literal portability issues
		if (s[0] == 45) { sign = -1; i = 1; }
		int val = 0;
		for (; i < s.length(); ++i) {
			const uint c = s[i];
			// 48 = '0', 57 = '9'
			if (c < 48 || c > 57) break;
			val = val * 10 + int(c - 48);
		}
		return sign * val;
	}

	bool ToBool(const string &in s) {
		return (s == "1" || s == "true" || s == "True" || s == "TRUE");
	}

	// Try to print a GameRules param if present (float or string), using LogUtil
	void PrintRuleIfSet(const string &in scope, const string &in key) {
		const float fv = ai.GetGameRulesParam(key, -9.876543f);
		if (fv != -9.876543f) {
			GenericHelpers::LogUtil("[Rules:" + scope + "] " + key + " = " + fv, 3);
			return;
		}
		const string sv = ai.GetGameRulesParam(key, "");
		if (sv != "") {
			GenericHelpers::LogUtil("[Rules:" + scope + "] " + key + " = '" + sv + "'", 3);
		}
	}

	// Try to print a TeamRules param if present (float or string), using LogUtil
	void PrintTeamRuleIfSet(const string &in scope, const string &in key) {
		const float fv = ai.GetTeamRulesParam(key, -9.876543f);
		if (fv != -9.876543f) {
			GenericHelpers::LogUtil("[TeamRules:" + scope + "] " + key + " = " + fv, 3);
			return;
		}
		const string sv = ai.GetTeamRulesParam(key, "");
		if (sv != "") {
			GenericHelpers::LogUtil("[TeamRules:" + scope + "] " + key + " = '" + sv + "'", 3);
		}
	}

	// Attempt to read a float GameRules param with a primary key and fallback alt key; log if found
	void PrintRuleFloatWithFallback(const string &in label, const string &in primaryKey, const string &in altKey) {
		float v = ai.GetGameRulesParam(primaryKey, -1.0f);
		if (v < 0.0f) v = ai.GetGameRulesParam(altKey, -1.0f);
		if (v >= 0.0f) {
			GenericHelpers::LogUtil("[Rules:Game] " + label + " = " + v, 2);
		}
	}

	// Prints a snapshot of map/terrain info available at setup time.
	// Note: The engine API currently exposes map name and mod options. A direct water coverage percentage API
	// is not available in these scripts; we log map_waterlevel if present and mark percentage as N/A.
	void PrintMapInfo(const AIFloat3& in startPos) {
		const string mapName = Global::Map::MapName;
		const bool landLocked = Global::Map::LandLocked;
		const string side = Global::AISettings::Side;
		const AiRole role = Global::AISettings::Role;
		const int roleInt = int(role); // explicit numeric to avoid enum -> string ambiguity

		// MapConfig summary
		const string cfgName = Global::Map::Config._mapNameMatch;
		const int unitLimitKeyCount = int(Global::Map::Config.UnitLimits.getKeys().length());
		const int objectiveCount = int(Global::Map::Config.Objectives.length());

		// Start spot summary
		StartSpot@ spot = Global::Map::NearestMapStartPosition;
		string spotStr = (spot is null)
			? "<none>"
			: ("pos=(" + spot.pos.x + "," + spot.pos.z + ") landLocked=" + spot.landLocked);

		// FactoryWeights summary for selected role and side (if any)
		dictionary@ roleWeights = Global::Map::Config.GetSideFactoryWeightsByRole(role);
		int weightEntries = 0;
		if (roleWeights !is null) {
			// Prefer side-specific nested dictionary if present
			dictionary@ sideWeights;
			if (roleWeights.get(side, @sideWeights) && sideWeights !is null) {
				weightEntries = int(sideWeights.getKeys().length());
			} else {
				// Treat role dictionary as flat factory->weight table
				weightEntries = int(roleWeights.getKeys().length());
			}
		}

		// Mod options: water-related and a few general ones
		const int waterLevel = Global::ModOptions::MapWaterLevel;
		const bool waterIsLava = Global::ModOptions::MapWaterIsLava;
		const int maxUnits = Global::ModOptions::MaxUnits;

		GenericHelpers::LogUtil(
			"[MapInfo] name='" + mapName + "' cfg='" + cfgName + "' role=" + roleInt +
			" side=" + side + " landLocked=" + landLocked +
			" team=" + ("" + ai.teamId) + " allyTeam=" + ("" + ai.allyTeamId) +
			" startPos=(" + startPos.x + "," + startPos.z + ")" +
			" nearestSpot={" + spotStr + "}" +
			" unitLimitKeys=" + unitLimitKeyCount +
			" objectives=" + objectiveCount +
			" factoryWeightsForRole=" + weightEntries,
			2);

		// Water coverage: percentage unknown without terrain sampling; report water plane level if provided by mod options.
		GenericHelpers::LogUtil(
			"[MapInfo] water: percent=N/A (no API) level=" + waterLevel + " isLava=" + waterIsLava +
			" maxUnits=" + maxUnits,
			2);

		// Dump all mod options (keys/values) at debug level 3 to avoid spam at default levels
		dictionary@ mo = aiSetupMgr.GetModOptions();
		if (mo !is null) {
			array<string>@ keys = mo.getKeys();
			GenericHelpers::LogUtil("[ModOptions] count=" + keys.length(), 3);
			for (uint i = 0; i < keys.length(); ++i) {
				const string k = keys[i];
				string v;
				if (mo.get(k, v)) {
					GenericHelpers::LogUtil("  " + k + "='" + v + "'", 3);
				}
			}
			// Note: In this build the dictionary type doesn't expose Release() to scripts; rely on GC.
		} else {
			GenericHelpers::LogUtil("[ModOptions] (none)", 3);
		}

		// Probe a set of common GameRules params often mirrored by Lua gadgets
		array<string> gameKeys = {
			"startmetal", "startenergy", "mo_coop", "mo_transportenemy",
			"map_tidal", "map_windmin", "map_windmax",
			"scoremode", "scenario_name", "chicken_queendifficulty"
		};
		for (uint i = 0; i < gameKeys.length(); ++i) {
			PrintRuleIfSet("Game", gameKeys[i]);
		}
		// Explicitly attempt wind min/max with alternate keys used by some games
		PrintRuleFloatWithFallback("windMin", "map_windmin", "windMin");
		PrintRuleFloatWithFallback("windMax", "map_windmax", "windMax");

		// Probe common TeamRules params
		array<string> teamKeys = { "share_energy", "share_metal", "allyteam", "is_commander_dead" };
		const string teamScope = "Team" + ("" + ai.teamId);
		for (uint j = 0; j < teamKeys.length(); ++j) {
			PrintTeamRuleIfSet(teamScope, teamKeys[j]);
		}
	}

	void setupMap(const AIFloat3& in startPos) {
		// Guard against multiple initialization
		if (Global::Map::MapResolved) return;

		CheckModOptions();
		// Register per-role configs 
		RegisterRoles();

		Global::Map::MapName = ai.GetMapName();
		GenericHelpers::LogUtil("MAP_NAME: " + Global::Map::MapName, 1);
		Global::Map::Config = Maps::mapManager.getMapConfig(Global::Map::MapName);

		GenericHelpers::LogUtil("Selected Map Config: " + Global::Map::Config._mapNameMatch, 1);

		// Determine side directly from engine-provided team side name
		string side = ai.GetSideName();
		GenericHelpers::LogUtil("Detected side=" + side, 1);
	
		//Get the default factory recommended by CircuitAI
		string defaultFactoryName = Factory::GetDefaultFactory(startPos, true, false).GetName();

		// Determine default role for AI based on factory. To be used if no map defined role is found
		AiRole defaultRole = RoleHelpers::DefaultRoleForFactory(defaultFactoryName);

		StartSpot@[]@ spots = Global::Map::Config.StartSpots;

		int spotCount = (spots is null) ? 0 : spots.length();
		GenericHelpers::LogUtil("[Setup] StartSpots length=" + spotCount, 1);

		// if (spots is null || spots.length() == 0) {
		// 	GenericHelpers::LogUtil("[Setup] No start spots in map config; NearestMapStartPosition unset", 2);
		// 	@Global::Map::NearestMapStartPosition = null;
		// 	return;
		// } else {
		// 	@Global::Map::NearestMapStartPosition = MapHelpers::NearestSpot(startPos, spots);
		// }

		@Global::Map::NearestMapStartPosition = MapHelpers::NearestSpot(startPos, spots);
		
		AiRole derivedRole;

		if (Global::Map::NearestMapStartPosition !is null) {
			derivedRole = Global::Map::NearestMapStartPosition.aiRole;
		} else {
			derivedRole = defaultRole;
		}

		bool landLocked = (Global::Map::NearestMapStartPosition !is null) ? MapHelpers::IsLandLocked(Global::Map::NearestMapStartPosition) : false;

		Global::Map::MapResolved = true;
		Global::Map::LandLocked = landLocked;

		Global::AISettings::Role = derivedRole;
		Global::AISettings::Side = side;

		GenericHelpers::RecordStart(startPos, derivedRole);

		Global::profileController = createProfileController();

		// Terrain snapshot: comprehensive map info (best-effort). Water percent not available in current API.
		PrintMapInfo(startPos);


		//Loop all role match functions, and return first match as the role config
		RoleConfig@ matchedCfg = RoleConfigs::Match(derivedRole, side, startPos, defaultFactoryName);

		if (matchedCfg is null) {
			GenericHelpers::LogUtil("[Role] Error: No RoleConfig matched; falling back to exact role lookup for default factory" + defaultFactoryName, 3);

			GenericHelpers::LogUtil("[Role] Default Role: " + defaultRole, 2);

			matchedCfg = RoleConfigs::Match(defaultRole, side, startPos, defaultFactoryName);


			if (matchedCfg is null) {
				GenericHelpers::LogUtil("[Role] Fatal Error: No RoleConfig found for role " + derivedRole + "; AI may malfunction", 3);
			}
		}

		@Global::profileController.RoleCfg = matchedCfg;
		@Global::AISettings::RoleCfg = matchedCfg;
 
		// Apply role-specific startup limits if provided
		RoleConfigs::ApplyStartLimits();

	// Merge map + role limits, store globally, and apply.
	dictionary@ merged = LimitsHelpers::ComputeAndStoreMergedUnitLimits(Global::Map::Config, derivedRole);
		UnitHelpers::ApplyUnitLimits(merged);

		GenericHelpers::LogUtil("Setup complete role=" + derivedRole + " landLocked=" + landLocked, 1);
	}

	void CheckModOptions() {
		dictionary@ opts = aiSetupMgr.GetModOptions();
		if (opts is null) {
			GenericHelpers::LogUtil("[ModOptions] No mod options available (opts is null)", 2);
			return;
		}

		// map_waterlevel -> log raw string if present, parse numeric from string fallback
		string str_waterlevel;
		if (opts.get("map_waterlevel", str_waterlevel)) {
			GenericHelpers::LogUtil("[ModOptions] map_waterlevel(raw)='" + str_waterlevel + "'", 1);
		}
		int waterLevel = 0;
		{
			if (str_waterlevel.length() > 0) {
				waterLevel = ToInt(str_waterlevel, 0);
			}
			Global::ModOptions::MapWaterLevel = waterLevel;
			GenericHelpers::LogUtil("[ModOptions] map_waterlevel(parsed)=" + waterLevel, 1);
		}

		// map_waterislava -> bool
		bool waterIsLava = false;
		{
			string sval;
			if (opts.get("map_waterislava", sval)) {
				waterIsLava = ToBool(sval);
			}
			Global::ModOptions::MapWaterIsLava = waterIsLava;
			GenericHelpers::LogUtil("[ModOptions] map_waterislava=" + waterIsLava, 1);
		}

		// maxunits -> int (retrieve as int64)
		int maxUnits = 0;
		{
			string sval;
			if (opts.get("maxunits", sval)) {
				maxUnits = ToInt(sval, 0);
			}
			Global::ModOptions::MaxUnits = maxUnits;
			GenericHelpers::LogUtil("[ModOptions] maxunits=" + maxUnits, 1);
		}

		// Note: In this build the dictionary type doesn't expose Release() to scripts; rely on GC.
	}

	void RegisterRoles() {
		RoleFront::Register();
		RoleAir::Register();
		RoleTech::Register();
		RoleFrontTech::Register();
		RoleSea::Register();
		RoleHoverSea::Register();
	}

	RoleConfig@ SelectRoleConfig(AiRole role) {
		return RoleConfigs::Get(role);
	}

} // namespace Setup