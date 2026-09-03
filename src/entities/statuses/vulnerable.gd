class_name VulnerableStatus
extends StatusEffect
## Takes 50% more attack damage. Multiplicative, applied on the RECEIVING side.

const MULTIPLIER := 1.5

func _init() -> void:
	id = &"vulnerable"
	display_name = "Defense Down"
	description = "Defense fell. Takes 50% more damage from attacks."
	is_debuff = true
	decays_at_turn_end = true
	apply_order = 10

func modify_incoming_damage(amount: float, ctx) -> float:
	if ctx.get("is_attack", true):
		return amount * MULTIPLIER
	return amount
