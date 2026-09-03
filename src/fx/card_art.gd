class_name CardArt
extends RefCounted
## Card illustrations, drawn from the move's TYPE first and its effect second.
##
## The previous version keyed only on the effect, so every attacking move was
## the same steel blade whether it was Ember, Water Gun or Rock Slide -- the art
## said what the card did to the rules, and nothing about what the move was.
## Type is the thing a player reads first in this genre, so type drives the
## image and the effect only shapes the composition behind it.
##
## Still a placeholder (D-22): drop a hand-drawn PNG at
## assets/sprites/cards/<id>.png and it is used instead, no code change.

const W := 80
const H := 56
const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}

## dark / mid / light per type. Palette constants only (D-08). EMBER itself is
## reserved for the PP gauge and never appears here.
const RAMPS := {
	Element.Kind.NORMAL:   [Palette.INK_MUTED, Palette.INK_LIGHT, Palette.BONE],
	Element.Kind.FIRE:     [Palette.EMBER_DEEP, Palette.FLAME, Palette.SAND],
	Element.Kind.WATER:    [Palette.QUENCH_DEEP, Palette.QUENCH, Palette.QUENCH_BRIGHT],
	Element.Kind.GRASS:    [Palette.MOSS_DARK, Palette.MOSS, Palette.BONE],
	Element.Kind.ELECTRIC: [Palette.FLAME, Palette.SPARK, Palette.WHITE],
	Element.Kind.ROCK:     [Palette.RUST, Palette.LEATHER, Palette.CLAY],
	Element.Kind.FLYING:   [Palette.INK_MUTED, Palette.INK_MID, Palette.INK_LIGHT],
	Element.Kind.POISON:   [Palette.VIOLET_DARK, Palette.VIOLET, Palette.ROSE],
	Element.Kind.STEEL:    [Palette.BORDER, Palette.INK_MID, Palette.INK_LIGHT],
	Element.Kind.FIGHTING: [Palette.BLOOD, Palette.RED, Palette.ROSE],
	Element.Kind.PSYCHIC:  [Palette.VIOLET_DARK, Palette.ROSE, Palette.BONE],
	Element.Kind.DRAGON:   [Palette.QUENCH_DEEP, Palette.VIOLET, Palette.QUENCH_BRIGHT],
}

static func for_card(card: CardData) -> Texture2D:
	var key := "card:%s" % card.id
	if _cache.has(key):
		return _cache[key]
	var path := "%scards/%s.png" % [SPRITE_DIR, card.id]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = _generate(card)
	_cache[key] = tex
	return tex

static func _generate(card: CardData) -> Texture2D:
	var field := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	field.fill(Palette.SHADOW)
	var ramp: Array = RAMPS.get(card.element, RAMPS[Element.Kind.NORMAL])

	# The effect shapes the stage the symbol stands on, so a defensive move and
	# an attacking move of the same type still read apart at a glance.
	var motif := motif_for(card)
	_stage(field, motif, ramp)

	var art := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	_symbol(art, card.element, ramp)
	_outline(art)
	for y in H:
		for x in W:
			var c := art.get_pixel(x, y)
			if c.a > 0.0:
				field.set_pixel(x, y, c)
	return ImageTexture.create_from_image(field)

# --- composition -----------------------------------------------------------

## A backdrop that says what the card does: a rising sweep for attacks, a dome
## for defence, a column for a power, a fan for draw.
static func _stage(img: Image, motif: StringName, ramp: Array) -> void:
	var dark: Color = ramp[0]
	match motif:
		&"block":
			for x in W:
				var dx := (float(x) - 40.0) / 38.0
				var top := int(30.0 + dx * dx * 22.0)
				_rect(img, x, top, 1, H - top, dark)
		&"power":
			_rect(img, 30, 0, 20, H, dark)
		&"draw":
			for i in 3:
				_rect(img, 12 + i * 20, 14 + i * 4, 16, 30, dark)
		&"cash_out":
			for i in 6:
				_rect(img, 8 + i * 12, 34 + i * 3, 8, H, dark)
		_:
			# Rising diagonal: mass entering bottom-left, leaving upper-right.
			for i in 60:
				_rect(img, 6 + i, 48 - i, 8, 6, dark)

