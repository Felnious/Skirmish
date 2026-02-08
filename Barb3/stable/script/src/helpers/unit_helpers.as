#include "../define.as"
#include "../unit.as"
#include "../global.as"
#include "../types/ai_role.as"
#include "../types/start_spot.as" // for StartSpot & AIFloat3
#include "../types/terrain.as" // for Terrain enum
#include "generic_helpers.as" // for LogUtil
#include "../types/strategic_objectives.as" // for Objectives::BuildingType

namespace UnitHelpers {
    // Commander detection (works across factions via role mask)
    bool IsCommander(const CCircuitDef@ def) {
        return (def !is null && def.IsRoleAny(Unit::Role::COMM.mask));
    }
    bool IsCommander(const CCircuitUnit@ unit) {
        const CCircuitDef@ def = (unit is null ? null : unit.circuitDef);
        return IsCommander(def);
    }
    // Lightweight whitespace helpers (to avoid propagating empty unit names)
    // AngelScript doesn't have char literals; compare numeric ASCII codes instead.
    // space(32), tab(9), newline(10), carriage return(13)
    bool _IsSpace(const uint c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    string _Trim(const string &in s) {
        uint len = s.length();
        if (len == 0) return s;
        uint i = 0, j = len - 1;
        while (i < len && _IsSpace(s[i])) { ++i; }
        while (j > i && _IsSpace(s[j])) { --j; }
        if (i >= len) return "";
        return s.substr(i, j - i + 1);
    }

    // Append unique, non-empty, trimmed names from src into dst
    void _AppendUniqueNonEmpty(array<string>@ src, array<string>@ dst, dictionary@ seen) {
        if (src is null) return;
        for (uint i = 0; i < src.length(); ++i) {
            string n = _Trim(src[i]);
            if (n.length() == 0) {
                // Optional: low-verbosity log to surface unexpected empties
                // GenericHelpers::LogUtil("[UnitHelpers] Skipping empty unit name in list aggregation", 5);
                continue;
            }
            int _;
            if (!seen.get(n, _)) { seen.set(n, 1); dst.insertLast(n); }
        }
    }
    // Apply per-map or role/timed unit limits. Expects dictionary of unitName -> int max.
    void ApplyUnitLimits(dictionary@ unitLimits) {
        if (unitLimits is null) return;
        GenericHelpers::LogUtil("ApplyUnitLimits", 5);
        array<string>@ keys = unitLimits.getKeys();
        for (uint i = 0; i < keys.length(); ++i) {
            string unitName = keys[i];
            int maxLimit;
            if (unitLimits.get(unitName, maxLimit)) {
                CCircuitDef@ cdef = ai.GetCircuitDef(unitName);
                if (cdef !is null) {
                    GenericHelpers::LogUtil("Set Unit Limit:" + unitName + ":" + maxLimit, 4);
                    cdef.maxThisUnit = maxLimit;
                } else {
                    GenericHelpers::LogUtil("Warning: Unit not found: " + unitName, 2);
                }
            }
        }
    }

    //Takes an array of unit names, applies the same cap to all
    void BatchApplyUnitCaps(array<string>@ units, int cap) {
        for (uint i = 0; i < units.length(); ++i) {
            CCircuitDef@ cdef = ai.GetCircuitDef(units[i]);
            if (cdef is null) continue;
            if (cdef.maxThisUnit != cap) {
                cdef.maxThisUnit = cap;
                GenericHelpers::LogUtil("Front econ cap set unit=" + units[i] + " cap=" + cap, 3);
            }
        }
    }

    /************************************************************************************

    Unit lists for various factions and tiers, grouped by terrain (LAND/WATER).

    *************************************************************************************/

    // Combined list of all lab unit names across factions, tiers, and terrains (deduplicated)
    array<string> GetAllLabs() {
        array<string> result;
        dictionary seen;

        { array<string> a = GetArmadaT1LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetArmadaT2LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetArmadaT3LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetArmadaT1WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetArmadaT2WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetArmadaT3WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }

        { array<string> a = GetCortexT1LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT2LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT3LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT1WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT2WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT3WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }

        { array<string> a = GetLegionT1LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT2LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT3LandLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT1WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT2WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT3WaterLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }

        return result;
    }
    // Armada (Arm) factories
    array<string> GetArmadaT1LandLabs() {
        array<string> ids = { 
            "armlab", //Armdada T1 Bot Lab
            "armvp", //Armdada T1 Vehicle Plant
            "armap", //Armdada T1 Air Plant
            "armhp", //Armdada T1 Hover Plant
        };
        return ids;
    }

    array<string> GetArmadaT2LandLabs() {
        array<string> ids = { 
            "armalab", //Armdada T2 Bot Lab
            "armavp", //Armdada T2 Vehicle Plant
            "armaap" //Armdada T2 Air Plant
        };
        return ids;
    }

    array<string> GetArmadaT1WaterLabs() {
        array<string> ids = {
            "armsy", // Shipyard
            "armfhp" // Floating Hover Plant
        };
        return ids;
    }

    array<string> GetArmadaT2WaterLabs() {
        array<string> ids = { 
            "armasy", //Advanced Shipyard
            "armplat", // Seaplane Platform
            "armamsub"  // Amphibious Complex (Amphib Units)
        };
        return ids;
    }

    array<string> GetArmadaT3LandLabs() {
        array<string> ids = {
            "armshltx" // Experimental Gantry
        };
        return ids;
    }

    array<string> GetArmadaT3WaterLabs() {
        array<string> ids = { 
            "armshltxuw" // Underwater Experimental Gantry
        };
        return ids;
    }

    // Cortex (Core) factories
    array<string> GetCortexT1LandLabs() {
        array<string> ids = { 
            "corlab", //Cortex T1 Bot Lab
            "corvp", //Cortex T1 Vehicle Plant
            "corap", //Cortex T1 Air Plant
            "corhp", //Cortex T1 Hover Plant
        };
        return ids;
    }

    array<string> GetCortexT2LandLabs() {
        array<string> ids = { 
            "coralab", //Cortex T2 Bot Lab
            "coravp", //Cortex T2 Vehicle Plant
            "coraap" //Cortex T2 Air Plant
        };
        return ids;
    }

    array<string> GetCortexT1WaterLabs() {
        array<string> ids = {
            "corsy",
            "corfhp"
        };
        return ids;
    }

    array<string> GetCortexT2WaterLabs() {
        array<string> ids = { 
            "corasy", //Advanced Shipyard
            "corplat", // Seaplane Platform
            "coramsub"  // Amphibious Complex (Amphib Units)
        };
        return ids;
    }

    array<string> GetCortexT3LandLabs() {
        array<string> ids = {
            "corshltx" // Experimental Gantry
        };
        return ids;
    }

    array<string> GetCortexT3WaterLabs() {
        array<string> ids = { 
            "corshltxuw" // Underwater Experimental Gantry
        };
        return ids;
    }

    // Legion factories
    array<string> GetLegionT1LandLabs() {
        array<string> ids = { 
            "leglab", //Legion T1 Bot Lab
            "legvp", //Legion T1 Vehicle Plant
            "legap", //Legion T1 Air Plant
            "leghp", //Legion T1 Hover Plant
        };
        return ids;
    }

    array<string> GetLegionT2LandLabs() {
        array<string> ids = { 
            "legalab", //Legion T2 Bot Lab
            "legavp", //Legion T2 Vehicle Plant
            "legaap" //Legion T2 Air Plant
        };
        return ids;
    }


    array<string> GetLegionT1WaterLabs() {
        array<string> ids = {
            "legsy", // Legion T1 Shipyard
            "legfhp"
        };
        return ids;
    }

    array<string> GetLegionT2WaterLabs() {
        array<string> ids = { 
            "corasy", //Advanced Shipyard
            "corplat", // Seaplane Platform (Legion uses Cortex platform)
            "coramsub"  // Amphibious Complex (Amphib Units)
        };
        return ids;
    }

    array<string> GetLegionT3LandLabs() {
        array<string> ids = {
            "leggant" // Experimental Gantry
        };
        return ids;
    }

    array<string> GetLegionT3WaterLabs() {
        array<string> ids = { 
            "corshltxuw" // Underwater Experimental Gantry
        };
        return ids;
    }

    // Build a dictionary of all lab unit names -> Terrain enum
    dictionary GetLabsTerrainDict() {
        dictionary idx;

        // Armada
        InsertTerrainToLabDict(idx, GetArmadaT1LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetArmadaT2LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetArmadaT3LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetArmadaT1WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetArmadaT2WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetArmadaT3WaterLabs(), Terrain::WATER);

        // Cortex
        InsertTerrainToLabDict(idx, GetCortexT1LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetCortexT2LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetCortexT3LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetCortexT1WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetCortexT2WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetCortexT3WaterLabs(), Terrain::WATER);

        // Legion (shares some labs with Cortex)
        InsertTerrainToLabDict(idx, GetLegionT1LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetLegionT2LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetLegionT3LandLabs(), Terrain::LAND);
        InsertTerrainToLabDict(idx, GetLegionT1WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetLegionT2WaterLabs(), Terrain::WATER);
        InsertTerrainToLabDict(idx, GetLegionT3WaterLabs(), Terrain::WATER);

        return idx;
    }

    void InsertTerrainToLabDict(dictionary@ d, array<string>@ arr, Terrain terrain) 
    {
        for (uint i = 0; i < arr.length(); ++i) {
            const string name = arr[i];

            // Retrieve as int64 from dictionary and cast to Terrain for comparison
            int64 existingRaw;
            if (d.get(name, existingRaw)) {
                Terrain existingEnum = Terrain(existingRaw);
                if (existingEnum != terrain) {
                    GenericHelpers::LogUtil("[LabsTerrain] Duplicate with differing terrain for '" + name + "' existing=" + int(existingEnum) + " new=" + int(terrain), 4);
                }
                continue;
            }

            d.set(name, terrain);
        }
    }

    // Returns true if the factory is known to match the expected terrain,
    // or if the factory isn't present in the dictionary (treat unknown as compatible).
    // Returns false only when the factory exists and its terrain differs from expected.
    bool FactoryIsTerrain(const string &in factoryName, Terrain expected)
    {
        int64 raw;
        if (Global::Lookups::LabTerrainDict.get(factoryName, raw)) {
            Terrain terrain = Terrain(raw);
            return terrain == expected;
        }
        return true; // Unknown factories don't block role matching by terrain
    }

    bool FactoryIsLand(const string &in factoryName)
    {
        return FactoryIsTerrain(factoryName, Terrain::LAND);
    }

    bool FactoryIsWater(const string &in factoryName)
    {
        return FactoryIsTerrain(factoryName, Terrain::WATER);
    }

    // Combined list of all T1 combat units (deduplicated across factions)
    array<string> GetAllT1CombatUnits() {
        array<string> result;
        dictionary seen;

        { array<string> a = GetArmadaT1CombatUnits(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> b = GetCortexT1CombatUnits(); _AppendUniqueNonEmpty(@b, @result, @seen); }
        { array<string> c = GetLegionT1CombatUnits(); _AppendUniqueNonEmpty(@c, @result, @seen); }

        return result;
    }
    // Armada T1 combat units
    array<string> GetArmadaT1CombatUnits() {
        array<string> ids = { 
            "armpw",
            "armrock",
            "armham",
            "armjeth",
            "armflash",
            "armstump",
            "armart",
            "armwar",
            "armflea", // Tick
            "armfboy", // Fatboy
            "armaser",
            "armmark",
            "armfast", // Sprinter
            "armsptk", // Recluse
            "armscab"  // Umbrella
        };
        return ids;
    }

    // Combined list of all T2 combat units (deduplicated across factions)
    array<string> GetAllT2CombatUnits() {
        array<string> result;
        dictionary seen;

        { array<string> a = GetArmadaT2CombatUnits(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> b = GetCortexT2CombatUnits(); _AppendUniqueNonEmpty(@b, @result, @seen); }
        { array<string> c = GetLegionT2CombatUnits(); _AppendUniqueNonEmpty(@c, @result, @seen); }

        return result;
    }

    // Armada T2 combat units
    array<string> GetArmadaT2CombatUnits() {
        array<string> ids = { 
            "armzeus", 
            "armfido", 
            "armmerl", 
            "armsnipe", 
            "armbull", 
            "armmav", 
            "armaak",
            "armspid",
            "armvader"
        };
        return ids;
    }

    // Cortex T2 combat units
    array<string> GetCortexT2CombatUnits() {
        array<string> ids = { 
            "corpyro", 
            "cormort", 
            "cormerl", 
            "correap", 
            "cormando", 
            "corgol", 
            "corsumo", 
            "corhrk", 
            "cortermite", 
            "corcan", 
            "coramph", 
            "corsktl", 
            "corspy", 
            "legajamk",
            "corvoyr"
        };
        return ids;
    }

    // Legion T2 combat units (placeholders)
    array<string> GetLegionT2CombatUnits() {
        array<string> ids = { 
            "legboar", 
            "leginc", 
            "legmorl", 
            "legsnip", 
            "legmammoth", 
            "legstr",
            "leghrk",
            "legsrail",
            "legaspy",
            "legajamk",
            "legbart",
            "legaradk"
        };
        return ids;
    }

    // Cortex T1 combat units
    array<string> GetCortexT1CombatUnits() {
        array<string> ids = { 
            "corak",
            "corstorm",
            "corthud",
            "corcrash",
            "corraid",
            "cormist",
            "cormart",
            "coraak"
        };
        return ids;
    }

    // Legion T1 combat units (placeholders)
    array<string> GetLegionT1CombatUnits() {
        array<string> ids = { 
            "legkoda",
            "legshot",
            "legaa",
            "legraider",
            "leginf",
            "legart",
            "legcen",
            "legbal",
            "legkark",
            "leglob",
            "leggob"
        };
        return ids;
    }

    // Determine if a unit def is a constructor and which tier (0=non-constructor, 1=T1, 2=T2)
    int GetConstructorTier(const CCircuitDef@ cdef)
    {
        GenericHelpers::LogUtil("[TECH] Enter GetConstructorTier", 4);

        int tier = 0;
        string uname = "";

        if (cdef !is null) {
            uname = cdef.GetName();

            // T1 bot/vehicle/hover constructors
            if (uname == "armck" || uname == "corck" || uname == "legck" ||
                uname == "armcv" || uname == "corcv" || uname == "legcv" ||
                uname == "armch" || uname == "corch" || uname == "legch" ||
                // T1 sea (construction ships) including Legion
                uname == "armcs" || uname == "corcs" || uname == "legnavyconship" ||
                // T1 air (construction aircraft)
                uname == "armca" || uname == "corca" || uname == "legca") {
                tier = 1;
            }
            // T2 bot/vehicle constructors
            else if (uname == "armack" || uname == "corack" || uname == "legack" ||
                     uname == "armacv" || uname == "coracv" || uname == "legacv" ||
                     // T2 sea (advanced construction submarine)
                     uname == "armacsub" || uname == "coracsub" ||
                     // T2 air (advanced construction aircraft)
                     uname == "armaca" || uname == "coraca" || uname == "legaca") {
                tier = 2;
            }
        }

        GenericHelpers::LogUtil("[TECH] GetConstructorTier result=" + tier + " for=" + (uname == "" ? "<null>" : uname), 3);
        return tier;
    }

    // Returns resurrection-capable builders for a given side (currently identical for all)
    array<string> GetRezBots(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armrectr" };
        } else if (side == "cortex") {
            ids = { "cornecro" };
        } else if (side == "legion") {
            ids = { "armrectr" };
        } else {
            ids = { "armrectr", "cornecro", "legrezbot" };
        }
        return ids;
    }

    array<string> GetAllRezBots() {
        return GetRezBots("");
    }

    // Return the side-specific T1 hover constructor unit name
    string GetT1HoverConstructor(const string &in side)
    {
        if (side == "armada") return "armch";
        if (side == "cortex") return "corch";
        if (side == "legion") return "legch";
        // Default to armada's name if side is unknown
        return "armch";
    }


    // Returns fast-assist builders for a given side
    array<string> GetFastAssistBots(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armfark" };
        } else if (side == "cortex") {
            ids = { "corfast" };
        } else if (side == "legion") {
            ids = { "legaceb" };
        } else {
            ids = { "armfark", "corfast", "legaceb" };
        }
        return ids;
    }

    array<string> GetAllFastAssistBots() {
        return GetFastAssistBots("");
    }

    array<string> GetT1LandBuilders(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armck", "armcv" };
        } else if (side == "cortex") {
            ids = { "corck", "corcv" };
        } else if (side == "legion") {
            ids = { "legck", "legcv" };
        } else {
            ids = GetAllT1LandBuilders();
        }
        return ids;
    }

