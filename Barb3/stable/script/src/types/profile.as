// #include "../helpers/factory_helpers.as"
// #include "map_config.as"
// #include "ai_role.as"

// //#include "../strategy/registry.as"

// #include "../unit.as"

// class Profile {
//     //These should be private, but Angelscript does not support static classes and cannot be private in namespace
//     //Lets pretend they are :P
//     MapConfig _mapConfig;
//     // AiRole _aiRole;
//     // string _side; // faction side (armada/cortex/legion)

//     // Map/selection cache fields migrated from registry globals
//     bool _mapResolved;
//     string _mapName;
//     bool _startLogged;
//     bool _factorySelected;
//     string _chosenFactory;
//     bool _landLocked;

//     Profile(MapConfig mapConfig, AiRole aiRole, const string &in side) {
//         _mapConfig = mapConfig;
//         _aiRole = aiRole;
//         _side = side;
//         _mapResolved = false;
//         _mapName = "";
//         _startLogged = false;
//         _factorySelected = false;
//         _chosenFactory = "";
//         _landLocked = false;
//     }

//     Profile() {
//         _mapConfig = MapConfig();
//         _aiRole = AiRole::FRONT;
//         _side = "";
//         _mapResolved = false;
//         _mapName = "";
//         _startLogged = false;
//         _factorySelected = false;
//         _chosenFactory = "";
//         _landLocked = false;
//     }

//     /************************ 
//     Pretend Public Methods
//     TODO: Refactor 
//     **************************/

//     //Returns pre-selected role determined on init
//     AiRole GetAiRole() {
//         return _aiRole;
//     }

//     //Returns pre-selected map config determined on init
//     MapConfig GetMapConfig() {
//         return _mapConfig;
//     }

//     // Returns resolved side
//     string GetSide() {
//         return _side;
//     }

//     // Cache field accessors (minimal set needed externally)
//     string GetMapName() { return _mapName; }
//     string GetChosenFactory() { return _chosenFactory; }
//     bool IsLandLocked() { return _landLocked; }
//     bool FactorySelected() { return _factorySelected; }
//     bool MapResolved() { return _mapResolved; }

//     // string SelectFactory(const AIFloat3& in pos) {
//     //     return FactoryHelpers::SelectFactory(pos);
// 	// }
// }  