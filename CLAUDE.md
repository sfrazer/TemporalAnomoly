# Temporal Anomaly — Working Notes

Solo rogue-lite (Pandemic-inspired) in Lua / Love2D 11.5 (LuaJIT). See `PLANNING.md` for game design; this file is the engineering quick-reference.

## Commands

- Run tests: `busted` from project root (config in `.busted`, recursive on `tests/`)
- Run game: `love .` (Love2D 11.5+)
- Tests use the Busted framework; mocks aren't allowed for state — call `Mod.clear()` in `before_each`

## Architecture map

```
main.lua                  Love2D entry; phase state machine; UI dispatch; modal/button handlers
conf.lua                  Love2D window config

src/state/
  gameState.lua           GameState.new(opts) — canonical run state shape
  modifiers.lua           Mod.register/clear + fold/permit/fire pipeline; ALL rule lookups route here
src/rules/
  actions.lua             try* mutators: Travel, Teleport, Build, Clear, Resolve, PlayCard, CoordinatorMove, RetrieveCard
  phases.lua              runDrawPhase, runInstabilityPhase (honours skipNextInstability)
  flux.lua                resolveChronologicalFlux
  explosion.lua           resolveTemporalExplosion + placeCubesAt (calls Mod.canPlaceCube)
  winLose.lua             checkWinLose ('won' | 'lost' | nil)
  roles.lua               APPLY[roleId](state) table; adjacency lookup built at module load
  runPrep.lua             computeRP, totalCost, prepOpts, applyModifiers
  unlocks.lua             evaluateUnlocks / applyUnlocks (5 locked-role conditions)
src/ui/
  map.lua                 2×2 scrollable map; getNodeWorld / worldToVirtual coord helpers
  hand.lua                card hand display
  actions.lua             action button row + role-conditional buttons + BUTTON_TIP
  modals.lua              generic picker modal (Modals.new(title, items, onSelect))
  footer.lua              stats bar with warning thresholds
  tooltip.lua             push-then-render hover tooltips (rect + circle); Tooltip.suppress() one-frame skip
  anim.lua                cube_flash, explosion, flux_pulse, phase_banner queue
  gameOver.lua            VICTORY/DEFEAT card; returns 'play_again' | 'return_to_shop' | 'change_role'
  roleSelect/profileSelect/difficultySelect/metaShop — screen UIs
src/persistence/
  save.lua                binser; newProfile, serializeState
  autosave.lua            after-action save; getProfile/getSlot accessors
src/debug/console.lua     backtick console; commands registered as closures over gs
src/audio/sounds.lua      no-op stubs ready for assets
src/util.lua              shuffle, drawTop, etc.

data/cities.lua           6 US cities + adjacency (bidirectional, identical per period)
data/periods.lua          4 periods → 4 colors (blue/yellow/black/red)
data/cards.lua            48 city cards + 4 base event cards + 24 threat cards
data/roles.lua            3 starter + 5 locked role definitions
data/shop.lua             starting bonuses, deck cards, challenge mods
```

## Modifier pipeline — read this before touching any rule

Every rule lookup goes through `src/state/modifiers.lua`. Never bypass. Three hook flavors:

- **Fold** (numeric): `actionsPerTurn`, `cardsDrawnPerTurn`, `cubesPerThreatCard`, `cardsToResolveAnomaly`, `cubesRemovedPerClear`, `outpostCardRequired`. Each handler `(state, acc[, ctx]) → newValue`. Base value is the vanilla rule.
- **Permit** (veto-AND): `canTravel`, `canBuildOutpost`, `canPlaceCube`. Any handler returning `false` blocks; otherwise allowed.
- **Fire** (event): `onThreatCardDraw`, `onChronologicalFlux`, `onTemporalExplosion`, `onCubePlaced`, `onArrive`. Return values ignored.

Roles register handlers in `roles.lua` `APPLY[id](state)`. Animation/sound/event-card effects register via `main.lua initAnims()` (re-called after every `Mod.clear()` — on `startGame` and `resumeGame`).

