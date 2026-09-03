class_name CardView
extends Node2D
## One card in hand. Owns its own hover/select/play motion.
##
## Card size is the art bible's 96x132 (docs/DECISIONS.md D-09), so the grey-box
## already sits at the real proportions and hand-drawn frames drop in without
## relayout.

const W := 96
const H := 132
const ART_W := 80
const ART_H := 56
## The name sits left of the cost orb, whose left edge is at W-21.
const TITLE_SIZE := 12
const TITLE_W := W - 26

signal pressed(view)

var card: Card
var art: Texture2D
var playable: bool = true

## Idle drift. Deliberately below the threshold of conscious notice -- a hand of
## ten cards all moving is a hand nobody can read.
const DRIFT_SPEED := 1.3
const DRIFT_RISE := 1.6
const DRIFT_TILT := 0.006

var _drift_time: float = 0.0
var _drift_phase: float = 0.0
## True while a tween owns this card's position, so drift never fights it.
var _busy: bool = false
var selected: bool = false

var home_pos: Vector2 = Vector2.ZERO
var home_rot: float = 0.0
var hovered: bool = false
var dragging: bool = false

var _title: Label
var _text: Label
var _cost: Label
var _badge: Label = null

func setup(c: Card) -> void:
	card = c
	art = CardArt.for_card(c.data)

	_title = _label(TITLE_SIZE, Palette.WHITE)
	_title.position = Vector2(-W / 2.0 + 4, -H / 2.0 + 4)
	_title.custom_minimum_size = Vector2(TITLE_W, 0)
	_title.text = c.title()
	_fit_title()

	_cost = _label(15, Palette.SPARK)
	_cost.position = Vector2(W / 2.0 - 18, -H / 2.0 + 3)
	_cost.text = str(c.cost())

	# The pixel font runs tighter than Godot's default, so the rules block can
	# start higher and still clear the 80x56 art window that ends at y=80.
	_text = _label(10, Palette.INK_LIGHT)
	_text.position = Vector2(-W / 2.0 + 5, -H / 2.0 + 82)
	_text.custom_minimum_size = Vector2(W - 10, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.text = c.describe()
	_fit_text()
	_drift_phase = randf() * TAU
	set_process(true)
	queue_redraw()

## Re-renders this view for a different card WITHOUT rebuilding its labels.
## Calling setup() again would stack a second set of Labels on top of the first,
## so the upgrade preview -- which swaps the same card back and forth as a key
## is held -- needs a way to change what is drawn in place.
func refresh(c: Card) -> void:
	card = c
	art = CardArt.for_card(c.data)
	_title.text = c.title()
	_fit_title()
	_cost.text = str(c.cost())
	_text.text = c.describe()
	_fit_text()
	queue_redraw()

## A price, drawn in the card's own frame. The shop used to put the cost in a
## line of text beside the card's name; on the card it is where the player is
## already looking, and it moves with the card.
func set_badge(text: String, affordable: bool = true) -> void:
	if _badge == null:
		_badge = _label(12, Palette.SPARK)
	_badge.text = text
	_badge.add_theme_color_override("font_color",
		Palette.SPARK if affordable else Palette.INK_MUTED)
	# Centred under the frame, once the label knows how wide its own text is.
	await get_tree().process_frame
	if is_instance_valid(_badge):
		_badge.position = Vector2(-_badge.size.x * 0.5, H / 2.0 + 3)

func _process(delta: float) -> void:
	_idle_drift(delta)

## Shrinks the rules text until it fits inside the card.
##
## A fixed font size cannot work across 61 cards: "Deal 6 damage." and "Spend up
## to 2 of your remaining PP. Deal 5 damage per PP spent." are the same box
## and four times the text, so any size that suits one overflows the other and
## spills onto the board behind it.
func _fit_text() -> void:
	var font: Font = _text.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var box_w := float(W - 10)
	# From the top of the text block to the bottom edge, less a pixel of
	# margin -- and less the keyword stripes, which _draw() paints INSIDE
	# the frame along that edge. Ignoring them is how "draw 1 card." ended
	# up printed across the ember bar on every Overload card.
	var box_h := float(H) * 0.5 - _text.position.y - 3.0 - _stripe_height()
	# get_multiline_string_size() measures glyphs only. The Label also adds
	# line_spacing between rows, so a three-line block is measured short by
	# two gaps and "fits" a box it overflows.
	var spacing := float(_text.get_theme_constant("line_spacing"))
	for size in [10, 9, 8, 7, 6]:
		var measured := font.get_multiline_string_size(
			_text.text, HORIZONTAL_ALIGNMENT_LEFT, box_w, size)
		var lines := maxi(1, int(round(measured.y / maxf(font.get_height(size), 1.0))))
		var needed := measured.y + float(lines - 1) * spacing
		if needed <= box_h or size == 6:
			_text.add_theme_font_size_override("font_size", size)
			return

## Height of the keyword stripes _draw() paints along the bottom edge.
func _stripe_height() -> float:
	if card == null:
		return 0.0
	if card.data.exhaust:
		return 8.0   # violet bar at H-8, ember bar may sit under it
	if card.data.overload_bonus:
		return 4.0
	return 0.0

## Shrinks the name until it clears the cost orb.
##
## "Focus Energy" and "Smokescreen" are wider than the gap at size 12, and
## a Label does not shrink itself -- it just draws past its minimum size,
## straight through the orb.
func _fit_title() -> void:
	var font: Font = _title.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	for size in [TITLE_SIZE, 11, 10, 9, 8]:
		if font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= float(TITLE_W) or size == 8:
			_title.add_theme_font_size_override("font_size", size)
			return

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l

## Cards drift in the hand. The motion is tiny and each card runs on its own
## phase, so a fanned hand reads as held rather than pinned to a board. Only
## affordable cards move: stillness is the cheapest way to say "not this turn",
## and it survives being colour-blind, which the dimming alone does not.
func _idle_drift(delta: float) -> void:
	if Juice.intensity <= 0.0 or _busy or hovered:
		return
	_drift_time += delta
	var t := _drift_time * DRIFT_SPEED + _drift_phase
	var amount := (1.0 if playable else 0.0) * Juice.intensity
	position = home_pos + Vector2(0, sin(t) * DRIFT_RISE * amount)
	rotation = home_rot + sin(t * 0.7) * DRIFT_TILT * amount

func set_playable(v: bool) -> void:
	if playable == v:
		return
	playable = v
	modulate = Color(1, 1, 1, 1) if v else Color(0.55, 0.55, 0.62, 1)
	queue_redraw()

func set_selected(v: bool) -> void:
	if selected == v:
		return
	selected = v
	queue_redraw()

func _draw() -> void:
	if card == null:
		return
	var origin := Vector2(-W / 2.0, -H / 2.0)
	var type_color := Palette.for_card_type(card.data.type)
	# Frame: 1px outline in a dark palette colour, never pure black.
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(W + 2, H + 2)), Palette.OUTLINE)
	draw_rect(Rect2(origin, Vector2(W, H)), Palette.SURFACE)
	draw_rect(Rect2(origin, Vector2(W, 20)), type_color)
	if art:
		draw_texture_rect(art, Rect2(origin + Vector2(8, 24), Vector2(ART_W, ART_H)), false)
	draw_rect(Rect2(origin + Vector2(8, 24), Vector2(ART_W, ART_H)), Palette.OUTLINE, false, 1.0)

	# Cost orb.
	draw_circle(origin + Vector2(W - 12, 10), 9, Palette.OUTLINE)
	draw_circle(origin + Vector2(W - 12, 10), 8, Palette.QUENCH_DEEP)

	# The move's type, as a band down the left edge. A card game where type
	# decides damage needs type readable without reading the text, and a full
	# edge survives the card being overlapped by its neighbours in the fan.
	var type_col := Element.colour(card.data.element)
	draw_rect(Rect2(origin, Vector2(5, H)), type_col)
	draw_rect(Rect2(origin, Vector2(5, 3)), Palette.BONE)

	if card.data.overload_bonus:
		draw_rect(Rect2(origin + Vector2(0, H - 4), Vector2(W, 4)), Palette.EMBER)
	if card.data.exhaust:
		draw_rect(Rect2(origin + Vector2(0, H - 8), Vector2(W, 3)), Palette.VIOLET)

	var border := Palette.SPARK if (selected or dragging) else (Palette.QUENCH_BRIGHT if hovered else Palette.BORDER)
	draw_rect(Rect2(origin, Vector2(W, H)), border, false, 2.0)

	# Out of reach: a wash over the whole card rather than a dimmed border, so
	# "cannot afford this" survives at a glance across a shelf of five.
	if not playable:
		draw_rect(Rect2(origin, Vector2(W, H)), Color(Palette.GROUND, 0.55))

