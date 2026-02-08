#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace SinkholeNetwork {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    // Start positions sourced from resources/data/maps/all_that_glitters.yaml (springName: All That Glitters v2.2)
    // Role mapping: front->FRONT, air->AIR, tech->TECH
    StartSpot@[] spots = {
        StartSpot(AIFloat3(  8200, 0,   2300), AiRole::FRONT, false), 
        StartSpot(AIFloat3( 9600, 0,   2200), AiRole::FRONT,   false), 
        StartSpot(AIFloat3( 8400, 0,   3700), AiRole::FRONT,  false), 
        StartSpot(AIFloat3( 9600, 0,   3600), AiRole::TECH, false),

        StartSpot(AIFloat3( 8200, 0,  5000), AiRole::FRONT, false),
        StartSpot(AIFloat3( 8000, 0,  6400), AiRole::FRONT, false), 
        StartSpot(AIFloat3( 9300, 0,  6300), AiRole::FRONT_TECH, false), 
        StartSpot(AIFloat3( 8000, 0,  7800), AiRole::FRONT, false)
    };

    // Base per-map unit limits
    dictionary mapUnitLimits; // add per-map unit restrictions here if needed

    MapConfig config = MapConfig("Sinkhole Network", mapUnitLimits, spots, getFactoryWeights());

    dictionary getFactoryWeights() {
		dictionary root; // role -> sideDict

		// FRONT role: side specific dictionaries
		dictionary frontArm; frontArm.set("armlab",2); frontArm.set("armvp",5);
		dictionary frontCor; frontCor.set("corlab",2); frontCor.set("corvp",5);
		dictionary frontLeg; frontLeg.set("leglab",2); frontLeg.set("legvp",5);
		dictionary frontRole; frontRole.set("armada", @frontArm); frontRole.set("cortex", @frontCor); frontRole.set("legion", @frontLeg);
		root.set("FRONT", @frontRole);

		// AIR role
		dictionary airArm; airArm.set("armap",3); 
		dictionary airCor; airCor.set("corap",3); 
		dictionary airLeg; airLeg.set("legap",3);

		dictionary airRole; airRole.set("armada", @airArm); airRole.set("cortex", @airCor); airRole.set("legion", @airLeg);
		root.set("AIR", @airRole);

		// TECH role
		dictionary techArm; techArm.set("armlab",4);
		dictionary techCor; techCor.set("corlab",4);
		dictionary techLeg; techLeg.set("leglab",4);

		dictionary techRole; techRole.set("armada", @techArm); techRole.set("cortex", @techCor); techRole.set("legion", @techLeg);
		
		root.set("TECH", @techRole); 

		// FRONT_TECH roles
		dictionary frontTechHybridArm; frontTechHybridArm.set("armlab",4);
		dictionary frontTechHybridCor; frontTechHybridCor.set("corlab",4);
		dictionary frontTechHybridLeg; frontTechHybridLeg.set("leglab",4);

		dictionary frontTechHybridRole; frontTechHybridRole.set("armada", @frontTechHybridArm); frontTechHybridRole.set("cortex", @frontTechHybridCor); frontTechHybridRole.set("legion", @frontTechHybridLeg);

		root.set("FRONT_TECH", @frontTechHybridRole); // reuse

		return root;
	}

} 
