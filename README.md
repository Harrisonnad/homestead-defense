# Homestead Defense (working title)

Low-poly homesteading city defense game. Design spec: [docs/game-master-spec.md](docs/game-master-spec.md).

## Requirements

- [Godot 4.3+](https://godotengine.org/download)

## Running

Open this folder as a project in the Godot editor (`Project > Import`, select this directory's `project.godot`), then press Play (F5). The main scene runs a day/night cycle: sky color, sun angle, and sun color shift over a 60-second cycle so a full day is visible in about a minute.

## Status

**Phase 0 - Scaffolding** (per the spec's Build Phases):
- [x] Repo + base 3D scene, camera, ground plane
- [x] Day/night cycle timer running end-to-end
- [ ] Everything else (Phase 1+)
