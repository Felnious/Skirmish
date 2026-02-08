#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace SereneCaldera {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    StartSpot@[] spots = {
    	StartSpot(AIFloat3(  2800, 0,  2900), AiRole::SEA, false), // P1 
    	StartSpot(AIFloat3(  4500, 0, 1600), AiRole::SEA, false), // P2
        StartSpot(AIFloat3( 6600, 0, 1000), AiRole::SEA, false), // P3 
        StartSpot(AIFloat3( 8000, 0,  2900), AiRole::SEA, false), // P4 

        StartSpot(AIFloat3( 8800, 0,  1100), AiRole::AIR, false), // P5 
        StartSpot(AIFloat3( 10100, 0,  3200), AiRole::SEA, false), // P6 
    	StartSpot(AIFloat3( 11000, 0,  1600), AiRole::SEA, false),   // P7 
    	StartSpot(AIFloat3( 12800, 0, 2700), AiRole::SEA, false),   // P8 

    	StartSpot(AIFloat3(  2800, 0,  12600), AiRole::SEA, false),
    	StartSpot(AIFloat3(  4500, 0, 13800), AiRole::SEA, false),
        StartSpot(AIFloat3( 6600, 0, 14250), AiRole::AIR, false), 
        StartSpot(AIFloat3( 8000, 0,  13000), AiRole::SEA, false), 

        StartSpot(AIFloat3( 8800, 0,  14300), AiRole::SEA, false),
        StartSpot(AIFloat3( 10100, 0,  13000), AiRole::SEA, false), 
    	StartSpot(AIFloat3( 11000, 0,  14200), AiRole::SEA, false),  
    	StartSpot(AIFloat3( 12800, 0, 12500), AiRole::SEA, false)
    };

	// Base per-map unit limits
	dictionary getMapUnitLimits() {
		dictionary limits; // add per-map unit restrictions here if needed
		limits.set("armvp", 0);
		limits.set("armavp", 0);
		limits.set("corvp", 0);
		limits.set("coravp", 0);
		limits.set("legvp", 0);
		limits.set("legavp", 0);
		limits.set("armlab", 0);
		limits.set("corlab", 0);
		limits.set("leglab", 0);
		return limits;
	}

	MapConfig config = MapConfig("Serene Caldera", getMapUnitLimits(), spots, getFactoryWeights());

	// (Replaced getMaxUnits() with mapUnitLimits dictionary above)

	// Example factory weights per role (higher weight = more likely).
	// New v2 schema: role -> ( side -> (factory -> weight) )
	dictionary getFactoryWeights() {
		dictionary root; // role -> sideDict
		// AIR role
		dictionary airArm; airArm.set("armap",3); 
		dictionary airCor; airCor.set("corap",3); 
		dictionary airLeg; airLeg.set("legap",3);

		dictionary airRole; airRole.set("armada", @airArm); airRole.set("cortex", @airCor); airRole.set("legion", @airLeg);
		root.set("AIR", @airRole);

		// SEA role
		dictionary seaArm; seaArm.set("armsy",5); seaArm.set("armhp",1); 
		dictionary seaCor; seaCor.set("corsy",5); seaCor.set("corhp",1); 
		dictionary seaLeg; seaLeg.set("legsy",5); seaLeg.set("corhp",1);

		dictionary seaRole; seaRole.set("armada", @seaArm); seaRole.set("cortex", @seaCor); seaRole.set("legion", @seaLeg);
		root.set("SEA", @seaRole);

		// TECH role
		dictionary techArm; techArm.set("armlab",4);
		dictionary techCor; techCor.set("corlab",4);
		dictionary techLeg; techLeg.set("leglab",4);

		dictionary techRole; techRole.set("armada", @techArm); techRole.set("cortex", @techCor); techRole.set("legion", @techLeg);
		
		root.set("TECH", @techRole); 

		return root;
	}

} 
