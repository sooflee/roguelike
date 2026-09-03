class_name EntityView
extends Node2D
## Visual representation of one combatant: sprite, HP bar, block, intent,
## statuses -- plus the animations for everything that can happen to it.
##
## Reads state that has ALREADY resolved. `display_hp` lags behind the real HP
## and is tweened toward it, which is what makes a health bar drain rather than
## teleport. The simulation never waits for this.

const BAR_W := 96
const BAR_H := 8

var combatant: Combatant
var sprite: Sprite2D
var display_hp: float = 0.0
var display_block: int = 0
var is_dying: bool = false

var _label: Label
var _intent_label: Label
var _status_label: Label
var _flash_mat: ShaderMaterial
var _hover: bool = false
## Idle motion. Small on purpose: this runs behind every other animation in the
## game, so anything readable as movement in isolation is noise in combination.
const IDLE_SPEED := 1.7
const IDLE_RISE := 1.5
const IDLE_SWELL := 0.02
## Sway is what separates a creature from a bobbing sprite. Whole pixels only.
const IDLE_SWAY := 1.0

## Frame animation. 12fps is the Gen-5 sprites' own rate; faster reads as
## jitter, slower as a slideshow.
const FPS := 12.0

var _frames: int = 1
var _frame: int = 0
var _frame_time: float = 0.0

var _idle_phase: float = 0.0
var _idle_time: float = 0.0
var _sprite_home: Vector2 = Vector2.ZERO
## Draw scale for this species, from CreatureScale. Everything that touches
## sprite.scale multiplies through it -- breathing and the hurt squash were
## both written assuming 1.0 and would otherwise snap the creature back to
## whatever size its art happened to be.
var _base_scale: float = 1.0
var _selectable: bool = false

signal clicked(view)

func setup(c: Combatant, texture: Texture2D) -> void:
	combatant = c
	display_hp = float(c.hp)
	display_block = c.block

	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = load("res://src/fx/hit_flash.gdshader")
	_flash_mat.set_shader_parameter("flash_amount", 0.0)
	_flash_mat.set_shader_parameter("flash_color", Palette.WHITE)
	sprite.material = _flash_mat
	add_child(sprite)

	# A sprite strip is N square cells wide, so the frame count is simply
	# width / height. One cell means a still image and nothing animates.
	var h := texture.get_height()
	_frames = maxi(1, texture.get_width() / maxi(1, h))
	if _frames > 1:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, h, h)
		# Each creature starts on its own frame, so a line of the same species
		# does not flap in lockstep.
		_frame = randi() % _frames
	_base_scale = CreatureScale.factor(texture, c.height_m)
	sprite.scale = Vector2(_base_scale, _base_scale)
	# Anchored on the bottom of the cell, so the feet stay on the platform
	# whatever the scale. Centring instead would sink the big ones into the
	# ground and hover the small ones above it.
	sprite.position = Vector2(0, -h * 0.5 * _base_scale)

	_label = _make_label(16)
	_label.position = Vector2(-BAR_W / 2.0, 10)
	_intent_label = _make_label(15)
	_intent_label.position = Vector2(-BAR_W / 2.0, -h - 30)
	_status_label = _make_label(13)
	_status_label.position = Vector2(-BAR_W / 2.0, 44)

	# Every combatant breathes on its own clock. A shared phase would read as a
	# single mechanism ticking rather than several creatures waiting.
	_idle_phase = randf() * TAU
	_sprite_home = sprite.position

	set_process(true)
	queue_redraw()

func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.INK_LIGHT)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.custom_minimum_size = Vector2(BAR_W, 0)
	add_child(l)
	return l

func set_selectable(v: bool) -> void:
	_selectable = v
	queue_redraw()

func _process(delta: float) -> void:
	if combatant == null:
		return
	# Bars chase the true value rather than snapping to it.
	var target := float(combatant.hp)
	if not is_equal_approx(display_hp, target):
		display_hp = move_toward(display_hp, target, maxf(28.0, absf(display_hp - target) * 7.0) * delta)
		queue_redraw()
	if display_block != combatant.block:
		display_block = combatant.block
		queue_redraw()
	_advance_frame(delta)
	_idle(delta)
	_refresh_text()

