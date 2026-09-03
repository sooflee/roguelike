class_name MapView
extends Node2D
## The run map, drawn as a node graph.
##
## Replaces the ASCII grid. The act runs LEFT TO RIGHT: stage 0 at the left
## edge, the boss at the right, lanes stacked vertically around the centre line.
## The run's shape is the screen's shape, and a journey reads as a journey.
##
## x is depth (MapNode.row, one stage per step) and y is lane (MapNode.col,
## centred on ORIGIN). Origin starts at x=200 to leave the left gutter free for
## the keyboard/screen-reader fallback in run_screen.gd.

signal node_chosen(node)

const STAGE_X := 104.0
const LANE_Y := 58.0
# Stage 0 sits at ORIGIN.x; the single entrance sits one step LEFT of it, which
# is why the gutter has to be wide enough for a node and not just a margin.
const ORIGIN := Vector2(248.0, 290.0)
const RADIUS := 11.0

var map: MapGenerator
var current: MapNode = null
var available: Array = []
var hovered: MapNode = null

var _time: float = 0.0

func setup(p_map: MapGenerator, p_current: MapNode, p_available: Array) -> void:
	map = p_map
	current = p_current
	available = p_available
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	# Every node animates now, not just the available ones.
	queue_redraw()

func pos_for(n: MapNode) -> Vector2:
	if map and map.boss and n == map.boss:
		return ORIGIN + Vector2(float(MapGenerator.ROWS) * STAGE_X, 0.0)
	var lane := float(n.col) - float(MapGenerator.WIDTH - 1) * 0.5
	return ORIGIN + Vector2(float(n.row) * STAGE_X, lane * LANE_Y)

func _draw() -> void:
	if map == null:
		return

	# Edges first, so nodes sit on top of them.
	for n in _every_node():
		for nxt in n.next:
			var a := pos_for(n)
			var b := pos_for(nxt)
			var lit: bool = n.visited and (nxt.visited or available.has(nxt))
			var col := Palette.EMBER_DEEP if lit else Palette.BORDER
			draw_line(a, b, col, 2.0 if lit else 1.0)

	for n in _every_node():
		_draw_node(n)
	if map.boss:
		_draw_node(map.boss)
	_draw_hover_label()

## Every node the graph actually contains, entrance included. Walking `rows`
## alone skipped the origin, so the entrance and its four edges were absent from
## a screen whose whole job is to show where you can go.
func _every_node() -> Array:
	var out: Array = []
	if map.origin:
		out.append(map.origin)
	for row in map.rows:
		out.append_array(row)
	return out

## What the hovered stop is, drawn beside it. The copy already existed but was
## reachable only from the keyboard fallback buttons in the left gutter, so
## hovering the map itself -- the thing the player is actually looking at --
## told them nothing.
func _draw_hover_label() -> void:
	if hovered == null:
		return
	var font := ThemeDB.fallback_font
	var title := MapNode.label_for(hovered.kind)
	if hovered.row >= 0:
		title += " — stage %d" % (hovered.row + 1)
	var hint := MapNode.hint_for(hovered.kind)
	var tw: float = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x,
		font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	var p := pos_for(hovered)
	# Flip to the left of the node when the box would run off the right edge.
	var box := Rect2(p.x + 18.0, p.y - 30.0, tw + 16.0, 44.0)
	if box.position.x + box.size.x > 952.0:
		box.position.x = p.x - 18.0 - box.size.x
	draw_rect(box, Palette.GROUND)
	draw_rect(box, Palette.BORDER, false, 2.0)
	draw_string(font, box.position + Vector2(8, 18), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_LIGHT)
	draw_string(font, box.position + Vector2(8, 34), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_MID)

