# Standard References

## **AIFloat3**
Represents a 3D vector used for positions and directions in the game.

### **Properties**
- `float x`: The x-coordinate.
- `float y`: The y-coordinate.
- `float z`: The z-coordinate.

### **Methods**
- **Constructor**: `void f()`
  - Initializes the vector to `(0, 0, 0)`.
- **Copy Constructor**: `void f(const AIFloat3& in)`
  - Copies values from another `AIFloat3`.
- **Parameterized Constructor**: `void f(float, float, float)`
  - Initializes with specific values for `x`, `y`, and `z`.

### **Example Usage**
```angelscript
AIFloat3 position(100.0f, 0.0f, 200.0f);
AiLog("Position: " + position.x + ", " + position.y + ", " + position.z);
```

---

## **CCircuitAI**
The main AI object used to interact with game mechanics.

### **Properties**
- `const int frame`: Current simulation frame.
- `const int skirmishAIId`: ID of the AI instance.
- `const int teamId`: The AI's team ID.
- `const int allyTeamId`: The allied team ID.

### **Methods**
- `CCircuitDef@ GetCircuitDef(const string& in name)`
  - Retrieves a unit definition by name.
- `int GetDefCount() const`
  - Returns the number of unit definitions.
- `string GetMapName() const`
  - Retrieves the current map name.
- `CCircuitUnit@ GetTeamUnit(Id id)`
  - Retrieves a unit by its ID.
- `bool IsLoadSave() const`
  - Returns whether the AI is in a load/save state.
- `Type GetBindedRole(Type type) const`
  - Gets the role bound to a specific type.
- `int GetLeadTeamId() const`
  - Gets the leader team ID.

### **Example Usage**
```angelscript
string mapName = ai.GetMapName();
AiLog("Current Map: " + mapName);
CCircuitDef@ def = ai.GetCircuitDef("armcom");
if (def !is null) {
    AiLog("Unit: " + def.GetName());
}
```

---

## **CCircuitDef**
Represents a unit definition in the game.

### **Properties**
- `const Id id`: Unique identifier.
- `const float health`: Health of the unit.
- `const float speed`: Speed of the unit.
- `const float costM`: Metal cost.
- `const float costE`: Energy cost.

### **Methods**
- `void AddAttribute(Type attr)`
  - Adds an attribute to the unit.
- `void DelAttribute(Type attr)`
  - Removes an attribute.
- `bool IsAbleToFly() const`
  - Checks if the unit can fly.
- `const string GetName() const`
  - Retrieves the unit's name.

### **Example Usage**
```angelscript
CCircuitDef@ def = ai.GetCircuitDef("armcom");
if (def !is null) {
    AiLog("Unit Name: " + def.GetName());
    AiLog("Cost (Metal): " + def.costM + ", Cost (Energy): " + def.costE);
}
```

---

## **IUnitTask**
Represents a task assigned to a unit.

### **Methods**
- `Type GetType() const`
  - Retrieves the task type.
- `Type GetBuildType() const`
  - Retrieves the type of build task.
- `const AIFloat3& GetBuildPos() const`
  - Gets the position of the build task.
- `CCircuitDef@ GetBuildDef() const`
  - Retrieves the definition of the unit being built.

### **Example Usage**
```angelscript
IUnitTask@ task = ...;  // Assume task is retrieved from context
AiLog("Task Type: " + task.GetType());
AIFloat3 pos = task.GetBuildPos();
AiLog("Build Position: " + pos.x + ", " + pos.y + ", " + pos.z);
```

---

## **CMaskHandler**
Handles type masks for roles, attributes, and sides.

### **Methods**
- `TypeMask GetTypeMask(const string& in name)`
  - Retrieves a type mask for a specific name.

### **Example Usage**
```angelscript
TypeMask builderMask = aiRoleMasker.GetTypeMask("builder");
AiLog("Builder Mask Type: " + builderMask.type);
```

---

## **Global Functions**

### **Logging**
- `void AiLog(const string& in)`
  - Logs a message.
- **Example:**
  ```angelscript
  AiLog("This is a log message.");
  ```