## Steps the sprite strip. Freezes on the current frame when motion is turned
## off (D-23) rather than snapping to frame zero, which would look like a bug.
func _advance_frame(delta: float) -> void:
	if _frames <= 1 or sprite == null or Juice.intensity <= 0.0 or is_dying:
		return
	_frame_time += delta * FPS * Juice.speed_scale
	if _frame_time < 1.0:
		return
	_frame = (_frame + int(_frame_time)) % _frames
	_frame_time = fmod(_frame_time, 1.0)
	var cell := sprite.region_rect.size.y
	sprite.region_rect = Rect2(float(_frame) * cell, 0.0, cell, cell)

## Breathing. Two sines an octave apart so the loop does not read as a metronome,
## scaled by Juice.intensity so the reduce-motion setting (D-23) stops it dead.
##
## The dying are exempt: a corpse mid-dissolve that is still breathing is worse
## than one that is not animated at all.
func _idle(delta: float) -> void:
	if sprite == null or is_dying or Juice.intensity <= 0.0:
		return
	_idle_time += delta
	var t := _idle_time * IDLE_SPEED + _idle_phase
	# Heavier things move less and slower. A Slag Titan breathing like an Ash
	# Wisp is the single fastest way to make both of them feel weightless.
	var heft: float = clampf(float(combatant.max_hp) / 60.0, 0.35, 1.6)
	var weight := 1.0 / heft
	var rise := (sin(t * weight) * 0.72 + sin(t * 2.0 * weight) * 0.28) \
		* IDLE_RISE * weight * Juice.intensity
	var sway := sin(t * 0.63 * weight) * IDLE_SWAY * weight * Juice.intensity
	# Whole pixels only: a pixel-art sprite drifting on sub-pixel offsets
	# shimmers against the nearest-neighbour filter (D-05).
	sprite.position = _sprite_home + Vector2(roundf(sway), roundf(rise))
	# Enemies about to act lean in. The tell is the animation, not just the text.
	var keyed: bool = not combatant.is_player and combatant.intent != null \
		and combatant.intent.kind == Intent.Kind.ATTACK
	var breathe := 1.0 + (sin(t * 1.5 * weight) * 0.5 + 0.5) \
		* (IDLE_SWELL * (2.0 if keyed else 1.0)) * Juice.intensity
	# Volume is roughly conserved: a chest that swells also narrows, which reads
	# as breathing rather than as a sprite being stretched.
	sprite.scale = Vector2(_base_scale / breathe, _base_scale * breathe)

func _refresh_text() -> void:
	if combatant == null:
		return
	_label.text = "%s   %d/%d" % [combatant.display_name, combatant.hp, combatant.max_hp]
	var parts: Array[String] = []
	# Standing passives read first: they are true every turn, unlike a status
	# that is decaying and unlike the intent, which is only true for the next one.
	if combatant is Enemy and combatant.passive_text != "":
		parts.append(combatant.passive_text)
	for st in combatant.statuses.values():
		if st.stacks != 0:
			parts.append("%s %d" % [st.display_name, st.stacks])
	_status_label.text = ", ".join(parts)
	_status_label.add_theme_color_override("font_color",
		Palette.VIOLET if parts.size() > 0 else Palette.INK_MUTED)

	if combatant is Enemy and combatant.is_alive():
		_intent_label.text = _intent_text(combatant.intent)
		_intent_label.add_theme_color_override("font_color", _intent_color(combatant.intent))
	else:
		_intent_label.text = ""

## A move's own `tell` wins over the generic wording for its kind. "ATTACK 4 +
## weaken" is the right label for three different moves and the wrong one for a
## move that eats your PP refill, so any move that does something the intent
## kinds cannot name says so itself.
func _intent_text(i: Intent) -> String:
	if i == null:
		return ""
	var hits := " x%d" % i.hits if i.hits > 1 else ""
	# Lead with the move, then the number. These are Pokemon fighting each other,
	# so what is coming is "Water Gun", not "ATTACK 7" -- and the name is the
	# part a player learns to recognise across a run.
	var name := i.move_name()
	match i.kind:
		Intent.Kind.ATTACK:
			return "%s  %d%s%s" % [name, i.damage, hits, _rider(i)]
		Intent.Kind.ATTACK_DEBUFF:
			return "%s  %d%s%s" % [name, i.damage, hits, _rider(i, "weaken")]
		Intent.Kind.ATTACK_DEFEND:
			return "%s  %d%s%s" % [name, i.damage, hits, _rider(i, "guard")]
		Intent.Kind.DEFEND, Intent.Kind.BUFF, Intent.Kind.DEBUFF:
			return name if name != "" else "?"
		Intent.Kind.SLEEP:
			return "Asleep"
		_: return "?"

