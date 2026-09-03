class_name PPGauge
extends Node2D
## The Emberwright's PP curve.
##
## This is the class's whole identity (docs/DECISIONS.md D-11), so it gets more
## visual attention than any other HUD element. Three pip states carry the whole
## mechanic at a glance:
##
##   LIT     -- PP you can spend right now
##   SPENT   -- unlocked by the ramp, already used this turn
##   LOCKED  -- past your current refill; the ramp has not reached it yet
##
## Overloaded pips are struck through in alarm: that is exactly how much smaller
## next turn's refill will be. The debt is visible before it comes due -- and
## since D-27 it does not vanish when it is charged, so the gauge also has to
## show the refill the debt is currently eating and how many turns of it are
## left. A cost the player cannot see coming is not a decision they made.

const BLOCK_W := 20
const BLOCK_H := 28
const GAP := 4

var pp: int = 0
var max_pp: int = 0
var cap: int = Player.PP_CAP
var overload: int = 0
var display_fill: float = 0.0

var _label: Label
var _particles: GPUParticles2D
var _pulse: float = 0.0

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(0, -24)
	add_child(_label)

	_particles = GPUParticles2D.new()
	_particles.amount = 26
	_particles.lifetime = 1.1
	_particles.emitting = false
	_particles.texture = _spark_texture()
	_particles.position = Vector2(_width() * 0.5, BLOCK_H)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 22.0
	mat.initial_velocity_min = 26.0
	mat.initial_velocity_max = 62.0
	mat.gravity = Vector3(0, -30, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.4
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(_width() * 0.5, 2, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Palette.SPARK)
	ramp.set_color(1, Color(Palette.EMBER_DEEP, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	_particles.process_material = mat
	add_child(_particles)

	set_process(true)

func _width() -> int:
	return cap * BLOCK_W + (cap - 1) * GAP

func _spark_texture() -> Texture2D:
	var img := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Palette.WHITE)
	return ImageTexture.create_from_image(img)

func set_pp(value: int, p_max: int, p_cap: int, p_overload: int) -> void:
	var changed := value != pp or p_max != max_pp or p_overload != overload
	pp = value
	max_pp = p_max
	cap = maxi(1, p_cap)
	overload = p_overload
	# Embers burn while you are in debt -- the fire you are running on is not
	# yours yet.
	_particles.emitting = overload > 0
	if changed:
		_pulse = 1.0
		Juice.pop(self, 1.06, 0.14)
	queue_redraw()

func flash_overload() -> void:
	_pulse = 1.6
	Juice.shake(7.0)
	Juice.hitstop(0.05)
	Juice.popup("OVERLOAD", Palette.ALARM, global_position + Vector2(_width() * 0.5 - 40, -50), 1.4)
	queue_redraw()

func flash_ramp() -> void:
	_pulse = 1.4
	Juice.popup("RAMP", Palette.SPARK, global_position + Vector2(_width() * 0.5 - 24, -50), 1.2)
	queue_redraw()

## The debt coming due. It was taken with a shake, a hitstop and a popup, and
## repaid in complete silence -- the player started a turn short of PP with
## nothing on screen saying why.
##
## `overload` is what is still owed AFTER this charge, so a debt that is still
## running says so rather than looking like it has been settled.
func flash_repaid(owed: int) -> void:
	if owed <= 0:
		return
	_pulse = 1.3
	var text := "−%d BORROWED" % owed
	if overload > 0:
		text += "  (%d STILL OWED)" % overload
	Juice.popup(text, Palette.ALARM,
		global_position + Vector2(_width() * 0.5 - 44, -50), 1.3)
	queue_redraw()

func _process(delta: float) -> void:
	var target := float(pp)
	if not is_equal_approx(display_fill, target):
		display_fill = move_toward(display_fill, target, 9.0 * delta)
		queue_redraw()
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.2)
		queue_redraw()
	# State the RULE, in numbers, permanently. What Ramp bought and what Overload
	# costs are the two things a player has to infer from nothing otherwise --
	# and "what will I have next turn" is the exact question the class is built
	# to price, so it should never have to be worked out.
	_label.text = _readout()
	_label.add_theme_color_override("font_color",
		Palette.ALARM if overload > 0 else Palette.INK_MID)

## What next turn refills to: the ramp climbs one, then the debt comes off.
func next_turn_pp() -> int:
	return maxi(0, mini(max_pp + 1, cap) - overload)

func _readout() -> String:
	if overload > 0:
		# The debt only pays down one a turn, so "next turn" is no longer the
		# whole story -- the number of turns it runs for is the thing the player
		# is actually gambling on, and it belongs on screen next to the cost.
		var turns := "1 more turn" if overload <= 1 else "%d more turns" % overload
		return "PP %d  ·  next turn %d  (%d refill − %d owed, %s)" % [
			pp, next_turn_pp(), mini(max_pp + 1, cap), overload, turns]
	if max_pp >= cap:
		return "PP %d of %d  ·  at maximum" % [pp, max_pp]
	return "PP %d of %d  ·  next turn %d of %d" % [pp, max_pp, next_turn_pp(), cap]

func _draw() -> void:
	# Borrowed PP can push the total past the ceiling, so the row is as long
	# as whichever is greater. Drawing only `cap` pips hid a point of PP the
	# player owned behind a "locked" cell while the label counted it.
	var pips: int = maxi(cap, pp)
	for i in pips:
		var x := i * (BLOCK_W + GAP)
		var r := Rect2(x, 0, BLOCK_W, BLOCK_H)
		draw_rect(Rect2(x - 1, -1, BLOCK_W + 2, BLOCK_H + 2), Palette.OUTLINE)

		# Past the ceiling but held anyway: this is the borrowed PP. Drawn in
		# alarm because it IS the debt -- rather than striking through pips the
		# player can spend right now, which read as "unavailable" and meant the
		# opposite of what it said.
		if i >= max_pp:
			if i < pp:
				draw_rect(r, Palette.SURFACE)
				draw_rect(Rect2(x, 0, BLOCK_W, BLOCK_H), Palette.ALARM)
			else:
				# Room the ramp has not reached yet.
				draw_rect(r, Palette.TEAL_DARK)
			continue

		draw_rect(r, Palette.SURFACE)
		var filled := display_fill - float(i)
		if filled > 0.0:
			var frac := clampf(filled, 0.0, 1.0)
			draw_rect(Rect2(x, BLOCK_H * (1.0 - frac), BLOCK_W, BLOCK_H * frac), Palette.EMBER)
		# Refill the debt is eating, on every turn it goes on eating it. Struck
		# through rather than filled, so what the player owns and what they owe
		# are never the same shape.
		elif i >= max_pp - overload:
			draw_line(Vector2(x + 2, BLOCK_H - 3), Vector2(x + BLOCK_W - 2, 3), Palette.ALARM, 2.0)

	# The CAP, not the current ceiling: the thing Ramp is racing toward, and the
	# only one of the two the pip colours do not already draw.
	var tx := float(cap) * (BLOCK_W + GAP) - GAP / 2.0
	draw_line(Vector2(tx, -6), Vector2(tx, BLOCK_H + 6), Palette.SPARK, 2.0)

	if _pulse > 0.0:
		var glow := Color(Palette.ALARM if overload > 0 else Palette.EMBER,
			clampf(_pulse * 0.5, 0.0, 0.6))
		draw_rect(Rect2(-4, -4, _width() + 8, BLOCK_H + 8), glow, false, 3.0)
