class_name EventScene
extends Control
## The place an event happens in: full-bleed scene art, a plate for the words to
## sit on, and Charmander standing in it.
##
## Events were left-aligned prose on the same veiled route as every other meta
## screen, so a hot spring, a berry tree and nightfall all looked identical --
## and the one character actually standing there was never on screen. The scene
## is named by the event's own `scene` field, so it stays a data edit (D-14).

## The column the text is allowed to use. Everything outside it is art, so the
## plate has to agree with what run_screen centres its labels to.
var _plate: Control = null
var _body: Control = null

const PLATE_W := 620.0
const PLATE_TOP := 88.0
## The plate tracks the body it sits behind, rather than guessing a height.
##
## Counting choices is not enough: prose wraps to a different number of lines
## per event and a long choice label wraps its own button, so a four-choice
## event overhung a plate sized by row count. The body knows its real height
## once laid out, so ask it.
const PLATE_PAD := 14.0
const PLATE_MIN_BOTTOM := 300.0
const PLATE_MAX_BOTTOM := 486.0

## `body` is the run screen's content column. Held so the plate can follow it.
func setup(scene: StringName, body: Control = null) -> void:
	_body = body
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := TextureRect.new()
	art.texture = PlaceholderArt.for_event_scene(scene)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	# Charmander, stood in the scene rather than on a menu. He goes to the left
	# of the text column, in the strip of art the plate leaves free.
	var mon := StarterView.new()
	mon.position = Vector2(4, 320)
	mon.size = Vector2(150, 150)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mon)
	mon.setup(PlaceholderArt.for_player(), 1.6)

	# Text over a lit landscape is unreadable. Darkening the WHOLE frame is what
	# made every event look like the same screen, so the veil is confined to the
	# column the words are actually in.
	var plate := _Plate.new()
	plate.position = Vector2(480.0 - PLATE_W * 0.5, PLATE_TOP)
	plate.size = Vector2(PLATE_W, PLATE_MIN_BOTTOM - PLATE_TOP)
	_plate = plate
	set_process(true)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

class _Plate extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.GROUND, 0.84))
		draw_rect(Rect2(Vector2.ZERO, size), Palette.BORDER, false, 2.0)

## The body is rebuilt and re-laid-out over several frames as an event resolves,
## so this follows it every frame rather than measuring once and going stale.
func _process(_delta: float) -> void:
	if _plate == null or _body == null or not is_instance_valid(_body):
		return
	var bottom := _body.global_position.y + _body.size.y + PLATE_PAD
	bottom = clampf(bottom, PLATE_MIN_BOTTOM, PLATE_MAX_BOTTOM)
	_plate.size.y = bottom - PLATE_TOP
