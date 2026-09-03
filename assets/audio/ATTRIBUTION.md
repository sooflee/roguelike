# Audio provenance

| Asset | Source | Licence |
|---|---|---|
| `sfx/*.ogg` | Kenney — *RPG Audio*, <https://kenney.nl/assets/rpg-audio> | **CC0 1.0** (public domain) |

The pack's `License.txt`: *"You may use these assets in personal and commercial projects."* CC0
requires no attribution; this file is a courtesy credit.

Files are renamed to the cue they serve (`knifeSlice` → `hit.ogg`) rather than kept under their
pack names, so `Audio.play(&"hit")` reads as intent and the library underneath can be replaced
without touching a line of code — the D-22 pattern applied to sound.

Satisfies **D-10** ("licensed library now, commissioned composer later"). Human-made, not AI —
`docs/STEAM_DISCLOSURE.md` is unaffected.

## Creature voices

`sfx/charmander_select.wav` ("char char"), `sfx/charmander_name.wav`, `sfx/charmeleon_voice.wav`
and `sfx/charmander_faint.wav` are **original synthesised audio** — macOS `say`, resampled into a
small-creature register — Junior for Charmander, Daniel pitched down for the evolved form; the faint cue is the same voice run slow and low.

They stand in for the anime voice clips, which are copyrighted performance with no archive that
has usable provenance. **Being original, these are the only creature sounds here that are safe to
ship.** To replace one, drop a file at the same path: `Audio` resolves a cue by filename (`.ogg`
then `.wav`), so there is no code to change — the swap-in path D-22 defines for sprites.

No Pokemon cries are used. Two were added and removed again; nothing references them.
