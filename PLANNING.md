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
├── main.lua                      -- Love2D entry point; phase state machine
├── conf.lua                      -- Love2D config (window, modules)
├── src/
│   ├── state/
│   │   ├── gameState.lua         -- canonical run state + setup
│   │   └── modifiers.lua         -- ability/event hook pipeline
│   ├── rules/
│   │   ├── actions.lua           -- tryTravel, tryTeleport, tryClear, tryResolve, etc.
│   │   ├── phases.lua            -- runDrawPhase, runInstabilityPhase, challenge mod effects
│   │   ├── flux.lua              -- resolveChronologicalFlux
│   │   ├── explosion.lua         -- resolveTemporalExplosion, placeCubesAt
│   │   ├── winLose.lua           -- checkWinLose (all difficulties + Priority City)
│   │   ├── roles.lua             -- applyRole; Chronologist, Physicist, Coordinator abilities
│   │   ├── runPrep.lua           -- computeRP, totalCost, prepOpts, applyModifiers
│   │   └── unlocks.lua           -- evaluateUnlocks, applyUnlocks (5 locked-role conditions)
│   ├── ui/
│   │   ├── map.lua               -- 2×2 scrollable/zoomable map; Priority City gold ring
│   │   ├── hand.lua              -- card hand display
│   │   ├── actions.lua           -- action button row
│   │   ├── modals.lua            -- generic picker modal (color / city / card list)
│   │   ├── footer.lua            -- stats bar with red warnings
│   │   ├── roleSelect.lua        -- role grid (locked roles read from profile.roleUnlocks)
│   │   ├── profileSelect.lua     -- 3-slot profile picker with create/delete
│   │   ├── metaShop.lua          -- Research Lab: Starting Bonuses, Deck Upgrades, Challenge Mods
│   │   ├── difficultySelect.lua  -- 4-option difficulty picker (Introductory → Legendary)
│   │   ├── gameOver.lua          -- VICTORY/DEFEAT card with Play Again / Return to Shop / Change Role
│   │   ├── tooltip.lua           -- push-then-render hover tooltips; rect and circle hit areas; segment-table rich text
│   │   └── anim.lua              -- animation queue: cube flash, explosion rings+shake, flux pulse, phase banners
│   ├── persistence/
│   │   ├── save.lua              -- binser serialize/deserialize; newProfile, serializeState
│   │   └── autosave.lua          -- after-action auto-save; getProfile/getSlot accessors
│   ├── debug/
│   │   └── console.lua           -- backtick-toggle dev console; command registration
│   └── audio/                    -- planned (Phase 10E)
│       └── sounds.lua
├── data/
│   ├── cities.lua                -- 6 US cities + adjacency graph
│   ├── periods.lua               -- 4 time periods mapped to colors
│   ├── cards.lua                 -- city cards (48), event cards (4), threat deck (24)
│   ├── roles.lua                 -- 3 starter + 5 locked role definitions with unlockHints
│   └── shop.lua                  -- starting bonuses, deck cards, challenge mod definitions
├── tests/                        -- Busted specs (276 passing); mirrors src/ layout
│   ├── helpers.lua               -- makeState, cityCard, eventCard, fluxCard, threatCard
│   ├── runPrep.spec.lua          -- computeRP, totalCost, prepOpts, GameState integration
│   └── unlocks.spec.lua          -- evaluateUnlocks, applyUnlocks conditions
└── assets/                       -- placeholder shapes; audio directory planned
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
- *Paradox Barrier* — skip the next Instability Phase
- *Unknown Assistance* — place a Temporal Outpost in any city, no discard required
- *Temporal Slip* — move to any (city, period) for free
- *Chrono Lock* — remove 1 card from the threat discard pile so it doesn't return on reshuffle

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
- Each profile stores: `rpBalance` (permanent pool, never decreases), `roleUnlocks` (map of role id → true), `bonusSelections`, `deckSelections`, `challengeModIds`, `selectedDifficulty`, `lastRole`, `activeRun`.
- Default to last-used profile on launch; auto-resumes an active run if one exists.
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
| Researcher | Win at Heroic | Start with +1 card and a free Chronological Rewind in deck |
| Failsafe Designer | Win at Legendary | Retrieve 1 event card from player discard (once per run) |
| Temporal Analyst | Win a run with no purchased deck upgrade cards | Spend an action to look at top 2 threat deck cards |
| Chronomancer | Win at Heroic without using Teleport | Once per run: view top 6 threat cards and reorder them freely |

