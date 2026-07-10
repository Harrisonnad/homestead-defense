# Homestead Defense (working title)

Low-poly homesteading city defense game. Design spec: [docs/game-master-spec.md](docs/game-master-spec.md).

## Requirements

- [Godot 4.3+](https://godotengine.org/download)

## Running

Open this folder as a project in the Godot editor (`Project > Import`, select this directory's `project.godot`), then press Play (F5). The main scene runs a day/night cycle: sky color, sun angle, and sun color shift over a 60-second cycle so a full day is visible in about a minute.

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

Controls: left-click a Tree/Rock to gather, or a FarmPlot to plant/harvest; click a Villager to select it, then click Farmer/Gatherer/Guard in the bottom-left panel to assign a role; press `1` to toggle wall-placement mode or `2` for trap-placement mode, move the mouse to position the ghost, left-click to place (wall costs 10 wood, trap costs 8 stone).