## Game state shape (`gs` / `state`)

Selected fields you'll touch often (see `gameState.lua` for the full list):
- `currentCity`, `currentPeriod`, `actionsRemaining`, `turn`
- `hand`, `playerDeck`, `playerDiscard`, `threatDeck`, `threatDiscard`
- `cubes[city][period][color] = int`, `outposts[city] = bool`
- `resolved[color] = bool`, `repaired[color] = bool`
- `instabilityIndex` (1..7, table `[2,2,2,3,3,4,4]`), `explosionCount`
- `role`, `difficulty`, `priorityCity`
- One-shots: `skipNextInstability`, `sealedCity`, `coordinatorMoveUsed`, `failsafeDesignerUsed`
- `hadDeckUpgrades` (for Temporal Analyst unlock)

## Phase state machine (`main.lua`)

`phase` cycles through: `"profileselect"` → `"setup"` → `"difficulty"` → `"shop"` → `"action"` → `"gameover"`. `advancePhase()` runs draw → instability → checks win/lose → either next turn or transitions to `"gameover"`.

## Conventions and gotchas — the parts that bite

1. **LuaJIT has no `table.unpack`.** Every file that unpacks must do `local unpack = table.unpack or unpack` at the top. `modifiers.lua` had a latent crash here for weeks.
2. **`spendAction(fn)` ordering.** `spendAction` calls `fn()`, then decrements actions, then calls `endAction()` which sets `modal = nil`. If you open a modal inside `fn()`, it will be wiped. Pattern: build data → `spendAction(function() return true end)` → set `modal` *after* it returns, gated on `phase == "action"`. See the `peek_threat` handler in `main.lua` for the canonical example.
3. **Forward declarations.** Lua local scoping means `local function foo()` is nil at the site of any earlier reference. If `foo` is called from another local defined above it (e.g. `resumeGame` calling `initAnims`), forward-declare: `local initAnims` near the top, then `initAnims = function() ... end` later.
4. **Tooltip suppression.** Tooltips accumulate hit areas during render; modals draw on top but don't block hits. When a modal is open, call `Tooltip.suppress()` before `Tooltip.render()` in the draw loop.
5. **`Mod.clear()` in tests.** Every spec needs `before_each(function() Mod.clear() end)` — handlers are module-global and bleed between tests otherwise.
6. **Naming.** `try*` mutators return `(ok, err)`. `get*` is side-effect-free. `resolve*` is event resolution with mutations. `check*` returns `'won' | 'lost' | nil`.
7. **No comments for what code does.** Comments are reserved for *why* (constraint, bug-workaround, surprise). Identifiers carry the rest.
8. **Don't add a card/role/button half-implemented.** If you stub it, return `false, "Not yet implemented"` rather than silently no-op'ing.

## How to add a thing

- **New action button:** `src/ui/actions.lua` (add to `BASE_BUTTONS` or `getButtons`, add `BUTTON_TIP` entry, add coloring branch); handler in `main.lua` button click switch.
- **New card effect:** `src/rules/actions.lua` `tryPlayCard` dispatcher + helper; UI flow in `main.lua` `handleCardPlay` (modal chain if needed); test in `tests/events.spec.lua`.
- **New role:** `data/roles.lua` definition (+ unlock hint); `src/rules/roles.lua` `APPLY[id] = function(state) ... end`; UI buttons in `src/ui/actions.lua` if active ability; test in `tests/roles.spec.lua`.
- **New modifier hook:** add the `M.foo` wrapper in `src/state/modifiers.lua` using `fold` / `permit` / `fire`; document the signature in `PLANNING.md` table; call from the rule site.

## Tests

`tests/helpers.lua` exposes `H.makeState`, `H.cityCard`, `H.eventCard`, `H.fluxCard`, `H.threatCard`. Mirror the `src/` layout. Run `busted` before any merge — green is the gate.
