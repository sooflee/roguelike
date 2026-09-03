class_name IconArt
extends RefCounted
## Small pixel icons for map nodes and relics, generated at runtime.
##
## Same contract as PlaceholderArt (D-22): nothing is written to assets/, and a
## hand-drawn PNG at the expected path is used the moment it exists. These are
## scaffolding for the animation and layout work, not art.
##
## Node icons are hand-authored 12x12 patterns rather than generated shapes,
## because these seven have to be told apart instantly at a glance -- that is
## their entire job, and a procedural blob cannot do it. Relic emblems ARE
## generated: sixteen of them only need to look distinct from each other.

const SIZE := 12
const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}

## '#' body, '+' highlight, '.' transparent.
const PATTERNS := {
	"hud_hp": [
		"............",
		"..##....##..",
		".####..####.",
		".##########.",
		".##+#######.",
		".##########.",
		"..########..",
		"...######...",
		"...######...",
		"....####....",
		".....##.....",
		"............",
	],
	"hud_gold": [
		"............",
		"....####....",
		"..########..",
		".##++++++##.",
		".#++++++++#.",
		".#+++##+++#.",
		".#+++##+++#.",
		".#++++++++#.",
		".##++++++##.",
		"..########..",
		"....####....",
		"............",
	],
	"hud_deck": [
		"............",
		"...#######..",
		"...#+++++#..",
		"...#+++++#..",
		".#######+#..",
		".#+++++#+#..",
		".#+++++#+#..",
		".#+++++#+#..",
		".#+++++##...",
		".#######....",
		"............",
		"............",
	],
	"hud_bag": [
		"............",
		"....#..#....",
		"...#....#...",
		"..########..",
		".##########.",
		".#++++++++#.",
		".#++####++#.",
		".#++####++#.",
		".#++++++++#.",
		".##########.",
		"..########..",
		"............",
	],
	"draft": [
		"............",
		"..#####.....",
		"..#+++#####.",
		"..#+++#+++#.",
		"..#+++#+++#.",
		"..#+++#+++##",
		"..#+++#+++#+",
		"..#+++#+++#+",
		"..#####+++#+",
		"......#####+",
		".........+++",
		"............",
	],
	"combat": [
		"............",
		".+........+.",
		"..#......#..",
		"...#....#...",
		"....#..#....",
		".....##.....",
		".....##.....",
		"....#..#....",
		"...#....#...",
		"..#......#..",
		".+........+.",
		"............",
	],
	"elite": [
		"............",
		"....####....",
		"..########..",
		".##########.",
		".##.####.##.",
		".##.####.##.",
		".##########.",
		"..###..###..",
		"...######...",
		"...#.##.#...",
		"............",
		"............",
	],
	"event": [
		"............",
		"....####....",
		"...##..##...",
		"...##..##...",
		".......##...",
		"......##....",
		".....##.....",
		".....##.....",
		"............",
		".....##.....",
		".....##.....",
		"............",
	],
	"shop": [
		"............",
		"....####....",
		"..########..",
		".####..####.",
		".##.####.##.",
		".##.#..#.##.",
		".##.####.##.",
		".####..####.",
		"..########..",
		"....####....",
		"............",
		"............",
	],
	"campfire": [
		".....+......",
		"....++......",
		"....+++.....",
		"...+++++....",
		"...#####....",
		"..#######...",
		"..###.###...",
		"...#####....",
		"............",
		".##########.",
		"..########..",
		"............",
	],
	"treasure": [
		"............",
		"..########..",
		".##########.",
		".####++####.",
		".##########.",
		"............",
		".##########.",
		".####++####.",
		".##########.",
		".##########.",
		"............",
		"............",
	],
	"boss": [
		"............",
		".+..+..+..+.",
		".#..#..#..#.",
		".##.##.##.##",
		".##########.",
		".##########.",
		".##.##.##.##",
		".##########.",
		"..########..",
		"............",
		"............",
		"............",
	],
}

## The run header's glyphs. Colours are fixed here rather than passed in, so the
## heart is the same red everywhere it appears and a caller cannot quietly
## invent a fifth palette entry (D-08).
const HUD_COLOURS := {
	"hud_hp":   [Palette.BLOOD, Palette.ROSE],
	"hud_gold": [Palette.FLAME, Palette.SPARK],
	"hud_deck": [Palette.QUENCH_DEEP, Palette.INK_LIGHT],
	"hud_bag":  [Palette.RUST, Palette.LEATHER],
}

