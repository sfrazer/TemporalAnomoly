# Temporal Anomaly — Design & Planning

## Context

A solo rogue-lite game inspired by the Pandemic board game. Coded in Lua using the Love2D framework.

Runs are short and punchy (24 nodes instead of 48, doubling up on player cards, but keeping the threat deck at 24). 4 colors for both time periods and anomalies. The rogue-lite loop: pick a role, attempt a run, earn Research Points, spend RP on starting bonuses and deck customizations, attempt the next run at higher difficulty.

---

## Terminology translation

How Pandemic terms map to Temporal Anomaly:

| Pandemic | Temporal Anomaly |
|---|---|
| Roles | Roles |
| Cities | US Cities |
| Diseases | Anomalies (still color-coded) |
| Regions | Time Periods (Prehistory, Industrial Age, Modern Age, Far Future) |
| Research Stations | Temporal Outposts |
| Direct / Chartered Flight | Teleportation |
| Epidemic | Chronological Flux |
| Infection Rate | Instability Level |
| Infection Deck | Threat Deck |
| Infection Cards | Threat Cards |
| Infection (cubes) | Incident cubes |
| Cure (a disease) | RESOLVE (an anomaly) |
| Eradicate | REPAIR |
| Outbreak | Temporal Explosion |

Travel between periods uses either a matching (city, period) card or a Temporal Outpost. Building one Outpost in a city builds it simultaneously in all 4 periods of that city.

---

## File Structure

```
TemporalAnomaly/
├── main.lua                  -- Love2D entry point
├── conf.lua                  -- Love2D config (window, modules)
├── src/
│   ├── state/
│   │   ├── gameState.lua     -- canonical run state
│   │   ├── profile.lua       -- persistent profile data
│   │   └── modifiers.lua     -- ability/event hook pipeline
│   ├── rules/
│   │   ├── actions.lua       -- tryTravel, tryTeleport, etc.
│   │   ├── phases.lua        -- action/draw/instability phases
│   │   ├── flux.lua          -- resolveChronologicalFlux
│   │   ├── explosion.lua     -- resolveTemporalExplosion
│   │   └── winLose.lua       -- checkWinLose
│   ├── ui/
│   │   ├── map.lua           -- 2×2 scrollable map
│   │   ├── hand.lua          -- card display
│   │   ├── actions.lua       -- action buttons
│   │   ├── modals.lua        -- role select, meta shop, pickers
│   │   └── footer.lua        -- stats with red warnings
│   ├── persistence/
│   │   ├── save.lua          -- binser serialize/deserialize
│   │   └── autosave.lua      -- after-action triggers
│   └── debug/
│       └── console.lua       -- backtick-toggle dev commands
├── data/
│   ├── cities.lua            -- 6 US cities + adjacency
│   ├── periods.lua           -- 4 time periods + colors
│   ├── cards.lua             -- player deck, threat deck, events
│   └── roles.lua             -- role definitions
├── tests/                    -- Busted specs, mirrors src/
└── assets/                   -- placeholders, art, audio
```

---

## Core Mechanics

### Rule breaking

Nearly every constraint should expect to be modified by a player ability, event card, or meta upgrade. Examples (not exhaustive):
1. Number of actions per turn
2. Cards drawn per turn
3. Number of new incidents when a threat card is drawn
4. Travel rules
5. Requirements for building Temporal Outposts
6. Incident cubes removed per action
7. Number of cards needed to RESOLVE an anomaly
8. Number of event cards in the player deck

These are implemented through a central `Modifiers` module (see *Architecture*) so abilities just register handlers.

### Turn structure

1. **Action Phase** — player takes 4 actions
2. **Draw Phase** — draw 2 player cards; Chronological Flux cards resolve immediately
3. **Instability Phase** — draw N threat cards (N = current Instability Level) and place 1 incident cube on each named (city, period)

### Hand limit

7 cards. Over-limit forces immediate discard or play. Modifiable by upgrades.

### Actions (1 each)

