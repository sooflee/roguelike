extends Node
## Global game feel. One file, so "the game feels mushy" is a tuning session
## rather than an archaeology expedition through fifty scenes.
##
## Everything here is presentation. None of it can affect combat state -- that
## separation is docs/DECISIONS.md D-13, and it is why animation speed is a free
## parameter instead of a physics constant.

## 0.0 disables all motion. Doubles as a "reduce motion" accessibility toggle.
var intensity: float = 1.0
## Multiplies playback speed. Players on their hundredth run want 2x or instant.
var speed_scale: float = 1.0

var _shake_amount: float = 0.0
var _shake_decay: float = 14.0
var _shake_target: Node2D = null
var _shake_origin: Vector2 = Vector2.ZERO
var _popup_layer: Node = null
## Incremented per hitstop so overlapping calls cannot restore time early.
var _hitstop_token: int = 0

func _process(delta: float) -> void:
	if _shake_target == null or not is_instance_valid(_shake_target):
		return
	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - _shake_decay * delta)
		var a := _shake_amount * intensity
		# Rounded to whole pixels: a sub-pixel offset would break the pixel grid,
		# which is the one thing a pixel-art game cannot get away with.
		_shake_target.position = _shake_origin + Vector2(
			randf_range(-a, a), randf_range(-a, a)).round()
	elif _shake_target.position != _shake_origin:
		_shake_target.position = _shake_origin

## The node that physically moves when the screen shakes.
func register_shake_target(node: Node2D) -> void:
	_shake_target = node
	_shake_origin = node.position if node else Vector2.ZERO

func register_popup_layer(node: Node) -> void:
	_popup_layer = node

## Small numbers. 2-3px for a hit, 6-9px for a boss slam or an Overload.
func shake(amount: float = 3.0, decay: float = 14.0) -> void:
	if intensity <= 0.0:
		return
	_shake_amount = maxf(_shake_amount, amount)
	_shake_decay = decay

## Freeze frames on impact. The cheapest way to make a hit land.
##
## Recovery MUST be driven by a timer with ignore_time_scale = true. The obvious
## implementation -- counting down with _process(delta) -- deadlocks the entire
## game, because delta is itself scaled by time_scale: at zero, delta is zero,
## the counter never decreases, and time_scale never comes back. That bug shipped
## once; test_hitstop_always_recovers exists so it cannot ship twice.
func hitstop(seconds: float = 0.05) -> void:
	if intensity <= 0.0:
		return
	Engine.time_scale = 0.0
	_hitstop_token += 1
	var token := _hitstop_token
	await get_tree().create_timer(seconds, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0

## Cancels any freeze and restores normal time. Called when a combat view tears
## down, so a hitstop in flight can never leak into the next screen.
func reset() -> void:
	_hitstop_token += 1
	Engine.time_scale = 1.0
	_shake_amount = 0.0
	if _shake_target and is_instance_valid(_shake_target):
		_shake_target.position = _shake_origin

## White-out on a sprite. Requires the hit_flash shader material.
func flash(node: CanvasItem, duration: float = 0.09) -> void:
	if node == null or not is_instance_valid(node):
		return
	var mat := node.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_amount", 1.0)
	var t := create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, dur(duration))

## Squash and stretch. Anticipation is what makes motion read as alive.
func pop(node: Node2D, scale_up: float = 1.18, duration: float = 0.16) -> void:
	if node == null or not is_instance_valid(node) or intensity <= 0.0:
		return
	var base: Vector2 = node.get_meta("base_scale", node.scale)
	node.set_meta("base_scale", base)
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base * scale_up, dur(duration) * 0.35)
	t.tween_property(node, "scale", base, dur(duration) * 0.65)

## Anticipation nudge: pull back, then strike. Used for enemy attacks.
func lunge(node: Node2D, direction: Vector2, distance: float = 14.0, duration: float = 0.26) -> void:
	if node == null or not is_instance_valid(node) or intensity <= 0.0:
		return
	var base: Vector2 = node.get_meta("base_pos", node.position)
	node.set_meta("base_pos", base)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(node, "position", base - direction * distance * 0.4, dur(duration) * 0.35) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", base + direction * distance, dur(duration) * 0.2) \
		.set_ease(Tween.EASE_IN)
	t.tween_property(node, "position", base, dur(duration) * 0.45).set_ease(Tween.EASE_OUT)

## Floating combat number.
func popup(text: String, color: Color, world_pos: Vector2, scale_up: float = 1.0) -> void:
	if _popup_layer == null or not is_instance_valid(_popup_layer):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", int(18 * scale_up))
	l.position = world_pos + Vector2(randf_range(-10, 10), 0)
	l.z_index = 100
	_popup_layer.add_child(l)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 44, dur(0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE * 1.25, dur(0.12)).set_trans(Tween.TRANS_BACK)
	t.chain().tween_property(l, "scale", Vector2.ONE, dur(0.1))
	t.chain().tween_property(l, "modulate:a", 0.0, dur(0.28))
	t.chain().tween_callback(l.queue_free)

## Scales a duration by the player's animation speed preference.
func dur(base: float) -> float:
	return base / maxf(0.05, speed_scale)
