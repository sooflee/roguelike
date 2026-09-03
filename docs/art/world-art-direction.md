# World and UI art direction

Specification for a human pixel artist. Nothing here is drawn — per D-06 this document exists so
someone can draw from it. Binding constraints: 960×540 (D-07), 8px grid, Endesga-32, nearest
filter, light source top-left, 1px non-black outline (`SHADOW`).

**`EMBER` (`f77622`) is reserved for Mana and Overload.** No world art, no map icon, no relic may
use it. The gauge is the only hot thing on screen or it stops meaning anything.

---

## 1. The theme conflict, and how it resolves

Act 1 is specified as green lush hills under a blue sky. Every existing name is forge-and-ash:
Cinder Rat, Slag Hound, Ash Wisp, Bellows Imp, Furnace Moth, Molten Glob, Tongsman, Forge Warden,
Slag Titan, The Bellowsmith. The protagonist is a forge-worker. Green hills do not currently
belong to that world.

Two readings resolve it. Only one is cheap.

**Rejected — "act 1 is the surface world, before the forge."** Clean, and it gives the run a
descent. But it makes act 1's entire enemy roster wrong: eleven creatures named after a forge,
standing in a meadow. Fixing that means renaming and redrawing all eleven, plus the four events
set in slag pools and cold forges. That is the whole act's content for a background.

**Chosen — the forge is spreading, and act 1 is where it reaches first.** The green world is what
the forge is eating. The creatures are forge-things that have come *up* into it. Nothing is
renamed. Every existing enemy gains a reason to be standing on grass: it does not belong there,
and that is the point.

This buys something the other reading does not. The map already runs left to right toward the
boss, so **the background progresses across the act**. Stage 1 is clean: full blue, unbroken
green. By stage 8 the sky is smoke-bleached, the grass is scarred with slag, and The Bellowsmith's
forge is on the horizon. The player watches the world get worse as they advance. The background
becomes a progress bar that nobody has to read.

### Act arc

| Act | Place | Dominant ramp | Sky | Value |
|---|---|---|---|---|
| 1 | Green surface, forge encroaching | `MOSS_DARK` → `MOSS` | `QUENCH_DEEP` → `QUENCH` | Bright |
| 2 | Slag flats — land the forge already killed | `RUST` → `CLAY` → `SAND` | Bleached `INK_MUTED` → `SAND` | Mid |
| 3 | Inside the forge | `SHADOW` → `TEAL_DARK` → `BLOOD` | None; lit only by what burns | Near-black |

Act 3 returns to `GROUND`, which is what the UI was built against. Acts 1 and 2 are the ones that
have to earn their readability, and §2 is how.

### Per-stage progression within act 1

Eight stages, three variants. Interpolating in code is not possible — dithered pixel art does not
tween — so draw three and switch on stage index.

| Stages | Sky | Ground | Horizon |
|---|---|---|---|
| 1–3 | Clean `QUENCH` | Unbroken `MOSS_DARK`/`MOSS` | Clear |
| 4–6 | `QUENCH` with `INK_MUTED` smoke bands | `RUST` slag scars in the grass | Thin plume, right edge |
| 7–8 | `INK_MUTED` overcast, `QUENCH_DEEP` only at zenith | Grass losing to `RUST`/`SHADOW` | Forge silhouette, `SHADOW` |

---

## 2. Act 1 combat background

### The problem to solve first

The current background is `bg.color = Palette.GROUND` (`181425`, luminance 0.008). Every UI
element in `combat_view.gd` was designed against near-black and none of it has a backing plate.
White text on `GROUND` is 18:1. On the colours a green-and-blue scene wants, it is not:

| Colour | Luminance | White-text contrast |
|---|---|---|
| `GROUND` `181425` | 0.008 | 18.0:1 |
| `SHADOW` `3e2731` | 0.027 | 13.6:1 |
| `TEAL_DARK` `193c3e` | 0.038 | 12.0:1 |
| `QUENCH_DEEP` `124e89` | 0.074 | 8.5:1 |
| `INK_MUTED` `5a6988` | 0.141 | 5.5:1 |
| `MOSS_DARK` `3e8948` | 0.194 | 4.3:1 |
| `QUENCH` `0099db` | 0.279 | 3.2:1 |
| `MOSS` `63c74d` | 0.440 | 2.1:1 |
| `QUENCH_BRIGHT` `2ce8f5` | 0.648 | **1.5:1** |

`QUENCH_BRIGHT` is never a field colour. It is a rim light on cloud tops and nothing else.

**The composition supplies the darkness, not a scrim.** Do not solve this with a translucent black
overlay — that greys the palette and is what makes pixel art look cheap. Solve it by putting
foreground geometry where the UI lives: a shadowed bank on the left, a treeline or slag heap on
the right, ground shadow along the bottom.