### **Randomness**
- `int AiRandom(int min, int max)`
  - Returns a random integer between `min` and `max`.
- **Example:**
  ```angelscript
  int randomValue = AiRandom(1, 10);
  AiLog("Random Value: " + randomValue);
  ```

### **Dice**
- `int AiDice(const array<float>@+ weights)`
  - Returns the index of a weighted random choice.
- **Example:**
  ```angelscript
  array<float> weights = {0.5f, 0.3f, 0.2f};
  int choice = AiDice(weights);
  AiLog("Weighted Choice: " + choice);
  ```

### **Pause**
- `void AiPause(bool enable, const string& in)`
  - Pauses or unpauses the game.
- **Example:**
  ```angelscript
  AiPause(true, "Pausing for strategy adjustment");
  ```

---

## **SArmorInfo**
Stores armor type information.

### **Methods**
- `void AddAir(int type)`
  - Adds an air armor type.
- `void AddSurface(int type)`
  - Adds a surface armor type.
- `void AddWater(int type)`
  - Adds a water armor type.

### **Example Usage**
```angelscript
SArmorInfo armor;
armor.AddAir(1);
armor.AddSurface(2);
armor.AddWater(3);
AiLog("Armor configured successfully.");
```

---

## **SCategoryInfo**
Stores category mappings for units.

### **Properties**
- `string air`: Categories for air units.
- `string land`: Categories for land units.
- `string water`: Categories for water units.

### **Example Usage**
```angelscript
SCategoryInfo categoryInfo;
categoryInfo.air = "VTOL NOTSUB";
categoryInfo.land = "SURFACE NOTSUB";
AiLog("Air Category: " + categoryInfo.air);
```

# Builder Script References

This document describes the AngelScript classes, methods, and properties exposed by the `BuilderScript.cpp` file. It also provides usage examples for each reference.

---

## SResource

### Description
A simple resource container that holds `metal` and `energy` values.

### Properties
- `float metal` - The amount of metal.
- `float energy` - The amount of energy.

### Constructors
```angelscript
// Constructor to initialize metal and energy values.
SResource(float metal, float energy);
```

### Example Usage
```angelscript
SResource resource(100.0f, 50.0f);
aiLog("Metal: " + resource.metal + ", Energy: " + resource.energy);
```

---

## SBuildTask

### Description
Represents a build task with various parameters such as type, priority, build definition, and position.

### Properties
- `uint8 type` - The build type (from `Task::BuildType`).
- `uint8 priority` - The priority of the task (from `Task::Priority`).
- `CCircuitDef@ buildDef` - The build definition associated with the task.
- `AIFloat3 position` - The position where the task should be executed.
- `SResource cost` - The cost of the task in metal and energy.
- `CCircuitDef@ reprDef` - The representative definition.
- `CCircuitUnit@ target` - The target unit for the task.
- `int pointId` - The ID of the associated point.
- `int spotId` - The ID of the associated spot.
- `float shake` - The shake radius for the task.
- `float radius` - The radius associated with the task.
- `bool isPlop` - Whether the task is a plop task.
- `bool isMetal` - Whether the task is related to metal.
- `bool isActive` - Whether the task is active.
- `int timeout` - The timeout value for the task.

### Example Usage
```angelscript
SBuildTask task;
task.type = Task::BuildType::MEX;
task.priority = Task::Priority::HIGH;
task.position = AIFloat3(100.0f, 0.0f, 200.0f);
task.cost = SResource(50.0f, 20.0f);
aiLog("Task initialized with type: " + task.type);
```

---

## SServBTask

### Description
A specialized build task used for service-related tasks.

### Properties
- `uint8 type` - The task type (from `Task::BuildType`).
- `uint8 priority` - The priority of the task (from `Task::Priority`).
- `AIFloat3 position` - The position where the task should be executed.
- `CCircuitUnit@ target` - The target unit for the task.
- `float powerMod` - The power modifier for the task.
- `bool isInterrupt` - Whether the task can be interrupted.
- `int timeout` - The timeout value for the task.

