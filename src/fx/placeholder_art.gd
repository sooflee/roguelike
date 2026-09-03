class_name PlaceholderArt
extends RefCounted
## Generates placeholder sprites procedurally at runtime.
##
## These are NOT shipped art. Per docs/DECISIONS.md D-05/D-06 every shipped pixel
## is hand-drawn; these exist so the animation layer has real sprites of the
## right dimensions to animate against. When a hand-drawn PNG lands in
## assets/sprites/, `for_enemy()` returns it instead and nothing else changes.
##
## They still obey the art bible: locked canvas sizes, palette-only colours,
## 1px non-black outline, light source top-left.

const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}

## Body palettes, each a [dark, mid, light] ramp. Hue-shifted rather than merely
## darkened -- art bible rule 6.
const RAMPS := [
	[Palette.RUST,        Palette.LEATHER,   Palette.CLAY],
	[Palette.TEAL_DARK,   Palette.MOSS_DARK, Palette.MOSS],
	[Palette.QUENCH_DEEP, Palette.QUENCH,    Palette.QUENCH_BRIGHT],
	[Palette.VIOLET_DARK, Palette.VIOLET,    Palette.ROSE],
	[Palette.SHADOW,      Palette.INK_MUTED, Palette.INK_MID],
	[Palette.EMBER_DEEP,  Palette.EMBER_MID, Palette.SAND],
	[Palette.BLOOD,       Palette.RED,       Palette.ROSE],
]

static func size_for(kind: String) -> int:
	match kind:
		"boss":  return 128
		"elite": return 96
		_:       return 64

