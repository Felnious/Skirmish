// High-level AI strategy toggles
// Multiple strategies can be enabled simultaneously per role via a bitmask.
// Keep this enum small and stable; append new values to avoid renumbering.
enum Strategy {
    T2_RUSH = 0,      // Prioritize reaching T2 quickly (labs, eco thresholds)
    T3_RUSH = 1,      // Prioritize reaching T3/experimental (e.g., Gantry)
    NUKE_RUSH = 2,    // Prioritize early nuclear capabilities (within safe eco bounds)
}

// Utilities for logging and display of strategy sets
namespace StrategyUtil {
    // Bit helper for a given strategy index
    uint Bit(const Strategy s) { return (uint(1) << uint(s)); }

    // Generic helpers operating on bitmasks. Return the updated mask instead of using &inout
    // to avoid reference-qualifier issues on primitive types.
    uint Enable(uint mask, const Strategy s) { return (mask | Bit(s)); }
    uint Disable(uint mask, const Strategy s) { return (mask & ~Bit(s)); }
    bool Has(const uint mask, const Strategy s) { return (mask & Bit(s)) != 0; }

    string ToString(const Strategy s) {
        switch (s) {
            case Strategy::T2_RUSH: return "T2_RUSH";
            case Strategy::T3_RUSH: return "T3_RUSH";
            case Strategy::NUKE_RUSH: return "NUKE_RUSH";
        }
        return "UNKNOWN";
    }

    string NamesFromMask(uint mask) {
        array<string> names;
        for (uint i = 0; i < 32; ++i) { // up to 32 flags
            if ((mask & (uint(1) << i)) != 0) {
                names.insertLast(ToString(Strategy(int(i))));
            }
        }
        if (names.length() == 0) return "<none>";
        string joined = names[0];
        for (uint j = 1; j < names.length(); ++j) joined += "," + names[j];
        return joined;
    }
}
