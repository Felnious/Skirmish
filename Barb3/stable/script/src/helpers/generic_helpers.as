#include "../define.as"
#include "../global.as"
#include "../types/ai_role.as"
#include "../types/start_spot.as" // for StartSpot & AIFloat3

namespace GenericHelpers {
    void RecordStart(const AIFloat3& in pos, AiRole role) {
        if (!Global::Map::HasStart) {
            Global::Map::StartPos = pos;
            Global::Map::StartRole = role;
            Global::Map::HasStart = true;
            LogUtil("Captured start position (" + pos.x + "," + pos.z + ") role=" + role, 1);
        }
    }

    void LogUtil(string message, int level) {
        if (LOG_LEVEL >= level) {
            AiLog(":::AI LOG:S:" + ai.skirmishAIId + ":T:" + ai.teamId + ":F:" + ai.frame + ":L:" + ":" + message);
        } 
    }

    void LogUtil(string message, AiRole aiRole, int level) {
        if (LOG_LEVEL >= level) {
            AiLog(":::AI LOG:S:" + ai.skirmishAIId + ":T:" + ai.teamId + ":F:" + ai.frame + ":L:" + ":R:" + aiRole + ":" + message);
        } 
    }


  
}