// Default map config (applies when no specific map match is found)
#include "../types/map_config.as"
#include "../types/start_spot.as"

MapConfig DEFAULT_MAP_CONFIG = MapConfig(
    "", // empty prefix catches none explicitly
    getDefaultMaxUnits()
);

dictionary getDefaultMaxUnits() {
    dictionary _unitLimits;
    return _unitLimits;
}