# --- motion ----------------------------------------------------------------

## Eases to its slot in the fan rather than snapping. Called on every relayout.
func glide_to(pos: Vector2, rot: float, duration: float = 0.22) -> void:
	home_pos = pos
	home_rot = rot
	_busy = true
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", pos, Juice.dur(duration))
	t.tween_property(self, "rotation", rot, Juice.dur(duration))
	t.finished.connect(func(): _busy = false)

## Arcs in from the draw pile. The overshoot is what makes a draw feel dealt
## rather than teleported.
func deal_from(start: Vector2, pos: Vector2, rot: float, delay: float = 0.0) -> void:
	home_pos = pos
	home_rot = rot
	_busy = true
	position = start
	rotation = -0.6
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	if delay > 0.0:
		t.tween_interval(Juice.dur(delay))
	t.chain().set_parallel(true)
	t.tween_property(self, "position", pos, Juice.dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", rot, Juice.dur(0.3)).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "scale", Vector2.ONE, Juice.dur(0.26)).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, Juice.dur(0.16))
	t.finished.connect(func(): _busy = false)

## Carried by the cursor: lifted above everything, scaled up a touch, and held
## out of the idle drift so the card sits exactly where the hand puts it.
func set_dragging(v: bool) -> void:
	dragging = v
	_busy = v
	z_index = 90 if v else 0
	scale = Vector2(1.12, 1.12) if v else Vector2.ONE
	if v:
		rotation = 0.0
	queue_redraw()

func set_hover(v: bool) -> void:
	if hovered == v:
		return
	hovered = v
	queue_redraw()
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if v:
		z_index = 50
		t.tween_property(self, "position", home_pos + Vector2(0, -26), Juice.dur(0.12))
		t.tween_property(self, "scale", Vector2(1.12, 1.12), Juice.dur(0.12))
		t.tween_property(self, "rotation", 0.0, Juice.dur(0.12))
	else:
		z_index = 0
		t.tween_property(self, "position", home_pos, Juice.dur(0.14))
		t.tween_property(self, "scale", Vector2.ONE, Juice.dur(0.14))
		t.tween_property(self, "rotation", home_rot, Juice.dur(0.14))
		# Drift stays out of the way until the card is actually back home.
		_busy = true
		t.finished.connect(func(): _busy = false)

## Play arc. Every card used to leave the hand the same way, which meant the
## most expressive moment in the game -- the one the player caused -- said
## nothing about what they had just done.
##
## `style` comes from the card's own effects (CardArt.motif_for), so the motion
## matches the illustration: attacks lunge at the target, blocks plant, ramp
## rises into the gauge, overload rushes right, cash-out tips and pours.
## `aim` is where the card should travel for styles that go somewhere specific.
func play_to(centre: Vector2, exit: Vector2, on_impact: Callable,
		style: StringName = &"", aim: Vector2 = Vector2.ZERO) -> void:
	_busy = true          # never released: this card is on its way out
	z_index = 80
	match style:
		&"blade":    _play_blade(centre, exit, on_impact, aim)
		&"block":    _play_block(centre, exit, on_impact)
		&"ramp":     _play_ramp(centre, on_impact, aim)
		&"overload": _play_overload(centre, exit, on_impact)
		&"cash_out": _play_cash_out(centre, exit, on_impact)
		&"draw":     _play_draw(centre, exit, on_impact)
		_:           _play_default(centre, exit, on_impact)

func _fade_out(t: Tween, exit: Vector2, secs: float) -> void:
	t.tween_property(self, "position", exit, Juice.dur(secs)).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), Juice.dur(secs))
	t.parallel().tween_property(self, "modulate:a", 0.0, Juice.dur(secs))
	t.tween_callback(queue_free)

