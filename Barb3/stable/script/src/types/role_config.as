#include "ai_role.as"
#include "../define.as"
#include "../helpers/generic_helpers.as"
#include "../helpers/unit_helpers.as" // for FactoryIsLand/Water
#include "profile_controller.as" // for MainUpdateDelegate

// Role-based factory switching delegates

funcdef void InitDelegate();

funcdef bool AiIsSwitchTimeDelegate(int lastSwitchFrame);
funcdef bool AiIsSwitchAllowedDelegate(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired);

funcdef void AiUnitAddedDelegate(CCircuitUnit@ unit, Unit::UseAs usage);
funcdef void AiUnitRemovedDelegate(CCircuitUnit@ unit, Unit::UseAs usage);

funcdef IUnitTask@ AiMakeTaskDelegate(CCircuitUnit@ u);

funcdef void AiTaskAddedDelegate(IUnitTask@ task);
funcdef void AiTaskRemovedDelegate(IUnitTask@ task, bool done);

funcdef int MakeSwitchIntervalDelegate();

//Role based Factory Selection
funcdef string SelectFactoryDelegate(const AIFloat3& in pos, bool isStart, bool isReset);

// Role-based economy update delegate; pass manager handles as generic refs to avoid engine type dependency here
funcdef void EconomyUpdateDelegate();


funcdef bool AiIsAirValidDelegate();
funcdef void AiMakeDefence(int cluster, const AIFloat3& in pos);

// Dynamic role matching: boolean match; first registered match wins
funcdef bool RoleMatchDelegate(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory);

class RoleConfig {
    AiRole role;
    dictionary UnitMaxOverrides; // unitName -> max cap (int)
    MainUpdateDelegate@ MainUpdateHandler; // optional role-specific update delegate
    EconomyUpdateDelegate@ EconomyUpdateHandler; // optional per-role economy update
    InitDelegate@ InitHandler; // optional initialization hook

    // Factory switching policy
    int switchInterval = 0; // frames until next switch allowed (managed per role)
    AiIsSwitchTimeDelegate@ AiIsSwitchTimeHandler;
    AiIsSwitchAllowedDelegate@ AiIsSwitchAllowedHandler;
    MakeSwitchIntervalDelegate@ MakeSwitchIntervalHandler;

    AiMakeTaskDelegate@ BuilderAiMakeTaskHandler;
    
    AiTaskAddedDelegate@ BuilderAiTaskAddedHandler;
    AiTaskRemovedDelegate@ BuilderAiTaskRemovedHandler;

    AiUnitAddedDelegate@ BuilderAiUnitAdded; 
    AiUnitRemovedDelegate@ BuilderAiUnitRemoved;

    AiMakeTaskDelegate@ FactoryAiMakeTaskHandler;

    AiTaskAddedDelegate@ FactoryAiTaskAddedHandler;
    AiTaskRemovedDelegate@ FactoryAiTaskRemovedHandler;

    AiUnitAddedDelegate@ FactoryAiUnitAdded; 
    AiUnitRemovedDelegate@ FactoryAiUnitRemoved;

    AiMakeTaskDelegate@ MilitaryAiMakeTaskHandler;

    AiUnitAddedDelegate@ MilitaryAiUnitAdded; 
    AiUnitRemovedDelegate@ MilitaryAiUnitRemoved;

    AiIsAirValidDelegate@ AiIsAirValidHandler;
    AiMakeDefence@ AiMakeDefenceHandler;

    SelectFactoryDelegate@ SelectFactoryHandler;
    RoleMatchDelegate@ RoleMatchHandler; // optional role-specific match predicate

    RoleConfig(AiRole _role, MainUpdateDelegate@ handler = null) {
        role = _role; @MainUpdateHandler = handler;
    }
    RoleConfig() { role = AiRole::FRONT; }
}

namespace RoleConfigs {
    array<RoleConfig@> registry;

    void Register(RoleConfig@ cfg) {
        if (cfg is null) return; registry.insertLast(cfg);
    }

    RoleConfig@ Get(AiRole role) {
        for (uint i=0; i<registry.length(); ++i) { if (registry[i].role == role) return registry[i]; }
        return null;
    }

    // Defaults for switching behavior (applied when role doesn't override)
    bool DefaultAiIsSwitchTime(int lastSwitchFrame) {
        return (lastSwitchFrame + DefaultMakeSwitchInterval()) <= ai.frame;
    }
    bool DefaultAiIsSwitchAllowed(const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        const bool isOK = (armyCost > 1.2f * facDef.costM * float(factoryCount))
            || (metalCurrent > facDef.costM);
        assistRequired = !isOK;
        return isOK;
    }
    int DefaultMakeSwitchInterval() {
        // 20-60 seconds window by default
        return AiRandom(20, 60)  * SECOND;
    }

    // Public API used by factory manager
    bool AiIsSwitchTime(AiRole role, int lastSwitchFrame) {
        RoleConfig@ cfg = Get(role);

        const bool isSwitchTime = (cfg !is null && cfg.AiIsSwitchTimeHandler !is null)
            ? cfg.AiIsSwitchTimeHandler(lastSwitchFrame)
            : DefaultAiIsSwitchTime(lastSwitchFrame);

        return isSwitchTime;
    }

    bool AiIsSwitchAllowed(AiRole role, const CCircuitDef@ facDef, float armyCost, int factoryCount, float metalCurrent, bool &out assistRequired) {
        RoleConfig@ cfg = Get(role);
        if (cfg !is null && cfg.AiIsSwitchAllowedHandler !is null) {
            return cfg.AiIsSwitchAllowedHandler(facDef, armyCost, factoryCount, metalCurrent, assistRequired);
        }
        return DefaultAiIsSwitchAllowed(facDef, armyCost, factoryCount, metalCurrent, assistRequired);
    }

    // Invoke role-specific startup limits if provided
    void ApplyStartLimits() {
        if (Global::profileController.RoleCfg.InitHandler !is null) {
            Global::profileController.RoleCfg.InitHandler();
        }
        GenericHelpers::LogUtil("Applied role-specific startup limits", 2);
    }

    // Select the first RoleConfig whose predicate returns true; fallback to exact role
    RoleConfig@ Match(AiRole preferredMapRole, const string &in side, const AIFloat3& in pos, const string &in defaultStartFactory) {
        for (uint i = 0; i < registry.length(); ++i) {
            RoleConfig@ cfg = registry[i];
            if (cfg.RoleMatchHandler !is null && cfg.RoleMatchHandler(preferredMapRole, side, pos, defaultStartFactory)) {
                return cfg;
            }
        }
        return null;
    }
}


