#include "../common.as"
#include "../unit.as"


namespace Init {

SInitInfo AiInit()
{
	AiLog("Nightmare AngelScript Rules!");

	SInitInfo data;
	data.armor = InitArmordef();
	data.category = InitCategories();
	@data.profile = @(array<string> = {"behaviour_arm", "behaviour_cor", "block_map", "build_chain_arm", "build_chain_cor", "commander", "economy_arm", "economy_cor", "factory_arm", "factory_cor", "response"});
	if (string(aiSetupMgr.GetModOptions()["experimentallegionfaction"]) == "1") {
		AiLog("inserting economy_leg");
		Side::LEGION = aiSideMasker.GetTypeMask("legion");
		data.profile.insertAt(data.profile.length(), {"behaviour_leg", "build_chain_leg", "commander_leg", "economy_leg", "factory_leg"});
	} else {
		AiLog("Ignoring Legion");
	}
	return data;
}

}
