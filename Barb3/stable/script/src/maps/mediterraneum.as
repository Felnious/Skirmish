#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace Mediterraneum {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    // Start positions sourced from resources/data/maps/all_that_glitters.yaml (springName: All That Glitters v2.2)
    // Role mapping: front->FRONT, air->AIR, tech->TECH
    StartSpot@[] spots = {

		//TOP
        StartSpot(AIFloat3(  1300, 0,   1200), AiRole::AIR, false), 
        StartSpot(AIFloat3( 3200, 0,   2800), AiRole::FRONT,  false),
        StartSpot(AIFloat3( 5600, 0,   1500), AiRole::SEA,  false), 
        StartSpot(AIFloat3( 7800, 0,   2500), AiRole::TECH, false), 

		StartSpot(AIFloat3( 750, 0,   3800), AiRole::SEA, false), 
		StartSpot(AIFloat3( 15600, 0,   700), AiRole::SEA, false), 

		StartSpot(AIFloat3(  4800, 0,   6200), AiRole::SEA, false), 
        StartSpot(AIFloat3( 7800, 0,   5100), AiRole::FRONT,  false),
        StartSpot(AIFloat3( 10800, 0,   3600), AiRole::FRONT,  false), 
        StartSpot(AIFloat3( 14600, 0,   4500), AiRole::FRONT, false),

		StartSpot(AIFloat3( 1180, 0,   7100), AiRole::HOVER_SEA, false),
		StartSpot(AIFloat3( 3200, 0,   7100), AiRole::FRONT, false),
		StartSpot(AIFloat3( 14800, 0,   6400), AiRole::FRONT, false),
		StartSpot(AIFloat3( 15700, 0,   6900), AiRole::FRONT, false),

		//BOTTOM
        StartSpot(AIFloat3( 4100, 0,  11000), AiRole::FRONT, false),
        StartSpot(AIFloat3( 6800, 0,  11000), AiRole::FRONT, false),
        StartSpot(AIFloat3( 10400, 0,  11400), AiRole::FRONT, false),
        StartSpot(AIFloat3( 14000, 0,  11600), AiRole::SEA, false),

		StartSpot(AIFloat3( 1040, 0,  10100), AiRole::SEA, false),

		StartSpot(AIFloat3( 5800, 0,  12700), AiRole::HOVER_SEA, false),
        StartSpot(AIFloat3( 8800, 0,  14200), AiRole::SEA, false),
        StartSpot(AIFloat3( 10600, 0,  11600), AiRole::AIR, false),
        StartSpot(AIFloat3( 13200, 0,  13000), AiRole::FRONT, false),

		StartSpot(AIFloat3( 1700, 0,  13200), AiRole::HOVER_SEA, false),
		StartSpot(AIFloat3( 4500, 0,  15500), AiRole::TECH, false),
        StartSpot(AIFloat3( 9800, 0,  15800), AiRole::HOVER_SEA, false),
        StartSpot(AIFloat3( 15200, 0,  15500), AiRole::HOVER_SEA, false)
    };

    // Base per-map unit limits
    dictionary mapUnitLimits; // add per-map unit restrictions here if needed

    MapConfig config = MapConfig("Mediterraneum_V1", mapUnitLimits, spots, getFactoryWeights());

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
