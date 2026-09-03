# Proposal — Act 1 events with a decision in them

Status: **awaiting approval.** Nothing here is implemented. No file under `src/`, `data/` or
`tests/` was touched to write it.

Amends **D-25** (event choices declare what the run must already have) by adding four things
`requires` cannot say today, and pushes on the boundary of **D-14** (content is JSON, not code):
three of the eight events below are not authorable in the current vocabulary at any price, and the
honest answer is to widen the vocabulary once rather than special-case an event in GDScript.

Numbers marked **measured** are read off the code or computed from its constants. Numbers marked
**guess** are reasoned and unmeasured; `tests/balance.gd` is the thing that settles them.

---

## 0 — First, the fact that should govern how much is spent here

**Measured, from `MapGenerator` constants.** `STAGES 7`, so `ROWS 6` (rows 0–5) plus the boss at
row 6, plus the origin DRAFT node. Row 0 is forced Combat, row 3 forced Treasure, row 5
(`REST_ROW = ROWS - 1`) forced Campfire. **Three rows are left to chance: 1, 2 and 4.**

Row 1 cannot roll Elite or Campfire (`NO_ELITE_BEFORE 2`, `NO_CAMPFIRE_BEFORE 2`), so its weights
total 72 and `P(event) = 22/72 = 0.306`. Rows 2 and 4 have full weights totalling 100, and neither
can have a Campfire or Elite parent (row 1 can be neither, row 3 is always Treasure), so the
zeroing rule never fires there: `P(event) = 0.22` each.

- **Expected event nodes visited per run: 0.75.**
- **P(a run sees no event at all) = 0.42.**
- With 8 events, **any one event is seen in roughly 9% of runs.**

Two consequences, and they point the same way.

1. **Writing more shallow events is close to worthless.** The eighth flat three-choice event
   changes what a player sees about once every eleven runs. The marginal value is in the *depth*
   of the event a run does hit, not in the count.
2. **A multi-step event is not expensive in pacing terms.** The usual objection to a three-screen
   event — "it eats too much of the map" — does not apply when the map hands out less than one
   event node per run. Spending the whole node on a real scene is the correct trade here.

There is a separate balance question underneath this: at `event 22` the act's only authored prose
is invisible in 42% of runs. Raising the event weight is a **D-17 balance decision** and belongs
with the other retuning in `act1-shortened.md`, not in this proposal. I flag it and leave it.

---

## 1 — What is weak about the existing eight

All measured by reading `data/events/act1.json` and `src/core/event_library.gd`.

**Structurally they are one event, written eight times.** Seven of eight have exactly three
choices; one has two. All 23 choices resolve in a single click to a single screen of result lines.
Nothing branches, nothing is asked twice, nothing is uncertain.

**Six of the 23 choices are literally `"effects": []`.** A quarter of the content is "Leave it be
— Nothing happens." That is a legitimate design element once; as the third row of six events it is
the author admitting the other two choices did not need a foil.

**Nothing is random, so nothing is a gamble.** `add_relic` and `add_potion` roll from the reward
tables, but the *decision* never does: every hint states the exact outcome, every outcome is the
one stated. There is no event in the game where the player weighs odds. In a run whose combat
class is literally built on borrowing against the future (Overload is described as a debt in
`player.gd`, `pp_gauge.gd` and `conditional_effect.gd`), the map layer has no risk in it at all.

**The events are a menu of the effect list.** All ten `RunEffects` types appear, roughly once each:
`upgrade_random` ×2, `lose_hp` ×5, `gold` ×4, `heal` ×3, `add_potion` ×3, `lose_gold` ×3,
`add_relic` ×2, `add_card` ×2, `max_hp` ×1, `remove_random` ×1. The set was clearly authored by
walking down `run_effects.gd`, and it reads that way.

**Two pairs are near-duplicates.** `cold_forge` "Drill against the post" is `upgrade_random` +
`lose_hp 5`; `the_long_shift` "Train through the night" is `upgrade_random` + `lose_hp 8`. Same
choice, different weather, three HP apart. Likewise `the_slag_pool` "Reach for it" (9 HP → relic)
and `the_toll` "Pay" (60 gold → relic) are the same shape with the currency swapped.

**`requires` is used only as a safety rail, never as a design tool.** D-25's own rationale says so
out loud: it closes the `lose_gold`-on-a-broke-player hole and stops an event killing anyone. That
is correct and it works — but the consequence is that **no event in the game reacts to what the
run looks like.** The vocabulary can already express "requires a relic" and **not one event uses
it** (used keys: `gold` ×3, `hp_above` ×5, `upgradeable_card` ×2, `free_potion_slot` ×2,
`deck_above` ×1; `relic` ×0). There is no event whose text or offer changes because you arrived
hurt, or rich, or with a bloated deck.

**No event's outcome is visible anywhere else.** `RunEffects.apply` writes to HP, gold, deck,
relics and potions and nothing else — there is nowhere for an event to leave a mark that a later
node could read. The map is memoryless by construction.

**Latent bug, worth fixing whatever happens to this proposal.** `add_relic` accepts a named
`relic` id, but `RunState.add_relic()` returns early when `has_relic(id)` while `RunEffects`
returns `"Obtained %s."` unconditionally. Naming a relic in an event therefore lies to a player
who already owns it. No current event names one, which is the only reason this has not shown up.
Section 4.6.

---

## 2 — New vocabulary at a glance

The eight designs use these. Full spec in section 4; nothing in section 3 works without the row
it cites.

