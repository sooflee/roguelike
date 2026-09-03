# Card art direction — 31 illustrations, 80×56

Binding: `docs/ART_BIBLE.md`. Frame 96×132, art window **80×56**, Endesga-32 only, 1px non-black
outline, light top-left, silhouette first. `EMBER` (`f77622`) is **reserved for the Mana gauge and
the Overloaded state** and may not appear in any illustration.

This document is a drawing brief. Per D-06 no pixel here is generated; it exists so a human artist
can draw a family at a time without re-deciding the conventions on every card.

---

## 1. The conventions

Six rules. Everything else is subject matter.

### 1.1 Type reads as geometry, not colour

Card frames carry type as colour, and that colour is in dispute (D-08/D-11: ATTACK frames use
`EMBER_DEEP`, which now collides with the resource). So the illustration must not depend on it.
Geometry survives a frame recolour, a colour-blind player, and a 1× screenshot.

| Type | Composition | Reads as |
|---|---|---|
| **ATTACK** | Rising diagonal, mass entering bottom-left, working end breaking the **upper-right** quadrant | Acting outward, on someone else |
| **SKILL** | Symmetric or horizontal, focal mass on the centre line, planted | Acting inward, on yourself |
| **POWER** | Vertical column filling the full 56px, base anchored to the bottom edge | Permanent; it stays on the table |

Test in solid black at 1×. If type is not obvious with all colour removed, redraw.

### 1.2 The verbs read as direction

Ramp and Overload are the class (D-11). A player must tell them apart before reading a word.

| Verb | Direction | Image family |
|---|---|---|
| **RAMP** | **Up** — bottom-anchored mass with visible empty headroom above | Fuel *added*, unlit, orderly, room left to fill |
| **OVERLOAD** | **Right** — rush leaving frame, with a hollow where it came from | Draught pulled early; something is now missing |
| **CASH OUT** | **Down** — vessel tipping, contents leaving downward, frame emptying | Spending what you already hold |

Up, right, down. Three axes, readable in silhouette.

### 1.3 `ALARM` is debt, and only debt

`ALARM` (`ff0044`) marks Overload wherever it appears — a notch, a rim-light, a crack. It already
means exactly this on the Mana gauge, where the strike-through showing next turn's shortfall is
drawn in it. Never use it as a field colour, never for damage, never on a card that does not touch
Overload. Cards with the `Overloaded:` payoff clause additionally get an `EMBER` strip along the
card bottom, drawn in code — do not draw one.

### 1.4 White-hot is `BONE`, not orange

The instinct on a forge game is to reach for orange for hot metal. `EMBER` is reserved and the
instinct is also wrong: working steel at forging heat reads white-to-straw, not orange. Hot metal
is `BONE` core → `SAND` → `CLAY` falloff. This buys the whole set its heat back without touching
the reserved colour.

`FLAME` and `SPARK` are permitted as **specular highlights only**, never as a field. They carry
the Mana gauge's particles and ramp marker; spending them as fill dilutes the gauge.

### 1.5 Counting is literal

Where a card names a number, draw that number. Ramp 1 shows one fresh fuel face; Ramp 2 shows
two. Draw 2 shows two billets. Doubling effects ("deal 8 damage again") show two overlapping
fronts. This is free legibility and it survives translation.

### 1.6 Two more markers

- **AoE** — multiple *discrete* marks, never one big shape.
- **Exhaust** — the subject's trailing edge breaking into loose 1px specks, mid-dissolve.

---

## 2. Starting deck — draw these first

The opening hand is 3 Strike, 2 Defend, 1 Kindle. All six cards on screen at fight one come from
these three drawings.

**strike** · ATTACK · 6 damage
Cross-peen hammer mid-swing. Haft rising from (12,48) to head at (66,10); head a solid ~22×18
mass breaking the upper-right. Haft `LEATHER`→`RUST`, head `INK_MID`→`INK_LIGHT`, one `BONE`
highlight cluster top-left of the head, `SHADOW` outline. **Read: the pale head mass.**

