#include "global.as"
#include "unit_helpers.as"
#include "unitdef_helpers.as"
#include "../types/building_type.as"

namespace DefenseHelpers {
    // Note: These helpers provide baseline logic for when to build specific defenses.
    // Each role can override or extend this logic based on its strategic context.
    // For now, they are placeholders returning false.

    // --- Tier 1 Defenses ---

    bool ShouldBuildT1LightAA(const string &in side) {
        // TODO: Logic for building T1 Light AA (e.g., armrl, corrl).
        // Example: if enemy has light air units and we have low AA coverage.
        return false;
    }

    bool ShouldBuildT1MediumAA(const string &in side) {
        // TODO: Logic for building T1 Medium AA (e.g., armferret, corerad).
        // Example: if enemy has gunships or stronger T1 air.
        return false;
    }

    bool ShouldBuildT1LightTurret(const string &in side) {
        // TODO: Logic for building T1 Light Laser Turrets (LLT).
        // Example: to defend against early raids at chokepoints.
        return false;
    }

    bool ShouldBuildT1MediumTurret(const string &in side) {
        // TODO: Logic for building T1 Medium Turrets.
        // Note: This often maps to T2 medium turrets if no true T1 medium exists.
        return false;
    }

    bool ShouldBuildT1Arty(const string &in side) {
        // TODO: Logic for building T1 static artillery.
        // Note: This often maps to T2 artillery if no T1 version is available.
        return false;
    }

    bool ShouldBuildT1Torp(const string &in side) {
        // TODO: Logic for building T1 torpedo launchers.
        // Example: if enemy naval units are detected near our shores.
        return false;
    }

    // --- Tier 2 Defenses ---

    bool ShouldBuildT2FlakAA(const string &in side) {
        // TODO: Logic for building T2 Flak AA.
        // Example: to counter swarms of aircraft.
        return false;
    }

    bool ShouldBuildT2RangeAA(const string &in side) {
        // TODO: Logic for building T2 long-range AA.
        // Example: to defend against bombers or strategic aircraft.
        return false;
    }

    bool ShouldBuildT2MediumTurret(const string &in side) {
        // TODO: Logic for building T2 Medium Turrets (e.g., armguard, corpun).
        // Example: to fortify key defensive positions.
        return false;
    }

    bool ShouldBuildT2Arty(const string &in side) {
        // TODO: Logic for building T2 static artillery.
        // Example: to siege enemy positions or for long-range area denial.
        return false;
    }

    // --- Long Range / Superweapons ---

    bool ShouldBuildLRPC(const string &in side) {
        // TODO: Logic for building Long Range Plasma Cannons (LRPC).
        // Example: late-game when economy is strong and a strategic advantage is needed.
        return false;
    }

    bool ShouldBuildLRPCHeavy(const string &in side) {
        // TODO: Logic for building Heavy LRPCs (e.g., Ragnarok, Calamity).
        // Example: very late-game, as a win condition.
        return false;
    }
}
