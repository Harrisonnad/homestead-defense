# Architecture & Design Decisions Log

Running log of judgment calls made while working the Trello backlog, kept separate
from `game-master-spec.md`/`spec_*.md` (which describe intended design) because
these are implementation-level decisions, scoping calls, and known gaps that
aren't obvious from reading the code alone. Newest entries at the top.

---

## Water-avoidance safeguard for villager/livestock spawns

- **The bug**: water tiles got real collision earlier this session (fixing
  a "villagers walk on water" visual bug), but every *spawn* position that
  places a villager or livestock unit was still a fixed offset never
  validated against the generated terrain - if water happened to be
  adjacent to the home tile (or a player-placed Animal Pen's edge), the
  unit could spawn already overlapping the water collider and get stuck
  immediately (a `CharacterBody3D` starting inside a collider doesn't slide
  around it the way one walking into it from outside would).
- **New `PlacementGrid.find_nearest_non_water(world_pos, max_radius=4)`**:
  if the given position's tile isn't water, returns it unchanged; otherwise
  searches expanding square rings of nearby tiles for the nearest
  in-bounds, non-water tile and returns *that* tile's world position,
  falling back to the original position only if nothing clears within
  `max_radius` (implies the position is deep inside a large lake - should
  be rare). Mirrors the same risk `wave_spawner.gd`'s `_is_on_water()`
  already guards against for enemies, just generalized into a reusable
  correction rather than a reject-and-retry loop, since these spawn sites
  don't have a wide ring of alternate candidates to retry against the way
  a full-circle enemy spawn does.
- **Wired into all three fixed-offset spawn sites**: the initial 3
  villagers (`map_builder.gd`'s `_place_landmarks()`), a recruited villager
  (`homestead.gd`'s `recruit_villager` upgrade handler, via a
  `get_tree().get_first_node_in_group("map_builder")` lookup - `Homestead`
  has no existing reference to `MapBuilder`/`PlacementGrid`, same pattern
  `Bridge` already established), and Dog/Goat/Sheep spawned from a
  player-placed Animal Pen (`animal_pen.gd`'s `_spawn_livestock_unit()` -
  a *local* offset from the pen, converted to world space via
  `to_global()`/`to_local()` around the correction since the pen's own
  footprint is always land but an adjacent tile at its edge might not be).
- **Verified**: headlessly across 5 random seeds (zero initial villagers
  ever land on water; `find_nearest_non_water()` correctly leaves an
  already-dry position untouched and correctly relocates a water position;
  a recruit forced toward a real water tile via `recruit_offset` actually
  lands on dry land instead) and via full project boot with no errors.

---

## Three crop-selection polish wins

Found while asked "are there any more easy wins for crop selection" - three
genuine, small gaps, each fixed by reusing a mechanism already proven
elsewhere in the codebase rather than inventing anything new:

- **FarmPlot had no hover tooltip** - every resource node (Tree/Rock/Hay
  Bale/etc.) already shows one via `WorldTooltip` (`resource_node.gd`), but
  a FarmPlot - arguably the thing players most want state info on ("what's
  planted, how long left?") - never wired up the identical
  `mouse_entered`/`mouse_exited` + `get_first_node_in_group("world_tooltip")`
  pattern. Now it does, with a small `_tooltip_text()` covering all three
  states (`"Empty Plot - click to plant"` / `"<Crop> - growing (x/y days)"`
  / `"<Crop> - ready to harvest!"`).
- **`CropDef.tint` was dead code** - a leftover from the old tinted-sprite
  crop visual (`crop_def.gd`'s own comment already said as much) that
  nothing had read since real 3D crop meshes replaced sprites. Repurposed
  as a per-button color swatch in the crop-select panel, using the exact
  runtime-`ImageTexture` trick `build_menu.gd`/`hud.gd` already use for
  their own icon chips - zero new assets, one already-defined field
  finally doing something.
- **No "harvest every crop type" achievement existed**, despite the
  identical `TOTAL_BUILDING_DEFS`/`_placed_def_paths`/set-tracking pattern
  already being proven for Jack of All Trades. Added `TOTAL_CROP_TYPES` +
  `_crops_harvested` mirroring that pattern exactly; `on_crop_harvested()`
  gained an optional `crop_name` parameter (default `""`, so any
  hypothetical other caller stays back-compatible) and `FarmPlot.harvest()`
  now passes `current_crop.crop_name` into it.
- **A real debugging detour, not a code bug**: the first verification pass
  showed the boot smoke test silently failing to print anything, looking
  like a serious regression. Root cause was a stale Bash working directory
  (an earlier `cd` into `asset-pack/` for the Blender pea/sunflower work
  never got restored, so `--path .` was quietly resolving to the wrong
  parent folder) - not any of the actual code changes. Fixed by using an
  explicit absolute `--path` for verification going forward instead of
  relying on shell cwd state.
- **Verified**: headlessly (tooltip text correct in all three states; the
  crop panel's 6 buttons each carry a non-null icon texture; harvesting
  all 6 crop types unlocks Master Farmer, using a fresh `user://
  achievements.cfg` since unlocks persist permanently by design and would
  otherwise already be true from an earlier test run) and with a real
  render of the crop panel showing 6 distinctly colored icon swatches.

---

## Pea trellis mesh + Sunflower fulfills its own master spec entry

- **Pea gets real art**: new `gen_crop_pea.py` (2 crossed stakes + a tie,
  built once at full size since a trellis is a fixed support, plus a vine
  that climbs it across the 4 growth stages via `crop_common`'s shared
  growth curve) - a genuinely different crop-scene silhouette (upright
  frame + climbing vine) rather than another ground-hugging stem+fruit
  recolor, per the user's explicit "peas on a trellis" ask. This also
  frees the pack's `sunflower` mesh, which Pea had been borrowing as a
  placeholder since Corn took the mesh Pea used before that (see the Corn
  entry above) - a two-step placeholder chain finally resolved.
- **Sunflower fulfills design intent that was already written down but
  never built**: `docs/game-master-spec.md` §5.1's own crop table has
  "Sunflowers - Light source that wards off dark-seeking enemies" - and
  `gen_crop_sunflower.py`'s docstring already called it "Thematic 'light
  source' crop... the brightest day-mode accent in the crop set," but no
  crop ever used that mesh or that mechanic until now. New
  `crops/sunflower.tres` (`ammo_type = "food"`, a modest yield since its
  real value is the passive effect below, not its harvest) gives a
  GROWING or READY Sunflower plot two effects for as long as it occupies
  the plot, not just at harvest:
  - a `NightLight` (see `scripts/night_light.gd`) parented directly to the
    crop mesh instance, so it's freed automatically on the next harvest/
    replant/Locust-eaten - no separate lifecycle tracking needed.
  - a ward against Locust Swarms, reusing `scarecrow.gd`'s exact scan-
    timer + `start_fleeing()` mechanism rather than inventing a new one.
    Deliberately scoped identically to Scarecrow - only `flee_on_damage`
    enemies (Locusts) respond; a universal "no enemy can approach" ward
    would trivialize the night defense the rest of the game is built
    around.
- **Verified**: headlessly (6 crops registered; a growing Sunflower
  carries a `NightLight` on its crop mesh; the ward's scan tick correctly
  calls `start_fleeing()` on a nearby Locust and correctly leaves an
  ordinary Raider alone; harvesting clears both the crop and the ward;
  Pea's own mesh path exists and loads) and with real renders - a close
  crop on the pea trellis clearly showing the crossed-stake frame at both
  growth stages, and a day/night comparison showing the Sunflower's warm
  light pool appear at night while the Pea plots stay dark.

---

## Corn: the one farmable food crop

- **The gap it fills**: all 4 existing crops (Pumpkin/Carrot/Tomato/Pea)
  produce ammo for a specific defense building - there was no way to
  *grow* food at all, only gather it (Hay Bale/Berry Bush/Fishing Spot),
  despite food being a real, repeated cost (`Progression.gd`'s
  `advance_age_2`/`_3`, `veteran_training`, and the repeatable
  `recruit_villager` upgrade). Corn's `ammo_type = "food"` - it's the
  farmable counterpart to those gathered food sources, not another ammo
  crop, which also makes the crop-choice panel added earlier this session
  meaningfully strategic for the first time: ammo now vs. population
  growth later is a real tradeoff, not just "which of four ammo types do
  I want."
- **A placeholder finally resolved**: Pea had been borrowing the pack's
  "corn" crop mesh since no pea-specific art exists (`farm_plot.gd`'s
  `CROP_MESH_MAP`). Corn gets that mesh honestly now; Pea moved to
  "sunflower," another already-generated pack asset that had been sitting
  completely unused - no new Blender generation needed for either.
- **Companion planting extended to a real "Three Sisters" group**: the
  original `COMPANION_PAIRS` was a strict 1:1 dict (each crop names
  exactly one partner). The actual classic technique is corn+beans+squash
  grown together - Pea already stood in for beans, Pumpkin for squash - so
  Corn joining that trio meant each of the three needed to name *two*
  companions, not one. `COMPANION_PAIRS` values became lists
  (`"Pea": ["Pumpkin", "Corn"]`, etc.), and `_has_companion_neighbor()`
  changed from an equality check to an `in` membership check. Carrot+Tomato
  stayed an untouched, separate 1:1 pair.
- **Verified**: headlessly (5 crops registered; harvesting Corn adds food
  to Economy; Corn+Pumpkin and Corn+Pea both trigger the companion bonus;
  Carrot+Corn correctly does *not*) and with real renders of the new corn
  mesh, Pea's new sunflower mesh, and the crop-select panel picking up
  Corn as a 5th button automatically (it builds its button list from
  `available_crops` at runtime, so no UI code changed at all).

---

## Farm plot redesign: recognizable tilled land

- **Root cause of "the plot seems hidden"**: the farm plot's soil color
  (the `sm_terrain_tile_planter_edge` mesh's "wood_dark" trim region,
  `#8B5E3C`) turned out nearly identical in hue/darkness to the terrain
  generator's own "dirt" biome color (`map_builder.gd`'s
  `TERRAIN_DAY_COLORS["dirt"]`, `Color(0.42, 0.32, 0.2)`) - a placed plot
  visually disappeared against ordinary dirt ground, reading as a subtle
  raised bed rather than a recognizable "this is farmland" shape.
- **A second, independent bug found while investigating**: the plot's
  visual (4 copies of the planter-edge tile spread across a 2x2 area) and
  its `CollisionShape3D` (`size = Vector3(2, 0.2, 2)`) were both sized for
  a 2x2 footprint, but `buildings/farm_plot.tres` declares
  `footprint_size = Vector2i(1, 1)`. The placement grid only ever reserved
  1 tile, while the actual visible/clickable object spanned 2 - a real
  mismatch that could clip into whatever a player placed in the adjacent,
  *unreserved* tile. `farm_plot.gd`'s own `COMPANION_NEIGHBOR_DISTANCE`
  (1.1) only makes sense if plots are actually ~1 unit apart, confirming
  1x1 was the intended size, not 2x2.
- **Fix leans on shape, not just color**: new `sm_terrain_tile_tilled`
  mesh (`asset-pack/blender/gen_terrain_tile_tilled.py`) has alternating
  raised ridges and dark recessed furrows - a plowed-row silhouette that
  reads as "tilled" from the game's isometric camera distance even before
  color is considered, plus a low wood-plank border keeping the "tended
  plot" identity a bare tilled patch wouldn't have. The furrow shadows
  reuse the "chitin" trim region purely for its dark near-black-brown tone
  (unrelated to creature hide - the same "borrow a region by its color,
  not its name" precedent `gen_animals.py` already set reusing "stone" for
  horns/hooves). Sized to exactly one 1x1 module, fixing both bugs at once
  - `farm_plot.tscn` now instances a single tile instead of 4, and its
  collision shape shrank to match.
- **Verified**: headlessly (project imports/boots clean with the new mesh
  and rebuilt scene) and with a real render comparing empty/growing/ready
  plots side by side against grass, confirming the new tile reads clearly
  where the old one didn't.

---

## Farm plot crop-choice UI

- **It was easier than it looked**: `farm_plot.gd`'s `plant(crop: CropDef =
  null)` already accepted an explicit crop - the only thing missing was a
  caller that ever passed one in. Both the Farmer AI (`villager.gd`'s
  `_on_work_complete()`) and a player's click called `plant()` bare,
  triggering the existing auto-cycle through `available_crops`. No change
  needed to the growth/harvest/yield logic at all.
- **New `Selection.farm_plot_selected` signal**, mirroring the existing
  `villager_selected` signal exactly (`scripts/autoload/selection.gd`).
  `farm_plot.gd`'s empty-plot click now calls `Selection.select_farm_plot(self)`
  instead of `plant()` directly; a new hidden-by-default `CropSelectPanel`
  (`scripts/crop_select_panel.gd`) listens for it and builds one button per
  `available_crops` entry (name + yield + ammo type), calling
  `plot.plant(crop)` with the exact CropDef clicked.
- **The Farmer AI's auto-cycle is completely untouched** - it still calls
  `plant()` bare, so an untended plot keeps rotating through every crop on
  its own. The player-facing choice is additive, not a replacement.
- **Mutual exclusion between the two selection panels**: selecting a
  villager hides the crop panel and selecting a farm plot hides the
  villager panel (each listens to the other's Selection signal) - both
  panels share the same bottom-center screen anchor, so without this
  they'd visually stack if one was left open from a previous click.
- **Verified**: headlessly (clicking an empty plot shows exactly
  `available_crops.size()` buttons; pressing a specific button plants that
  *exact* CropDef, not the auto-cycle's next-in-line default; both
  directions of panel mutual-exclusion; the Farmer AI's bare `plant()` path
  still works unchanged) and with a real screenshot of the panel showing
  all 4 crops with their yield/ammo readout.

---

## Trello backlog sweep (6 open cards: #24-#29)

- **#24 Resources regenerate too quickly**: `Tree` had no `respawn_seconds`
  override at all - it was silently inheriting `resource_node.gd`'s base
  default of 3.0s, far shorter than every sibling node (Rock 6s/BerryBush
  10s/HayBale 12s/FishingSpot 15s) despite being the *most common* resource
  (55% of the spawn roll). Almost certainly a missed override, not a
  deliberate balance choice. Fixed by giving Tree its own explicit 6.0s
  value and doubling every other node's respawn time (Rock 12s/BerryBush
  20s/HayBale 24s/FishingSpot 30s), preserving the existing "rarer resource
  = slower respawn" ordering rather than inventing a new curve.
- **#25 Daytime lighting still showing the "mycelium" (night glow) effect**:
  root cause was the night-lighting pass (`day_night_cycle.gd`'s ambient
  light addition) - `ambient_light_color`/`energy` were set once as fixed
  `Environment` values, never touched by `_process()` like the sun/sky/fog
  colors are, so the violet night-fill tint was active at full noon too.
  First fix attempt lerped `ambient_light_energy` to 0 at full day - this
  did stop the tint, but a real render showed daytime reading noticeably
  flatter/darker than before, because it also killed the ambient fill light
  itself (previously implicit from the sky background at all times, not
  just at night). Corrected by keeping ambient energy constant (0.6) and
  only lerping its *color* between a neutral daytime tone and the violet
  night tone - the fungal tint is night-only, daytime brightness is
  unaffected. A good reminder that "zero it out during the day" and "make
  it season/time-reactive like everything else already is" aren't always
  the same fix.
- **#26 Landscaping should share the night mycelium theme**: Tree/Rock/
  BerryBush/FishingSpot are gray-box primitives with plain
  `StandardMaterial3D`s (deliberately, per `resource_node.gd`'s own
  comment, since they predate the custom asset pack) - they never
  responded to day/night at all, unlike every pack mesh/terrain tile.
  Building a full UV-texture day/night material for them wasn't an option
  (no unwrapped textures exist for primitives), so added a new, much
  simpler shader, `assets/terrain/landscape_day_night.gdshader` - same flat
  `mix(day_color, night_color, ratio)` idea as `terrain_day_night.gdshader`,
  plus a flat `EMISSION = glow_color * glow_strength * ratio` term (no
  texture mask needed) for a subtle fungal glow accent at night. Applied
  per-mesh-part with `day_color` set to each primitive's *exact* prior
  `albedo_color` (so daytime is unchanged) and a modest `glow_strength`
  (0.0 on inert parts like tree trunks/rope, up to 0.25 on "should read as
  a little alive" parts like berries/fish).
- **#27 Trees too round, not enough variation**: the single `tree.tscn` was
  one cylinder trunk + one perfect `SphereMesh` foliage - literally as
  round as a primitive can look, and there was only ever one shape. Kept
  the original silhouette but made it visibly irregular (3 offset spheres
  instead of 1), and added two more distinct variants: `tree_pine.tscn`
  (stacked cones, a conifer silhouette) and `tree_tall.tscn` (taller/
  thinner trunk, non-uniformly-scaled ellipsoid foliage - stretched, not
  round). `map_builder.gd`'s single `tree_scene` export became
  `tree_scenes: Array[PackedScene]`, picked randomly per spawn via a new
  `_random_tree_scene()` helper - `MapBuilder` doesn't need to know how
  many variants exist or care which one lands where.
- **#28 No way to traverse water**: a direct consequence of this session's
  earlier "villagers can walk on water" bug fix - giving water tiles real
  collision correctly stopped the walk-on-water bug, but as a side effect
  made water *fully* impassable with zero way back across, which a
  procedurally generated river/lake map can turn into a hard blocker. Added
  a `Bridge` building (new `"bridge"` `BuildingDef` category), the one
  category `PlacementGrid.check_placement()` *requires* water instead of
  forbidding it. On completion it permanently frees the specific
  `CollisionShape3D`(s) under its footprint (`MapBuilder.open_water_
  crossing()`, matched to tiles via a new `Water_%d_%d` naming convention
  on each shape). Deliberately not built on the generic `Building` base
  class: collision layer 2 is what makes a structure *both* attackable
  *and* movement-blocking everywhere else in this codebase (Wall, Building,
  Fence), and a bridge structurally can't have the first property without
  the second - so `Bridge` has zero collision of its own and can't be
  attacked/destroyed. This needed one small generic hook in
  `construction_site.gd`'s `_on_complete()` (`if building.has_method(
  "on_footprint_ready"): building.on_footprint_ready()`) since a Bridge
  can't safely act on its own `footprint_origin` inside `_ready()` - by the
  same "assigned after `add_child()`, so `_ready()` still sees the old
  value" gotcha the Ruin bug fix (`#22`, see below) already ran into once
  this project.
- **#29 No way to prioritize which resources Gatherers fetch**: added a
  single `Economy.priority_resource_type` (not a full ranked list - a
  single "prefer this one" toggle is a much smaller, more legible control
  surface for the same practical benefit). `Villager._find_nearest_
  gatherable()` now strictly prefers the nearest available node of that
  type over anything closer of another type, falling back to nearest-of-
  any-type exactly as before when no priority is set or the priority type
  currently has nothing available. Exposed by turning the HUD's Wood/Food/
  Stone chip icons from plain `TextureRect`s into flat icon `Button`s
  (Home/Pop stay non-interactive, since they aren't gatherable) - click to
  set, click again to clear, with a `"* "` prefix on the active resource's
  label as the only UI feedback needed.
- **Verified**: headlessly (Bridge legal on water/illegal on grass, Wall
  still illegal on water/unchanged; a simulated completed Bridge actually
  removes its tile's water-collision shape; gather priority wins over a
  closer node of another type, and correctly falls back to nearest-of-any-
  type once cleared; `tree_scenes.size() == 3`) and with real renders
  (daytime terrain reads clearly bright/colorful again after the ambient
  fix - the first, over-corrected attempt was caught this way, not by any
  headless assertion; the HUD's `"* Stone"` priority marker; the build
  menu's new `[8] Bridge` slot).

---

## Torch building + build-menu category grouping

- **Torch (`scripts/torch.gd`, `scenes/buildings/torch.tscn`,
  `buildings/torch.tres`)**: a cheap (5 wood), low-HP (15), pure-utility
  `Building` - it exists only to let players patch dark gaps between
  buildings/walls (see the night-lighting entry above) without paying for
  a full structure. Reuses `sm_prop_spore_lantern.glb`, an already
  Blender-generated, previously-unused prop mesh (its trim comment: the
  spore-glow material was designed to "quietly light at night ... rather
  than needing a warm light the shader can't produce" - fitting flavor for
  a building whose whole job is now to carry a real dynamic light).
  Overrides `Building._add_night_light()` with a lower, dimmer light
  (`position.y=0.55` vs. the default `1.5`) since the lantern prop is much
  shorter than a house or tower - reusing `Homestead`'s already-established
  override pattern rather than inventing a new one.
- **The actual problem this solves**: `NightLight` (see below) is only
  ever a side effect of building a House/Storehouse/Tower/etc. - there was
  no way to deliberately light an empty stretch of wall or a dark corner
  of the base without also paying for and placing a full building there.
  Torch is the "just give me light" building.
- **New `"utility"` `BuildingDef.category`** - Torch is its own category
  rather than being folded into `"defense"`; it has zero combat function
  and grouping it with the defense buildings would have been misleading
  in tooltips/UI even though the build menu's grouping logic (below) would
  have handled it fine either way.
- **Build-menu category grouping (`scripts/build_menu.gd`)**: this pass
  also added a 12th `BuildingDef`, on top of a session that had already
  grown the hotbar to 11 - explicitly called out as "getting too large."
  Rather than just raising `HOTKEY_SLOTS` again, top-level hotbar slots are
  now grouped by `BuildingDef.category`: a category with exactly one
  building (wall/farm/core/storage/pen/utility today) still shows and
  hotkeys directly, unchanged from before. A category with more than one
  building - only `"defense"` today, with 6 (Watchtower/Ballista/Sling
  Post/Spike Trap/Scarecrow/Net Trap) - collapses into a single group
  button (labeled e.g. `"[2] Defenses +"`). Its hotkey (or a click) opens
  a flyout row of that category's buildings, each with its own 1-9 hotkey
  while the flyout is open; picking one or re-pressing the group's hotkey
  closes it again. This took the bar from 11 slots to 7 (Wall, Defenses,
  Farm Plot, House, Storehouse, Animal Pen, Torch) with the same building
  count, and generalizes automatically - a second utility building would
  make `"utility"` a group too, with zero further hotbar-design work.
- **Deliberately not built**: multi-level nested categories (a flat
  one-level flyout is enough for 6 buildings, the largest group today) and
  a persistent/pinned flyout state across placements - the flyout closes
  every time a building is actually selected, matching the existing
  "start_placing puts you in placement mode" flow rather than leaving a
  stale open submenu on screen.
- **Found via real render, not headless assertions**: the HUD's separate
  static control-hint label (`hud.tscn`, unrelated to `build_menu.gd`'s own
  per-building hotkeys) still read `"[1-8] Building"`, stale since before
  this session even started. Caught only because the real screenshot pass
  for this change happened to include that corner of the screen; fixed to
  `"[1-9] Building/Category"`.
- **Verified**: headless (grouping produces the expected 7 top-level slots
  with defense holding exactly 6; opening/closing the flyout via the same
  dispatch path `_unhandled_input` uses; selecting a flyout entry closes it;
  Torch's own `NightLight` child exists with its overridden values) and
  real renders (collapsed bar, the open Defense flyout, and a placed Torch
  showing its own distinct light pool separate from the Homestead's).

---

## Night lighting (base visibility for the core night-defense gameplay)

- **The actual bug**: the sun's night-time `light_energy` was deliberately
  very low (0.05) for atmosphere, but that made the game's single most
  important moment - the night defense - the hardest to visually read.
  Fixed with two complementary changes rather than just cranking the sun
  back up (which would have flattened the day/night contrast the whole
  seasonal-visuals pass, above, was built to sell).
- **`NightLight` (`scripts/night_light.gd`)**: a reusable `OmniLight3D`
  component, warm lantern-color (`Color(1.0, 0.75, 0.45)`), off during the
  day and fading in at night off the same `GameClock.day_factor()` source
  `day_night_cycle.gd` already uses - no new signal needed. Shadows
  disabled per-light deliberately; a shadow-casting light on every building
  would add up fast.
- **Attached to `Building` (base class) and `Homestead` only**, not to
  Wall/Trap/FarmPlot/Fence/Scarecrow. A whole wall perimeter each carrying
  its own real-time light would be visual clutter and a lot of concurrent
  lights for little gain; the Homestead gets a stronger/wider override
  (`night_energy=2.2`, `range=10.0`, vs. a regular Building's
  `night_energy=1.4`, `range=6.0`) since it's the base's anchor and the
  actual raid target.
- **Global night floor raised, modestly**: `day_night_cycle.gd`'s sun
  `light_energy` lerp floor went `0.05 -> 0.14` (noon stays 1.2, unchanged)
  - enough that the world isn't pure black between buildings' light pools,
  not enough to undermine the day/night contrast. Paired with an explicit
  `ambient_light_source=COLOR`/modest `ambient_light_color`/`energy=0.6` on
  `Main.tscn`'s `Environment`, previously unset (ambient was implicitly
  deriving from background color, which is near-black at night) - this
  fills in shadowed sides of buildings/terrain that `NightLight`'s point
  lights alone don't reach.
- **Test-harness gotcha, new variant**: even without any `is CustomClass`/
  static-type reference, a bare `load()` of a `class_name`-decorated script
  (`night_light.gd`) from a `--script` entrypoint triggered the same
  eager-class-reload-breaks-autoload-resolution problem documented
  elsewhere in this log. Fixed by resolving the autoload via
  `root.get_node("/root/GameClock")` instead of the bare `GameClock`
  identifier in that one test script, rather than avoiding the `load()`
  entirely (the real code doesn't have this problem - only the isolated
  `--script` test harness does).
- **Verified**: headless component test (NightLight off at noon, at
  `night_energy` by midnight, Homestead override values correct) plus a
  real non-headless render at midnight showing a clear warm light pool
  around the homestead against the (still meaningfully darker) surrounding
  terrain.

---

## Seasonal terrain/lighting reskinning (visual counterpart to the season system)

- **Scope clarified up front, not guessed**: "visual changes into the new
  season" was genuinely ambiguous (a UI announcement popup? real
  environment changes? both?) - asked directly rather than picking one and
  risking real Blender/shader effort on the wrong scope. Confirmed:
  environment/terrain reskinning, not a UI modal.
- **Summer is the pre-existing baseline, byte-for-byte** - both
  `map_builder.gd`'s `SEASON_TERRAIN_DAY_COLORS["summer"]` and
  `day_night_cycle.gd`'s `SEASON_SKY_DAY["summer"]`/`SEASON_FOG_DAY["summer"]`
  are exactly the original hardcoded values, so a summer map/sky is
  pixel-identical to before this change. A real regression-check bug
  surfaced while verifying this: **day 1's default season is spring, not
  summer** (`GameState.current_season()`'s own quarter math), so a test
  that assumed "boot state = summer baseline" was checking the wrong
  season entirely - fixed by explicitly forcing a summer day (8) before
  comparing, exactly like the other three seasons.
- **Night colors deliberately stay constant across all four seasons** -
  both in the terrain shader's `night_color` and `day_night_cycle.gd`'s
  night sky/sun colors. The fungal-world night identity (§4) isn't
  seasonal; only the daytime look shifts. This keeps night's visual
  language completely unchanged, so nothing about the established "night =
  violet/hostile" reading gets diluted.
- **The Ground plane (Main.tscn) needed its own update path** -
  `map_builder.gd`'s tile MultiMeshes are its own materials, but the base
  Ground plane underneath them (a separate `ShaderMaterial` on
  `Ground/MeshInstance3D`, sharing the same shader as a seamless backdrop -
  see `_build_terrain()`'s own comment) is a sibling node MapBuilder
  doesn't otherwise touch. Missing this would have left a visible seam:
  tile colors changing per season while the plane underneath stayed
  perpetually summer-green. Wired via a new `ground_mesh_path` export
  (same pattern every other MapBuilder cross-reference already uses),
  updated in the same `_apply_season_terrain()` call as the tile materials.
- **First-pass spring and summer read as nearly identical** in a real
  render - caught by actually looking at screenshots, not just trusting
  the headless color-value assertions (which passed even when the visual
  result was weak, since they only checked "does it match some season-
  specific value," not "is it visually distinct enough to matter"). Fixed
  by increasing spring's saturation/brightness gap from summer
  meaningfully (grass `(0.36,0.56,0.3)` → `(0.44,0.66,0.32)`, water
  similarly brightened) rather than a token difference. Fall and winter
  were strong on the first pass (winter in particular reads convincingly
  as snow-covered ground purely through color, without any actual
  snow/particle system).
- **Known minor limitation, accepted**: the map edge's radial fade overlay
  (`_build_edge_fade()`) uses a fixed `EDGE_FADE_COLOR` baked once at
  build time to match the *original* fog color, and isn't updated per
  season. It's a peripheral, distant cosmetic effect (fades to sky color
  well past the playable area) - a slight mismatch there in non-summer
  seasons is a minor, likely barely-noticeable imperfection, not worth a
  dynamic edge-fade shader for this pass.
- **Verified**: headless assertions (summer terrain matches the original
  hardcoded baseline exactly when explicitly forced to a summer day; each
  season's tile materials *and* the Ground plane's material update in
  sync; `WorldEnvironment`'s background/fog visibly shift for winter during
  daytime) plus real (non-headless) screenshots of the actual game world in
  all four seasons, confirming - after the spring/summer contrast fix -
  that all four are now clearly distinguishable at a glance, not just in
  raw color values.

---

## Seasonal enemy identity + new enemy AI states (§5.4 + §5.7 together)

- **The two deferred items compose better together than either would alone.**
  §5.7 (seasonal enemy identity) and §5.4 (non-lethal deterrence) were each
  flagged as needing their own subsystem. Giving each new seasonal enemy a
  real non-lethal counter turned out to be a smaller, more legible slice of
  §5.4 than retrofitting all 4 existing enemies with a universal toggle -
  and gave §5.7's "reshapes strategy" goal a second dimension (not just
  harder, *behaviorally different*).
- **`GameState.SEASONS`/`current_season()` is a different "season" than the
  word already means everywhere else in that file** (the whole 20-day
  playthrough arc). Named and commented explicitly to avoid the collision -
  4 even quarters of the existing arc, no new calendar/UI, purely a
  wave-composition input.
- **`Enemy.set_initial_target(default_target)` replaces `wave_spawner.gd`
  setting `.target` directly.** This one seam is what let Locust/Wolf
  redirect their default target (nearest Farm Plot / nearest Animal Pen)
  without WaveSpawner needing to know anything about seasonal enemy types -
  it just calls the same method on everything, and only Locust/Wolf
  override it.
- **`AIState` (APPROACHING/ENGAGED/FLEEING/PACIFIED) lives on `Enemy` itself,
  not a subclass**, so `start_fleeing()`/`pacify()` are available to *any*
  enemy (a Net Trap works on Raiders/Brutes too, not just Wolves) while
  defaulting to fully inert for the 4 pre-existing enemy types
  (`flee_on_damage = false` by default, `pacify()` only ever called
  externally). `_on_attack_range_body_entered` and the attack-timer path
  both gained state guards so a fleeing/pacified enemy can't be
  re-engaged mid-flight by something wandering into its old AttackRange.
- **Locust eats the crop, Wolf damages the pen directly** - both override
  `_reach_target()` rather than reusing the generic raid-loss/homestead-
  damage path, since that path is hardcoded to look up the "homestead"
  group regardless of what `target` actually was. `FarmPlot` gained a
  small `get_eaten()` method (distinct from `harvest()` - no resource
  payout) so Locust doesn't reach into FarmPlot's state machine directly.
- **Two of three new visuals reused existing assets, one needed real
  generation.** `sk_crawler` (Locust) was already generated and unused,
  literally authored as "low, wide swarm creature." `sm_prop_rope_coil`
  (Net Trap) was an existing decorative prop that happens to read
  perfectly as netting. Wolf had no unused quadruped fitting "dangerous
  predator" (Dog/Goat/Sheep are all livestock now) and Scarecrow had no
  fitting prop at all, so both are genuinely new Blender-generated meshes
  (`gen_wolf.py`, `gen_scarecrow.py`), following the exact same
  `creature_common.py`/`tool_common.py` pipeline already proven this
  session - not a special case.
- **Non-lethal tools cost wood/stone only, not an existing crop's ammo** -
  reusing e.g. Carrot/darts for the Net Trap would dilute §5.1's
  already-established "one crop, one legible defense output" rule.
  Scarecrow and Net Trap are a parallel resource track.
- **Build hotbar hotkeys cap at 9** (`build_menu.gd`'s new
  `HOTKEY_SLOTS` constant) - a real, if minor, bug this surfaced: adding
  Scarecrow/Net Trap pushed `building_defs` to 11 entries, and the old
  `KEY_1 + building_defs.size()` range check would have silently mapped
  slots 10-11 to arbitrary non-digit keycodes while still *labeling* the
  buttons "[10]"/"[11]." Fixed by capping the label/hotkey logic at 9 and
  falling back to label-only (still fully clickable) beyond that.
- **`TOTAL_BUILDING_DEFS` (achievement_manager.gd, Jack of All Trades)
  updated from 9 to 11** - easy to miss when adding new BuildingDefs, which
  is exactly why that constant has its own "update if a new BuildingDef is
  ever added" comment.
- **Headless test gotcha, same class as before**: the same
  `is CustomClass`/static-enum-reference issue from the earlier deferred-
  content pass recurred in this verification script too and was avoided
  the same way (node-name/duck-typing checks, raw enum ints with a
  comment). Also hit two flavors of "`queue_free()` doesn't take effect
  until the next idle frame" in the test itself - checking
  `is_instance_valid()` immediately after a manual `_physics_process()`
  call needs an `await process_frame` first, or it will incorrectly read
  as "still valid" - not a game bug, a test-methodology one.
- **Verified**: `current_season()` across the full day range; a Locust
  reaching a Farm Plot empties it with zero Economy/Homestead side effects;
  `start_fleeing()` doesn't count as a kill and the enemy actually despawns
  past `flee_distance`; `pacify()` freezes movement, reverts after its
  duration, and a pacified enemy can still be damaged normally in the
  meantime; a Scarecrow frightens a nearby Locust but not a Raider; a Net
  Trap pacifies while Spike Trap's `pacify_duration = 0` path is
  unchanged (regression check); a Wolf targets and damages an Animal Pen
  directly, not the Homestead; wave composition adds Locusts only in
  summer / Wolves only in winter under the existing per-night cap and trim
  order. Two accelerated playthroughs (jumped to day 6 and day 16 so the
  run actually lands inside summer/winter within the time budget rather
  than hoping ~36 natural cycles complete first) ran with zero
  script/physics errors. Real render confirmed the Wolf reads as
  meaningfully bigger/more threatening than the Locust, and the Scarecrow's
  post/crossbar/hat silhouette is recognizable at a glance.

---

## Deferred-content pass: pulling MVP-deferred scope back in

Asked directly to spend remaining session budget bringing back items
previously pushed out of MVP scope. Picked the ones genuinely finishable
well (existing assets, contained logic) and explicitly skipped the rest -
see `README.md`'s matching status block for the full skip list and why
(mainly: audio needs generation capability this session doesn't have;
seasonal calendar and trader/scavenger economy are each their own
subsystem, not a slice of one).

- **Glow-flora scatter** was the easiest possible win: all 7
  `sm_flora_*` assets already existed (generated in an earlier session) but
  were referenced in zero scenes. Wired via the same `PackProp`
  script-free-decoration pattern already used for hay/sack/crate props, and
  a new `_scatter_flora()` pass in `map_builder.gd` mirroring
  `_scatter_props()`'s shape (avoids water/crop-plot/animal-zone tiles).
- **Goat reuses `dog.gd` directly** rather than a near-duplicate script -
  added one new `excluded_creature_names: Array[String]` export (empty =
  Dog's existing "fight anything" behavior; Goat sets it to
  `["sk_shambler", "sk_myconid"]` so it only ever engages Raider-tier
  enemies, matching the spec's "active combat assist on smaller enemies").
  Checked in both the proactive scan (`_find_nearest_enemy_in_detect_radius`)
  and the passive melee-reaction path (`_on_attack_range_body_entered`), so
  a Goat won't chase *or* trade blows with a Brute/Siege-breaker.
- **Sheep needed no combat logic at all** - it's a `StaticBody3D` with
  `take_damage()`/HP on the same collision layer (8) Dog/Goat already sit
  on, which is already inside `Enemy`'s `AttackRange` detection mask. A
  raider that wanders close enough may opportunistically engage it instead
  of continuing to the Homestead, for free, via `enemy.gd`'s existing
  generic `has_method("take_damage")` targeting - exactly the "padding/
  physical blockade" role from the spec, zero `enemy.gd` changes needed.
  Both Sheep/Goat were verified with a real (non-headless) render at the
  Animal Pen - no overlap with each other, the Cow, or the fence.
- **Companion planting applies to the game's actual 4 crops**
  (Pumpkin/Carrot/Tomato/Pea), not the master spec's original example table
  (which used different crops entirely) - paired Carrot+Tomato and
  Pea+Pumpkin, both real permaculture companion pairs, for a +25% yield
  bonus at harvest when the paired crop is growing/ready in an adjacent
  plot. Checked by **world-position proximity** (`<= 1.1` units), not
  `footprint_origin`/`PlacementGrid` - map-generated crop plots (see
  `map_builder.gd`'s `_populate_farm_plots()`) are spawned directly and
  never get a `footprint_origin` assigned, so grid-tile adjacency would have
  silently only worked for player-built plots.
- **NightReport is a new autoload, deliberately separate from
  AchievementManager** - same one-line-hook-at-existing-call-site pattern,
  but ephemeral (reset every `night_started`) rather than permanent, and
  built for a different consumer (the Dawn Report UI, not achievement
  unlocks). Reused its existing hook points (`enemy.gd`'s `take_damage()`/
  `_reach_target()`, `villager.gd`'s `take_damage()`) rather than
  duplicating them a third time.
- **Dawn Report is intentionally non-blocking** - master spec §5.5 asks for
  idle-friendly night resolution, and night combat was already fully
  automated (Guards/Towers/Traps/Dog/Goat all act without input); the only
  missing piece was a summary, not a new mechanic. The panel's root
  `CenterContainer` sets `mouse_filter = IGNORE` so it never blocks clicks
  to the game underneath, and it auto-hides after 8 seconds rather than
  requiring a dismiss click - it should never get in the way of a player who
  wants to keep playing straight through it.
- **Iron Curtain and Veteran Guard, previously deferred as needing "a short
  design pass" for new tracking, were unblocked by NightReport landing** -
  Iron Curtain became a one-line check (`Progression.wall_tier() >= 2` and
  `NightReport`'s zero-damage tally) on `NightReport.report_ready`. Veteran
  Guard's per-villager night-survival counter lives on `villager.gd` itself
  (not `AchievementManager`) since that state belongs with the specific
  villager - it only accumulates while the villager is *currently* Guard
  *and* Veteran Training is already purchased, matching the design doc's
  "survives 5+ nights afterward" wording (nights before the purchase, or
  spent on another role, don't count; switching roles resets it).
- **Headless test gotcha, worth remembering**: a verification script for
  this pass hit a real, reproducible compile-time error -
  `is Dog`/`is Sheep`/`FarmPlot.State.READY`-style static references to
  custom `class_name` types, used directly from a `SceneTree`-extending
  entrypoint script, triggered GDScript to eagerly reload those class files
  in a context where autoload singleton identifiers
  (`AchievementManager`/`GameClock`/`Progression`) failed to resolve -
  despite those exact classes compiling and running fine when loaded
  normally through `Main.tscn`. Every earlier test script this session that
  worked used only generic `Node`/`Node3D` typing; this one didn't until
  fixed. Worked around by using node-name checks (`child.name == "Dog"`)
  and raw enum integers instead of static class/enum references - not fully
  root-caused, but reproduced twice identically, so worth flagging like the
  `animal_pen.gd` Area3D mystery earlier in this log.

---

## Water collision fix (characters could walk on water)

- **This was a known, documented gap, not a hidden bug** - `map_builder.gd`'s
  own header comment said outright "water is wadeable until navmesh lands."
  No navmesh/pathfinding system exists in this codebase (every character
  moves via straight-line `move_and_slide()` toward a target, zero
  navigation), so the real fix here is scoped to "water physically blocks
  movement," not "characters intelligently route around it" - that's a
  separate, much bigger feature this doesn't attempt.
- **Reused the existing collision-layer convention instead of touching any
  character script.** Wall/Building/Fence all sit on `collision_layer = 2`,
  and Villager/Enemy/Dog's `collision_mask` already includes it (that's how
  they already slide around Walls/trees/rocks today). Water tiles get a new
  `StaticBody3D` ("WaterCollision", one `CollisionShape3D` per water tile)
  on that same layer 2 in `map_builder.gd`'s `_build_terrain()` - every
  moving character now blocks/slides against water exactly like it already
  does against a Wall, with zero changes to `villager.gd`/`enemy.gd`/
  `dog.gd`.
- **The real risk wasn't the fix itself, it was where enemies spawn.**
  `wave_spawner.gd`'s `_pick_spawn_position()` rings around the homestead at
  a random angle/distance (18-30 units) checking only wall clearance - never
  biome type. Before this fix that didn't matter (no collision to get stuck
  on); after it, an enemy could easily have spawned already overlapping a
  solid water collider and gotten stuck/jittery immediately, which would
  have been a *worse*, harder-to-notice bug (a night that never resolves)
  than the one being fixed. Added a `map_builder_path` reference (same
  pattern `build_manager.gd` already uses) and an `_is_on_water()` check
  alongside the existing wall-clearance check, so candidates on water are
  rejected the same way candidates too close to a wall already are.
- **Known residual edge case, accepted**: `_pick_spawn_position()`'s final
  fallback (`spawn_point.global_position`, used only if all
  `max_spawn_attempts` candidates fail) isn't itself checked against water.
  This is an existing last-resort path for an already-degenerate case: not
  worth expanding scope over for a fix this targeted.
- **Villager/building placement wasn't at risk** - `PlacementGrid` already
  restricts buildings/farm plots to `grass`/`dirt` biomes, and the
  homestead/starting villagers spawn within the map's validated buildable
  core, so this fix didn't need to touch any of that.
- **Verified**: a real physics check (spawn a `CharacterBody3D`, push it
  toward a known water tile for 60 physics frames) confirmed it travels
  only ~0.10 of a 0.9-unit gap before being blocked, across 5 separate map
  seeds. A 300-sample fuzz test confirmed `_pick_spawn_position()` never
  returns a water tile. An accelerated ~4-day playthrough with real wave
  spawns and enemy movement ran with zero script/physics errors.

---

## Homestead Age/Era progression system (the "Age of Empires" request)

- **Fulfills a design doc that predates all current code.**
  `docs/spec_base_builder.md` (titled "Base Builder (AoE-style, Homesteading
  Theme)") specified a Homestead -> Established Farm -> Fortified Farmstead
  progression model that was never implemented - only `wall.gd`'s
  `reinforced_walls` upgrade existed as a partial, walls-only seed of it.
  This system generalizes that seed to every building, confirmed directly
  with the user: a **global Age/Era gate** (not per-building walk-up
  upgrades), and **deepening the existing 9 buildings** rather than adding
  new building types.
- **Reused the upgrade board instead of building new UI.** `advance_age_2`/
  `advance_age_3` are two more `Progression.UPGRADES` entries (the latter
  gated on the former via a new `requires` field), so the existing `T`-key
  panel, affordability graying, and `SaveManager`'s existing
  `Progression.purchased` persistence all work with zero new code. The old
  `reinforced_walls` entry was retired and folded into `wall_tier()`, now
  derived from `homestead_age()`, so there's one source of truth instead of
  two upgrade mechanisms that could drift out of sync.
- **Retroactive by design, not just for new construction.** Every affected
  script (`building.gd`, `wall.gd`, `trap.gd`, `farm_plot.gd`,
  `homestead.gd`) connects to `Progression.upgrade_purchased` and re-applies
  its own `_apply_age(age)`/equivalent, recomputed from a captured base value
  each time rather than compounding - so buildings already standing when the
  homestead ages up get stronger immediately, which is what actually makes
  "the homestead visibly grows" land for the player. `Building` centralizes
  this for House/Storehouse/Tower/AnimalPen (all extend it); Wall/Trap/
  FarmPlot/Homestead each carry their own small copy of the same pattern
  (consistent with this codebase's existing preference for small per-script
  duplication over deep inheritance).
- **A shared `AgeTrim2`/`AgeTrim3` node-name convention** drives all visual
  escalation - any building scene may optionally have child nodes with those
  exact names, hidden by default; `_apply_age()`/`_update_age_trim()` just
  toggles `.visible` by name lookup by convention, so no per-building special
  casing was needed to wire 9 scenes + Homestead.
- **Visual escalation reused already-generated, unused assets first.**
  `sm_rampart_walkway.glb`, `sm_defense_wall_slit.glb`, and `sm_barricade.glb`
  existed in `assets/custom_pack/models/` already (generated at some earlier
  point) but were referenced in zero scenes before this - free Age-2 trim
  for Wall/Watchtower/Ballista/Sling Post/Spike Trap. Age-3 needed exactly
  one new asset, `sm_prop_banner_post` (a pennant-on-a-post, ~136 tris),
  reused identically across every building rather than authoring nine
  bespoke tier-3 variants - matching `spec_base_builder.md`'s own original
  cost-containment guidance ("reuse assets with recoloring, scaling, or
  additive prop-stacking" rather than new packs per tier).
- **Deliberately did NOT scale Wall's visual size** the way every other
  Building-derived type gets a modest scale bump (`Building.AGE_SCALE`) -
  wall segments tile edge-to-edge in a continuous line, and scaling one
  segment up would create visible gaps/overlaps with its unscaled
  neighbors. Wall's escalation is HP + trim only; Trap/FarmPlot were left
  unscaled too for consistency, since their trim-node visual change is
  enough on its own.
- **Two real bugs found and fixed as a direct consequence of this work**,
  not scope creep - exactly why the verification step exists: (1) `Tower`'s
  chokepoint range bonus (`if chokepoint: attack_range += 1.0` in `_ready()`)
  was silently dead code - `ConstructionSite`/`Ruin` both set
  `building.chokepoint` *after* `add_child()`, i.e. after `_ready()` had
  already run, so the bonus never actually applied in the shipped game.
  Fixed by giving `chokepoint` a setter that recomputes range immediately
  regardless of ordering. (2) `AchievementManager`'s Iron Homestead tracking
  bound `homestead.max_health` once at connect time via `.bind()` - harmless
  before this system existed (max_health was static), but would have
  silently corrupted the running min-HP-ratio the moment a homestead aged up
  and its max_health changed. Fixed to read `max_health` live from the
  homestead node reference instead of a stale bound value.
- **Verified headlessly**: a purpose-built script instantiated real Wall/
  Watchtower/House/AnimalPen scenes, confirmed baseline age-1 stats, then
  purchased `advance_age_2`/`advance_age_3` through the real `Progression`
  API (not by hand-setting state) and re-asserted every stat against the
  already-existing instances - confirming retroactive application, not just
  correct values on fresh construction. Also confirmed `advance_age_3` is
  refused before `advance_age_2`, and that `fully_upgraded` still fires
  correctly at the new `UPGRADES.size()` of 6. Save/load correctness was
  confirmed by code inspection rather than a second script: `SaveManager`
  already restores `Progression.purchased` *before* re-instantiating
  buildings, and every building already applies its age at its own
  `_ready()`, so the existing save/load path needed zero special-casing.
- **Verified with real (non-headless) renders**, not just headless
  assertions - a throwaway gallery scene placed Age-1 and Age-3 instances of
  the same buildings side by side. Confirmed the scale bump, rampart-walkway
  trim, and banner prop are all clearly visible and read as intended on the
  Watchtower; the Wall's Age-2 slit panel turned out to visually dominate
  the thin picket-fence base model, which happens to look *better* than
  planned (reads as a genuinely more fortified wall, fitting the "Reinforced
  Walls" flavor perfectly) rather than the two layering as separately
  visible pieces.

---

## Phase E slice 1: settings/controller baseline + local achievements + export presets

- **Scope call: controller support means menu navigation + camera, not full
  gameplay parity.** Building placement, villager/ruin selection, and every
  hotkey (B/T/R/1-9) stay mouse-and-keyboard-only. Steam Deck's trackpad
  emulates a precise cursor and Steam Input can remap any keyboard key to
  any physical input, so a mouse-driven placement flow isn't actually a
  Deck-compatibility gap - it's how most non-twin-stick strategy games ship
  on Deck. What *is* a real gap without extra work: menu navigation (nothing
  had focus, so a gamepad-only player had no way to move through buttons)
  and pausing (Escape was a raw keycode check, invisible to Steam Input's
  action-based remapping). Fixed both; didn't attempt the rest.
- **`ui_cancel` over raw `KEY_ESCAPE`.** `pause_menu.gd` and
  `build_manager.gd`'s placement-cancel both checked
  `event.keycode == KEY_ESCAPE` directly. Switched to
  `event.is_action_pressed("ui_cancel")` - Godot's default InputMap already
  binds that action to Escape *and* gamepad East/B, with zero
  `project.godot` edits needed. Same reasoning extends camera pan/zoom in
  `camera_controller.gd`: left-stick pan via direct `Input.get_joy_axis()`
  polling (no InputMap action needed, works with any connected pad) and
  shoulder-button zoom via `InputEventJoypadButton`, sitting alongside the
  existing WASD/mouse-wheel handling rather than replacing it.
- **`grab_focus()` added at every menu open point** (main menu on `_ready`,
  pause menu on `_open()`, settings panel on `show_panel()`, upgrade board
  and build hotbar when toggled visible) - Godot's Button/CheckBox/OptionButton
  controls are focusable and gamepad-navigable (`ui_up`/`ui_down`/`ui_accept`)
  by default, the only missing piece was ever giving them a starting focus.
- **Settings autoload gained `fullscreen`/`resolution_index`/`vsync`**,
  applied via `DisplayServer.window_set_mode/size/vsync_mode`, all guarded
  behind `DisplayServer.get_name() == "headless"` so headless test runs
  don't error calling window APIs that don't exist under the dummy driver.
  Resolution list includes 1280x800 specifically for Steam Deck's native
  panel size.
- **AchievementManager: direct one-line calls at the identified hook point,
  not signal-discovery scanning.** `docs/achievements.md` was written so
  wiring "is connect to an existing signal, not invent new tracking" - the
  cleanest way to honor that for *transient* per-instance nodes (a Tower, an
  Enemy, a Dog) turned out to be a single `AchievementManager.on_x(...)`
  call added right at the spot the doc already named (harvest(), the
  `died.emit()` in enemy.gd/villager.gd, `_on_target_died()` in dog.gd, the
  ammo-consuming branch in tower.gd/trap.gd, `_try_repair()` in ruin.gd,
  `_on_complete()` in construction_site.gd, and the save-load restore loop
  in save_manager.gd). This avoided ever needing a group-scan-and-connect
  discovery pattern (which the codebase does use elsewhere for Area3D-style
  triggers) - every achievement hook here is either that kind of one-liner,
  or a direct autoload-to-autoload signal connect in `_ready()` (Economy,
  Progression, GameState, GameClock are all always-present autoloads).
- **Three achievements intentionally left unimplemented**: Iron Curtain
  (needs a per-night damage tally), Veteran Guard (needs a per-villager
  night-survival counter), Speedrunner (the doc itself flagged this one as
  needing reframing before it's implementable as stated). All three were
  explicitly called out in `docs/achievements.md` as needing their own short
  design pass rather than being invented during this wiring session - that
  caution held up, so they stayed out.
- **`_report_to_steam(id)` is the entire Steamworks integration seam.**
  Everything else in `achievement_manager.gd` (unlock logic, persistence to
  `user://achievements.cfg`, the in-game toast) works identically with or
  without Steam. Didn't attempt GodotSteam/Steamworks wiring itself this
  pass - that needs a Steamworks partner account + App ID and the GodotSteam
  GDExtension binary, none of which exist in this repo/environment, and
  installing them is a real external decision, not a code change.
- **Headless test gotcha, worth remembering:** a throwaway
  `--headless --script` verification script for `AchievementManager` hung
  indefinitely on first attempt - `_initialize()` fired *before* autoloads
  were actually attached to the tree in this engine build (`get_node()` on
  `/root/AchievementManager` errored "outside the active scene tree", then
  every subsequent call silently hung with no more output). Fixed by adding
  `await process_frame` as the very first line of `_initialize()` before
  touching any autoload. Separately, a second false-failure round came from
  `user://achievements.cfg` persisting *between test runs* on real disk -
  achievements unlocked in an earlier run were still `unlocked` at the start
  of the next, breaking "not yet unlocked" assertions. Not a bug, just a
  reminder that local achievement persistence is real disk state, not
  scoped to one process run.
- **`export_presets.cfg` hand-authored, not generated via the Editor GUI**
  (no GUI access in this environment) - validated by actually running
  `--headless --export-debug "Windows Desktop" ...`, which parsed the preset
  correctly and failed *only* on missing export templates (confirms the
  config itself is well-formed, not just superficially plausible). Windows
  Desktop + Linux/X11 presets exist; actual export needs export templates
  installed (Editor > Manage Export Templates, or manually placed under
  `%APPDATA%/Godot/export_templates/4.7.stable/`) which this environment
  doesn't have - a real download step for the user, not something to do
  silently in the background.

---

## Chibi proportion pass (requested after a reference screenshot)

- **Reference-driven, not a guess.** The user supplied a Sketchfab low-poly
  "Blacksmith" character screenshot as the explicit target: big expressive
  head (~35-40% of standing height), chunky simplified limbs/hands, bold
  color blocking, minimal detail - a real comparison point rather than
  vague "make it more readable" direction. Worth remembering the *why*
  the next time this roster gets touched: it's not stylization for its own
  sake, it's specifically about legibility at the game's actual isometric
  camera distance (the previous gallery screenshot made this concrete -
  characters that looked fine as a close-up render read as thin gray/tan
  slivers at in-game zoom).
- **Only mesh geometry changed, not skeletons.** `creature_common.py`'s
  `quadruped_skeleton`/`biped_skeleton` factories (bone positions) were
  left untouched - every `gen_*.py` file's own `blob()`/`cone()`/
  `cylinder()` radius/position arguments were revised instead. This means
  the vertex-weight skinning (nearest-1-2-bones-by-distance, see
  `creature_common.py`'s `_skin()`) automatically adapted to the new
  geometry with zero rigging-code changes, and the idle animation keeps
  working identically. If a future pass wants to change actual body
  *proportions* in the skeletal sense (e.g. genuinely shorter legs, not
  just a bigger head blob), that's a bigger change than this one.
- **Tri counts didn't change** (confirmed identical before/after per
  creature in the Blender export log) - this was pure vertex
  repositioning/rescaling of existing primitives, not added geometry.
- **Collision shapes only retuned where the mismatch was real**, checked
  via headless AABB probes before touching anything: Dog needed a real fix
  (0.34→0.55 tall, a >60% miss), Lurker and Shambler got smaller bumps
  (~0.06-0.08), Villager/Raider/Siege-breaker were left alone (within
  ~0.02-0.06 of their existing capsule, not worth the churn).
- **Headless screenshot testing gotcha, worth remembering:** `--headless`
  uses a dummy rendering driver with no real GPU rasterization - a
  `get_viewport().get_texture().get_image().save_png()` call under
  `--headless` will not produce a meaningful image. Real screenshots need
  Godot run *without* `--headless` (confirmed working: it picks up the
  real Vulkan/GL driver and renders normally, briefly opening a window).
  Same underlying reason as the `MultiMesh.get_instance_transform()` and
  `material_get_instance_shader_parameters` dummy-driver artifacts already
  logged elsewhere in this file.

## Held-tool props per Villager role (follow-up to the chibi pass above)

- **Proportions weren't the actual ask, in the end.** After the chibi
  proportion pass, the user clarified the real target: the reference
  blacksmith reads as "blacksmith" because of the hammer prop + apron +
  gloves - a distinct silhouette element, not just big-head proportions.
  Villager roles only differed by tunic tint before this, which is a much
  weaker signal than a held tool. Worth remembering for any future "make
  it read better" request on this roster: check whether the real gap is
  proportion or a missing distinguishing *prop*, since they look similar
  as complaints but need different fixes.
- **Reused existing `sm_tool_*` static meshes, no new Blender assets.**
  Farmer→`sm_tool_hoe_basic`, Gatherer→`sm_tool_axe_basic`, Guard→
  `sm_tool_sword`. These were built in step 4 (`gen_tools.py`) standing
  upright with the handle along local +Z, origin at the handle base -
  attached as plain sibling nodes under the `Villager` root (NOT nested
  inside the `ModelX` instanced sub-scenes, which would need "editable
  children" to modify from the parent .tscn text) at a fixed offset,
  toggled visible/invisible in lockstep with each role's `ModelX` in
  `_update_model_visibility()`.
- **Tools are not role-tinted.** `CharacterVisualUtils.apply_pack_material`
  only (the plain `day_night.tres`, no `tint_meshes` call) - keeping the
  tool's natural wood/stone/metal coloring makes it pop against the tinted
  tunic instead of blending in, which matters more for at-a-glance reading
  than tonal consistency would.
- Position `(0.22, 0.3or0.55, 0.05)` (Guard's sword sits higher, at 0.55,
  since a sword is shorter than a hoe/axe and would otherwise mostly clip
  into the ground) was reached empirically via screenshot iteration, not
  derived analytically - the exact rotation math for "where is the
  character's hand after the -90 degree creature-facing correction" was
  confusing enough (see the villager/enemy rotation notes elsewhere in
  this project's history) that trial-and-error render checks were faster
  and more reliable than re-deriving it by hand a third time.

## Steam MVP roadmap Phase D (see `docs/roadmap_steam_mvp.md`)

- **Siege-breaker reuses `sk_myconid`**, not a new mesh. It's a middling
  thematic fit (a mushroom humanoid isn't an obvious "siege" silhouette),
  scaled up ~1.4x for a more imposing presence instead - same "known v1
  seam, stats over perfect asset match" tradeoff already accepted for
  Ballista Tower reusing the Watchtower kit. `sk_crawler` was the only other
  unused night creature and fit even worse (a "low swarm bug" reads as
  fast/small, the opposite of a tanky wall-smasher).
- **Difficulty is one multiplier across the whole wave, not per-tunable
  retuning.** `WaveSpawner.DIFFICULTY_MULTIPLIERS = {"easy": 0.7, "normal":
  1.0, "hard": 1.4}` scales the final raider/ranged/brute/siege counts *and*
  `max_enemies_per_night` together, rather than hand-tuning every
  `*_unlock_day`/`*_per_days` pair three times over. Deliberate consequence:
  early nights (small counts, `roundi()` of a small number times 0.7/1.4
  often rounds to the same integer) barely differ between difficulties,
  and the gap only becomes meaningful once counts grow - treated as a
  feature (early game stays consistent/fair across difficulties) not a gap,
  but worth knowing if a future pass wants Easy/Hard to diverge from day 1.
- **`GameState.pending_seed`/`difficulty`, not a new autoload.** Mirrors
  `SaveManager.pending_load` exactly (set before `change_scene_to_file`,
  consumed once by `MapBuilder`/`WaveSpawner` in their own `_ready()`).
  Considered a dedicated `NewGameConfig` autoload but `GameState` already
  owns "state describing the current season" (population cap, win/lose) -
  seed/difficulty are the same kind of thing, just set earlier.

## Terrain day/night material + elevation (requested alongside Phase D)

- **Root cause of "terrain doesn't change at night":** terrain tiles
  (`map_builder.gd`'s `_build_terrain()`) used a flat `StandardMaterial3D`
  with a hardcoded `albedo_color` per biome - it never read the global
  `day_night_ratio` uniform every other asset in the game already responds
  to. Not a regression, just never wired up. Fixed with a new, hand-authored
  `assets/terrain/terrain_day_night.gdshader` (day_color/night_color lerp,
  no textures - terrain tiles are flat-colored boxes, unlike
  `assets/custom_pack/day_night.gdshader` which needs trim-sheet UVs). Kept
  deliberately separate from `assets/custom_pack/` since it isn't part of
  that folder's Blender-generated pipeline.
- **Elevation was computed and immediately discarded.** `MapGenerator`
  already generates a full elevation noise grid and uses it to threshold
  biome placement (water/rock/dirt/grass), then never touches it again -
  the terrain always rendered dead flat regardless of what the noise
  produced. Now used for a **quantized, stepped** height per tile
  (`ELEVATION_STEPS = 3`, `ELEVATION_STEP_HEIGHT = 0.16`), not smooth
  per-tile noise - continuous height at this scale (1-unit tiles, low-poly
  flat-shaded style) would read as noisy/messy rather than "rolling hills."
  Water is deliberately excluded from stepping and stays at a fixed flat
  height - a river/pool surface shouldn't be bumpy the way solid ground can
  be.
- **Villagers/buildings/enemies still spawn at a flat y=0** - unchanged.
  `BuildManager`'s ghost placement raycasts a math `Plane(Vector3.UP, 0.0)`,
  not real terrain height, and entity placement throughout `map_builder.gd`
  goes through `tile_to_world()`, which still returns `y=0.0`. Elevation
  amplitude was kept modest (max relief ~0.5 units across 3 steps)
  specifically so entities sitting at a fixed height next to visually
  stepped terrain doesn't read as floating/sinking. Making entities actually
  conform to terrain height would be a real follow-up (sample elevation at
  each spawn point, offset the *visual* model without touching the
  gameplay-position root so range/distance math stays untouched) but is a
  bigger, riskier change than "terrain has some texture to it" - not done
  here.
- **Headless-testing gotcha, worth remembering:** `MultiMesh.get_instance_transform()`
  reads back as unreliable/zeroed under `--headless`'s dummy rendering
  driver, even though the write side (`set_instance_transform()`) is
  correct and the real game (verified via a normal `Main.tscn` boot, and via
  temporary `print()`s placed directly in `_build_terrain()` rather than
  reading the MultiMesh back afterward) works fine. Same family of issue as
  the `material_get_instance_shader_parameters` dummy-renderer artifact
  noted in an earlier session's asset-swap work - if a future headless test
  needs to *verify* MultiMesh per-instance data, print it at write-time
  inside the real script rather than trying to read it back from outside
  afterward.

## Steam MVP roadmap Phase C slice 1 (see `docs/roadmap_steam_mvp.md`)

- **Ammo attack patterns are a `Tower` export, not an `ammo_type` string switch.**
  `attack_pattern: AttackPattern` (`SINGLE`/`SPLASH`/`SPRAY`) is a separate
  field from `ammo_type` on purpose - reassigning which crop feeds a tower
  should never silently change its attack shape. Ballista's splash is
  deliberately reduced (`splash_damage_multiplier = 0.5`) on secondary hits
  while keeping the primary hit at full damage, specifically so it doesn't
  become a strictly-better Watchtower-plus-AoE at the same ammo cost - a
  repeat-cast tower's splash needed toning down where Spike Trap's (one-shot,
  consumed either way) didn't. Sling Post's SPRAY hits the nearest N
  (`spray_max_targets`, distance-sorted) rather than all-in-range unbounded -
  without the cap, a wave bunched at a chokepoint (which `wave_spawner.gd`'s
  spawn-ring + `enemy.gd`'s straight-line chase toward one target reliably
  produces) would get shredded by the cheapest, fastest-to-unlock building in
  the game for a single ammo per volley.
- **Chicken alarm + Goose spec deviation, intentional.** `game-master-spec.md`
  §5.3 splits this into a loud Goose (alerts) and a subtler Chicken (a
  quieter day-time "something's off" tell) as two separate animals. No
  `sk_goose` mesh exists in the custom pack (only `sk_chicken`/`sk_cow`/
  `sk_dog`, plus unused `sk_sheep`/`sk_goat`). Merged both roles into one
  loud Chicken alarm for v1 rather than blocking on a new asset-pack mesh -
  sheep/goat/goose are good candidates if this system gets revisited.
- **Dog must be a child of `AnimalPen`, not a sibling under `Entities`.**
  `SaveManager._apply()` frees every node in `"player_buildings"` (which
  includes `AnimalPen`) and re-instantiates from saved data, which re-runs
  `_ready()` and spawns a *new* Dog - but a Dog added as a loose sibling
  belongs to no group `_apply()` iterates, so the *old* one is never freed.
  Every save/reload would otherwise leak one more permanently-fighting
  orphaned Dog. Parenting Dog directly under `AnimalPen` (`add_child(dog)` on
  `self`) ties its lifecycle to the pen's automatically - freed on both the
  pen's combat death and any save/reload, no extra bookkeeping. Confirmed via
  a headless test that repeated save/reload holds at exactly 1 dog, not N.
  Also: `dog.position` must be set *before* `add_child()`, since Dog's own
  `_ready()` reads `global_position` synchronously during `add_child()` -
  same ordering gotcha already documented below for Ruin rewards.
- **`AnimalPen`'s alarm trigger is a Timer + group-scan, not an `Area3D`.**
  Originally built as an `Area3D` nested under `AnimalPen`'s `StaticBody3D`
  (mirroring `Trap`'s own working `Area3D` pattern). It never fired:
  `get_overlapping_bodies()` stayed empty despite `PhysicsServer3D`-level
  inspection confirming the shape was registered with the correct mask
  (`4`), radius, and identity transform. An *identical* `Area3D` added to the
  same `AnimalPen` node at runtime (not via the scene file) worked
  immediately, and a from-scratch minimal repro (bare `StaticBody3D` + child
  `Area3D`, built entirely in code) also worked - so it isn't "Area3D under
  StaticBody3D" in general, only this specific scene-file-loaded node.
  Root cause not identified after a genuine debugging attempt (several
  isolated repros, `PhysicsServer3D.area_get_shape_count()` checks, disabled
  flag checks). Rather than keep fighting an unexplained engine-level quirk,
  switched to the same "scan `get_tree().get_nodes_in_group("enemies")` on a
  Timer" pattern `tower.gd` and `dog.gd` already use successfully - simpler,
  proven, and sidesteps the mystery entirely. If a future `Area3D` on a
  `StaticBody3D`-derived `Building` subclass mysteriously doesn't detect
  overlaps, this is a known unresolved trap - try the group-scan pattern
  first before assuming your own new code is at fault.
- **Duplicate-signal-connection bug #2, different shape than the Phase A one.**
  `Building._ready()` already does
  `if not passive_resource_output.is_empty(): GameClock.day_started.connect(_on_day_started)`.
  `AnimalPen` overrides `_on_day_started` (to also reset the alarm flag) *and*
  originally also called `GameClock.day_started.connect(_on_day_started)`
  itself in its own `_ready()` - since GDScript virtual dispatch means both
  connect calls resolve to the same overridden method, this is a duplicate
  connection to the identical signal + callable, which Godot rejects.  Fix:
  don't re-connect at all - call `super._on_day_started(day_count)` from the
  override and rely on the one connection `Building._ready()` already made.
  Any `Building` subclass overriding `_on_day_started` needs this same
  pattern, not a fresh `connect()` call.

## Steam MVP roadmap Phase A fixes (see `docs/roadmap_steam_mvp.md`)

- **The save/seed gap noted below (see "Known pre-existing gap") is fixed.**
  `SaveManager.peek_saved_seed()` reads just the seed out of the save file
  synchronously; `MapBuilder._ready()` calls it when `SaveManager.pending_load`
  is true, before the deferred `load_game()` call (which restores everything
  *else*) ever runs. This works because `day_night_cycle.gd`'s `_ready()` -
  which resets `pending_load` to false and schedules the deferred load - lives
  on the *root* `Main` node, and Godot calls children's `_ready()` (including
  `MapBuilder`, a child of `Main`) before the parent's. If `day_night_cycle.gd`
  ever moves off the scene root, re-verify this ordering assumption.
- **Bullets (Pea) now has a consumer**: a new `Sling Post` building
  (cheap/fast/short-range, `tower.gd` reused, `sm_watchtower_base` reused
  without the platform for a visually "smaller" post). Intentionally
  weaker-per-hit than Watchtower/Ballista rather than a strict upgrade, so it
  reads as an anti-swarm pick, not a better tower.
- **Found (not part of the original bug list) while bug-bashing**: `enemy.gd`'s
  `_on_attack_range_body_exited` didn't disconnect the `died` signal it
  connected on entry, so a target walking out of range and back in later
  (without dying) hit Godot's duplicate-connection error. Fixed by mirroring
  `villager.gd`'s already-correct Guard-side pattern (`is_connected()` check
  before disconnecting). Worth grepping for the same "connect on enter, no
  matching disconnect on exit" shape if similar range-trigger code is added
  later - it won't `push_error` or crash, just quietly leak connections until
  the exact repro path above traps on the same target instance.

## Ammo/crop system (cards #16, #10)

- **Crop selection is automatic, not player-chosen.** `FarmPlot.plant()` with no
  argument (called by both the Farmer AI and a player's own click) auto-cycles
  through `available_crops` in order (Pumpkin -> Carrot -> Tomato -> Pea -> repeat).
  There is no per-plot "choose a crop" UI. If per-plot choice is ever wanted,
  `plant(crop: CropDef)` already accepts an explicit crop - only the UI to call it
  with a specific choice is missing.
- **Crop -> ammo mapping:** Pumpkin -> cannonballs, Carrot -> darts, Tomato ->
  grenades, Pea -> bullets (`crops/*.tres`). No dedicated art exists for these, so
  `FarmPlot` reuses the corn `Sprite3D` shape and tints it per-crop via `modulate`
  rather than swapping textures.
- **Ammo consumption is per-shot, not per-second.** `Tower.ammo_type`/`ammo_cost`:
  if the ammo type is set and unaffordable, the tower simply skips that attack
  cycle (no target search wasted... it still searches, but does not fire or
  spend ammo). `Trap.ammo_type`: an unloaded trap is a "dud" - `body_entered` only
  fires once per entry, so an enemy that walks over a dud trap takes no damage
  and the trap stays armed for next time (does not consume itself).
- **Defense -> ammo mapping:** Watchtower -> darts, Ballista Tower -> cannonballs,
  Spike Trap -> grenades. **Bullets (Pea) have no consumer yet** - there are only
  3 existing defense types against 4 crop types. Don't force bullets onto an
  ill-fitting consumer; a future fast-firing/cheap defense is the natural home.
- **Known gap:** ammo counts are not shown anywhere in the persistent HUD.
  Harvesting a crop posts a one-off `NotificationManager` toast as the only
  current feedback. If this matters, it's a HUD follow-up (`hud.gd` already has
  the icon-chip pattern from card #19 to extend).
- `Economy`'s `storage_caps` default dict was refactored into
  `_default_storage_caps()` (built from `STARTING_RESOURCES.keys()`) specifically
  because the old code had two independently-hand-written copies of the same
  dict (the `var` default and `reset()`) that had already silently drifted out of
  sync once ammo types were added - don't reintroduce a third hand-written copy
  if adding more resource types later.

## Wall/fence/chokepoint assets (cards #14, #17, #18)

- **Chose to stay in the wood/village aesthetic rather than pull in KayKit Dungeon
  Remastered's stone wall set**, even though Dungeon Remastered has a much
  richer wall variety (straight/corner/broken/cracked/arched/gated). Medieval
  Hexagon Pack has no thicker wood wall variant than what was already in use, so
  `Wall`/`Fence` were recomposed as gray-box log primitives (matching the
  established Tree/Rock/BerryBush "no fitting asset exists" convention) instead
  of switching packs. Reuse this reasoning if another "asset looks wrong" ticket
  comes in for a wood-themed structure - check Medieval Hexagon Pack thoroughly
  before reaching for Dungeon Remastered, which reads as a different game's style.
- **`Gate` (`scenes/gate.tscn`) was deliberately left untouched** - neither #17 nor
  #18 named it, so it still uses the original `fence_wood_straight_gate.gltf`
  plank model. It will look visually inconsistent next to the new log-style
  Wall/Fence until someone explicitly asks for it.
- Chokepoint fence orientation (`MapBuilder._dress_chokepoints()`) now checks
  which axis the natural rock/water terrain actually pinches on and orients the
  fence row to match, instead of always laying out along X. **Side finding:**
  sampling 20+ random seeds, every chokepoint came back "pinched east/west,"
  never "pinched north/south" - `MapGenerator`'s elevation noise may have an
  unintended directional bias producing vertically-elongated water/rock bands
  rather than isotropic blobs. Not investigated further (out of scope for the
  fence-orientation ticket) - worth a look if map shape variety matters.

## Resource gathering & world interaction (cards #13, #20)

- **Only a Gatherer villager's AI can harvest a resource node.** Player
  left-click-to-gather was removed entirely from `resource_node.gd`
  (Tree/Rock/HayBale/BerryBush/FishingSpot) - collection is a role-assignment
  decision, not a direct player action. `FarmPlot`'s click-to-plant/harvest was
  **deliberately left untouched** (not requested, not a "resource" node) - if
  consistency is wanted later, that's a separate, explicit decision to make.
- Hover tooltips (`WorldTooltip`) reuse `mouse_entered`/`mouse_exited` on the same
  `CollisionObject3D`, gated by `input_ray_pickable`. This is the same physics-picking
  flag `input_event` uses, so re-enabling it for hover **does not** reintroduce
  click-to-gather as long as `input_event` itself stays disconnected - keep those
  two concerns mentally separate if touching this again.

## Ruins/repair mechanic (card #22)

- Repairing a ruin grants a **fully functioning building for free**, not a
  resource payout or a passive perk (a fatter, more literal reading of "gain
  something from it"). A ruin is rendered as its own reward building's model,
  ghost-tinted via the same `CharacterVisualUtils.apply_ghost_tint()` BuildManager
  already uses for placement previews - so it previews what repairing it
  produces, with no new "ruined" art needed.
- Flat repair cost (50 wood + 50 stone) regardless of which of the 3 reward
  types (Watchtower/House/Storehouse) gets assigned - simpler than scaling cost
  to the reward's own `resource_cost`, at the expense of a Storehouse "deal"
  feeling better than a Watchtower one. Revisit if that imbalance matters.
- Ruins are rare and far from home on purpose (max 2 per map, >= 10 tiles from
  the homestead) - an exploration reward, not something reachable turtling at
  spawn.
- **Ordering gotcha to remember:** a node's exported properties must be set
  *before* `add_child()`, not after, if `_ready()` reads them - `_ready()` runs
  synchronously during `add_child()`. This bit `Ruin.reward_def` during
  verification (the ghost model silently came out empty because `_ready()` ran
  before `reward_def` was assigned) and is an easy trap to hit again with any
  future spawner code that configures-then-adds a scene instance.

## Tutorial (card #8)

- The opt-in tutorial prompt only fires from **New Game**, never **Continue**
  (`SaveManager.show_tutorial_prompt`, set in `main_menu.gd`). Returning players
  loading a save never see it, by design.

## Wave composition (cards #2, #9)

- Enemy spawn positions are randomized (angle + distance ring around the home
  base, `WaveSpawner._pick_spawn_position()`) instead of a fixed marker, with a
  wall-clearance check so raiders don't spawn stuck inside player defenses.
- Per-night enemy cap trims **weakest type first**: plain Raiders, then Ranged
  Raiders, then Brutes last. Keep this order if a 4th enemy tier is ever added -
  it's what keeps late-game waves reading as "harder," not just "more of
  everything capped arbitrarily."
- Ranged Raider needed **zero changes** to `enemy.gd` - it's purely a bigger
  `AttackRange` radius on a new scene. If another "ranged" unit variant is
  wanted, this is the pattern: enemy.gd already stops and fights whatever first
  enters its AttackRange, melee or not.

## UI visual language (cards #4, #19)

- The build hotbar (`build_menu.gd`) and the resource HUD (`hud.gd`) intentionally
  share the same category color palette and the same "runtime-generated flat
  `ImageTexture` as an icon" technique, since no real per-item icon art exists for
  either buildings or resources. If real icon art ever arrives, both call sites
  need updating together to stay consistent.
- `build_menu.gd`'s hotkey range is **dynamic** (`KEY_1` through
  `KEY_1 + building_defs.size() - 1`), not hardcoded to 1-7/1-8. Adding a new
  BuildingDef to the array just works; no script change needed for the hotkey
  itself.

## Known pre-existing gap (found, not fixed at the time - RESOLVED, see "Steam MVP roadmap Phase A fixes" above)

- `SaveManager.load_game()` restores `GameClock`/`Economy`/villagers/buildings,
  but never feeds the saved seed back into `MapBuilder.seed_override` - and by
  the time a deferred `load_game()` call runs, `MapBuilder._ready()` has already
  generated a **new random map**, not the saved one. The save-game comment
  claims the map "reproduces identical terrain... on load" via the saved
  seed, but nothing currently wires that seed back in before generation
  happens. Not touched during this session (unrelated to the tickets worked),
  but worth its own ticket if map consistency across save/load matters.
