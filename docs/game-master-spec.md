# [Working Title] — Master Spec Sheet
*Low-Poly Homesteading City Defense*

> **How to use this doc:** The "North Star" section below should rarely change — it's your anchor when an AI agent (or you, mid-session) starts drifting scope. Everything below it is meant to be edited freely as the design evolves. Re-paste the North Star at the top of any new agent session to re-ground context.

---

## North Star (edit sparingly)

**One-sentence pitch:** A cozy-but-tense low-poly game where you build and grow a homestead by day, and defend it from escalating threats by night — think *Stardew Valley* meets *Kingdom: Two Crowns* meets *Plants vs. Zombies* pacing.

**Core Fantasy:** "I am a homesteader who has to become a fortress commander every night — and every choice I make farming and building during the day determines whether I survive the night."

**Non-negotiable pillars:**
1. **Day = Growth, Night = Defense.** The core loop never breaks this rhythm.
2. **Low-poly, readable-at-a-glance art.** No visual noise — every asset communicates function first, beauty second.
3. **Crops and resources connect the two halves — literally.** Nothing you farm/build is decorative; specific crops map to specific defense equipment/effects (see Section 5.1), not a generic currency.
4. **Solo-developer-with-AI-agent feasible.** Every system must be buildable and iterable by one person directing AI tools — scope discipline over ambition.

If a feature idea doesn't clearly serve one of these four pillars, it goes in the "Parking Lot" (see bottom of doc), not into active scope.

---

## 1. Genre & Inspiration

| Reference | What we're borrowing |
|---|---|
| Stardew Valley | Farming loop, tool progression, cozy tone |
| Kingdom: Two Crowns | Day/night rhythm, resource-to-defense pipeline |
| Plants vs. Zombies | Readable threat telegraphing, wave escalation |
| Townscaper / low-poly voxel games | Art style, build-anywhere placement feel |
| They Are Billions | Base-defense tension, siege pacing (lighter touch) |

---

## 2. Core Gameplay Loop

```
MORNING  -> Plan defenses, assign villagers to tasks
DAY      -> Farm, gather, build, craft, upgrade walls/traps
DUSK     -> Warning system triggers (horn, sky color shift, scout report)
NIGHT    -> Wave hits; player actively defends (placing units/traps/direct action)
DAWN     -> Loot fallen enemies, repair, assess losses, next day begins
```

Difficulty curve = wave frequency/strength scales with **days survived**, not just a fixed script — but capped by a "story season" length (e.g., 20-30 day cycles = 1 playthrough arc).

---

## 3. Art Style Guide

- **Palette:** Muted earth tones for homestead (day), high-contrast warning colors (orange/red) for threats (night)
- **Geometry:** Low-poly, flat-shaded, no more than ~500-1500 tris per building asset
- **Lighting:** Dynamic day/night cycle is a *gameplay signal*, not just ambiance — light color = threat proximity
- **Camera:** Fixed isometric or slightly-rotatable isometric (easier to build and light than full 3D free-cam)
- **UI:** Minimal, diegetic where possible (e.g., resource counts on physical carts/silos rather than floating HUD)

---

## 4. Core Systems Breakdown

### Homesteading (Day)
- Farming plots (plant/water/harvest cycle)
- Resource gathering (wood, stone, food, later: ore/herbs)
- Building placement (house, farm, walls, watchtower, workshop)
- Villager assignment (farmer, builder, guard, gatherer roles)

