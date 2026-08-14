# Achievement List (design doc)

Design-only, per `docs/roadmap_steam_mvp.md`'s Phase D — actual Steamworks integration (achievement unlock calls, icons, store-page config) is Phase E's job once GodotSteam or equivalent is wired in. This doc exists so that work has a concrete list to implement against instead of starting from a blank page, and so achievement *design* (what's worth rewarding) gets thought through separately from achievement *plumbing*.

Each entry lists the trigger condition in terms of signals/state that already exist in the codebase, so wiring this up later is "connect to an existing signal," not "invent new tracking." Where no signal exists yet, that's called out explicitly.

---

## Milestones (first-time-only, story-of-a-playthrough beats)

| Achievement | Trigger | Notes |
|---|---|---|
| **Homesteader** | First building of any kind completed (`ConstructionSite.completed` fires once) | The very first "you built something" beat |
| **Green Thumb** | First crop harvested (`FarmPlot.harvest()` succeeds) | |
| **Full House** | First House built (`population_cap_changed` fires from a House's bonus) | |
| **Warm Bodies** | Population cap reached (`GameState.current_population() >= GameState.population_cap`) | Needs a check on `Recruit Villager` purchase or villager count change - no dedicated signal yet, would poll on `population_cap_changed`/villager spawn |
| **Stockpiled** | Any resource reaches its storage cap (`Economy.storage_caps`) | |
| **Menagerie** | First Animal Pen built | |
| **Best Friend** | The Dog survives its first full night (a wave starts and ends with the Dog still alive) | No existing signal for "wave ended" per dog - `GameClock.day_started` after a night with an active Dog is the cheapest hook |
| **Ruin Runner** | First ruin repaired (`Ruin`'s reward-granting path) | |
| **Fully Upgraded** | All 6 unlock-board upgrades purchased (`Progression.purchased.size() == Progression.UPGRADES.size()`, accounting for the repeatable `recruit_villager` not counting twice) | |

## Building & defense variety

| Achievement | Trigger | Notes |
|---|---|---|
| **Jack of All Trades** | All 13 `BuildingDef`s placed at least once in one playthrough | Track placed `building_def_path`s in a set, check size against `BuildManager.building_defs.size()` (`TOTAL_BUILDING_DEFS` in `achievement_manager.gd`) |
| **Master Farmer** | All 6 `CropDef`s harvested at least once in one playthrough | Same set-tracking pattern as Jack of All Trades - `_crops_harvested` keyed by `crop_name`, checked against `TOTAL_CROP_TYPES` in `achievement_manager.gd`. `FarmPlot.harvest()` now passes `current_crop.crop_name` into `on_crop_harvested()` |
| **Arsenal** | All 4 ammo types (darts/cannonballs/grenades/bullets) fired at least once | Hook `Tower`/`Trap`'s ammo-consuming branch |
| **Splash Zone** | A single Ballista Tower or Spike Trap shot damages 3+ enemies at once | `Tower.AttackPattern.SPLASH`/`Trap.splash_radius` path - count hits in one trigger |
| **Spray and Pray** | A single Sling Post volley hits its full `spray_max_targets` cap | |
| **Iron Curtain** | Wall tier >= 2 (Age 2+) *and* a raid ends with zero Homestead damage that night | **Implemented** - `NightReport` (scripts/autoload/night_report.gd) provides the per-night damage tally |

## Combat & survival

| Achievement | Trigger | Notes |
|---|---|---|
| **First Blood** | First enemy killed (any `Enemy.died` signal) | |
| **Wall Breaker's Bane** | A Siege-breaker killed before it reaches the Homestead | Hook `Enemy.died` filtered to the Siege-breaker scene/creature_name |
| **Guard Dog** | The Dog (`scripts/dog.gd`) kills an enemy | `Dog`'s `current_target.take_damage` path already knows when a kill happens via the target's own `died` signal |
| **Early Warning** | The Animal Pen's chicken alarm fires for the first time | `AnimalPen._on_alarm_timer_timeout` |
| **Nail-Biter** | Survive a night where the Homestead ends below 10% HP | Check `homestead.current_health` vs `max_health` at `day_started` |
| **Veteran Guard** | Veteran Training purchased *and* a Guard villager survives 5+ nights afterward | **Implemented** - per-villager night-survival counter lives on `villager.gd` itself |
| **Season Survivor** | Win the season (`GameState.game_ended(true, ...)`) | The base "you won" achievement |
| **Iron Homestead** | Win the season without the Homestead ever dropping below 50% HP | Needs a running minimum-HP tracker across the season |
| **Hard Mode Champion** | Win the season with `GameState.difficulty == "hard"` | Cheap to check at `game_ended` |
| **Flawless** | Win the season without losing a single villager (no `Villager.died` ever fired) | |

## Fun / secret (reward specific playstyles, not just progress)

| Achievement | Trigger | Notes |
|---|---|---|
| **Pacifist Farmer** | Win the season having built zero Wall/Fence/Gate/Spike Trap/Watchtower/Ballista/Sling Post (defense-category buildings) - survive on Guards/Dog/terrain alone | Filter placed buildings by `category == "defense"` (or `"wall"`) |
| **No Turrets Needed** | Win the season having built zero Tower-type buildings (Watchtower/Ballista/Sling Post) specifically, relying on Traps/Guards/Dog instead | |
| **Ruin Hoarder** | Repair both ruins in a single season (`MapBuilder.MAX_RUINS == 2`) | |
| **Speedrunner** | Win the season with time left over - no real "time left" concept exists (season length is fixed at 20 days), so this would need reframing, e.g. "win by day 20 with the Homestead never below 90% HP" instead | Needs design rework before it's implementable as stated |
| **Custom Cartographer** | Start a New Game with a manually-entered seed (not left blank) | `GameState.pending_seed != 0` at the point `MapBuilder` consumes it |

---

## Open design questions before Phase E implementation

- **Resolved**: Iron Curtain and Veteran Guard were implemented in the deferred-content pass (see `docs/architecture-decisions.md`) once `NightReport` provided the per-night damage tally the former needed; the latter's per-villager survival counter lives directly on `villager.gd`. Iron Homestead's running minimum-HP tracker was already implemented earlier, in `AchievementManager`.
- **Steam has a hard achievement-count practicality limit in spirit, not rule** - this list (~24 entries) is a reasonable size for a small indie title; trim rather than grow further before Phase E.
- **Icons/art**: none of this needs new 3D assets, but Steam achievement icons are their own small 2D art task, not covered by this doc or the existing 3D asset pack.
