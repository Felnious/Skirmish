#include "../src/common.as"
#include "../src/unit.as"

namespace Init {
	
	SInitInfo AiInit()
	{
		AiLog("hard AngelScript Rules!");

		SInitInfo data;
		data.armor = InitArmordef();
		data.category = InitCategories();
		@data.profile = @(array<string> = {
			"ArmadaBehaviour", 
			"CortexBehaviour", 
			"ArmadaBuildChain", 
			"CortexBuildChain", 
			"block_map", 
			"commander", 
			"ArmadaEconomy", 
			"CortexEconomy", 
			"ArmadaFactory", 
			"CortexFactory", 
			"response"});
		if (string(aiSetupMgr.GetModOptions()["experimentallegionfaction"]) == "1") {
			AiLog("Inserting Legion");
			Side::LEGION = aiSideMasker.GetTypeMask("legion");
			data.profile.insertLast("LegionBehaviour");
			data.profile.insertLast("LegionBuildChain");
			data.profile.insertLast("commander_leg");
			data.profile.insertLast("LegionEconomy");
			data.profile.insertLast("LegionFactory");
		} else {
			AiLog("Ignoring Legion");
		}
		if (string(aiSetupMgr.GetModOptions()["scavunitsforplayers"]) == "1") {
			AiLog("Inserting Scav Units");
			data.profile.insertLast("extrascavunits");
		} else {
			AiLog("Ignoring Scav Units");
		}
		if (string(aiSetupMgr.GetModOptions()["experimentalextraunits"]) == "1") {
			AiLog("Inserting Extra Units");
			data.profile.insertLast("extraunits");
		} else {
			AiLog("Ignoring Extra Units");
		}
		return data;
	}

}