**defend** · SKILL · 5 Block
Round buckler, face-on, boss dead centre at (40,28), ~34px across. Perfectly symmetric — this is
the reference for SKILL geometry. Field `QUENCH_DEEP`, rim `QUENCH`, one `QUENCH_BRIGHT` arc
upper-left, `SHADOW` outline. **Read: the `QUENCH` rim ring.**

**kindle** · SKILL · Ramp 1, draw 1
One split log with a pale cut end, set on two smaller logs. Bottom-anchored across y=34..50,
x=18..62, dark headroom above it — that headroom *is* the Ramp signal. Logs `LEATHER`/`RUST`/
`CLAY`, the single cut end `BONE`, ground `SHADOW`. **Read: one `BONE` cut end. One, because
Ramp 1.**

---

## 3. Arrive early — the Ramp family

Bottom-anchored, headroom above, unlit fuel. No `ALARM` anywhere in this family.

**stoke** · SKILL · Ramp 2, Exhaust
Poker driving **two** fresh coals into a bed. Bottom-anchored, poker entering from the left.
Poker `INK_MUTED` with its tip breaking into specks (Exhaust); coals `SHADOW`/`RUST` with two
`BONE` fresh faces; bed `CLAY`. **Read: two `BONE` faces.**

**kindling** · POWER · Ramp 1 every turn
Vertical woodpile filling all 56px, round cut ends repeating up the stack, clear space at the very
top. Logs `LEATHER`/`RUST`/`CLAY`, ends `BONE`, gaps `SHADOW`. **Read: repetition up a column —
repetition is what says "every turn".**

**forge_master** · POWER · 2 Strength + Ramp 1 every turn · RARE
Master's standard: tall pole, `RED` pennant at the top, stacked fuel at the base with `BONE` cut
ends. Two effects, two zones. Pennant `RED`, anvil `INK_MID`, base `LEATHER`/`BONE`.
**Read: `RED` top over `BONE` base.**

---

## 4. Burst and pay — the Overload family

Rightward rush, a hollow left behind, one `ALARM` accent carrying the debt.

**bellows** · SKILL · Overload 2, draw 1
Great bellows compressed hard past its stop. Accordion pleats fill the left; air rushes right; an
`ALARM` notch sits where the stop should be. Pleats `LEATHER`, frame `RUST`, rush `INK_LIGHT`.
**Read: the accordion pleats — the most recognisable forge object after the anvil.**

**tongs** · SKILL · draw 2, Overload 1
Tongs pulling **two** billets from the fire at once. Tongs from the left, two small billets right.
Tongs `INK_MUTED`, billets `BONE`, `ALARM` at the pivot. **Read: two billets = draw 2.**

**overdrive** · ATTACK · 6 damage, Overload 2
Bellows handle slammed fully down, past its travel, with an `ALARM` gap where the stop broke away.
Rightward. `LEATHER` bellows, `RUST` frame. **Read: the `ALARM` gap.**

**second_wind** · SKILL · Overload 1, draw 2, Exhaust
Face grate breathing out, edges dissolving. Centred grate, outward puff, one grate bar `ALARM`.
Grate `INK_MUTED`, breath `INK_LIGHT`. **Read: the grate bars.**

**crucible** · ATTACK · 20 damage, Overload 2 · RARE
Crucible tipped, pouring a heavy white stream down-right. Crucible upper-left, stream diagonal to
the lower-right corner — the thickest single mass in the set, because it is the biggest number.
Crucible `RUST`/`SHADOW`, stream `BONE`→`SAND`, `ALARM` rim-light on the lip.
**Read: the unbroken `BONE` stream.**

**last_ember** · SKILL · Overload 4, 10 Block, Exhaust · RARE
A single dying coal cupped in a gauntlet, held up. Small bright core inside a large dark mass —
maximum value contrast in the set. Gauntlet `INK_MUTED`/`SHADOW`, coal `BONE`→`SAND`, heavy
`ALARM` rim: the largest debt in the deck gets the strongest mark. Dissolving edge for Exhaust.
**Read: tiny bright core in a big dark hand.**