| Token | Where | What it is | Cost |
|---|---|---|---|
| `"next": "<event id>"` on a choice | `EventLibrary` + `run_screen` | resolve, then open a named event instead of Continue | S |
| `"hidden": true` on an event | `EventLibrary.pick` | a follow-up that must never be rolled as a first screen | XS |
| `{"type":"chance", ...}` | `RunEffects` | a coin flip resolved in data, from the `events` RNG stream | S |
| `"when": {...}` on an event | `EventLibrary.pick` | event-level eligibility, so a flag can summon an event | M |
| `{"type":"set_flag"}` / `requires: {"flag": …}` | `RunState`, both | a mark on the run that a later node reads | M |
| `{"type":"remove_choice"}` | `RunEffects` + `run_screen` | the player picks the card, via the existing `CardPicker` | M |
| `{"type":"remove_relic"}` / `"relic_choice"` | `RunState`, `RunEffects`, `run_screen` | give up a held item you pick | L |
| `{"type":"fight", "encounter": …}` | `run_screen` | the event starts a real combat and comes back | XL |
| `requires: {"not_relic": …}` | `EventLibrary` | don't offer a named relic twice | XS |

**Event 8 uses none of it.** It is authorable today, and it is in here on purpose: to show the
current format still has room, and to give the batch something that ships in a single data commit.

---

## 3 — The eight events

Every one obeys the D-25 authoring rule — a destitute run (0 gold, 1 HP, full potion belt, fully
upgraded deck) always has a legal button, including on every hidden follow-up screen, which
`tests/screen_smoke.gd` walks as a top-level event too.

Frame geometry the scenes are written against is in section 5; the short version is **focal art
lives right of BG x 198 or below BG y 100**, and every scene below says where its focus sits.

---

### 3.1 — The Snag Vine · press your luck

**Fiction.** Vine has grown over a cleft in the rock. Years of things have washed in and stayed.
You can get an arm in as far as the elbow, and then further, and then not comfortably at all.

**The decision.** A three-rung ladder where the stop button is free at every rung and the pot and
the odds both worsen. This is the one shape the current event set cannot do at all: the player is
asked the same question three times and has to decide *for themselves* where the marginal deal
turns, with no hint text able to answer it because the answer depends on their HP. The first rung
is a pure gift, which is what makes the second one hard.

Note the shape of the loss on rung three: HP *and* gold. Losing only HP makes the ladder a
straight HP-for-loot converter and a healthy run should always climb it. Making the failure eat
the winnings from rung one is what puts the sunk cost in play.

**Scene: `vine`.** The vine curtain hangs down the entire right strip (BG x 196–240) from the
treeline to the grass, with the cleft mouth — the thing being reached into — at BG x 206–232,
y 96–118, i.e. in the bottom-right corner, well clear of both the plate and Charmander. Boulders
reused along the bottom band.

