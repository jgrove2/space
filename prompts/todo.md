# TASKS

Engineering plan to make this LÖVE2D grid engine extensible, support full
arbitrary ship rotation (with collision), and fix the "going into the ship
doesn't work" bugs.

Goals:
- Stand up a small **ECS core early** (Entity = id + Components; behavior lives in
  Systems) so ships, asteroids, stations, the player, and later **AI ships, crew,
  and creatures** are all the same kind of thing — composed, not subclassed.
- Generalize shared logic so other objects render through one path (a `GridBody`
  component), not bespoke per-type code.
- Support **full arbitrary rotation**, with collision, interaction proximity, and
  thruster flames all respecting an entity's angle.
- Fix the boarding / disembarking / wall-collision bugs.

> **Sequencing principle:** the architecture is load-bearing, so the ECS core is
> established **early (Phase 0.5)**, before rotation, collision, the object model,
> and the editor are built on top of it. Doing the clean architecture late would
> force a rewrite of everything stacked above it. The few throwaway bug-fixes that
> get the ship walkable again fast are explicitly marked as stopgaps that the
> proper Systems later supersede.

---

## Confirmed bugs (with file:line)

1. **No tile collision; only a bounding-box clamp** — `lib/world.lua:145`
   `_clampPlayerToShipIfInside`. Walls (`#`, `=`, `!`, corners) don't block the
   player. Main "going into the ship doesn't work" symptom.
2. **Clamp uses exterior dims while in interior mode** — `lib/world.lua:152-153`
   uses `ship.pixel_w/pixel_h`, but interior has its own `int_pixel_w/int_pixel_h`
   (`lib/ship.lua:158`). Clamp box is the wrong size when boarded.
3. **Disembark always pushes south** — `lib/world.lua:112`
   `wy = wy + ship.font_size`, regardless of which hull side the airlock is on.
   Side/top airlocks drop the player back inside the hull, re-triggering
   proximity so you can't leave.
4. **Airlock teleport can land outside interior hull** — `lib/world.lua:95-100`
   `_findMatchingAirlock` picks the nearest interior airlock by world distance
   via `gridToWorld`, but exterior and interior grids can have different col/row
   counts while sharing the same `self.x/self.y` origin. Destination can fall
   outside the interior, then get clamped to an edge.
5. **`getTileAt` index convention mismatch** — `lib/ship.lua:324-329` subtracts 1
   from `row/col` to index 0-based maps, while `worldToGrid` (`lib/ship.lua:335`)
   returns 1-based `col,row`. Currently unused, but a latent trap, and collision
   will depend on it. Also `worldToGrid` returns `col,row` while `gridToWorld`
   takes `row,col` — inconsistent arg order across the file.
6. **Interaction proximity ignores layer geometry drift** — `lib/interaction.lua:52`
   converts the player to grid coords with `worldToGrid` (exterior origin) but
   checks interactables tagged per layer; fine today, breaks once interior offset
   differs or once rotation exists.
7. **Starfield reseeds the global RNG to 42** — `lib/starfield.lua:7`
   `math.randomseed(42)` at construction makes all later `math.random()`
   deterministic gameplay-wide (affects thruster flicker, future spawns).
   **FIXED in Phase 0** — now uses `love.math.newRandomGenerator(42)`.
8. **Per-frame font reload** — `lib/grid_renderer.lua:130` `loadFont` runs inside
   `renderGrid` each bake and probes the filesystem every call. Cache it.
   **FIXED in Phase 0** — added `font_cache[size]` table.
9. **`dt_last` plumbing is fragile** — `main.lua:12,39` passes `dt` into `draw`
   via a module global; thruster animation already uses `ship.thruster_time`, so
   `draw(dt)` is redundant and inconsistent.
10. **Hardcoded internal resolution** — `main.lua:7` `W,H = 1920,1080` is
     duplicated as the canvas size, camera size, and starfield size; should be one
     config source.
