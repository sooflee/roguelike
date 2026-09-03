# Emberwright — Design Document

## Premise

A Slay the Spire–structured roguelike deckbuilder. Draft cards, climb a procedurally generated
node map, fight turn-based card combat, die, repeat.

Structure is deliberately Spire-faithful. The differentiator is the class.

## The class: The Emberwright

A forge-worker who runs their body hot.

### The Mana curve

Mana is both the cost of every card and the thing the class plays games with. It opens at **1**
and climbs by one at the start of each turn to a ceiling of **5**, so the shape of a combat is
fixed before you draw a card: turn one is a single cheap play, turn five is a full hand.

The class earns its identity by breaking that curve in two directions.

| Verb | Rule |
|---|---|
| **Ramp N** | Permanently raise this combat's refill by N, never past the cap. Grants no Mana on the turn it is played. |
| **Overload N** | Gain N Mana now and owe N. Every refill is reduced by the whole outstanding debt, and only 1 is written off per turn. |
| **Overloaded:** | Cards with this clause gain a bonus for as long as you still owe Mana. |

**The interest is the mechanic.** Because the debt is charged in full every turn and pays down
only one point a turn, borrowing N costs **N + (N−1) + … + 1** in total:

| Borrow | Total cost | Turns in debt |
|---|---|---|
| 1 | 1 | 1 |
| 2 | 3 | 2 |
| 3 | 6 | 3 |
| 4 | 10 | 4 |

Dabbling is nearly free; living in debt is ruinous. That curve is what makes the *size* of a
borrow a decision rather than a formality — and it is why the debt was changed from
charged-once-and-cleared, which priced N Mana now at exactly N Mana later. A loan at nought per
cent is always worth taking, so the old rule asked no question at all. See D-27.

**Why it works.** Ramp and Overload pull in opposite directions on the same dial, so every turn
asks the same legible question: *spend now, invest for later, or borrow against later?* Ramp is
strongest on turn one and worthless at the cap; Overload is available every turn but always
charges for it. Neither is ever the automatic answer.

Carrying debt also keeps every `Overloaded:` card switched on, so the archetype is a **stance you
pay rent on** rather than a one-turn combo: a debt of 3 buys three turns of bonuses and costs six
Mana. `Quench` and `Slack Tub` are then real decisions, because writing off the debt also switches
the payoffs off.

It also *is* a visual — pips that light, spend and lock, an alarm strike-through showing exactly
how much smaller next turn is, embers while you are in debt — which is the whole reason it earns
its place in a game whose stated goal is great animation.

### Archetypes

1. **Arrive early** — ramp on turn one and play a bigger curve than the fight expects. Payoff
   cards: `kindle`, `stoke`, `kindling`, `forge_master`.
2. **Burst and pay** — overload into a turn the enemy cannot answer, then survive the hangover.
   Payoff cards: `bellows`, `last_ember`, `crucible`, `overdrive`, and every `Overloaded:` card.
3. **Cash out** — treat leftover Mana as a resource in itself rather than waste. Payoff cards:
   `vent`, `temper`, `quench`.

Zero-cost cards (`ember_jab`, `flare`) are load-bearing for archetype 2: a deep debt can leave a
turn with almost no Mana, and they are what stops that turn being blank.

`afterburn` deliberately bridges 2 and 3: it rewards the *act* of borrowing rather than the size
of the debt, so it plays in both and gives the draft a genuine branch point rather than a lane
assignment. `quench` is the release valve that makes archetype 2 draftable at all — without a way
to write off the debt, one greedy turn just loses the next one.

## Numbers

| Stat | Value |
|---|---|
| Player HP | 75 |
| Mana | 1 on turn 1, +1/turn, cap 5 |
| Hand size | 5 |
| Max hand | 10 |
| Starting deck | 3× Strike, 1× Defend, 1× Kindle (5 cards) |
| Opening draft | 5 picks of 3, one card each, before the first fight |
| Act 1 enemy HP | 8–34 |
| Mana refill floor | 1 (enemies can drain the curve, never past this) |
| Act 1 elite HP | 44–58 |
| Boss HP | 120 |

## Enemies pose problems, not damage

An enemy that rolls "attack or block" behind a weighted die is a damage faucet: the player reads
the intent to price their Block and never changes plan. Every Act 1 enemy used to be exactly that.
Three data-driven levers turn one into a puzzle, and each Act 1 enemy now uses at least one. See
D-28.

| Lever | What it buys |
|---|---|
| **`opening`** | A fixed sequence of moves on the first turns. Learnable, so knowledge carries between runs. The Cracked Golem always guards, then swings. |
| **`condition`** | A move that is only legal in a state the player can see and control — HP threshold, turn number, whether the player is carrying debt. The enemy argues with the player's choices instead of rolling dice at them. |
| **`passives`** | Effects that resolve at the start of its turn regardless of intent, after Block clears. This is how an enemy poses a *standing* problem — a guard that always comes back — rather than a per-turn one. |

Every move may also carry a **`tell`**: a short phrase shown on the intent line. A move that eats
your Mana refill and a move that applies Weak both rendered as "ATTACK 4 + weaken" otherwise,
which teaches the player nothing until it has already happened to them.

### What each new enemy asks of you

