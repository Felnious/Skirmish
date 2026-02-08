namespace Objectives {
    // Reusable building/type taxonomy for objectives and other systems
    enum BuildingType {
        // Tier 1
        T1_LIGHT_AA = 0,
        T1_MEDIUM_AA,
        T1_LIGHT_TURRET,
        T1_MED_TURRET,
        T1_ARTY,
        T1_TORP,
        T1_JAMMER,
        T1_RADAR,
        T1_ENERGY,
        T1_TIDAL,    // New: Tidal generator (water energy)
        // Basic economy structures
        T1_MEX,      // Metal Extractor on a metal spot
        T1_GEO,      // Geothermal Plant on a geo spot
        SEAPLANE_FACTORY,

        // Tier 2
        T2_FLAK_AA,
        T2_RANGE_AA,
        T2_MED_TURRET,
        T2_ARTY,
        T2_JAMMER,
        T2_RADAR,
        T2_ENERGY,

        // Long range
        LRPC,
        LRPC_HEAVY
    }
}