### Value budget by screen region

These are hard ceilings. The artist works inside them.

| Region | Rect | Max luminance | Why |
|---|---|---|---|
| HUD strip | y 0–40, full width | **0.10** | `_top` at (12,6) is unoutlined BBCode: HP / Block / Mana / Turn |
| Open sky | y 40–200 | free | Only the turn banner, which is outlined |
| Combat band | y 200–370 | **0.45** | Sprites carry 1px outlines; entity labels carry 3px outlines |
| Card band | y 370–540 | **0.12** | Card fan spans y 372–532, x 201–759; `SURFACE` frames on `BORDER` |
| Left rail | x 0–200, y 320–500 | **0.12** | Mana gauge (12,348), potion bar (12,400), pile counters (12,458) |
| Right rail | x 796–960, y 0–500 | **0.12** | Speed (806,8), Dev (806,44), End Turn (806,392), Continue (806,436) |

The left and right rails are why the composition needs foreground mass on both sides. Treat them
as a framing device, not a compromise: the Emberwright stands in the shadow of a bank at x≈180,
and the right edge is where the forge's reach begins.

### Layers

There is **no camera pan in combat**, so these do not parallax in the usual sense. They respond to
`Juice` screen-shake at different rates, which is what sells depth here. `_world` is the registered
shake target; the background must be a sibling of it so it can take fractional shake independently.

| Layer | Content | y range | Shake response | Palette |
|---|---|---|---|---|
| L0 | Sky plate, static | 0–270 | 0.00 | see below |
| L1 | Far ridge | 236–300 | 0.15 | `TEAL_DARK` flat, 1px `MOSS_DARK` top edge |
| L2 | Mid hills | 268–330 | 0.35 | `MOSS_DARK` field, `MOSS` left-lit flanks |
| L3 | Near ground | 300–540 | 0.60 | `MOSS_DARK`/`MOSS`, ramping down (below) |
| L4 | Foreground fringe | 516–540 | 1.00 | `SHADOW` grass silhouette |

**L0, sky plate**, top to bottom:

- y 0–48 — `QUENCH_DEEP`. This is the HUD safe band. Skies *are* darker at zenith, so this is
  physically right as well as legible.
- y 48–150 — `QUENCH_DEEP` → `QUENCH`, 2px ordered dither cells. Never finer: 1px dither shimmers
  and mushes at 1× (art bible rule 4).
- y 150–250 — `QUENCH` open sky.
- y 250–270 — `QUENCH` → `SAND` haze, 2px dither. Warm air at the horizon.
- Clouds: `INK_LIGHT` bodies, `WHITE` tops, `INK_MUTED` undersides. `QUENCH_BRIGHT` only as a 1px
  rim on the upper-left edge of the two nearest clouds — light source top-left.

**L1 far ridge.** Flat `TEAL_DARK` silhouette, **no dark outline**. Aerial perspective pulls
distant forms toward the sky's hue and drops their contrast; a hard `SHADOW` line makes a ridge
read as a sticker. A single 1px `MOSS_DARK` lightening along the top edge is enough to separate it
from the sky.

**L3 near ground** carries the value ramp that makes the card band work:

- y 300–370 — `MOSS_DARK` field with `MOSS` clumps, full brightness.
- y 370–440 — ramp `MOSS_DARK` → `TEAL_DARK` across 2px dither bands.
- y 440–540 — `TEAL_DARK` → `SHADOW`. Reads as the ground falling into shadow at the viewer's
  feet, which is both natural and exactly the 0.12 ceiling the card fan needs.

### Motion

All of it must stop dead at `Juice.intensity = 0` (D-23, reduce-motion).

| Element | Frames | Loop | Notes |
|---|---|---|---|
| Cloud drift | not framed — scroll | 32s per 96px tile | 3 px/s right→left. The only true parallax in the scene |
| Grass sway, L3 clumps | 6 | 1.0s @ 6fps | Phase-offset per clump; never in unison |
| Foreground fringe sway | 6 | 1.0s @ 6fps | Same cycle, 0.5s out of phase with L3 |
| Forge plume, stages 4–8 | 6 | 1.0s @ 6fps | Right horizon; taller and darker each variant |
| Birds | 2 | 0.25s flap | Crosses once every 40–60s, stages 1–3 only. They leave as the forge advances |

---

## 3. Map node icons

24×24 (art bible), replacing the drawn letters in `map_view.gd`. The node circle is radius 11, so
a 24×24 icon fills it edge to edge; keep the readable mass inside a 20×20 core with 2px of margin.

**`CAMPFIRE` currently draws in `Palette.EMBER` (`map_view.gd:103`), which violates the
reservation.** It must move to `FLAME`. That is the one existing colour choice this document
overrules.

