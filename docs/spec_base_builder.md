# System: Base Builder (AoE-style, Homesteading Theme)

## Purpose
Defines the base-building and economy layer of the game. Player-managed structures generate resources, house population, and defend the homestead during night raids. This system consumes map data produced by the Procedural Map Generation system (see `spec_procedural_maps.md`) and reuses its validation logic for runtime placement checks.

## Design intent
- AoE-style economy: gather → spend resources → construct buildings → unlock capability.
- Homesteading theme: buildings are farm/homestead structures, not military-fantasy structures.
- Day/night loop: buildings behave differently in build/farm phase (day) vs raid/defense phase (night).
- Reuse, don't duplicate: placement validation reuses the same buildable-core, chokepoint, and zone-overlap logic already defined in the map generation system, applied per-tile at runtime instead of full-map validation.

## Placement model
- **Grid-snapped placement**, not free placement. Uses the same tile grid the map generator outputs.
- Buildings occupy an N×N tile footprint (defined per building).
- Placement legality check (runtime, per-tile, lightweight — not full map regen validation):
  1. Tile(s) are within `biomes` marked buildable (`grass`/`dirt`).
  2. Tile(s) are unoccupied (no existing building).
  3. Tile(s) do not overlap a locked `crop_plot` or `animal_zone` from generation data, unless the building type is explicitly a farm/pen structure meant to occupy that zone type.
  4. Defense structures (walls/towers/traps) get a bonus/priority flag if placed on tiles listed in `chokepoints` from the generated map — this is a suggestion weight for the player/AI, not a hard requirement.

## Building categories and asset mapping

| Category | Source asset pack | Footprint role | Gameplay role |
|---|---|---|---|
| Core / House | KayKit Medieval Hexagon Pack | 2x2 or 3x3 | Population cap, respawn/spawn point |
| Farm plots | Farming pack w/ crop growth stages | 1x1 per plot | Resource economy, feeds crop-to-defense conversion |
| Walls / chokepoint structures | Hexagon Pack + Dungeon Pack props | 1xN linear | Funnels raiders into flagged chokepoint tiles |
| Defense towers / traps | KayKit Platformer Pack (traps) + Fantasy Weapons Bits | 1x1 or 2x2 | Night-phase raid defense |
| Storage / Barn | KayKit City Builder Bits | 2x2 | Increases resource storage cap |
| Animal pens | Kenney Animal Pack Redux + LowPoly Animated Farm Animal Pack | 2x2 or 3x3 | Passive resource generation (eggs, wool, milk) |

Style note: KayKit packs share a consistent gradient-atlas low-poly look; mixing Kenney/OpenGameArt animal assets alongside them is the one deliberate style seam and may need a shared post-process/shader pass to visually unify (see Open Questions).

## Data structure: BuildingDef (Resource)
Mirrors the `MapTheme` resource pattern — one `.tres` file per building type, no code changes needed to add new buildings.

Fields:
- `building_name: String`
- `category: String` (core, farm, wall, defense, storage, pen)
- `footprint_size: Vector2i`
- `resource_cost: Dictionary` (resource id -> amount)
- `build_time_seconds: float`
- `scene: PackedScene` (final visual)
- `construction_scene: PackedScene` (optional in-progress visual, or scale-in fallback)
- `population_cap_bonus: int` (Houses)
- `storage_cap_bonus: Dictionary` (Storage)
- `defense_stats: Dictionary` (damage, range, radius — Defense structures only)
- `passive_resource_output: Dictionary` (Pens/Farms — resource id -> rate)
- `chokepoint_priority_bonus: float` (used only for UI/AI suggestion weighting, not hard placement rule)

## Construction & economy loop
1. Gathering units collect from `resources` nodes placed by the map generator.
2. Player spends resources to place a "ghost"/translucent building preview on a valid grid cell (validated per placement model above).
3. Construction timer runs (`build_time_seconds`); optionally show `construction_scene` or a scaled-in version of `scene`.
4. On completion, building becomes functional: contributes population cap, storage cap, passive resource output, or defense capability depending on category.

## Day/night state behavior
**Day (build/farm phase):**
- Farms active and harvestable.
- Construction and movement unrestricted.
- Villager pathing open across buildable tiles.

**Night (raid/defense phase):**
- Walls/towers/traps become active (engage raiders).
- Crops become vulnerable — raid objective can include crop destruction, which is the direct link to the crop-to-defense conversion mechanic (see master spec's core loop section).
- Consider disabling new construction during night, or allow only emergency/cheap defense placement — TBD, see Open Questions.

## Progression model
Instead of new building categories per tier (which would require new asset packs), progression reuses the **same building slots with upgraded stats/visual scale**:
- Tier 1: "Homestead" — base versions of all categories.
- Tier 2: "Established Farm" — improved farm yield, stronger walls, more storage.
- Tier 3: "Fortified Farmstead" — best defense stats, largest population/storage caps.

This keeps art budget contained: reuse existing KayKit/Kenney assets with recoloring, scaling, or additive prop-stacking (e.g., adding a second wall-prop layer) rather than sourcing new packs per tier.

## Integration points with other systems
- **Map Generation (`spec_procedural_maps.md`)**: base builder consumes `biomes`, `resources`, `crop_plots`, `chokepoints`, `animal_zones` from generated map data. Do not duplicate validation logic — call into the same validator utilities for per-tile runtime checks.
- **Crop-to-defense conversion (master spec core loop)**: farm output during day phase feeds into defense capability/resources usable at night — exact conversion ratio TBD in master spec, not redefined here.

## Open questions / TBD
- Exact resource cost/build-time balancing (needs playtesting).
- Whether construction is fully disabled at night or allowed at a penalty/cost premium.
- Whether chokepoint placement bonus should ever become a hard requirement (e.g., walls only buildable on flagged tiles) vs. remaining a soft suggestion.
- Shared shader/post-process pass to unify KayKit assets with non-KayKit animal assets (Kenney/OpenGameArt) so animal pens don't visually clash with the rest of the base.
- Population cap formula and starting values.
- How AI/pathing for gathering units should be implemented (separate system, not covered here).
