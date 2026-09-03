class_name FrailStatus
extends StatusEffect
## Gains 25% less Block from cards.

const MULTIPLIER := 0.75

func _init() -> void:
	id = &"frail"
	display_name = "Guard Down"
	description = "Gain 25% less Block from moves."
	is_debuff = true
	decays_at_turn_end = true
	apply_order = 10

func modify_block_gain(amount: float, _ctx) -> float:
	return amount * MULTIPLIER
