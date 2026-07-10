# Homestead Defense (working title)

Low-poly homesteading city defense game. Design spec: [docs/game-master-spec.md](docs/game-master-spec.md).

## Requirements

- [Godot 4.3+](https://godotengine.org/download)

## Running

Open this folder as a project in the Godot editor (`Project > Import`, select this directory's `project.godot`), then press Play (F5). The main scene runs a day/night cycle: sky color, sun angle, and sun color shift over a 60-second cycle so a full day is visible in about a minute.

## Status

**Phase 0 - Scaffolding** (per the spec's Build Phases): done.

**Phase 1 - Core Loop Skeleton (gray-box)**: done.
- [x] Place-a-building system (press `B` to toggle placement, click to place a wall)
- [x] Resource counter (wood/food) that ticks up from clicking gray-box trees/farm plots
- [x] One enemy type that spawns at night and walks toward the home base
- [x] Wall that can be destroyed by that enemy
- [x] You can build a box wall, survive one wave, and lose resources if it falls

Controls: left-click a Tree/FarmPlot to gather; press `B` to toggle wall-placement mode, move the mouse to position the ghost, left-click to place (costs 10 wood).
