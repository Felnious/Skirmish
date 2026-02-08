// BuildingType moved to its own reusable definition file
#include "building_type.as"
#include "../task.as"

namespace Objectives {

    enum ConstructorClass {
        ANY = 0,
        BOT,
        VEH,
        AIR,
        SEA,
        HOVER
    }

    // Which builder leadership group should handle this objective
    enum BuilderGroup {
        PRIMARY = 0,
        SECONDARY,
        TACTICAL
    }

    // A single, generic strategic objective. Keep fields simple and optional.
    // Step within a strategic objective's ordered build chain
    class ObjectiveStep {
        // What to build/do at this step
        BuildingType type;
        // How many times to perform this step (default 1)
        int count = 1;
        // Optional per-step eco gates (<= 0 to ignore)
        float minMetalIncome = 0.0f;
        float minEnergyIncome = 0.0f;
        // Optional per-step priority (default NOW to avoid stalling)
        Task::Priority priority = Task::Priority::NOW;
    }

    // A single, generic strategic objective. Keep fields simple and optional.
    class StrategicObjective {
        string id;
        // Each position can carry an ordered list of objective types to fulfill.
        // Order implies progression (e.g., RUSH_AA -> BUILD_LLT -> UPGRADE_AA -> BUILD_T2_ARTILLERY).
        array<BuildingType> types;

        // Point goal or ordered line for defenses
        AIFloat3 pos;               // optional
        array<AIFloat3> line;       // optional
        float radius = 0.0f;        // optional: coverage/build radius (0 = default heuristic)
        float objectiveBaseRange = 0.0f; // optional: max distance from base (StartPos) to consider this objective (0 = default)

        // Filters
        array<AiRole> roles;        // allowed roles
        array<string> sides;        // "armada","cortex","legion"
        array<ConstructorClass> classes; // required constructor classes
        array<int> tiers;           // allowed tiers (e.g., 1 or 2)

        // Timing/eco gates (<= 0 means ignore)
        int startFrameMax = 0;
        float minMetalIncome = 0;
        float minEnergyIncome = 0;

        // Priority: higher first
        int priority = 0;

        // Freeform metadata
        string note;

        // Preferred builder group to execute this objective; default PRIMARY to preserve existing behavior
        BuilderGroup builderGroup = BuilderGroup::PRIMARY;
        array<ObjectiveStep@> steps;

        // Convenience: add a step to this objective (overloads)
        void AddStep(BuildingType t)
        {
            ObjectiveStep@ s = ObjectiveStep();
            s.type = t; s.count = 1; s.minMetalIncome = 0.0f; s.minEnergyIncome = 0.0f; s.priority = Task::Priority::NOW;
            steps.insertLast(s);
        }

        void AddStep(BuildingType t, int count)
        {
            ObjectiveStep@ s = ObjectiveStep();
            s.type = t; s.count = count; s.minMetalIncome = 0.0f; s.minEnergyIncome = 0.0f; s.priority = Task::Priority::NOW;
            steps.insertLast(s);
        }

        void AddStep(BuildingType t, int count, float minMetalIncome, float minEnergyIncome)
        {
            ObjectiveStep@ s = ObjectiveStep();
            s.type = t; s.count = count; s.minMetalIncome = minMetalIncome; s.minEnergyIncome = minEnergyIncome; s.priority = Task::Priority::NOW;
            steps.insertLast(s);
        }

        // Overload with explicit priority
        void AddStep(BuildingType t, int count, float minMetalIncome, float minEnergyIncome, Task::Priority prio)
        {
            ObjectiveStep@ s = ObjectiveStep();
            s.type = t; s.count = count; s.minMetalIncome = minMetalIncome; s.minEnergyIncome = minEnergyIncome; s.priority = prio;
            steps.insertLast(s);
        }
    }

}
