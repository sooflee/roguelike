# Palette

Drop the locked palette here as `emberwright.gpl` (GIMP palette format — what both Aseprite and
Lospec export). `tools/check_art.py` reads it and fails any sprite containing a colour outside it.

**Candidate:** Endesga-32 (EN32) — designed for game art, strong value ramps, wide adoption.
Alternatives: DawnBringer-32, AxulArt-32 (CC-BY 4.0).

> **Verify the licence on the individual palette page before committing it.** Lospec licensing is
> per-palette, not site-wide. Record the licence in `LICENSE.md` alongside the `.gpl`.

Reserved colour roles are specified in `docs/ART_BIBLE.md` §3. Ember orange is reserved to the
Heat gauge and Stoked state — nothing else may use it, so "hot" always reads at a glance.