11. **Interior not visible after boarding (Transform coordinate mismatch)** —
     `lib/transform.lua:25-36` `worldToGridRC` returns center-relative grid coords
     instead of top-left-relative, so `InteractionSystem` (`lib/systems/interaction_system.lua:31`)
     queries proximity against the wrong tiles (off by half the grid dimensions).
     `gridRCToWorldCenter` (`lib/transform.lua:32-36`) passes top-left-relative
     positions into `localToWorld` which expects center-relative values, placing
     the player outside the interior canvas on board (`lib/systems/boarding_system.lua:112`).
     Net effect: airlocks can't be detected and interiors appear off-screen.

---

## Architecture direction (ECS-first)

See the **Architecture** section at the end of this file for diagrams. In short:

- **Entity = id + a bag of Components.** Everything in the world (player, ship,
  AI ship, crew member, creature, asteroid, station) is an entity. There are **no
  per-type subclass trees** — a player ship and an AI ship are the same entity
  differing only by a `ControlledBy(player)` vs an `AIBrain` component.
- **Components are plain data** (Transform, GridBody, Velocity, Collider,
  Pilotable, Interactable, AIBrain, Faction, Pathing, ContainedIn, CrewMember, …).
- **Systems hold the logic** and run in a fixed order each tick: Input ▸ AI ▸
  Pathfinding ▸ Movement ▸ Collision ▸ Interaction ▸ Boarding ▸ Camera ▸ Render.
  New behavior is a new System or component, not a new class.
- **`GridBody` is a component**, not a base class: it holds the baked canvas(es)
  per layer + the collision grid. The renderer and collision system read it.
- **Full arbitrary rotation + collision** via a `Transform` helper: convert
  world<->local by translating to an entity's center and rotating by `-angle`.
  Every spatial query (collision, interaction proximity, board/disembark,
  camera-follow center, AI perception, pathfinding) goes through it. Rendering
  uses `love.graphics.draw(canvas, cx, cy, angle, 1, 1, halfW, halfH)`.
- **Cross-cutting services:** an `EventBus` (decouples systems), a `SpatialIndex`
  (collision + perception + interaction + render culling), plus Config/Time/RNG.

---

## Phase 0 — Foundation (do first; everything else builds on it) ✓ DONE

- [x] **Config module** (`lib/config.lua`): single source for internal `W/H`,
      default `font_size`, interaction range, camera lerp, debug flags. Remove
      duplicated constants from `main.lua`, `lib/world.lua`, `lib/starfield.lua`.
- [x] **Transform helper** (`lib/transform.lua`): `worldToLocal(entity, wx, wy)`,
      `localToWorld(entity, lx, ly)`, `worldToGridRC(entity, wx, wy)`,
      `gridRCToWorldCenter(entity, row, col)` — all angle-aware, rotating about
      the entity's pixel center. **Standardize on `(row, col)` order everywhere**
      and document 1-based vs 0-based once. Replaces
      `Ship:worldToGrid/gridToWorld/isInsideBounds`.
- [x] **Cache `GridRenderer.loadFont`** by size (`lib/grid_renderer.lua:32`) so
      bakes don't re-probe the filesystem.
- [x] **Stop hijacking the global RNG**: give `Starfield` its own
      `love.math.newRandomGenerator(seed)` (`lib/starfield.lua:7`) so gameplay
      randomness stays independent.

## Phase 0.5 — ECS core (do EARLY; everything below is built on it) ✓ DONE

> **Why early:** rotation, collision, the object model, AI, crew, and creatures
> all attach to this. Building them first and retrofitting ECS at the end would
> mean rewriting them. Keep it small — this is a lightweight ECS, not a framework.

- [x] **Entity registry** (evolve `lib/entity_manager.lua`): an entity is an `id`
      plus a component table. Add `addComponent(id, name, data)`,
      `getComponent(id, name)`, `removeComponent`, and `query(...component names)`
      returning entities that have all of them. Clean break — old `add/get/remove`
      methods removed; all callers updated to use the new API.
- [x] **Component definitions** (`lib/components.lua`):
      start with the data-only shapes needed now — `Transform {x,y,angle,scale}`,
      `GridBody {layers, active_layer, bounds}`, `Velocity {vx,vy,vθ}`,
      `Collider {kind, solid}`, `Interactable {kind, prompt, row, col, layer}`,
      `ControlledBy {by="player"|"ai"}`, `Pilotable`, `ContainedIn`.
      Add `AIBrain`, `Perception`, `Faction`, `Pathing`, `CrewMember` as
      **stubs now, filled in Phase 10**.
