#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace KoomValley {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
	// Start spots for Koom Valley map (converted from YAML, roles matched to AiRole enum)
	StartSpot@[] spots = {
		StartSpot(AIFloat3(  410, 0,  730), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  2100, 0, 2400), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  1400, 0, 4100), AiRole::TECH, false),  

		StartSpot(AIFloat3(  300, 0, 2800), AiRole::TECH, false),  

		StartSpot(AIFloat3(  3200, 0, 4000), AiRole::FRONT, false),    
		StartSpot(AIFloat3(  2000, 0, 6000), AiRole::FRONT, false),     
		StartSpot(AIFloat3(  2050, 0, 7500), AiRole::FRONT, false),      
		         
		StartSpot(AIFloat3(  10600, 0,  730), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  10300, 0, 2400), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  10700, 0, 4100), AiRole::TECH, false),  

		StartSpot(AIFloat3(  12000, 0, 5600), AiRole::TECH, false), 

		StartSpot(AIFloat3(  9000, 0, 4000), AiRole::FRONT, false),    
		StartSpot(AIFloat3(  10700, 0, 6000), AiRole::FRONT, false),     
		StartSpot(AIFloat3(  10400, 0, 7500), AiRole::FRONT, false)
	};

	// Base per-map unit limits
	dictionary mapUnitLimits; // add per-map unit restrictions here if needed

	MapConfig config = MapConfig("Koom Valley", mapUnitLimits, spots, getFactoryWeights());

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
