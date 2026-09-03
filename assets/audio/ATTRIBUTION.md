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