- [x] **System runner**: `World` holds an ordered list of systems and calls
      `system.update(dt, world)` each tick; a separate render pass calls
      `RenderSystem.draw(world)`. Define the canonical order (Input ▸ Movement ▸
      Collision ▸ Interaction ▸ Boarding ▸ Camera). Logic that
      lived in `lib/world.lua:update/draw` moved into systems
      incrementally. Systems live in `lib/systems/`, one file per system.
- [x] **EventBus** (`lib/event_bus.lua`): `subscribe(name, fn)` / `emit(name,
      payload)`. Created; ready for use by later phases.
- [x] **Make the Player an entity**: give the player
      `Transform + Velocity + Collider + ControlledBy(player)`. `InputSystem`
      writes movement intent into `Velocity`, `MovementSystem` applies it.
      Removes the bespoke `self.player` handling and deletes `lib/player.lua`.
- [x] **SpatialIndex stub** (`lib/spatial_index.lua`): a simple uniform grid with
      `insert/remove/queryRegion`. Created; ready for use by Phase 1.
- [x] **Migration guardrail**: game runs the single ship + walkable player
      (collision is still the bounding-box stopgap from old code, to be
      replaced in Phase 3). ECS switch is proven.

## Phase 1 — GridBody component + object model (extensibility / "render other objects")

> Built on Phase 0.5. `GridBody` is a **component** (data: baked canvases +
> collision grid per layer), not a base class. Rendering and collision are
> Systems that read it. "An object you can render" = an entity with a `GridBody`.

- [x] **`GridBody` component + baker** (`lib/components.lua` defaults +
      `lib/grid_body.lua` builder): holds `layers = { name -> {canvas, tiles,
      tile_map, grid_w, grid_h, pixel_w, pixel_h, collision} }`, `active_layer`,
      and cached `bounds`. A `buildLayer(grid_rows, palette, font_size, opts)`
      wraps `GridRenderer.renderGrid`. Pure data + a builder — no behavior.
- [x] **Move grid baking out of `Ship`** into the `GridBody` builder. Ship
      loading produces `Transform + GridBody + ShipStats + Pilotable +
      Interactables` components on an entity. `lib/ship.lua` is no longer a
      class — it is a **loader/factory** (`Ship.spawn(world, file, x, y, angle)`
      that assembles components).
- [x] **Per-object-type "tilesets"** (`lib/tilesets/ship.lua`): moved
      `CHAR_TO_GLYPH/CHAR_TO_SHAPE/CHAR_TYPE/CHAR_DEFAULTS` out of `lib/ship.lua`
      into `lib/tilesets/ship.lua`. Also includes `WALKABLE_CHARS`,
      `INTERACTABLE_CHARS`, `autoDetectThrusters()`, `scanInteractables()`, and
      `buildCollisionGrid()`. A new object type just supplies its own tileset.
- [x] **Ship-specific data as components, not a subclass**: `mode` → `GridBody.
      active_layer`; thrusters/thruster_time → `ShipStats`; shield_capacity/
      thrust_bonus → `Pilotable`. No `Ship` class, no `_ship_data` hack.
- [x] **Generic interactable registry**: replaced the hardcoded `airlocks/
      captains_seats/shield_gens/engines` quadruple with a generic `Interactables`
      component (list of `{kind, row, col, layer}` entries). Built by
      `ShipTileset.scanInteractables()` which reads `INTERACTABLE_CHARS`.
      InteractionSystem iterates `kind` generically.
- [x] **RenderSystem: component-driven** (replaces the old `_ship_data` branch):
      queries `Transform + GridBody`, reads `active_layer` from the component,
      draws thrusters from `ShipStats`. Interior overlay uses `ContainedIn.layer`.