---

## Cards

### Player deck
- 48 city cards (2 per (city, period) — 6 cities × 4 periods × 2 copies)
- 4 base event cards: *Paradox Barrier*, *Unknown Assistance*, *Temporal Slip*, *Chrono Lock*
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

RP is a **permanent pool** — it only ever grows (earned after each run). In the Research Lab shop, players *allocate* RP into starting bonuses and deck additions. Removing a selection immediately returns that RP to the available pool. The shop shows Total RP, Allocated, and Remaining. Selections persist between runs; players re-choose each run but nothing is permanently deducted.

### Player deck additions (buffs)

| Card | Cost | Effect |
|---|---|---|
| Chronological Rewind | 3 RP | Clear all cubes of 1 color across all periods of current city |
| Mobile Outpost | 4 RP | *(undefined — to be designed)* |
| Time Corridor | 5 RP | +2 actions this turn |
| Temporal Seal | 4 RP | Prevent all incidents in 1 city for 1 round |
| Supply Drop | 3 RP | *(undefined — to be designed)* |

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
- **Role Selection** — grid of role cards; locked roles grayed; unlocks read dynamically from profile
- **Difficulty Selection** — 4 cards (Introductory → Legendary) showing flux count, RESOLVE target, special rules
- **Research Lab (Meta Shop)** — Starting Bonuses, Deck Upgrades, Challenge Mods; shows Total / Allocated / Remaining RP
- **Generic picker** — color chooser, city chooser, card list (reused across actions)
- **Win / Lose** — *(Phase 10A)* — clickable end-of-run screen with Play Again / Return to Shop / Change Role

### Tooltips
Hover tooltip on every game term explaining mechanic/state. No scripted tutorial.

---

## Debug Console ✓

Toggle with backtick at any time. Renders as a semi-transparent terminal overlay at the bottom of the screen. Up/Down arrows scroll history. Commands are registered from `main.lua` as closures over `gs` so they always see current run state.

| Command | Effect |
|---|---|
| `flux` | Force a Chronological Flux resolution |
| `seed <n>` | Run the instability phase n times |
| `addcube <city> <period> <color>` | Place 1 cube (may chain-explode) |
| `clearcube <city> <period> <color>` | Remove 1 cube |
| `setinstability <n>` | Jump instability index (1–7) |
| `win` | Resolve all 4 anomalies → triggers gameover flow |
| `lose` | Set `gs.lost` → triggers gameover flow |
| `dump` | Print city, turn, difficulty, resolved/repaired state |
| `help` | List all commands |

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
- Full audio (Phase 10E adds stubs; real assets can be dropped in without code changes)
- Localization
- Telemetry

---

## Build Roadmap

### Active / Next

*No phase in progress.* Phases below are queued from `Future Ideas.md`; pick any. Order is not priority. Move each into the archive once complete.

Open design threads:
- *Mobile Outpost* card effect — currently a stub returning "Not yet implemented".
- *Supply Drop* card effect — currently a stub returning "Not yet implemented".

---

---

### Phase 19 — Demo mode & itch.io web release (large)

Packaging work; mostly outside the Lua codebase.

- **Demo mode flag.** Build flag (env var, conf.lua constant, or compile-time switch) gating:
  - Limit to one complete run total (after gameover, all menu paths except Exit are disabled or the game just exits).
  - Disable persistence entirely (no save files written; profile picker hidden or single-slot).
  - Optionally a "Buy the full game" CTA on gameover.

  Files: `conf.lua` (or a new `src/config.lua`), gates in `main.lua`, `src/persistence/save.lua`, `src/ui/gameOver.lua`.