### Example Usage
```angelscript
SServBTask task;
task.type = Task::BuildType::REPAIR;
task.priority = Task::Priority::NORMAL;
task.position = AIFloat3(150.0f, 0.0f, 250.0f);
task.isInterrupt = true;
aiLog("Service task initialized.");
```

---

## CBuilderManager

### Description
Manages builder tasks and workers in the AI system.

### Methods
- `IUnitTask@+ DefaultMakeTask(CCircuitUnit@ unit)` - Creates a default task for the specified unit.
- `IUnitTask@+ Enqueue(const SBuildTask& in task)` - Enqueues a build task.
- `IUnitTask@+ Enqueue(const SServBTask& in task)` - Enqueues a service build task.
- `IUnitTask@+ EnqueueRetreat()` - Enqueues a retreat task.
- `uint GetWorkerCount() const` - Returns the count of workers managed.

### Global Property
- `CBuilderManager aiBuilderMgr` - The global instance of the builder manager.

### Example Usage
```angelscript
// Create a default task for a unit.
CCircuitUnit@ unit = ai.GetTeamUnit(1);
IUnitTask@ task = aiBuilderMgr.DefaultMakeTask(unit);

// Enqueue a build task.
SBuildTask buildTask;
buildTask.type = Task::BuildType::FACTORY;
buildTask.priority = Task::Priority::HIGH;
buildTask.position = AIFloat3(200.0f, 0.0f, 300.0f);
aiBuilderMgr.Enqueue(buildTask);

// Get the count of workers.
uint workerCount = aiBuilderMgr.GetWorkerCount();
aiLog("Number of workers: " + workerCount);
```

---

## Additional Notes
- `SBuildTask` and `SServBTask` provide detailed control over build and service tasks in the AI system.
- `CBuilderManager` acts as the primary interface for managing builder-related tasks.

# Economy Script References

## Overview
This document outlines the Angelscript API exposed by the `EconomyScript` module in CircuitAI. The `EconomyScript` is responsible for managing and interacting with the economy-related functionalities within the AI system.

---

## Global Objects

### CEconomyManager

The `CEconomyManager` manages the AI's economy state and operations.

#### Properties
- **`const SResourceInfo metal`**
  - Details the current state of metal resources.
- **`const SResourceInfo energy`**
  - Details the current state of energy resources.
- **`bool isMetalEmpty`**
  - Indicates if metal reserves are nearly depleted.
- **`bool isMetalFull`**
  - Indicates if metal reserves are nearly full.
- **`bool isEnergyStalling`**
  - Indicates if energy production is insufficient for demand.
- **`bool isEnergyEmpty`**
  - Indicates if energy reserves are nearly depleted.
- **`bool isEnergyFull`**
  - Indicates if energy reserves are nearly full.
- **`float reclConvertEff`**
  - Efficiency of reclaim-to-metal conversion.
- **`float reclEnergyEff`**
  - Efficiency of reclaim-to-energy conversion.

#### Methods
- **`float GetMetalMake(const CCircuitDef@)`**
  - Returns the metal production rate of the specified unit definition.

- **`float GetEnergyMake(const CCircuitDef@)`**
  - Returns the energy production rate of the specified unit definition.

#### Example Usage
```angelscript
// Access economy manager
aisMetalDepleted = aiEconomyMgr.isMetalEmpty;

// Get metal production of a specific unit
auto metalProduction = aiEconomyMgr.GetMetalMake(myUnitDef);
```

---

## Object Types

### SResourceInfo

Represents the state of a specific resource (metal or energy).

#### Properties
- **`const float current`**
  - Current available amount of the resource.
- **`const float storage`**
  - Maximum storage capacity of the resource.
- **`const float pull`**
  - Current consumption rate of the resource.
- **`const float income`**
  - Current production rate of the resource.

#### Example Usage
```angelscript
// Access metal resource info
const SResourceInfo@ metal = aiEconomyMgr.metal;
float availableMetal = metal.current;
float metalStorageCapacity = metal.storage;
```

---

## Functions