func _draw_node(n: MapNode) -> void:
	var p := pos_for(n)
	var is_available: bool = available.has(n)
	var is_current: bool = n == current
	var r := RADIUS if n.kind != MapNode.Kind.BOSS else RADIUS * 1.6

	if is_available:
		# Pulse: the only moving thing on this screen, so the eye goes straight
		# to what the player can actually do.
		var pulse := 1.0 + sin(_time * 4.0) * 0.12
		draw_circle(p, r * pulse + 5.0, Color(Palette.SPARK, 0.16))
		draw_arc(p, r * pulse + 3.0, 0, TAU, 24, Palette.SPARK, 2.0)

	var fill := _colour(n.kind)
	if not (is_available or is_current or n.visited):
		fill = fill.darkened(0.55)

	draw_circle(p, r + 1.0, Palette.OUTLINE)
	draw_circle(p, r, fill)

	if n == hovered:
		draw_arc(p, r + 4.0, 0, TAU, 24, Palette.WHITE, 2.0)
	if is_current:
		draw_arc(p, r + 6.0, 0, TAU, 24, Palette.SPARK, 3.0)

	# An icon, not a letter. Each kind moves in a way that says what it is: the
	# campfire flickers, treasure bobs like it is being lifted, the boss breathes.
	# Every phase is derived from the node's own position so no two tick together.
	var icon := IconArt.for_node(_icon_name(n.kind), Palette.GROUND, Palette.OUTLINE)
	var scale := 1.0 if n.kind != MapNode.Kind.BOSS else 1.6
	var phase := float(n.row) * 1.7 + float(n.col) * 0.9
	var bob := 0.0
	var squash := 1.0
	if Juice.intensity > 0.0:
		match n.kind:
			MapNode.Kind.CAMPFIRE:
				squash = 1.0 + sin(_time * 7.0 + phase) * 0.09
			MapNode.Kind.TREASURE:
				bob = sin(_time * 2.4 + phase) * 1.4
			MapNode.Kind.BOSS:
				squash = 1.0 + sin(_time * 1.9) * 0.06
			_:
				bob = sin(_time * 1.6 + phase) * 0.8
		bob *= Juice.intensity
		squash = 1.0 + (squash - 1.0) * Juice.intensity
	var w := float(IconArt.SIZE) * scale
	var h := w * squash
	draw_texture_rect(icon, Rect2(p - Vector2(w, h) * 0.5 + Vector2(0, bob),
		Vector2(w, h)), false)

## The icon file name for a node kind. Kept separate from _glyph, which the
## legend still uses to name each kind in text.
func _icon_name(kind: int) -> String:
	match kind:
		MapNode.Kind.COMBAT:   return "combat"
		MapNode.Kind.ELITE:    return "elite"
		MapNode.Kind.EVENT:    return "event"
		MapNode.Kind.SHOP:     return "shop"
		MapNode.Kind.CAMPFIRE: return "campfire"
		MapNode.Kind.TREASURE: return "treasure"
		MapNode.Kind.BOSS:     return "boss"
		MapNode.Kind.DRAFT:    return "draft"
		_: return "combat"

func _colour(kind: int) -> Color:
	match kind:
		MapNode.Kind.COMBAT:   return Palette.INK_MID
		MapNode.Kind.ELITE:    return Palette.RED
		MapNode.Kind.EVENT:    return Palette.VIOLET
		MapNode.Kind.SHOP:     return Palette.SPARK
		MapNode.Kind.CAMPFIRE: return Palette.CLAY   # FLAME is treasure; a rest must not read as loot
		MapNode.Kind.TREASURE: return Palette.FLAME
		MapNode.Kind.BOSS:     return Palette.ALARM
		MapNode.Kind.DRAFT:    return Palette.BONE
		_: return Palette.INK_MUTED

func _glyph(kind: int) -> String:
	match kind:
		MapNode.Kind.COMBAT:   return "x"
		MapNode.Kind.ELITE:    return "X"
		MapNode.Kind.EVENT:    return "?"
		MapNode.Kind.SHOP:     return "$"
		MapNode.Kind.CAMPFIRE: return "^"
		MapNode.Kind.TREASURE: return "T"
		MapNode.Kind.BOSS:     return "B"
		_: return ""

func node_at(point: Vector2) -> MapNode:
	for n in available:
		if point.distance_to(pos_for(n)) <= RADIUS + 8.0:
			return n
	return null

func _input(event: InputEvent) -> void:
	if map == null or available.is_empty():
		return
	var m := get_global_mouse_position()
	if event is InputEventMouseMotion:
		var h := node_at(m)
		if h != hovered:
			hovered = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var n := node_at(m)
		if n:
			node_chosen.emit(n)