| Action | Requirement |
|---|---|
| Travel | Move to an adjacent city in the same period, or to the matching Outpost city in another period |
| Teleport | Discard a (city, period) card → move to that city in that period |
| Teleport (alternate) | Discard a card matching your current (city, period) → move to any (city, period) |
| Build Temporal Outpost | Discard a card matching your current city → places Outposts in all 4 periods of that city simultaneously |
| Clear Anomalous Incident | Remove 1 cube; remove all cubes of that color in your city if its anomaly is RESOLVED |
| RESOLVE Anomaly | At a Temporal Outpost: discard 5 same-color cards → that anomaly becomes RESOLVED |

`RESOLVED` is a state, not a second action. When an anomaly is RESOLVED **and** there are 0 cubes of that color anywhere on the board, the anomaly becomes **REPAIRED** automatically. Future threat cards of that color have no effect (the named city skips its Instability Phase placement, though explosions of other colors can still scatter cubes there).

### Event cards

Free to play anytime on your turn (between actions, or between phases). Do not consume an action. Cannot interrupt a Chronological Flux mid-resolution.

**Base event cards** (shuffled into the player deck at run start):
- *One Quiet Night* — skip the next Instability Phase
- *Government Grant* — place a Temporal Outpost in any city, no discard required
- *Temporal Slip* — move to any (city, period) for free
- *Resilient Population* — remove 1 card from the threat discard pile so it doesn't return on reshuffle

### Chronological Flux resolution

1. Advance Instability Level index (`[2,2,2,3,3,4,4]`)
2. Draw bottom card of threat deck → place 3 cubes on that (city, period) (may trigger Temporal Explosions)
3. Shuffle threat discard pile (including the just-drawn card) → place on top of the deck

### Temporal Explosion chain

When a (city, period, color) node would receive a 4th cube it suffers a Temporal Explosion:
- +1 Explosion counter
- Spread 1 cube of that color to each adjacent (city, period) in the same period
- If the exploding city has a Temporal Outpost, **also** spread 1 cube to that same city in every other period
- Neighbors may chain-explode but never back to a city already exploding this round
- Same-city/different-period nodes count as separate cube piles

### Cube supply

24 cubes per color (96 total). Running out of any color = loss.

### Win conditions (scale with difficulty)

| Difficulty | Chronological Flux cards | RESOLVEs required | Bonus / extra |
|---|---|---|---|
| Introductory | 4 | 2 of 4 | — |
| Standard | 5 | 3 of 4 | — |
| Heroic | 6 | 4 of 4 | OR REPAIR any 2 anomalies (alt win path) |
| Legendary | 7 | 4 of 4 | AND Priority City must remain intact in all periods |

**Priority City** (Legendary): randomly chosen at run start; shown with a gold border in every period. A Temporal Explosion in any period of the Priority City is an instant loss regardless of current explosion count.

### Lose conditions

- Player deck exhausted during draw phase
- Any anomaly cube supply reaches 0
- 8 Temporal Explosions reached
- (Legendary) Priority City explodes in any period

---

## Persistence

### Auto-save
- After every action and at the end of each phase.

