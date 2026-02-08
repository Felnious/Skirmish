#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace AllThatGlitters {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    // Start positions sourced from resources/data/maps/all_that_glitters.yaml (springName: All That Glitters v2.2)
    // Role mapping: front->FRONT, air->AIR, tech->TECH
    StartSpot@[] spots = {
        StartSpot(AIFloat3(  668, 0,   755), AiRole::FRONT, false), // P1
        StartSpot(AIFloat3( 2801, 0,   775), AiRole::AIR,   false), // P2
        StartSpot(AIFloat3( 4211, 0,   609), AiRole::TECH,  false), // P3
        StartSpot(AIFloat3( 5762, 0,   600), AiRole::FRONT, false), // P4
        StartSpot(AIFloat3( 1159, 0,  1943), AiRole::FRONT, false), // P5
        StartSpot(AIFloat3( 3061, 0,  1967), AiRole::FRONT, false), // P6
        StartSpot(AIFloat3( 4298, 0,  1996), AiRole::FRONT, false), // P7
        StartSpot(AIFloat3( 5472, 0,  2030), AiRole::FRONT, false), // P8
        StartSpot(AIFloat3( 5475, 0,  9444), AiRole::FRONT, false), // P9
        StartSpot(AIFloat3( 3452, 0,  9689), AiRole::AIR,   false), // P10
        StartSpot(AIFloat3( 1943, 0,  9622), AiRole::TECH,  false), // P11
        StartSpot(AIFloat3(   408, 0,  9640), AiRole::FRONT, false), // P12
        StartSpot(AIFloat3( 5166, 0,  8246), AiRole::FRONT, false), // P13
        StartSpot(AIFloat3( 3212, 0,  8249), AiRole::FRONT, false), // P14
        StartSpot(AIFloat3( 1859, 0,  8256), AiRole::FRONT, false), // P15
        StartSpot(AIFloat3(   697, 0,  8224), AiRole::FRONT, false)  // P16
    };

    // Base per-map unit limits
    dictionary mapUnitLimits; // add per-map unit restrictions here if needed

    MapConfig config = MapConfig("All That Glitters", mapUnitLimits, spots, getFactoryWeights());

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
