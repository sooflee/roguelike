class_name StarterView
extends Control
## A small animated Pokemon, playing its sprite strip.
##
## The battle view animates strips through EntityView, but that class is bound
## to a Combatant and a health bar. The title and death screens need the same
## motion with none of the fight attached.

const CELL := 96

## Holds one frame and stops the bob. A fainted Pokemon should not be playing
## its idle animation.
var still := false
## Applied to the SPRITE, not to this Control. A Control turns about its
## top-left corner, so rotating the panel swings the sprite off across the
## screen instead of tipping it over where it stands.
## Shifts the sprite within its Control. Set it to the negative of the art's
## offset inside its cell and the ART centres, rather than the mostly-empty
## cell centring around it.
var content_offset := Vector2.ZERO:
	set(v):
		content_offset = v
		_place()

var sprite_rotation := 0.0:
	set(v):
		sprite_rotation = v
		_place()

var _sprite: Sprite2D
var _frames := 1
var _frame := 0
var _time := 0.0
var _bob := 0.0

func setup(texture: Texture2D, scale_to: float = 3.0) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_frames = maxi(1, texture.get_width() / maxi(1, texture.get_height()))
	if _frames > 1:
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(0, 0, texture.get_height(), texture.get_height())
	_sprite.scale = Vector2(scale_to, scale_to)
	add_child(_sprite)
	_place()
	resized.connect(_place)
	set_process(true)

## Where the sprite sits when it is not bobbing.
##
## Also called from setup(), because _process() returns early under reduce
## motion (Juice.intensity 0) -- and it was _process() that positioned the
## sprite. With motion off it was never placed at all and sat centred on this
## Control's top-left corner.
func _place() -> void:
	if _sprite == null:
		return
	_sprite.position = Vector2(size.x * 0.5, size.y * 0.5) + content_offset
	_sprite.rotation = sprite_rotation

func _process(delta: float) -> void:
	if _sprite == null or still or Juice.intensity <= 0.0:
		return
	_time += delta
	_bob += delta
	_sprite.position = Vector2(size.x * 0.5, size.y * 0.5 + roundf(sin(_bob * 1.6) * 3.0)) \
		+ content_offset
	if _frames <= 1:
		return
	if _time < 1.0 / 12.0:
		return
	_time = 0.0
	_frame = (_frame + 1) % _frames
	var cell := _sprite.region_rect.size.y
	_sprite.region_rect = Rect2(float(_frame) * cell, 0.0, cell, cell)
