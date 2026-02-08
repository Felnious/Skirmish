#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace EightHorses {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
	// Start spots for Eight Horses map (from resources/data/maps/eight_horses.yaml)
	// Roles set to match YAML team roles: FRONT everywhere except SEA at P3 and P11
	StartSpot@[] spots = {
		StartSpot(AIFloat3(  795, 0,  211), AiRole::FRONT, false), // P1
		StartSpot(AIFloat3(  683, 0, 2016), AiRole::AIR, false), // P2
		StartSpot(AIFloat3(  320, 0, 3580), AiRole::SEA,   false), // P3
		StartSpot(AIFloat3(  331, 0, 5162), AiRole::FRONT, false), // P4
		StartSpot(AIFloat3(  671, 0, 6122), AiRole::FRONT, false), // P5
		StartSpot(AIFloat3(  905, 0, 7170), AiRole::FRONT_TECH, false), // P6
		StartSpot(AIFloat3(  718, 0, 8383), AiRole::FRONT, false), // P7
		StartSpot(AIFloat3(  970, 0, 9829), AiRole::FRONT, false), // P8
		StartSpot(AIFloat3(11492, 0,  226), AiRole::FRONT, false), // P9
		StartSpot(AIFloat3(11598, 0, 2013), AiRole::AIR, false), // P10
		StartSpot(AIFloat3(11883, 0, 3555), AiRole::SEA,   false), // P11
		StartSpot(AIFloat3(11934, 0, 5164), AiRole::FRONT, false), // P12
		StartSpot(AIFloat3(11619, 0, 6116), AiRole::FRONT, false), // P13
		StartSpot(AIFloat3(11380, 0, 7138), AiRole::FRONT_TECH, false), // P14
		StartSpot(AIFloat3(11541, 0, 8370), AiRole::FRONT, false), // P15
		StartSpot(AIFloat3(11289, 0, 9831), AiRole::FRONT, false)  // P16
	};

	// Base per-map unit limits
	dictionary getMapUnitLimits() {
		dictionary d; // per-map unit restrictions
		// Disable Amphbot Lab (coramph) on this map
		d.set("coramph", 0);
		return d;
	}

	MapConfig config = MapConfig("Eight Horses", getMapUnitLimits(), spots, getFactoryWeights());

	// (Replaced getMaxUnits() with mapUnitLimits dictionary above)

	// Example factory weights per role (higher weight = more likely).
	// New v2 schema: role -> ( side -> (factory -> weight) )
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

		// SEA role
		dictionary seaArm; seaArm.set("armsy",4); 
		dictionary seaCor; seaCor.set("corsy",4); 
		dictionary seaLeg; seaLeg.set("legsy",4);

		dictionary seaRole; seaRole.set("armada", @seaArm); seaRole.set("cortex", @seaCor); seaRole.set("legion", @seaLeg);
		root.set("SEA", @seaRole);

		// HOVER_SEA role
		dictionary hoverSeaArm; hoverSeaArm.set("armhs",4);  hoverSeaArm.set("armhp",4);  hoverSeaArm.set("armsy",4); 
		dictionary hoverSeaCor; hoverSeaCor.set("corhs",4);  hoverSeaCor.set("corhp",4);  hoverSeaCor.set("corsy",4);
		dictionary hoverSeaLeg; hoverSeaLeg.set("leghs",4);  hoverSeaLeg.set("leghp",4);  hoverSeaLeg.set("legsy",4);

		dictionary hoverSeaRole; hoverSeaRole.set("armada", @hoverSeaArm); hoverSeaRole.set("cortex", @hoverSeaCor); hoverSeaRole.set("legion", @hoverSeaLeg);
		root.set("HOVER_SEA", @hoverSeaRole);

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