## Returns a hand-drawn sprite if one exists, else a generated placeholder.
static func for_enemy(id: StringName, kind: String = "normal") -> Texture2D:
	var key := "%s:%s" % [id, kind]
	if _cache.has(key):
		return _cache[key]
	var path := "%senemies/%s.png" % [SPRITE_DIR, id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _generate(String(id), size_for(kind))
	_cache[key] = tex
	return tex

static func for_player() -> Texture2D:
	if _cache.has("player"):
		return _cache["player"]
	var path := SPRITE_DIR + "player/emberwright.png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else _generate("emberwright", 64, 5)
	_cache["player"] = tex
	return tex

## The player with his tail flame put out, for the defeat screen.
##
## The flame is painted into the sprite strip, but it is painted in three
## colours that appear NOWHERE else on the body -- verified across all 16
## frames, whose bounding boxes all sit in the upper-left flame area. Erasing
## exactly those leaves the tail stump clean, with no orphaned outline, and it
## survives the flame changing shape between frames in a way any bounding-box
## rule would not.
const FLAME_COLOURS := [
	Color8(0xe6, 0x3a, 0x00),   # outer flame
	Color8(0xff, 0xd6, 0x08),   # bright core
	Color8(0xf7, 0xa4, 0x00),   # amber mid
]

static func for_player_snuffed() -> Texture2D:
	if _cache.has("player_snuffed"):
		return _cache["player_snuffed"]
	var src: Texture2D = for_player()
	var img := src.get_image()
	if img == null:
		_cache["player_snuffed"] = src
		return src
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var clear := Color(0, 0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a < 0.5:
				continue
			for f in FLAME_COLOURS:
				if is_equal_approx(px.r, f.r) and is_equal_approx(px.g, f.g) \
						and is_equal_approx(px.b, f.b):
					img.set_pixel(x, y, clear)
					break
	var tex := ImageTexture.create_from_image(img)
	_cache["player_snuffed"] = tex
	return tex

## The ink a locked roster slot is drawn in. Mid-value on purpose: near-black
## disappears into the panel behind it, and anything brighter stops reading as
## a shape withheld and starts reading as a design.
const LOCKED_INK := Palette.INK_MUTED

## A featureless silhouette of a partner that exists but cannot be picked yet.
##
## A locked slot wants a shape, not a portrait. Flattening every opaque pixel to
## one colour drops the ramp, the eyes and the outline together, so the slot
## says "something goes here" without spending the reveal early. `id` only seeds
## the generator -- the same id always gives back the same silhouette, so the
## roster does not reshuffle itself between launches.
static func for_locked_starter(id: StringName) -> Texture2D:
	var key := "locked:%s" % id
	if _cache.has(key):
		return _cache[key]
	var img := _generate(String(id), 64).get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, LOCKED_INK)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Builds a creature silhouette on a low-res logical grid, mirrors it for
## bilateral symmetry (which is what makes a blob read as a creature), upscales,
## then shades and outlines at full resolution.
static func _generate(seed_text: String, size: int, forced_ramp: int = -1) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)

	const GRID := 16
	var cell := size / GRID
	var half := GRID / 2

	# 1. silhouette on the logical grid
	var mask := []
	for y in GRID:
		mask.append([])
		for x in GRID:
			mask[y].append(false)

	var body_top := rng.randi_range(2, 4)
	var body_bottom := GRID - rng.randi_range(1, 3)
	for y in range(body_top, body_bottom):
		# Width tapers toward the top and bottom: a body, not a rectangle.
		var t := float(y - body_top) / maxf(1.0, float(body_bottom - body_top))
		var w := int(round(lerpf(2.0, float(half - 1), sin(t * PI) * 0.9 + 0.25)))
		w = clampi(w + rng.randi_range(-1, 1), 1, half)
		for x in range(half - w, half):
			mask[y][x] = true

	# Limbs / horns: a few random studs, still mirrored.
	for _i in rng.randi_range(2, 5):
		var sy := rng.randi_range(body_top, body_bottom - 1)
		var sx := rng.randi_range(1, half - 1)
		for dy in rng.randi_range(1, 3):
			if sy + dy < GRID:
				mask[sy + dy][sx] = true

	for y in GRID:
		for x in range(half):
			if mask[y][x]:
				mask[y][GRID - 1 - x] = true

	# 2. paint
	var ramp: Array = RAMPS[forced_ramp if forced_ramp >= 0 else rng.randi_range(0, RAMPS.size() - 1)]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in size:
		for x in size:
			var gx := x / cell
			var gy := y / cell
			if gx >= GRID or gy >= GRID or not mask[gy][gx]:
				continue
			# Light source top-left, always (art bible rule 1).
			var lit := (float(x) / size) * 0.5 + (float(y) / size) * 0.5
			var c: Color = ramp[2] if lit < 0.35 else (ramp[1] if lit < 0.72 else ramp[0])
			img.set_pixel(x, y, c)

	# 3. 1px outline in a dark palette colour, never pure black (rule 2)
	var outlined := img.duplicate()
	for y in size:
		for x in size:
			if img.get_pixel(x, y).a > 0.0:
				continue
			var touching := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < size and ny < size and img.get_pixel(nx, ny).a > 0.0:
					touching = true
					break
			if touching:
				outlined.set_pixel(x, y, Palette.OUTLINE)

	# 4. eyes -- the cheapest way to make a blob read as something alive
	var eye_y := int(size * 0.34)
	var eye_dx := maxi(cell, int(size * 0.13))
	for side in [-1, 1]:
		var ex: int = size / 2 + side * eye_dx
		for oy in range(0, maxi(2, cell / 2)):
			for ox in range(0, maxi(2, cell / 2)):
				var px: int = ex + ox
				var py: int = eye_y + oy
				if px >= 0 and py >= 0 and px < size and py < size and outlined.get_pixel(px, py).a > 0.0:
					outlined.set_pixel(px, py, Palette.SPARK if forced_ramp >= 0 else Palette.EMBER)

	return ImageTexture.create_from_image(outlined)