### `void AiUpdateEconomy()`
Updates the internal economy state, such as resource availability, storage, and production/consumption rates.

#### Example Usage
```angelscript
// Update the economy state
Economy::AiUpdateEconomy();

// Check if energy is stalling
if (aiEconomyMgr.isEnergyStalling) {
    AiLog("Energy production is insufficient!");
}
```

---

## Initialization

### `bool Init()`
Initializes the EconomyScript module and binds the `AiUpdateEconomy` function.

#### Example Usage
```angelscript
// Initialize the EconomyScript module
if (!Economy::Init()) {
    AiLog("Failed to initialize EconomyScript module");
}
```

---

## Summary
The `EconomyScript` provides tools to monitor and manage the AI's economy effectively. Using the exposed properties and methods, developers can:

- Track the state of metal and energy resources.
- Determine resource production and consumption rates.
- Update the economy state dynamically.


# Factory Script References

## Overview
This document describes the Angelscript API provided by the `FactoryScript` module, enabling interaction with the factory management system in CircuitAI.

---

## Classes and Structs

### SRecruitTask
A structure representing a factory recruitment task.

#### Properties:
- **`uint8 type`**: Specifies the recruitment type (e.g., Task::RecruitType).
- **`uint8 priority`**: Priority level of the recruitment task.
- **`CCircuitDef@ buildDef`**: Definition of the unit to be built.
- **`AIFloat3 position`**: Position where the task is to be executed.
- **`float radius`**: Radius of influence for the task.

#### Example Usage:
```angelscript
SRecruitTask recruitTask;
recruitTask.type = Task::BUILDPOWER;
recruitTask.priority = Task::HIGH;
recruitTask.buildDef = ai.GetCircuitDef("armmex");
recruitTask.position = AIFloat3(100.0f, 0.0f, 200.0f);
recruitTask.radius = 50.0f;
aiFactoryMgr.Enqueue(recruitTask);
```

### SServSTask
A structure representing a service task for a factory.

#### Properties:
- **`uint8 type`**: Type of the service task (e.g., Task::RecruitType).
- **`uint8 priority`**: Priority level of the service task.
- **`AIFloat3 position`**: Position where the task is to be executed.
- **`CCircuitUnit@ target`**: The target unit for the task.
- **`float radius`**: Radius of influence for the task.
- **`bool stop`**: Whether the task stops an action.
- **`int timeout`**: Timeout duration for the task.

#### Example Usage:
```angelscript
SServSTask serviceTask;
serviceTask.type = Task::ASSIST;
serviceTask.priority = Task::NORMAL;
serviceTask.position = AIFloat3(150.0f, 0.0f, 250.0f);
serviceTask.radius = 30.0f;
serviceTask.stop = false;
serviceTask.timeout = 300;
aiFactoryMgr.Enqueue(serviceTask);
```

---

## Global Objects

### CFactoryManager
Provides access to factory-related functionality.

#### Global Instance:
- **`CFactoryManager aiFactoryMgr`**: The global instance of the factory manager.

#### Methods:

- **`IUnitTask@+ DefaultMakeTask(CCircuitUnit@)`**
  Creates a default task for the given unit.
  
  **Example:**
  ```angelscript
  CCircuitUnit@ factoryUnit = ai.GetTeamUnit(123);
  IUnitTask@ task = aiFactoryMgr.DefaultMakeTask(factoryUnit);
  ```

- **`IUnitTask@+ Enqueue(const SRecruitTask& in)`**
  Adds a recruitment task to the factory queue.
  
  **Example:**
  ```angelscript
  aiFactoryMgr.Enqueue(recruitTask);
  ```

- **`IUnitTask@+ Enqueue(const SServSTask& in)`**
  Adds a service task to the factory queue.
  
  **Example:**
  ```angelscript
  aiFactoryMgr.Enqueue(serviceTask);
  ```

- **`CCircuitDef@ GetRoleDef(const CCircuitDef@, Type)`**
  Retrieves the unit definition for a given role.
  
  **Example:**
  ```angelscript
  CCircuitDef@ roleDef = aiFactoryMgr.GetRoleDef(factoryUnit.circuitDef, Unit::Role::BUILDER);
  ```

