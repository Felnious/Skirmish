// Supreme Isthmus v2.1 map data & role / start spot + config consolidation (refactored 2025-09)
#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"
#include "../types/strategic_objectives.as"
// Step helpers
#include "../helpers/objective_helpers.as"

namespace SupremeIsthmus {
	// NOTE: This map file intentionally holds only static data (start spots & MapConfig).
	// Role determination and factory selection now occur in Main::AiMain using shared helpers.

	// landLocked heuristic (initial): none flagged yet on this map; future pass may mark
	// isolated peninsulas requiring hover/amph first. Pass false for all for now.
    StartSpot@[] spots = {
    	StartSpot(AIFloat3(  711, 0,  7218), AiRole::HOVER_SEA, false), // P1 (sea)
    	StartSpot(AIFloat3(  837, 0, 10407), AiRole::TECH, false), // P2 (tech)
        StartSpot(AIFloat3( 2155, 0, 11747), AiRole::AIR, false), // P3 (air)
        StartSpot(AIFloat3( 2513, 0,  7983), AiRole::FRONT, false), // P4 (front)
        StartSpot(AIFloat3( 4595, 0,  7440), AiRole::FRONT, false), // P5 (front)
        StartSpot(AIFloat3( 4997, 0,  8570), AiRole::FRONT, false), // P6 (front)
    	StartSpot(AIFloat3( 4375, 0,  9800), AiRole::FRONT_TECH, false),   // P7 (front/tech -> FRONT_TECH)
    	StartSpot(AIFloat3( 4814, 0, 11077), AiRole::SEA, false),   // P8 (sea)
    	StartSpot(AIFloat3(11579, 0,  5063), AiRole::HOVER_SEA, false),   // P9 (sea)
    	StartSpot(AIFloat3(11456, 0,  1901), AiRole::TECH, false),   // P10 (tech)
        StartSpot(AIFloat3(10129, 0,   541), AiRole::AIR, false),   // P11 (air)
        StartSpot(AIFloat3( 9764, 0,  4339), AiRole::FRONT, false), // P12 (front)
        StartSpot(AIFloat3( 7729, 0,  4835), AiRole::FRONT, false), // P13 (front)
        StartSpot(AIFloat3( 7292, 0,  3727), AiRole::FRONT, false), // P14 (front)
    	StartSpot(AIFloat3( 7925, 0,  2500), AiRole::FRONT_TECH, false),   // P15 (front/tech -> FRONT_TECH)
    	StartSpot(AIFloat3( 7492, 0,  1220), AiRole::SEA, false)    // P16 (sea)
    };

	// Base per-map unit limits
	dictionary getMapUnitLimits() {
		dictionary limits; // add per-map unit restrictions here if needed
		limits.set("armpincer", 0);
		limits.set("corgarp", 0);
		return limits;
	}

	MapConfig config = MapConfig("Supreme Isthmus", getMapUnitLimits(), spots, getFactoryWeights());

