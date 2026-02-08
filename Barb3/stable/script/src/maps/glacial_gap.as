#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace GlacialGap {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
	// Start spots for Eight Horses map (converted from YAML, roles matched to AiRole enum)
	StartSpot@[] spots = {
		StartSpot(AIFloat3(  490, 0,  1140), AiRole::TECH, false),       
		StartSpot(AIFloat3(  1800, 0, 1400), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  430, 0, 2300), AiRole::FRONT, false),        
		StartSpot(AIFloat3(  1800, 0, 2550), AiRole::FRONT, false),    

		StartSpot(AIFloat3(  1430, 0, 4000), AiRole::SEA, false),     
		StartSpot(AIFloat3(  700, 0, 4600), AiRole::SEA, false),      
		StartSpot(AIFloat3(  1900, 0, 5800), AiRole::SEA, false), 
		StartSpot(AIFloat3(  880, 0, 6850), AiRole::HOVER_SEA, false), 
		    
		StartSpot(AIFloat3(  12572, 0,  1400), AiRole::FRONT, false),       
		StartSpot(AIFloat3(  14000, 0, 1100), AiRole::TECH, false),       
		StartSpot(AIFloat3(  12640, 0, 2500), AiRole::FRONT, false),        
		StartSpot(AIFloat3(  13890, 0, 2246), AiRole::FRONT, false),    

		StartSpot(AIFloat3(  12925, 0, 4000), AiRole::SEA, false),     
		StartSpot(AIFloat3(  13700, 0, 4600), AiRole::SEA, false),      
		StartSpot(AIFloat3(  12618, 0, 5800), AiRole::SEA, false), 
		StartSpot(AIFloat3(  13454, 0, 6850), AiRole::HOVER_SEA, false)        
	};

	// Role-specific unit limit overlays: for HOVER_SEA, disallow vehicle labs
	dictionary getRoleUnitLimits() {
		dictionary roleUnitLimits; // roleKey -> (unitName -> cap)
		dictionary hoverSeaLimits;
		hoverSeaLimits.set("armvp", 0);
		hoverSeaLimits.set("corvp", 0);
		hoverSeaLimits.set("legvp", 0);
		roleUnitLimits.set("HOVER_SEA", @hoverSeaLimits);
		return roleUnitLimits;
	}

	// Base per-map unit limits
	dictionary getMapUnitLimits() {
		dictionary limits; // add per-map unit restrictions here if needed
		limits.set("armthor", 0);
		return limits;
	}

	MapConfig config = MapConfig("Glacial Gap", getMapUnitLimits(), spots, getFactoryWeights(), getRoleUnitLimits());

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
