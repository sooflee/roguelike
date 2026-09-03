class_name WeakStatus
extends StatusEffect
## Deals 25% less attack damage. Applied on the DEALING side.

const MULTIPLIER := 0.75

func _init() -> void:
	id = &"weak"
	display_name = "Attack Down"
	description = "Attack fell. Deals 25% less damage with attacks."
	is_debuff = true
	decays_at_turn_end = true
	apply_order = 10

func modify_outgoing_damage(amount: float, ctx) -> float:
	if ctx.get("is_attack", true):
		return amount * MULTIPLIER
	return amount