- [x] **Spawn factory / object catalog** (`lib/spawn.lua`): one `Spawn.spawn(
      world, type, file, x, y, angle)` entry point dispatching to type loaders.
      Currently registered: `"ship" → Ship.spawn`. Extensible via
      `Spawn.registerType()`.

> **Phase 1 implementation summary (26 Jun 2026):** Complete clean-break
> rewrite of the ship system.
> - **3 new files:** `lib/tilesets/ship.lua` (tile character mappings +
>   scanner/ collision helpers), `lib/grid_body.lua` (GridBody builder),
>   `lib/spawn.lua` (object spawn factory)
> - **2 rewritten files:** `lib/ship.lua` (class → factory), `lib/transform.lua`
>   (API now takes `xf, layer, ...` instead of a single entity table)
> - **8 modified files:** `lib/components.lua` (+ ShipStats, Interactables);
>   `lib/world.lua` (uses `Ship.spawn()`, no `_ship_data`); all 6 systems
>   (read components instead of `_ship_data.ref`); `lib/ship_renderer.lua`
>   (accepts plain data, not Ship class)
> - **`_ship_data` component removed entirely.** All ship state now lives in
>   proper components: `GridBody`, `ShipStats`, `Pilotable`, `Interactables`.
>   `lib/ship.lua` is a factory module — no class, no metatable, no
>   `Ship:method()` calls anywhere.

## Phase 2 — Rotation (full arbitrary angle + collision), as Systems ✓ DONE

> Implemented as Systems reading `Transform`/`GridBody`, not methods on a class.

- [x] **RenderSystem draws rotated**: use `love.graphics.draw(canvas, cx, cy,
      Transform.angle, scale, scale, halfW, halfH)` with the origin at the entity
      center (`lib/systems/render_system.lua:34-38`). Removes the top-left
      assumptions.
- [x] **Angle-aware thruster flames**: the thruster/effects renderer
      (`lib/ship_renderer.lua:35-37`) wraps flame drawing in a
      `push/translate(center)/rotate(angle)/pop` block so flames emit in the ship's
      local orientation at any angle.
- [x] **All spatial queries go through `Transform`** (Phase 0): CollisionSystem now
      uses `Transform.worldToLocal` → local-space clamp → `Transform.localToWorld`,
      making it rotation-aware (`lib/systems/collision_system.lua:27-32`).
- [x] **PilotSystem rotates the ship**: new `lib/systems/pilot_system.lua`. Mouse
      steering smoothly rotates the ship toward the cursor world position; Q/E
      provide manual rotation override (180°/s). W/S apply thrust along facing
      into `Velocity` using `Pilotable.thrust`.
- [x] **Camera + screen-space prompt** use the rotated center: verified — the
      prompt drawer (`lib/ship_renderer.lua:91`) projects world position to screen
      and tracks correctly inside a rotated ship.

> **Phase 2 implementation summary (26 Jun 2026):** Full arbitrary rotation.
> - **1 new file:** `lib/systems/pilot_system.lua` (mouse + Q/E steering, W/S thrust)
> - **3 modified files:** `lib/systems/render_system.lua` (rotated draw call + angle
>   passed to thruster drawer); `lib/ship_renderer.lua` (flames in rotated local
>   space); `lib/systems/collision_system.lua` (local-space clamp via Transform)
> - **1 updated system list:** `lib/world.lua` (PilotSystem registered before
>   MovementSystem)

## Phase 3 — Fix "going into the ship" (collision + board/disembark) ✓ DONE

> The stopgap was superseded by the full ECS-based implementation in Phases 0.5–3.
> All old file:line references (`lib/world.lua:112,145,152`) no longer exist — the
> relevant code was rewritten into dedicated Systems.

- [x] **Collision grid built per layer** (`lib/tilesets/ship.lua:124-134`):
      `buildCollisionGrid` marks solid (`#`, walls, slants) vs walkable (`.`,
      `A`, `C`, `o`, etc.). Stored as `collision[row][col]` per layer via
      `GridBodyBuilder.buildLayer`. Consumed by CollisionSystem.
