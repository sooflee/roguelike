class_name EventScene
extends Control
## The place something happens in: full-bleed scene art, weather and drifting
## motes in the air, a plate for the words to sit on, and Charmander standing
## in it.
##
## Events were left-aligned prose on the same veiled route as every other meta
## screen, so a hot spring, a berry tree and nightfall all looked identical --
## and the one character actually standing there was never on screen. The scene
## is named by the event's own `scene` field, so it stays a data edit (D-14).
## The campfire, the reward and the treasure screens name their own scene the
## same way, because "you just won a fight" is as much a place as a berry tree.

## The column the text is allowed to use. Everything outside it is art, so the
## plate has to agree with what run_screen centres its labels to.
var _plate: Control = null
var _body: Control = null
var _weather: WeatherFx = null

const PLATE_W := 620.0
const PLATE_TOP := 88.0
## The plate tracks the body it sits behind, rather than guessing a height.
##
## Counting choices is not enough: prose wraps to a different number of lines
## per event and a long choice label wraps its own button, so a four-choice
## event overhung a plate sized by row count. The body knows its real height
## once laid out, so ask it.
const PLATE_PAD := 14.0
## The floor stops the plate collapsing to a sliver on a two-line outcome. Kept
## low enough that a treasure -- a title, a line of flavour and a tally -- does
## not get eighty pixels of empty veil parked over its own strongbox.
const PLATE_MIN_BOTTOM := 268.0
const PLATE_MAX_BOTTOM := 486.0

## What is in the air at each place, and what is moving in the sky behind it.
##
## Table rather than a match, because this is the knob that gets turned: adding
## a scene should be one row here and one drawing helper in PlaceholderArt, not
## a new branch threaded through setup(). A scene missing from the table simply
## gets still air, which is the right failure.
##
## `weather` reuses WeatherFx -- the rain and the sun the combat screen already
## draws. A second rain implementation is a second rain to keep looking right.
const MOOD := {
	&"spring":   {"motes": &"steam",   "clouds": true},
	&"shade":    {"motes": &"leaves",  "clouds": true},
	&"berry":    {"motes": &"leaves",  "clouds": true},
	&"path":     {"motes": &"dust",    "clouds": true},
	&"stall":    {"motes": &"dust",    "clouds": true},
	&"rock":     {"motes": &"dust",    "clouds": true},
	&"field":    {"motes": &"dust",    "clouds": true},
	# Fifty years of rain sorting a spoil heap is in the event's own prose.
	&"workings": {"motes": &"ash",     "clouds": true,  "weather": &"rain"},
	&"night":    {"motes": &"firefly", "clouds": false},
	&"campfire": {"motes": &"ember",   "clouds": false},
	# Sun breaking over the field you just cleared, and the ash still settling.
	&"victory":  {"motes": &"ash",     "clouds": true,  "weather": &"sun"},
	&"cache":    {"motes": &"glint",   "clouds": true},
}

## One row per kind of thing that hangs in the air. Frame coordinates, because
## these are drawn over the scaled art rather than into it.
##
## Deliberately sparse and slow. The plate is 84% opaque and every one of these
## is behind it, but the strips of art either side are where the player's eye
## rests between reading and clicking -- busy air there drags it off the words.
const MOTES := {
	&"ember":   {"count": 24, "at": Rect2(596, 424, 200, 44), "vel": Vector2(8, -44),
		"jitter": Vector2(16, 20), "size": Vector2(3, 3), "life": 2.6, "sway": 11.0,
		"twinkle": 0.45, "alpha": 0.95, "a": Palette.FLAME, "b": Palette.SPARK},
	&"firefly": {"count": 24, "at": Rect2(0, 300, 960, 230), "vel": Vector2(7, -5),
		"jitter": Vector2(18, 12), "size": Vector2(3, 3), "life": 5.0, "sway": 24.0,
		"twinkle": 0.8, "alpha": 0.9, "a": Palette.SPARK, "b": Palette.MOSS},
	&"steam":   {"count": 14, "at": Rect2(520, 430, 280, 24), "vel": Vector2(4, -24),
		"jitter": Vector2(9, 9), "size": Vector2(2, 7), "life": 3.2, "sway": 9.0,
		"twinkle": 0.0, "alpha": 0.24, "a": Palette.INK_LIGHT, "b": Palette.INK_MID},
	&"leaves":  {"count": 12, "at": Rect2(0, 110, 960, 90), "vel": Vector2(-15, 27),
		"jitter": Vector2(11, 10), "size": Vector2(4, 3), "life": 6.5, "sway": 28.0,
		"twinkle": 0.0, "alpha": 0.8, "a": Palette.MOSS_DARK, "b": Palette.FLAME},
	&"dust":    {"count": 20, "at": Rect2(0, 250, 960, 290), "vel": Vector2(19, -4),
		"jitter": Vector2(11, 7), "size": Vector2(2, 2), "life": 6.0, "sway": 11.0,
		"twinkle": 0.0, "alpha": 0.3, "a": Palette.BONE, "b": Palette.SAND},
	&"ash":     {"count": 20, "at": Rect2(0, 70, 960, 140), "vel": Vector2(-11, 21),
		"jitter": Vector2(11, 9), "size": Vector2(2, 2), "life": 7.0, "sway": 15.0,
		"twinkle": 0.0, "alpha": 0.36, "a": Palette.INK_MID, "b": Palette.INK_MUTED},
	&"glint":   {"count": 16, "at": Rect2(500, 400, 340, 110), "vel": Vector2(0, -3),
		"jitter": Vector2(5, 5), "size": Vector2(2, 2), "life": 1.5, "sway": 0.0,
		"twinkle": 1.0, "alpha": 1.0, "a": Palette.SPARK, "b": Palette.WHITE},
}