```json
{
 "id": "the_snag_vine",
 "title": "The Snag Vine",
 "text": "Vine has grown right over a cleft in the rock, and fifty years of whatever the route drops has washed in behind it. You can get an arm in as far as the elbow. Something down there is definitely coins.",
 "scene": "vine",
 "choices": [
  {
   "label": "Reach in to the elbow",
   "hint": "Gain 30 gold. Then decide again.",
   "effects": [{"type": "gold", "amount": 30}],
   "next": "the_snag_vine_deeper"
  },
  {
   "label": "Leave the vine alone",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

```json
{
 "id": "the_snag_vine_deeper",
 "hidden": true,
 "title": "The Snag Vine",
 "text": "Coins in your fist, and the cleft keeps going. Past the elbow it narrows, and whatever is packed in down there is wedged rather than loose.",
 "scene": "vine",
 "choices": [
  {
   "label": "Reach in to the shoulder",
   "hint": "Two chances in three: an item. Otherwise lose 8 HP.",
   "requires": {"hp_above": 8},
   "effects": [{
    "type": "chance",
    "chance": 0.66,
    "win": [{"type": "add_potion"}],
    "lose": [{"type": "lose_hp", "amount": 8}]
   }],
   "next": "the_snag_vine_bottom"
  },
  {
   "label": "Take the coins and go",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

```json
{
 "id": "the_snag_vine_bottom",
 "hidden": true,
 "title": "The Snag Vine",
 "text": "Right at the back your fingers close on something with a strap on it. So, a moment later, does something else.",
 "scene": "vine",
 "choices": [
  {
   "label": "Pull",
   "hint": "Two chances in five: a held item. Otherwise lose 14 HP and 30 gold.",
   "requires": {"hp_above": 14},
   "effects": [{
    "type": "chance",
    "chance": 0.4,
    "win": [{"type": "add_relic"}],
    "lose": [
     {"type": "lose_hp", "amount": 14},
     {"type": "lose_gold", "amount": 30}
    ]
   }]
  },
  {
   "label": "Let go",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

---

### 3.2 — The Ford · buying down variance

**Fiction.** The route crosses on stepping stones, green with algae. Below them the water has cut
a pool and the pool has been collecting whatever the route drops for a long time. A hiker with a
rope is sitting on the bank, and he has done this before.

**The decision.** The same prize at two prices: a free coin flip, or 50 gold for four-in-five. The
interesting part is that **the gold is spent before the odds are used**, and the player can still
back out afterwards. That is deliberate. It makes buying the odds a commitment rather than a
purchase, and it means the correct play depends on how much a relic is worth to *this* run — a
question the hint text cannot answer for them.

The third choice is not a "nothing happens": crossing dry-shod pays 15 gold, so walking away is a
real, small, positive option rather than the author's shrug.

**Scene: `ford`.** `_pool` reused wide and low (cx 140, cy 126, rx 84, ry 9) so the water fills the
bottom band under the plate, with five stepping stones in a shallow arc across it at BG y 112–126,
x 56–226. Focus is the whole bottom strip; nothing above BG y 100.

```json
{
 "id": "the_ford",
 "title": "The Ford",
 "text": "The route crosses on stepping stones, green with algae. Under them the water has dug a pool, and the pool has been collecting whatever the route drops since before the route had a name. A hiker with a coil of rope watches you work it out.",
 "scene": "ford",
 "choices": [
  {
   "label": "Go in after it",
   "hint": "Even odds: a held item. Otherwise lose 14 HP.",
   "requires": {"hp_above": 14},
   "effects": [{
    "type": "chance",
    "chance": 0.5,
    "win": [{"type": "add_relic"}],
    "lose": [{"type": "lose_hp", "amount": 14}]
   }]
  },
  {
   "label": "Pay the hiker to belay you",
   "hint": "Lose 50 gold. Then go in on the rope.",
   "requires": {"gold": 50, "hp_above": 6},
   "effects": [{"type": "lose_gold", "amount": 50}],
   "next": "the_ford_roped"
  },
  {
   "label": "Cross on the stones",
   "hint": "Gain 15 gold.",
   "effects": [{"type": "gold", "amount": 15}]
  }
 ]
}
```

```json
{
 "id": "the_ford_roped",
 "hidden": true,
 "title": "The Ford",
 "text": "He ties the rope off round a stone with a knot he does not have to look at, and hands you the other end. He does not offer to refund anything if you change your mind.",
 "scene": "ford",
 "choices": [
  {
   "label": "Go in on the rope",
   "hint": "Four chances in five: a held item. Otherwise lose 6 HP.",
   "requires": {"hp_above": 6},
   "effects": [{
    "type": "chance",
    "chance": 0.8,
    "win": [{"type": "add_relic"}],
    "lose": [{"type": "lose_hp", "amount": 6}]
   }]
  },
  {
   "label": "Think better of it",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

---

### 3.3 — The Day-Care Fence · you pick the card

**Fiction.** A paddock of long grass and a couple in matching aprons. They will board a move for
you while you are on the route, or teach you whatever the pen has picked up. One thing, not two.

**The decision.** Thin the deck or thicken it — the deckbuilder's actual core question, which the
current event set only ever asks through `remove_random`, i.e. with the player's hands tied.
**Choosing which card leaves is a categorically stronger effect than removing a random one**, so
the gate is real: `deck_above 5` keeps it off a starting deck, and the alternative on offer is a
genuinely good 2-cost TM, so taking the removal costs you a card you wanted.

`remove_random` should stay in the vocabulary — `the_apprentice` uses it as a *cost* ("let him
study you"), which is exactly what a random removal is good for. This is the other verb.

**Scene: `fence`.** A low run of paddock fence across the bottom-right, BG x 150–240 at y 98–120:
three posts and two rails, sitting just under the plate's bottom edge with the long grass of the
pen behind it. Focus is bottom-right; the fence line leads the eye out to the right margin.

```json
{
 "id": "the_daycare_fence",
 "title": "The Day-Care Fence",
 "text": "A paddock of long grass, and a couple in matching aprons who have been doing this since before you were born. They will board a move for you while you are out on the route, or teach you what the pen has picked up between them. One or the other.",
 "scene": "fence",
 "choices": [
  {
   "label": "Board a move here",
   "hint": "Forget a move you choose.",
   "requires": {"deck_above": 5},
   "effects": [{"type": "remove_choice"}]
  },
  {
   "label": "Learn what the pen knows",
   "hint": "Add Roar to your deck.",
   "effects": [{"type": "add_card", "card": "great_bellows"}]
  },
  {
   "label": "Lean on the fence a while",
   "hint": "Heal 6 HP.",
   "effects": [{"type": "heal", "amount": 6}]
  }
 ]
}
```

---

### 3.4 — The Ledger Stone · a cost that lands somewhere else

**Fiction.** A cairn at a junction with a slate propped against it, chalked over with names and
figures. Route-keepers leave supplies here on trust and settle up at the far end. Nobody is
watching the slate.

**The decision.** Take 90 gold now and the guaranteed campfire heals nothing, or pay 45 now and it
heals 15 more. This is the first event in the game whose outcome is **visible at a different node**,
and it prices a resource the player cannot yet see the size of: `rest_heal_amount()` is
`round(max_hp * 0.3)` plus relic bonuses, so at 75 max HP the campfire is worth 23 HP, and Shell
Bell moves that. A player who owns Shell Bell should refuse the debt; a player at full HP heading
into a short walk should take it.

**Measured, and this is what makes the event work:** `REST_ROW = ROWS - 1 = 5`, and events can only
occur on rows 1, 2 and 4. **Every event node is strictly before the campfire**, so the debt always
comes due and the credit always pays out. There is no dead-flag case to handle.

It also rhymes with the class. Overload is described as a debt everywhere in the combat code; the
map layer having one too is the fantasy, not a coincidence.

**Scene: `cairn`.** A stacked stone cairn, BG x 200–232, y 66–122 — a tall thin mass entirely
inside the right strip, its top rising above the plate's bottom edge so it reads as a landmark
rather than as scenery. A pale slate leans against the base at y 108–120, in the clear.

```json
{
 "id": "the_ledger_stone",
 "title": "The Ledger Stone",
 "text": "A cairn at the junction with a slate propped against it, chalked over with names and figures in half a dozen hands. Route-keepers leave supplies here on trust and settle up at the far end. Nobody is watching the slate.",
 "scene": "cairn",
 "choices": [
  {
   "label": "Draw against the tally",
   "hint": "Gain 90 gold. Your next rest heals nothing.",
   "effects": [
    {"type": "gold", "amount": 90},
    {"type": "set_flag", "flag": "tally_debt"}
   ]
  },
  {
   "label": "Pay into the tally",
   "hint": "Lose 45 gold. Your next rest heals 15 more.",
   "requires": {"gold": 45},
   "effects": [
    {"type": "lose_gold", "amount": 45},
    {"type": "set_flag", "flag": "tally_credit"}
   ]
  },
  {
   "label": "Chalk nothing and walk on",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

The campfire reads it (section 4.4). The rest button's label must state the modified number, for
the same reason `_show_campfire` already clamps the promised heal to `max_hp - hp`: promising 23
and delivering 0 is the bug that clamp exists to prevent.

---

### 3.5 — The Sleeping Titan · the fight you chose

**Fiction.** A Golem is asleep across the cut, coiled round a hiker's pack that is not its own.
The pack is reachable. So is the way past, if you are quiet and quick and prepared to be neither
for very long.

**The decision.** Three grades of greed against one escalating consequence: take nothing and
squeeze past for a small HP cost; take the pack and it stays asleep on a 50/50; take the pack
*and* the thing under its head and it definitely wakes up — and then you fight the elite you chose
to fight, with the loot already in your bag. This is the only event that can put a **combat**
behind a decision, and it is the only place in the run where the player picks up an elite fight
voluntarily, having already been paid for it.

**This is the most expensive item in the proposal** (section 4.7). A version that ships without the
`fight` effect is given below the main JSON; it is a worse event and I would rather have the
engineering.

**Scene: `sleeper`.** The coil fills the right strip and the bottom-right corner: seven overlapping
boulder segments arcing from off the bottom-right edge (BG 240,135) up and left, with the head
resting low at BG x 168, y 118 — in the bottom band, clear of both plate and Charmander. Existing
boulders reused along the bottom band left of the head. The body deliberately runs off the right
edge; the thing is too big for the frame and should read that way.

```json
{
 "id": "the_sleeping_titan",
 "title": "The Sleeping Titan",
 "text": "Something the size of a shed is asleep across the cut, curled round a hiker's pack that was certainly not packed by it. There is a way past along the wall. There is also the pack, and there is something with a strap on it under the thing's head.",
 "scene": "sleeper",
 "choices": [
  {
   "label": "Squeeze past along the wall",
   "hint": "Lose 6 HP.",
   "requires": {"hp_above": 6},
   "effects": [{"type": "lose_hp", "amount": 6}]
  },
  {
   "label": "Lift the pack",
   "hint": "Gain 60 gold and an item. Even odds it wakes.",
   "effects": [
    {"type": "gold", "amount": 60},
    {"type": "add_potion"},
    {"type": "chance", "chance": 0.5, "win": [], "lose": [{"type": "set_flag", "flag": "titan_stirring"}]}
   ],
   "next": "the_sleeping_titan_after"
  },
  {
   "label": "Go for the strap under its head",
   "hint": "Obtain a held item. It wakes up.",
   "effects": [
    {"type": "add_relic"},
    {"type": "set_flag", "flag": "titan_stirring"}
   ],
   "next": "the_sleeping_titan_after"
  }
 ]
}
```

```json
{
 "id": "the_sleeping_titan_after",
 "hidden": true,
 "title": "The Sleeping Titan",
 "scene": "sleeper",
 "text": "One eye, then the other.",
 "choices": [
  {
   "label": "Stand your ground",
   "hint": "Fight it.",
   "requires": {"flag": "titan_stirring"},
   "effects": [{"type": "fight", "encounter": "elite_titan", "reward": "elite"}]
  },
  {
   "label": "Run",
   "hint": "Lose 15 HP.",
   "requires": {"flag": "titan_stirring", "hp_above": 15},
   "effects": [{"type": "lose_hp", "amount": 15}]
  },
  {
   "label": "It settles again",
   "hint": "Nothing happens.",
   "requires": {"not_flag": "titan_stirring"},
   "effects": []
  }
 ]
}
```

Note the requirement pattern: the follow-up screen is one event whose choices are partitioned by
the flag, so the "it settles" branch and the "it woke" branch are the same authored screen. That
needs `not_flag` as well as `flag`, and it needs the **destitute-run rule restated as: every
reachable partition must contain an unconditional-ish exit**. Here the woken partition's exit is
"Run", gated on `hp_above 15` — which fails at 1 HP and leaves that partition with only the fight.
**That is a bug in the design, not in the engine**: drop the `hp_above` and let `lose_hp` clamp at
0… except D-25 exists precisely to stop an event killing anyone. The correct fix is a third
woken-branch exit with no HP cost ("Drop the pack and go" — `lose_gold 60`), and I would author
that rather than weaken D-25. Flagged rather than silently patched because it is exactly the class
of hole D-25 was written for.

**Cheap version, if `fight` is not built.** Replace the third choice's follow-up with a flat
consequence — `{"type": "lose_hp", "amount": 22}` and no `next`. It is a worse event: the player
buys a fixed toll instead of choosing a fight, and the scene's whole point evaporates.

---

### 3.6 — The Nest · a boon you carry

**Fiction.** A nest in the grass with one egg in it and nothing anywhere near it that could have
laid it. It is warm.

**The decision.** Carrying it costs 8 Max HP up front — you are feeding it — and pays out *later*,
at a hidden event that only becomes eligible once you are carrying it. The interesting property is
that **the payout node consumes an event slot**, and section 0 says a run averages 0.75 event
nodes. So taking the egg is a bet that the run will roll another event at all. A player who takes
it on row 1 has two more chances; a player who takes it on row 4 has none and has simply bought a
Max HP loss.

That is a real, legible, slightly cruel decision, and it is the cleanest demonstration of "an
outcome changes what a later node does" in the batch. It also gives the event pool a reason to
have a *priority* concept, which is the generalisable half of the engineering (section 4.3).

**Scene: `nest`.** A ring of dry stems around a single pale egg, roughly 26×14 at BG cx 150,
cy 120 — bottom band, right of Charmander, below the plate. Grass tufts reused, thickened around
the nest. The hatch event reuses the same scene: the same patch of grass, one screen later.

```json
{
 "id": "the_nest",
 "title": "The Nest",
 "text": "A nest of dry stems in the long grass with one egg in it, and nothing within a mile that could have laid it. Nobody is coming back for this. It is warm.",
 "scene": "nest",
 "choices": [
  {
   "label": "Carry it with you",
   "hint": "Lose 8 Max HP. Something comes of it later.",
   "effects": [
    {"type": "max_hp", "amount": -8},
    {"type": "set_flag", "flag": "carrying_egg"}
   ]
  },
  {
   "label": "Break it open",
   "hint": "Heal 15 HP and gain 8 Max HP.",
   "effects": [
    {"type": "heal", "amount": 15},
    {"type": "max_hp", "amount": 8}
   ]
  },
  {
   "label": "Leave it where it is",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

```json
{
 "id": "the_hatching",
 "hidden": true,
 "when": {"flag": "carrying_egg", "priority": 100},
 "title": "The Hatching",
 "text": "It goes off in your pack like a dropped plate, somewhere around the middle of the afternoon. Whatever is in there is very small, extremely loud, and has decided you are the arrangement.",
 "scene": "nest",
 "choices": [
  {
   "label": "Keep it",
   "hint": "Gain 16 Max HP and obtain a held item.",
   "effects": [
    {"type": "clear_flag", "flag": "carrying_egg"},
    {"type": "max_hp", "amount": 16},
    {"type": "add_relic"}
   ]
  },
  {
   "label": "Find it a day-care",
   "hint": "Gain 110 gold.",
   "effects": [
    {"type": "clear_flag", "flag": "carrying_egg"},
    {"type": "gold", "amount": 110}
   ]
  }
 ]
}
```

`"when"` makes `the_hatching` ineligible unless the flag is set, and `priority` makes `pick()`
prefer it over the ordinary pool once it is. `clear_flag` on both branches is what stops it firing
twice — belt and braces alongside the `seen` list, because `seen_events` lives on `RunScreen` and
is not serialised, so a save/load mid-run currently forgets what you have seen.

**That last sentence is a live bug I found and did not fix:** `seen_events` is a `RunScreen` field
cleared on new run and never written to `RunState.to_dict()`. Load a run and the event pool resets.
Harmless today, load-bearing the moment events have flags.

---

### 3.7 — The Night Market · giving something up

**Fiction.** The roadside stall after dark, lamps lit, a different person behind it. He does not
want money. He wants something off your belt, and he will not tell you what he is offering for it
until it is on the table.

**The decision.** Trade a held item you pick for one you do not get to see. Every other relic in
the game arrives free; this is the only place a player is asked to **lose** one, which makes it
the only place the relic *strip* becomes a thing to think about rather than a trophy shelf. The
right play is to hand over Rocky Helmet in a deck that never gets hit; the trap is handing over
something whose value has quietly become structural.

Uses the `relic` requirement that D-25 authored and nothing has ever used, plus its inverse.

**Scene: `nightstall`.** Reuse only, no new drawing code: the `night` sky path (dark bands plus
`_stars`) with the existing `_awning` at cx 196, top 82 — the stall's awning and legs sit BG
x 162–231, y 82–120, i.e. bottom-right, straddling the plate's lower-right corner exactly as the
daylight `stall` scene already does. Costs one `match` arm and one change to how `night` is
detected (section 5.3). Same furniture, completely different screen — which is the argument that
the scene system is already carrying more weight than the eight events ask of it.

```json
{
 "id": "the_night_market",
 "title": "The Night Market",
 "text": "The stall is still up after dark, lamps lit, and the person behind it is not the person who was behind it this morning. He does not want money. He nods at your belt, and he will not say what is under the cloth until something of yours is on the table.",
 "scene": "nightstall",
 "choices": [
  {
   "label": "Put something on the table",
   "hint": "Give up a held item you choose. Obtain a rarer one.",
   "requires": {"relic_count_above": 1},
   "effects": [
    {"type": "relic_choice"},
    {"type": "add_relic", "min_rarity": "UNCOMMON"}
   ]
  },
  {
   "label": "Buy whatever is under the cloth",
   "hint": "Lose 120 gold. Obtain a held item.",
   "requires": {"gold": 120},
   "effects": [
    {"type": "lose_gold", "amount": 120},
    {"type": "add_relic"}
   ]
  },
  {
   "label": "Keep walking",
   "hint": "Gain 20 gold. He is not the only one out here after dark.",
   "effects": [{"type": "gold", "amount": 20}]
  }
 ]
}
```

`relic_count_above: 1` rather than `0` on purpose: the starter Charcoal is a relic, and an event
that can strip a run's only held item — the one the deck was built around from turn one — is not a
decision, it is a mugging.

---

### 3.8 — The Old Workings · authorable today

**Fiction.** A cut in the hillside propped with rotten beams, and a spoil heap the rain has been
sorting for fifty years. Someone has been back recently: a flat stone with three things laid out
on it, and nobody to ask.

**The decision.** Three named, knowable prizes and no randomness anywhere. **This is the point of
the event.** Every current relic-granting choice rolls `Rewards.relic()`, so the player is deciding
whether they want *a relic*, which is not a decision — the answer is yes. Naming Muscle Band means
the player is deciding between +1 Strength every fight, 70 gold, and a 3-cost AoE they may not be
able to cast, against *this* deck. That is a harder question than anything in the current eight and
it needs no new engineering at all.

It has four choices rather than three, which is a UI risk — see 5.4.

**Scene: `workings`.** Reuse only: `_flat_rock` moved to cx 150, cy 122 (bottom band, right of
Charmander, holding the three things), plus `_rocks` for the spoil heap. `_rocks` currently
hardcodes a boulder at (20,120), which lands squarely behind Charmander — see 5.3 for the two-line
fix that lets a scene pass its own positions.

```json
{
 "id": "the_old_workings",
 "title": "The Old Workings",
 "text": "A cut in the hillside, propped with beams that have gone soft, and a spoil heap the rain has been sorting for fifty years. Someone has been back recently. There is a flat stone with three things laid out on it, squared up, and nobody anywhere to ask.",
 "scene": "workings",
 "choices": [
  {
   "label": "Take the muscle band",
   "hint": "Obtain Muscle Band.",
   "requires": {"not_relic": "whetstone"},
   "effects": [{"type": "add_relic", "relic": "whetstone"}]
  },
  {
   "label": "Take the coin roll",
   "hint": "Gain 70 gold.",
   "effects": [{"type": "gold", "amount": 70}]
  },
  {
   "label": "Take the TM and work the heap yourself",
   "hint": "Add Rock Slide to your deck. Lose 10 HP.",
   "requires": {"hp_above": 10},
   "effects": [
    {"type": "add_card", "card": "runout"},
    {"type": "lose_hp", "amount": 10}
   ]
  },
  {
   "label": "Leave the stone as you found it",
   "hint": "Nothing happens.",
   "effects": []
  }
 ]
}
```

`not_relic` (4.6) is the one XS-sized new requirement it needs, and only because of the duplicate-
relic bug in section 1. Without that fix, ship it with the requirement dropped and accept that a
player holding Muscle Band can be told they obtained a second one.

---

## 4 — Engineering work

Ranked by cost. Everything above section 3.8 depends on at least one of these; **none of it is
authorable as data today.**

### 4.1 — `hidden` on an event · XS

`EventLibrary.pick()` currently rolls from `all()`. A follow-up screen in the same JSON file would
be rolled as a first screen, and the player would open a run on "Coins in your fist, and the cleft
keeps going."

```
pool = all().filter(func(e): return not bool(e.get("hidden", false)) and not seen.has(...))
```

One line. Do it first; every multi-step event needs it and nothing else does.

### 4.2 — `next` on a choice · S

`EventLibrary.choose()` returns lines and knows nothing about screens, which is right. The chaining
belongs in `run_screen._resolve_event`:

- read `choices[index].get("next", "")` before applying;
- after printing the result lines, if it is non-empty, the action button becomes
  `Continue → _enter_event(EventLibrary.get_event(id))` instead of `Continue → _finish_node()`;
- `_enter_event` is `_show_event`'s body minus the `pick()` call, so the pick and the presentation
  stop being one function. Push the followed-up id onto `seen_events` too.

**`run.complete_node()` must still be called exactly once**, at the end of the chain. It currently
increments `floors_cleared`, so a three-screen event that finishes each screen would count as three
floors.

Validation worth having in the same commit: a test that every `next` names an event that exists and
is `hidden`, and that no chain contains a cycle. Chained events are the first place in this codebase
where a data typo can produce an unwinnable screen.

### 4.3 — `chance` in `RunEffects` · S

```
&"chance":
    var roll := Rng.randf_in(&"events")
    var branch = spec.get("win", []) if roll < float(spec.get("chance", 0.5)) else spec.get("lose", [])
    return "\n".join(apply_all(run, branch))
```

Two details that matter.

**Use `&"events"`, not a fresh generator.** D-15 is the whole reason event outcomes are
reproducible from a seed, and `Rng` state is already saved and restored in `RunState.to_dict()`.

**`apply` returns one `String` and `apply_all` joins on nothing.** A `chance` wrapping two effects
has to return two lines or the log loses one. Either give `apply` an `Array[String]` return — a
mechanical change across ten `match` arms and worth doing — or have `chance` be special-cased in
`apply_all`. I prefer the first: `conditional` in the card layer had the same shape and the card
effects return lists.

Do **not** add a hidden-odds variant. The hints state the odds, the odds are real, and a
deckbuilder that lies about probabilities in its own tooltips is a game nobody trusts.

### 4.4 — Run flags · M

`RunState` gains `var flags: Dictionary = {}`, serialised in `to_dict`/`from_dict` as a plain
string→bool map. `RunEffects` gains `set_flag` and `clear_flag`. `EventLibrary.unmet_requirement`
gains `flag` and `not_flag`.

Consumers are the interesting half:

- **Campfire.** `_show_campfire` reads `tally_debt` / `tally_credit`, adjusts `run.rest_heal_amount()`
  and **clears the flag when the rest is taken**. The rest button's label must show the modified
  number for the same reason it already clamps to `max_hp - hp`.
- **Cleanest home for the arithmetic is `RunState.rest_heal_amount()`**, not the screen — it already
  folds in `bonus_rest_heal` from relics, and the balance harness calls the model, not the UI. A
  debt applied in `run_screen` is a debt `tests/balance.gd` never measures.

Keep the flag namespace flat and the vocabulary tiny. This is one step away from a scripting
language living in JSON, and the guard rail is that a flag may only be **set by an event** and
**read by exactly one named consumer**, documented where it is set.

### 4.5 — Event-level eligibility, `when` · M

`pick()` gains a two-stage filter: events with a `when` block are eligible only if it is satisfied
(same evaluator as `unmet_requirement`, which should therefore be factored out to take a condition
dictionary rather than a choice); eligible events with a `priority` sort ahead of the ordinary pool
and are picked before it.

This is the generalisable mechanism behind "an outcome changes what a later node does", and it is
worth building once rather than hard-coding the egg. It is also the only item here that changes
what a plain `?` node can be, so it wants a test: with `carrying_egg` set, `pick()` must return
`the_hatching`; without it, never.

### 4.6 — Named relics, and the duplicate bug · XS

Two small things, both needed by 3.8 and 3.7.

1. `RunEffects.add_relic` returns `"Obtained %s."` even when `RunState.add_relic` refused the
   duplicate. Make it check `run.has_relic(relic.id)` first and return `""` (or an honest line).
   **This is a live bug today**, latent only because no event names a relic.
2. `not_relic` in `unmet_requirement`, the inverse of the existing `relic` key. Three lines.

Also `min_rarity` on `add_relic` for 3.7, which is a filter argument threaded into
`Rewards.relic()` — it already filters BOSS out, so the shape exists.

**Not new, checked:** 3.6 spends Max HP with `{"type": "max_hp", "amount": -8}`, which already
works — `RunEffects` does `max_hp += amount` then `hp = mini(hp + maxi(0, amount), max_hp)`, so a
negative amount clamps current HP and never heals. No current event uses a negative `max_hp`, so it
is untested; a `max_hp_above` requirement would be wanted the moment a bigger cost is authored,
since nothing stops max HP reaching zero.

### 4.7 — Interactive effects: `remove_choice` and `relic_choice` · M / L

`RunEffects.apply` is synchronous and returns a string. A card picker is neither. The pattern that
fits what is already there:

- `RunEffects` declares a set of **interactive** effect types and refuses to apply them, returning
  `""`.
- `run_screen._resolve_event` splits the choice's effects at the first interactive one: applies the
  prefix, drives the picker (`CardPicker` is already built and already used by
  `_show_upgrade_picker`, including a `display_only` mode), then applies the suffix and shows the
  result screen.

`remove_choice` is M: `CardPicker` does exactly this at the campfire already.

`relic_choice` is L and carries a real hazard. `RunState` has **no** `remove_relic`, and
`add_relic` applies `bonus_max_hp` on the way in. Removing Lucky Egg must take the 8 Max HP back
out, which can drop `max_hp` below `hp` (clamp) and, with Life Orb's +12, below a *dying* run's
current HP. Write `remove_relic` to mirror `add_relic` exactly and clamp `hp = mini(hp, max_hp)`,
and make sure it cannot reach 0 max HP. There is no relic-picker widget; `ItemShelf` exists and
would need a selectable mode.

If only one of the two gets built, build `remove_choice`. Event 3.7 can wait; deck thinning is the
one the deckbuilder actually needs.

### 4.8 — `fight` from an event · XL

`_begin_combat(kind)` picks its own encounter from `EnemyLibrary.encounters_of_kind` and its
completion handler calls `_show_rewards` and then `_finish_node`. An event-launched fight needs:

- a named encounter rather than a kind;
- a return path to the *event's* result screen rather than to the map;
- `complete_node()` still called exactly once, and the reward screen still shown;
- death mid-event routed to game over, which `_on_combat_finished` already handles.

This is the one item I would happily see rejected. It buys exactly one event, and the cheap version
of 3.5 is playable. It is in the proposal because "an event that starts a fight" is the single most
requested shape in the genre and because the plumbing, once built, also unlocks event-gated elites
and a boss-preview node.

---

## 5 — The art

### 5.1 — Where things may actually go

Measured from `event_scene.gd` and `project.godot`. The viewport is 960×540, the scene plate is
240×135 drawn at ×4, so **screen ÷ 4 = frame**.

| Thing | Screen | Frame (240×135) |
|---|---|---|
| Text plate | x 170–790, y 88–396 | **x 42–198, y 22–99** |
| Charmander | x 4–154, y 320–470 | **x 1–39, y 80–118** |
| Free: right strip | x 792–960 | **x 198–240, all y** |
| Free: bottom band | y 400–540 | **y 100–135, x 39–240** |
| Backdrop only: sky | y 0–88 | y 0–22, full width |

The existing horizon sits at frame y 56–60, which is **behind the plate**. So the usable stage is a
42px-wide right strip and a 35px-tall bottom band, and every focal element below is placed in one
or both. The rule of thumb: **focal x ≥ 198, or focal y ≥ 100, or a tall mass at x ≥ 200 that rises
past the plate's bottom edge to read as a landmark.**

This is also the rule the existing scenes follow — `_pool` at cy 118, `_posts` at x 182–238,
`_big_tree` at cx 208 — and the comment in `for_event_scene` says why. The proposal keeps to it.

### 5.2 — New helpers

Six, all in `placeholder_art.gd`, all drawing from `Palette` only (D-08).

| Helper | Shape | Where it sits (frame) | Used by |
|---|---|---|---|
| `_vine_curtain(img, rng, x0, x1)` | Wavering vertical strands hanging from the treeline to the grass, MOSS over MOSS_DARK, with a SHADOW cavity mouth punched through them low down | x 196–240, y 50–124; cavity x 206–232, y 96–118 | `vine` |
| `_fence(img, cx, y)` | Three RUST posts and two LEATHER rails, with a SHADOW rail shadow cast down-right on the grass | x 150–240, y 98–120; rails at y 104 and 111 | `fence` |
| `_cairn(img, rng, cx, base_y)` | Seven flattened stones stacked with a slight lean, 9–17px wide and 2–4px tall, INK_MUTED lit tops over SHADOW undersides, a BONE slate leaning at the base | x 200–232, y 66–122 at cx 216 | `cairn` |
| `_stepping_stones(img, rng, y)` | Five flat CLAY ellipses ~13×5 in a shallow left-to-right arc, SHADOW undersides, 1px QUENCH_BRIGHT wake on the upstream edge | x 56–226, y 112–126 | `ford` |
| `_coil(img, rng, cx, base_y)` | Seven overlapping boulder segments of decreasing radius arcing from off the bottom-right corner up and left, RUST bodies, SHADOW undersides, one INK_MUTED highlight per segment top-left | x 150–240, y 62–135; head at x 168, y 118 | `sleeper` |
| `_nest(img, rng, cx, cy)` | A ring of BONE and LEATHER stems around one SAND egg with a 1px WHITE highlight top-left | ~26×14 at cx 150, cy 120 | `nest` |

Light source top-left on every one of them (D-09). No dither cells below 2px (art bible rule 4) —
`_dither_band` is the only thing that dithers and none of these call it.

### 5.3 — Reuse, and two small refactors it wants

Two of the eight scenes need **no new drawing code**, which is the strongest evidence the scene
system is under-used rather than under-built:

- **`nightstall`** = the existing `night` sky path (`GROUND`/`QUENCH_DEEP` bands + `_stars`) with
  the existing `_awning(img, 196, 82)`.
- **`workings`** = `_flat_rock(img, 150, 122)` + `_rocks`.

Both want a small change to `for_event_scene`:

1. `var night := scene == &"night"` becomes a membership test, so `nightstall` gets the dark sky
   and the darker treeline/ground branch. One line.
2. `_rocks` and `_posts` hardcode their positions. `_rocks`'s first boulder is at (20, 120), which
   at ×4 is **directly behind Charmander** — already true of the shipped `path` scene, and it will
   bite `workings` too. Give both an optional `specs: Array[Vector2i] = []` argument defaulting to
   today's list. Two lines each, and it turns two fixed pictures into two reusable primitives.

### 5.4 — One UI risk this batch creates

The plate is a **fixed 308px tall** (`PLATE_TOP 88` to `PLATE_BOTTOM 396`) while the body it backs
is a `VBoxContainer` inside a `ScrollContainer` that sizes to content. Today's maximum is three
choices and three lines of prose, which fits. `the_old_workings` has four choices, and several
events here have four lines of text. Four `_centred_button`s at ~40px plus separation plus a
four-line `text` will push the last button past y 396 and out from under the plate onto the raw art.

The fix is small and belongs with this work: measure the body after layout and set the plate's
height from it, with `PLATE_TOP`/`PLATE_BOTTOM` becoming a minimum rather than the geometry. Until
then, **cap authored events at three choices and three lines**, and 3.8 does not ship.

---

## 6 — What I am not sure about

**Whether flags are worth it.** Section 4.4 is the item most likely to metastasise. One event
setting one flag read by one screen is fine; the tenth flag is a scripting language nobody designed,
living in JSON, with no type checking. The guard rail I proposed (set by an event, read by exactly
one named consumer) is a convention, not a mechanism, and conventions lose. If the reviewer wants
to cut one M-sized item, cut this one and cut 3.4 with it.

**Whether the ford's "pay then choose" is clever or just mean.** Letting a player spend 50 gold and
then decline the dive is the kind of thing that reads as depth to a designer and as a bug to a
player. It may need the second screen's decline option to refund, which deletes the entire point.
Unmeasured; this is a playtest question, not an analysis question.

**The numbers are all guesses.** 90 gold for a skipped campfire heal (worth ~23 HP at base max HP),
50 gold for +30 percentage points on a relic roll, 8 Max HP to carry an egg, 70 gold against Muscle
Band against Rock Slide in 3.8 — every one of these is reasoned from the existing events' rates
(the current set prices a relic at 60 gold or 9 HP, and a card at 30 gold) and none is measured.
`tests/balance.gd` cannot settle most of them, because the bot policies have no model of an event
choice at all; a policy that picks event choices would have to be written first, and it would be
measuring the policy as much as the event.

**Whether `chance` will be hated.** Slay the Spire's most-complained-about events are the ones with
hidden coin flips. Mine are stated up front, which I think is the whole difference, but a run
already lost 42% of its events to the map roll and a player who hits their one event and loses the
flip has had a bad time that the game told them was possible. Consider making the *first* rung of
the vine free — it is, in 3.1 — and consider whether 3.2's base dive should be 60/40 rather than
50/50.

**Whether eight new events is even the right number** given section 0. The honest alternative
reading of "0.75 events per run" is that this proposal should be **three** events deep enough to
carry the whole slot — 3.1, 3.3 and 3.8 — plus a balance change to the event weight, and the other
five should wait for Act 2. I wrote eight because the brief asked for six to ten, but I would not
argue hard against the smaller version.

**Where the fiction sits.** Every event I wrote is a route-and-hikers register, matching the
existing eight after their rename from forge imagery (the ids are still `the_slag_pool`,
`the_dead_bellows`, `cold_forge` under Pokémon-flavoured titles). I kept the ids in the new
register rather than the old, which makes the file inconsistent either way. Somebody should decide
whether the old ids get renamed; save-game compatibility does not block it, since `seen_events` is
not serialised (section 3.6).

**The scenes are described, not drawn.** Every placement above is arithmetic against the plate
rectangle, not something I rendered and looked at. `tests/screenshot.gd` already poses two named
events (`_pose_event`) and is the right place to check all eight before any of the JSON lands.
