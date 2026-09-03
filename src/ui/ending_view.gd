class_name EndingView
extends Control
## How a run ends, win or lose. Full art, your Pokemon, and the numbers.
##
## The old version was a bold line of text and a button on a flat plate, which
## is the least memorable moment in a roguelike getting the least attention.
## The run's ending is the thing a player retells.

signal again_requested

## A soft ellipse under the body. Without one he reads as floating above the
## field rather than lying on it -- the sprite alone cannot say "ground".
class _Shadow extends Control:
	func _draw() -> void:
		draw_set_transform(size * 0.5, 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, size.x * 0.5, Color(Palette.GROUND, 0.5))

var _fainted := false

func setup(won: bool, run: RunState) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fainted = not won

	var art := TextureRect.new()
	art.texture = PlaceholderArt.for_background(&"route")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var wash := ColorRect.new()
	# Defeat drains the colour out of the scene; victory only warms it.
	wash.color = Color(Palette.GROUND, 0.66) if _fainted else Color(Palette.FLAME, 0.12)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	if _fainted:
		# It rains on the ending you lost. WeatherFx already knew how to draw
		# this; it only needed a way to be switched on with no fight behind it.
		var rain := WeatherFx.new()
		rain.set_anchors_preset(Control.PRESET_FULL_RECT)
		rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rain)
		rain.set_weather(&"rain")

	if _fainted:
		var shade := _Shadow.new()
		shade.position = Vector2(480 - 130, 402)
		shade.size = Vector2(260, 54)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)

	var mon := StarterView.new()
	# Defeat lays him out on the ground, so he sits low in the frame with the
	# text above him. Victory keeps him standing where he always stood.
	mon.position = Vector2(480 - 110, 300 if _fainted else 150)
	mon.size = Vector2(220, 190)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mon)
	if _fainted:
		# On his side, still, with the tail flame out. In this franchise that
		# flame is the character's life, so putting it out carries the moment
		# on its own -- the line of text underneath is only the caption.
		mon.still = true
		mon.setup(PlaceholderArt.for_player_snuffed(), 1.8)
		mon.sprite_rotation = PI / 2.0
		mon.modulate = Color(0.62, 0.64, 0.72, 1.0)
	else:
		mon.setup(PlaceholderArt.for_player(), 1.7)

	_line("CHARMANDER FAINTED!" if _fainted else "THE CHAMPION FALLS!",
		96, 30, Palette.ALARM if _fainted else Palette.SPARK)
	# Above the body on a defeat, below the standing sprite on a win.
	_line("You blacked out." if _fainted else "Blastoise is beaten. The route is yours.",
		150 if _fainted else 358, 16, Palette.INK_LIGHT)
	_line("Stages cleared %d      Moves known %d      Held items %d" % [
		run.floors_cleared, run.deck.size(), run.relics.size()],
		182 if _fainted else 390, 14, Palette.INK_MID)

	var again := Button.new()
	again.text = "Set out again"
	again.custom_minimum_size = Vector2(240, 40)
	again.position = Vector2(480 - 120, 470 if _fainted else 434)
	again.size = Vector2(240, 40)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.GROUND if state == "normal" else Palette.SURFACE
		box.border_color = Palette.SPARK if state in ["hover", "focus"] else Palette.BORDER
		box.set_border_width_all(2)
		box.set_content_margin_all(6)
		again.add_theme_stylebox_override(state, box)
	again.add_theme_color_override("font_color", Palette.INK_LIGHT)
	again.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.5)
		again_requested.emit())
	add_child(again)
	again.call_deferred("grab_focus")

func _line(text: String, y: float, size: int, colour: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(80, y)
	l.size = Vector2(800, size + 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
