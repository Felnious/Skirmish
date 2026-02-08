#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"
#include "../helpers/unit_helpers.as"

namespace AcidicQuarry {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    // Start positions sourced from resources/data/maps/all_that_glitters.yaml (springName: All That Glitters v2.2)
    // Role mapping: front->FRONT, air->AIR, tech->TECH
    StartSpot@[] spots = {
        StartSpot(AIFloat3(  1200, 0,   1200), AiRole::AIR, false), 
        StartSpot(AIFloat3( 1200, 0,   4800), AiRole::AIR,   false), 
        StartSpot(AIFloat3( 5100, 0,   1200), AiRole::AIR,  false), 
        StartSpot(AIFloat3( 5000, 0,   4800), AiRole::AIR, false)     
    };

	// Construct per-map unit limits
	dictionary getUnitLimits() {
		dictionary limits;
		// AIR-only map setup: disable anti-ground static defenses (LLT/Guard/Pit Bull etc.)
		array<string> landDefs = UnitHelpers::GetAllLandDefences();
		for (uint i = 0; i < landDefs.length(); ++i) {
			limits.set(landDefs[i], 0);
		}
		return limits;
	}

	MapConfig config = MapConfig("AcidicQuarry", getUnitLimits(), spots, getFactoryWeights());

    dictionary getFactoryWeights() {
		dictionary root; // role -> sideDict

		// AIR role
		dictionary airArm; airArm.set("armap",1); 
		dictionary airCor; airCor.set("corap",1); 
		dictionary airLeg; airLeg.set("legap",1);

		dictionary airRole; airRole.set("armada", @airArm); airRole.set("cortex", @airCor); airRole.set("legion", @airLeg);
		root.set("AIR", @airRole);

		return root;
	}

} 
