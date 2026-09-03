# Emberwright

A pixel-art roguelike deckbuilder in Godot 4.7. Slay the Spire structure; original class.

**Status: Phase 4 (juice), on placeholder art.** A full Act 1 run is playable start to death,
with the complete animation layer running: fanned cards that deal and arc, sequenced event
playback, hit flash, screen shake, hitstop, damage popups, dissolve deaths, enemy lunges, an
animated Mana gauge with embers, and a drawn map graph.

Sprites are generated procedurally at runtime to the art bible's locked dimensions — they are
scaffolding, not art. Per D-05/D-06 every shipped pixel is hand-drawn; drop a PNG at
`assets/sprites/enemies/<id>.png` and it is used instead, no code change.

## Run it

```bash
brew install --cask godot     # 4.7.2
godot --path .                # opens the editor
godot --path . scenes/main.tscn   # runs the grey-box combat directly
godot --path . scenes/main.tscn -- --dev   # adds a "win fight" button and shows the seed
```

## Test it

```bash
./tools/test.sh               # 253 assertions + four headless walks
./tools/test.sh screens       # just one scene — seconds instead of minutes
python3 tools/check_art.py    # art bible conformance (no deps)
```

`test.sh` runs five scenes. `tests/test_runner.tscn` proves the **rules** are right.
`tests/view_smoke.tscn` proves the **combat view** survives contact with them: it drives the
animated view through three real fights, playing cards and ending turns, and fails on any script
error. A rules suite alone would have passed happily while the screen was broken.

`tests/screen_smoke.tscn` makes the same argument for the other half of the game. It walks 89
meta screens — map, every event against a rich run and a destitute one, rewards, shop, campfire,
treasure, the potion pickers — pressing real buttons, and fails if a screen renders nothing to
click or resolves to the wrong state. Both smokes press only *live* buttons: `_clear_body()` frees
with `queue_free()`, so last screen's controls are still children until the frame ends.

`tests/soak.tscn` self-plays fourteen fights through the animated view and checks, every time the
view goes idle, that the screen still agrees with the simulation. `tests/playthrough.tscn` is the
only scene that walks a whole act — map to boss, through the real screens — so it is the only one
that can prove a player can finish. Its policy is deliberately stupid: press whatever is live.
That is what makes it catch screens which offer a control that leads nowhere.

`tests/screenshot.tscn` is not part of the suite. It renders the real screens to PNGs
(`godot --path . tests/screenshot.tscn -- --out=<dir>`), because a layout bug is far cheaper to
see than to reason about.

`test.sh` bounds the run with a timeout and treats it as a failure. That is not paranoia: if the
test script fails to *compile*, Godot loads the scene with no script attached, so nothing calls
`quit()` and the suite hangs forever instead of failing.

Two integration tests carry most of the weight. `test_combat_invariants_hold_under_autoplay`
plays 24 encounters with a greedy policy and asserts card conservation, HP/Mana ranges and
hand limits after every one — it also fails loudly on any card combination that allows unbounded
actions in a turn, which is how a 0-cost draw-2 infinite loop was caught.
`test_full_run_simulation` walks six complete runs from stage 0 to the boss or to death, and
separates *reaching* the boss from *killing* it — only the second means the act is completable.

The combat simulation has no nodes and never awaits, so the whole rules engine is testable
headlessly. That is a deliberate architectural constraint, not a coincidence — see below.

## The one architectural rule

> **The simulation resolves instantly and pushes `VisualEvent`s. The view drains that queue and
> animates. The simulation never awaits the view.**

`Combat` (`src/combat/combat.gd`) mutates state synchronously and appends to `event_queue`.
`CombatView` (`src/ui/combat_view.gd`) calls `drain_events()` and turns them into log lines,
popups and screen shake.

Break this and you get race conditions, unskippable animations, corrupt saves and untestable
combat. Every card game that feels good keeps them separate.

## Layout

```
src/core/      seeded RNG streams, RunState + save/load, Rewards, Shop, events, run effects
src/combat/    Combat simulation, VisualEvent
src/cards/     CardData, Card, CardEffect + 10 composable effects, EffectFactory, CardLibrary
src/entities/  Combatant, Player (Mana curve), Enemy (intents, openings, conditions, passives),
               9 statuses, relics, potions, registries
src/map/       Spire-style layered DAG generator
src/ui/        run screen, map graph, animated combat view, card/hand/entity/gauge views
src/fx/        Juice autoload, Palette, procedural placeholder art, hit-flash + dissolve shaders
data/          cards, enemies, encounters, relics, potions, events as JSON
docs/          DESIGN.md, DECISIONS.md, ART_BIBLE.md, STEAM_DISCLOSURE.md
tools/         test.sh, check_art.py
tests/         headless test suite
```

## Content is data, not code

Cards, enemies and encounters live in `data/*.json` and are built by `EffectFactory`.
Adding a card is a data edit. This is what makes classes 2 and 3 content work rather than
engineering work.

```json
{
  "id": "ember_jab", "cost": 0, "type": "ATTACK", "target": "ENEMY", "overload_bonus": true,
  "effects": [
    {"type": "damage", "amount": 3, "upgrade_bonus": 2},
    {"type": "conditional", "condition": "overloaded",
     "effects": [{"type": "damage", "amount": 3, "upgrade_bonus": 2}]}
  ]
}
```

JSON rather than `.tres` because it is diffable in review, editable without opening the Godot
editor, and loadable in headless tests. The runtime objects are still `Resource`s, so a `.tres`
pipeline stays possible later without touching effect code.

## Save files

`user://run.json`. The map is **not** serialised — it is regenerated from the run seed on load,
which is only safe because map generation draws from its own RNG stream. Deriving it rather than
storing it means a save file cannot disagree with the generator. RNG stream cursors *are* saved,
so reloading doesn't re-roll rewards the player has already seen.

## Colour

Every colour comes from `src/fx/palette.gd`, which mirrors `assets/palette/endesga-32.gpl`.
A literal `Color(...)` anywhere else is a bug — that is how a 32-colour palette quietly becomes a
200-colour one. Ember orange is reserved for Mana and Overload; nothing else may use it.

The palette is still a **candidate** (D-08). To lock it:
`cp assets/palette/endesga-32.gpl assets/palette/emberwright.gpl` — `check_art.py` then enforces it.

## Next

See `docs/DESIGN.md` for the class design, `docs/DECISIONS.md` for why things are the way they
are, and `docs/ART_BIBLE.md` for the art contract.

The remaining art work is hand-drawn sprites, which is yours. Everything they need to slot into
already exists.
