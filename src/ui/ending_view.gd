class_name EndingView
extends Control
## How a run ends, win or lose. Full art, your Pokemon, and the numbers.
##
## The old version was a bold line of text and a button on a flat plate, which
## is the least memorable moment in a roguelike getting the least attention.
## The run's ending is the thing a player retells.

signal again_requested

## setup() can run either side of this view entering the tree, and WeatherFx
## lifts itself to z_index 120 in its own _ready() so it can sit over a battle.
## Here that put the wash and 90 streaks on top of the headline, the stats and
## the only button. Godot runs a parent's _ready() after its children's, so this
## is the one place that reliably wins.
func _ready() -> void:
	if _rain == null:
		return
	_rain.z_index = 0
	# WeatherFx._process bails at intensity 0 but _draw still paints, which left
	# reduce motion with a field of rain frozen mid-fall rather than no rain.
	_rain.modulate.a = clampf(Juice.intensity, 0.0, 1.0)

## A soft ellipse under the body. Without one he reads as floating above the
## field rather than lying on it -- the sprite alone cannot say "ground".
class _Shadow extends Control:
	func _draw() -> void:
		draw_set_transform(size * 0.5, 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, size.x * 0.5, Color(Palette.GROUND, 0.5))

var _fainted := false
## The two forms of the evolution, stacked in the same place. Only one is ever
## visible; the sequence swaps which.
var _before: StarterView = null
var _after: StarterView = null
var _evolved_line: Label = null
var _rain: WeatherFx = null

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
		_rain = rain

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
		# The cry, slowed and dropped -- which is how the games play a fainting
		# cry, and it lands better than any sound effect would.
		Audio.play(&"charmander_faint", 1.0, 0.95)
	else:
		# The FRONT sprite: for_player() is the battle back sprite, which is right
		# over his shoulder in a fight and wrong on a screen he is facing you from.
		mon.setup(PlaceholderArt.for_player_front(), 1.7)
		_before = mon
		_after = StarterView.new()
		_after.position = mon.position
		_after.size = mon.size
		_after.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_after)
		# Bigger than Charmander was. The size change IS the evolution -- holding
		# both at one scale made it a costume swap.
		_after.setup(PlaceholderArt.for_partner(&"charmeleon"), 2.5)
		_after.visible = false

	_line("CHARMANDER FAINTED!" if _fainted else "Blastoise slayed!",
		96 if _fainted else 88, 30, Palette.ALARM if _fainted else Palette.SPARK)
	# Above the body on a defeat, below the standing sprite on a win.
	if _fainted:
		_line("You blacked out.", 150, 16, Palette.INK_LIGHT)
	else:
		# Filled in when the evolution lands, so the screen does not announce it
		# before it has happened.
		_evolved_line = _line("", 356, 18, Palette.FLAME)
		# Saying plainly that the game stops here. A victory screen that reads as
		# THE END on an act-one boss tells the player they have seen everything.
		_line("The next part is under construction.", 390, 15, Palette.INK_LIGHT)
	# Only on a defeat. After a win the evolution is the payoff and a row of
	# tallies underneath reads as a results screen interrupting it.
	if _fainted:
		_line("Stages cleared %d      Moves known %d      Held items %d" % [
			run.floors_cleared, run.deck.size(), run.relics.size()], 182, 14, Palette.INK_MID)

	var again := Button.new()
	again.text = "Set out again"
	again.custom_minimum_size = Vector2(240, 40)
	again.position = Vector2(480 - 120, 470 if _fainted else 462)
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
	if not _fainted:
		_evolve()

func _line(text: String, y: float, size: int, colour: Color) -> Label:
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
	return l

## The evolution, as the games play it: the two forms alternate in white
## silhouette, faster and faster, then the new one resolves out of the flash.
##
## Both forms sit in the same place and only one is ever visible, which is what
## makes the swap read as one creature changing rather than two sprites
## crossfading. Blown out with modulate above 1.0 rather than a shader, because
## the ending screen has no material on its sprites and does not need one.
const WHITE_OUT := Color(9.0, 9.0, 9.0, 1.0)
const SWAPS := 9

func _evolve() -> void:
	if _before == null or _after == null:
		return
	if Juice.intensity <= 0.0:
		# Reduce motion (D-23) gets the outcome without the strobe -- and this
		# particular animation is a flashing one, so honouring that matters more
		# here than anywhere else in the game.
		_land()
		return
	Audio.play(&"charmander_name", 1.0, 0.95)
	_before.modulate = WHITE_OUT
	_after.modulate = WHITE_OUT
	var t := create_tween()
	t.tween_interval(Juice.dur(0.7))      # a beat to read the headline first
	for i in SWAPS:
		var showing_after := i % 2 == 1
		t.tween_callback(func():
			_before.visible = not showing_after
			_after.visible = showing_after)
		t.tween_interval(Juice.dur(lerpf(0.30, 0.07, float(i) / float(SWAPS - 1))))
	t.tween_callback(_land)

## Settles on the evolved form and says so.
func _land() -> void:
	_before.visible = false
	_after.visible = true
	if _evolved_line:
		_evolved_line.text = "CHARMANDER evolved into CHARMELEON!"
	# The voice changes with the form. A generic fanfare here would throw away
	# the one moment the sound can do the storytelling.
	Audio.play(&"charmeleon_voice", 1.0, 1.0)
	if Juice.intensity <= 0.0:
		_after.modulate = Color(1, 1, 1, 1)
		return
	var out := create_tween()
	out.tween_property(_after, "modulate", Color(1, 1, 1, 1), Juice.dur(0.5))
