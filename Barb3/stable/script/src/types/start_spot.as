// Shared types & utilities for map-aware logic
#include "../define.as"
#include "ai_role.as"

class StartSpot {
	AIFloat3 pos;
	AiRole aiRole;      // enum role for direct logic use
	bool landLocked;    // true if area is isolated from main land by water (needs hover/amphib)
	StartSpot() { aiRole = AiRole::FRONT; landLocked = false; }
	StartSpot(const AIFloat3& in p, AiRole r, const bool ll = false) {
		pos = p; aiRole = r; landLocked = ll;
	}
}