	// Register strategic objectives for Supreme Isthmus
	void registerObjectives()
	{
		// 1) Island with two mexes: AIR constructor required.
		//    Needs light AA quickly, followed by a light laser turret; later more AA/LLT and T2 artillery.
		{
			Objectives::StrategicObjective@ o1 = Objectives::StrategicObjective();
			o1.id = "island_air_two_mexes";

			o1.AddStep(Objectives::BuildingType::T1_LIGHT_AA, 3);

			o1.pos = AIFloat3(340.f, 0.f, 12700.f); // TODO precise
			o1.radius = SQUARE_SIZE * 8.0f; // TODO tune: island build area ~5x5 squares
			o1.objectiveBaseRange = 6000.0f; // gate by base distance
			o1.roles = { AiRole::AIR };
			o1.sides = { "armada", "cortex", "legion" };
			o1.classes = { Objectives::ConstructorClass::AIR };
			o1.tiers = { 1, 2 };
			o1.startFrameMax = 0; // rush window applies to early stages
			o1.minMetalIncome = 0.0f; // keep high-level gates; per-type gates TBD
			o1.minEnergyIncome = 0.0f;
			o1.priority = 10;
			o1.note = "Island (AIR): RUSH_AA -> LLT -> UPGRADE_AA -> T2 ARTY";
			o1.builderGroup = Objectives::BuilderGroup::TACTICAL;
			config.AddObjective(o1);
		}

		// 2) Island with two mexes: HOVER constructor required.
		{
			Objectives::StrategicObjective@ o2 = Objectives::StrategicObjective();
			o2.id = "island_hover_two_mexes";

			o2.AddStep(Objectives::BuildingType::T1_LIGHT_AA, 3);
			o2.AddStep(Objectives::BuildingType::T1_LIGHT_TURRET, 1);
			o2.AddStep(Objectives::BuildingType::T1_MEX, 2);
			o2.AddStep(Objectives::BuildingType::T1_JAMMER, 1);
			o2.AddStep(Objectives::BuildingType::T1_RADAR, 1);
			o2.AddStep(Objectives::BuildingType::T1_ARTY, 1);

			o2.pos = AIFloat3(11940.f, 0.f, 10400.f); // TODO precise
			o2.radius = SQUARE_SIZE * 8.0f; // TODO tune
			o2.objectiveBaseRange = 6000.0f; // gate by base distance
			o2.roles = { AiRole::HOVER_SEA };
			o2.sides = { "armada", "cortex", "legion" };
			o2.classes = { Objectives::ConstructorClass::HOVER };
			o2.tiers = { 1 };
			o2.startFrameMax = 0; // disable time gate so objective remains detectable beyond early rush window
			o2.priority = 10;
			o2.note = "Island (HOVER): RUSH_AA -> LLT";
			o2.builderGroup = Objectives::BuilderGroup::TACTICAL;
			config.AddObjective(o2);
		}

		// 3) Hill with Geo: HOVER required. Light AA first, then better AA, later T2 artillery.
		{
			Objectives::StrategicObjective@ g1 = Objectives::StrategicObjective();
			g1.id = "hill_geo_hover";

			// New build chain: 3x AA immediately, then RADAR, then JAMMER
			//g1.AddStep(Objectives::BuildingType::T1_GEO, 1);
			g1.AddStep(Objectives::BuildingType::T1_LIGHT_AA, 3);
			g1.AddStep(Objectives::BuildingType::T1_RADAR, 1);
			g1.AddStep(Objectives::BuildingType::T1_JAMMER, 1);

			g1.pos = AIFloat3(10300.f, 0.f, 6670.f); // TODO precise geo hill
			g1.radius = SQUARE_SIZE * 32.0f; // TODO tune: hill crest area
			g1.objectiveBaseRange = 2500.0f; // gate by base distance
			g1.roles = { AiRole::HOVER_SEA };
			g1.classes = { Objectives::ConstructorClass::HOVER };
			g1.tiers = { 1, 2 };
			g1.minMetalIncome = 0.0f; // gate seaplane platform on eco as requested
			g1.minEnergyIncome = 0.0f;
			g1.startFrameMax = 0; // early AA
			g1.priority = 9;
			g1.note = "Geo hill (A): RUSH_AA -> UPGRADE_AA -> T2 ARTY";
			g1.builderGroup = Objectives::BuilderGroup::SECONDARY;
			config.AddObjective(g1);
		}

		// 4) Hill with Geo: duplicate variant (another geo location)
		{
			Objectives::StrategicObjective@ g2 = Objectives::StrategicObjective();
			g2.id = "hill_geo_hover_2";

			g2.AddStep(Objectives::BuildingType::T1_LIGHT_AA, 2);
			g2.AddStep(Objectives::BuildingType::T1_RADAR, 1);
			g2.AddStep(Objectives::BuildingType::T1_JAMMER, 1);
			//g2.AddStep(Objectives::BuildingType::T1_GEO, 1);

			g2.pos = AIFloat3(2000.f, 0.f, 5500.f); // TODO precise
			g2.radius = SQUARE_SIZE * 32.0f; // TODO tune
			g2.objectiveBaseRange = 2500.0f; // gate by base distance
			g2.roles = { AiRole::HOVER_SEA };
			g2.classes = { Objectives::ConstructorClass::HOVER };
			g2.tiers = { 1, 2 };
			g2.minMetalIncome = 20.0f; // gate seaplane platform on eco as requested
			g2.minEnergyIncome = 0.0f;
			g2.startFrameMax = 0;
			g2.priority = 8;
			g2.note = "Geo hill (B): RUSH_AA -> UPGRADE_AA -> T2 ARTY";
			g2.builderGroup = Objectives::BuilderGroup::SECONDARY;
			config.AddObjective(g2);
		}

		// 5) Naval tech spike: Build a Seaplane Platform once metal income >= 30, then spam TIDAL until energy >= 2000
		{
			Objectives::StrategicObjective@ s1 = Objectives::StrategicObjective();
			s1.id = "hover_seaplane_then_tidals";

			s1.AddStep(Objectives::BuildingType::SEAPLANE_FACTORY, 1);

			// First make a single seaplane factory, then keep adding tidals for energy
			// Place near water lane mid; exact spot can be tuned later
			s1.pos = AIFloat3(9800.f, 0.f, 3500.f); // TODO precise safe coastal/midwater build point
			s1.radius = 256.0f; // reasonable placement area for platform and tidals
			s1.objectiveBaseRange = 4000.0f; // allow mid-range from base
			s1.roles = { AiRole::HOVER_SEA };
			s1.sides = { "armada", "cortex", "legion" };
			s1.classes = { Objectives::ConstructorClass::HOVER };
			s1.tiers = { 1 };
			s1.minMetalIncome = 40.0f; // gate seaplane platform on eco as requested
			s1.minEnergyIncome = 0.0f;
			s1.priority = 7; // lower than island/geo pushes
			s1.note = "HOVER_SEA: Build 1x Seaplane Platform at >=20 metal, then TIDALs until >=2000 energy";
			s1.builderGroup = Objectives::BuilderGroup::SECONDARY;
			config.AddObjective(s1);
		}

		// 5) Naval tech spike: Build a Seaplane Platform once metal income >= 30, then spam TIDAL until energy >= 2000
		{
			Objectives::StrategicObjective@ s1 = Objectives::StrategicObjective();
			s1.id = "hover_pond_tidals";

			s1.AddStep(Objectives::BuildingType::T1_TIDAL, 20);

			// First make a single seaplane factory, then keep adding tidals for energy
			// Place near water lane mid; exact spot can be tuned later
			s1.pos = AIFloat3(9800.f, 0.f, 3500.f); // TODO precise safe coastal/midwater build point
			s1.radius = 256.0f; // reasonable placement area for platform and tidals
			s1.objectiveBaseRange = 5000.0f; // allow mid-range from base
			s1.roles = { AiRole::HOVER_SEA };
			s1.sides = { "armada", "cortex", "legion" };
			s1.classes = { Objectives::ConstructorClass::HOVER };
			s1.tiers = { 1 };
			s1.minMetalIncome = 0.0f; // gate seaplane platform on eco as requested
			s1.minEnergyIncome = 0.0f;
			s1.priority = 7; // lower than island/geo pushes
			s1.note = "HOVER_SEA: Build 1x Seaplane Platform at >=20 metal, then TIDALs until >=2000 energy";
			s1.builderGroup = Objectives::BuilderGroup::SECONDARY;
			config.AddObjective(s1);
		}
	}

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
		dictionary hoverSeaArm; hoverSeaArm.set("armhp",4); 
		dictionary hoverSeaCor; hoverSeaCor.set("corhp",4);
		dictionary hoverSeaLeg; hoverSeaLeg.set("leghp",4);

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