## Abstract card art keyed to the card's type. Placeholder for the 80x56 window.
static func for_card(card: CardData) -> Texture2D:
	var key := "card:%s" % card.id
	if _cache.has(key):
		return _cache[key]
	var path := "%scards/%s.png" % [SPRITE_DIR, card.id]
	if ResourceLoader.exists(path):
		_cache[key] = load(path)
		return _cache[key]

	var w := 80
	var h := 56
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var base := Palette.for_card_type(card.type)
	img.fill(base.darkened(0.45))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(card.id))
	# A few overlapping bands -- suggests an illustration without pretending to be one.
	for _i in rng.randi_range(3, 6):
		var bx := rng.randi_range(0, w - 8)
		var by := rng.randi_range(0, h - 6)
		var bw := rng.randi_range(6, 26)
		var bh := rng.randi_range(4, 14)
		var c := base if rng.randf() < 0.6 else base.lightened(0.25)
		for y in range(by, mini(h, by + bh)):
			for x in range(bx, mini(w, bx + bw)):
				img.set_pixel(x, y, c)
	if card.overload_bonus:
		for x in w:
			img.set_pixel(x, h - 1, Palette.EMBER)
			img.set_pixel(x, h - 2, Palette.EMBER_DEEP)

	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

## Act backgrounds, built at a quarter of the 960x540 frame and scaled x4 by the
## view. Drawing at 240x135 is what makes the pixels chunky and on-grid instead
## of a smooth gradient wearing a pixel-art costume.
##
## As with every other placeholder (D-22): drop a hand-drawn PNG at
## assets/sprites/backgrounds/<id>.png and it is used instead, no code change.
##
## Implements docs/art/world-art-direction.md section 2. Frame coordinates in
## that document are divided by four to land here.
const BG_W := 240
const BG_H := 135

## Region ceilings from the art direction, in BACKGROUND pixels. The UI has no
## backing plates, so the scene itself has to stay dark where the UI lives:
## white BBCode in the HUD strip, and dark blue card frames in the card band.
const HUD_BAND_Y := 12         ## frame y 0-48
const CARD_BAND_Y := 93        ## frame y 372, top of the card fan