### Overloaded payoffs

These fire *while* in debt. They carry one `ALARM` accent but keep their own subject; the code
already draws an `EMBER` strip along the card bottom.

**ember_jab** · ATTACK · 0-cost · 3 damage, +3 Overloaded
Short tong-tip jab, two prongs, entering from the left edge to centre. `ALARM` on the prong tips.
Tongs `INK_MUTED`/`INK_MID`. **Read: the two-prong fork.** *Fill the frame — see §7.*

**molten_strike** · ATTACK · 9 damage, +2 Vulnerable Overloaded
White-hot billet swung on tongs, rising diagonal. Billet `BONE` core → `SAND` → `CLAY`, tongs
`INK_MUTED`, a `VIOLET` wisp at the tip for the Vulnerable payoff. **Read: the `BONE` core.**

**backdraft** · ATTACK · 8 damage, +8 Overloaded
Hatch blown open with **two** overlapping gust fronts, the second offset from the first — the
doubling is the picture. Hatch `RUST`/`SHADOW`, gusts `INK_LIGHT` with `ALARM` leading edges.
**Read: two arcs, not one.**

**immolate** · ATTACK · 6 to ALL, +6 to ALL Overloaded · RARE
Full-width floor-level wash with **two** crests. Bottom-anchored across the whole 80px. Waves
`BONE`/`SAND`/`CLAY`, `ALARM` at the leading crest. **Read: full width, two crests.**

**forge_guard** · SKILL · 6 Block, +3 Overloaded
Tongs-held plate raised as a shield. Centred, symmetric. Plate `QUENCH_DEEP`, rim `QUENCH`, tongs
`INK_MUTED`, `ALARM` rivet cluster. **Read: the `QUENCH` plate.**

**anvil_stance** · SKILL · 5 Block, draw 1 Overloaded
The anvil, face-on, planted, bottom-anchored. The most recognisable silhouette available — this is
the card that sells the forge world. Body `INK_MUTED`, top face `INK_MID`, `QUENCH` under-glow for
Block, `SHADOW` base, one `ALARM` chip on the horn. **Read: the anvil profile.**

---

## 5. Cash out — spending Mana you hold

Downward flow. Frame empties.

**vent** · ATTACK · spend all Mana, 3 damage each
Tuyere blasting down and out. Nozzle top-centre, cone widening to the bottom edge. Nozzle
`INK_MUTED`, blast `INK_LIGHT`→`BONE`, two `SPARK` specks. **Read: the widening cone.**

**temper** · SKILL · spend up to 3 Mana, 3 Block each
Blade lowered slowly into an oil bath. Descent line down the centre; oil band across the bottom
third with **three** `BONE` tick marks on the vessel wall — the cap, drawn literally. Blade
`BONE`→`SAND`, oil `QUENCH_DEEP`, no steam. **Read: the descent line and three ticks.**

---

## 6. Everything else

**hammer_fall** · ATTACK · 12 damage
Two-handed sledge at the instant of impact, haft foreshortened. Same weapon language as Strike,
head at twice the mass and lower — impact at (52,38), `BONE` chips radiating. Head `INK_MID` body
with `INK_LIGHT` crown. **Read: the head mass. More mass = more damage, and that rule holds across
the set.**

**searing_blow** · ATTACK · 7 damage, 2 Weak
Glowing billet pressed against a surface, smoke curling off. Billet diagonal from the lower-left;
`VIOLET_DARK` plume breaking upper-right for Weak. Billet `BONE`→`SAND`→`CLAY`.
**Read: `BONE` core against `VIOLET_DARK` smoke.**

**pin** · ATTACK · 5 damage, 2 Vulnerable
A punch driven through plate, edge-on. Spike descends from the upper-right to a struck point at
(44,40); `VIOLET` cracks radiate from it. Spike `INK_MID`/`INK_LIGHT`, plate `RUST`.
**Read: the `VIOLET` crack star.**

