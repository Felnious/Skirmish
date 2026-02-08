#include "../define.as"
#include "../types/start_spot.as"
#include "../types/map_config.as"

namespace ShoreToShore {
	/*
	Shore_to_Shore_V3 map profile
	- Purpose: Provide start spots, per-role factory weights, and per-map unit caps.
	- Notes:
	  * Vehicle plants are disabled via map unit limits (water-heavy map); weights may still list them for consistency across roles, but caps prevent building.
	  * landLocked is currently false for all spots. If peninsulas/islands are detected later, we can flip to require hover/amph starts.
	*/

	// Start spots for Shore_to_Shore_V3 (converted from YAML, roles matched to AiRole enum)
	// landLocked heuristic: currently false for all
	StartSpot@[] spots = {
		StartSpot(AIFloat3(  560, 0,  730), AiRole::TECH,      false),
		StartSpot(AIFloat3(  550, 0, 1740), AiRole::AIR,       false),
		StartSpot(AIFloat3(  340, 0, 2700), AiRole::HOVER_SEA, false),

		StartSpot(AIFloat3( 2000, 0,  730), AiRole::SEA,       false),
		StartSpot(AIFloat3( 2000, 0, 1740), AiRole::SEA,       false),
		StartSpot(AIFloat3( 2000, 0, 2700), AiRole::SEA,       false),

		StartSpot(AIFloat3(14800, 0,  550), AiRole::TECH,      false),
		StartSpot(AIFloat3(14800, 0, 1450), AiRole::AIR,       false),
		StartSpot(AIFloat3(14800, 0, 2300), AiRole::HOVER_SEA, false),

		StartSpot(AIFloat3(13250, 0,  730), AiRole::SEA,       false),
		StartSpot(AIFloat3(13250, 0, 1740), AiRole::SEA,       false),
		StartSpot(AIFloat3(13250, 0, 2700), AiRole::SEA,       false)
	};

	// Role-specific unit limit overlays (roleKey -> (unitName -> cap))
	// Currently unused; keep for future role gating.
	dictionary getRoleUnitLimits()
	{
		dictionary roleUnitLimits;
		return roleUnitLimits;
	}

	// Base per-map unit limits (disallow vehicle plants). Add more as needed.
	dictionary getMapUnitLimits()
	{
		dictionary limits;
		// Allow T1 land factories so T1 constructors can be built
		limits.set("armvp", 0);
		limits.set("corvp", 0);
		limits.set("legvp", 0);
		// Disable T2 vehicle plants (land)
		// limits.set("armavp", 0);
		// limits.set("coravp", 0);
		// limits.set("legavp", 0);

		// Prevent all land T1 combat units (constructors remain allowed). Hover units remain allowed.
		// ARMADA - T1 land combat bots
		limits.set("armpw", 0);    // Pawn (raider bot)
		limits.set("armwar", 0);   // Centurion (riot bot)
		limits.set("armrock", 0);  // Rocket Bot
		// ARMADA - T1 land combat vehicles
		limits.set("armflash", 0); // Fast Assault Tank
		limits.set("armstump", 0); // Medium Assault Tank
		limits.set("armart", 0);   // Light Artillery Vehicle
		limits.set("armsam", 0);   // Missile Truck
		limits.set("armjanus", 0); // Twin Medium Rocket Launcher
		limits.set("armyork", 0);  // AA Flak Vehicle
		limits.set("armgremlin", 0); // Stealth Tank

		// CORTEX - T1 land combat bots
		limits.set("corak", 0);    // Fast Infantry Bot (raider)
		limits.set("corthud", 0);  // Light Plasma Bot (riot)
		limits.set("corstorm", 0); // Rocket Bot (skirm)
		// CORTEX - T1 land combat vehicles
		limits.set("corgator", 0); // Light Tank (raider)
		limits.set("corraid", 0);  // Medium Assault Tank
		limits.set("corlevlr", 0); // Anti-Swarm Tank (riot)
		limits.set("corwolv", 0);  // Light Mobile Artillery
		limits.set("cormist", 0);  // Missile Truck

		// LEGION - T1 land combat bots
		limits.set("leggob", 0);   // Light Skirmish Bot
		limits.set("legshot", 0);  // Shielded Riot Bot
		limits.set("legstr", 0);   // Fast Raider Bot
		// LEGION - T1 land combat vehicles
		limits.set("legmrv", 0);   // Fast Raider Vehicle
		limits.set("leghelios", 0); // Skirmisher Tank

		return limits;
	}

