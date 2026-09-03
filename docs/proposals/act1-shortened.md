# Proposal — the numbers a 7-node Act 1 invalidates

Status: **awaiting approval.** Nothing here is implemented.

Act 1 goes from 15 rows plus a boss (16 stops) to 8 stages ending on the boss (8 stops). That is
half the attrition, half the gold and roughly a third of the card rewards. Almost every tuned
number in the game was fitted to the old length; this is what each one should become and why.

Numbers marked **guess** are reasoned but unmeasured. The planned self-play harness settles them;
where it does, the measurement is named.

---

## 0 — First, an off-by-one worth settling before anything is written

`_attach_boss()` puts the boss at row `ROWS`, one past the generated grid, and wires it to
`rows[REST_ROW]`. So the number of stops is `ROWS + 1`, not `ROWS`.

**Eight stages ending on the boss therefore means `ROWS = 7`, not 8.** Setting `ROWS = 8` yields
nine stops. Seven generated rows (0–6) plus the boss at row 7 is the intended shape.

---

## 1 — Pacing

**Current.** `ROWS 15`, `WIDTH 7`, `PATHS 6`. Row 0 Combat, row 8 Treasure, row 14 Campfire.
`NO_ELITE_BEFORE 5`, `NO_CAMPFIRE_BEFORE 5`. Weights 45 combat / 22 event / 16 elite /
12 campfire / 5 shop. Twelve rows are left to chance.

**Proposed.**

| Stage | Kind |
|---|---|
| 0 | Combat (forced) |
| 1, 2 | Weighted, no Elite |
| 3 | Treasure (forced) |
| 4 | Weighted, at least one Shop node |
| 5 | Weighted, at least one Elite node |
| 6 | Campfire (forced) |
| 7 | Boss |

`TREASURE_ROW 8 → 3`, `REST_ROW` stays `ROWS - 1` (now 6), `NO_ELITE_BEFORE 5 → 4`,
`NO_CAMPFIRE_BEFORE` retired. Weights for the four free rows: **combat 45, event 30, elite 20
(rows ≥ 4), shop 5**. Campfire leaves the weighted pool entirely.

Also `WIDTH 7 → 5` and `PATHS 6 → 4`.

**Why.** Only four rows are left to chance, so the guarantees have to carry the act's shape rather
than decorate it. Treasure at stage 3 sits 43% through, close to the old 53%. Campfire before the
boss is the one rest, which is why extra campfires leave the pool: with four fights instead of
ten there is not enough attrition to justify a second heal, and a spare rest in a seven-node act
converts directly into a free boss win.

Two new guarantees are needed because probability stops working at this length. Shop at weight 5
across four rows appears on **19%** of paths — content that exists in one run in five is content
nobody tunes and nobody sees. Elites are the act's only repeatable relic source; without one the
player reaches the boss on the starter relic plus a coin-flip treasure drop. Both are stated as
*at least one node in the row*, not *the whole row*, so the player still chooses whether to take
the elite or walk past it. That decision is the best one Spire has and forcing the row would
delete it.

`WIDTH 7` with seven rows and six paths fills nearly every cell: the graph becomes a mesh where
every choice reaches every other node, which is the same as having no choice. Five lanes and four
paths keeps it a legible fan, and reads better left-to-right on a 960-wide frame — eight stages at
~96px is 768px, which fits with margin.

**Risk.** Four weighted rows is thin; a run can still draw combat four times and feel like a
corridor. If that shows up, raise event to 35 and drop combat to 40 — do not add more guarantees,
because each one removes a choice.

**Implementation note.** `TREASURE_ROW 8` against `ROWS 7` would silently never fire, since no row
index reaches 8. `_attach_boss` hardcodes `col 3`, which is off-centre once `WIDTH` is 5.

---

## 2 — Deck maths

**Current.** 5 Strike, 4 Defend, 1 Kindle. `HAND_SIZE 5`.

**Proposed starting deck: 2 Strike, 2 Defend, 1 Kindle.** Not 3/1/1.

**Why.** 5:4 is the current attack:defend ratio; 3:1 is 3:1. Cutting the deck in half should
preserve the ratio, not quietly triple the aggression. One Defend in a five-card deck means one
Block card per turn cycle against enemies that hit every turn, and the player has no way to fix it
until the second card reward.