- **`int GetFactoryCount()`**
  Returns the number of factories currently managed.
  
  **Example:**
  ```angelscript
  int factoryCount = aiFactoryMgr.GetFactoryCount();
  ```

#### Properties:
- **`bool isAssistRequired`**: Indicates whether assistance is required for factories.

  **Example:**
  ```angelscript
  if (aiFactoryMgr.isAssistRequired) {
      // Provide assistance
  }
  ```

---

## Global Functions

### `bool AiIsSwitchTime(int lastSwitchFrame)`
Determines whether it is time to switch factories.

#### Parameters:
- **`int lastSwitchFrame`**: The last frame a factory switch occurred.

#### Returns:
- **`bool`**: `true` if a factory switch is needed, `false` otherwise.

#### Example Usage:
```angelscript
if (Factory::AiIsSwitchTime(ai.frame - 1000)) {
    LogUtil("Switching factories", 1);
}
```

### `bool AiIsSwitchAllowed(CCircuitDef@ facDef)`
Checks whether switching the given factory is allowed.

#### Parameters:
- **`CCircuitDef@ facDef`**: The factory definition to check.

#### Returns:
- **`bool`**: `true` if switching is allowed, `false` otherwise.

#### Example Usage:
```angelscript
CCircuitDef@ factoryDef = ai.GetCircuitDef("armvp");
if (Factory::AiIsSwitchAllowed(factoryDef)) {
    LogUtil("Factory switch allowed", 1);
}
```

---

## Initialization and Update

### Initialization
The `FactoryScript` module must be initialized during the script setup phase.

#### Example:
```angelscript
bool initialized = Factory::Init();
if (!initialized) {
    LogUtil("FactoryScript initialization failed", 3);
}
```

### Update
Call `Update` to manage factory tasks and state transitions.