    array<string> GetAllT1LandBuilders() {
        array<string> ids;
        ids = { "armck", "armcv", "corck", "corcv", "legck", "legcv" };
        return ids;
    }

    array<string> GetAllT1BotConstructors() {
        array<string> ids;
        ids = { "armck", "corck", "legck" };
        return ids;
    }

    // Side-specific T1 bot constructors (exclude vehicles)
    array<string> GetT1BotConstructors(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armck" };
        } else if (side == "cortex") {
            ids = { "corck" };
        } else if (side == "legion") {
            ids = { "legck" };
        } else {
            ids = GetAllT1BotConstructors();
        }
        return ids;
    }

    // Vehicle constructors (T1) across all sides
    array<string> GetAllT1VehicleConstructors() {
        array<string> ids;
        ids = { "armcv", "corcv", "legcv" };
        return ids;
    }

    // Side-specific T1 vehicle constructors (exclude bots)
    array<string> GetT1VehicleConstructors(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armcv" };
        } else if (side == "cortex") {
            ids = { "corcv" };
        } else if (side == "legion") {
            ids = { "legcv" };
        } else {
            ids = GetAllT1VehicleConstructors();
        }
        return ids;
    }

    // Front role: preferred fast T1 combat scouts per side (bots/vehicles)
    // Bot lab scout/raider
    string GetT1BotScoutForSide(const string &in side)
    {
        // Fast scout/raider infantry per side
        if (side == "armada") return "armflea";  // Tick (fast scout bot)
        if (side == "cortex") return "corak";    // Grunt (raider bot)
        if (side == "legion") return "leggob";   // Goblin (light skirm/raider)
        return "armpw"; // default
    }

    // Tech role: T1 amphibious anti-air bots for landlocked starts
    string GetT1AntiAirBotForSide(const string &in side)
    {
        if (side == "armada") return "armjeth";   // Crossbow (amphibious AA bot)
        if (side == "cortex") return "corcrash";   // Trasher (amphibious AA bot)
        if (side == "legion") return "legaabot"; // Toxotai (amphibious AA bot)
        return "armjeth"; // default
    }

    // Vehicle plant scout/raider
    string GetT1VehicleScoutForSide(const string &in side)
    {
        if (side == "armada") return "armflash"; // Fast assault tank
        if (side == "cortex") return "corfav";   // Fast scout car
        if (side == "legion") return "legscout"; // Light scout vehicle
        return "armflash"; // default
    }

    // Given a factory name and side, resolve the appropriate T1 scout to rush for the Front role
    string GetFrontT1ScoutForFactory(const string &in factoryName, const string &in side)
    {
        if (IsT1BotLab(factoryName)) {
            return GetT1BotScoutForSide(side);
        }
        if (IsT1VehicleLab(factoryName)) {
            return GetT1VehicleScoutForSide(side);
        }
        return ""; // not a T1 land factory
    }

    array<string> GetT2LandBuilders(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armack", "armacv" };
        } else if (side == "cortex") {
            ids = { "corack", "coracv" };
        } else if (side == "legion") {
            ids = { "legack", "legacv" };
        } else {
            ids = GetAllT2LandBuilders();
        }
        return ids;
    }

    array<string> GetAllT2BotConstructors() {
        array<string> ids;
        ids = { "armack", "corack", "legack" };
        return ids;
    }

    // Side-specific T2 bot constructors (exclude vehicles)
    array<string> GetT2BotConstructors(const string &in side) {
        array<string> ids;
        if (side == "armada") {
            ids = { "armack" };
        } else if (side == "cortex") {
            ids = { "corack" };
        } else if (side == "legion") {
            ids = { "legack" };
        } else {
            ids = GetAllT2BotConstructors();
        }
        return ids;
    }

    array<string> GetAllT2LandBuilders() {
        array<string> ids;
        ids = { "armack", "armacv", "corack", "coracv", "legack", "legacv" };
        return ids;
    }

    array<string> GetAllT1BotLabs() {
        array<string> ids;
        ids = { "armlab", "corlab", "leglab" };
        return ids;
    }

    array<string> GetAllT2BotLabs() {
        array<string> ids;
        ids = { "armalab", "coralab", "legalab" };
        return ids;
    }

    array<string> GetAllT1VehicleLabs() {
        array<string> ids;
        ids = { "armvp", "corvp", "legvp" };
        return ids;
    }

    array<string> GetAllT2VehicleLabs() {
        array<string> ids;
        ids = { "armavp", "coravp", "legavp" };
        return ids;
    }

    array<string> GetAllT1AircraftPlants() {
        array<string> ids;
        ids = { "armap", "corap", "legap" };
        return ids;
    }

    array<string> GetAllT2AircraftPlants() {
        array<string> ids;
        ids = { "armaap", "coraap", "legaap" };
        return ids;
    }

    // Non-construction aircraft (T1) across all sides
    // Note: Keep constructors excluded: armca, corca, legca
    array<string> GetAllT1AircraftCombatUnits() {
        array<string> ids;
        // Armada T1 aircraft
        ids.insertLast("armpeep");   // scout
        ids.insertLast("armfig");    // fighter
        ids.insertLast("armthund");  // bomber
        ids.insertLast("armkam");    // gunship
        // Cortex T1 aircraft
        ids.insertLast("corfink");
        ids.insertLast("corveng");
        ids.insertLast("corshad");
        ids.insertLast("corbw");
        // Legion T1 aircraft (names based on existing configs)
        ids.insertLast("legcib");    // scout
        ids.insertLast("legfig");    // fighter
        ids.insertLast("legmos");    // bomber
        ids.insertLast("legkam");    // gunship
        return ids;
    }

    // Non-construction aircraft (T2) across all sides
    // Note: Keep constructors excluded: armaca, coraca, legaca
    array<string> GetAllT2AircraftCombatUnits() {
        array<string> ids;
        // Armada T2 aircraft
        ids.insertLast("armhawk");
        ids.insertLast("armpnix");
        ids.insertLast("armbrawl");
        ids.insertLast("armblade");
        ids.insertLast("armstil");
        ids.insertLast("armlance");
        ids.insertLast("armawac");   // radar plane
        // Cortex T2 aircraft
        ids.insertLast("corvamp");
        ids.insertLast("corhurc");
        ids.insertLast("corape");
        ids.insertLast("corcrw");
        ids.insertLast("corawac");   // radar plane
        ids.insertLast("cortitan");  // heavy gunship (if available)
        // Legion T2 aircraft (names based on existing configs)
        ids.insertLast("legvenator");
        ids.insertLast("legphoenix");
        ids.insertLast("legnap");
        ids.insertLast("legionnaire");
        ids.insertLast("legwhisper");
        // Some maps/configs include defensive/fortified flyers – include cautiously
        // ids.insertLast("legstronghold");
        // ids.insertLast("legfort");
        return ids;
    }

    array<string> GetAllT1Shipyards() {
        array<string> ids;
        ids = { "armsy", "corsy", "legsy" }; // Include Legion T1 shipyard
        return ids;
    }

    array<string> GetAllT2Shipyards() {
        array<string> ids;
        ids = { "armasy", "corasy" };
        return ids;
    }

    // T1 naval combat units across all sides (deduplicated)
    // Intent: Provide a conservative, maintainable set of Tech 1 sea combat units to drive default behavior
    // such as setting initial fire states in the SEA role.
    // Note: Excludes constructors and obvious utility units. IDs align to each side’s T1 shipyard products.
    array<string> GetArmadaT1NavalCombatUnits()
    {
        // Patrol boat, submarine, destroyer
        array<string> ids = { "armpt", "armsub", "armroy", "armpship" };
        return ids;
    }

    array<string> GetCortexT1NavalCombatUnits()
    {
        // Patrol boat, submarine, destroyer
        array<string> ids = { "corpt", "corsub", "corroy", "corpship" };
        return ids;
    }

    array<string> GetLegionT1NavalCombatUnits()
    {
        // Legion T1 shipyard outputs (combat): scout, frigate, destroyer, sub, AA ship, arty ship
        // Keep broad for init behaviors; safe even if some variants lean toward specialist roles.
        array<string> ids = { "legnavyscout", "legnavyfrigate", "legnavydestro", "legnavysub", "legnavyaaship", "legnavyartyship" };
        return ids;
    }

    array<string> GetAllT1NavalCombatUnits()
    {
        array<string> ids; dictionary seen;
        { array<string> a = GetArmadaT1NavalCombatUnits(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetCortexT1NavalCombatUnits(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetLegionT1NavalCombatUnits(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        return ids;
    }

    // --- Hover (T1) combat units ---
    // Side-specific lists plus an aggregated helper. Keep conservative, T1-only.
    array<string> GetArmadaT1HoverCombatUnits()
    {
        // Fast attack hover, rocket hover, hovertank, AA hover
        array<string> ids = { "armsh", "armmh", "armanac", "armah" };
        return ids;
    }

    array<string> GetCortexT1HoverCombatUnits()
    {
        // Fast attack hover, rocket hover, hovertank, AA hover
        array<string> ids = { "corsh", "cormh", "corsnap", "corah" };
        return ids;
    }

    array<string> GetLegionT1HoverCombatUnits()
    {
        // Fast attack hover, rocket hover, hovertank, AA hover
        array<string> ids = { "legsh", "legmh", "legner", "legah" };
        return ids;
    }

    array<string> GetAllT1HoverCombatUnits()
    {
        array<string> result; dictionary seen;
        { array<string> a = GetArmadaT1HoverCombatUnits(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetCortexT1HoverCombatUnits(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetLegionT1HoverCombatUnits(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        return result;
    }

    // Aggregated list for TECH support-role tagging:
    // Returns all T1/T2 land labs (bot + vehicle) and T1/T2 aircraft plants across factions.
    // Excludes: shipyards, floating hover plants, seaplane platforms, and T3 gantries.
    array<string> GetAllT1T2LandLabsAndAircraftPlants()
    {
        array<string> result; dictionary seen;

        { array<string> a = GetAllT1BotLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetAllT2BotLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetAllT1VehicleLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetAllT2VehicleLabs(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetAllT1AircraftPlants(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> a = GetAllT2AircraftPlants(); _AppendUniqueNonEmpty(@a, @result, @seen); }

        return result;
    }

    // Hover factories (T1) – land and floating variants across factions
    array<string> GetAllT1HoverPlants() {
        array<string> ids;
        ids = { "armhp", "corhp", "leghp" };
        return ids;
    }

    array<string> GetAllFloatingHoverPlants() {
        array<string> ids;
        ids = { "armfhp", "corfhp", "legfhp" };
        return ids;
    }

    // Side-specific hover plant factory names
    string GetT1HoverPlantForSide(const string &in side)
    {
        if (side == "armada") return "armhp";
        if (side == "cortex") return "corhp";
        if (side == "legion") return "leghp";
        return "armhp"; // default
    }

    string GetFloatingHoverPlantForSide(const string &in side)
    {
        if (side == "armada") return "armfhp";
        if (side == "cortex") return "corfhp";
        if (side == "legion") return "legfhp";
        return "armfhp"; // default
    }

    // Seaplane platforms across factions
    array<string> GetAllSeaplanePlatforms() {
        array<string> ids;
        ids = { "armplat", "corplat" }; // Legion shares Cortex platform
        return ids;
    }

    array<string> GetAllT1Solar() {
        array<string> ids;
        ids = { "armsolar", "corsolar", "legsolar" };
        return ids;
    }

    array<string> GetAllT2Solar() {
        array<string> ids;
        ids = { "armadvsol", "coradvsol", "legadvsol" };
        return ids;
    }

    array<string> GetAllFusionReactors() {
        array<string> ids;
        ids = { "armfus", "corfus", "legfus" };
        return ids;
    }

    array<string> GetAllAdvancedFusionReactors() {
        array<string> ids;
        ids = { "armafus", "corafus", "legafus" };
        return ids;
    }

    // Standard T1 metal storages across factions
    array<string> GetAllT1MetalStorages()
    {
        array<string> ids;
        // Verified via config: armada "armmstor", cortex "cormstor", legion "legmstor"
        ids = { "armmstor", "cormstor", "legmstor" };
        return ids;
    }

    // Advanced/Hardened storage structures across factions
    // Energy storages: underwater hardened (Arm/Cortex) and Legion hardened land store
    array<string> GetAllAdvancedEnergyStorages()
    {
        array<string> ids;
        ids = { "armuwadves", "coruwadves", "legadvestore" };
        return ids;
    }

    // Metal storages: underwater hardened (Arm/Cortex) and Legion hardened land store
    array<string> GetAllAdvancedMetalStorages()
    {
        array<string> ids;
        ids = { "armuwadvms", "coruwadvms", "legamstor" };
        return ids;
    }

    // All nuclear silos (nuke launchers) across factions
    array<string> GetAllNukeSilos() {
        array<string> ids;
        ids = { "armsilo", "corsilo", "legsilo" };
        return ids;
    }
    
    // All anti-nuke defenses across factions
    array<string> GetAllAntiNukes()
    {
        array<string> ids;
        // Verified via config JSONs: armada "armamd", cortex "corfmd", legion "legabm"
        ids = { "armamd", "corfmd", "legabm" };
        return ids;
    }
    
    // Resolve anti-nuke unit name by side (fallback to first known)
    string GetAntiNukeNameForSide(const string &in side)
    {
        if (side == "armada") return "armamd";
        if (side == "cortex") return "corfmd";
        if (side == "legion") return "legabm";
        array<string> ids = GetAllAntiNukes();
        return (ids.length() > 0 ? ids[0] : "armamd");
    }
    
    // All T1 nano caretakers across factions (including platform variants where applicable)
    array<string> GetT1NanoUnitNames() {
        array<string> ids;
        // Armada
        ids.insertLast("armnanotc");
        ids.insertLast("armnanotcplat");
        // Cortex
        ids.insertLast("cornanotc");
        ids.insertLast("cornanotcplat");
        // Legion
        ids.insertLast("legnanotc");
        ids.insertLast("legnanotcplat");
        return ids;
    }

    // Side-specific T1 nano caretaker name (base variant)
    string GetT1NanoNameForSide(const string &in side)
    {
        if (side == "armada") return "armnanotc";
        if (side == "cortex") return "cornanotc";
        if (side == "legion") return "legnanotc";
        return "armnanotc"; // default
    }

    // Side-specific T1 nano caretaker name (naval/platform variant)
    string GetT1NavalNanoNameForSide(const string &in side)
    {
        if (side == "armada") return "armnanotcplat";
        if (side == "cortex") return "cornanotcplat";
        if (side == "legion") return "legnanotcplat"; // Legion has its own platform nano variant
        return "armnanotcplat"; // default
    }

    // Note: DesiredNanoCountFromEnergy moved to EconomyHelpers

    // Return the T1 bot lab unit name for a given side (armada, cortex, legion).
    // Defaults to armada when side is unknown.
    string GetT1BotLabForSide(const string &in side)
    {
        if (side == "armada") return "armlab";
        if (side == "cortex") return "corlab";
        if (side == "legion") return "leglab";

        GenericHelpers::LogUtil("[UnitHelpers] GetT1BotLabForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armlab";
    }

    // Return the T2 bot lab unit name for a given side (armada, cortex, legion).
    // Defaults to armada when side is unknown.
    string GetT2BotLabForSide(const string &in side)
    {
        if (side == "armada") return "armalab";
        if (side == "cortex") return "coralab";
        if (side == "legion") return "legalab";

        GenericHelpers::LogUtil("[UnitHelpers] GetT2BotLabForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armalab";
    }

    // Energy structure helpers by side (default to armada). TODO: verify/add Legion-specific ids if they differ.
    string GetSolarNameForSide(const string &in side)
    {
        if (side == "armada") return "armsolar";
        if (side == "cortex") return "corsolar";
        if (side == "legion") return "legsolar"; // TODO: replace with Legion solar if different

        GenericHelpers::LogUtil("[UnitHelpers] GetSolarNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armsolar";
    }

    string GetAdvSolarNameForSide(const string &in side)
    {
        if (side == "armada") return "armadvsol";
        if (side == "cortex") return "coradvsol";
        if (side == "legion") return "legadvsol"; // TODO: replace with Legion adv solar if different
        
        GenericHelpers::LogUtil("[UnitHelpers] GetAdvSolarNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armadvsol";
    }

    string GetEnergyConverterNameForSide(const string &in side)
    {
        // BAR metal maker (converter): T1
        if (side == "armada") return "armmakr";
        if (side == "cortex") return "cormakr";
        if (side == "legion") return "legeconv"; // TODO: replace with Legion T1 converter if different

        GenericHelpers::LogUtil("[UnitHelpers] GetEnergyConverterNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armmakr";
    }

    // Naval energy converter (sea metal maker): T1
    string GetNavalEnergyConverterNameForSide(const string &in side)
    {
        // T1 naval (floating) energy converters
        if (side == "armada") return "armfmkr";
        if (side == "cortex") return "corfmkr";
        if (side == "legion") return "legfeconv"; // Legion: use naval energy converter id per behaviour_leg.json

        GenericHelpers::LogUtil("[UnitHelpers] GetNavalEnergyConverterNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armfmkr";
    }

    // --- Sea energy: Tidal generators ---
    string GetTidalNameForSide(const string &in side)
    {
        if (side == "armada") return "armtide";
        if (side == "cortex") return "cortide";
        if (side == "legion") return "legtide"; // Legion: dedicated tidal (was cortex fallback)
        GenericHelpers::LogUtil("[UnitHelpers] GetTidalNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armtide";
    }

    string GetAdvEnergyConverterNameForSide(const string &in side)
    {
        // BAR moho metal maker (advanced converter): T2
        if (side == "armada") return "armmmkr";
        if (side == "cortex") return "cormmkr";
        if (side == "legion") return "legadveconv"; // TODO: replace with Legion T2 converter if different

        GenericHelpers::LogUtil("[UnitHelpers] GetAdvEnergyConverterNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armmmkr";
    }

    // Advanced naval (underwater) energy converter (T2): underwater moho metal maker
    string GetAdvNavalEnergyConverterNameForSide(const string &in side)
    {
        // Underwater moho metal makers (sea-capable). Legion falls back to Cortex until confirmed.
        if (side == "armada") return "armuwmmm";
        if (side == "cortex") return "coruwmmm";
        if (side == "legion") return "coruwmmm";

        GenericHelpers::LogUtil("[UnitHelpers] GetAdvNavalEnergyConverterNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armuwmmm";
    }

    string GetFusionNameForSide(const string &in side)
    {
        if (side == "armada") return "armfus";
        if (side == "cortex") return "corfus";
        if (side == "legion") return "legfus"; 

        GenericHelpers::LogUtil("[UnitHelpers] GetFusionNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armfus";
    }

    string GetAdvFusionNameForSide(const string &in side)
    {
        if (side == "armada") return "armafus";
        if (side == "cortex") return "corafus";
        if (side == "legion") return "legafus"; // TODO: replace with Legion advanced fusion if different

        GenericHelpers::LogUtil("[UnitHelpers] GetAdvFusionNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armafus";
    }

    // Side-specific T2 bomber (advanced strategic bomber) name
    string GetT2BomberNameForSide(const string &in side)
    {
        // BAR canonical T2 bombers per faction
        if (side == "armada") return "armpnix";     // Strategic Bomber
        if (side == "cortex") return "corhurc";     // Heavy Strategic Bomber
        if (side == "legion") return "legphoenix";  // Heavy Assault Heatray Bomber (Legion)
        // Fallback to armada variant
        return "armpnix";
    }

    // Naval/underwater fusion reactor (sea-capable energy structure)
    string GetNavalFusionNameForSide(const string &in side)
    {
        // Underwater fusion reactors per side; Legion reuses Cortex variant unless confirmed otherwise
        if (side == "armada") return "armuwfus";
        if (side == "cortex") return "coruwfus";
        if (side == "legion") return "coruwfus"; // Legion fallback to Cortex underwater fusion

        GenericHelpers::LogUtil("[UnitHelpers] GetNavalFusionNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armuwfus";
    }

    // T2 naval "destroyer" class (cruiser-tier) per side
    // - Armada: Paladin -> armcrus
    // - Cortex: Buccaneer -> corcrus
    // - Legion sea shares Cortex naval: use corcrus
    string GetNavalT2DestroyerNameForSide(const string &in side)
    {
        if (side == "armada") return "armcrus";
        if (side == "cortex") return "corcrus";
        if (side == "legion") return "corcrus"; // Legion uses Cortex sea
        return "armcrus";
    }

    // --- Naval combat/support ships (produced by shipyards) ---
    // T2 Destroyers
    string GetNavalDestroyerNameForSide(const string &in side)
    {
        // Verified in resources/data/units.json
        if (side == "armada") return "armroy";       // Corsair, Destroyer
        if (side == "cortex") return "corroy";       // Oppressor, Destroyer
        if (side == "legion") return "legtriarius";  // Triarius, Destroyer (Legion)
        return "armroy";
    }

    // Naval anti-air ship (AA escort)
    string GetNavalAAShipNameForSide(const string &in side)
    {
        // Verified in units.json: armaas/corarch are AA ships; Legion uses Cortex sea in many cases
        if (side == "armada") return "armaas";   // Dragonslayer, Anti-Air Ship
        if (side == "cortex") return "corarch";  // Arrow Storm, Anti-Air Ship
        if (side == "legion") return "corarch";  // fallback to Cortex AA ship
        return "armaas";
    }

    // Naval jammer ship (mobile radar jammer)
    string GetNavalJammerShipNameForSide(const string &in side)
    {
        // Verified in units.json: armsjam/corsjam are Radar Jammer Ship
        if (side == "armada") return "armsjam";
        if (side == "cortex") return "corsjam";
        if (side == "legion") return "corsjam"; // fallback to Cortex jammer ship
        return "armsjam";
    }

    // Naval radar/utility ship: use MLS (Naval Engineer) which provides radar/sonar support
    string GetNavalRadarShipNameForSide(const string &in side)
    {
        // Produced by shipyards and provides scouting utility
        if (side == "armada") return "armmls";  // Voyager, Naval Engineer
        if (side == "cortex") return "cormls";  // Pathfinder, Naval Engineer
        if (side == "legion") return "cormls";  // fallback to Cortex variant
        return "armmls";
    }

    // Naval missile ship (cruise missile cruiser)
    string GetNavalMissileShipNameForSide(const string &in side)
    {
        // Verified in units.json: armmship/cormship
        if (side == "armada") return "armmship";  // Longbow, Missile Cruiser
        if (side == "cortex") return "cormship";  // Messenger, Cruise Missile Ship
        if (side == "legion") return "cormship";  // fallback to Cortex variant
        return "armmship";
    }

    // Naval anti-nuke ship (mobile ABM + radar/sonar)
    string GetNavalAntiNukeShipNameForSide(const string &in side)
    {
        // Verified in units.json: armantiship/corantiship carry mobile anti-nuke
        if (side == "armada") return "armantiship";
        if (side == "cortex") return "corantiship";
        if (side == "legion") return "corantiship"; // fallback to Cortex variant
        return "armantiship";
    }

    // --- Static defenses and structures (side-aware) ---
    string GetStaticAALightNameForSide(const string &in side)
    {
        if (side == "armada") return "armrl";
        if (side == "cortex") return "corrl";
        if (side == "legion") return "legrl";
        GenericHelpers::LogUtil("[UnitHelpers] GetStaticAALightNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armrl";
    }

    string GetStaticAAHeavyNameForSide(const string &in side)
    {
        if (side == "armada") return "armferret";
        if (side == "cortex") return "corerad";
        if (side == "legion") return "legflak";
        GenericHelpers::LogUtil("[UnitHelpers] GetStaticAAHeavyNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armferret";
    }

    string GetStaticLLTNameForSide(const string &in side)
    {
        if (side == "armada") return "armllt";
        if (side == "cortex") return "corllt";
        if (side == "legion") return "leglht";
        GenericHelpers::LogUtil("[UnitHelpers] GetStaticLLTNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armllt";
    }

    string GetStaticT2ArtilleryNameForSide(const string &in side)
    {
        if (side == "armada") return "armpb";
        if (side == "cortex") return "corvipe";
        if (side == "legion") return "legacluster";
        GenericHelpers::LogUtil("[UnitHelpers] GetStaticT2ArtilleryNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armpb";
    }

    string GetStaticRadarNameForSide(const string &in side)
    {
        if (side == "armada") return "armrad";
        if (side == "cortex") return "corrad";
            if (side == "legion") return "legabm";
        return "armrad";
    }

    string GetStaticJammerNameForSide(const string &in side)
    {
        // Use static jammer structures (not mobile vehicles)
        if (side == "armada") return "armjamt";   // Sneaky Pete (static jammer)
        if (side == "cortex") return "corjamt";   // Castro (static jammer)
        if (side == "legion") return "legjam";    // Nyx (static jammer); alt long-range 'legajam'
        GenericHelpers::LogUtil("[UnitHelpers] GetStaticJammerNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armjamt";
    }

    string GetSeaplanePlatformNameForSide(const string &in side)
    {
        if (side == "armada") return "armplat";
        if (side == "cortex") return "corplat";
        if (side == "legion") return "corplat"; // Legion shares Cortex seaplane platform
        GenericHelpers::LogUtil("[UnitHelpers] GetSeaplanePlatformNameForSide: no matching side '" + side + "', defaulting to armada", 2);
        return "armplat";
    }

    // --- Floating (sea/water) defence structures ---
    // Light floating AA turret
    string GetFloatingAALightNameForSide(const string &in side)
    {
        if (side == "armada") return "armfrt";   // Floating AA turret
        if (side == "cortex") return "corfrt";   // Floating AA turret
        if (side == "legion") return "legfrl";   // Floating AA turret (Legion)
        // Fallback to Armada
        return "armfrt";
    }

    // Longer-range floating AA (missile battery). Legion lacks a distinct variant; fall back to light AA
    string GetFloatingAARangeNameForSide(const string &in side)
    {
        if (side == "armada") return "armfrock"; // Floating AA missile battery
        if (side == "cortex") return "corfrock"; // Floating AA missile battery
        if (side == "legion") return "legfrl";   // Fallback until a Legion long-range floating AA is confirmed
        return "armfrock";
    }

    // Floating heavy laser turret (basic floating gun tower)
    string GetFloatingHeavyLaserNameForSide(const string &in side)
    {
        if (side == "armada") return "armfhlt";  // Floating Heavy Laser Tower
        if (side == "cortex") return "corfhlt";  // Floating Heavy Laser Tower
        if (side == "legion") return "legfmg";   // Legion floating gatling turret (closest analogue)
        return "armfhlt";
    }

    // Heavier floating plasma/multi-weapon towers
    string GetFloatingHeavyTurretNameForSide(const string &in side)
    {
        if (side == "armada") return "armkraken"; // Floating rapid-fire plasma
        if (side == "cortex") return "corfdoom";  // Floating multi-weapon platform
        if (side == "legion") return "legfmg";    // Legion floating gatling turret
        return "armkraken";
    }

    // --- Additional side-aware mappings for new objective types ---
    string GetStaticT1TorpNameForSide(const string &in side)
    {
        // T1 static torpedo launchers
        if (side == "armada") return "armtl"; // TODO: verify upstream id
        if (side == "cortex") return "cortl"; // TODO: verify upstream id
        if (side == "legion") return "cortl"; // TODO: provide Legion id when available
        return "armtl";
    }

    string GetStaticT2TorpNameForSide(const string &in side)
    {
        // T2 static torpedo launchers
        if (side == "armada") return "armatl"; // TODO: verify upstream id
        if (side == "cortex") return "coratl"; // TODO: verify upstream id
        if (side == "legion") return "coratl"; // TODO: provide Legion id when available
        return "armatl";
    }

    string GetStaticT2AAFlakNameForSide(const string &in side)
    {
        if (side == "armada") return "armflak";
        if (side == "cortex") return "corflak";
        if (side == "legion") return "legflak";
        return "armflak";
    }

    string GetStaticT2AARangeNameForSide(const string &in side)
    {
        // Long-range AA (e.g., chainsaw/screamer equivalents)
        if (side == "armada") return "armmercury"; // TODO: confirm BAR unit id
        if (side == "cortex") return "corscreamer"; // TODO: confirm BAR unit id
        if (side == "legion") return "legscreamer"; // TODO: placeholder until confirmed
        return "armmercury";
    }

    string GetStaticT2MediumTurretNameForSide(const string &in side)
    {
        // Medium plasma turrets
        if (side == "armada") return "armguard";
        if (side == "cortex") return "corpun";
        // TODO: add Legion counterpart when confirmed; fallback to armada variant for now
        if (side == "legion") return "armguard";
        return "armguard";
    }

    string GetStaticT2RadarNameForSide(const string &in side)
    {
        if (side == "armada") return "armarad";
        if (side == "cortex") return "corarad";
        // TODO: add Legion advanced radar id when confirmed; fallback to armada variant for now
        if (side == "legion") return "armarad";
        return "armarad";
    }

    string GetLRPCNameForSide(const string &in side)
    {
        // Long Range Plasma Cannon
        if (side == "armada") return "armbrtha";
        if (side == "cortex") return "corint";
        // TODO: add Legion LRPC when confirmed; fallback to armada variant for now
        if (side == "legion") return "armbrtha";
        return "armbrtha";
    }

    string GetLRPCHeavyNameForSide(const string &in side)
    {
        // Heavy LRPCs (Ragnarok/Calamity/Starfall equivalents)
        if (side == "armada") return "armragnarok"; // TODO: confirm BAR unit id
        if (side == "cortex") return "corcalamity"; // TODO: confirm BAR unit id
        if (side == "legion") return "legstarfall"; // TODO: confirm BAR unit id
        return "armragnarok";
    }

    // -------------------------------
    // Static land defences (anti-ground)
    // Reusable lists for disabling on air-only maps, etc.
    // Excludes: AA structures, LRPCs, and nukes. Torpedoes are sea-only and excluded.
    // -------------------------------

    // Returns all Tier 1 land-only static defenses (exclude AA)
    array<string> GetAllT1LandDefences()
    {
        array<string> ids; dictionary seen;
        // Include LLTs plus known T1 ground turrets and pop-ups per side
        // ARMADA: armllt (LLT), armbeamer (rapid laser), armhlt (heavy laser, BAR tiered as early turret), armclaw (popup)
        {
            array<string> arm = { "armllt", "armbeamer", "armhlt", "armclaw" };
            for (uint i = 0; i < arm.length(); ++i) {
                const string n = arm[i];
                if (n != "" && !seen.exists(n)) { ids.insertLast(n); seen.set(n, true); }
            }
        }
        // CORTEX: corllt (LLT), corhllt (rapid laser), corhlt (heavy laser), cormaw (popup)
        {
            array<string> cor = { "corllt", "corhllt", "corhlt", "cormaw" };
            for (uint i = 0; i < cor.length(); ++i) {
                const string n = cor[i];
                if (n != "" && !seen.exists(n)) { ids.insertLast(n); seen.set(n, true); }
            }
        }
        // LEGION: leglht (LLT), leghive (cluster/hive turret), legmg (machine-gun turret)
        {
            array<string> leg = { "leglht", "leghive", "legmg" };
            for (uint i = 0; i < leg.length(); ++i) {
                const string n = leg[i];
                if (n != "" && !seen.exists(n)) { ids.insertLast(n); seen.set(n, true); }
            }
        }
        return ids;
    }

    // Returns all Tier 2 land-only static defenses (exclude AA, exclude LRPCs and nukes)
    array<string> GetAllT2LandDefences()
    {
        array<string> ids; dictionary seen;
        array<string> sides = { "armada", "cortex", "legion" };
        for (uint i = 0; i < sides.length(); ++i) {
            // Medium plasma turrets (Guardian/Punisher/etc.)
            string med = GetStaticT2MediumTurretNameForSide(sides[i]);
            if (med != "" && !seen.exists(med)) { ids.insertLast(med); seen.set(med, true); }

            // Close-range heavy turrets (Pit Bull/Viper/Legion cluster)
            string arty = GetStaticT2ArtilleryNameForSide(sides[i]);
            if (arty != "" && !seen.exists(arty)) { ids.insertLast(arty); seen.set(arty, true); }
        }
        return ids;
    }

    // Combined list of all static land defences (T1 + T2), non-AA, non-LRPC, non-nuke
    array<string> GetAllLandDefences()
    {
        array<string> result; dictionary seen;
        { array<string> a = GetAllT1LandDefences(); _AppendUniqueNonEmpty(@a, @result, @seen); }
        { array<string> b = GetAllT2LandDefences(); _AppendUniqueNonEmpty(@b, @result, @seen); }
        return result;
    }

    // Resolve a side-aware unit name for a given strategic objective type.
    // Note: Some executor code may still special-case certain types (e.g. energy placement choice) for task type,
    // but this resolver provides a consistent name for counting/validation.
    string GetObjectiveUnitNameForSide(const string &in side, Objectives::BuildingType t)
    {
        // Tier 1
        if (t == Objectives::BuildingType::T1_LIGHT_AA)    return GetStaticAALightNameForSide(side);
        if (t == Objectives::BuildingType::T1_MEDIUM_AA)   return GetStaticAAHeavyNameForSide(side);
        if (t == Objectives::BuildingType::T1_LIGHT_TURRET) return GetStaticLLTNameForSide(side);
        if (t == Objectives::BuildingType::T1_MED_TURRET)   return GetStaticT2MediumTurretNameForSide(side); // TODO: use true T1 medium if available
        if (t == Objectives::BuildingType::T1_ARTY)         return GetStaticT2ArtilleryNameForSide(side);    // TODO: replace with T1 artillery when available
        if (t == Objectives::BuildingType::T1_TORP)         return GetStaticT1TorpNameForSide(side);
        if (t == Objectives::BuildingType::T1_JAMMER)       return GetStaticJammerNameForSide(side);
        if (t == Objectives::BuildingType::T1_RADAR)        return GetStaticRadarNameForSide(side);
        if (t == Objectives::BuildingType::T1_ENERGY)       return GetSolarNameForSide(side); // Note: executor/roles may choose tidal/solar placement
        if (t == Objectives::BuildingType::T1_TIDAL)        return GetTidalNameForSide(side);
        if (t == Objectives::BuildingType::T1_MEX)          return (side == "armada" ? "armmex" : (side == "cortex" ? "cormex" : "legmex"));
        if (t == Objectives::BuildingType::T1_GEO)          return (side == "armada" ? "armgeo" : (side == "cortex" ? "corgeo" : "leggeo"));

        // Factories
        if (t == Objectives::BuildingType::SEAPLANE_FACTORY) return GetSeaplanePlatformNameForSide(side);

        // Tier 2
        if (t == Objectives::BuildingType::T2_FLAK_AA)      return GetStaticT2AAFlakNameForSide(side);
        if (t == Objectives::BuildingType::T2_RANGE_AA)     return GetStaticT2AARangeNameForSide(side);
        if (t == Objectives::BuildingType::T2_MED_TURRET)   return GetStaticT2MediumTurretNameForSide(side);
        if (t == Objectives::BuildingType::T2_ARTY)         return GetStaticT2ArtilleryNameForSide(side);
        if (t == Objectives::BuildingType::T2_JAMMER)       return GetStaticJammerNameForSide(side); // TODO: use advanced jammer when available
        if (t == Objectives::BuildingType::T2_RADAR)        return GetStaticT2RadarNameForSide(side);
        if (t == Objectives::BuildingType::T2_ENERGY)       return GetFusionNameForSide(side);

        // Long range
        if (t == Objectives::BuildingType::LRPC)            return GetLRPCNameForSide(side);
        if (t == Objectives::BuildingType::LRPC_HEAVY)      return GetLRPCHeavyNameForSide(side);

        return "";
    }

    // Perhaps replace array loops with hashtable lookup in future - Centrifugal
    bool IsT1BotLab(const string &in unitName)
    {
        array<string> labs = GetAllT1BotLabs();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsT2BotLab(const string &in unitName)
    {
        array<string> labs = GetAllT2BotLabs();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    // Vehicle labs
    bool IsT1VehicleLab(const string &in unitName)
    {
        array<string> labs = GetAllT1VehicleLabs();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsT2VehicleLab(const string &in unitName)
    {
        array<string> labs = GetAllT2VehicleLabs();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    // Aircraft plants
    bool IsT1AircraftPlant(const string &in unitName)
    {
        array<string> labs = GetAllT1AircraftPlants();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        // Trace unexpected names to help diagnose misconfig
        GenericHelpers::LogUtil("[UnitHelpers] IsT1AircraftPlant: '" + unitName + "' not in T1 list", 5);
        return false;
    }

    // Determine if a unit definition is an air constructor (T1 or T2)
    bool IsAirConstructor(const CCircuitDef@ d)
    {
        if (d is null) return false;
        const string n = d.GetName();
        // T1 air constructors
        if (n == "armca" || n == "corca" || n == "legca") return true;
        // T2 air constructors
        if (n == "armaca" || n == "coraca" || n == "legaca") return true;
        return false;
    }

    // Convenience: all T1 air constructor unit names across sides
    array<string> GetAllT1AirConstructors()
    {
        array<string> ids = { "armca", "corca", "legca" };
        return ids;
    }

    // Side-specific aircraft plant names
    string GetT1AirPlantForSide(const string &in side)
    {
        if (side == "armada") { GenericHelpers::LogUtil("[UnitHelpers] T1AirPlantForSide: armada -> armap", 4); return "armap"; }
        if (side == "cortex") { GenericHelpers::LogUtil("[UnitHelpers] T1AirPlantForSide: cortex -> corap", 4); return "corap"; }
        if (side == "legion") { GenericHelpers::LogUtil("[UnitHelpers] T1AirPlantForSide: legion -> legap", 4); return "legap"; }
        GenericHelpers::LogUtil("[UnitHelpers] T1AirPlantForSide: unknown side '" + side + "', defaulting to armap", 2);
        return "armap"; // default to armada
    }

    string GetT2AirPlantForSide(const string &in side)
    {
        if (side == "armada") return "armaap";
        if (side == "cortex") return "coraap";
        if (side == "legion") return "legaap";
        return "armaap"; // default to armada
    }

    // T1 Air scout unit names per side (BAR ids; verified against behaviour.json)
    string GetT1AirScoutForSide(const string &in side)
    {
        // Armada uses ARM Peewee scout plane
        if (side == "armada") return "armpeep";
        // Cortex uses COR Fink scout plane
        if (side == "cortex") return "corfink";
        // Legion: use fighter as early scout per profile config
        if (side == "legion") return "legfig";
        // Default to armada variant if unknown
        return "armpeep";
    }

    array<string> GetAllT1AirScouts()
    {
        array<string> ids;
        ids = { "armpeep", "corfink", "legfig" };
        return ids;
    }

    bool IsT2AircraftPlant(const string &in unitName)
    {
        array<string> labs = GetAllT2AircraftPlants();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    // Shipyards (sea)
    bool IsT1Shipyard(const string &in unitName)
    {
        array<string> labs = GetAllT1Shipyards();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsT2Shipyard(const string &in unitName)
    {
        array<string> labs = GetAllT2Shipyards();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    // Hover factories
    bool IsT1HoverPlant(const string &in unitName)
    {
        array<string> labs = GetAllT1HoverPlants();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsFloatingHoverPlant(const string &in unitName)
    {
        array<string> labs = GetAllFloatingHoverPlants();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsSeaplanePlatform(const string &in unitName)
    {
        array<string> labs = GetAllSeaplanePlatforms();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    // Experimental Gantry (T3) helpers
    array<string> GetAllLandGantries()
    {
        array<string> ids; dictionary seen;
        { array<string> a = GetArmadaT3LandLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetCortexT3LandLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetLegionT3LandLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        return ids;
    }

    array<string> GetAllWaterGantries()
    {
        array<string> ids; dictionary seen;
        { array<string> a = GetArmadaT3WaterLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetCortexT3WaterLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        { array<string> a = GetLegionT3WaterLabs(); _AppendUniqueNonEmpty(@a, @ids, @seen); }
        return ids;
    }

    bool IsLandGantry(const string &in unitName)
    {
        array<string> labs = GetAllLandGantries();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsWaterGantry(const string &in unitName)
    {
        array<string> labs = GetAllWaterGantries();
        for (uint i = 0; i < labs.length(); ++i) {
            if (labs[i] == unitName) return true;
        }
        return false;
    }

    bool IsGantryLab(const string &in unitName)
    {
        return IsLandGantry(unitName) || IsWaterGantry(unitName);
    }

    // Return a land gantry (experimental) unit name for the given side
    string GetLandGantryForSide(const string &in side)
    {
        if (side == "armada") return "armshltx";
        if (side == "cortex") return "corgant";
        if (side == "legion") return "leggant";
        return "armshltx"; // default
    }

    // Resolve the signature experimental unit produced by a Gantry per side
    // Display names requested: Titan (armada), Juggernaut (cortex), Sol Invictus (legion)
    // TODO: Verify exact BAR unitdef ids for these experimentals.
    // Fallbacks here are best-effort; if a name is unknown, return an empty string so callers can safely skip.
    string GetGantrySignatureUnitForSide(const string &in side)
    {
        if (side == "armada") {
            // TODO: Replace with the actual Titan unitdef id if different
            // Common Arm experimental alternatives include: armbanth (Bantha) but may be T2
            // Using 'armtitan' as a placeholder id; will no-op if not found.
            return "armbanth";
        }
        if (side == "cortex") {
            // Juggernaut/Krogoth commonly maps to 'corkrog' in TA-derived mods
            return "corkorg"; // TODO: confirm Juggernaut unitdef id
        }
        if (side == "legion") {
            // TODO: Replace with actual Sol Invictus unitdef id when confirmed (placeholder)
            return "legeheatraymech";
        }
        return "";
    }

    // 
    bool IsT1LandBuilders(const string &in unitName)
    {
        array<string> ids = GetAllT1LandBuilders();
        for (uint i = 0; i < ids.length(); ++i) {
            if (ids[i] == unitName) return true;
        }
        return false;
    }

    bool IsT2LandBuilder(const string &in unitName)
    {
        array<string> ids = GetAllT2LandBuilders();
        for (uint i = 0; i < ids.length(); ++i) {
            if (ids[i] == unitName) return true;
        }
        return false;
    }

    // Infer side from a raw unit name string by prefix; defaults to armada if unknown
    string GetSideForUnitName(const string &in unitName)
    {
        string n = _Trim(unitName);
        if (n.length() >= 3) {
            string p = n.substr(0, 3);
            if (p == "arm") return "armada";
            if (p == "cor") return "cortex";
            if (p == "leg") return "legion";
        }
        return "armada";
    }

    // Simple, fast side inference by unitdef name prefix.
    // BAR: arm..., cor...; Legion: leg...
    bool IsArmadaDef(const CCircuitDef@ d) {
        if (d is null) return false;
        const string n = d.GetName();
        return n.length() >= 3 && n.substr(0, 3) == "arm";
    }

    bool IsCortexDef(const CCircuitDef@ d) {
        if (d is null) return false;
        const string n = d.GetName();
        return n.length() >= 3 && n.substr(0, 3) == "cor";
    }

    bool IsLegionDef(const CCircuitDef@ d) {
        if (d is null) return false;
        const string n = d.GetName();
        return n.length() >= 3 && n.substr(0, 3) == "leg";
    }

    bool IsArmadaUnit(const CCircuitUnit@ u) { return u !is null && IsArmadaDef(u.circuitDef); }
    bool IsCortexUnit(const CCircuitUnit@ u) { return u !is null && IsCortexDef(u.circuitDef); }
    bool IsLegionUnit(const CCircuitUnit@ u) { return u !is null && IsLegionDef(u.circuitDef); }

}