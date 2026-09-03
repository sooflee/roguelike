class_name TitleArt
extends RefCounted
## The title screen's art: a dusk scene and a pixel wordmark, both generated.
##
## Same contract as everything else (D-22): a hand-drawn PNG at
## assets/sprites/backgrounds/title.png wins if it exists.
##
## The scene is the run in one image -- green country in the foreground, the
## forge already burning on the horizon. It is drawn at 240x135 and scaled x4,
## so the pixels are four screen pixels across.
##
## EMBER (`f77622`) is reserved for the PP gauge (D-08), so the forge light is
## BONE -> SAND -> CLAY: the colour working steel actually is, and hotter-looking
## than orange for it.

const BG_W := 240
const BG_H := 135
const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}

static func backdrop() -> Texture2D:
	if _cache.has("title"):
		return _cache["title"]
	var path := SPRITE_DIR + "backgrounds/title.png"
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _generate()
	_cache["title"] = tex
	return tex

static func _generate() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260901
	var img := Image.create_empty(BG_W, BG_H, false, Image.FORMAT_RGBA8)
	var horizon := 78

	# Dusk, banded. Seven steps rather than four: at x4 a band is 4 screen pixels
	# tall, and four of them read as flat stripes instead of a sky. Darkest
	# overhead, so the wordmark has a ground to sit on, warming to the horizon.
	# One hue family, monotonic value: near-black overhead, warming through
	# purple and rust to a tan horizon behind the forge. The first attempt
	# reached for whatever palette entries looked like "sky" -- purple, magenta,
	# navy, cyan, tan -- and produced a test pattern, because those five are not
	# a ramp in either hue or value. Skipping VIOLET matters: at full saturation
	# it is the brightest thing on screen and drags the eye off the wordmark.
	var sky := [
		[0, Palette.GROUND], [15, Palette.GROUND], [27, Palette.SHADOW],
		[40, Palette.VIOLET_DARK], [56, Palette.RUST], [68, Palette.LEATHER],
		[75, Palette.CLAY],
	]
	for y in BG_H:
		var col: Color = Palette.GROUND
		for band in sky:
			if y >= int(band[0]):
				col = band[1]
		for x in BG_W:
			img.set_pixel(x, y, col)

	# Stars, only in the dark upper band where they can be seen.
	for _i in 40:
		var sx := rng.randi_range(0, BG_W - 1)
		var sy := rng.randi_range(1, 30)
		img.set_pixel(sx, sy, Palette.BONE if rng.randf() < 0.3 else Palette.INK_MID)

	# The forge on the horizon: a stack and a hall, throwing light into the sky.
	# The plume narrows going UP and breaks into scattered pixels at its edges,
	# so it reads as light and smoke rather than as a solid shape sitting on the
	# roof -- which is what a clean triangle looked like.
	var fx := 168
	for r in 26:
		var up := horizon - 40 - r
		if up < 0:
			continue
		var spread: int = maxi(1, 7 - r / 4)
		var glow: Color = Palette.CLAY if r < 9 else Palette.VIOLET_DARK
		for x in range(fx - spread, fx + spread + 1):
			if x < 0 or x >= BG_W:
				continue
			# Ragged edges: solid at the core, scattered at the rim.
			var edge: bool = absi(x - fx) >= spread - 1
			if edge and rng.randf() < 0.55:
				continue
			img.set_pixel(x, up, glow)
	_rect(img, fx - 3, horizon - 40, 7, 22, Palette.SHADOW)          # chimney
	_rect(img, fx - 20, horizon - 16, 40, 18, Palette.SHADOW)        # hall
	_rect(img, fx - 12, horizon - 9, 8, 7, Palette.BONE)             # doorway light
	_rect(img, fx + 4, horizon - 9, 6, 5, Palette.SAND)
	# Light spilling onto the ground in front of the door.
	for i in 9:
		_rect(img, fx - 14 - i, horizon - 2 + i / 3, 3, 1, Palette.CLAY)

	# Ridges, far to near, each darker: the country the run crosses to get there.
	_ridge(img, rng, horizon + 2, 8.0, 61.0, Palette.MOSS_DARK)
	_ridge(img, rng, horizon + 20, 7.0, 39.0, Palette.TEAL_DARK)
	_ridge(img, rng, horizon + 44, 6.0, 27.0, Palette.SHADOW)
	return ImageTexture.create_from_image(img)

static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < BG_W and yy >= 0 and yy < BG_H:
				img.set_pixel(xx, yy, col)

static func _ridge(img: Image, rng: RandomNumberGenerator, base_y: int,
		amp: float, period: float, col: Color) -> void:
	var phase := rng.randf() * TAU
	for x in BG_W:
		var t := float(x) / period
		var crest := base_y + int(round(sin(t + phase) * amp * 0.6 + sin(t * 0.37) * amp * 0.4))
		for y in range(maxi(0, crest), BG_H):
			if y >= 0 and y < BG_H:
				img.set_pixel(x, y, col)

# --- wordmark --------------------------------------------------------------

## A 5x7 block alphabet, only the letters EMBERWRIGHT needs. The real 8px
## bitmap font is an outstanding art asset; until it lands, the title at least
## should not be rendered in Godot's default sans.
const GLYPHS := {
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"R": ["####.", "#...#", "#...#", "####.", "##...", "#.#..", "#..##"],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
}

static func wordmark(text: String) -> Texture2D:
	var key := "word:%s" % text
	if _cache.has(key):
		return _cache[key]
	var cols := text.length() * 6 - 1
	var img := Image.create_empty(cols, 9, false, Image.FORMAT_RGBA8)
	for i in text.length():
		var rows: Array = GLYPHS.get(text[i], GLYPHS["I"])
		for y in 7:
			var row: String = rows[y]
			for x in 5:
				if row[x] == "#":
					# Struck metal: light face, dark bed one pixel below.
					img.set_pixel(i * 6 + x, y, Palette.BONE)
					if y == 6 or rows[y + 1][x] == ".":
						img.set_pixel(i * 6 + x, y + 1, Palette.CLAY)
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

static func clear_cache() -> void:
	_cache.clear()