| Enemy | The question |
|---|---|
| **Coal Thief** | *Can you kill it before it eats your curve?* Its opening move always drains 1 Mana refill, permanently for the fight, and it hides behind Block once hurt. Ramp becomes repair, not just greed. |
| **Damper** | *Is this turn worth the debt?* Its two nasty moves are both gated on `player_overloaded`, so it prices Overload directly, and `Dampened` stops the debt paying itself down. |
| **Kiln Hound** | *Did you put damage on the board this turn?* `Simmer 2` grows it every turn it is left alone, so blocking and waiting for a better hand stops being free. |
| **Slag Shell** | *Can you land one big turn?* A passive restores 7 Block every turn, so a big turn is worth about three chip turns. It drops its guard and hits for 14 below half HP. |

Two statuses carry these: **Dampened** (your Overload stops paying down) and **Simmer** (this
enemy grows unless you damaged it since its last turn). Both are the first statuses in the game
aimed at the *class mechanic* rather than at the damage numbers.

The existing roster gained openings — Cracked Golem, Forge Warden, Slag Titan and the boss — and
the boss gained a second half: below 45% HP it can play `white_heat`, which Dampens, turning the
back end of the fight into a question about your debt.

## Map

**8 stages, and the last stage is the boss.** Seven generated stages of 7 lanes, 4 seeded paths,
layered DAG, read **left to right**: stage 0 at the left edge, the boss at the right.

- Stage 0 is always Combat.
- Stage 3 is always Treasure — the act's one guaranteed windfall.
- Stage 6 is always Campfire (guaranteed rest before the boss).
- Stage 7 is the boss, and every stage-6 node leads to it.
- No Elite or Campfire before stage 2.
- No Campfire directly after a Campfire, no Elite directly after an Elite.
- Edges may not cross.

Four paths rather than six: across seven stages, six paths fill nearly every lane and the map
stops offering a choice, because everything reaches everything.

## Content status

| Content | Count |
|---|---|
| Cards | 31 (3 starter, 12 common, 12 uncommon, 4 rare) |
| Enemies | 12 normal, 2 elite, 1 boss |
| Encounters | 4 easy, 7 normal, 3 elite, 1 boss |
| Statuses | 9 (Strength, Dexterity, Vulnerable, Weak, Frail, Kindling, Afterburn, Dampened, Simmer) |
| Relics | 16 (1 starter, 5 common, 6 uncommon, 2 rare, 2 boss) |
| Potions | 11 (6 common, 4 uncommon, 2 rare) |
| Events | 8, 23 choices |

Target for a full Act 1 draft is ~75 cards. The 31 here cover all three archetypes end to end,
which is enough to answer the Phase 1 question: *is this fun as coloured rectangles?*

## Run economy

| Source | Gold |
|---|---|
| Normal combat | 10–20 |
| Elite | 25–35 |
| Treasure | 45–65 |
| Boss | 95–105 |

Card reward weights: common 60, uncommon 37, rare 3. Potion drop chance 40%. Elites always drop a
relic; the boss drops a boss relic; treasure has a 50% relic chance. Shop prices carry ±10%
variance; card removal starts at 75 gold and rises 25 per use across the run.

Rest heals 30% of max HP. Potions are free to use and playable at any point in your turn — gating
them behind Mana removes the reason they exist.

## Balance signal

`test_full_run_simulation` walks six runs with a deliberately dumb greedy policy (play anything
legal, take the first reward, choose the first event option). A policy that bad clearing roughly
half its runs is about the right Act 1 difficulty — but this is a smoke signal, not tuning data.
Real numbers come from playtesting.

`tests/balance.gd` is the sharper instrument: it plays the same encounters with a bot that never
touches Ramp or Overload and a bot that plays the class as intended, and the gap between them is
the only machine-checkable evidence about the class mechanic.

**Read that gap with care since D-27.** At 40 runs on fixed seeds:

| Policy | Reaches boss | Kills boss | Mana borrowed | Turns in debt |
|---|---|---|---|---|
| greedy | 100% | 65% | 282 | 32% |
| curve-blind (never ramps or overloads) | 100% | 62.5% | 0 | 0% |
| curve-aware | 95% | 45% | 520 | 58% |

Curve-aware losing to curve-blind is **not** evidence the class is worthless. Overload's value is
entirely *what does this borrow unlock, and is that worth the interest* — and no policy in the
harness can answer the first half, because none of them can value a card: the bot plays the first
legal card in hand order, so "unlocking" one means playing an arbitrary card a turn early. Under
the old nought-per-cent loan that was free. Under interest it loses.

What the numbers do establish is that **there is now a wrong way to play Overload**, and the
harness can detect it. Before D-27 nothing was punished, so no bot could be wrong. Demonstrating
a *right* way needs either a bot that evaluates cards or the human playtest D-18 is waiting on.

The other thing these numbers say plainly: **Act 1 is soft.** A greedy bot reaches the boss on
100% of runs and kills it on 65%. That was true before this work and is unchanged by it — the
enemy additions raise the ceiling on how badly a fight can be misplayed, not the floor. Retuning
is `docs/proposals/balance-baseline.md`'s job, not this change's.

## Not yet built

Acts 2–3 · meta-progression · a second and third class · card art · a settings screen.

Card upgrade previews, potion discarding and run-state-dependent event choices are now in; the
three remaining items above are all gated on D-18, the Phase 1 fun gate.
