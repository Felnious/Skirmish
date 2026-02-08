#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace RedRiverEstuary {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
	// Start spots for Eight Horses map (converted from YAML, roles matched to AiRole enum)
	StartSpot@[] spots = {
		StartSpot(AIFloat3(  2000, 0,  900), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  2100, 0, 2300), AiRole::AIR, false),       
		StartSpot(AIFloat3(  2000, 0, 4000), AiRole::FRONT, false),        
		StartSpot(AIFloat3(  500, 0, 5200), AiRole::FRONT_TECH, false),    

		StartSpot(AIFloat3(  1900, 0, 7200), AiRole::FRONT, false),     
		StartSpot(AIFloat3(  300, 0, 7800), AiRole::FRONT, false),      
		StartSpot(AIFloat3(  1800, 0, 9100), AiRole::SEA, false), 
		StartSpot(AIFloat3(  400, 0, 9700), AiRole::SEA, false), 
		    
		StartSpot(AIFloat3(  8060, 0,  900), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  8000, 0, 2300), AiRole::AIR, false),       
		StartSpot(AIFloat3(  9500, 0, 4500), AiRole::FRONT, false),        
		StartSpot(AIFloat3(  8200, 0, 5000), AiRole::FRONT_TECH, false),    

		StartSpot(AIFloat3(  8300, 0, 6700), AiRole::FRONT, false),     
		StartSpot(AIFloat3(  9800, 0, 7100), AiRole::FRONT, false),      
		StartSpot(AIFloat3(  8300, 0, 9200), AiRole::SEA, false), 
		StartSpot(AIFloat3(  9800, 0, 9700), AiRole::SEA, false)     
	};

	// Base per-map unit limits
	dictionary getMapUnitLimits() {
		dictionary limits; // add per-map unit restrictions here if needed
		limits.set("armthor", 0);
		return limits;
	}

	MapConfig config = MapConfig("Red River Estuary", getMapUnitLimits(), spots, getFactoryWeights());

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
