# Roadmap: Current State → Steam-Viable MVP

*How to use this doc:* picks up where `game-master-spec.md` §7's "Build Phases for an AI Agent" leaves off (Phase 0-6 are all done — see `README.md`'s Status section). Re-paste the **North Star** section of the master spec at the top of any new agent session working from this roadmap, same as the master spec itself recommends. Each phase below has a **Done when** line, matching that doc's convention. Phases are ordered by dependency/leverage, not by difficulty — some (E) can run in parallel with others once started.

Anything not in this doc but mentioned in the master spec's own §9 Parking Lot (multiplayer, mobile port, story campaign, etc.) is still explicitly out of scope — don't pull those in while working this roadmap.

---

## Phase A — Fix what's broken ✅ done

Nothing else here matters if the game lies about what it already does. This phase is bug fixes only, no new scope.

- [x] **Save/load doesn't actually restore the map seed.** Fixed: `MapBuilder._ready()` now checks `SaveManager.pending_load` and calls a new `SaveManager.peek_saved_seed()` (reads just the seed out of the save file, synchronously, before the deferred `load_game()` call that restores everything else runs) instead of always generating a fresh random seed. Verified with a headless save→reload round-trip test confirming an identical `seed_used` across both sessions. `docs/architecture-decisions.md`'s "known pre-existing gap" entry is resolved.
- [x] **Pea/bullets has no consumer.** Added a new **Sling Post** defense building (`buildings/sling_post.tres`, `scenes/buildings/sling_post.tscn`) — cheap (10 wood/5 stone), fast-firing (0.5s interval, 4 damage, 5.0 range), consuming Pea's `bullets`. Deliberately weaker per-hit than Watchtower/Ballista Tower so it reads as "shreds Raiders, plinks off Brutes" rather than a strictly-better tower — reuses `tower.gd` and the existing `sm_watchtower_base` mesh (without the platform, for a visually "smaller/cheaper" post). Verified headlessly: correct damage-per-shot and ammo consumption over a real attack-timer cycle.
- [x] **General bug-bash pass**: ran accelerated (`Engine.time_scale`-scaled, real-wall-clock-timed) multi-day playthroughs across 3 seeds with Farmer+Guard roles assigned, reaching day 5-6 each (natural loss under hands-off play — no player building/upgrades — which is expected, not a bug). **Found and fixed a real signal-connection bug along the way**: `enemy.gd`'s `_on_attack_range_body_exited` never disconnected the `died` signal it connected in `_on_attack_range_body_entered`, so a target that walked out of range and back in later (without dying) hit Godot's "signal already connected" error. `villager.gd`'s Guard logic already guarded against this exact case (`_reset_task()`'s `is_connected()` check) — `enemy.gd` now follows the same pattern. Re-ran clean (zero errors) after the fix.

**Done when:** a save/reload cycle reproduces the exact same map, every farmed resource has a use, and a handful of full-season playthroughs run clean with no console errors. **All three confirmed.**

---

## Phase B — Audio

Flagged explicitly in the README as the last real Phase 6 gap: "no audio assets exist in this repo and none were generated." The volume/mute plumbing (`Settings` autoload, `Master` bus) is already real and wired — this phase is purely sourcing/generating and hooking up sound.