| Kind | Icon | Palette | Idle |
|---|---|---|---|
| Combat | Two crossed short blades, one notched | `INK_MUTED` grips, `INK_LIGHT` edges | **None.** These are the most common node; motion on all of them is noise |
| Elite | Horned helm, empty eye slot | `BLOOD` → `RED` horns, `SHADOW` slot | 2 frames — eye glint, 0.15s on every 3.0s |
| Event | A question mark drawn as a curled ribbon | `VIOLET_DARK` → `VIOLET` → `ROSE` | 4 frames @ 6fps, 0.67s flutter |
| Shop | Drawstring purse, one coin above it | `LEATHER` purse, `SPARK` coin | 4-frame coin spin, 0.5s, once every 4s |
| Rest | Small fire over two logs | `RUST` logs, `EMBER_DEEP` → `FLAME` → `SPARK` flame | 4 frames @ 8fps, 0.5s flicker |
| Treasure | Banded chest, lid shut | `RUST` bands, `LEATHER` body, `SAND` lock | 2 frames — lock glint every 3s |
| Boss | Horned anvil-skull | `SHADOW` → `BLOOD` → `ALARM` | 6 frames @ 6fps, 1.0s — slow breathing, smoke from the horns |

Boss draws at radius 17.6 in `map_view.gd`, so its icon is **38×38**, not 24×24.

Engineering consequence, not for this document to implement: `MapView._process` currently only
redraws while `available` is non-empty. Animated icons need it redrawing whenever any icon has a
live frame, and not at all when `Juice.intensity` is 0.

---

## 4. Relic icons

32×32. Light top-left, 1px `SHADOW` outline, three-step ramp each. The two BOSS relics share a
`VIOLET_DARK` shadow tone as a rarity tell — the only cross-cutting rule here.

| Relic | Subject | Ramp |
|---|---|---|
| `forge_mark` | A brand seared into an open palm | `RUST` → `LEATHER` → `CLAY`, `SPARK` at the burn's centre |
| `iron_tongs` | Crossed tongs, jaws closed | `SHADOW` → `INK_MUTED` → `INK_MID` |
| `ash_charm` | Knotted cord, single grey bead | `SHADOW` → `INK_MUTED` → `BONE` |
| `whetstone` | Canted oval stone, one honed edge catching light | `TEAL_DARK` → `INK_MUTED` → `BONE` |
| `slag_pouch` | Bulging drawstring pouch, three pebbles spilling | `RUST` → `LEATHER` → `SAND` |
| `cinder_vial` | Stoppered vial of grey dust | `QUENCH_DEEP` glass, `INK_MUTED` → `BONE` contents |
| `spare_bellows` | Small hand-bellows, nozzle to the left | `LEATHER` body, `RUST` → `INK_MID` fittings |
| `ring_of_ash` | Plain band, ash-dulled, one facet lit | `SHADOW` → `INK_MUTED` → `INK_LIGHT` |
| `quench_basin` | Shallow stone bowl, water dead still | `SHADOW` stone, `QUENCH_DEEP` → `QUENCH` → `QUENCH_BRIGHT` water |
| `governor` | Brass flyball governor, two weights out | `RUST` → `LEATHER` → `SAND`, `BONE` highlight |
| `twin_hammers` | Two crossed cross-peen hammers | `SHADOW` heads, `LEATHER` handles, `INK_LIGHT` struck faces |
| `coal_ration` | Cloth bundle tied at the neck, one black lump showing | `SAND` cloth, `SHADOW` coal |
| `white_forge` | A forge mouth head-on, white-hot at the core | `SHADOW` → `BONE` → `WHITE` |
| `slack_tub` | Half-barrel of dark water, iron hoops, one steam curl | `RUST` staves, `SHADOW` hoops, `QUENCH_DEEP` water |
| `bottomless_bellows` | Oversized bellows, bag running off the bottom edge | `LEATHER` → `CLAY`, `VIOLET_DARK` seams |
| `smiths_lungs` | A ribcage with bellows-leather stretched between the ribs | `BONE` ribs, `LEATHER` webbing, `VIOLET_DARK` shadow |

`white_forge` is the trap. Its name and effect both pull toward orange, and orange is reserved.
Spec it as *white*-hot — `BONE` into `WHITE` — which is hotter than orange anyway, and keeps the
reservation intact.

---

## 5. Noted, out of scope

`ART_BIBLE.md` §3 still assigns ember orange to "Heat gauge, Stoked glow" and calls the Heat gauge
the class identity. Heat was replaced by the Mana curve (D-11). The reservation itself is
unchanged and everything above honours it, but the bible's wording is stale.
