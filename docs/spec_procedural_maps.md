## System: Procedural Map Generation

### Purpose
Generate a new playable map each session that fits a chosen theme without producing an identical layout twice. Themes are visual/ecological flavors (river valley, highland terraces, coastal marsh, etc.), not fixed blueprints. Every generated map must pass a validation pass guaranteeing it is actually playable before it's handed to the session.

### Design goals
- **Variety**: no two sessions feel like the same map.
- **Theme fidelity**: a "river valley" map always reads as a river valley — same rules, different rolls.
- **Guaranteed playability**: buildable core area, reachable chokepoints, at least one water source, resource nodes within reasonable range of the spawn.
- **Reproducibility**: every map is tied to a seed so a specific session's map can be regenerated or debugged.
- **Data-driven themes**: adding a new theme should mean adding a resource file, not new generator code.

### Pipeline stages
1. **Heightmap pass** — noise-based elevation using theme-specific frequency/amplitude.
2. **Biome assignment** — elevation + moisture noise mapped to tile/biome weights defined per theme.
3. **Resource & crop-plot placement** — scatter resource nodes and viable crop-plot zones based on theme density ranges, weighted away from unbuildable terrain.
4. **Defense-feature pass** — identify chokepoints (narrow elevation transitions or forced paths) and elevated tower-viable tiles; tag animal spawn zones.
5. **Prop scatter** — decorative/theme props placed last, non-blocking.
6. **Validation** — run playability constraints (below). On failure: attempt a bounded local patch (nudge elevation/regenerate a sub-region), else reroll with `seed + 1` up to a max retry count, then fall back to a known-safe layout.

### Playability constraints (validator)
- Buildable core area ≥ minimum tile count, contiguous.
- At least one water tile within range of spawn.
- At least one enforced chokepoint reachable from all enemy spawn edges.
- Resource nodes reachable via buildable/walkable tiles (no isolated pockets).
- Animal spawn zones not overlapping crop-plot zones.

### Theme as data, not code
Each theme is a `Resource` (`.tres`) exposing:
- Noise parameters (frequency, octaves, amplitude ranges)
- Biome tile-weight table
- Resource node density range
- Prop set + density
- Chokepoint bias (how aggressively terrain should funnel paths)

The generator reads whichever theme resource is active; swapping themes swaps the resource, not the algorithm. This keeps balance/tuning in designer-editable data files rather than requiring code changes per theme.

### Seeding
- Session seed generated at map start, logged with the save/session record.
- Same seed + same theme resource = same map (deterministic regen for debugging or seed-sharing later).

### Open questions to resolve later
- Exact minimum buildable-core threshold (needs playtesting).
- Whether failed validations should patch locally or always reroll (perf vs. quality tradeoff).
- How many themes ship at launch vs. post-launch content.
