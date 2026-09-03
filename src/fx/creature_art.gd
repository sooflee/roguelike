class_name CreatureArt
extends RefCounted
## Placeholder creature sprites with an actual body plan.
##
## The previous generator mirrored random blocks down a centre line. Mirroring
## alone buys symmetry, not anatomy, so every enemy came out as the same lumpy
## blob in a different colour -- a Slag Hound and a Furnace Moth were
## indistinguishable, which is the one thing a combat sprite must never be.
##
## Each creature is now drawn from a named plan (quadruped, wisp, imp, hulk,
## blob, smith), on a LOW logical grid upscaled 4x with nearest filtering. That
## upscale is what makes it read as pixel art: the pixels are genuinely 4 screen
## pixels across, not a smooth shape pretending.
##
## Still placeholder (D-22): drop a hand-drawn PNG at
## assets/sprites/enemies/<id>.png and it is used instead, no code change.

const SCALE := 4
const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}

## Body plan per creature, so a hound reads as a hound. Anything unlisted falls
## back to `imp`, which is the most generic upright silhouette.
const PLANS := {
	&"cinder_rat": "quadruped", &"slag_hound": "quadruped",
	&"ash_wisp": "wisp", &"furnace_moth": "wisp",
	&"bellows_imp": "imp", &"tongsman": "imp",
	&"cracked_golem": "hulk", &"forge_warden": "hulk", &"slag_titan": "hulk",
	&"molten_glob": "blob", &"slag_shell": "blob", &"damper": "blob",
	&"coal_thief": "imp", &"kiln_hound": "quadruped",
	&"the_bellowsmith": "smith",
}

## dark / mid / light. Hot things use BONE-SAND-CLAY, never orange: EMBER
## belongs to the PP gauge alone (D-08).
const RAMPS := {
	&"cinder_rat": [Palette.RUST, Palette.LEATHER, Palette.CLAY],
	&"slag_hound": [Palette.SHADOW, Palette.RUST, Palette.LEATHER],
	&"ash_wisp": [Palette.VIOLET_DARK, Palette.VIOLET, Palette.ROSE],
	&"furnace_moth": [Palette.VIOLET_DARK, Palette.ROSE, Palette.BONE],
	&"bellows_imp": [Palette.BLOOD, Palette.RED, Palette.ROSE],
	&"tongsman": [Palette.RUST, Palette.CLAY, Palette.SAND],
	&"cracked_golem": [Palette.SHADOW, Palette.INK_MUTED, Palette.INK_MID],
	&"forge_warden": [Palette.QUENCH_DEEP, Palette.INK_MUTED, Palette.INK_LIGHT],
	&"slag_titan": [Palette.SHADOW, Palette.RUST, Palette.CLAY],
	&"molten_glob": [Palette.CLAY, Palette.SAND, Palette.BONE],
	&"coal_thief": [Palette.SHADOW, Palette.INK_MUTED, Palette.SAND],
	&"damper": [Palette.QUENCH_DEEP, Palette.QUENCH, Palette.INK_LIGHT],
	&"kiln_hound": [Palette.BLOOD, Palette.RUST, Palette.CLAY],
	&"slag_shell": [Palette.SHADOW, Palette.RUST, Palette.LEATHER],
	&"the_bellowsmith": [Palette.RUST, Palette.LEATHER, Palette.SAND],
}
const DEFAULT_RAMP := [Palette.SHADOW, Palette.INK_MUTED, Palette.INK_MID]

static func size_for(kind: String) -> int:
	match kind:
		"boss":  return 128
		"elite": return 96
		_:       return 64

static func for_enemy(id: StringName, kind: String = "normal") -> Texture2D:
	var key := "enemy:%s:%s" % [id, kind]
	if _cache.has(key):
		return _cache[key]
	# The art bible keeps elites and bosses in their own directories because
	# their locked sizes differ (D-09): 64, 96, 128. Look in the one that
	# matches this encounter, then fall back to the ordinary roster.
	var tex: Texture2D
	for dir in [_dir_for(kind), "enemies"]:
		var path := "%s%s/%s.png" % [SPRITE_DIR, dir, id]
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	if tex == null:
		var ramp: Array = RAMPS.get(id, DEFAULT_RAMP)
		tex = _draw(String(PLANS.get(id, "imp")), size_for(kind) / SCALE, ramp, String(id))
	_cache[key] = tex
	return tex

