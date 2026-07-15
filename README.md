# Homestead Defense (working title)

Low-poly homesteading city defense game. Design spec: [docs/game-master-spec.md](docs/game-master-spec.md).

## Requirements

- [Godot 4.3+](https://godotengine.org/download)

## Running

Open this folder as a project in the Godot editor (`Project > Import`, select this directory's `project.godot`), then press Play (F5). Boots to a main menu (New Game / Continue / Settings / Quit) rather than straight into gameplay.

## Status

**Phase 0 - Scaffolding** (per the spec's Build Phases): done.

**Phase 1 - Core Loop Skeleton (gray-box)**: done.
- [x] Place-a-building system (toggle placement, click to place a wall)
- [x] Resource counter (wood/food) that ticks up from clicking gray-box trees/farm plots
- [x] One enemy type that spawns at night and walks toward the home base
- [x] Wall that can be destroyed by that enemy
- [x] You can build a box wall, survive one wave, and lose resources if it falls

**Phase 2 - Farming & Gathering Depth**: done.
- [x] Farm plots with real plant/grow/harvest states (ready after a day/night cycle)
- [x] A third resource type, stone, gathered from rocks
- [x] Villagers with simple assignable AI (Farmer/Gatherer roles, autonomous search-walk-work loop)
- [x] The day half of the loop is a small mini-game on its own: manage plots, gather materials, assign villagers

**Phase 3 - Defense Depth**: done.
- [x] Two enemy types: fast/fragile Raiders and slow/tanky Brutes (unlocked from day 4), same script, different stats
- [x] A Trap building: one-shot ambush damage (kills a Raider outright, only wounds a Brute), doesn't block movement, costs stone
- [x] Guard is a new Villager role: guards proactively hunt enemies and fight them with real HP on both sides, competing with Farmer/Gatherer for the same villager pool
- [x] Wave escalation: more Raiders over time, Brutes join from day 4 onward
- [x] The night half now has real decisions: intercept early (risk your guard) vs. let a wall/trap take the hit, and who to spare from farming to fight

**Phase 4 - Art Pass**: done (for the assets available so far).
- [x] Villagers and Enemies use real rigged KayKit character models (Mage/Ranger/Rogue/Knight per villager role, Rogue_Hooded/Barbarian for Raider/Brute) instead of solid-color capsules, each posed with a static idle animation frame
- [x] Walls and FarmPlots use real Kenney isometric sprite art (billboarded, always facing the camera) instead of solid-color boxes
- [x] Trees and Rocks are still gray-box (no matching assets in the sourced packs) but recomposed into more recognizable multi-part shapes instead of a single solid box; the Trap keeps its primitive shape but gained an emissive warning glow
- [x] Lighting/mood pass: ambient occlusion, subtle fog, glow/bloom, filmic tonemapping, and the Ground finally has an actual material instead of Godot's default gray
- [ ] No walk-cycle/attack/death animation yet — deliberately descoped, see `docs/CREDITS.md` context and the code comments in `scripts/character_visual_utils.gd`

**Phase 5 - Progression & Content**: done.
- [x] A 20-day season with a real win/lose arc: survive 20 nights to win; the Homestead (100 HP) takes damage from every raid that lands, and the run ends if it falls
- [x] Unlock board (press `T`): Sharpened Tools (gather x2), Reinforced Walls (120 HP, cross-braced), Veteran Training (+HP/+damage/faster work for all villagers), Heavy Traps (double damage), and repeatable Recruit Villager (population growth / death recovery)
- [x] Tiers per the spec: tools (gather multiplier), buildings (wood wall -> reinforced wall), villagers (untrained -> veteran)
- [x] Balance pass: gentler wave curve (brutes from day 6) with a per-night cap, tuned against a fully-upgraded homestead
- [x] End screen with restart (fully resets clock/resources/upgrades)

**Map pass**: done.
- [x] Destructible fences/gates, gatherable hay bales, decorative props
- [x] Camera pan (WASD/arrows) and zoom (mouse wheel), clamped to the map

**Procedural maps v1 — River Valley** (spec: [docs/spec_procedural_maps.md](docs/spec_procedural_maps.md)): done.
- [x] Every session generates a fresh 64x64 map from the data-driven `themes/river_valley.tres` theme: noise elevation/moisture, biome thresholds that keep rivers and rocky ridges contiguous, seeded + deterministic (session seed printed to console), validated for playability (contiguous buildable core, water present, chokepoints) with retry + pre-verified fallback seed
- [x] The map builder realizes the data in-scene: biome terrain tiles, ~50 trees / 20 rocks / 10 hay / 18 farm plots with spacing rules, old fence lines dressing the chokepoints, prop scatter, and the homestead/villagers/enemy-spawn placed onto the generated buildable core
- [x] Known v1 limits: water is a shallow, wadeable river (real movement blocking arrives with navmesh pathfinding later); animal zones are generated but unused until livestock exists

**Base Builder v1** (spec: [docs/spec_base_builder.md](docs/spec_base_builder.md)): done.
- [x] Data-driven `BuildingDef` resources (`buildings/*.tres`, seven so far: Wall, Spike Trap, Watchtower, Farm Plot, House, Storehouse, Animal Pen) drive a rewritten `BuildManager` — grid-snapped ghost placement on the procedural map's own tile grid, per-tile legality reusing `MapValidator`'s rules (buildable biome, unoccupied, crop-plot/animal-zone reservation) via a new lightweight `PlacementGrid`, translucent green/red/gold ghost tinting (gold = chokepoint bonus or fertile/pasture zone bonus), R to rotate, a build palette (`B` to open, `1`-`7` to quick-select)
- [x] Construction takes real time: a scaffolding `ConstructionSite` (attackable — a raid can interrupt a build and free the tile) scales in, then swaps for the finished building
- [x] Building categories now do something: House raises the population cap (recruiting is gated on it — build houses before recruiting), Storehouse raises every resource's storage cap, Animal Pen pays out food at dawn (bonus on generated animal-zone tiles), Watchtower auto-fires on nearby enemies (bonus range on chokepoint tiles). Wall/Spike Trap reuse their existing scripts unchanged
- [x] Visual unification pass: Wall/Fence/Gate/Homestead swapped from 2D sprites to real KayKit Medieval Hexagon 3D models; the Spike Trap uses a KayKit Dungeon Remastered model
- [x] Known v1 seam: the Animal Pen's livestock billboard uses Kenney's Animal Pack Remastered, which is icon/badge-style art (a round backing behind each animal) rather than the loose in-scene sprite style the rest of the game uses — it visually reads as a sticker. Flagged in the spec itself as an open question (a shared shader pass to unify KayKit and non-KayKit art), not fixed here
- [x] Deferred per spec TBDs: night construction lockout (construction stays allowed at night), crop-destruction raid objectives, weapon-bits garrison props

**Phase 6 — Polish & Ship Prep** (UI/UX + save/load; sound/music deliberately not done, see below): done.
- [x] A single `themes/ui_theme.tres` Theme (set as the project's global theme) reskins every panel — HUD, villager panel, upgrade board, build menu, end screen — at once, in the game's earthy palette, with zero per-scene changes
- [x] A main menu (New Game / Continue / Settings / Quit — Continue only enabled when a save exists) is now the game's actual entry point, and an in-game pause menu (`Escape`) adds Save/Load/Settings/Restart Season/Quit to Main Menu/Quit Game — `Escape` correctly defers to canceling an in-progress build placement first if one is active
- [x] Save/Load (`user://savegame.json`, human-readable): preserves season progress (day, resources + storage caps, purchased upgrades, population cap), the Homestead's HP, every villager (position/role/HP), and every player-built structure (type/position/rotation/HP). The map itself isn't saved tile-by-tile — `MapGenerator` is deterministic, so saving the theme+seed reproduces identical terrain/tree/rock/farm-plot *positions* on load
- [x] **Known v1 limitation**, stated plainly rather than hidden: loading does *not* preserve map-generated resource-node/farm-plot growth state (they come back fresh) or any enemies mid-raid (a wave in progress when you save gets a pass until the next natural dusk, since `night_started` fires on a live phase *transition* that a direct state-restore doesn't replay)
- [x] A `Settings` autoload with a working master-volume slider/mute wired to the real `Master` audio bus, and a toast-notification system (upgrade purchases, "the Homestead is under attack", failed-placement reasons) plus a brief red screen-flash on Homestead damage — small feedback gaps that were silent before
- [ ] **Sound/music: not done.** No audio assets exist in this repo and none were generated — the volume/mute plumbing above is real and ready, but there is currently nothing for it to play. Source audio assets to close this out
- [ ] **Playtesting feedback loop**: needs an actual human playing it, which is exactly what this phase's menu/pause/save-resume shell now makes possible to do in more than one sitting

See [docs/CREDITS.md](docs/CREDITS.md) for third-party asset attribution.

Controls: left-click a Tree/Rock to gather, or a FarmPlot to plant/harvest; click a Villager to select it, then click Farmer/Gatherer/Guard in the bottom-left panel to assign a role; press `B` for the build menu, `1`-`7` to select a building, move the mouse to position the ghost, `R` to rotate, left-click to place, right-click/`Escape` to cancel; press `T` for the upgrade board; press `Escape` to pause (Save/Load/Settings/Restart/Quit). Survive 20 nights without losing the Homestead to win the season.