func _play_default(centre: Vector2, exit: Vector2, on_impact: Callable) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", centre, Juice.dur(0.16))
	t.parallel().tween_property(self, "rotation", 0.0, Juice.dur(0.16))
	t.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), Juice.dur(0.16))
	t.tween_interval(Juice.dur(0.08))
	t.tween_callback(on_impact)
	_fade_out(t, exit, 0.22)

## Wind back, then drive at the target. The pause before the lunge is what makes
## the hit land rather than merely happen.
func _play_blade(centre: Vector2, exit: Vector2, on_impact: Callable, aim: Vector2) -> void:
	var strike: Vector2 = aim if aim != Vector2.ZERO else centre
	var wind := centre + (centre - strike).normalized() * 34.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", wind, Juice.dur(0.14))
	t.parallel().tween_property(self, "rotation", -0.35, Juice.dur(0.14))
	t.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), Juice.dur(0.14))
	t.tween_interval(Juice.dur(0.05))
	t.tween_property(self, "position", strike, Juice.dur(0.09)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", 0.42, Juice.dur(0.09))
	t.tween_callback(on_impact)
	_fade_out(t, exit, 0.18)

## Plants itself and pushes outward. No travel: block is something you do here.
func _play_block(centre: Vector2, exit: Vector2, on_impact: Callable) -> void:
	var t := create_tween()
	t.tween_property(self, "position", centre + Vector2(0, 14), Juice.dur(0.13)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", 0.0, Juice.dur(0.13))
	t.parallel().tween_property(self, "scale", Vector2(1.28, 0.82), Juice.dur(0.13))
	t.tween_callback(on_impact)
	t.tween_property(self, "scale", Vector2(1.05, 1.24), Juice.dur(0.12)).set_trans(Tween.TRANS_ELASTIC)
	_fade_out(t, exit, 0.2)

## Rises into the gauge: the card becomes the curve it just raised.
func _play_ramp(centre: Vector2, on_impact: Callable, aim: Vector2) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", centre + Vector2(0, -30), Juice.dur(0.2))
	t.parallel().tween_property(self, "rotation", 0.0, Juice.dur(0.2))
	t.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), Juice.dur(0.2))
	t.tween_callback(on_impact)
	var land: Vector2 = aim if aim != Vector2.ZERO else centre
	t.tween_property(self, "position", land, Juice.dur(0.26)).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.25, 0.25), Juice.dur(0.26))
	t.parallel().tween_property(self, "modulate:a", 0.0, Juice.dur(0.26))
	t.tween_callback(queue_free)