static func _dir_for(kind: String) -> String:
	match kind:
		"boss":  return "bosses"
		"elite": return "elites"
		_:       return "enemies"

static func for_player() -> Texture2D:
	if _cache.has("player"):
		return _cache["player"]
	var path := SPRITE_DIR + "player/emberwright.png"
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _draw("smith", 20, [Palette.RUST, Palette.LEATHER, Palette.BONE], "emberwright")
	_cache["player"] = tex
	return tex

# --- drawing ---------------------------------------------------------------

static func _draw(plan: String, g: int, ramp: Array, seed_text: String) -> Texture2D:
	var img := Image.create_empty(g, g, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	match plan:
		"quadruped": _quadruped(img, g, ramp, rng)
		"wisp":      _wisp(img, g, ramp, rng)
		"hulk":      _hulk(img, g, ramp, rng)
		"blob":      _blob(img, g, ramp, rng)
		"smith":     _smith(img, g, ramp, rng)
		_:           _imp(img, g, ramp, rng)
	_shade(img, g, ramp)
	_outline(img, g)
	return _upscale(img, g)

static func _px(img: Image, g: int, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < g and y >= 0 and y < g:
		img.set_pixel(x, y, col)

static func _rect(img: Image, g: int, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, g, xx, yy, col)

static func _ellipse(img: Image, g: int, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in g:
		for x in g:
			var dx := (float(x) - cx) / maxf(0.5, rx)
			var dy := (float(y) - cy) / maxf(0.5, ry)
			if dx * dx + dy * dy <= 1.0:
				_px(img, g, x, y, col)

## Light from the top-left (art bible), applied after the silhouette exists so
## every plan gets the same lighting without each one re-deciding it.
static func _shade(img: Image, g: int, ramp: Array) -> void:
	for y in g:
		for x in g:
			if img.get_pixel(x, y).a == 0.0:
				continue
			var lit: bool = (x > 0 and img.get_pixel(x - 1, y).a == 0.0) \
				or (y > 0 and img.get_pixel(x, y - 1).a == 0.0)
			var shadowed: bool = (x < g - 1 and img.get_pixel(x + 1, y).a == 0.0) \
				or (y < g - 1 and img.get_pixel(x, y + 1).a == 0.0)
			if lit:
				img.set_pixel(x, y, ramp[2])
			elif shadowed:
				img.set_pixel(x, y, ramp[0])

static func _outline(img: Image, g: int) -> void:
	var solid: Array[Vector2i] = []
	for y in g:
		for x in g:
			if img.get_pixel(x, y).a > 0.0:
				solid.append(Vector2i(x, y))
	for p in solid:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.x >= g or q.y < 0 or q.y >= g:
				continue
			if img.get_pixel(q.x, q.y).a == 0.0:
				img.set_pixel(q.x, q.y, Palette.OUTLINE)

static func _upscale(img: Image, g: int) -> Texture2D:
	var out := Image.create_empty(g * SCALE, g * SCALE, false, Image.FORMAT_RGBA8)
	for y in g:
		for x in g:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			for oy in SCALE:
				for ox in SCALE:
					out.set_pixel(x * SCALE + ox, y * SCALE + oy, c)
	return ImageTexture.create_from_image(out)

# --- body plans ------------------------------------------------------------

static func _quadruped(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var body: Color = ramp[1]
	var f := float(g)
	_ellipse(img, g, f * 0.48, f * 0.58, f * 0.30, f * 0.18, body)          # barrel
	_ellipse(img, g, f * 0.76, f * 0.46, f * 0.15, f * 0.13, body)          # head, forward
	_rect(img, g, int(f * 0.86), int(f * 0.36), maxi(1, int(f * 0.07)), maxi(1, int(f * 0.08)), body)  # snout
	for i in 4:                                                             # four legs
		var lx := int(f * (0.26 + float(i) * 0.15))
		_rect(img, g, lx, int(f * 0.72), maxi(1, int(f * 0.07)), int(f * 0.22), body)
	for i in 2:                                                             # ears
		_rect(img, g, int(f * (0.70 + float(i) * 0.09)), int(f * 0.28), maxi(1, int(f * 0.05)), int(f * 0.09), body)
	_rect(img, g, int(f * 0.10), int(f * 0.44), int(f * 0.14), maxi(1, int(f * 0.06)), body)   # tail

static func _wisp(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var f := float(g)
	_ellipse(img, g, f * 0.5, f * 0.44, f * 0.20, f * 0.22, ramp[1])        # core
	for side in [-1.0, 1.0]:                                                # wings
		_ellipse(img, g, f * (0.5 + side * 0.26), f * 0.38, f * 0.16, f * 0.24, ramp[1])
	for i in 3:                                                             # trailing motes
		_ellipse(img, g, f * 0.5, f * (0.70 + float(i) * 0.09),
			f * (0.09 - float(i) * 0.02), f * (0.07 - float(i) * 0.015), ramp[1])

static func _imp(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var f := float(g)
	_ellipse(img, g, f * 0.5, f * 0.30, f * 0.17, f * 0.17, ramp[1])        # head
	_rect(img, g, int(f * 0.36), int(f * 0.44), int(f * 0.28), int(f * 0.30), ramp[1])  # torso
	for side in [0.22, 0.68]:                                               # arms
		_rect(img, g, int(f * side), int(f * 0.46), maxi(1, int(f * 0.10)), int(f * 0.24), ramp[1])
	for side in [0.38, 0.54]:                                               # legs
		_rect(img, g, int(f * side), int(f * 0.74), maxi(1, int(f * 0.08)), int(f * 0.22), ramp[1])
	for side in [-1.0, 1.0]:                                                # horns
		_rect(img, g, int(f * (0.5 + side * 0.16)), int(f * 0.14), maxi(1, int(f * 0.05)), int(f * 0.09), ramp[1])

static func _hulk(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var f := float(g)
	_rect(img, g, int(f * 0.22), int(f * 0.30), int(f * 0.56), int(f * 0.38), ramp[1])   # slab torso
	_rect(img, g, int(f * 0.16), int(f * 0.26), int(f * 0.68), int(f * 0.12), ramp[1])   # shoulders
	_ellipse(img, g, f * 0.5, f * 0.20, f * 0.13, f * 0.11, ramp[1])                     # sunken head
	for side in [0.10, 0.76]:                                                            # heavy arms
		_rect(img, g, int(f * side), int(f * 0.34), int(f * 0.14), int(f * 0.34), ramp[1])
	for side in [0.30, 0.56]:                                                            # short legs
		_rect(img, g, int(f * side), int(f * 0.68), int(f * 0.14), int(f * 0.26), ramp[1])
	for i in 3:                                                                          # cracks
		_rect(img, g, int(f * (0.34 + float(i) * 0.12)), int(f * 0.40), 1, int(f * 0.18), ramp[0])

static func _blob(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var f := float(g)
	_ellipse(img, g, f * 0.5, f * 0.60, f * 0.34, f * 0.30, ramp[1])
	_ellipse(img, g, f * 0.42, f * 0.40, f * 0.20, f * 0.18, ramp[1])       # rising bulge
	for i in 4:                                                             # drips
		_rect(img, g, int(f * (0.24 + float(i) * 0.17)), int(f * 0.84), maxi(1, int(f * 0.06)), int(f * 0.12), ramp[1])

static func _smith(img: Image, g: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var f := float(g)
	_ellipse(img, g, f * 0.46, f * 0.20, f * 0.13, f * 0.12, ramp[1])                    # head
	_rect(img, g, int(f * 0.30), int(f * 0.30), int(f * 0.34), int(f * 0.14), ramp[1])   # shoulders
	_rect(img, g, int(f * 0.32), int(f * 0.42), int(f * 0.30), int(f * 0.30), ramp[1])   # apron
	_rect(img, g, int(f * 0.20), int(f * 0.34), int(f * 0.12), int(f * 0.26), ramp[1])   # far arm
	_rect(img, g, int(f * 0.62), int(f * 0.34), int(f * 0.12), int(f * 0.20), ramp[1])   # hammer arm
	for side in [0.34, 0.52]:                                                            # legs
		_rect(img, g, int(f * side), int(f * 0.72), int(f * 0.12), int(f * 0.24), ramp[1])
	# The hammer: the one prop that says what this creature does for a living.
	_rect(img, g, int(f * 0.72), int(f * 0.16), maxi(1, int(f * 0.05)), int(f * 0.36), Palette.INK_MUTED)
	_rect(img, g, int(f * 0.64), int(f * 0.10), int(f * 0.22), int(f * 0.10), Palette.INK_MID)

static func clear_cache() -> void:
	_cache.clear()
