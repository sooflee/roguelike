class_name TitleView
extends Control
## The start-up screen: full-bleed art, your starter, and one button.
##
## No veil over the art. This screen has almost no text to protect, so the
## scene gets to be the whole picture -- which is the point of a title screen.

signal new_run_requested
signal continue_requested

const FRAME := Vector2(960, 540)
const SPARKS := 30

var _sparks: Array[Vector3] = []
var _time: float = 0.0
var _has_save := false
var _selected := false
var _start_btn: Button

func setup(has_save: bool) -> void:
	_has_save = has_save

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var art := TextureRect.new()
	art.texture = PlaceholderArt.for_background(&"route")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var motes := _Motes.new()
	motes.owner_view = self
	add_child(motes)

	var mark := TextureRect.new()
	mark.texture = TitleArt.wordmark("EMBERWRIGHT")
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.stretch_mode = TextureRect.STRETCH_SCALE
	mark.size = Vector2(65 * 5, 9 * 5)
	mark.position = Vector2(480 - 65 * 2.5, 40)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)

	_caption("Choose your partner.", 120, 15, Palette.INK_LIGHT)

	# The starter. One option today, but built as a row so a second and third
	# slot is a data change rather than a rewrite of this screen.
	var slot := _starter_slot(Vector2(480 - 72, 170), PlaceholderArt.for_player())
	_caption("CHARMANDER", 320, 17, Palette.BONE)
	_caption("Fire  ·  the only one ready to travel", 344, 13, Palette.INK_MID)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.position = Vector2(480 - 120, 396)
	menu.custom_minimum_size = Vector2(240, 0)
	add_child(menu)
	if _has_save:
		_menu_button(menu, "Continue run", func(): continue_requested.emit())
	_start_btn = _menu_button(menu, "Start", func(): new_run_requested.emit())
	_start_btn.disabled = true
	slot.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(slot))

	for i in SPARKS:
		_sparks.append(Vector3(randf() * 960.0, randf() * 540.0, 12.0 + randf() * 22.0))
	# Pre-selected, because refusing to start until you click the only option
	# available is a puzzle, not a choice.
	_select(slot)
	set_process(true)

func _starter_slot(at: Vector2, tex: Texture2D) -> Panel:
	var slot := Panel.new()
	slot.position = at
	slot.size = Vector2(144, 144)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.GROUND, 0.55)
	box.border_color = Palette.BORDER
	box.set_border_width_all(2)
	slot.add_theme_stylebox_override("panel", box)
	add_child(slot)
	var mon := StarterView.new()
	mon.set_anchors_preset(Control.PRESET_FULL_RECT)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(mon)
	mon.setup(tex, 1.3)
	return slot

func _select(slot: Panel) -> void:
	_selected = true
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.GROUND, 0.55)
	box.border_color = Palette.SPARK
	box.set_border_width_all(3)
	slot.add_theme_stylebox_override("panel", box)
	if _start_btn:
		_start_btn.disabled = false
		_start_btn.call_deferred("grab_focus")

func _caption(text: String, y: float, size: int, colour: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(230, y)
	l.size = Vector2(500, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

func _menu_button(into: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 38)
	# Godot's default chrome is rounded and grey; against pixel art it reads as
	# an operating system sitting on top of the game.
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.GROUND if state == "normal" else Palette.SURFACE
		box.border_color = Palette.SPARK if state in ["hover", "focus"] else Palette.BORDER
		box.set_border_width_all(2)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Palette.INK_LIGHT)
	b.add_theme_color_override("font_hover_color", Palette.BONE)
	b.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.5)
		cb.call())
	into.add_child(b)
	return b

func _process(delta: float) -> void:
	if Juice.intensity <= 0.0:
		return
	_time += delta
	for i in _sparks.size():
		var s: Vector3 = _sparks[i]
		s.y -= s.z * delta
		s.x += sin(_time * 1.3 + float(i)) * 10.0 * delta
		if s.y < -4.0:
			s = Vector3(randf() * 960.0, 560.0, 12.0 + randf() * 22.0)
		_sparks[i] = s
	queue_redraw()

## Drifting motes, above the art and below the wordmark.
class _Motes extends Node2D:
	var owner_view: TitleView

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		if owner_view == null:
			return
		for s in owner_view._sparks:
			var fade: float = clampf(s.y / 540.0, 0.15, 0.9)
			draw_rect(Rect2(roundf(s.x), roundf(s.y), 2, 2), Color(Palette.BONE, fade))
