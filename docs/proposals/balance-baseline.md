# Balance baseline — first measured numbers

Produced by `./tools/balance.sh all` (60 runs per policy, fixed seed set, `tests/balance.gd`).
This run **establishes** the baseline. No game numbers were changed to produce it, and none should
be changed on the strength of it without re-running.

Context: the act was halved (15 stages to 8, D-17) and the class was replaced (Heat to Mana,
D-11) without retuning anything. Until now the entire balance signal was one line reading
"2 of 6 runs killed the boss".

---

## 1. Headline

| Policy | Boss reached | **Boss killed** | Turns/fight | Turns at Mana cap |
|---|---|---|---|---|
| `greedy` — plays anything affordable | 98.3% | **53.3%** | 4.89 | 53.6% |
| `curve-blind` — never plays Ramp or Overload | 100.0% | **36.7%** | 5.09 | 39.5% |
| `curve-aware` — ramps early, overloads to unlock | 96.7% | **46.7%** | 4.91 | 65.0% |

**Reaching the boss is not a filter.** 98–100% of runs arrive. Every run is decided in one fight.

### The curve-blind gap: +16.6 points

A bot that never touches Ramp or Overload kills the boss 36.7% of the time. The same bot allowed
to play them kills it 53.3% of the time. **The two verbs are worth roughly seventeen points of win
rate**, which is the first evidence that the class mechanic pays for its own complexity. That is a
partial, machine-checkable answer to D-11 — partial because it says the verbs are *strong*, not
that using them is an *interesting decision*, which only a human can judge.

### `curve-aware` is worse than `greedy`, and that is a fact about the harness

The hand-written "smart" policy loses 6.6 points to the dumb one. The honest reading is that the
heuristic is bad, not that thinking is bad: it withholds Ramp after turn 3 and at the cap, and
spends actions on Overload to unlock cards that were not worth unlocking. **Do not read
`curve-aware` as a skill ceiling.** It is a third data point, and mainly it demonstrates that
"play everything" is a strong policy in a game with 4.9-turn fights.

---

## 2. Three findings worth acting on

### 2.1 Ramp does nothing 58.5% of the time — SOLID

598 Ramp plays across 60 runs; **58.5% moved the ceiling by zero.** The card cost Mana, left the
hand, and had no effect. `curve-aware`, which actively tries to avoid this, still wastes 35.4%.

The cause is structural, not a bug: 53.6% of all turns are already at the Mana cap. With Forge
Mark the real curve is 2, 3, 4, 5, 5, 5… and fights last 4.89 turns. Ramp is live for roughly the
first three turns of a fight and dead for the rest, silently.

Stoke — "Ramp 2. Exhaust." — is the sharpest case: at the cap it costs a Mana, exhausts itself,
and does literally nothing. It is played 26 times per 60 runs at a 67% rate, so the policy cannot
tell either.

This is the same defect the first-player report reached independently from the other direction.

### 2.2 The cash-out archetype has no fuel — SOLID

**Average unspent Mana at end of turn: 0.13.** Effectively zero. Vent and Temper convert leftover
Mana into damage or Block, and there is no leftover Mana to convert. They are played (75% when
affordable) because they are *cards*, not because the archetype functions.

D-11 names "cash out" as one of three archetypes. On these numbers it does not exist.

### 2.3 Pacing is flat, then a cliff — SOLID

Median HP on leaving each stage:

| Stage | 0 | 1 | 2 | 3 | 4 | 5 | 6 (campfire) | 7 (boss) |
|---|---|---|---|---|---|---|---|---|
| HP | 70 | 70 | 60 | 60 | 54 | 48 | 73 | **3** |

Deaths by stage: **stage 7 — 27. Stage 5 — 1. Everywhere else — zero.**

Stages 0–6 cost 27 HP over seven nodes and then hand almost all of it back at the guaranteed
campfire. The boss then removes 70 HP and kills 45% of arrivals. The act is a walk followed by a
coin flip, and no decision made during the walk is under enough pressure to matter.

The guaranteed campfire at stage 6 (D-17, `REST_ROW`) is doing most of this: it erases the
attrition the preceding seven stages were supposed to create.

---

## 3. Cards

Sorted least-played first — the top of the list is where dead weight lives.

Nothing is unplayable. The lowest play rates belong to expensive cards that are genuinely
sometimes unaffordable (`molten_strike` 52%, `crucible` 67%, `immolate` 58%), which is a cost
curve working, not a dead card.

`last_ember` was seen twice in 60 runs and `crucible` twelve times. Rares are too rare to measure
at this sample size; raise `--runs` before drawing any conclusion about them.

**Accounting caveat:** `flare` reports `played=23, affordable=22` — 105%. Hand contents are
sampled once per turn after the draw, so a card drawn *mid*-turn by a draw effect can be played
without ever being sampled. Play counts for cheap cards in a draw-heavy deck are therefore
slightly understated in the denominator. It does not affect the aggregate metrics.

---

## 4. What this does not tell you

- **Whether any of it is fun.** D-18 and the interesting half of D-11 are unanswerable here.
- **Anything about a competent player.** All three policies are crude. `curve-aware` losing to
  `greedy` is proof of that, not of anything about the game.
- **Anything about rares.** Sample size is far too small at 60 runs.
- **Anything about the shop or potions.** The harness buys shop card index 0 and never uses a
  potion, so both are effectively untested surfaces.

## 4b. Holdout check — the findings hold, the win rate does not

`SEEDS=holdout RUNS=20 ./tools/balance.sh greedy`:

| Metric | Fixed (60) | Holdout (20) |
|---|---|---|
| Boss killed | 53.3% | **75.0%** |
| Ramp wasted | 58.5% | 61.5% |
| Avg unspent Mana | 0.13 | 0.12 |
| Turns at cap | 53.6% | 51.8% |

**Win rate is strongly seed-sensitive and 20 runs is too few to trust** — treat 53% and 75% as the
same statement, "the boss is roughly a coin flip", and do not tune against the difference.

The three structural findings, by contrast, reproduce almost exactly across disjoint seed sets.
Ramp being dead most of the time and there being no leftover Mana to cash out are properties of
the design, not of a lucky map. Those are safe to act on. The win rate is not, yet.

## 5. Method

- `tests/balance.gd`, run head­less via `tools/balance.sh` with the same timeout guard as
  `tools/test.sh` (a parse error otherwise hangs forever with no script attached).
- Fixed seed set `70000 + 13n`; disjoint holdout set `910000 + 17n` via `SEEDS=holdout`. Tune
  against the fixed set, confirm on the holdout, because numbers tuned against fixed seeds
  eventually describe those seeds.
- Card traits are read from the effect objects themselves, not a hand-kept list, so the policies
  cannot drift out of step with `data/cards/emberwright.json`.