- [ ] Day and night music (a simple crossfade on the day/night transition is enough for MVP — doesn't need to be adaptive/layered).
- [ ] Core SFX: gather (wood/stone/food), build placement, plant/harvest, Guard combat hits, enemy death, UI clicks, dusk wave-warning cue, victory/defeat stings.
- [ ] Ambient loops: birds/wind by day, crickets or a fungal-drone night bed (matches the custom pack's Pandora-at-night theming).
- [ ] Wire everything through the existing `Settings`/`Master` bus plumbing — no new settings-menu work should be needed, just audio nodes referencing what's already there.

**Done when:** a full day/night cycle has music, every core player action has feedback SFX, and nothing is silent that shouldn't be.

---

## Phase C — Deepen the actual differentiator (pick 1–2, not all 7) — 5 of 7 done

`game-master-spec.md` §5 calls its crop-to-defense/companion-planting/livestock/non-lethal/idle-resolution/decoration/seasonal-enemy ideas "the most ownable idea in the pitch" against the closest comp (*Becastled*). Right now only a thin slice of one of those seven exists. Per the spec's own "solo-developer-with-AI-agent feasible" pillar, don't build all 7 — pick the highest-leverage 1–2 and defer the rest (see Parking Lot addendum at the bottom).

- [x] **#1 — deepen crop-to-defense (§5.1), done.** Watchtower/darts stays single-target baseline; Ballista Tower/cannonballs now splashes (50% damage to nearby enemies, full damage kept single-target so it's not just a strictly-better Watchtower); Spike Trap/grenades also splashes on trigger (full damage — a trap only fires once, no repeat-cast concern); a new **Sling Post** building consumes Pea/bullets with a SPRAY pattern (nearest 3 enemies in range, distance-sorted, capped to avoid trivializing chokepoint-clustered waves). `tower.gd` gained an `AttackPattern` enum; `trap.gd` gained `splash_radius` (0 = fully back-compat). Verified headlessly against dummy enemies at varied distances.
- [x] **#2 — livestock as living defense (§5.3), done in full.** Chicken raises a one-shot-per-raid alarm via `NotificationManager` when an enemy comes within radius, re-arming at dawn (a deliberate v1 merge of the spec's separate Goose-alarm + Chicken-tell into one, since no `sk_goose` mesh exists — see README). Dog is a free always-on combat defender spawned by every Animal Pen, outside the villager population cap/role system entirely. **Sheep and Goat (deferred-content pass) complete the roster**: Goat reuses `dog.gd` with an `excluded_creature_names` filter so it only assists against Raider-tier enemies; Sheep is a static HP-having body on the same collision layer, giving it the "padding/physical blockade" role for free via `enemy.gd`'s existing generic targeting — no enemy.gd changes needed for either.
- [x] **Companion planting (§5.2), deferred-content pass.** Applied to the game's actual 4 crops rather than the spec's original example table: Carrot+Tomato and Pea+Pumpkin (real permaculture pairs) grant +25% yield when the companion is growing in an adjacent plot.
- [x] **Idle-friendly night resolution (§5.5), deferred-content pass.** Night combat was already fully automated; the missing piece was a summary, not a new mechanic — a new `NightReport` autoload plus a non-blocking Dawn Report panel shown each morning closes this out.
- [x] **Two real bugs found and fixed via headless testing** (not scope creep — this is exactly why the verification step exists): a duplicate-signal-connection bug in `animal_pen.gd` (same *class* of bug as the `enemy.gd` fix in Phase A, different cause — overriding `Building._on_day_started` while also explicitly re-connecting it), and an `Area3D` nested under `AnimalPen`'s `StaticBody3D` that mysteriously never reported overlaps despite correct `PhysicsServer3D`-level registration (root cause not fully identified; worked around by switching the alarm to the same group-scan-on-a-timer pattern `tower.gd`/`dog.gd` already use, rather than continuing to fight an unexplained engine quirk).
- [x] **Non-lethal/deterrence path (§5.4) + seasonal enemy identity (§5.7), done together.** `GameState.current_season()` divides the existing 20-day season into 4 quarters, purely a wave-composition input. Summer brings **Locust Swarm** (targets Farm Plots, eats crops instead of raiding — reuses the already-generated, previously-unused `sk_crawler` mesh); winter brings **Wolf Pack** (targets the Animal Pen directly — a genuinely new mesh, `sk_wolf`, since no unused quadruped fit "dangerous predator"). Both reshape what "defending the homestead" means by season, not just the difficulty. `Enemy` gained two opt-in AI states, `FLEEING`/`PACIFIED` (fully inert for the 4 pre-existing enemy types), giving each seasonal threat a real non-lethal counter: a **Scarecrow** building frightens only Locusts, a **Net Trap** (reusing `trap.gd`'s existing pattern) pacifies any enemy instead of damaging it. A pacified enemy is still killable normally in the meantime — non-lethal is an option, not a forced replacement. Deliberately did *not* build a universal toggle-able alternate win path across all enemies, or real flocking AI ("pack" is a spawn-cluster detail) — stated scope cuts, not surprises.
- [ ] **Still explicitly deferred**: decoration-with-teeth (§5.6) needs a curb-appeal scoring system and a trader/scavenger economy — its own subsystem, a good candidate for a post-launch content update. Don't start it without deliberately revisiting this decision.

**Done when:** at least one system exists that a screenshot/trailer viewer would recognize as "not just another Becastled clone" within 30 seconds of watching it played. **Several now do: distinct splash/spray impacts per ammo type, a goose-alarm-honk + farm dog/goat/sheep defending the pen, companion-planted fields, and a night that visibly looks and plays different depending on the season (a locust swarm eating your fields vs. a wolf pack circling your livestock).**

---

## Phase D — Content & replayability — done

- [x] **More enemy variety.** A new Siege-breaker (tanky/slow/hard-hitting, unlocks day 10, reuses the previously-unused `sk_myconid` mesh) is the "breaks through defenses" archetype the spec called for. Per-night cap trim order updated to protect it last.
- [x] **Player-facing seed/difficulty choice.** The main menu's New Game screen has a seed field (blank = random) and an Easy/Normal/Hard picker. `GameState.pending_seed`/`difficulty` carry the choice across the scene change (same pattern as `SaveManager.pending_load`); `WaveSpawner` applies difficulty as one multiplier across wave composition + the per-night cap.
- [x] An achievement list (`docs/achievements.md`) — design doc only, ~24 entries across milestones/building-variety/combat-survival/secret categories, each mapped to an existing signal or a flagged tracking gap. Implementation is still Phase E's job.
- [x] Verified headlessly: Siege-breaker stats/wave-math/trim-priority, seed reproduction + safe fallback on bad input, clearly differentiated Easy/Normal/Hard totals, and an extended accelerated Hard-mode run with zero script errors.

**Done when:** a returning player has a reason to start a second season beyond "the same run again." **They do now: a different seed, a harder difficulty, and a new late-game threat to prepare for.**

---

## Phase E — Steam-specific technical work — slice 1 done

Can start in parallel with C/D once A/B are stable — long lead times (store page, wishlist runway) mean starting late here costs more than starting early.

- [x] **Settings expansion, done.** `Settings` autoload gained `fullscreen`/`resolution_index` (five presets, including Steam Deck's native 1280x800)/`vsync`, applied via `DisplayServer` and persisted alongside audio in `settings.cfg`. Settings panel UI updated to match.
- [x] **Controller support (menu navigation + camera), done — building placement stays mouse/touch-only, deliberately.** `ui_cancel` (Escape/gamepad B) now drives pause and placement-cancel instead of a raw keycode; every menu (`main_menu`, `pause_menu`, `settings_panel`, upgrade board, build hotbar) grabs initial focus so gamepad `ui_up/down/accept` can navigate without a mouse; `camera_controller.gd` gained left-stick pan and shoulder-button zoom. Full gameplay-input parity (placement, unit selection, hotkeys) was deliberately left mouse/keyboard-only — Steam Deck's trackpad-as-cursor and Steam Input's key-remapping cover that without more code. See architecture-decisions.md for the full reasoning.
- [x] **Local achievement tracking, done (Steamworks reporting itself not yet wired).** New `AchievementManager` autoload implements ~22 of `docs/achievements.md`'s list against real signals/hook points, persists to `user://achievements.cfg`, and shows an unlock toast. `_report_to_steam(id)` is a single no-op seam for the actual Steamworks call once that's wired in. Three achievements (Iron Curtain, Veteran Guard, Speedrunner) remain unimplemented per the design doc's own note that they need a short tracking-design pass first.
- [ ] **Steamworks integration itself (GodotSteam or equivalent GDExtension) for achievements and Steam Cloud saves — not started.** Needs a Steamworks partner account + App ID and the GodotSteam binary, neither of which exist yet; this is an external/account setup step, not something to script blind.
- [x] **Export/build pipeline: baseline presets exist, real templates don't.** Hand-authored `export_presets.cfg` (Windows Desktop + Linux/X11), validated by actually running a headless export attempt — it correctly parsed the preset and failed only on missing export templates, confirming the config itself is sound. Code-signing for Windows SmartScreen is still unaddressed (needs a real certificate).
- [ ] Store page assets: capsule art, trailer, screenshots, short/long description, tags — needs Phase C's differentiator work done first so the page can actually show what's different about this game. Phase C is done; this hasn't been started.
- [ ] Consider a free demo / Steam Next Fest slot to build wishlists ahead of launch.

**Done when:** the game can be wishlisted and a build could be uploaded to Steam today without missing baseline platform features. **Not yet** — Steamworks integration, export templates/actual build upload, and store page assets are the three remaining blockers.

---

## Phase F — Playtesting & launch prep

Threads through every phase above but needs a dedicated final pass before committing to a launch date.

- [ ] **First real external playtesting.** The README states this plainly: "needs an actual human playing it." This has never happened yet — do not treat any earlier phase as truly "done" without it, since balance/pacing calls made in isolation (e.g. the Phase 5 wave-curve tuning) haven't been validated against anyone but the person who built it.
- [ ] A balance pass informed by that feedback (wave curve, upgrade costs, season length).
- [ ] Resolve the still-open pricing/monetization question from `game-master-spec.md` §10.
- [ ] A wishlist marketing runway — commonly recommended as 3-6 months of visible presence (store page live, screenshots/trailer, dev updates) before launch day, which is why Phase E's store-page work can't be left until the week before shipping.

**Done when:** you would be comfortable naming a launch date.

---

## Sequencing summary

```
A (fix bugs)  ──┬──> B (audio) ──┬──> C (differentiator) ──> D (content) ──┐
                │                │                                         ├──> F (playtest + launch)
                └────────────────┴──> E (Steam tech, store page) ──────────┘
```

A blocks everything (don't build new features on top of a save/load bug that contradicts your own docs). B and E's early technical items can start as soon as A is stable. C is the highest-value work and should start before D or E's store-page assets, since the store page needs something differentiated to actually show. F's playtesting should happen early and often, not just at the end — but the *dedicated* pre-launch pass belongs last.