- [x] **CollisionSystem: tile-level AABB** (`lib/systems/collision_system.lua`):
      replaced the old bounding-box clamp. Converts entity world pos → local
      top-left origin → grid coords. Checks player AABB (font_size × font_size)
      against solid tiles. Axis-separated resolution (resolve X then Y) for
      wall-sliding. Generic over any entity with `ContainedIn + Transform +
      Collider`.
- [x] **BoardingSystem: teleport + walkable check**
      (`lib/systems/boarding_system.lua`): `findMatchingAirlock` now uses
      **world-distance** matching (converts source tile to world coords via each
      layer's own dimensions, then picks nearest). `findNearestWalkable` verifies
      the destination tile is walkable and spirals outward up to `max_radius` if
      not. Fallback to layer center if no airlock found.
- [x] **Fix disembark direction** (`lib/systems/boarding_system.lua:55-83`
      `getOutwardDirection`): checks 4 cardinal neighbors of the exterior airlock
      in `tile_map`. Pushes outward toward empty space (outside grid bounds or
      nil tile_map entry) instead of always south. Falls back to "down".
- [x] **Fix coordinate system consistency** (`lib/transform.lua:25-40`):
      `worldToGridRC` and `gridRCToWorldCenter` now both use **top-left origin**
      1-based coords, matching `scanInteractables` and `collision[row][col]`.
      Previously they used center-origin, causing a ~19-tile offset in the
      interaction proximity check.

> **Known remaining issue:** After boarding, `gb.active_layer` switches to
> `"interior"` and the exterior canvas is correctly hidden, but the interior
> canvas is not visible. Camera follows the player to the correct teleport
> position. Investigating — may be a pre-existing render/layer issue carried
> from Phase 1/2, or related to the interior canvas baking or draw order.

## Phase 4 — Decoupling & polish (extensibility) ✓ DONE

> Built on Phase 0.5/1/3. `dt`-to-draw plumbing was already resolved in prior
> code. The remaining items focus on making the game code extensible, removing
> special-casing, and proving the "other objects" abstraction works.

- [x] **Separate "render to canvas" from "blit/UI"** in `main.lua` into
      `drawWorldToCanvas()`, `blitCanvas()`, `drawUI()` for readability. Removed
      the empty `ShipRenderer.drawWorld` stub.
- [x] **Make the player a `GridEntity`**: the player now has a `GridBody`
      component (1×1 baked canvas, blue square) and renders through the main
      `transform + grid_body` RenderSystem path. A new `origin` field on the
      Transform component (`"top_left"` default, `"center"` for the player)
      lets entity position convention be clean — ships store top-left, the
      player stores center. `Transform._center()` is the single source of truth
      for computing an entity's world-center position.
- [x] **Data-driven object catalog + asteroid example**: `lib/spawn.lua`
      registered `"asteroid"`. New files: `lib/tilesets/asteroid.lua` (tileset:
      `%` rock, `o` ore, `*` crystal), `lib/asteroid.lua` (factory), and
      `ships/asteroid1.txt` (example asteroid with ore deposits). Spawned
      alongside the ship in `World.new()` to prove multi-entity rendering.
- [x] **Interaction generalization**: replaced hardcoded `if kind == "airlock"`
      / `"captain"` with a `PROMPTS` table keyed by `{kind} → {layer/state/prompt}`.
      Added `InteractionSystem.registerKind(kind, layer, cfg)` so new
      interactables (cargo, turret, ore, door) need one call — no state-machine
      edits.
- [x] **Document the file format**: created `docs/format.md` covering the `.txt`
      object file format (headers, sections, tile character reference, collision
      rules).

## Phase 6 — Shared tile schema (single source of truth)

> **Why:** the tile schema is currently hand-duplicated in **four** places that
> already drift: `lib/ship.lua` (`CHAR_TO_GLYPH`, `CHAR_TO_SHAPE`, `CHAR_TYPE`,
> `CHAR_DEFAULTS`), `tools/sprite_editor.html` (`CHAR_COLOR`, `CHAR_DESC`,
> `CHAR_TO_GLYPH`, `CHAR_TYPE`, `DEFAULT_COLORS`, `PALETTE_GROUPS`),
> `prompts/generate_ship.txt`, and `scripts/gen_flatiron.js`. Adding any new
> tile or object type means editing all four by hand. This phase is the
> foundation for both "render other objects" and "create the world."

- [ ] **Define one schema file** (e.g. `data/schema.json` or `data/tiles.lua`):
      for each tile char → `{ glyph, shape, type, default_color_key, layers
      (exterior/interior/shared), collision (solid/walkable), interactable_kind,
      thruster_dir }`. Include the 16-color palette (`a`–`p`) here too.
- [ ] **Engine consumes the schema**: `lib/grid_renderer.lua` /
      `lib/tilesets/*` and `lib/ship.lua` build their lookup tables from the
      schema at load instead of the inline literals
      (`lib/ship.lua:6-61`, `lib/grid_renderer.lua:11-28`).
- [ ] **Editor consumes the same schema**: `tools/sprite_editor.html` loads the
      schema (fetch the JSON, or a generated JS file) to build `DEFAULT_COLORS`,
      `CHAR_*` maps, and `PALETTE_GROUPS` instead of the hardcoded blocks
      (`sprite_editor.html:165-243`). One schema, identical behavior.
- [ ] **AI prompt generated from schema**: regenerate the palette/character
      tables in `prompts/generate_ship.txt` from the schema (a small build
      step) so the prompt can never drift from the engine.
- [ ] **Audit & fix existing drift** while extracting: confirm `S` (shield) and
      `E` (engine) glyphs/colors match between `lib/ship.lua` and
      `sprite_editor.html`, and that the prompt documents them (it currently
      omits `S`/`E`/`*` consoles in places). Decide `@` semantics: editor
      `generateHull` and `gen_flatiron.js` emit `@` borders, but the shipped
      `flatiron_ship.txt` and the prompt's "outer ring must be `#`" rule use
      `#` — pick one and make all tools agree.
- [ ] **Unknown-char policy**: `lib/grid_renderer.lua:108` silently falls back to
      drawing the raw char for unknown tiles. Decide whether to warn/validate
      against the schema instead, so authoring mistakes are caught.

## Phase 7 — Designer tool: support objects beyond ships

> **Why:** `tools/sprite_editor.html` is hardwired to "ship" — the New modal is
> "New Ship," layers are fixed to exterior/interior/preview, and ship classes
> are the only presets. To author asteroids, stations, planets, debris, and
> world tiles it needs an object-type concept driven by the Phase 6 schema.

- [ ] **Object-type selector**: generalize the "New Ship" modal
      (`sprite_editor.html:139-157,887-911`) into "New Object" with a type
      dropdown (Ship, Station, Asteroid, Planet, Prop, …). Type determines which
      layers, palette groups, and metadata sections are available.
- [ ] **Schema-driven palette per type**: replace the hardcoded `PALETTE_GROUPS`
      / `LAYER_GROUPS` (`sprite_editor.html:231-243`) with groups derived from
      the schema filtered by the selected object type. Ships get
      hull/interior/thrusters; an asteroid gets rock/ore tiles; etc.
- [ ] **Configurable layers**: today layers are fixed to exterior/interior
      (`getActiveGrid`/`getActiveColorMap`, `sprite_editor.html:466-476`). Make
      the layer set come from the object type (e.g. asteroid = single layer,
      station = exterior/interior, planet = surface).
- [ ] **Generic metadata sections**: thrusters are special-cased
      (`autoUpdateThrusters`, `sprite_editor.html:837-851`). Generalize to a
      schema-described set of point-metadata sections (thrusters for ships,
      resource nodes for asteroids, docking ports for stations, spawn points for
      world tiles) so save/load handles them generically.
- [ ] **Generalize save/load to the object format** (`serializeShip` /
      `parseShipFile`, `sprite_editor.html:1006-1037,1067-1169`): write/read a
      `type:` header and the type's sections; keep ship files
      backward-compatible (no `type:` ⇒ ship).
- [ ] **Rotation preview**: add a rotate control to the Preview tab so authors
      can see the object at arbitrary angles (matches the new Phase 2 engine
      rotation) and verify silhouette/thruster directions.
- [ ] **In-editor validation against the schema**: port the checks from
      `scripts/gen_flatiron.js:verify()` (row/col bounds, ext↔int boundary
      match, no cross-layer-only chars, airlock reachability) into the editor as
      live warnings, driven by the same schema.
- [ ] **Procedural generators as editor actions** (optional): fold
      `generateHull` (`sprite_editor.html:932-987`) and the logic in
      `scripts/gen_flatiron.js` into reusable "generate" buttons per object type
      (hull, asteroid blob, station ring), so the one-off Node script can be
      retired. Note `ships/flatiron_ship3.txt` has no generator today.

## Phase 8 — World / scene authoring (place objects into a world)

> **Why:** there is currently **no world/scene concept** anywhere — `lib/world.lua`
> hardcodes a single ship (`world.lua:16`). "Create the world" needs a scene
> format describing many positioned, rotated objects, plus engine + editor
> support to load and author it.

- [ ] **Scene file format** (e.g. `worlds/<name>.json` or `.txt`): a list of
      entity placements `{ type, source_file, x, y, angle, scale, z_order,
      overrides }` plus world-level settings (starfield seed/density, bounds,
      spawn point). Document it alongside the object format.
- [ ] **Engine loads scenes**: `lib/world.lua` reads a scene file and spawns each
      entity via the Phase 4 object catalog into the `EntityManager`, instead of
      the hardcoded single ship (`world.lua:16-31`). Player spawn comes from the
      scene.
- [ ] **Multi-entity correctness**: ensure interaction/collision/camera already
      work with N entities (they iterate `entities` but have only ever been
      exercised with one) — covered partly by Phase 1 culling/sort; add a scene
      with ≥2 ships + a non-ship object as a test.
- [ ] **Scene editor mode in the designer**: a new top-level mode in
      `sprite_editor.html` that loads object files as placeable instances on a
      large canvas, supports drag-to-move, rotate handle, z-order, and
      duplicate/delete, then exports the scene format. (This is the largest
      editor task; can be a separate tool/page if cleaner.)
- [ ] **Object library/browser**: let the scene editor list available object
      `.txt` files (ships, stations, asteroids) to drag into the world.
- [ ] **Round-trip test**: author a small scene in the editor, load it in the
      game, confirm positions/angles match; edit an object, reload, confirm the
      scene picks up changes.

## Phase 9 — Direct save/edit of sprite & world data (no download/upload dance)

> **Why:** the editor is currently browser-sandboxed — `saveFile` triggers a
> Blob download and `openFile` uses a file-picker
> (`sprite_editor.html:1039-1065`). Every edit means "download, find it in
> ~/Downloads, move it into `ships/`." You want to open a sprite or world
> straight from the project, edit it, and **save back to the same file** in
> place. Pick one of the implementation paths below (A is simplest, C is most
> seamless); they are mutually exclusive but share the same UI/task work.

### Shared (regardless of path)

- [ ] **Dirty-state + explicit Save/Save As**: track unsaved changes, show a
      modified indicator, warn on close/navigation, and remember the current
      file path/handle so "Save" overwrites it without re-prompting.
- [ ] **Distinct save targets**: "Save" writes to `ships/` (objects) or
      `worlds/` (scenes) based on the object/scene type, with sane default
      filenames (reuse the existing `name → snake_case_ship.txt` logic,
      `sprite_editor.html:1041`).
- [ ] **Validate-on-save**: run the Phase 6/7 schema validation before writing;
      block or warn on invalid data so bad files never hit disk.

### Path A — File System Access API (pure browser, zero backend)

- [ ] **Use `showOpenFilePicker` / `showSaveFilePicker`** to obtain a
      `FileSystemFileHandle`; keep it in state so subsequent saves call
      `handle.createWritable()` and overwrite the original file directly — no
      downloads. Replace the Blob path in `saveFile`/`openFile`.
- [ ] **Optional `showDirectoryPicker`** on the project root: grant the
      `ships/` + `worlds/` folders once, then list/open/save files in place and
      power the Phase 8 object browser from real directory contents.
- [ ] **Graceful fallback**: this API is Chromium-only and needs a user gesture
      + (for some setups) a secure context. Detect support and fall back to the
      current download/upload flow on unsupported browsers.

### Path B — Tiny local dev server (works in any browser)

- [ ] **Minimal file API** (e.g. a small Node/Express or Python script under
      `tools/`): `GET /files?dir=ships`, `GET /file?path=…`,
      `PUT /file?path=…` (write), scoped/sandboxed to the project's `ships/` and
      `worlds/` dirs only (reject path traversal). Document how to run it.
- [ ] **Editor talks to the server**: replace Blob download / file-picker with
      `fetch` calls to the API for list/open/save; add a small "Open from
      project" / "Save to project" UI. Serve `sprite_editor.html` from the same
      server to avoid CORS.

### Path C — Move the editor into the game (LÖVE-native, single tool)

- [ ] **In-engine editor mode** using `love.filesystem.write` (writes to the
      LÖVE save directory) or a configured project path: edit the grid/scene in
      the running game and hot-reload the entity/scene without leaving the app.
      Heaviest lift, but unifies authoring + play and removes the HTML tool.

### World data specifically

- [ ] **Edit & save scenes in place too**: whichever path is chosen, the Phase 8
      scene format must load from `worlds/` and save back to the same file, so
      world layout edits persist directly (not just sprites).
- [ ] **Live reload in-game (optional)**: watch the open `ships/`/`worlds/`
      file(s) and re-bake/re-spawn on change so edits show up in the running
      game without a manual restart.

## Phase 5 — Verification

- [ ] **Manual test matrix**: board from each airlock; walk into every wall
      (blocked); slide along walls; disembark from each airlock (lands outside);
      pilot + rotate 360 degrees; board/disembark while rotated; thruster flames
      point correctly at several angles.
- [ ] **Debug overlay** (toggle in config): draw the collision grid + entity AABB
      + local axes, to make rotation/collision bugs visible.
- [ ] **Schema parity check**: a tiny script/test that loads the Phase 6 schema
      and asserts the engine and editor produce the same glyph/color/shape for
      every char (guards against future drift).
- [ ] **Editor ↔ engine round-trip**: author one ship and one non-ship object in
      the editor, load both in-game, confirm they render and behave identically
      to the editor preview (including rotation).
- [ ] **Direct save/edit round-trip**: open an existing `ships/` file, edit, save
      in place (no download), reload in-game, confirm changes persisted; repeat
      for a `worlds/` scene file.

---

## Current status & suggested priority (updated 26 Jun 2026)

### Completed
- ✅ **Phase 0** (Foundation — Config, Transform, RNG, font cache)
- ✅ **Phase 0.5** (ECS core — EntityManager, Components, Systems, EventBus, SpatialIndex)
- ✅ **Phase 1** (GridBody component + object model — tilesets, spawn factory, RenderSystem)
- ✅ **Phase 2** (Full arbitrary rotation — PilotSystem, angle-aware render/collision/thrusters)
- ✅ **Phase 3** (Tile-level collision, boarding fixes, coordinate system consistency)
- ✅ **Phase 4** (Decoupling & polish — draw separation, player-as-GridEntity, asteroid catalog, interaction generalization, format docs)

### Remaining phases (in suggested order)

1. **Phase 6** — Shared tile schema (single source of truth for chars/palette/collision)
2. **Phase 7** — Designer tool: non-ship objects (type selector, schema-driven palette)
3. **Phase 9** — Direct save/edit (FS Access API or local server)
4. **Phase 8** — World / scene authoring (scene files, multi-entity, editor mode)
5. **Phase 5** — Verification (manual test matrix, debug overlay, round-trip tests)

### Known open issue (carrying forward)

- **Interior canvas not visible after boarding:** `active_layer` switches to
  `"interior"` and the exterior correctly hides, but the interior canvas does
  not appear. Camera follows the player to the teleport position. May be a
  pre-existing render/layer bug in the Phase 1/2 code, possibly related to
  `RenderSystem.draw` draw order, interior canvas baking, or camera alignment
  after layer switch. New `origin` system in Phase 4 (`Transform._center`) or
  Phase 6 schema work may reveal the root cause.