- **Web build.** Compile with [love.js](https://github.com/Davidobot/love.js) (or successor) to produce a static WASM bundle. Verify: file I/O via `love.filesystem` works in browser; audio doesn't break; canvas sizing behaves on resize. Document the build command in this file.
- **itch.io deploy.** Two listings: demo (free, web-playable) and full version (paid, web + native zips). Use `butler` for upload pipeline. Document the release checklist (bump version in `conf.lua`, run tests, package zip, push to butler) in a new top-level `RELEASE.md` or under this phase.
- This phase has no unit tests — verify by running the actual web build on itch.io's draft preview.

---

<details>
<summary><strong>Completed Phases (archive)</strong> — click to expand</summary>

### Phase 0 — Project scaffolding ✓
- Lua + Love2D project skeleton; `main.lua` boots a stub scene.
- Busted set up; `busted` from project root passes a sample test.
- File layout created with empty modules; `binser` vendored.

### Phase 1 — Static data & domain model ✓
- 6 US cities with bidirectional adjacency; 4 time periods mapped to colors.
- Card definitions: 48 city cards, 4 event cards, 24 threat cards, Chronological Flux cards.
- Tests verify counts, adjacency symmetry, color/period mapping.

### Phase 2 — Game-state core ✓
- `GameState.new(opts)` builds full run state: decks, hand, cube table, outposts, instability index, explosion counter.
- All six actions implemented as `try*` functions; draw and instability phases; Chronological Flux resolution.
- `resolveTemporalExplosion` chain with same-period spread and cross-period Outpost spread.
- Auto-derivation of REPAIRED from RESOLVED + zero cubes; `checkWinLose` for all four difficulties.

### Phase 3 — Modifier pipeline ✓
- `Modifiers` module: fold (numeric), permit (veto-AND), fire (event) semantics.
- All rule lookups route through hooks; tests confirm order and veto-AND behavior.

### Phase 4 — Minimal UI ✓
- 2×2 map with scroll/zoom/pan; city nodes with cube stacks and Outpost markers.
- Action button row; hand display; footer stats with red warnings.
- Generic picker modal (color / city / card list); modal rendering wired into draw loop.
- Clear action auto-selects when only one color present; shows picker only for ambiguous multi-color nodes.

### Phase 5 — Roles (starting three) ✓
- Role select grid; Chronologist, Physicist, Coordinator abilities wired as `Modifiers` handlers.
- `src/rules/roles.lua`; data-driven so locked roles plug in without code changes.

### Phase 6 — Persistence ✓
- 3 profile slots; `src/ui/profileSelect.lua` with create/delete.
- Auto-save after every action and phase end via `src/persistence/autosave.lua`.
- Boot auto-resumes last active run; `Save.loadIndex` tracks last-used slot.

### Phase 7 — Meta-progression ✓
- `src/rules/runPrep.lua`: `computeRP`, `totalCost`, `prepOpts`, `applyModifiers`.
- `data/shop.lua`: 5 starting bonuses, 5 deck cards, 4 challenge mods with bonus RP values.
- `src/ui/metaShop.lua`: Research Lab 3-column shop (Total / Allocated / Remaining RP display).
- Run flow: profile select → role select → difficulty select → shop → game → gameover.
- Challenge mod cards (Hotspot, Cascade Event, Volatile Anomaly, Temporal Ban) added to threat deck post-seeding; effects wired in `phases.lua` and `flux.lua`.
- 28 Busted tests for runPrep module.

### Phase 8 — Locked roles, difficulty, Priority City ✓
- `src/ui/difficultySelect.lua`: 4-option picker between role select and shop.
- Chosen difficulty saved to `profile.selectedDifficulty`; flows through `RunPrep.prepOpts` → `GameState.new`.
- `src/rules/unlocks.lua`: `evaluateUnlocks` checks 5 win conditions; `applyUnlocks` saves to `profile.roleUnlocks`; newly unlocked roles shown on gameover overlay.
- `src/ui/roleSelect.lua` now reads `profile.roleUnlocks` dynamically.
- Priority City gold ring on map for Legendary runs; instant-loss on explosion already wired in `explosion.lua`.
- `gs.hadDeckUpgrades` flag supports Temporal Analyst unlock condition.
- 14 Busted tests for unlock conditions.

### Phase 9 — Debug console ✓
- `src/debug/console.lua`: toggle, history, scroll, cursor blink, command registration.
- Commands: `flux`, `seed <n>`, `addcube`, `clearcube`, `setinstability`, `win`, `lose`, `dump`, `help`.
- Backtick toggles; console absorbs all keypresses when open; renders last in the draw stack.

### Phase 10A — Win/Lose modal ✓
- `src/ui/gameOver.lua`: styled VICTORY (green) / DEFEAT (red) card with reason text, +RP earned, and newly unlocked role names; `render(gameResult)` and `hit(vx, vy)` → `"play_again"` / `"return_to_shop"` / `"change_role"` / nil.
- Three buttons: **Play Again** (same role + difficulty, skip shop → `startGame`), **Return to Shop** (same role/difficulty, back to shop with prior selections), **Change Role** (back to role select).
- R key now returns to role select instead of profile select.
- Bug fix: `AutoSave.finish()` was nilifying slot and profile, causing the shop to show 0 RP and `commitShop` to silently bail after returning from gameover. Fix: capture slot/profile before `finish()`, then re-init AutoSave so the updated profile stays accessible.

### Phase 10B — Tooltips ✓
- `src/ui/tooltip.lua` — push-then-render accumulator. `push(x,y,w,h,content)` for rects, `pushCircle(cx,cy,r,content)` for map nodes. Content is a plain string (word-wrapped at 300px) or a segment table `{t, r, g, b, bold}` for inline color/weight. Bold is simulated by double-printing at `(x+1,y)`. `render()` finds the first hovered area, draws the floating box edge-clamped to the virtual canvas, then clears all areas. `setMouse(vx,vy)` called from `love.mousemoved`.
- **Action buttons** — per-button description of requirement and effect (8 buttons including Coordinator Move).
- **Hand cards** — city cards show name + discard hint; event cards show their `description` field; flux cards explain the full resolution sequence.
- **Footer stats** — deck count (loss/warn thresholds), per-color cube supply (loss/warn thresholds), instability schedule with current step in **bold red**, explosion count (loss/warn thresholds), resolved/repaired status legend.
- **Map city nodes** — city + period name, non-zero cube counts, Temporal Outpost flag, Priority City warning. Uses `pushCircle` with virtual-space coordinates derived from camera state (`cam.x + wx * cam.scale`).

### Phase 10C — Accessibility
Make the four anomaly colors distinguishable without relying solely on hue.
- Cube stacks use both color and a distinct shape/symbol per anomaly (●▲■◆ or letter labels B/Y/K/R).
- Period quadrant labels and borders use both color and a text tag.
- Shape+color pairing is consistent across map, hand cards, and footer.
- Implementation touchpoints: `src/ui/map.lua` cube drawing; `src/ui/hand.lua`; `src/ui/footer.lua`.

### Phase 10D — Animations & phase feedback ✓
- `src/ui/anim.lua` — animation queue; `update(dt)` / `render()` / `getShakeOffset()`. Four effect types:
  - **cube_flash** — expanding ring in anomaly color at the node; triggered via new `Mod.onCubePlaced` hook fired from `explosion.lua` after each successful placement.
  - **explosion** — two concentric orange rings + screen shake (~0.32 s taper); triggered via existing `Mod.onTemporalExplosion` hook.
  - **flux_pulse** — orange screen-edge glow; triggered via existing `Mod.onChronologicalFlux` hook (already fired in `flux.lua`).
  - **phase_banner** — "Draw Phase" / "Instability Phase" fade-in/hold/fade-out strip; fired from `advancePhase` in `main.lua`. Accepts a `delay` param so both banners can be queued in the same synchronous call and still play sequentially (Instability delayed 0.7 s).
- `modifiers.lua`: added `onCubePlaced` fire hook.
- `map.lua`: added `getNodeWorld(cityId, periodId)` and `worldToVirtual(wx, wy)` for coordinate conversion.
- `main.lua`: `initAnims()` registers three Modifier handlers; re-called after every `Mod.clear()` in `startGame`/`resumeGame`. Forward-declared as `local initAnims` to fix a nil-at-definition-time crash caused by Lua's local scoping rules.

### Phase 10E — Sound stubs
Named audio hook points, all silent, ready for real assets.
- `src/audio/sounds.lua` — one function per event (`Sounds.cubePlaced`, `Sounds.explosion`, `Sounds.flux`, `Sounds.win`, `Sounds.lose`, `Sounds.buttonClick`); each is a no-op until an asset is loaded.
- Called at the same sites as animation hooks; real `.ogg` files can be dropped into `assets/audio/` and loaded by name without touching call sites.

### Phase 11 — Playable Cards from Hand ✓ Done
Wire up all cards that should be playable from the hand. Interaction model: first click selects, second click on the same card plays it. Play is only allowed during `phase == "action"`.

**Card IDs and names:**

| ID | Display Name | Type | Effect |
|---|---|---|---|
| `paradox_barrier` | Paradox Barrier | base event | Set `gs.skipNextInstability = true` — next Instability Phase is skipped |
| `unknown_assistance` | Unknown Assistance | base event | City picker → place Temporal Outpost in chosen city; no card discard |
| `temporal_slip` | Temporal Slip | base event | City picker → period picker → move player to chosen (city, period) for free; fires `Mod.onArrive` |
| `chrono_lock` | Chrono Lock | base event | Picker from threat discard list → permanently remove chosen card (never returns on reshuffle) |
| `chronological_rewind` | Chronological Rewind | deck upgrade | Color picker → clear all cubes of that color from every period of current city |
| `mobile_outpost` | Mobile Outpost | deck upgrade | *(undefined — stub only; shows "Not yet implemented")* |
| `time_corridor` | Time Corridor | deck upgrade | `gs.actionsRemaining += 2` |
| `temporal_seal` | Temporal Seal | deck upgrade | City picker → prevent all cube placements in chosen city until next Instability Phase ends |
| `supply_drop` | Supply Drop | deck upgrade | *(undefined — stub only; shows "Not yet implemented")* |

- `data/cards.lua`, `data/shop.lua` — renamed all card IDs and display names to new scheme.
- `src/state/gameState.lua` — added `skipNextInstability = false` and `sealedCity = nil` to initial state.
- `src/rules/actions.lua` — `tryPlayCard(state, cardIdx, arg1, arg2)` dispatcher + 7 implemented helpers + 2 stubs; discard handled in dispatcher on success.
- `src/rules/phases.lua` — `runInstabilityPhase` checks and clears `state.skipNextInstability` before running.
- `src/state/modifiers.lua` — bug fix: `permit()` was calling `table.unpack` directly instead of the local `unpack` alias, crashing when any `canPlaceCube` handler was registered.
- `main.lua` — `handleCardPlay` (with modal chains per card); `canPlaceCube` hook in `initAnims` enforces `sealedCity`; `gs.sealedCity = nil` cleared after instability; mousepressed uses second-click-to-play for event cards.
- `tests/events.spec.lua` — 16 new tests covering all 7 implemented effects and both stubs; 233 total passing.

### Phase 12 — Locked Role Abilities ✓ Done
Implemented all 5 missing locked-role abilities. Also fixed a latent bug where `applyRole` called `fn()` instead of `fn(state)`, silently breaking any role that needs to mutate state at setup time.

| Role | Ability |
|---|---|
| Temporal Isolationist | `canPlaceCube` hook blocks placements in player's current city and all adjacent cities |
| Engineer | `outpostCardRequired` hook returns `false`, skipping card discard in `tryBuildOutpost` |
| Researcher | On `applyRole`: draws 1 extra card into hand; inserts a free `chronological_rewind` at random deck position |
| Failsafe Designer | `Retrieve Card` button (teal, free action) opens event-card picker from playerDiscard; `tryRetrieveCard` moves chosen card to hand; usable once per run via `failsafeDesignerUsed` flag |
| Temporal Analyst | `Peek Threat` button (amber, costs 1 action) shows info modal with names of top 2 threat deck cards |

- `data/roles.lua` — updated Researcher description ("Stabilizer Cache" → "Chronological Rewind")
- `src/state/gameState.lua` — added `failsafeDesignerUsed = false`
- `src/state/modifiers.lua` — added `outpostCardRequired` fold hook
- `src/rules/roles.lua` — fixed `fn(state)`; implemented all 5 APPLY functions; added adjacency lookup built at module load
- `src/rules/actions.lua` — `tryBuildOutpost` wraps card requirement in hook check; added `tryRetrieveCard`
- `src/ui/actions.lua` — `retrieve_card` and `peek_threat` buttons added with role-conditional visibility and tooltips
- `main.lua` — handlers for both new buttons; bug fix: `peek_threat` modal was being cleared immediately because `spendAction` → `endAction()` sets `modal = nil`; fixed by building items before `spendAction`, calling it with a no-op, then opening the modal after it returns (only when `phase == "action"`)
- `src/ui/tooltip.lua` — added `Tooltip.suppress()`: sets a one-frame flag causing `render()` to drop all accumulated hit areas without drawing; fixes tooltips from the map bleeding through open modals
- `main.lua` — `if modal then Tooltip.suppress() end` added in draw loop before `Tooltip.render()`
- `tests/roles.spec.lua` — 19 new tests added alongside existing starter-role tests; 252 total passing

### Phase 13 — Bugfix & dev tooling ✓ Done

- **Chronologist REPAIRED bug fixed.** `onArrive` handler was checking `state.repaired[color]` instead of `state.resolved[color]`. An anomaly is only REPAIRED when there are 0 cubes on the board, making the condition self-defeating — the handler could never fire in normal gameplay. Changed to check `resolved` (cubes still exist and need clearing) and added `util.updateRepaired` call so arriving on the last cube of a RESOLVED anomaly correctly advances it to REPAIRED. Role description updated to "Auto-clears RESOLVED cubes on arrival". Existing tests happened to pass because they manually set both flags; a new test covers the real RESOLVED-but-not-yet-REPAIRED scenario.
- **Console commands added:** `showplayerdeck` and `showthreatdeck` — print each deck in draw order (index 1 = top) with name and card type/city/period detail.
- `src/rules/roles.lua` — `onArrive` handler fix + `util.updateRepaired` call
- `data/roles.lua` — description updated ("REPAIRED" → "RESOLVED")
- `main.lua` — `showplayerdeck` and `showthreatdeck` registered in `initConsole`
- `tests/roles.spec.lua` — test descriptions updated; new REPAIRED-advancement test; 253 total passing

### Phase 14 — Turn flow polish ✓ Done

- **Explicit End Turn.** `spendAction` no longer calls `advancePhase()` when actions hit zero. The player stays in the action phase and can play event cards freely. Only the End Turn button advances the phase. Action-costing buttons (Build, Clear, Resolve, Peek Threat) render visually dimmed at 0 actions and show "No actions remaining" if clicked. Clicking an unreachable map node at 0 actions shows "No actions left".
- **Unified click-to-move.** Travel, Teleport, and Teleport Alt buttons removed. Clicking any city node calls `Actions.movementOptions()` to find all legal paths. If travel is available it fires immediately. Otherwise, a single teleport option executes directly; multiple options show a picker modal. Coordinator Move is also offered inline as a free option when available — works both via the existing button and via direct map click.
- `main.lua` — removed auto-advance in `spendAction`; removed three movement button handlers; rewrote `handleMapClick` with unified logic; travel short-circuits to immediate execution
- `src/ui/actions.lua` — removed travel/teleport/teleport_alt buttons and tooltips; added `COSTS_ACTION` set and disabled visual rendering
- `src/rules/actions.lua` — added `M.movementOptions(state, destCity, destPeriod)` pure-read helper
- `tests/actions.spec.lua` — 9 new tests for `movementOptions`
- `tests/helpers.lua` — added `H.contains()` array search utility; 262 total passing

### Phase 16 — Status bar readability & instability animation ✓ Done

- **Role chip + effect chips (footer, right-aligned).** `src/ui/footer.lua` now renders a pill-badge chip strip on the right edge of the footer. The rightmost chip is always the current role (color-coded, tooltip = ability description, looked up from `data/roles.lua` at module load via `ROLE_BY_ID`). Active-effect chips appear to its left: `Barrier` (skipNextInstability), `Sealed: [city]` (sealedCity), `Coord. Move` (coordinator role + move not yet used), `Retrieve` (failsafe_designer + not yet used). Each has a tooltip explaining duration and effect.
- **REPAIRED → X mark.** The `★` glyph for REPAIRED anomalies replaced with two crossing `love.graphics.line` calls forming a thick X in the anomaly color. RESOLVED stays as `◆`. Tooltip legend updated accordingly.
- **Async instability animation.** `Phases.buildInstabilitySteps(state)` draws all N threat cards from the deck into `threatDiscard` and returns step descriptors (`{card, stepType}`) without placing any cubes. `advancePhase` now enters `"instability_anim"` phase, executes the first step immediately, then `love.update` drains one step every `instabilityDelay` seconds (read from `profile.instabilityStepDelay`, default 2.0 — tunable in Phase 18 options screen). Each step calls cube placement + fires a new `Anim.threatReveal(label, color)` banner showing the drawn card's city/period at the bottom of the map area. Loss is detected per-step; gameover triggers immediately on `gs.lost`. Save happens only in `finishInstability()` via `endAction()` — no mid-animation save.
- `src/ui/footer.lua`, `src/ui/anim.lua`, `src/rules/phases.lua`, `src/persistence/save.lua`, `main.lua` — all modified
- `Phases.applyChallengeModEffect` promoted from local to `M.applyChallengeModEffect` so `main.lua` can call it during step drain; `runInstabilityPhase` (used by `seed` console command) unchanged
- 262 total passing (no new tests — all changes are UI/orchestration layer)

### Phase 18 — Main menu, profile names, options ✓ Done

Wrapped the run loop in a proper menu shell. Boot path: `profileselect → mainmenu` (instead of directly into role select).

- `src/persistence/save.lua` — added `name = ""`, `fullscreen = false` to `newProfile()`
- `src/ui/mainMenu.lua` — new file. 4 buttons: **Resume Last Run** (dimmed when no activeRun), **New Run**, **Change Profile**, **Options**. Shows profile name as subtitle.
- `src/ui/options.lua` — new file. Settings: **Instability Delay** [<]/[>] slider (0.5 s–10.0 s, step 0.5), **Fullscreen** toggle (calls `love.window.setFullscreen`). Action buttons: **Back**, **Quit Run** (only when `profile.activeRun`, abandons run with confirm dialog), **Exit Game** (confirm dialog). All settings persisted to profile on change.
- `src/ui/profileSelect.lua` — shows `profile.name` instead of "Profile N" when name is set.
- `main.lua` — `namingState` overlay: clicking an empty profile slot shows a text-input box (max 16 chars); Enter confirms, Escape cancels. `optionsConfirm` flag gates "Yes/No" confirm dialogs for Quit Run / Exit Game. `selectProfile` routes through mainmenu instead of setup. `love.load` boots to mainmenu when a last-used profile has no active run. `love.textinput` and `love.keypressed` routed through naming overlay when active. Escape: dismisses confirm in options, returns to mainmenu from options.
- Music/SFX volume sliders deferred — audio system is still all stubs.
- `tests/save.spec.lua` — 5 new tests. 276 total passing.

### Phase 17 — New role: Chronomancer ✓ Done

Locked role with an active deck-manipulation ability.

- `data/roles.lua` — Chronomancer entry: cyan/teal color, unlock hint "Win at Heroic without Teleporting"
- `src/state/gameState.lua` — added `chronomancerUsed = false` and `teleportsUsed = 0` to initial state
- `src/rules/actions.lua` — `teleportsUsed` incremented in `tryTeleport` and `tryTeleportAlt`; added `tryReorderThreats(state, orderedCards)` — removes top N cards and re-inserts in player-specified order; sets `chronomancerUsed`
- `src/rules/roles.lua` — `APPLY.chronomancer` (no passive modifiers — ability is UI-triggered)
- `src/rules/unlocks.lua` — chronomancer unlock condition: Heroic+ win with `teleportsUsed == 0`
- `src/ui/actions.lua` — `reorder_threat` button (teal, free action), visible when role matches and not yet used; tooltip added
- `src/ui/modals.lua` — `Modals.newReorder(title, items, onPick)` variant with ↑/↓ per-item arrows, Confirm, and Cancel; `clickReorder` returns `"reorder"` (arrow hit), `modal.items` table (confirm), or `"cancel"`
- `main.lua` — `reorder_threat` handler: peeks top 6 threat cards, opens reorder modal, on confirm calls `Actions.tryReorderThreats`; modal click handler passes through `"reorder"` to keep modal open
- `tests/roles.spec.lua` — 5 Chronomancer tests: reorders deck correctly, sets flag, second use fails, works on short deck, applyRole registers no modifiers
- `tests/unlocks.spec.lua` — 3 chronomancer unlock tests; "legendary win" assertion updated to `>= 6`
- 270 total passing

### Phase 15 — Map and hand UX cleanup ✓ Done

- **Map zoom/scroll/pan removed.** Dropped `cam` struct, all drag/scroll/wheel handlers, and `camToMap`. `worldToVirtual` is now identity (`wx, MAP_Y + wy`). `hitCity` uses direct virtual coords. `love.wheelmoved` and pan handlers removed from `main.lua`. Map is permanently locked to the full 1280×540 2×2 grid.
- **Hand scroll + sort.** `src/ui/hand.lua` rewritten. Shows up to 10 cards per page; `<` / `>` arrow buttons appear at the edges when hand exceeds 10. Sort mode cycles through `insertion | color | period | type` via a clickable label in the lower-right of the hand strip. Sort mode persisted on `profile.handSortMode`; restored on `startGame`/`resumeGame`. `Hand.hitControl` returns `"scroll_left" | "scroll_right" | "sort"` before `Hand.hitCard` is checked. `getSortedIndices` sorts a copy of hand indices; `hitCard` maps sorted display positions back to original hand indices so selection/play still uses the real index.
- **Resolve modal viability filter.** Resolve handler now calls `Mod.cardsToResolveAnomaly` and counts per-color city cards in hand. Each color item shows `count/threshold` and is `disabled = true` when already RESOLVED or below threshold. Disabled items render dim and are unclickable in `Modals.click`. Each item includes a `tip` for hover context.
- **Tooltips inside modals.** `Tooltip.pushModal(x,y,w,h,content)` registers areas in a separate `_modalAreas` list that survives `suppress()`. `render()` checks modal areas first (regardless of suppression), then non-modal areas (only if not suppressed). `Modals.render` calls `Tooltip.pushModal` for each item with a `tip` field. Now `Tooltip.suppress()` in the draw loop blocks map/button/hand tooltips but not modal-item tooltips.
- `src/ui/map.lua`, `src/ui/hand.lua`, `src/ui/tooltip.lua`, `src/ui/modals.lua`, `main.lua`, `src/persistence/save.lua` — all modified
- 262 total passing (no new tests — all changes are UI/presentation layer)

### Cross-cutting / always-on
- New code ships with Busted tests in `tests/`; `busted` is green before any UI work merges.
- All rule lookups go through the modifier pipeline once Phase 3 lands — never bypass it.

</details>
