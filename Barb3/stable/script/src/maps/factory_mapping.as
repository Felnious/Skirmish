// Generic factory selection helpers (extracted from Supreme Isthmus specific logic)
#include "../types/start_spot.as"

namespace FactoryMapping {
	string FactoryFor(const string &in role, const string &in side, bool landLocked) {
		if (role == "") return "";
		if (side == "armada") {
			if (role == "sea") return "armsy";
			if (role == "air") return "armap";
			if (role == "tech" || role == "front/tech") return landLocked ? "armhp" : "armlab";
			if (role == "front") return landLocked ? "armhp" : "armvp";
			return "armlab";
		}
		if (side == "cortex") {
			if (role == "sea") return "corsy";
			if (role == "air") return "corap";
			if (role == "tech" || role == "front/tech") return landLocked ? "corhp" : "corlab";
			if (role == "front") return landLocked ? "corhp" : "corvp";
			return "corlab";
		}
		if (side == "legion") {
			if (role == "sea") return "legsy";
			if (role == "air") return "legap";
			if (role == "tech" || role == "front/tech") return landLocked ? "leghp" : "leglab";
			if (role == "front") return landLocked ? "leghp" : "legvp";
			return "leglab";
		}
		return "";
	}
}
