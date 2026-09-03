# Decision log

Twenty-nine decisions behind Emberwright: what was chosen, what was rejected, and what each would
cost to reverse. Readable version: the published artifact. Amend entries in the same commit that
changes the decision.

**Status** — `LOCKED` decided and in code · `OPEN` needs a call · `DEVIATION` departs from the
approved plan · `VERIFIED` covered by a passing test.

**Cost to reverse** — measured from today; several rise steeply once the art pass begins.
`1` an afternoon · `3` a refactor · `5` start over.

---

## Foundations

### D-01 — Roguelike deckbuilder, Slay the Spire structure · LOCKED · reverse 5
Draft cards, climb a generated node map, turn-based card combat, permadeath. Structure
deliberately faithful; originality goes into the class.

Rejected: *action roguelite* (animation-hungry in a way a solo dev pays for daily),
*turn-based grid* (animation is decoration there, not substance), *tactical* (closest runner-up).

**Why.** The one genre where "great animations" and "solo, pixel art" don't fight. Enemies are
static illustrations with short idle loops, so animation means card motion and UI feel — not
12-frame run cycles.

### D-02 — Godot 4.7.2, GDScript · VERIFIED · reverse 5
Tweens, `AnimationTree`, `GPUParticles2D` and shaders in the box; desktop and web export.