static func hud(name: String) -> Texture2D:
	var key := "hud:%s" % name
	if _cache.has(key):
		return _cache[key]
	var cols: Array = HUD_COLOURS.get(name, [Palette.INK_MID, Palette.INK_LIGHT])
	var tex := _from_pattern(PATTERNS[name], cols[0], cols[1])
	_cache[key] = tex
	return tex

static func for_node(kind_name: String, body: Color, highlight: Color) -> Texture2D:
	var key := "node:%s:%s" % [kind_name, body.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var path := "%snodes/%s.png" % [SPRITE_DIR, kind_name]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _from_pattern(PATTERNS.get(kind_name, PATTERNS["combat"]), body, highlight)
	_cache[key] = tex
	return tex

static func _from_pattern(rows: Array, body: Color, highlight: Color) -> Texture2D:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in mini(SIZE, rows.size()):
		var row: String = rows[y]
		for x in mini(SIZE, row.length()):
			match row[x]:
				"#": img.set_pixel(x, y, body)
				"+": img.set_pixel(x, y, highlight)
	_outline(img)
	return ImageTexture.create_from_image(img)

## A one-pixel dark border around the silhouette. Without it an icon vanishes
## the moment it sits on a node circle of a similar value.
static func _outline(img: Image) -> void:
	var solid: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(x, y).a > 0.0:
				solid.append(Vector2i(x, y))
	for p in solid:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.x >= SIZE or q.y < 0 or q.y >= SIZE:
				continue
			if img.get_pixel(q.x, q.y).a == 0.0:
				img.set_pixel(q.x, q.y, Palette.OUTLINE)

## A consumable's icon. Real item sprites where they exist, a generated emblem
## where they do not -- the Mystery Dungeon seeds and X items have no published
## sprite, and a missing picture should degrade rather than crash.
static func for_item(id: StringName) -> Texture2D:
	var key := "item:%s" % id
	if _cache.has(key):
		return _cache[key]
	var path := "%sitems/%s.png" % [SPRITE_DIR, id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _generate_emblem("item:" + String(id))
	_cache[key] = tex
	return tex

## A symmetric emblem derived from the relic's id. Mirrored down the centre so
## it reads as a made object rather than as noise.
static func for_relic(id: StringName) -> Texture2D:
	var key := "relic:%s" % id
	if _cache.has(key):
		return _cache[key]
	var path := "%srelics/%s.png" % [SPRITE_DIR, id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _generate_emblem(String(id))
	_cache[key] = tex
	return tex

const EMBLEM_RAMPS := [
	[Palette.LEATHER, Palette.CLAY, Palette.SAND],
	[Palette.QUENCH_DEEP, Palette.QUENCH, Palette.QUENCH_BRIGHT],
	[Palette.VIOLET_DARK, Palette.VIOLET, Palette.ROSE],
	[Palette.MOSS_DARK, Palette.MOSS, Palette.BONE],
	[Palette.RUST, Palette.BLOOD, Palette.RED],
]

static func _generate_emblem(seed_text: String) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var ramp: Array = EMBLEM_RAMPS[rng.randi_range(0, EMBLEM_RAMPS.size() - 1)]
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE / 2
	for y in range(2, SIZE - 2):
		for x in half:
			# Denser toward the centre column, so the emblem has a spine.
			var chance := 0.72 - float(x) * 0.09
			if rng.randf() > chance:
				continue
			var shade: Color = ramp[1] if rng.randf() < 0.6 else ramp[2]
			img.set_pixel(half - 1 - x, y, shade)
			img.set_pixel(half + x, y, shade)
	# Ground the emblem so it never floats as scattered pixels.
	for x in range(2, SIZE - 2):
		img.set_pixel(x, SIZE - 3, ramp[0])
	_outline(img)
	return ImageTexture.create_from_image(img)

## A Poke Ball, for the mouse pointer. Drawn rather than downloaded so it stays
## on the locked palette and on the pixel grid like everything else.
static func poke_ball(size: int = 24) -> Texture2D:
	var key := "ball:%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	var r := c - 1.0
	for y in size:
		for x in size:
			var dx := float(x) - c + 0.5
			var dy := float(y) - c + 0.5
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var col: Color
			if d > r - 1.5:
				col = Palette.OUTLINE                      # rim
			elif absf(dy) < 1.5:
				col = Palette.OUTLINE                      # the band
			elif sqrt(dx * dx + dy * dy) < r * 0.28:
				col = Palette.WHITE if d < r * 0.18 else Palette.OUTLINE
			elif dy < 0.0:
				col = Palette.RED
			else:
				col = Palette.BONE
			img.set_pixel(x, y, col)
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

static func clear_cache() -> void:
	_cache.clear()
