#include "../src/setup.as"
#include "../src/helpers/generic_helpers.as"
#include "../src/global.as"
#include "../src/maps.as"
#include "../src/types/strategy.as" // for StrategyUtil names when logging

namespace Main {

	// Weighted strategy configuration for HARD difficulty.
	// Values are likelihoods in [0.0, 1.0] for enabling a given strategy.
	// Adjust these to tune how often a strategy is chosen at game start.
	namespace StrategyWeights {
		float Tech_T2_RUSH = 0.85f;   // 85% chance
		float Tech_T3_RUSH = 0.35f;   // 35% chance
		float Tech_NUKE_RUSH = 0.25f; // 25% chance
	}

	// Decide a boolean from a probability using AiDice with two weights: off vs on.
	bool DecideEnabled(float probability) {
		// Clamp to [0,1]
		float p = AiMax(0.0f, AiMin(probability, 1.0f));
		// Build weights {off, on}
		array<float>@ w = array<float>(2);
		w[0] = 1.0f - p;
		w[1] = p;
		int idx = AiDice(w);
		return (idx == 1);
	}

	void ApplyTechStrategyWeights() {
		// Start fresh (no strategies), then enable per dice outcome
		Global::RoleSettings::Tech::StrategyMask = 0;

		if (DecideEnabled(StrategyWeights::Tech_T2_RUSH)) {
			Global::RoleSettings::Tech::EnableStrategy(Strategy::T2_RUSH);
		}
		if (DecideEnabled(StrategyWeights::Tech_T3_RUSH)) {
			Global::RoleSettings::Tech::EnableStrategy(Strategy::T3_RUSH);
		}
		if (DecideEnabled(StrategyWeights::Tech_NUKE_RUSH)) {
			Global::RoleSettings::Tech::EnableStrategy(Strategy::NUKE_RUSH);
		}

		GenericHelpers::LogUtil(
			"[Strategy] (EXPERIMENTAL BALANCED) Decided: Tech mask=" + Global::RoleSettings::Tech::StrategyMask +
			" (" + StrategyUtil::NamesFromMask(Global::RoleSettings::Tech::StrategyMask) + ")",
			2);
	}

	void AiMain()
	{
		GenericHelpers::LogUtil("Running AiMain()", 1);

		GenericHelpers::LogUtil("registerMaps", 1);
		Maps::registerMaps();
		// Map + profile setup deferred until first factory selection in AiGetFactoryToBuild

		// HARD difficulty strategy selection: decide per-weight which strategies to enable for the TECH role
		ApplyTechStrategyWeights();

		// for (Id defId = 1, count = ai.GetDefCount(); defId <= count; ++defId) {
		// 	CCircuitDef@ cdef = ai.GetCircuitDef(defId);
		// 	if (cdef.costM >= 200.f && !cdef.IsMobile() && aiEconomyMgr.GetEnergyMake(cdef) > 1.f)
		// 		cdef.AddAttribute(Unit::Attr::BASE.type);  // Build heavy energy at base
		// }

		// Example of user-assigned custom attributes
		array<string> names = {Factory::armalab, Factory::coralab, Factory::armavp, Factory::coravp,
			Factory::armaap, Factory::coraap, Factory::armasy, Factory::corasy};
		for (uint i = 0; i < names.length(); ++i)
			Factory::userData[ai.GetCircuitDef(names[i]).id].attr |= Factory::Attr::T2;
		names = {Factory::armshltx, Factory::corgant, Factory::leggant};
		for (uint i = 0; i < names.length(); ++i)
			Factory::userData[ai.GetCircuitDef(names[i]).id].attr |= Factory::Attr::T3;

		ApplyProfileSettings();
	}

	void AiUpdate()  // SlowUpdate, every 30 frames with initial offset of skirmishAIId
	{
		if (Global::profileController !is null) {
			Global::profileController.MainUpdate();
		}
	}

	void AiLuaMessage(const string& in data)  // Spring.SendSkirmishAIMessage(teamID, msg) from unsynced lua
	{
		GenericHelpers::LogUtil("[AI][LuaMessage] ", 2);
		//GenericHelpers::LogUtil("[AI][LuaMessage] " + data, 2);
		// Minimal console integration: simple command parser for messages prefixed with "smrt" or "SMRT".
		// Example usage from widget input: smrt status
		// string s = data;
		// // trim leading/trailing spaces
		// int n = s.length();
		// int i = 0, j = (n > 0 ? n - 1 : 0);
		// while (i < n && (s[i] == 32 || s[i] == 9)) { ++i; }
		// while (j > i && (s[j] == 32 || s[j] == 9)) { --j; }
		// if (i < n) s = s.substr(i, j - i + 1);
		// if (s.length() == 0) return;

		// // lowercase copy for command detection
		// string lower = s;
		// for (uint k = 0; k < lower.length(); ++k) {
		// 	uint8 c = lower[k];
		// 	if (c >= 65 && c <= 90) { // A-Z to a-z
		// 		lower[k] = c + 32;
		// 	}
		// }
		// if (lower.length() >= 4 && lower.substr(0, 4) == "smrt") {
		// 	// Tokenize on spaces: smrt <cmd> [args]
		// 	array<string> tokens; tokens.resize(0);
		// 	string cur = ""; bool inTok = false;
		// 	for (uint t = 0; t < s.length(); ++t) {
		// 		uint8 c = s[t];
		// 		bool isSpace = (c == 32 || c == 9);
		// 		if (!isSpace) { cur += string(1, c); inTok = true; }
		// 		else if (inTok) { tokens.insertLast(cur); cur = ""; inTok = false; }
		// 	}
		// 	if (inTok) tokens.insertLast(cur);
		// 	if (tokens.length() >= 2) {
		// 		string cmdLower = tokens[1];
		// 		// normalize cmdLower
		// 		for (uint k2 = 0; k2 < cmdLower.length(); ++k2) {
		// 			uint8 cc = cmdLower[k2]; if (cc >= 65 && cc <= 90) cmdLower[k2] = cc + 32;
		// 		}
		// 		if (cmdLower == "status") {
		// 			float mi = Global::Economy::GetMetalIncome();
		// 			float ei = Global::Economy::GetEnergyIncome();
		// 			float mcur = Global::Economy::MetalCurrent;
		// 			float ecur = Global::Economy::EnergyCurrent;
		// 			float mstor = Global::Economy::MetalStorage;
		// 			float estor = Global::Economy::EnergyStorage;
		// 			GenericHelpers::LogUtil("[AI][Console] status frame=" + ai.frame +
		// 				" mi=" + mi + " ei=" + ei +
		// 				" metal=" + mcur + "/" + mstor +
		// 				" energy=" + ecur + "/" + estor,
		// 				2);
		// 			return;
		// 		}
		// 	}
		// 	GenericHelpers::LogUtil("[AI][Console] Unknown or incomplete command. Try: smrt status", 2);
		// }
	}

	//Use this to modify global.as and apply difficulty/profile settings
	void ApplyProfileSettings()
	{
	}

}  // namespace Main