### The real problem: draw 5 against a curve that opens on 1

With a 5-card deck the player draws their entire deck every turn. That part is fine — for the
first two fights it is a *teaching* state, perfect information while learning what Ramp and
Overload do, and variance returns the moment a reward is taken.

The problem is the mana curve underneath it. Turn one is 1–2 mana against a five-card hand, and
the hand is discarded at end of turn. The player draws five, plays one, and throws away four. Turn
two: draws five, plays two, throws away three. Spire draws 5 against a flat 3 energy and wastes
two; this wastes four, then three, then two, and only stops wasting on turn five.

That is not a small tuning gap. It is the ramp mechanic and the draw rule disagreeing about what
a turn is. Hearthstone ramps mana *and* draws one card a turn; Spire has a flat resource *and*
draws a full hand. This currently has one of each.

**Proposed: draw scales with the curve — `draw = clamp(max_mana + 1, 2, 5)`.**

Turn 1 draws 2 on 1 mana, turn 2 draws 3 on 2, turn 4 draws 5 on 4, and turn 5 onward draws 5 on
5. Waste stays near one card throughout instead of starting at four. Ramp then buys cards as well
as mana, which makes the Ramp archetype legible without a single new card, and Overload's cost is
felt properly because a shorter next turn is also a smaller next hand.

**This amends D-12, which is LOCKED and reads "draw 5".** It also interacts with `bonus_card_draw`
relics, which should stack on top of the clamp rather than inside it.

**Alternative if the draw rule is not to be touched:** accept the waste. It is survivable and it
makes early turns about choosing which card to play rather than how to sequence four. But it will
read as "my hand does nothing" for the first three turns of every fight, which is the worst
possible first impression of a new mechanic.

**Deck size at the boss.** A typical path is combat, two weighted, treasure, weighted, elite,
campfire — about four card rewards, plus perhaps one from an event or shop. **Deck reaches 9–11 by
the boss**, against 14–16 before. Keep `CARD_CHOICES 3`; do not raise the reward rate. A short act
where each of four picks is decisive is a better act than a short act that hands out cards to hit
a target deck size. It does mean skipping a reward is now a real cost, which is correct.

**Risk.** A 9-card deck may simply be too weak for a 120 HP boss. That is section 4's problem, and
the fix belongs there — lower the boss, do not inflate the deck.

---

## 3 — Economy

**Current.** Start 99 gold. Normal 10–20, elite 25–35, treasure 45–65, boss 95–105. Cards 50/75/150,
relics 150–300, potions 50/75/100, removal 75 rising 25 per use.

**Earned gold on a typical path:** three normal combats (~45) + one elite (~30) + treasure (~55),
call it **130**, against roughly 260 before. Plus 99 starting = ~230 available, and realistically
**one shop visit**, since shop appears once by guarantee.

**Proposed.**

- **Prices unchanged.** 230 gold buys a relic and a common card, or removal plus an uncommon plus a
  potion. That is a real shopping decision with real exclusion, which is exactly what one shop
  visit should be. The 15-row prices happen to land correctly for a 7-node purse.
- **Starting gold 99 → 60.** **Guess.** At 99, nearly half the money the player ever holds was
  never earned, so combat rewards stop registering as rewards. 60 keeps the shop reachable while
  making the elite detour and the treasure node matter.
- **`REMOVAL_BASE` stays 75.** Note that removal got *stronger*, not weaker: cutting a Strike from
  a 5-card deck is a 20% concentration gain against 10% before. If anything it is underpriced now.
  `REMOVAL_INCREMENT 25` is close to dead — with one shop you will never buy a second removal.
- **Boss gold (95–105) is currently inert.** The boss is the last stage and there is no Act 2, so
  it pays out into nothing. Keep the number for when Act 2 exists, but do not count it when
  judging whether the economy works.

**Risk.** Cutting starting gold to 60 could put the guaranteed shop out of reach on a path that
skips the elite, which would make the guarantee pointless. The measurement: **share of simulated
runs that can afford at least two shop items on arrival.** Below ~70%, put starting gold back up.

---

## 4 — Enemy numbers

**Current.** Player 75 HP. Normals 8–34, elites 44–58, boss 120. `REST_HEAL_FRACTION 0.3`.