static func for_background(id: StringName) -> Texture2D:
	var key := "bg:%s" % id
	if _cache.has(key):
		return _cache[key]
	var path := "%sbackgrounds/%s.png" % [SPRITE_DIR, id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		# The meta screens want the same country without the battle platforms --
		# those exist to say "a fight happens here" and would be a lie on a map.
		tex = _generate_route(String(id), id != &"route")
	_cache[key] = tex
	return tex

## A place an event happens in, drawn to the same 240x135 plate as the battle
## backgrounds and scaled x4 on screen.
##
## Events were a wall of left-aligned text on the same veiled route as every
## other meta screen, so "a hot spring", "a berry tree" and "nightfall" all
## looked identical. The scene is named by the event's own `scene` field, so
## adding one is a data edit (D-14) -- and an event with no `scene` still gets
## the plain field rather than an error.
static func for_event_scene(scene: StringName) -> Texture2D:
	var key := "event:%s" % scene
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("event:" + String(scene))
	var img := Image.create_empty(BG_W, BG_H, false, Image.FORMAT_RGBA8)
	var night := scene == &"night"

	if night:
		_fill_band(img, 0, 22, Palette.GROUND)
		_dither_band(img, 22, 30, Palette.GROUND, Palette.QUENCH_DEEP)
		_fill_band(img, 30, 56, Palette.QUENCH_DEEP)
		_stars(img, rng, 46)
	else:
		_fill_band(img, 0, 16, Palette.QUENCH_DEEP)
		_dither_band(img, 16, 20, Palette.QUENCH_DEEP, Palette.QUENCH)
		_fill_band(img, 20, 56, Palette.QUENCH)

	_treeline(img, rng, 56, Palette.TEAL_DARK if not night else Palette.GROUND)
	_fill_band(img, 60, BG_H, Palette.MOSS_DARK if not night else Palette.TEAL_DARK)
	_clumps(img, rng, 64, BG_H - 6, Palette.MOSS if not night else Palette.MOSS_DARK)

	# Every focal feature lives low or to the right, because the text plate covers
	# the middle of the frame and Charmander stands bottom-left. Art the plate
	# sits on top of is art nobody sees -- the first pass put the hot spring
	# squarely behind the words.
	match scene:
		&"spring":  _pool(img, rng, 146, 118, 50, 11)
		&"shade":   _big_tree(img, 208, 116, false)
		&"berry":   _big_tree(img, 208, 116, true)
		&"path":    _rocks(img, rng)
		&"stall":   _awning(img, 196, 82)
		&"rock":    _flat_rock(img, 196, 118)
		&"workings": _workings(img, rng)
		&"field":   _posts(img)
		_:          pass

	# Only a hint of a darker foreground. The battle plate grades the bottom 16
	# rows hard because the card fan sits there; an event has nothing down there
	# but ground, and a black bar reads as dead space.
	_grade_ground(img, BG_H - 6, BG_H, Palette.TEAL_DARK)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _stars(img: Image, rng: RandomNumberGenerator, count: int) -> void:
	for i in count:
		var x := rng.randi_range(0, BG_W - 1)
		var y := rng.randi_range(0, 48)
		img.set_pixel(x, y, Palette.BONE if rng.randf() < 0.3 else Palette.INK_MID)

## Water, with a lit rim and a couple of steam wisps above it.
static func _pool(img: Image, rng: RandomNumberGenerator, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or x >= BG_W or y < 0 or y >= BG_H:
				continue
			var dx := float(x - cx) / float(rx)
			var dy := float(y - cy) / float(ry)
			if dx * dx + dy * dy > 1.0:
				continue
			# Deep water with a lit rim, not a flat cyan puddle: QUENCH at full
			# saturation across the whole ellipse reads as a cartoon pond.
			var d := dx * dx + dy * dy
			var col := Palette.QUENCH_DEEP
			if d > 0.86:
				col = Palette.TEAL_DARK
			elif d < 0.30:
				col = Palette.QUENCH
			img.set_pixel(x, y, col)
	# Steam, as short wisps rising off the surface. Scattered single pixels just
	# looked like dirt on the lens.
	for i in 7:
		var x := cx + rng.randi_range(-rx + 6, rx - 6)
		var top := cy - ry - rng.randi_range(4, 18)
		for y in range(top, cy - ry):
			if x >= 0 and x < BG_W and y >= 0 and (y + x) % 3 != 0:
				img.set_pixel(x, y, Palette.INK_MID)

## A canopy on a trunk. `fruit` hangs berries in it.
static func _big_tree(img: Image, cx: int, base_y: int, fruit: bool) -> void:
	for y in range(base_y - 46, base_y + 1):
		for x in range(cx - 3, cx + 4):
			if x >= 0 and x < BG_W and y >= 0 and y < BG_H:
				img.set_pixel(x, y, Palette.RUST)
	var top := base_y - 42
	for y in range(top - 20, top + 16):
		for x in range(cx - 30, cx + 31):
			if x < 0 or x >= BG_W or y < 0 or y >= BG_H:
				continue
			var dx := float(x - cx) / 30.0
			var dy := float(y - top) / 22.0
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			img.set_pixel(x, y, Palette.MOSS_DARK if d > 0.72 else Palette.MOSS)
	if fruit:
		for spot in [Vector2i(-18, 4), Vector2i(-4, 12), Vector2i(12, 2), Vector2i(20, 10), Vector2i(2, -8)]:
			for oy in 2:
				for ox in 2:
					var px: int = cx + int(spot.x) + ox
					var py: int = top + int(spot.y) + oy
					if px >= 0 and px < BG_W and py >= 0 and py < BG_H:
						img.set_pixel(px, py, Palette.FLAME)

## Boulders either side, leaving a trail down the middle.
## Boulders. `at` defaults to the pair-either-side arrangement; a scene that
## needs the left side clear passes its own, because the default drops one at
## (20,120) which is squarely behind Charmander.
static func _rocks(img: Image, rng: RandomNumberGenerator, at: Array = []) -> void:
	var spots: Array = at if not at.is_empty() else \
		[Vector2i(20, 120), Vector2i(214, 118), Vector2i(196, 100), Vector2i(228, 96)]
	for spec in spots:
		var r := rng.randi_range(11, 18)
		for y in range(spec.y - r, spec.y + r):
			for x in range(spec.x - r, spec.x + r):
				if x < 0 or x >= BG_W or y < 0 or y >= BG_H:
					continue
				var dx := float(x - spec.x) / float(r)
				var dy := float(y - spec.y) / float(r) * 1.5
				var d := dx * dx + dy * dy
				if d > 1.0:
					continue
				img.set_pixel(x, y, Palette.SHADOW if d > 0.6 else Palette.RUST)

## A market stall: legs, a table and a striped awning.
static func _awning(img: Image, cx: int, top: int) -> void:
	for x in range(cx - 34, cx + 35):
		for y in range(top, top + 7):
			if x >= 0 and x < BG_W and y >= 0 and y < BG_H:
				img.set_pixel(x, y, Palette.RED if ((x / 7) % 2 == 0) else Palette.BONE)
	for lx in [cx - 32, cx + 31]:
		for y in range(top + 7, top + 34):
			if lx >= 0 and lx < BG_W and y < BG_H:
				img.set_pixel(lx, y, Palette.RUST)
	for x in range(cx - 30, cx + 31):
		for y in range(top + 26, top + 30):
			if x >= 0 and x < BG_W and y < BG_H:
				img.set_pixel(x, y, Palette.LEATHER)

## A slab to lay things out on.
static func _flat_rock(img: Image, cx: int, cy: int) -> void:
	for y in range(cy - 6, cy + 7):
		var half := 30 - absi(y - cy) * 2
		for x in range(cx - half, cx + half):
			if x >= 0 and x < BG_W and y >= 0 and y < BG_H:
				img.set_pixel(x, y, Palette.SHADOW if y > cy + 1 else Palette.INK_MUTED)

## A cut in the hillside: a spoil heap to the right and a flat stone holding
## what somebody left on it. Nothing on the left -- Charmander stands there.
static func _workings(img: Image, rng: RandomNumberGenerator) -> void:
	_rocks(img, rng, [Vector2i(222, 112), Vector2i(200, 96), Vector2i(236, 88)])
	_flat_rock(img, 150, 122)

## Worn training posts standing in the grass.
static func _posts(img: Image) -> void:
	for spec in [Vector2i(210, 122), Vector2i(182, 114), Vector2i(232, 110)]:
		for y in range(spec.y - 26, spec.y):
			for x in range(spec.x - 3, spec.x + 4):
				if x >= 0 and x < BG_W and y >= 0 and y < BG_H:
					img.set_pixel(x, y, Palette.RUST if x < spec.x + 1 else Palette.SHADOW)
		for x in range(spec.x - 6, spec.x + 7):
			for y in range(spec.y - 30, spec.y - 26):
				if x >= 0 and x < BG_W and y >= 0 and y < BG_H:
					img.set_pixel(x, y, Palette.LEATHER)

## The drifting cloud layer, kept out of the static plate so it can scroll.
## Wraps seamlessly at x = BG_W, so the view can tile two copies and slide them.
static func for_cloud_layer(id: StringName) -> Texture2D:
	var key := "clouds:%s" % id
	if _cache.has(key):
		return _cache[key]
	var path := "%sbackgrounds/%s_clouds.png" % [SPRITE_DIR, id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("clouds:" + String(id))
		var img := Image.create_empty(BG_W, BG_H, false, Image.FORMAT_RGBA8)
		_draw_clouds(img, rng)
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A Pokemon route, drawn as a battle background.
##
## The identifying shape of a Pokemon battle is not the scenery -- it is the two
## elliptical PLATFORMS, one under each side, that lift the combatants off the
## horizon and tell you where the fight is happening. Rolling hills read as a
## landscape; platforms read as a battle. The player's is nearer, lower and
## larger; the opposing one sits further back and smaller, which is what sells
## the depth without a camera.
##
## Sizes here are in the 240x135 drawing space and multiply by four on screen.
static func _generate_route(seed_text: String, platforms: bool = true) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var img := Image.create_empty(BG_W, BG_H, false, Image.FORMAT_RGBA8)

	# Sky: darkest at the zenith so the HUD strip keeps a dark ground to sit on.
	# Kept SHORT on purpose. Widening this to ten rows was tried and is worse: a
	# 2x2 Bayer dither between two flat colours does not become a gradient when
	# you give it more room, it becomes a bigger checkerboard. With no
	# intermediate blue in the locked palette (D-08) the smooth version of this
	# sky is a hand-drawn one, not a longer dither.
	_fill_band(img, 0, 16, Palette.QUENCH_DEEP)
	_dither_band(img, 16, 18, Palette.QUENCH_DEEP, Palette.QUENCH)
	_fill_band(img, 18, 52, Palette.QUENCH)

	# A distant treeline, flat and low-contrast: aerial perspective pulls far
	# forms toward the sky, and a hard outline would make it a sticker.
	_treeline(img, rng, 52, Palette.TEAL_DARK)

	# The field the fight stands on.
	_fill_band(img, 56, BG_H, Palette.MOSS_DARK)
	_clumps(img, rng, 60, CARD_BAND_Y - 4, Palette.MOSS)

	# The two platforms. Enemy first: it is further away, so anything the player
	# platform overlaps should be drawn over.
	#
	# Aligned to where the combatants ACTUALLY stand, which is not what the view's
	# constants say on their own. Enemies sit at ENEMY_Y + 90 = frame y 295, not
	# at ENEMY_Y; reading the constant alone put this platform 79px above the
	# things standing on it, hanging in the air behind them. Player feet are at
	# PLAYER_POS.y = 246. Divide by four for this space.
	#
	# The enemy platform is wide enough for three abreast: they spread 200px
	# apart around x=620, so a third one lands at x=420 and x=820.
	if platforms:
		_platform(img, 155, 74, 57, 8)
		_platform(img, 45, 62, 40, 8)

	# Grade into the card band, recolouring ground pixels in place rather than
	# painting bands over them -- flat rows would erase the platforms.
	_grade_ground(img, CARD_BAND_Y - 8, CARD_BAND_Y, Palette.TEAL_DARK)
	_grade_ground(img, CARD_BAND_Y, 118, Palette.TEAL_DARK, true)
	# TEAL_DARK, not SHADOW: SHADOW is a warm brown and reads as scorched earth
	# under a green field.
	_grade_ground(img, 118, BG_H, Palette.TEAL_DARK, true)
	return ImageTexture.create_from_image(img)

## One battle platform: a filled ellipse, a lit top edge, and a shadow beneath.
## The shadow is what stops it reading as a flat green sticker on green grass.
static func _platform(img: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry - 2, cy + ry + 4):
		for x in range(cx - rx - 2, cx + rx + 2):
			if x < 0 or x >= BG_W or y < 0 or y >= BG_H:
				continue
			var dx := float(x - cx) / float(rx)
			var dy := float(y - cy) / float(ry)
			var d := dx * dx + dy * dy
			if d > 1.0:
				# A one-pixel rim under the lower edge only. A full offset
				# ellipse read as a dark smear arcing out across the grass.
				if y > cy and d <= 1.35:
					img.set_pixel(x, y, Palette.TEAL_DARK)
				continue
			# Lit along the top, darker along the bottom: a disc, not a circle.
			if dy < -0.55:
				img.set_pixel(x, y, Palette.MOSS)
			elif dy > 0.5:
				img.set_pixel(x, y, Palette.TEAL_DARK)
			else:
				img.set_pixel(x, y, Palette.MOSS_DARK)

## Distant trees as a run of overlapping domes -- enough silhouette to read as a
## treeline at 4x without drawing a single tree.
static func _treeline(img: Image, rng: RandomNumberGenerator, base_y: int, col: Color) -> void:
	var x := -4
	while x < BG_W + 4:
		var w := rng.randi_range(5, 11)
		var h := rng.randi_range(3, 7)
		for oy in range(-h, 5):
			for ox in range(-w, w + 1):
				var px := x + ox
				var py := base_y + oy
				if px < 0 or px >= BG_W or py < 0 or py >= BG_H:
					continue
				if float(ox * ox) / float(w * w) + float(oy * oy) / float(h * h) <= 1.0 or oy >= 0:
					img.set_pixel(px, py, col)
		x += rng.randi_range(4, 9)

static func _grade_ground(img: Image, y0: int, y1: int, to_col: Color, solid: bool = false) -> void:
	var span := maxi(1, y1 - y0)
	for y in range(maxi(0, y0), mini(BG_H, y1)):
		var t := float(y - y0) / float(span)
		for x in BG_W:
			if _is_sky(img.get_pixel(x, y)):
				continue
			if solid:
				img.set_pixel(x, y, to_col)
				continue
			var cell: int = (int(x / 2.0) % 2) + (int(y / 2.0) % 2) * 2
			var threshold: float = (BAYER[cell] + 0.5) / 4.0
			if t > threshold:
				img.set_pixel(x, y, to_col)

static func _is_sky(c: Color) -> bool:
	return c.is_equal_approx(Palette.QUENCH_DEEP) or c.is_equal_approx(Palette.QUENCH) \
		or c.is_equal_approx(Palette.SAND)

## Darkens the ground down the left and right edges, where the PP gauge, the
## potion bar, the pile counters and the buttons all sit.
##
## Done as a per-pixel step down the palette ramp rather than as drawn geometry.
## Procedural landforms -- a bank, a treeline -- come out as triangles and read
## as curtains hung over the scene; a hand-drawn background does this with real
## composition, and this is the placeholder standing in for that.
static func _rail_shade(img: Image, cols: int) -> void:
	# One step down the locked ramp. Named constants both sides: a hex string
	# here would be a colour the artist cannot look up (D-08).
	var step := {
		Palette.MOSS: Palette.MOSS_DARK,
		Palette.MOSS_DARK: Palette.TEAL_DARK,
		Palette.TEAL_DARK: Palette.SHADOW,
	}
	for x in BG_W:
		var into: int = mini(x, BG_W - 1 - x)
		if into >= cols:
			continue
		# Fades toward the middle, so there is no edge where the shading starts.
		var strength := 1.0 - float(into) / float(cols)
		for y in BG_H:
			var here := img.get_pixel(x, y)
			if not step.has(here):
				continue
			# Hard steps, not dithered. The background is drawn at 240x135 and
			# scaled x4, so a 2x2 Bayer cell lands as an 8x8 block on screen --
			# at that size a dither stops reading as shading and starts reading
			# as corruption. Banded terrain is honest pixel art; this was noise.
			if strength < 0.30:
				continue
			var to: Color = step[here]
			# Two steps at the outer columns. One step leaves MOSS_DARK in the
			# rail, which measures 0.194 against a 0.12 ceiling.
			if strength > 0.62 and step.has(to):
				to = step[to]
			img.set_pixel(x, y, to)


static func _fill_band(img: Image, y0: int, y1: int, col: Color) -> void:
	for y in range(maxi(0, y0), mini(BG_H, y1)):
		for x in BG_W:
			img.set_pixel(x, y, col)

## Ordered dither between two palette colours, in 2x2-pixel cells. Never 1px:
## a single-pixel checker shimmers and mushes at 1x (art bible rule 4).
const BAYER: Array[float] = [0.0, 2.0, 3.0, 1.0]

static func _dither_band(img: Image, y0: int, y1: int, from_col: Color, to_col: Color) -> void:
	var span := maxi(1, y1 - y0)
	for y in range(maxi(0, y0), mini(BG_H, y1)):
		var t := float(y - y0) / float(span)
		for x in BG_W:
			var cell: int = (int(x / 2.0) % 2) + (int(y / 2.0) % 2) * 2
			var threshold: float = (BAYER[cell] + 0.5) / 4.0
			img.set_pixel(x, y, to_col if t > threshold else from_col)

## One rolling ridge filled to the bottom of the frame, with a single lit pixel
## along its crest. Two sines of different period so the line never visibly
## repeats across 240px.
static func _ridge(img: Image, rng: RandomNumberGenerator, base_y: int, amp: float,
		period: float, col: Color, crest_col: Color) -> void:
	var phase := rng.randf() * TAU
	var phase2 := rng.randf() * TAU
	for x in BG_W:
		var t := float(x) / period
		var crest := base_y + int(round(sin(t + phase) * amp * 0.62 + sin(t * 0.41 + phase2) * amp * 0.38))
		for y in range(maxi(0, crest), BG_H):
			img.set_pixel(x, y, crest_col if y == crest else col)

## Lit tufts scattered on the near field. Light is top-left.
static func _clumps(img: Image, rng: RandomNumberGenerator, y0: int, y1: int, col: Color) -> void:
	# Sparse. At x4 every tuft is a 4-8px speck, and forty of them across the
	# field reads as static rather than as grass.
	for _i in rng.randi_range(10, 16):
		var cx := rng.randi_range(2, BG_W - 4)
		var cy := rng.randi_range(y0, maxi(y0 + 1, y1 - 3))
		# 2x1 or 2x2 tufts. Longer horizontal runs read as scanlines across the
		# field rather than as anything growing on it.
		var w := rng.randi_range(1, 2)
		var tall := rng.randi_range(1, 2)
		for x in range(cx, cx + w + 1):
			for y in range(cy, cy + tall):
				if x < 0 or x >= BG_W or y < 0 or y >= BG_H:
					continue
				img.set_pixel(x, y, col)

## Grass silhouette across the very bottom. Pure SHADOW, so the card fan's
## lowest row still has the darkest thing on screen behind it.
static func _fringe(img: Image, rng: RandomNumberGenerator) -> void:
	for x in BG_W:
		var blade := 128 - rng.randi_range(0, 4)
		for y in range(maxi(0, blade), BG_H):
			img.set_pixel(x, y, Palette.SHADOW)

## Cloud bodies with a lit top, a shaded underside, and a rim on the upper-left
## where the light comes from. Drawn with wraparound so the layer tiles.
static func _draw_clouds(img: Image, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(4, 6)
	for i in count:
		var cx := rng.randi_range(0, BG_W - 1)
		var cy := rng.randi_range(HUD_BAND_Y + 4, 44)
		var w := rng.randi_range(16, 30)
		var rows := 4
		var near: bool = i < 2      # only the nearest two earn a rim light
		for r in rows:
			var rw: int = maxi(4, w - absi(r - 1) * rng.randi_range(4, 7))
			var y := cy + r
			if y < 0 or y >= BG_H:
				continue
			var x0 := cx - int(rw / 2.0)
			for x in range(x0, x0 + rw):
				var wrapped: int = ((x % BG_W) + BG_W) % BG_W
				var col := Palette.INK_LIGHT
				if r == 0:
					col = Palette.WHITE
				elif r == rows - 1:
					col = Palette.INK_MUTED
				img.set_pixel(wrapped, y, col)
				# 1px rim on the upper-left edge, light source top-left.
				if near and x == x0 and r <= 1:
					img.set_pixel(wrapped, y, Palette.QUENCH_BRIGHT)

static func clear_cache() -> void:
	_cache.clear()
