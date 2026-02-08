#include "../define.as"
#include "../global.as"
#include "generic_helpers.as"
#include "unit_helpers.as"
#include "../types/ai_role.as"
#include "../types/start_spot.as" // for StartSpot & AIFloat3

namespace FactoryHelpers {

    // Resolve a sensible per-role fallback factory when no map-configured weights exist.
    // Returns a unit name string suitable for starting factory placement.
    string GetFallbackStartFactoryForRole(AiRole role, const string &in side)
    {
        // Default-most-safe across land maps: T1 bot lab
        // Specialize for roles that prefer different openings.
        if (role == AiRole::AIR) {
            return UnitHelpers::GetT1AirPlantForSide(side);
        }
        if (role == AiRole::SEA) {
            // Side-aware T1 shipyards; Legion currently falls back to Cortex variant
            if (side == "armada") return "armsy";
            if (side == "cortex") return "corsy";
            if (side == "legion") return "legsy";
            return "armsy";
        }
        if (role == AiRole::HOVER_SEA) {
            // Hover factory tends to work on many mixed water/land starts
            if (side == "armada") return "armhp";
            if (side == "cortex") return "corhp";
            if (side == "legion") return "leghp";
            return "armhp";
        }

        // TECH, FRONT, FRONT_TECH and any unknown -> T1 bot lab (widely valid)
        return UnitHelpers::GetT1BotLabForSide(side);
    }

    // Select a map-configured weighted start factory for a role/side if available;
    // otherwise return a robust role-specific fallback.
    string SelectStartFactoryForRole(AiRole role, const string &in side)
    {
        dictionary@ sides = GetSideFactoryWeightsFromMapConfig(Global::Map::Config, role);
        dictionary@ factoryWeights = GetFactoryWeightsFromSide(side, sides);
        string selected = SelectWeightedFactory(factoryWeights);
        if (selected != "") {
            return selected;
        }
        GenericHelpers::LogUtil("[FactoryHelpers] No map-config start factory weights. Using fallback for role=" + int(role) + " side='" + side + "'", 2);
        return GetFallbackStartFactoryForRole(role, side);
    }

    dictionary@ GetSideFactoryWeightsFromMapConfig(MapConfig@ mapConfig, AiRole role) {
        // Guard: mapConfig/weights may be missing; caller/engine will handle null handle as fallback trigger.
        if (mapConfig is null) return null;
        return mapConfig.GetSideFactoryWeightsByRole(role);
    }

    dictionary@ GetFactoryWeightsFromSide(const string &in side, dictionary@ sides) {
        // Always return a valid dictionary handle; never null. Single return at end.
        dictionary@ result = null;

        if (sides is null) {
            GenericHelpers::LogUtil("[FactoryWeights] sides is null for side='" + side + "'", 3);
            @result = dictionary();
        } else {
            dictionary@ factoryWeights = null;
            if (sides.get(side, @factoryWeights) && factoryWeights !is null) {
                array<string>@ keys = factoryWeights.getKeys();
                GenericHelpers::LogUtil("[FactoryWeights] found for side='" + side + "' entries=" + int(keys.length()), 2);
                @result = factoryWeights;
            } else {
                GenericHelpers::LogUtil("[FactoryWeights] no weights for side='" + side + "' entries=0", 2);
                @result = dictionary();
            }
        }

        return result;
    }

    string SelectWeightedFactory(dictionary@ sideDict) {
        if (sideDict is null) return "";

        array<string>@ sKeys = sideDict.getKeys();
        array<string> factories; array<int> weights; int total = 0;
        for (uint i = 0; i < sKeys.length(); ++i) {
            int w; if (!sideDict.get(sKeys[i], w)) continue; if (w <= 0) continue;
            factories.insertLast(sKeys[i]); weights.insertLast(w); total += w;
        }
        if (total > 0 && factories.length() > 0) {
            int roll = AiRandom(0, total - 1); int accum = 0;
            for (uint i = 0; i < factories.length(); ++i) {
                accum += weights[i];
                 if (roll < accum) {
                    GenericHelpers::LogUtil("FactoryWeightedSelect chose=" + factories[i] + " roll=" + roll + "/" + total, 1);
                    return factories[i];
                }
            }
        }

        // No weighted match found
        return "";
    }

}