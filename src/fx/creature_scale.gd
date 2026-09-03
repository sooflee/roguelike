class_name CreatureScale
extends RefCounted
## How big a creature should be drawn, from how big it actually is.
##
## Every sprite in `assets/sprites/` is published in the same 96x96 box, and
## EntityView drew each one at 1:1 -- so apparent size was an accident of how
## much of its box a species happened to fill. Measured: Rattata came out 86px
## tall and Onix, which is 8.8 METRES, came out 73. A rat rendered bigger than
## the largest thing in the act.
##
## So the size is derived instead: the species' real height, mapped onto the
## frame, divided by how much of its box the art occupies.

## Pokedex heights run 0.3 m to 8.8 m -- a 29x range. Drawn literally Onix would
## be four screens tall and Rattata a smudge, so the range is compressed hard.
## 0.6 m is the reference height and maps to REF_PX.
const REF_M := 0.6
## Raised from 60: at that reference the whole roster sat small in a 540px
## frame with a lot of empty field above it. The curve and the ordering are
## unchanged -- this moves every creature up together.
const REF_PX := 74.0
## Deliberately flat. Correct proportions are not the goal on their own --
## a battle screen has to stay readable, and an Onix drawn to true scale
## against a Rattata is one creature and one speck. This keeps the ordering
## honest while holding the whole roster inside about a 2x spread.
const COMPRESSION := 0.22
const MIN_PX := 58.0
const MAX_PX := 112.0

## Bounds on the scale itself, independent of the target. These sprites are
## native 96x96 with 1px detail, so a large factor visibly coarsens one creature
## against its neighbours -- past 2x the cure is worse than the disease, and the
## real fix is art drawn at the right size.
const MIN_FACTOR := 0.5
const MAX_FACTOR := 2.25

## The cell every ordinary creature is published in. The boss ships already
## doubled to 192 precisely so it reads larger than what it fights (see
## assets/sprites/ATTRIBUTION.md) -- rescaling that by Pokedex height would
## undo a deliberate decision and leave the act boss smaller than the elite
## two rooms earlier. Anything authored oversized is left alone.
const STANDARD_CELL := 96

## texture RID -> occupied height of frame 0, in pixels.
static var _content: Dictionary = {}
static var _rects: Dictionary = {}

## On-screen height, in frame pixels, for a creature `metres` tall.
static func target_px(metres: float) -> float:
	return clampf(REF_PX * pow(maxf(metres, 0.05) / REF_M, COMPRESSION), MIN_PX, MAX_PX)

## How much of its box the art actually fills. Measured from frame 0 rather than
## assumed, so redrawn art resizes itself instead of needing a number updated
## alongside it (D-22).
static func content_height(tex: Texture2D) -> int:
	if tex == null:
		return 0
	var key := tex.get_rid().get_id()
	if _content.has(key):
		return _content[key]
	var img := tex.get_image()
	if img == null:
		return 0
	var cell := img.get_height()
	var frame := img.get_region(Rect2i(0, 0, cell, cell))
	var used := frame.get_used_rect()
	var h: int = maxi(1, used.size.y)
	_content[key] = h
	return h

## The rectangle frame 0's art actually occupies inside its cell.
##
## These sprites are published with a lot of empty cell around them -- 42px of
## art in a 96px box is typical -- so anything laying one out by the cell puts a
## small creature in the middle of a large gap. Callers that want the ART
## centred or filling a space need the rect, not the height alone.
static func content_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	var key := tex.get_rid().get_id()
	if _rects.has(key):
		return _rects[key]
	var img := tex.get_image()
	if img == null:
		return Rect2i()
	var cell := img.get_height()
	var r: Rect2i = img.get_region(Rect2i(0, 0, cell, cell)).get_used_rect()
	_rects[key] = r
	return r

## The scale EntityView should draw this texture at. Snapped to eighths: the
## exact ratio is a number nobody can verify by looking, and eighths keep two
## creatures of the same species identical across a run.
static func factor(tex: Texture2D, metres: float) -> float:
	if tex == null or tex.get_height() > STANDARD_CELL:
		return 1.0
	var content := content_height(tex)
	if content <= 0:
		return 1.0
	var raw := target_px(metres) / float(content)
	return clampf(roundf(raw * 8.0) / 8.0, MIN_FACTOR, MAX_FACTOR)