### Save format
- Lua serialization via [`binser`](https://github.com/bakpakin/binser) — compact, fast, handles cycles.
- Files: `love.filesystem.getSaveDirectory()/profile_<N>.dat`.

### Profiles
- 3 profile slots.
- No manual "load" action exposed to the player.
- Each profile stores: RP balance, role unlocks, deck-card unlocks, starting-bonus purchases, highest difficulty cleared, run history summary.
- Default to last-used profile on launch, with an option to change profile.
- Profile selection screen allows creating a new profile or deleting an existing one.

---

## Roles

### Starting (always unlocked)

| Role | Color | Ability |
|---|---|---|
| Chronologist | Green | Clear Anomalous Incident removes ALL cubes of the chosen color in your city; auto-clears all cubes of REPAIRED anomalies on arrival |
| Physicist | Blue | RESOLVE Anomaly with only 4 same-color cards instead of 5 |
| Coordinator | Purple | Once per turn: free move to any Temporal Outpost city |

### Locked (earn by winning)

| Role | Unlock condition | Ability |
|---|---|---|
| Temporal Isolationist | Win at Standard | Prevent cube placement in your current city and adjacent cities each turn |
| Engineer | Win at Heroic | Build Temporal Outpost without discarding a card |
| Researcher | Win at Heroic | Start with +1 card and a free Stabilizer Cache in deck |
| Failsafe Designer | Win at Legendary | Retrieve 1 event card from player discard (once per run) |
| Temporal Analyst | Win a run with 0 event cards in the deck | Spend an action to look at top 2 threat deck cards |

---

## Cards

### Player deck
- 48 city cards (2 per (city, period) — 6 cities × 4 periods × 2 copies)
- 4 base event cards: *One Quiet Night*, *Government Grant*, *Temporal Slip*, *Resilient Population*
- N Chronological Flux cards evenly distributed through shuffled city + event cards (N = difficulty's Chronological Flux count)

### Starting hand
- 4 cards by default. "Extra Starting Card" upgrade stacks 4 → 5 → 6 → 7.

### Threat deck (base 24)
- 24 (city, period) threat cards, shuffled.

### Initial seeding
Draw 6 threat cards; cubes are placed only on the named (city, period):
- Top 2 cards → 3 cubes each
- Next 2 → 2 cubes each
- Last 2 → 1 cube each

---

## Deck Customization (rogue-lite meta-layer)

Players spend Research Points between runs to unlock event cards that can be added to their deck during run preparation.

### Player deck additions (buffs)

| Card | Cost | Effect |
|---|---|---|
| Stabilizer Cache | 3 RP | Clear all cubes of 1 color in current city |
| Mobile Outpost | 4 RP | Build a Temporal Outpost in current city without discarding |
| Emergency Protocol | 5 RP | +2 actions this turn |
| Temporal Seal | 4 RP | Prevent all incidents in 1 city for 1 round |
| Supply Drop | 3 RP | Restore 3 cubes to any depleted anomaly supply |

Max 2 copies of each. Cards shuffle into player deck at run start.

### Threat deck additions (challenge modifiers — free, earn bonus RP/run)

| Card | Bonus RP | Effect when drawn |
|---|---|---|
| Hotspot | +1 | Place 2 cubes on a random (city, period) |
| Cascade Event | +2 | Resolve top 2 threat cards instead of 1 |
| Volatile Anomaly | +3 | Next Chronological Flux places cubes on 3 cities |
| Temporal Ban | +1 | Teleport actions disabled for 1 turn |

---

## Meta-Progression

### Research Points earned per run
- +1 for attempting any run
- +2 per anomaly REPAIRED
- +3 for winning
- +1 per difficulty tier above Introductory (Standard +1, Heroic +2, Legendary +3)
- + bonus RP for each threat deck challenge card in play

### Starting bonuses (spend RP)

| Upgrade | Cost | Effect |
|---|---|---|
| Extra Starting Card | 3 RP | +1 card in opening hand (stack up to 3×) |
| Starting Outpost | 5 RP | Pre-placed Temporal Outpost at a chosen US city at run start |
| Light Incidents | 8 RP | Skip first 2 initial threat seedings |
| Remove Chronological Flux | 10 RP | Remove 1 Chronological Flux card from deck each run |
| Bonus Action | 12 RP | 5 actions per turn instead of 4 |

### Difficulty access
Player can freely select any difficulty from run 1. Unlocks gate *content* (roles, deck cards, starting bonuses), not access. Higher difficulties carry their own RP rewards to encourage climbing.

---

## Cities (24 nodes = 6 cities × 4 periods)

### Time periods → colors

| Color | Time Period |
|---|---|
| Blue | Prehistory |
| Yellow | Industrial Age |
| Black | Modern Age |
| Red | Far Future |

### Cities and adjacency

6 US cities; each exists as a node in every period. The adjacency graph is identical in every period. Connections are bidirectional and capped at 3 per city.

| City | Adjacent to |
|---|---|
| Seattle | Chicago, Los Angeles |
| Los Angeles | Seattle, Houston |
| Houston | Los Angeles, Atlanta, Chicago |
| Atlanta | Houston, New York |
| New York | Atlanta, Chicago |
| Chicago | Seattle, Houston, New York |

Cross-period travel: only via Temporal Outposts (which exist in all 4 periods of the city once built) or Teleport with the matching (city, period) card.

---

## Architecture

### Modifier pipeline

Every rule lookup routes through a central `Modifiers` module. Roles, event cards, and meta-upgrades register handlers into named hooks. The base game ships with default behavior; modifiers stack on top in order: base → role → events → meta-upgrades.

Hook set (extend as needed):

| Hook | Signature | Example use |
|---|---|---|
| `actionsPerTurn` | `(state, value) → value` | Bonus Action upgrade |
| `cardsDrawnPerTurn` | `(state, value) → value` | Future buffs |
| `cubesPerThreatCard` | `(state, value) → value` | Volatile Anomaly |
| `cardsToResolveAnomaly` | `(state, value) → value` | Physicist (4 instead of 5) |
| `cubesRemovedPerClear` | `(state, ctx, value) → value` | Chronologist |
| `canTravel` | `(state, from, to) → bool` | Temporal Ban |
| `canBuildOutpost` | `(state, city) → bool` | Engineer (skip discard) |
| `canPlaceCube` | `(state, city, period, color) → bool` | Temporal Isolationist, Temporal Seal |
| `onThreatCardDraw` | `(state, ctx) → void` | Logging, future events |
| `onChronologicalFlux` | `(state, ctx) → void` | Future events |
| `onTemporalExplosion` | `(state, ctx) → void` | Future events |

- Numeric hooks fold: `final = handlers.reduce(base, (acc, h) → h(state, acc))`.
- Permission hooks are veto-AND: any handler returning false blocks the action.

---

## UI Layout

- Primary game scene: map, scrollable, zoomable, pannable.
- The 4 time periods are shown in a 2×2 grid; each period clearly labeled and bordered in its color.
- Cards in the player's hand are spread along the bottom like a hand of cards.
- A row of action buttons for the actions.
- Footer stats with red warnings: cube supply ≤ 4, deck ≤ 5, Temporal Explosions ≥ 6.

### Window
- Default 1280×720, resizable.
- Virtual resolution with letterboxed scaling so the 2×2 map keeps its aspect at any window size.

### Modals
- **Role Selection** — setup screen, grid of role cards (locked roles grayed)
- **Meta Shop** — three sections: Starting Bonuses, Player Deck Cards, Challenge Modifiers
- **Win / Lose** — title, reason, RP earned, Play Again + Shop buttons
- **Generic picker** — color chooser, city chooser, card list (reused across actions)

### Tooltips
Hover tooltip on every game term explaining mechanic/state. No scripted tutorial.

---

## Debug Console

Toggle with backtick. Used to exercise the modifier pipeline and end-state conditions during development.

Commands:
- `flux` — force a Chronological Flux
- `seed <n>` — set initial seeding aggression
- `addcube <city> <period> <color>` — drop a cube
- `clearcube <city> <period> <color>` — remove a cube
- `setinstability <n>` — jump Instability Level index
- `win` / `lose` — force end-state
- `dump` — print full state to stdout

---

## Naming Conventions

| Prefix | Meaning |
|---|---|
| `get*` | Pure read, no side effects |
| `try*` | Mutation that can fail; returns `true`/`false` |
| `resolve*` | Game event resolution with side effects (e.g. `resolveTemporalExplosion`) |
| `check*` | Win/lose evaluator returning `'won' \| 'lost' \| nil` |
| `update*` | UI refresh of a specific element |
| `render*` | Full section rebuild |
| `_*` | File-internal; not called from other files |

---

## Unit Tests

For every subroutine/class/function write a test that can verify functionality without running the game. Store tests in `tests/`, mirroring the `src/` layout.

Use the Busted framework for Love2D.

Test after each change by running `busted` from the root of the project.

---

## Deferred (post-MVP)

- Scripted tutorial
- Final art (use placeholder shapes during development: circles for cubes, rounded rects for cities, colored borders for periods)
- Sound effects and music
- Animations beyond minimal feedback
- Localization
- Telemetry

---

## Build Roadmap

### Phase 0 — Project scaffolding
- Lua + Love2D project skeleton; `main.lua` boots a stub scene.
- Busted set up; `busted` from project root passes a sample test.
- File layout above created with empty modules.
- `binser` vendored for save serialization.

### Phase 1 — Static data & domain model
- 6 US cities with bidirectional adjacency (above).
- 4 time periods mapped to colors.
- Card definitions: player city cards (48), base event cards (4), threat deck (24), Chronological Flux cards.
- Pure data modules; tests verify counts, adjacency symmetry, color/period mapping.

### Phase 2 — Game-state core (headless, fully testable)
- `GameState` object: decks, hands, board cubes per (city, period, color), outposts, Instability index, Explosion counter, current role.
- Setup routine: shuffle decks, draw starting hand (4 default), seed initial threats (3/3/2/2/1/1).
- `tryAction` dispatcher for: Travel, Teleport, Teleport (alternate), Build Temporal Outpost, Clear Anomalous Incident, RESOLVE Anomaly.
- Draw phase: draw 2; Chronological Flux → `resolveChronologicalFlux`.
- Instability phase: draw N threat cards based on Instability Level.
- `resolveTemporalExplosion` chain across same-period neighbors and across periods when an Outpost is present.
- Auto-derivation of REPAIRED state when RESOLVED + 0 cubes.
- `checkWinLose` per difficulty, including Priority City rule.
- Unit tests for every subroutine: each action, flux resolution, explosion chains (single, multi, cross-period), all loss conditions, all win conditions.

### Phase 3 — Modifier pipeline
- `Modifiers` module with hook set above.
- Rewire core rules to read through hooks (no behavior change).
- Tests confirm fold order and veto-AND semantics.

### Phase 4 — Minimal UI
- 2×2 map scene with scroll/zoom/pan.
- City nodes with per-color cube stacks; Outpost markers visible across all periods once built.
- Hand of cards along the bottom.
- Action button row.
- Footer stats with red warnings.
- Generic picker modal (color / city / card list).

### Phase 5 — Roles (starting three)
- Role-selection modal at run start (grid; locked roles grayed).
- Chronologist, Physicist, Coordinator abilities wired as `Modifiers` handlers with tests.
- Hook for future locked roles (data-driven so unlocks plug in).

### Phase 6 — Persistence
- 3 profile slots; profile selection screen with create/delete.
- Auto-save after every action and end of each phase (atomic write).
- Boot defaults to last-used profile; no manual load.

### Phase 7 — Meta-progression
- RP accounting per run.
- Meta Shop modal with Starting Bonuses, Player Deck Cards, Challenge Modifiers.
- Run-prep flow: pick role, choose unlocked bonuses, choose deck additions (max 2 per buff), opt into challenge modifiers for bonus RP.

### Phase 8 — Locked roles, difficulty, Priority City
- Unlock conditions evaluated on run completion.
- Difficulty selector with Chronological Flux count, RESOLVE target, and bonus-win logic.
- Priority City: randomly chosen at Legendary run start, gold border, instant-loss on explosion.

### Phase 9 — Debug console
- Backtick toggle, command list above.
- Useful during all earlier phases — bring it forward if needed during Phase 2.

### Phase 10 — Polish & feel
- Animations for cube placement, explosions, card draws.
- Sound stubs.
- Tooltip overlay for every term.
- Win/Lose modal with reason, RP earned, Play Again + Shop.
- Accessibility pass (color-blind cues; 4 anomaly colors carry meaning).

### Cross-cutting / always-on
- New code ships with Busted tests in `tests/`; `busted` is green before any UI work merges.
- All rule lookups go through the modifier pipeline once Phase 3 lands — never bypass it.