These were fitted to ten-plus fights of attrition, a 14–16 card deck at the boss, **and a flat 3
energy**. Two of those three are now wrong, and D-12 already records the third as unretuned —
autoplay fell from 3-of-6 to 2-of-6 reaching the boss on identical seeds before the act was
shortened at all.

**Proposed first pass. All guesses; all measurable.**

| | Current | Proposed | Why |
|---|---|---|---|
| Boss HP | 120 | **90** | Faces a 9–11 card deck instead of 14–16. At 5 mana and a realistic 15–20 damage a turn, 120 is a 6–8 turn fight against a boss that hits every one of them. |
| Elite HP | 44–58 | **38–48** | Elites now appear at stage 5 of 7 against a deck two rewards smaller than the old stage-9 equivalent. |
| `cracked_golem` | 28–34 | **24–30** | The top of the normal band, and it can now be drawn at stage 1 with a five-card deck. |
| Other normals | 8–26 | unchanged | The low band is already calibrated to a one-mana opening turn. |
| Player HP | 75 | unchanged | Fewer fights means less total damage taken; raising HP as well would make the act trivial. |
| `REST_HEAL_FRACTION` | 0.3 | unchanged | One guaranteed rest before the boss, healing 22. Correct for one fewer campfire. |

**Do not tune anything here by hand before the harness runs.** The correct order is: land the
structure, run the self-play, then move these. Every number above is a starting point for the
first measurement, not a conclusion.

**Amends D-12**, which is LOCKED and states 8–34 / 44–58 / 120 explicitly.

---

## 5 — The palette conflict

**Current.** `EMBER f77622` is reserved for Mana and the Overloaded state (D-08). But
`Palette.for_card_type` gives ATTACK cards `EMBER_DEEP be4a2f` — the same warm family. Under Heat
that was coherent: attacks were hot and so was the gauge. Under Mana the warm ramp now means
"resource" in one place and "attack" in another, on the same screen, three inches apart.

**Proposed. ATTACK card frames move to `BLOOD a22633`.**

Red already means damage in this game — `Strength` is `RED`, damage popups are the red family — so
the association is established rather than invented. `BLOOD` is dark and desaturated where `EMBER`
is bright and saturated, so the two separate at a glance even in peripheral vision, which is the
actual requirement for a card frame.

**And D-08's wording should be tightened from a colour to a ramp:**

> The warm ramp (`EMBER`, `FLAME`, `SPARK`, `EMBER_MID`) is reserved for Mana and Overload.
> The red ramp (`BLOOD`, `RED`, `ROSE`) means damage. Nothing else may use either.

As written, the rule reserves one hex value, which is why `EMBER_DEEP` slipped through without
technically breaking anything. A rule that a script or a reviewer can apply has to name the family.

**Fallback if `BLOOD` reads too close to the enemy sprites**, which currently use `RED e43b44`:
`RUST 733e39`, a dark iron-brown that is thematically right for a forge game and unmistakably not
the gauge. It is muddier against `GROUND 181425` and may need a lighter outline.

**Risk.** `BLOOD` against red enemy sprites could make the hand read as "enemy-coloured". This is
the one item here that is settled by looking rather than measuring: render the combat screen with
both options and compare. That is a five-minute screenshot job, not a simulation.

**D-08 is OPEN**, so tightening it costs nothing procedurally. Worth doing in the same pass that
locks the palette file.

---

## What this amends

- **D-12 (LOCKED)** — enemy HP bands, boss HP, starting deck composition, and the draw rule if the
  scaling draw is accepted. Needs rewriting, not a footnote.
- **D-17 (VERIFIED)** — "Map is a 15×7 layered DAG" becomes 7×5 with a different row schedule and
  two new guarantees. The verifying tests move with it.
- **D-08 (OPEN)** — reservation widens from one colour to two ramps.
- **D-18** is untouched but gets easier to answer: a 7-node act is roughly one sitting, which is
  the length a "is this fun?" playtest actually wants.

## What the harness should measure first

1. Share of runs reaching the boss, and where the deaths cluster by stage.
2. Mana wasted per turn, by turn number — the number that decides whether the scaling draw is
   needed or whether the waste is tolerable.
3. Share of runs affording two or more shop items on arrival.
4. Share of paths that include an elite, given the at-least-one-node guarantee.