func _rider(i: Intent, fallback: String = "") -> String:
	var word := i.tell if i.tell != "" else fallback
	return " + %s" % word if word != "" else ""

func _intent_color(i: Intent) -> Color:
	if i == null:
		return Palette.INK_MUTED
	match i.kind:
		Intent.Kind.ATTACK, Intent.Kind.ATTACK_DEBUFF, Intent.Kind.ATTACK_DEFEND:
			return Palette.RED
		Intent.Kind.DEFEND: return Palette.QUENCH
		Intent.Kind.BUFF:   return Palette.FLAME
		_: return Palette.VIOLET

func _draw() -> void:
	if combatant == null:
		return
	var x := -BAR_W / 2.0
	var y := 0.0
	# HP bar, drawn with a 1px dark frame so it sits on the pixel grid.
	draw_rect(Rect2(x - 1, y - 1, BAR_W + 2, BAR_H + 2), Palette.OUTLINE)
	draw_rect(Rect2(x, y, BAR_W, BAR_H), Palette.SURFACE)
	var frac := clampf(display_hp / maxf(1.0, float(combatant.max_hp)), 0.0, 1.0)
	if frac > 0.0:
		var col := Palette.MOSS if frac > 0.5 else (Palette.FLAME if frac > 0.25 else Palette.RED)
		draw_rect(Rect2(x, y, round(BAR_W * frac), BAR_H), col)
	if display_block > 0:
		draw_rect(Rect2(x - 1, y + BAR_H + 2, 30, 14), Palette.OUTLINE)
		draw_rect(Rect2(x, y + BAR_H + 3, 28, 12), Palette.QUENCH_DEEP)
		draw_string(ThemeDB.fallback_font, Vector2(x + 4, y + BAR_H + 13),
			str(display_block), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.QUENCH_BRIGHT)
	if _selectable:
		# The CELL at the drawn scale, exactly as hit_test does it. Reading
		# get_width() here gave 1536 -- the whole 16-frame strip -- so the
		# "which enemy am I aiming at" outline was wider than the screen and
		# every living enemy drew one on top of the others.
		var cell := float(sprite.texture.get_height()) if sprite and sprite.texture else 64.0
		var h := cell * _base_scale
		var w := cell * _base_scale
		var col := Palette.SPARK if _hover else Palette.EMBER
		draw_rect(Rect2(-w / 2.0 - 4, -h - 4, w + 8, h + 8), col, false, 2.0)

# --- animations ------------------------------------------------------------

## `element` colours the damage number to the move that caused it; -1 leaves it
## the default red for untyped damage.
func play_hurt(amount: int, element: int = -1) -> void:
	if sprite == null:
		return
	Juice.flash(sprite)
	# Squash horizontally as well as scaling down: a flinch is a body folding,
	# not a sprite shrinking evenly.
	Juice.pop(sprite, 0.86, 0.14)
	var t := create_tween()
	t.tween_property(sprite, "scale",
		Vector2(_base_scale * 1.18, _base_scale * 0.82), Juice.dur(0.05))
	t.tween_property(sprite, "scale",
		Vector2(_base_scale, _base_scale), Juice.dur(0.12)).set_trans(Tween.TRANS_ELASTIC)
	var col: Color = Element.colour(element) if element >= 0 else Palette.RED
	Juice.popup("-%d" % amount, col, global_position + Vector2(0, -70),
		1.0 + minf(amount / 40.0, 0.8))

