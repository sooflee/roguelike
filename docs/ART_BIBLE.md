# Art Bible — Emberwright

**This document is the contract.** Consistency in pixel art comes from constraints written down
before you draw, not from discipline in the moment. Nothing ships that violates this file.
`tools/check_art.py` enforces the mechanical half automatically.

---

## 1. Locked specifications

These are expensive to change after the first art pass. Change them now or not at all.

| Spec | Value |
|---|---|
| Base resolution | **960 × 540** (integer-scales to 1920×1080 at 2×) |
| Stretch mode | `viewport`, aspect `keep`, **integer scale on** |
| Texture filter | **Nearest** (set project-wide in `project.godot`) |
| Palette | **32 colors**, `assets/palette/emberwright.gpl`, no exceptions |
| UI grid | 8 px — every element snaps |
| Font | One 8 px bitmap family, everywhere |

### Sprite dimensions

| Asset | Size |
|---|---|
| Normal enemy | 64 × 64 |
| Elite enemy | 96 × 96 |
| Boss | 128 × 128 |
| Player | 64 × 64 |
| Card frame | 96 × 132 |
| Card art window | 80 × 56 |
| Status icon | 16 × 16 |
| Map node icon | 24 × 24 |
| Relic icon | 32 × 32 |

### Animation

| Rule | Value |
|---|---|
| Idle loop | 4–6 frames @ 8 fps |
| Hurt | 2 frames, 1 held + 1 recoil |
| Attack | 5–7 frames with **anticipation** (wind back before swinging) |
| Death | dissolve shader, no hand-drawn frames needed |

---

## 2. The rules that actually create consistency

Sprite size and palette are the easy half. These are the ones that get broken:

1. **Light source is top-left. Always.** Every sprite, every prop, every UI bevel. One
   inconsistent light direction is more visible than a wrong color.
2. **Outline: 1 px, a dark palette color, never pure black.** Pure black outlines flatten
   everything and make the palette look cheap.
3. **No anti-aliasing on outer edges.** Selective AA *inside* a sprite is fine; AA against the
   background makes sprites look pasted on.
4. **No dithering below 2 px cells.** Fine dithering shimmers when the camera moves and turns to
   mush at 1× scale.
5. **Every sprite must read as a silhouette.** If it doesn't read in solid black, color won't
   save it. This is the first production step, not a check at the end.
6. **Hue-shift when shading.** Shadows shift toward blue/purple, highlights toward yellow/orange.
   Never darken by reducing brightness alone — that's what makes pixel art look muddy.
7. **Pixel density is uniform.** No mixing 1× art with 2× art. A "big" enemy is a bigger canvas,
   not scaled-up pixels.

---

## 3. Palette

**Candidate:** Endesga-32 (EN32) — designed for game art, strong value ramps, wide adoption.

Alternatives: DawnBringer-32, AxulArt-32 (CC-BY 4.0).

> **Verify the license on the individual palette page.** Lospec licensing is per-palette, not
> site-wide. Record whichever you pick in `assets/palette/LICENSE.md` at the time you download it.

Reserved roles — assign these before drawing anything:

| Role | Use |
|---|---|
| Ember orange | Mana gauge, Overloaded state, player accents. **Reserve it.** Nothing else uses it, so "this is the resource" always reads instantly |
| Cold blue | Block, Frail, quench effects |
| Sick green | Poison/debuff |
| Bone white | Text, UI highlights |
| Deep charcoal | Outlines (never `#000000`) |

The Emberwright's identity is the Mana curve — Ramp and Overload (D-11). Ember orange being
reserved to the gauge is what makes the mechanic legible at a glance; the moment it appears
elsewhere, the signal is gone. White-hot metal is drawn `BONE` → `WHITE`, which is hotter than
orange anyway and keeps the reservation intact.

---

## 4. Production order (silhouette first)

1. **Silhouette** — solid black, no palette. Does it read? If not, restart.
2. **Flat color** — locked palette only.
3. **Shading** — one light source, hue-shifted.
4. **Animation** — idle first, then hurt, then attack.
5. **In-engine check at 1× and 2×** before it counts as done.

Skipping step 1 is the single most common way pixel art goes wrong.

---

## 5. AI usage policy

> **AI for reference and ideation only. Every shipped pixel is hand-drawn.**

Allowed: concept boards, silhouette exploration, composition studies, color roughs, mood boards.
Not allowed: any AI-generated raster that ships, in whole or in part.

Rationale is practical as well as legal. AI output is pseudo-pixel — off-grid, anti-aliased, and
palette-exploded to 200+ colors — so it needs near-total redraw anyway. And Steam's
**17 January 2026** policy rewrite narrowed AI disclosure to *player-facing shipped content*,
explicitly exempting concept-art ideation whose output does not ship, plus AI code assistants.
A reference-only pipeline therefore requires **no AI disclosure** on the store page.

If this policy ever changes, update `docs/STEAM_DISCLOSURE.md` in the same commit.

---

## 6. Tools

- **Aseprite** ($20) — or **Pixelorama** / **LibreSprite** (free).
- **Lospec** — palette list and tutorials.
- **saint11's pixel art tutorials** — the standard reference for game animation.

## 7. Asset checklist for the vertical slice

- [ ] Player: idle, hurt, attack, death
- [ ] 8 normal enemies: idle, hurt, attack
- [ ] 2 elites: idle, hurt, attack
- [ ] 1 boss: idle, hurt, 2 attacks
- [ ] Card frames: attack / skill / power, ×2 for upgraded
- [ ] 31 card illustrations (80×56)
- [ ] Status icons (7)
- [ ] Mana gauge: pip lit / spent / locked, ramp ceiling marker, Overload strike-through
- [ ] Map node icons (7)
- [ ] Act 1 background: 3 stage variants (1–3, 4–6, 7–8), 5 layers each, 240×135 drawn at 1:4
- [ ] Relic icons (16, 32×32)
- [ ] UI: buttons, end-turn, tooltips, pile counters