#### Example:
```angelscript
void AiUpdate() {
    if (Factory::AiIsSwitchTime(ai.frame)) {
        LogUtil("Switching factory tasks", 2);
    }
}

# Military Script References

## Overview
This document provides a detailed reference for the Angelscript API exposed by the `MilitaryScript` in CircuitAI. The script integrates with the `CMilitaryManager` to handle military-related AI tasks.

---

## Registered Types and Properties

### CMilitaryManager
The `CMilitaryManager` is registered as a reference type and exposes methods to handle military unit tasks.

#### Global Properties
- **`CMilitaryManager aiMilitaryMgr`**
  - The global instance of the `CMilitaryManager` accessible within the script.

#### Methods
1. **`IUnitTask@+ DefaultMakeTask(CCircuitUnit@)`**
   - Creates a default task for a given unit.
   - **Parameters:**
     - `CCircuitUnit@`: The unit for which the task is created.
   - **Returns:**
     - `IUnitTask@+`: A reference to the created task.

#### Example Usage
```angelscript
void ExampleDefaultMakeTask() {
    CCircuitUnit@ unit = ai.GetTeamUnit(1);  // Fetch a unit by ID
    IUnitTask@ task = aiMilitaryMgr.DefaultMakeTask(unit);
    if (task !is null) {
        AiLog("Task created successfully for unit ID: " + unit.id);
    } else {
        AiLog("Failed to create task for unit ID: " + unit.id);
    }
}
```

---

## Namespace: Military

The `Military` namespace contains additional functions for military-related tasks.

### Methods

1. **`IUnitTask@ MakeTask(CCircuitUnit@)`**
   - Creates a task for a specified unit.
   - **Parameters:**
     - `CCircuitUnit@`: The unit for which the task is created.
   - **Returns:**
     - `IUnitTask@`: A reference to the created task.

   **Example Usage**
   ```angelscript
   void ExampleMakeTask() {
       CCircuitUnit@ unit = ai.GetTeamUnit(1);  // Fetch a unit by ID
       IUnitTask@ task = Military::MakeTask(unit);
       if (task !is null) {
           AiLog("Custom task created successfully for unit ID: " + unit.id);
       } else {
           AiLog("Failed to create custom task for unit ID: " + unit.id);
       }
   }
   ```

2. **`bool IsAirValid()`**
   - Checks if the air strategy is currently valid based on the AI state.
   - **Returns:**
     - `bool`: `true` if air strategies are valid, `false` otherwise.

   **Example Usage**
   ```angelscript
   void ExampleIsAirValid() {
       if (Military::IsAirValid()) {
           AiLog("Air strategy is valid.");
       } else {
           AiLog("Air strategy is not valid.");
       }
   }
   ```

---

## Script Initialization

### Initialization Behavior
- **Namespace:** `Military`
- **Registered Functions:**
  - `IUnitTask@ MakeTask(CCircuitUnit@)`
  - `bool IsAirValid()`

### Example Initialization
```angelscript
void InitializeMilitaryScript() {
    AiLog("Initializing Military Script...");
    // Custom logic for script initialization can be added here.
}
```

---

## Example Script
Below is a complete example demonstrating the usage of the `MilitaryScript` API:

```angelscript
void Main() {
    CCircuitUnit@ unit = ai.GetTeamUnit(1);  // Fetch a unit by ID

    // Create a default task for the unit
    IUnitTask@ defaultTask = aiMilitaryMgr.DefaultMakeTask(unit);
    if (defaultTask !is null) {
        AiLog("Default task created successfully.");
    }

    // Create a custom task for the unit
    IUnitTask@ customTask = Military::MakeTask(unit);
    if (customTask !is null) {
        AiLog("Custom task created successfully.");
    }

    // Check if air strategies are valid
    if (Military::IsAirValid()) {
        AiLog("Air strategy is valid.");
    } else {
        AiLog("Air strategy is not valid.");
    }
}
```

---

## Notes
- The `MilitaryScript` integrates tightly with `CMilitaryManager` to provide flexible military task management.
- Ensure that the methods `MakeTask` and `IsAirValid` are implemented in the main script for the `Military` namespace.

---

# EconomyScript Angelscript Documentation

This documentation provides details on the Angelscript interface exposed by the `EconomyScript.cpp` implementation in CircuitAI.

## Global Functions

### `void OpenStrategy(const CCircuitDef@, const AIFloat3& in)`
Executes the `OpenStrategy` function in the AngelScript module.

#### Parameters
- `CCircuitDef@ facDef`: The factory definition for the strategy.
- `AIFloat3 pos`: The position on the map to consider for the strategy.

#### Usage
```angelscript
const CCircuitDef@ myFactory = ai.GetCircuitDef("armvp");
AIFloat3 strategyPosition(100.0f, 0.0f, 200.0f);
Economy::OpenStrategy(myFactory, strategyPosition);
```

---

## Script Initialization

The `CEconomyScript` class is responsible for registering and initializing script functionalities. It exposes a single method:

### `void Init()`
Registers the `OpenStrategy` function from the Angelscript module `main`.

#### Usage in C++
```cpp
void CEconomyScript::Init()
{
    asIScriptModule* mod = script->GetEngine()->GetModule("main");
    info.openStrategy = script->GetFunc(mod, "void OpenStrategy(const CCircuitDef@, const AIFloat3& in)");
}
```

---

## Methods in CEconomyScript

### `void OpenStrategy(const CCircuitDef* facDef, const AIFloat3& pos)`
Executes the `OpenStrategy` function in the AngelScript module if it is registered.

#### Parameters
- `facDef`: A pointer to the factory definition to consider.
- `pos`: A reference to the position for the strategy.

#### Usage in C++
```cpp
void CEconomyScript::OpenStrategy(const CCircuitDef* facDef, const AIFloat3& pos)
{
    if (info.openStrategy == nullptr) {
        return;
    }
    asIScriptContext* ctx = script->PrepareContext(info.openStrategy);
    ctx->SetArgObject(0, const_cast<CCircuitDef*>(facDef));
    ctx->SetArgAddress(1, &const_cast<AIFloat3&>(pos));
    script->Exec(ctx);
    script->ReturnContext(ctx);
}


