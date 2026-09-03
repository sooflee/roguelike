class_name StrengthStatus
extends StatusEffect
## Flat additive bonus to attack damage. Can go negative.

func _init() -> void:
	id = &"strength"
	display_name = "Attack"
	description = "Attack rose. Deal %d more damage per attack."
	is_debuff = false

func modify_outgoing_damage(amount: float, _ctx) -> float:
	return amount + float(stacks)
