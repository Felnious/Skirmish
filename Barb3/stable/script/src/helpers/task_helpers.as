#include "../task.as"

namespace TaskHelpers {
    // --- tiny helpers for readable logs ---
    string TaskTypeName(Task::Type t) {
        GenericHelpers::LogUtil("[TECH] Enter TaskTypeName", 4);
        switch (t) {
            case Task::Type::NIL: return "NIL";
            case Task::Type::PLAYER: return "PLAYER";
            case Task::Type::IDLE: return "IDLE";
            case Task::Type::WAIT: return "WAIT";
            case Task::Type::RETREAT: return "RETREAT";
            case Task::Type::BUILDER: return "BUILDER";
            case Task::Type::FACTORY: return "FACTORY";
            case Task::Type::FIGHTER: return "FIGHTER";
            default: return "UNKNOWN_TYPE";
        }
    }
    string BuildTypeName(Task::BuildType bt) {
        GenericHelpers::LogUtil("[TECH] Enter BuildTypeName", 4);
        switch (bt) {
            case Task::BuildType::FACTORY: return "FACTORY";
            case Task::BuildType::NANO: return "NANO";
            case Task::BuildType::STORE: return "STORE";
            case Task::BuildType::PYLON: return "PYLON";
            case Task::BuildType::ENERGY: return "ENERGY";
            case Task::BuildType::GEO: return "GEO";
            case Task::BuildType::GEOUP: return "GEOUP";
            case Task::BuildType::DEFENCE: return "DEFENCE";
            case Task::BuildType::BUNKER: return "BUNKER";
            case Task::BuildType::BIG_GUN: return "BIG_GUN";
            case Task::BuildType::RADAR: return "RADAR";
            case Task::BuildType::SONAR: return "SONAR";
            case Task::BuildType::CONVERT: return "CONVERT";
            case Task::BuildType::MEX: return "MEX";
            case Task::BuildType::MEXUP: return "MEXUP";
            case Task::BuildType::REPAIR: return "REPAIR";
            case Task::BuildType::RECLAIM: return "RECLAIM";
            case Task::BuildType::RESURRECT: return "RESURRECT";
            case Task::BuildType::RECRUIT: return "RECRUIT";
            case Task::BuildType::TERRAFORM: return "TERRAFORM";
            default: return "UNKNOWN_BUILD";
        }
    }
}