	// Example factory weights per role (higher weight => more likely)
	// Schema v2: role -> ( side -> (factory -> weight) )
	dictionary getFactoryWeights()
	{
		dictionary root; // role -> sideDict

		// FRONT role
		dictionary frontArm; frontArm.set("armlab", 2); frontArm.set("armvp", 5);
		dictionary frontCor; frontCor.set("corlab", 2); frontCor.set("corvp", 5);
		dictionary frontLeg; frontLeg.set("leglab", 2); frontLeg.set("legvp", 5);
		dictionary frontRole; frontRole.set("armada", @frontArm); frontRole.set("cortex", @frontCor); frontRole.set("legion", @frontLeg);
		root.set("FRONT", @frontRole);

		// AIR role
		dictionary airArm; airArm.set("armap", 3);
		dictionary airCor; airCor.set("corap", 3);
		dictionary airLeg; airLeg.set("legap", 3);
		dictionary airRole; airRole.set("armada", @airArm); airRole.set("cortex", @airCor); airRole.set("legion", @airLeg);
		root.set("AIR", @airRole);

		// SEA role
		dictionary seaArm; seaArm.set("armsy", 4);
		dictionary seaCor; seaCor.set("corsy", 4);
		dictionary seaLeg; seaLeg.set("legsy", 4);
		dictionary seaRole; seaRole.set("armada", @seaArm); seaRole.set("cortex", @seaCor); seaRole.set("legion", @seaLeg);
		root.set("SEA", @seaRole);

		// HOVER_SEA role
		dictionary hoverSeaArm; hoverSeaArm.set("armhs", 4); hoverSeaArm.set("armhp", 4); hoverSeaArm.set("armsy", 4);
		dictionary hoverSeaCor; hoverSeaCor.set("corhs", 4); hoverSeaCor.set("corhp", 4); hoverSeaCor.set("corsy", 4);
		dictionary hoverSeaLeg; hoverSeaLeg.set("leghs", 4); hoverSeaLeg.set("leghp", 4); hoverSeaLeg.set("legsy", 4);
		dictionary hoverSeaRole; hoverSeaRole.set("armada", @hoverSeaArm); hoverSeaRole.set("cortex", @hoverSeaCor); hoverSeaRole.set("legion", @hoverSeaLeg);
		root.set("HOVER_SEA", @hoverSeaRole);

		// TECH role
		dictionary techArm; techArm.set("armlab", 4);
		dictionary techCor; techCor.set("corlab", 4);
		dictionary techLeg; techLeg.set("leglab", 4);
		dictionary techRole; techRole.set("armada", @techArm); techRole.set("cortex", @techCor); techRole.set("legion", @techLeg);
		root.set("TECH", @techRole);

		// FRONT_TECH role
		dictionary frontTechHybridArm; frontTechHybridArm.set("armlab", 4);
		dictionary frontTechHybridCor; frontTechHybridCor.set("corlab", 4);
		dictionary frontTechHybridLeg; frontTechHybridLeg.set("leglab", 4);
		dictionary frontTechHybridRole; frontTechHybridRole.set("armada", @frontTechHybridArm); frontTechHybridRole.set("cortex", @frontTechHybridCor); frontTechHybridRole.set("legion", @frontTechHybridLeg);
		root.set("FRONT_TECH", @frontTechHybridRole);

		return root;
	}

	// Consolidated map config
	MapConfig config = MapConfig("Shore_to_Shore_V3", getMapUnitLimits(), spots, getFactoryWeights(), getRoleUnitLimits());

}
