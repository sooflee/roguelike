class_name HandView
extends Node2D
## Arranges cards along an arc and keeps them there as the hand changes.
##
## The fan is not decoration: it is what lets ten overlapping cards stay
## individually readable and individually clickable.

const ARC_RADIUS := 900.0
const MAX_SPREAD := 0.62      ## radians across the whole fan
## Wide enough that a small hand does not overlap at all: at five cards the old
## 84 left each card covering 12px of the one before it, which is exactly where
## the rules text sits.
const CARD_GAP := 100.0

var centre: Vector2 = Vector2(480, 700)

## How far below `centre` the lowest pixel of a `count`-card fan can fall.
##
## Not just the droop. A card tilted by theta reaches H/2*cos(theta) +
## W/2*sin(theta) below its own centre, and the outer cards of a full fan are
## tilted enough for that term to be worth 11px. Budgeting the half-card alone
## is what put the bottom line of their rules text off the screen edge.
static func lowest_reach(count: int) -> float:
	var angle := minf(MAX_SPREAD, 0.11 * float(count)) * 0.5
	var droop := angle * ARC_RADIUS * 0.10
	var half := float(CardView.H) * 0.5 * cos(angle) + float(CardView.W) * 0.5 * sin(angle)
	return droop + half + CardView.DRIFT_RISE
var views: Array[CardView] = []

func layout(animate: bool = true) -> void:
	var n := views.size()
	if n == 0:
		return
	# Tighten the spacing as the hand grows so a full hand still fits on screen.
	var gap := minf(CARD_GAP, 620.0 / maxf(1.0, float(n)))
	var spread := minf(MAX_SPREAD, 0.11 * float(n))
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		var x := (float(i) - float(n - 1) * 0.5) * gap
		# Cards further from centre sit slightly lower: that is what makes it
		# read as a fan held in a hand rather than a row on a table.
		var y := absf(angle) * ARC_RADIUS * 0.10
		var pos := centre + Vector2(x, y)
		var view := views[i]
		view.z_index = i
		if animate:
			view.glide_to(pos, angle)
		else:
			view.position = pos
			view.rotation = angle
			view.home_pos = pos
			view.home_rot = angle

func slot_for(index: int, count: int) -> Dictionary:
	var gap := minf(CARD_GAP, 620.0 / maxf(1.0, float(count)))
	var spread := minf(MAX_SPREAD, 0.11 * float(count))
	var t := 0.5 if count <= 1 else float(index) / float(count - 1)
	var angle := lerpf(-spread * 0.5, spread * 0.5, t)
	var x := (float(index) - float(count - 1) * 0.5) * gap
	var y := absf(angle) * ARC_RADIUS * 0.10
	return {"pos": centre + Vector2(x, y), "rot": angle}

func add_view(v: CardView) -> void:
	views.append(v)
	add_child(v)

func remove_view(v: CardView) -> void:
	views.erase(v)

func find_for(card: Card) -> CardView:
	for v in views:
		if v.card == card:
			return v
	return null

func clear() -> void:
	for v in views:
		v.queue_free()
	views.clear()

## Topmost card under the cursor -- iterate backwards so the visually front
## card wins, which is the one the player thinks they are pointing at.
func card_at(point: Vector2) -> CardView:
	for i in range(views.size() - 1, -1, -1):
		if views[i].hit_test(point):
			return views[i]
	return null