## `body` is the run screen's content column. Held so the plate can follow it.
##
## The persistent action bar -- Continue, Skip, Leave -- deliberately does NOT
## reach the plate. Stretching down to cover it was tried and is worse: the bar
## sits at the bottom of the frame whatever is above it, so every short screen
## got a plate to the floor and the scene art it was supposed to be framing
## disappeared behind an empty box. Those buttons carry their own background
## and read perfectly well standing on the landscape; they are only centred so
## they line up under the column.
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

	var mood: Dictionary = MOOD.get(scene, {})

	# Depth, from the one moving thing a still landscape can afford: the sky.
	# The layer PlaceholderArt already draws for the battle screen wraps at its
	# own width, so two copies sliding together never show a seam.
	if mood.get("clouds", false):
		add_child(_Parallax.new())

	# Rain and sun come from WeatherFx rather than from a second implementation
	# here. It lifts itself to z_index 120 so it can sit over a battle; inside an
	# event that puts rain over the words, so _ready() flattens it back down.
	if mood.has("weather"):
		var w := WeatherFx.new()
		w.set_anchors_preset(Control.PRESET_FULL_RECT)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(w)
		w.set_weather(mood["weather"])
		_weather = w

	# Vignette before the character and the plate, so it shades the landscape
	# and leaves Charmander and the prose at full contrast.
	add_child(_Vignette.new())

	if MOTES.has(mood.get("motes", &"")):
		var m := _Motes.new()
		add_child(m)
		# The banked-coal glow breathes only where there are coals to breathe.
		m.start(MOTES[mood["motes"]], scene == &"campfire")

	# Charmander, stood in the scene rather than on a menu. He goes to the left
	# of the text column, in the strip of art the plate leaves free.
	var mon := StarterView.new()
	mon.position = Vector2(4, 320)
	mon.size = Vector2(150, 150)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mon)
	# FRONT, not for_player(): that is the battle back sprite, right over his
	# shoulder in a fight and wrong on a screen he is standing in facing you.
	mon.setup(PlaceholderArt.for_player_front(), 1.6)

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

## setup() runs before this scene is in the tree, so WeatherFx has not had its
## _ready() yet and anything set on it there is overwritten a frame later.
## Godot readies children before parents, so by the time this runs the 120 is
## on and can be taken back off.
func _ready() -> void:
	if _weather != null and is_instance_valid(_weather):
		_weather.z_index = 0

class _Plate extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.GROUND, 0.84))
		draw_rect(Rect2(Vector2.ZERO, size), Palette.BORDER, false, 2.0)

## The body is rebuilt and re-laid-out over several frames as an event resolves,
## so this follows it every frame rather than measuring once and going stale.
func _process(_delta: float) -> void:
	# Reduce motion means reduce motion, not "reduce most of it". Weather is the
	# one effect not written here, so it is faded rather than switched (D-23).
	if _weather != null and is_instance_valid(_weather):
		_weather.modulate.a = clampf(Juice.intensity, 0.0, 1.0)
	if _plate == null or _body == null or not is_instance_valid(_body):
		return
	var bottom := _body.global_position.y + _body.size.y + PLATE_PAD
	bottom = clampf(bottom, PLATE_MIN_BOTTOM, PLATE_MAX_BOTTOM)
	_plate.size.y = bottom - PLATE_TOP

## A soft dark frame. Nothing in the palette is a gradient, so this is banded --
## thirty-two 4px steps, which at this alpha reads as falloff rather than as
## rings. Corners are covered twice over, which is where a vignette wants to be
## darkest anyway.
class _Vignette extends Control:
	const BANDS := 32
	const STEP := 4.0
	const DEEPEST := 0.34

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in BANDS:
			var t := 1.0 - float(i) / float(BANDS)
			var col := Color(Palette.GROUND, DEEPEST * t * t)
			var o := float(i) * STEP
			draw_rect(Rect2(0, o, size.x, STEP), col)
			draw_rect(Rect2(0, size.y - o - STEP, size.x, STEP), col)
			draw_rect(Rect2(o, 0, STEP, size.y), col)
			draw_rect(Rect2(size.x - o - STEP, 0, STEP, size.y), col)

