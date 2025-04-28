#include "../common.as"
#include "../unit.as"


namespace Init {

SInitInfo AiInit()
{
	AiLog("Extreme AngelScript Rules!");

	SInitInfo data;
	data.armor = InitArmordef();
	data.category = InitCategories();
	@data.profile = @(array<string> = {"behaviour", "block_map", "build_chain", "commander", "economy", "factory", "response"});

if (string(aiSetupMgr.GetModOptions()["experimentallegionfaction"]) == "1") {
    Side::LEGION = aiSideMasker.GetTypeMask("legion");
    data.profile.insertAt(data.profile.length(), {"behaviour_leg", "block_map_leg", "build_chain_leg", "commander_leg", "economy_leg", "factory_leg"});
	}
}
}