### Defense (Night)
- Wall/gate system with HP and upgrade tiers
- Trap placement (spike pits, fire barrels, later: mechanical traps)
- Guard units (villagers you've equipped, or dedicated defenders)
- Direct player action (optional: player can pick up a weapon and fight)
- Enemy wave types (weak/fast, slow/tanky, ranged, siege-breakers)

### Progression
- Tool tiers (better axe/hoe = faster resource gathering)
- Building tiers (wood wall -> stone wall -> reinforced wall)
- Villager tiers (untrained -> trained guard -> veteran)
- Tech tree or unlock board (kept simple — avoid sprawling trees early)

### Economy Loop
Resources gathered by day -> spent on defense upgrades -> defense success protects resource stockpile & population -> population growth unlocks more gathering capacity. This loop is the beating heart — protect it in every design discussion.

---

## 5. Differentiation & Niche Hooks (market-informed)

*Added after competitive scan — closest direct comp is **Becastled** (build a castle by day, defend by night, cozy city-building + tower defense). Our wedge: make the farming half mechanically inseparable from the defense half, not just a resource abstraction feeding a generic currency.*

### 5.1 Crop-to-Defense System (core differentiator)
This is the most ownable idea in the pitch — most base-defense games abstract resources into a generic currency. We go literal instead:

| Crop | Defense Output |
|---|---|
| Pumpkins | Catapult ammo / thrown boulders |
| Hemp / Flax | Rope, nets, bowstrings |
| Chili Peppers | Fire trap fuel |
| Garlic | Ward that repels a specific nocturnal enemy type |
| Corn | Arrow shafts |
| Sunflowers | Light source that wards off dark-seeking enemies |
| Herbs | Healing salves/potions for guards |

**Design rule:** every crop should map to a *visible, specific* piece of equipment or effect — not a generic material tier. Player should be able to look at their field and know what kind of night they're preparing for.

### 5.2 Companion Planting as Strategy Layer
Real homesteaders pair crops for pest control and soil health — mirror this so certain crop pairings buff each other's defense output (e.g., marigolds near grain reduce "pest" enemy spawns at night). Gives optimization-minded players a system to master beyond plant-harvest-sell.

### 5.3 Livestock as Living Defense Systems
Not just income sources — authentic homesteading roles, each animal earning its keep with a distinct defensive job rather than being a reskinned generic "unit":

| Animal | Defense Role |
|---|---|
| Goose | Alarm system — loudly aggros and alerts guards/player the instant a threat crosses the property line, buying prep time before a wave fully arrives |
| Chickens | Early-warning flock — scatter/flap when something's near, giving a subtler "something's off" cue by day; feathers double as fletching for arrows |
| Sheep | Wool — padding/armor for guards; a penned flock can also be driven into gaps as a physical/soft blockade to slow an enemy's approach |
| Goats | Active combat assist (headbutt attacks on smaller enemies); also graze down brush/overgrowth, which can double as clearing sightlines or removing cover enemies would otherwise approach through |
| Bunnies | Not combat animals — instead an extreme-sensitivity "tell": they freeze/thump at the first sign of a predator-type enemy, functioning as a low-key ambient warning; also fast breeders, so a healthy warren is a steady trade/income side-loop |
| Dog | Your primary active defender — trainable, follows/guards a specific structure or the player directly, and can be the one animal with a real combat stat progression (untrained -> guard dog -> veteran) |

**Design rule:** each animal should give the player a *reason to keep it* beyond stat-sticking a "guard unit" — alarm animals feel different from combat animals, which feel different from ambient-tell animals. That variety is more interesting than five reskinned dogs.

### 5.4 Non-Lethal / Deterrence Path
A toggle-able strategy (not just difficulty slider) for cozy-leaning players: nets, sleep-inducing herbs, scarecrow-style scare tactics as a viable alternative to combat-only defense. Taps into the values-driven audience segment (see e.g. the "vegan farming" niche trend) without forcing a tone change on players who want combat.

### 5.5 Idle-Friendly Night Resolution
Let a well-prepared defense "auto-resolve" a night with a dawn summary report if the player can't play live. Respects casual players' time without removing tension for players who engage actively — matches the broader 2026 cozy-game trend toward low-stakes, flexible-pace play.

### 5.6 Decoration With Teeth
Cozy audiences love decorating, but it's usually pure cosmetic in other farm sims. Give aesthetic/curb-appeal choices a small mechanical effect: a well-kept homestead attracts helpful traders or wandering hires; a neglected one attracts scavenger-type raiders.

### 5.7 Seasonal Enemy Identity
Tie enemy types to season, not just crops to season — locust swarms in summer, wolf packs in winter — so the "what am I defending against" question reshapes crop-to-defense strategy across a playthrough, not just crop-to-income strategy.

---

## 6. Tech Stack Recommendation (AI-agent-friendly)

Given you're building this primarily by directing AI coding agents, and your own background is React/TypeScript:

**Recommended: Web-based build using React Three Fiber (Three.js) + TypeScript**
- Leverages your existing frontend fluency for tooling, UI, and state management
- Huge amount of training data/documentation for AI agents to draw from (Three.js, R3F)
- Easy to prototype, deploy, and share playable builds instantly (no export/build pipeline friction)
- Libraries: `@react-three/fiber`, `@react-three/drei`, `zustand` (game state), `use-cannon` or `rapier` (physics if needed)

**Alternative: Godot 4 (GDScript or C#)**
- Purpose-built game engine, better built-in tools for tilemaps, animation, and lighting
- Steeper agent-collaboration curve if you're not already in the ecosystem, but excellent for low-poly 3D and has first-class low-poly-friendly rendering
- Worth considering if you want a genuine "shippable game" (Steam, itch.io) rather than a browser prototype

**Suggested default for you specifically:** Start in React Three Fiber to prototype fast using skills you already have, validate the loop, then decide whether to port to Godot for a "real" release once the core loop is fun.

> **Project decision (2026-07-09):** Went with Godot 4 (GDScript) instead of the suggested R3F default, for a genuine shippable-game target from the start. See [README.md](../README.md) for current status.

---

## 7. Build Phases for an AI Agent

Structure agent sessions around these phases. Each phase should end in something *playable*, not just code written.

### Phase 0 — Scaffolding
- Set up repo, base scene, camera, basic ground plane
- Day/night cycle timer (even just a color-changing skybox) working end-to-end
- **Done when:** you can open the game and watch a day turn to night on a timer

### Phase 1 — Core Loop Skeleton (gray-box)
- Place-a-building system (even as colored cubes)
- Basic resource counter (wood/food) that ticks up from a "gather" action
- One enemy type that spawns at night and walks toward a target
- One wall/defense object that can be destroyed by that enemy
- **Done when:** you can build a box wall, survive one wave, lose resources if it falls

### Phase 2 — Farming & Gathering Depth
- Farm plots with plant/grow/harvest states
- Multiple resource types
- Villager assignment (even simple state-machine AI)
- **Done when:** the "day" half of the loop feels like an actual mini-game on its own

### Phase 3 — Defense Depth
- Multiple enemy types with distinct behavior
- Trap types
- Guard unit placement and combat resolution
- Wave escalation logic tied to day count
- **Done when:** the "night" half feels tense and has meaningful decisions

### Phase 4 — Art Pass
- Swap gray-box assets for actual low-poly models (commission, buy asset packs, or AI-generate + retopologize)
- Lighting pass for day/night mood
- **Done when:** a stranger looking at a screenshot understands the game's vibe instantly

### Phase 5 — Progression & Content
- Tool/building/villager tiers
- Unlock/tech board
- Balance pass on difficulty curve across a full "season" (20-30 days)
- **Done when:** a full playthrough from day 1 to day 20+ has a satisfying arc

### Phase 6 — Polish & Ship Prep
- UI/UX pass (your specialty — lean on it hard here)
- Sound/music
- Save/load
- Playtesting feedback loop
- **Done when:** you'd be comfortable sharing a public build link

---

## 8. Working Agent Prompting Notes

- At the start of each new agent session, paste the **North Star** section as context so the agent doesn't scope-creep.
- Ask the agent to build in **vertical slices** (one full loop working badly) rather than horizontal layers (all art, then all code) — this matches the phase structure above and keeps things playable at every step.
- When an idea comes up mid-session that doesn't obviously serve a pillar, tell the agent to log it to the Parking Lot instead of building it immediately.

---

## 9. Parking Lot (ideas to revisit later, not in active scope)

- Multiplayer/co-op defense
- Seasonal weather effects beyond day/night
- Trading/economy with NPC traders
- Story/narrative campaign layer
- Mobile port

---

## 10. Open Questions (fill in as you decide)

- [ ] Final title / working name
- [ ] Single biome or multiple? (start single)
- [ ] Player avatar: visible on-screen character, or abstracted "commander" view?
- [ ] Monetization plan (if any) — premium, itch.io pay-what-you-want, free/portfolio piece?
- [ ] Target playtime per season / total game length
