# Sprite provenance

| Asset | Source | Basis |
|---|---|---|
| `player/`, `enemies/`, `elites/`, `bosses/` | Pokémon sprites via the [PokeAPI sprite archive](https://github.com/PokeAPI/sprites) | **Personal, non-commercial fan use** |

**These are Nintendo / Game Freak / The Pokémon Company assets.** They are used here on the
explicit basis that this is a personal project that will not be sold or distributed — the same
footing as any fan game. They must be removed before any public or commercial release, and
`docs/STEAM_DISCLOSURE.md` does not cover them: that file is about AI disclosure, which is a
different question entirely.

Sprites are 96×96 as published. The boss is nearest-neighbour ×2 to 192×192 so it reads as larger
than what it fights; nothing is interpolated. All re-saved as 8-bit RGBA, because the published
files are 4-bit indexed and `tools/check_art.py` decodes with the standard library only.

The Kenney *Tiny Dungeon* pack (CC0) that previously filled these directories has been replaced.
Kenney's CC0 audio and font are still in use and are recorded in their own attribution files —
those remain safe for any use, commercial included.

**If this ever goes commercial**, the swap-in path is the one D-22 already builds: drop original
PNGs at the same paths and nothing else changes.