**flare** · ATTACK · 0-cost · 4 damage, Exhaust
One thrown scale with a thin curved trail. Small, sparse, upper-right — deliberately the emptiest
illustration in the set, because it is the smallest card. Head `SAND`, trail `CLAY`, two `SPARK`
speculars, trailing edge dissolving. **Read: the trail arc.**

**cinder_spray** · ATTACK · 4 to ALL
Shovel-fling of sparks. Small blade lower-left, 9–12 **discrete** 1–2px specks fanning across the
upper-right. Blade `INK_MUTED`, specks `SAND`/`BONE` with two `SPARK`. **Read: the fan of separate
specks.**

**slag_toss** · ATTACK · 6 to ALL, 1 Weak to ALL
Ladle flinging slag. Ladle lower-left, **five** irregular lumps arcing right, `VIOLET_DARK` haze
trailing. Lumps `MOSS_DARK`/`TEAL_DARK` — otherwise unused in the set, which is what keeps this
card distinct from the other two AoEs. **Read: five green-grey lumps.**

**quench** · SKILL · 8 Block, clear Overload
Blade plunged into the trough, sheet of steam rising. Symmetric, vertical blade centred, `QUENCH`
water band across the lower third, `INK_LIGHT` steam. One `ALARM` cluster dying at the waterline —
that is "clear your Overload", drawn. Blade `BONE`. **Read: water band plus steam.**

**brace** · SKILL · 4 Block, 1 Dexterity
Leather bracer being strapped, buckle centred and symmetric. Strap `LEATHER`/`RUST`, buckle
`QUENCH_BRIGHT` (Dexterity is `QUENCH` in `Palette.for_status`). **Read: the buckle.**

**afterburn** · POWER · damage whenever you Overload
Flue column, full height, heat escaping through three cracks up its length. Pipe `RUST`/`SHADOW`/
`INK_MUTED`, cracks `ALARM`. **Read: `ALARM` cracks up a dark column.**

**forge_body** · POWER · 2 Strength
Armoured torso on a stand, full height. Plate `INK_MID`, chest sigil `RED` (Strength is `RED`),
`SHADOW` depths. **Read: the `RED` sigil.**

**temperance** · POWER · 2 Dexterity
Tall slender oil flask on a stand, full height. Glass `QUENCH`, `QUENCH_BRIGHT` highlight, stopper
`BONE`. **Read: the `QUENCH` column.**

---

## 7. The ones that will fight you

| Cards | Collision | Resolution |
|---|---|---|
| cinder_spray / slag_toss / immolate | Three AoEs | Discrete specks · discrete `MOSS_DARK` lumps · continuous full-width wave |
| quench / temper | Both blade-into-liquid | Violent plunge, steam, dying `ALARM` · slow descent, no steam, three ticks |
| strike / hammer_fall | Same weapon | Intentional family. Separated by head mass and impact chips |
| bellows / second_wind | Both moving air | Accordion pleats · flat grate |
| kindle / stoke / kindling | All fuel | 1 pale face · 2 pale faces · vertical column of repeats |
| ember_jab | 0-cost, minimal subject risks reading as an empty card | Let the prongs fill 60% of the frame width. Small cost, not small picture |

**Fallback, any card:** one object, centred, maximum value contrast, drop the secondary element.
A card that reads as one clear thing beats a card carrying three ideas none of which survive 80×56.

---

## 8. Drawing order

1. **strike** — three copies in the opening hand
2. **defend** — two copies; together with 1 and 3 the entire first hand is real art
3. **kindle** — the Ramp teacher, and it sets the fuel language
4. **anvil_stance** — the strongest silhouette available; sells the forge world in one screenshot
5. **bellows** — the Overload teacher; proves the `ALARM`-as-debt convention
6. **hammer_fall** — proves the mass-scales-with-damage rule against Strike

After six the game screenshots as a real game. Cards 4–6 are chosen to prove the three conventions
most likely to break — silhouette language, the debt marker, and damage scaling — while they are
still cheap to revise.