## Two copies of the wrapping cloud layer, sliding. Slow enough that it reads as
## weather rather than as a scrolling background: the player is standing still.
class _Parallax extends Control:
	const SPEED := 7.0
	var _a: TextureRect
	var _b: TextureRect
	var _x := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_a = _sheet()
		_b = _sheet()
		add_child(_a)
		add_child(_b)
		set_process(true)

	func _sheet() -> TextureRect:
		var t := TextureRect.new()
		t.texture = PlaceholderArt.for_cloud_layer(&"route")
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2(960, 540)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t

	func _process(delta: float) -> void:
		_x = fmod(_x + SPEED * delta * Juice.intensity, 960.0)
		# Whole pixels only. A cloud on a half pixel is the one thing a pixel-art
		# game cannot get away with (art bible rule 4).
		_a.position.x = -round(_x)
		_b.position.x = 960.0 - round(_x)

## Whatever hangs in the air here: embers, fireflies, steam, blown leaves, dust,
## ash, the glint off a coin heap. One class, driven by a row of MOTES, so a new
## mood is data rather than another particle system.
class _Motes extends Control:
	var _spec: Dictionary = {}
	var _bits: Array[Dictionary] = []
	var _t := 0.0
	var _glow := false
	## Frame position of the coals, for the flicker. The static halo is painted
	## into the scene texture; only the breathing is here, so reduce-motion
	## takes the flicker and leaves the fire lit.
	const GLOW_AT := Vector2(672, 464)

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func start(spec: Dictionary, glow: bool) -> void:
		_spec = spec
		_glow = glow
		for i in int(spec["count"]):
			_bits.append(_spawn(randf() * float(spec["life"])))
		set_process(true)

	func _spawn(age: float) -> Dictionary:
		var at: Rect2 = _spec["at"]
		var jitter: Vector2 = _spec["jitter"]
		return {
			"p": at.position + Vector2(randf() * at.size.x, randf() * at.size.y),
			"v": (_spec["vel"] as Vector2) + Vector2(
				randf_range(-jitter.x, jitter.x), randf_range(-jitter.y, jitter.y)),
			"phase": randf() * TAU,
			"warm": randf() < 0.4,
			"age": age,
		}

	func _process(delta: float) -> void:
		# Intensity scales the motion AND the alpha, so 0.0 is a still, empty
		# frame rather than a frozen swarm of specks (D-23).
		var k := Juice.intensity
		if k <= 0.0:
			if _t != 0.0:
				_t = 0.0
				queue_redraw()
			return
		_t += delta
		var life: float = _spec["life"]
		for i in _bits.size():
			var b := _bits[i]
			b["age"] += delta
			if b["age"] >= life:
				_bits[i] = _spawn(0.0)
				continue
			b["p"] += (b["v"] as Vector2) * delta * k
		queue_redraw()

	func _draw() -> void:
		var k := clampf(Juice.intensity, 0.0, 1.0)
		if k <= 0.0 or _spec.is_empty():
			return
		if _glow:
			# Three rings rather than a texture: at this alpha the banding is
			# below the noise floor of the art underneath it.
			var pulse := 0.55 + 0.45 * sin(_t * 2.3) * (0.6 + 0.4 * sin(_t * 5.7))
			for r in [46.0, 78.0, 112.0]:
				draw_circle(GLOW_AT, r, Color(Palette.FLAME, 0.05 * pulse * k))
		var life: float = _spec["life"]
		var sway: float = _spec["sway"]
		var size_of: Vector2 = _spec["size"]
		var twinkle: float = _spec["twinkle"]
		var base: float = _spec["alpha"]
		for b in _bits:
			var t: float = float(b["age"]) / life
			# In at the start, out at the end. A mote that pops into existence
			# at full brightness reads as a dead pixel.
			var fade: float = minf(t / 0.18, (1.0 - t) / 0.35)
			if twinkle > 0.0:
				fade *= 1.0 - twinkle * (0.5 + 0.5 * sin(_t * 3.4 + float(b["phase"])))
			fade = clampf(fade, 0.0, 1.0) * base * k
			if fade <= 0.01:
				continue
			var p: Vector2 = b["p"]
			p.x += sin(_t * 0.9 + float(b["phase"])) * sway
			draw_rect(Rect2(p.round(), size_of),
				Color(_spec["b"] if b["warm"] else _spec["a"], fade))
