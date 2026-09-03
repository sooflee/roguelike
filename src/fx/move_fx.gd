class_name MoveFx
extends Node2D
## Typed move effects: the thing that travels from the attacker to the target,
## and the impact it lands with.
##
## The play animations already say HOW a card is used -- attacks lunge, blocks
## plant. This says WHAT it is: a Fire move throws embers, Water throws a jet,
## Electric arcs. It is drawn rather than particled so the shapes stay on the
## pixel grid and inside the locked palette (D-05, D-08).
##
## Purely presentational. Nothing here can touch combat state, and nothing waits
## on it (D-13).

const SPEED := 900.0
const MOTE := 4.0

var _shots: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []

## Sparks fall, because sparks that drift in a straight line read as a
## screensaver rather than as something that just happened.
const SPARK_GRAVITY := 520.0

func _ready() -> void:
	z_index = 150
	set_process(true)

## Throws a volley of motes from `from` to `to` in the move's type colour.
func fire(from: Vector2, to: Vector2, element: int, count: int = 7) -> void:
	if Juice.intensity <= 0.0:
		impact(to, element)
		return
	var colour := Element.colour(element)
	for i in count:
		_shots.append({
			"pos": from, "to": to, "col": colour, "element": element,
			# Staggered, and spread across the line, so a volley reads as many
			# things thrown rather than one thing duplicated.
			"delay": float(i) * 0.035,
			"drift": Vector2(randf_range(-16.0, 16.0), randf_range(-22.0, 6.0)),
			"last": i == count - 1,
		})

## The moment a card lands, in the move's own type colour: a ring pushing
## outward and a scatter of sparks.
##
## `power` scales it with the card's cost, so a three-Mana finisher does not
## land like a cantrip -- how big the flourish is IS the feedback for what the
## card just cost you.
func burst(at: Vector2, element: int, power: float = 1.0) -> void:
	if Juice.intensity <= 0.0:
		return
	var colour := Element.colour(element)
	_bursts.append({"pos": at, "col": colour, "t": 0.0, "power": power})
	for i in int(10.0 + 10.0 * power):
		var a := randf() * TAU
		_sparks.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(150.0, 380.0) * power,
			"col": colour, "t": 0.0, "life": randf_range(0.34, 0.62),
		})
	queue_redraw()

func impact(at: Vector2, element: int) -> void:
	_impacts.append({"pos": at, "col": Element.colour(element), "t": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	var step := delta * maxf(0.2, Juice.speed_scale)
	var live: Array[Dictionary] = []
	for s in _shots:
		if s["delay"] > 0.0:
			s["delay"] -= step
			live.append(s)
			continue
		var to: Vector2 = s["to"] + s["drift"]
		s["pos"] = (s["pos"] as Vector2).move_toward(to, SPEED * step)
		if (s["pos"] as Vector2).distance_to(to) < 6.0:
			if s["last"]:
				impact(s["to"], s["element"])
		else:
			live.append(s)
	_shots = live

	var kept: Array[Dictionary] = []
	for im in _impacts:
		im["t"] += step * 3.2
		if im["t"] < 1.0:
			kept.append(im)
	_impacts = kept

	var live_bursts: Array[Dictionary] = []
	for b in _bursts:
		b["t"] += step * 1.9
		if b["t"] < 1.0:
			live_bursts.append(b)
	_bursts = live_bursts

	var live_sparks: Array[Dictionary] = []
	for sp in _sparks:
		sp["t"] += step
		if sp["t"] >= sp["life"]:
			continue
		var v: Vector2 = sp["vel"]
		v.y += SPARK_GRAVITY * step
		sp["vel"] = v
		sp["pos"] = (sp["pos"] as Vector2) + v * step
		live_sparks.append(sp)
	_sparks = live_sparks

	if not _shots.is_empty() or not _impacts.is_empty() \
			or not _bursts.is_empty() or not _sparks.is_empty():
		queue_redraw()

func _draw() -> void:
	for s in _shots:
		if s["delay"] > 0.0:
			continue
		var p: Vector2 = s["pos"]
		draw_rect(Rect2(p - Vector2(MOTE, MOTE) * 0.5, Vector2(MOTE, MOTE)), s["col"])
		# A one-pixel bright core, so the mote reads as lit rather than as a dot.
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Palette.BONE)
	for im in _impacts:
		var t: float = im["t"]
		var r: float = 6.0 + t * 34.0
		var fade: float = 1.0 - t
		draw_arc(im["pos"], r, 0.0, TAU, 20, Color(im["col"], fade), 3.0)
		if t < 0.4:
			draw_arc(im["pos"], r * 0.55, 0.0, TAU, 16, Color(Palette.BONE, fade), 2.0)

	for b in _bursts:
		var bt: float = b["t"]
		var pw: float = b["power"]
		var fade: float = 1.0 - bt
		var at: Vector2 = b["pos"]
		# A white pop first. Held for a fifth of the burst rather than a couple
		# of frames -- at 60fps a two-frame flash is something you only notice
		# is missing.
		if bt < 0.22:
			var ft: float = 1.0 - bt / 0.22
			draw_circle(at, 22.0 * pw * ft, Color(Palette.BONE, 0.95))
			draw_circle(at, 30.0 * pw * ft, Color(b["col"], 0.55))
		# Spokes. A bare ring expands politely; spokes read as something
		# being driven outward from a point.
		var rr: float = 12.0 + bt * 78.0 * pw
		if bt < 0.62:
			var sf: float = 1.0 - bt / 0.62
			for i in 8:
				var a := TAU * float(i) / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(at + dir * rr * 0.72, at + dir * (rr + 14.0 * pw * sf),
					Color(b["col"], sf * 0.85), 3.0)
		draw_arc(at, rr, 0.0, TAU, 30, Color(b["col"], fade), 4.0 * pw)
		# A pale rim just outside the ring. The type colours are deliberately
		# desaturated (D-08 reserves the bright warm ramp for Mana), which
		# leaves a bare ring reading as mud against the grass.
		draw_arc(at, rr * 1.07, 0.0, TAU, 30, Color(Palette.BONE, fade * 0.4), 2.0)
		draw_arc(at, rr * 0.58, 0.0, TAU, 24, Color(Palette.BONE, fade * 0.7), 2.0)

	for sp in _sparks:
		var life: float = sp["life"]
		var f: float = 1.0 - sp["t"] / life
		var pos: Vector2 = sp["pos"]
		# Same build as the volley motes: a body in the type colour with a lit
		# core, so a spark reads as burning rather than as a coloured dot.
		draw_rect(Rect2(pos - Vector2(2.5, 2.5), Vector2(5, 5)), Color(sp["col"], f))
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), Color(Palette.BONE, f))
