
#include "helpers/generic_helpers.as"

//Maps
#include "maps/default_map_config.as"
#include "maps/swirly_rock.as"
#include "maps/all_that_glitters.as"
#include "maps/supreme_isthmus.as"
#include "maps/eight_horses.as"
#include "maps/flats_and_forests.as"
#include "maps/glacial_gap.as"
#include "maps/forge.as"
#include "maps/red_river_estuary.as"
#include "maps/serene_caldera.as"
#include "maps/shore_to_shore.as"
#include "maps/koom_valley.as"
#include "maps/swirly_rock.as"
#include "maps/acidic_quarry.as"
#include "maps/tempest.as"
#include "maps/tundra_continents.as"
#include "maps/raptor_crater.as"
#include "maps/sinkhole_network.as"
#include "maps/ancient_bastion_remake.as"
#include "maps/mediterraneum.as"

namespace Maps {
    MapConfigManager@ mapManager = MapConfigManager(DEFAULT_MAP_CONFIG);

    void registerMaps() {
        GenericHelpers::LogUtil("Registering map configurations...", 1);
        
		// Initialize per-map extras (objectives, etc.) before registration
		SupremeIsthmus::registerObjectives();

		mapManager.RegisterMapConfig(SupremeIsthmus::config);
		mapManager.RegisterMapConfig(AllThatGlitters::config);
        mapManager.RegisterMapConfig(EightHorses::config);
        mapManager.RegisterMapConfig(FlatsAndForests::config);
        mapManager.RegisterMapConfig(GlacialGap::config);
        mapManager.RegisterMapConfig(Forge::config);
        mapManager.RegisterMapConfig(RedRiverEstuary::config);
        mapManager.RegisterMapConfig(SereneCaldera::config);
        mapManager.RegisterMapConfig(ShoreToShore::config);
        mapManager.RegisterMapConfig(SwirlyRock::config);
        mapManager.RegisterMapConfig(KoomValley::config);
        mapManager.RegisterMapConfig(AcidicQuarry::config);
        mapManager.RegisterMapConfig(Tempest::config);
        mapManager.RegisterMapConfig(TundraContinents::config);
        mapManager.RegisterMapConfig(RaptorCrater::config);
        mapManager.RegisterMapConfig(SinkholeNetwork::config);
        mapManager.RegisterMapConfig(AncientBastionRemake::config);
        mapManager.RegisterMapConfig(Mediterraneum::config);

        GenericHelpers::LogUtil("Finished registering map configurations.", 1);
    }
}