## Rushes right and leaves. Same direction the card art points.
func _play_overload(centre: Vector2, exit: Vector2, on_impact: Callable) -> void:
	var t := create_tween()
	t.tween_property(self, "position", centre - Vector2(46, 0), Juice.dur(0.11)).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", 0.0, Juice.dur(0.11))
	t.tween_property(self, "position", centre + Vector2(70, 0), Juice.dur(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(1.3, 0.9), Juice.dur(0.1))
	t.tween_callback(on_impact)
	_fade_out(t, exit, 0.18)

## Tips over and pours downward.
func _play_cash_out(centre: Vector2, exit: Vector2, on_impact: Callable) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "position", centre, Juice.dur(0.15)).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", 1.35, Juice.dur(0.22))
	t.tween_callback(on_impact)
	t.tween_property(self, "position", centre + Vector2(0, 120), Juice.dur(0.24)).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, Juice.dur(0.24))
	t.tween_callback(queue_free)

## Spins, because drawing is a shuffle of the deck rather than a blow.
func _play_draw(centre: Vector2, exit: Vector2, on_impact: Callable) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", centre, Juice.dur(0.15))
	t.parallel().tween_property(self, "rotation", TAU, Juice.dur(0.28))
	t.tween_callback(on_impact)
	_fade_out(t, exit, 0.2)

func hit_test(point: Vector2) -> bool:
	var half := Vector2(W, H) * 0.5 * scale
	return Rect2(global_position - half, half * 2.0).has_point(point)