## Tints the sprite for a beat -- used to say "super effective" in colour as
## well as in words, since the popup is easy to miss mid-fight.
func play_tint(colour: Color, strength: float = 0.85) -> void:
	if _flash_mat == null:
		return
	_flash_mat.set_shader_parameter("flash_color", colour)
	_flash_mat.set_shader_parameter("flash_amount", strength)
	var t := create_tween()
	t.tween_method(func(v: float):
		_flash_mat.set_shader_parameter("flash_amount", v), strength, 0.0, Juice.dur(0.45))

func play_block(amount: int) -> void:
	Juice.popup("+%d" % amount, Palette.QUENCH_BRIGHT, global_position + Vector2(0, -70))

func play_heal(amount: int) -> void:
	Juice.popup("+%d" % amount, Palette.MOSS, global_position + Vector2(0, -70))

func play_status(id: StringName, stacks: int) -> void:
	Juice.popup("%s %d" % [String(id).left(4).to_upper(), stacks],
		Palette.for_status(id), global_position + Vector2(0, -50))

func play_attack(direction: Vector2) -> void:
	Juice.lunge(self, direction)

## How far short of the target a charge stops. Landing ON it overlaps the two
## sprites into one blob at exactly the frame the hit needs to be legible.
const STRIKE_GAP := 62.0

## True while a charge is in flight, so the later hits of a multi-hit move
## (Comet Punch is four) flurry where the attacker already is instead of
## running the whole charge four times.
var is_charging := false

## Crosses the field, strikes, and springs home.
##
## For a contact move the thing that should travel is the Pokemon, not a card
## thrown at the target -- Scratch should look like Scratch. Ranged moves keep
## the small lunge and send a volley instead.
func play_charge(to: Vector2) -> void:
	if Juice.intensity <= 0.0:
		return
	if sprite == null or is_charging:
		return
	var dir := (to - position).normalized()
	if dir == Vector2.ZERO:
		return
	is_charging = true
	# Only the CREATURE travels. Moving the whole view drags the name and the
	# HP bar across the field with it, so at the exact frame the hit lands the
	# attacker's nameplate is sitting on top of the victim's.
	#
	# _sprite_home is the anchor _idle() breathes around, so tweening it moves
	# the sprite without the two fighting over sprite.position.
	var home := _sprite_home
	var reach := to - position - dir * STRIKE_GAP
	var was_z := z_index
	z_index = was_z + 40      # over whatever it is hitting, while it is there
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	# Wind back, drive in, hold on the hit, then return under its own steam.
	t.tween_property(self, "_sprite_home", home - dir * 16.0, Juice.dur(0.10)) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_sprite_home", home + reach, Juice.dur(0.11)) \
		.set_ease(Tween.EASE_IN)
	t.tween_interval(Juice.dur(0.10))
	t.tween_property(self, "_sprite_home", home, Juice.dur(0.22)).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		is_charging = false
		z_index = was_z)

## Death: dissolve rather than an alpha fade, so the sprite stays crisp on the
## pixel grid instead of turning to mush on the way out.
func play_death() -> void:
	if is_dying or sprite == null:
		return
	is_dying = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/dissolve.gdshader")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 64
	tex.height = 64
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("edge_color", Palette.EMBER)
	sprite.material = mat
	_label.visible = false
	_intent_label.visible = false
	_status_label.visible = false
	_selectable = false
	queue_redraw()
	var t := create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.05, Juice.dur(0.55))

# --- input -----------------------------------------------------------------

func _input_event(_vp: Viewport, event: InputEvent, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(self)

func hit_test(point: Vector2) -> bool:
	if sprite == null or sprite.texture == null or is_dying:
		return false
	# The CELL, and at the scale it is drawn.
	#
	# sprite.texture is the whole 16-frame strip, so get_width() was 1536 and
	# every enemy claimed a hit box sixteen cells wide. They all overlapped
	# each other and most of the field, so whichever came first in the list
	# swallowed the click -- targeting the enemy you pointed at was luck.
	# _base_scale rather than sprite.scale: the live one is mid-breath, and a
	# hit box that inflates and deflates is not one a player can learn.
	var cell := float(sprite.texture.get_height())
	var w := cell * _base_scale
	var h := cell * _base_scale
	return Rect2(global_position + Vector2(-w / 2.0, -h), Vector2(w, h + 20)).has_point(point)

func set_hover(v: bool) -> void:
	if _hover == v:
		return
	_hover = v
	queue_redraw()