Rejected: *TypeScript + PixiJS* (you'd hand-build the animation system, audio bus and particles),
*LÖVE* (no batteries), *Unity* (heaviest iteration for least benefit at this scale).

### D-03 — One class now, commercial game as the ambition · LOCKED · reverse 1
Act 1 with a single class; architecture built so classes two and three are content work.
Cards, enemies and encounters are JSON assembled from composable effects — see D-14, D-16.

### D-04 — No budget until wishlists justify one · LOCKED · reverse 1
Free and CC0 tooling throughout. Spending gates on ~1,000 wishlists off a demo.
Forces D-18 to be answered honestly: money spent before the game is proven buys polish on an
unproven core.

---

## Art direction

### D-05 — Pixel art · AMENDED by D-29 · reverse 4
Hand-drawn, locked palette, locked canvas grid.

Rejected: *painted illustration* and *ink/woodcut*, both far more reproducible from AI generation.

**Note, recorded honestly.** I argued against this — it pairs badly with an AI-assisted pipeline.
You reaffirmed, so it's the decision, and D-06 resolves the conflict rather than papering over it.
The consequence is real: art is now the critical path for every feature.

### D-06 — AI for reference only; every shipped pixel hand-drawn · LOCKED · reverse 2
AI generates concept boards, silhouettes, composition and colour studies. No AI-generated raster
ships, in whole or in part.

Rejected: *AI-assisted pixel tools* (PixelLab, Scenario) — viable, but they require Steam
disclosure and daily palette policing.

**Why.** Two reasons pointing the same way. AI output is pseudo-pixel — off-grid, anti-aliased,
palette-exploded past 200 colours — so it needs near-total redraw anyway. And Steam's
**17 January 2026** rewrite narrowed disclosure to player-facing shipped content, explicitly
exempting concept-art ideation whose output doesn't ship, plus AI code assistants. This pipeline
needs **no AI disclosure**. See `docs/STEAM_DISCLOSURE.md`.

### D-07 — 960×540 base, integer-scaled · LOCKED · reverse 5
Doubles to exactly 1920×1080. Viewport stretch, aspect `keep`, integer scaling on, nearest filter.

Rejected: *640×360* — cards land near 64×88, forcing a 5px font. Rules-text readability is the
known killer in pixel card games.

**The most expensive decision here to revisit.** Every sprite is bound to it.

### D-08 — A 32-colour locked palette · AMENDED by D-29 · reverse 2, rising
Thirty-two colours, one `.gpl`, no exceptions. Ember orange **reserved** for the Mana gauge and
the Overloaded state so "this is the resource" always reads at a glance.

Pending: Endesga-32 recommended; DawnBringer-32 and AxulArt-32 are alternatives. Verify the
licence on the individual palette page — Lospec licensing is per-palette, not site-wide.

Enforced by `tools/check_art.py`; dimensions-only until the palette lands.

### D-09 — Sprite dimensions and the 8px grid · LOCKED · reverse 4
Enemies 64², elites 96², bosses 128², cards 96×132 with an 80×56 art window, status icons 16².
Everything snaps to 8px. Light source top-left on every asset. 1px outlines in a dark palette
colour, never pure black. No dithering below 2px cells. Hue-shift when shading.

**Why.** Consistency comes from constraints written down before drawing. Inconsistent light
direction is more visible than a wrong colour.

---

## Audio

### D-10 — Licensed library now, commissioned composer later · LOCKED · reverse 1
Phase 1 on CC0 and royalty-free: Kenney (CC0, no attribution), Sonniss GDC 2026 bundle (7.47 GB,
unlimited projects, lifetime), OpenGameArt and Pixabay filtered to CC0.

Rejected: *AI-generated music* (commercial rights vary sharply by service, triggers Steam
disclosure, OST quality is a recurring review complaint), *commissioning now* (right later, wrong
before the game is proven).

**Hard rule.** "Royalty-free" is not "free to embed in a game." Many standard tiers cap copies or
exclude game embedding outright. Every file gets a licence row in `assets/audio/LICENSES.md` at
download time, not later.

First five SFX: card draw, card play, hit impact, block gain, intent reveal.

---

## The class

### D-11 — The Emberwright, built on a Mana curve with Ramp and Overload · OPEN · reverse 3
Mana is the cost of every card and the class's whole identity. It opens at 1, climbs by one a
turn to a cap of 5, and the class breaks that curve in two directions: **Ramp N** permanently
raises the refill (and grants nothing the turn it is played), **Overload N** hands you Mana now
against a debt that shortens every refill until it is paid off. Cards marked **Overloaded:** pay
a bonus for as long as you carry that debt. The debt's repayment schedule — and with it whether
Overload is a decision at all — is D-27, which amended this entry.

**Why.** Ramp and Overload pull opposite ways on one dial, so every turn asks the same legible
question — spend now, invest for later, or borrow against later? Ramp is strongest on turn one
and worthless at the cap; Overload is always available and always charges. Neither is ever the
automatic answer. And it *is* a visual: pips that light, spend and lock, an alarm strike-through
sizing next turn's shortfall, embers while in debt.

Archetypes: arrive early (ramp turn one), burst and pay (overload into an unanswerable turn),
cash out (`vent`/`temper` turn leftover Mana into damage or Block). `afterburn` bridges the last
two by rewarding the *act* of borrowing rather than the size of the debt. `quench` is the release
valve that makes the burst archetype draftable — without a way to write off debt, one greedy turn
simply loses the next.

**Replaced a Heat gauge**, the original proposal: a 0–10 bar with a Stoked threshold at 6 and an
Overheat penalty at 10. Heat was a second resource sitting beside a flat 3 energy; folding the
class's identity into the resource it already had removes a bar from the HUD and makes every card
cost part of the mechanic rather than a tax paid before it. Heat was retired before it was ever
playtested, so nothing was learned from it and nothing is owed to it — but it is worth recording
that the class has now had two identities and neither has yet passed D-18.

**Still a proposal**, built so there is something to playtest.

### D-27 — Overload is a debt that carries interest · VERIFIED · reverse 2
Overload N hands over N Mana and adds N to a debt. Every refill is reduced by the **whole
outstanding debt**, and only **one point** is written off per turn — so borrowing N costs
N + (N−1) + … + 1 in total: 1 costs 1, 2 costs 3, 3 costs 6, 4 costs 10. `Overloaded:` clauses
read the debt, so they stay switched on for as many turns as it runs.

**Why.** The original rule charged the debt once and wiped it: N Mana now for exactly N Mana
next turn. That is a loan at nought per cent, and a loan at nought per cent is always worth
taking — so the mechanic the class is named for asked no question. Worse, `Overloaded:` could
only ever be live on the turn the debt was taken, which made the whole archetype a one-turn combo
with a rebate rather than a gamble.

Charging interest fixes both at once. The size of a borrow becomes a real decision, because the
cost curves up sharply while the benefit does not. And carrying debt becomes a **stance you pay
rent on**: a debt of 3 keeps every `Overloaded:` card live for three turns and costs six Mana. That
is what finally gives `quench`, `slack_tub` and `quenching_oil` a job — writing the debt off also
switches the payoffs off, which is a decision rather than a safety net.

**Rejected: paying down half the debt each turn.** Gentler and more forgiving, but the interest
curve flattens out exactly where the interesting risk lives (3 costs 4 instead of 6), and "half,
rounded down" is harder to hold in your head mid-turn than "one a turn".

**Consequences accepted.** A deep debt can leave a turn with no Mana at all. Zero-cost cards are
what stop that being a blank turn, which gives `ember_jab` and `flare` a role they did not have.
`last_ember` was retuned from Overload 4 (now a ten-Mana bill) to Overload 3.

The gauge had to change with it: the debt no longer vanishes when charged, so it draws the refill
the debt is currently eating and states how many turns are left to run. A cost the player cannot
see coming is not a decision they made.

### D-28 — Enemies are puzzles, expressed as data · VERIFIED · reverse 2
Enemy behaviour gains three levers, all in JSON: **`opening`** (a fixed move sequence on the first
turns), **`condition`** (a move that is only legal in a visible state of the fight — HP threshold,
turn number, whether the player is carrying debt) and **`passives`** (effects resolved at the start
of its turn regardless of intent, after Block clears). Moves may also carry a **`tell`**, a short
phrase rendered on the intent line.

**Why.** Every Act 1 enemy was one attack move and one block-or-buff move behind a weighted die.
Nothing in the roster ever made the player change plan: you read the intent to price your Block
and played your best cards in descending order. The enemies that make Act 1 of a deckbuilder
memorable each impose a small rule that invalidates the default line — and none of ours did.

Critically, **nothing in the roster interacted with Ramp or Overload**. The class mechanic was
purely self-facing, which meant Ramp was only ever a greed play. `Coal Thief` drains the refill
itself and `Damper` gates its worst moves on `player_overloaded`, so both halves of the curve are
now things the *fight* argues with.

`tell` exists because a move that eats your Mana refill and a move that applies Weak both rendered
as "ATTACK 4 + weaken". A mechanic the intent line cannot name is a mechanic the player only
learns by being hit with it.

**Rejected: hard-coding behaviours in GDScript subclasses.** Faster for the first enemy and worse
for the twentieth; it would also have put enemy rules outside the JSON that D-14 says content
lives in, and outside the integrity test that now checks every opening names a real move and every
condition names one the engine evaluates.

### D-12 — Baseline numbers · LOCKED · reverse 1
75 HP · Mana 1→5 · draw 5 · deck of 3 Strike, 1 Defend, 1 Kindle (five cards), plus a
**pre-run draft of five picks, one card each**, before the first fight — so a run reaches its
first combat on ten cards, half of them chosen.

The starting five are near-identical, so without the draft every run opened on the same fight and
the player's first decision did not arrive until after it. It also gives the card art, the hover
panel and the two keywords somewhere to be met that cannot kill anyone. Act 1 enemies 8–34 HP, elites
44–58, boss 120. Enemy numbers are deliberately Spire-adjacent so playtest signal is about the
Mana curve, not tuning noise — but they were tuned against a flat 3 energy, and a curve that opens
on 1 makes the first two turns markedly harder. The autoplay simulation went from 3 of 6 runs
reaching the boss to 2 of 6 on the same seeds. **Unretuned; this is the first thing to measure.**

A six-card deck against a hand size of five draws all but one card on turn one, so which card you
miss is a coin flip and shuffle order barely matters until the deck grows. It also means turn one draws five cards and can afford one, and the waste only
stops on turn five. `docs/proposals/act1-shortened.md` argues for scaling draw to the curve
instead; that would amend this entry.

---

## Architecture

### D-13 — The simulation never awaits the view · VERIFIED · reverse 5
`Combat` resolves state instantly and synchronously, pushing `VisualEvent` records onto a queue.
The view drains that queue and animates at whatever speed it likes.

**Why.** This is what makes "great animations" achievable rather than a bug farm. Interleave the
two — `await tween` inside damage calculation — and you get race conditions, unskippable
animations, corrupt saves and untestable combat.

**Proof.** The whole suite runs headlessly with no display. Only possible because the rules engine
has no nodes in it. Animations can also be sped up or skipped wholesale, which matters on a
hundredth run.

Retrofitting this is a rewrite. Baked in from the first commit for that reason.

### D-14 — Content in JSON, not `.tres` · DEVIATION · reverse 2
The approved plan specified `.tres`. This is the one place the build diverges from sign-off.

**Why.** Hand-writing `.tres` with nested `Array[CardEffect]` sub-resources is error-prone,
unreadable in a diff, and can't be loaded in a headless test without the editor. JSON is
reviewable, editable outside Godot, and testable.

Runtime objects are still `Resource`s, so a `.tres` pipeline stays possible without touching
effect code.

### D-15 — Independent named RNG streams · VERIFIED · reverse 3
Separate generators for map, shuffle, rewards, shop, events, enemy AI and cosmetics, each seeded
from a hash of the run seed and the stream name.

**Why.** Share a stream and drawing one extra card changes the map. Runs stop being reproducible,
seeded bug reports become worthless, daily seeds are impossible. Godot's `Array.shuffle()` uses
the global RNG and is banned here.

### D-16 — Cards are arrays of composable effects · VERIFIED · reverse 3
Twelve effect types — damage, block, status, draw, mana, ramp, overload, clear_overload,
spend_mana, heal, conditional, add_card — resolving against a shared context. Overloaded is a
`conditional` wrapper, not a special case in the resolver. Enemies run the same effect objects the player does, so combat rules exist
in exactly one place.

### D-17 — An act is 8 stages, read left to right, and the last stage is the boss · VERIFIED · reverse 1
Seven generated stages of 7 lanes plus the boss. Four seeded paths walked forward, drifting at
most one lane per step; crossing edges rejected. Stage 0 always Combat, stage 3 always Treasure,
stage 6 always Campfire, stage 7 the boss. No Elite or Campfire before stage 2. No Campfire
directly after a Campfire.

**Why.** Crossing edges turn the map into a hairball. Back-to-back rests trivialise the attrition
the run structure is built on. Tests assert every node is reachable from the start, and that a
full path from stage 0 to the boss is walkable.

**Was 15 rows × 7, six paths, drawn bottom-to-top as a climb.** Shortened so a whole run is
playable in one sitting — which is what makes the D-18 fun gate answerable at all, since nobody
judges a mechanic they never finished a run with. Four paths rather than six because seven stages
at width seven fills nearly every cell and choice degrades into noise. Left-to-right because a
journey reads as a journey and the screen is 960×540: depth belongs on the long axis.

**The shortening invalidated numbers it did not touch.** Half the nodes means half the attrition,
half the gold and half the deck growth, against enemies tuned for the old length. Autoplay went
from 2 of 6 runs reaching the boss to 5 of 6, and 2 of 6 killing it. `docs/proposals/act1-shortened.md`
carries the retuning proposal; none of it is applied.

### D-24 — Card text is generated from the effects; the authored copy is a checked mirror · VERIFIED · reverse 2
`CardData.describe(upgraded)` builds a card's text by asking each effect to describe itself. The
authored `text` in JSON stays, and a test asserts the two agree exactly for all 31 cards at base
rank.

**Why.** An upgraded card has to be readable before it exists — on the reward screen, and at the
campfire where the player is choosing whether to spend the upgrade at all. Authoring a second
`upgraded_text` per card is 31 more strings to keep in sync with numbers that move during tuning,
and the failure is silent: the card reads 6 and hits for 9.

Generating it means the text cannot disagree with the effects. The authored copy is kept anyway
because generated prose is worse prose, and it is the thing the drift test pins the generator
against: change a number in JSON and forget the text, or teach an effect a new trick without
teaching it to describe itself, and the suite fails instead of the reward screen lying.

Building it surfaced a live bug — `card_view.gd` drew `data.text` for every card in hand, so an
upgraded Strike+ read "Deal 6 damage" while dealing 9 — and two cards whose text was wrong rather
than vague. "Stoked: deal 3 more" described a *separate* hit that re-runs the damage pipeline, so
with Strength it beats +3 on one hit; Forge Guard's "gain 3 more" is a second Block gain that
Dexterity buffs twice. Both now say what they do.

### D-25 — Event choices declare what the run must already have · VERIFIED · reverse 1
A choice may carry a `requires` block (`gold`, `hp_above`, `deck_above`, `upgradeable_card`,
`free_potion_slot`, `relic`). Unmet, the option is shown greyed with its reason. `EventLibrary`
refuses it too, not just the screen.

**Why.** `lose_gold` takes only what is there, so "Lose 60 gold. Obtain a relic." handed a broke
player a free relic — the same hole in three of the eight events. Requirements close it in data
rather than in a special case per event, and they also stop an event killing anyone: a choice that
costs HP is offered only while you can survive it.

Enforced in the rules layer because a gate the UI owns is only as strong as the screen drawing it.
The authoring rule is that no run state may lock *every* choice of an event, which is asserted
against a deliberately destitute run rather than trusted.

### D-26 — Dev shortcuts resolve through the real path, and are off unless asked for · VERIFIED · reverse 1
`Dev.is_enabled()` is false unless the game is launched with `--dev`. When it is on, combat gets a
"DEV: win fight" button. `Combat.dev_win()` deals lethal damage to every enemy and lets the normal
resolution run, rather than assigning `result` directly.

**Why.** The reason to skip a fight is to test what comes *after* it — rewards, the potion swap,
the campfire, the boss handoff. A shortcut that jumped straight to `Result.VICTORY` would skip the
event queue too, so the reward screen would be reached by a route no player ever takes, and the
two would drift apart silently the moment anything in the real path changed. Going through the
real path costs one loop and keeps the shortcut honest.

Off by default rather than editor-only: `OS.has_feature("editor")` would have turned it on inside
every test and screenshot run, which is exactly where a hidden win button does the most damage.

### D-29 — Ship a CC0 art pack and a CC0 audio library instead of hand-drawn art · LOCKED · reverse 2
Creature sprites come from Kenney's *Tiny Dungeon*; sound from Kenney's *RPG Audio*. Both CC0 1.0.
Provenance in `assets/sprites/ATTRIBUTION.md` and `assets/audio/ATTRIBUTION.md`.

**Why.** D-05 made art the critical path for every feature and it stayed there: the game still
looked like coloured rectangles, so D-18 could not be judged against anything resembling the real
thing. D-04 rules out commissioning until wishlists justify it, so "hand-drawn" meant, in practice,
"not drawn". A CC0 pack is the only option that produces a game you can look at this week.

**What it costs, stated plainly.** D-09's locked sizes survive: the pack is 16×16 and scales by
whole numbers to 64, 96 and 128, so nothing lands off the grid. **D-08 does not survive.** The pack
carries its own palette and will never conform to Endesga-32, so locking `emberwright.gpl` would
now fail every sprite in the project. The palette rule drops from a conformance gate to a rule for
code-drawn UI, where it still holds and is still worth holding.

**D-06 and the Steam position are untouched.** Both packs are human-made; Steam's requirement
covers AI-generated content. `docs/STEAM_DISCLOSURE.md` stands as written.

**Satisfies D-10** on the audio side. There was no sound in the game at all before this, which was
doing more damage to how it felt than the art was.

**Not chosen:** *AI-assisted pixel tools* — still rejected, now for a second reason: they would
require the disclosure a CC0 pack does not, for output that needs redrawing anyway.

The bible is not deleted. `docs/ART_BIBLE.md` still describes the target and any hand-drawn PNG
dropped at a sprite's path still wins (D-22). This changes what ships today, not what the game is
allowed to become.

---

## Process

### D-18 — Phase 1 gate: is it fun as rectangles? · OPEN · reverse 1
No art until grey-box combat is fun. The current UI is deliberately buttons and text, built to be
thrown away in Phase 3.

**Why.** A deckbuilder that isn't fun as coloured rectangles will not be rescued by pixel art.
Finding out before twelve enemies are drawn is the difference between a redesign and a dead
project.

Waiting on twenty minutes of play and a judgement on whether the Mana curve produces an
interesting decision every turn.

### D-20 — The map is derived from the seed, never serialised · VERIFIED · reverse 2
A save stores the run seed, the current node key and the RNG stream *cursors* — not the map. The
map is regenerated on load.

**Why.** A stored map can disagree with the generator; a derived one cannot. Storing cursors as
well as the seed matters: restoring only the seed would rewind every stream to the start of the
run, so a reloaded save would re-roll rewards the player has already seen.

Only safe because map generation draws from its own stream (D-15). Round-trip asserted in tests.

### D-21 — Potions are free and playable any time in your turn · LOCKED · reverse 1
No Mana cost, no once-per-turn limit; three slots.

**Why.** Potions are the deckbuilder's safety valve — the thing that lets a player survive a draw
that betrayed them. Charging Mana makes them just bad cards, which removes the reason the
category exists. The constraint is slot scarcity, not cost.

### D-22 — Placeholder art is generated at runtime, never committed · VERIFIED · reverse 1
`src/fx/placeholder_art.gd` builds enemy, player and card sprites procedurally: a mirrored
silhouette on a 16×16 logical grid, upscaled, shaded from a palette ramp with the light top-left,
1px non-black outline. Nothing is written to `assets/sprites/`.

**Why.** The animation layer needed real sprites at the real locked dimensions to animate against,
but D-05 says every *shipped* pixel is hand-drawn. Generating them at runtime keeps both true:
`PlaceholderArt.for_enemy()` returns a hand-drawn PNG the moment one exists at the expected path,
and nothing else changes. Committing generated PNGs would instead put art in the repo that the
conformance checker would bless and a future reader would mistake for real.

### D-23 — All game feel routes through one autoload, and speed is a player control · LOCKED · reverse 2
Shake, hitstop, flash, pop, lunge and popups all live in `src/fx/juice.gd`. Playback speed is a
single multiplier with an in-game 1x/2x/4x toggle.

**Why.** Two reasons. "The game feels mushy" should be a tuning session in one file, not an
archaeology expedition through fifty scenes. And on a hundredth run the player wants the animation
they loved on run one to get out of the way — which is only possible because the simulation never
waits for the view (D-13). Playback timers ignore `time_scale` so a hitstop can never stall the
event player.

`Juice.intensity = 0` disables all motion, which doubles as a reduce-motion accessibility setting.

### D-19 — The art bible is enforced by tooling, not memory · VERIFIED · reverse 1
`tools/check_art.py` decodes every PNG with the standard library — no dependencies — and fails any
sprite with off-palette colours or wrong dimensions.

**Why.** Palette drift is the documented failure mode of pixel-art projects, and it happens one
forgivable exception at a time. A rule a script enforces is a rule; a rule in a document is a hope.

Verified against synthetic conforming and violating PNGs rather than assumed working.

---

*The published page is generated from `docs/decisions.html` in this repo. Update both together, or
they drift.*
