# SMRTBARb Profile

Experimental skirmish AI profile for Beyond All Reason (BAR). This profile focuses on:
- Deterministic role assignment based on actual start position.
- Data-only map definitions (no embedded logic in map files beyond static tables).
- Deferred initialization: map + role + factory resolved only when a real build position is known.
- Clear separation between strategy mapping, managers, and per-role behavior handlers.

## High-Level Flow
1. Engine calls `Factory::AiGetFactoryToBuild(pos, isStart, isReset)` when the AI attempts the first factory.
2. On the first `isStart` call:
   - `Setup::setupMap(startPos)` runs (if not already resolved) to:
     - Register map configs.
     - Select map config matching `ai.GetMapName()`.
     - Determine team side via `ai.GetSideName()` normalization.
     - Locate nearest `StartSpot` to starting position → derive `AiRole` + `landLocked`.
     - Instantiate `Profile` & corresponding `ProfileController` with role handler delegate.
     - Apply any unit limits defined in `MapConfig`.
3. Factory selection delegates to `StrategyRegistry::SelectFactory` which:
   - Uses cached role/side/landLocked (or recomputes nearest spot if needed).
   - Maps `(AiRole, side, landLocked)` → factory via `FactoryMapping::FactoryFor`.
4. Subsequent factories fall back to default manager logic unless switching logic later overrides.

## Directory Layout
`stable/script/`
- `common.as`: Shared helpers or global definitions (if present in future expansions).
- `define.as`: Core engine / integration constants & includes.
- `helpers.as`: Utility functions (distance, nearest spot, logging wrappers, start recording).
- `setup.as`: Lazy map/profile setup + overridden `Factory::AiGetFactoryToBuild`.
- `task.as`: Task abstractions used by managers.
- `unit.as`: Unit/definition access helpers.

### `hard/`
Runtime logic modules.
- `init.as`: (If used) early initialization glue.
- `main.as`: Entry points `AiMain`, `AiUpdate`; now minimal, defers setup to factory hook.
- `manager/`
  - `builder.as`: Buildpower / construction task orchestration.
  - `economy.as`: Economic thresholds, income tracking, switch conditions.
  - `factory.as`: Factory manager, opener handling, (non-start) switching helpers.
  - `military.as`: Combat unit grouping & strategic behavior.
- `misc/commander.as`: Commander-specific logic (e.g., morphing, safety, openers).
- `role_handlers/`
  - `front.as`: Main frontline behavior update loop.
  - `eco.as`: Tech/front-tech hybrid (formerly ECO) handler.
  - `air.as`: Air-focused behavior handler.

### `maps/`
Data-only map configuration.
- `default_map_config.as`: Base/fallback config or defaults (if referenced).
- `supreme_isthmus.as`: Start spots (with `AiRole::SEA`, `FRONT`, `FRONT_TECH`, `AIR` cases) + `MapConfig` container.
- `all_that_glitters.as`: Start spots with front/air/tech distributions.
- `swirly_rock.as`: (If present) Additional map example.
- `factory_mapping.as` (legacy; prefer `strategy/factory_mapping.as`).

### `strategy/`
Strategic translation layers.
- `factory_mapping.as`: Pure mapping of `(AiRole, side, landLocked)` → initial factory unit name.
- `registry.as`: Wrapper to compute nearest spot if role not cached and request mapped factory once.

### `types/`
Structured data & enums.
- `ai_role.as`: Enum `AiRole` including `FRONT`, `AIR`, `TECH`, `SEA`, `FRONT_TECH`.
- `map_types.as`: `StartSpot` (position, role, landLocked flag) + lightweight helpers.
- `map_config.as`: `MapConfig` aggregation (name match pattern, unit limits, start spots).
- `opener.as`: Opener sequences (initial build order role counts) fetched by factory manager when a factory is created.
- `profile.as`: `Profile` data container (selected map, role, side, caching flags, chosen factory).
- `profile_controller.as`: Caches selected `RoleConfig` and calls its `MainUpdateHandler`.

## Role Determination
- Role chosen by nearest `StartSpot` to actual first factory position.
- `FRONT_TECH` merges previous ECO/Tech hybrid logic.
- `SEA` spots produce a sea lab (`armsy`, `corsy`, `legsy`).
- `landLocked` (currently unused in mapping beyond hover fallback) can steer factory selection in future.

## Factory Mapping
Implemented in `strategy/factory_mapping.as`:
```
AiRole::SEA -> armsy|corsy|legsy
AiRole::AIR -> armap|corap|legap
AiRole::TECH / FRONT_TECH -> primary land (armlab/corlab/leglab) or alt if landLocked
AiRole::FRONT -> vehicle (armvp/corvp) or hover (hp) if landLocked
```
Fallback: If mapping empty, side default lab (e.g., `armlab`).

## Deferred Initialization Rationale
- The engine does not expose a guaranteed start position early enough in `AiMain`.
- First valid placement call (`AiGetFactoryToBuild` with `isStart=true`) provides a reliable position.
- Deferring avoids speculative or incorrect role assignments.

## Extending the Profile
1. Add a new map:
   - Create `maps/<map_name>.as` returning a `StartSpot@[]` and `MapConfig`.
   - Register inside `Setup::registerMaps`.
2. Add a new role handler:
   - Extend `AiRole` enum if necessary (avoid churn unless genuinely distinct behavior).
   - Add handler script under `role_handlers/` and register in `createProfileController` switch.
3. Adjust factory mapping:
   - Update `strategy/factory_mapping.as` keeping side + role matrix explicit.
4. Tune openers:
   - Modify `types/opener.as` sequences referenced by `Factory::AiUnitAdded`.

## Debugging Tips
- Enable higher verbosity log level to see: side detection, selected role, chosen factory.
- Look for `[MapRegistry] selecting_start_factory` lines to confirm mapping.
- If no SEA factory at a sea spot: verify the map file uses `AiRole::SEA` and that side normalization is correct.

## Known TODO / Future Enhancements
- Add amphib/hover nuanced role if `landLocked` proves insufficient.
- Centralize logging level constants.
- Add a validation script comparing `StartSpot` unit counts vs. expected map player slots.
- Hook in performance telemetry for opener efficiency.

## Constraints / Guidelines Recap
- Map files: static data only (no factory selection logic inside).
- No random initial role assignment; fully deterministic by distance.
- Avoid broad refactors of core engine glue unless required for determinism.

---
Feel free to extend or request additional sections (e.g., opener format details, task pipeline diagram).