static func motif_for(card: CardData) -> StringName:
	var kinds := _effect_kinds(card.effects)
	if card.type == CardData.Type.POWER:
		return &"power"
	for verb in [&"cash_out", &"draw", &"block"]:
		if kinds.has(verb):
			return verb
	return &"attack"

static func _effect_kinds(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		if e is SpendPPEffect:       out.append(&"cash_out")
		elif e is GainBlockEffect:   out.append(&"block")
		elif e is DrawCardsEffect:   out.append(&"draw")
		elif e is DealDamageEffect:  out.append(&"attack")
		elif e is ConditionalEffect: out.append_array(_effect_kinds(e.effects))
	return out

# --- the type symbol -------------------------------------------------------

static func _symbol(img: Image, element: int, ramp: Array) -> void:
	match element:
		Element.Kind.FIRE:     _flame(img, ramp)
		Element.Kind.WATER:    _drop(img, ramp)
		Element.Kind.GRASS:    _leaf(img, ramp)
		Element.Kind.ELECTRIC: _bolt(img, ramp)
		Element.Kind.ROCK:     _rocks(img, ramp)
		Element.Kind.FLYING:   _wing(img, ramp)
		Element.Kind.POISON:   _bubbles(img, ramp)
		Element.Kind.STEEL:    _claw(img, ramp)
		Element.Kind.FIGHTING: _fist(img, ramp)
		Element.Kind.PSYCHIC:  _swirl(img, ramp)
		Element.Kind.DRAGON:   _fang(img, ramp)
		_:                     _star(img, ramp)

static func _flame(img: Image, r: Array) -> void:
	for y in range(6, 50):
		var t := float(y - 6) / 44.0
		var half := int(2.0 + t * t * 17.0)
		_rect(img, 40 - half, y, half * 2, 1, r[1])
	for y in range(20, 48):                       # inner tongue
		var t := float(y - 20) / 28.0
		var half := int(1.0 + t * 8.0)
		_rect(img, 40 - half, y, half * 2, 1, r[2])
	_rect(img, 36, 44, 8, 4, r[0])

static func _drop(img: Image, r: Array) -> void:
	_ell(img, 40, 34, 15, 14, r[1])
	for y in range(8, 26):                        # the point
		var half := int(float(y - 8) / 18.0 * 10.0) + 1
		_rect(img, 40 - half, y, half * 2, 1, r[1])
	_ell(img, 35, 30, 5, 4, r[2])                 # highlight
	_ell(img, 44, 40, 7, 5, r[0])

static func _leaf(img: Image, r: Array) -> void:
	for y in range(8, 48):
		var t := float(y - 8) / 40.0
		var half := int(sin(t * PI) * 16.0)
		if half <= 0:
			continue
		_rect(img, 40 - half, y, half * 2, 1, r[1])
	for y in range(10, 46):                       # midrib
		_rect(img, 39, y, 2, 1, r[0])
	for i in 5:                                   # veins
		_rect(img, 41, 16 + i * 6, 8 - i, 1, r[2])

static func _bolt(img: Image, r: Array) -> void:
	var pts := [Vector2i(46, 6), Vector2i(28, 30), Vector2i(38, 30),
				Vector2i(30, 50), Vector2i(52, 24), Vector2i(42, 24)]
	for i in pts.size():
		var a: Vector2i = pts[i]
		var b: Vector2i = pts[(i + 1) % pts.size()]
		_line(img, a, b, r[1], 5)
	for i in pts.size():
		var a: Vector2i = pts[i]
		var b: Vector2i = pts[(i + 1) % pts.size()]
		_line(img, a, b, r[2], 2)

static func _rocks(img: Image, r: Array) -> void:
	_rect(img, 22, 32, 22, 16, r[1]); _rect(img, 22, 32, 22, 3, r[2])
	_rect(img, 44, 26, 16, 22, r[0]); _rect(img, 44, 26, 16, 3, r[1])
	_rect(img, 32, 14, 18, 18, r[1]); _rect(img, 32, 14, 18, 3, r[2])

static func _wing(img: Image, r: Array) -> void:
	for i in 4:
		var y := 14 + i * 8
		var w := 44 - i * 6
		for x in w:
			_rect(img, 18 + x, y + int(sin(float(x) / float(w) * PI) * -4.0), 1, 4,
				r[2] if i == 0 else r[1])

static func _bubbles(img: Image, r: Array) -> void:
	_ell(img, 34, 34, 13, 12, r[1]); _ell(img, 30, 30, 4, 4, r[2])
	_ell(img, 52, 22, 8, 8, r[1]);  _ell(img, 50, 20, 3, 3, r[2])
	_ell(img, 50, 44, 6, 6, r[0])

static func _claw(img: Image, r: Array) -> void:
	for i in 3:
		var ox := i * 13
		for k in 30:
			_rect(img, 14 + ox + k / 2, 10 + k, 4, 2, r[1] if k < 20 else r[0])
		for k in 14:
			_rect(img, 14 + ox + k / 2, 10 + k, 2, 1, r[2])

static func _fist(img: Image, r: Array) -> void:
	_rect(img, 22, 18, 34, 24, r[1])
	_rect(img, 22, 18, 34, 4, r[2])
	for i in 4:                                   # knuckles
		_ell(img, 26 + i * 9, 18, 4, 4, r[1])
	_rect(img, 22, 38, 34, 4, r[0])
	_rect(img, 44, 42, 14, 8, r[0])               # wrist

static func _swirl(img: Image, r: Array) -> void:
	for ring in 3:
		var rad := 6.0 + float(ring) * 6.5
		var col: Color = [r[2], r[1], r[0]][ring]
		for a in 46:
			var th := float(a) / 46.0 * TAU
			_rect(img, 40 + int(cos(th) * rad), 28 + int(sin(th) * rad * 0.86), 3, 3, col)

static func _fang(img: Image, r: Array) -> void:
	for y in range(8, 48):
		var t := float(y - 8) / 40.0
		var half := int((1.0 - t) * 15.0) + 1
		_rect(img, 34 - half + int(t * 12.0), y, half * 2, 1, r[1])
	for y in range(12, 34):
		_rect(img, 30 + int(float(y - 12) / 22.0 * 10.0), y, 4, 1, r[2])
	_ell(img, 54, 18, 6, 6, r[0])

static func _star(img: Image, r: Array) -> void:
	for i in 22:
		var t := float(i) / 22.0
		var w := int((1.0 - t) * 16.0) + 2
		_rect(img, 40 - w / 2, 28 - i, w, 1, r[1])
		_rect(img, 40 - w / 2, 28 + i, w, 1, r[1])
	for i in 30:
		var t := float(i) / 30.0
		var h := int((1.0 - t) * 8.0) + 1
		_rect(img, 40 - i, 28 - h / 2, 1, h, r[1])
		_rect(img, 40 + i, 28 - h / 2, 1, h, r[1])
	_ell(img, 40, 28, 7, 7, r[2])

# --- primitives ------------------------------------------------------------

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, col)

static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, col)

static func _ell(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / maxf(1.0, float(rx))
			var dy := float(y - cy) / maxf(1.0, float(ry))
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, col)

static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color, thick: int) -> void:
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var t := float(i) / float(maxi(1, steps))
		var x := int(round(lerpf(float(a.x), float(b.x), t)))
		var y := int(round(lerpf(float(a.y), float(b.y), t)))
		_rect(img, x - thick / 2, y - thick / 2, thick, thick, col)

## 1px border so the symbol never dissolves into the field behind it (D-05).
static func _outline(img: Image) -> void:
	var solid: Array[Vector2i] = []
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				solid.append(Vector2i(x, y))
	for p in solid:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.x >= W or q.y < 0 or q.y >= H:
				continue
			if img.get_pixel(q.x, q.y).a == 0.0:
				img.set_pixel(q.x, q.y, Palette.OUTLINE)

static func clear_cache() -> void:
	_cache.clear()
