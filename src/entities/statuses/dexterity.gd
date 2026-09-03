class_name DexterityStatus
extends StatusEffect
## Flat additive bonus to block gained.

func _init() -> void:
	id = &"dexterity"
	display_name = "Defense"
	description = "Defense rose. Gain %d more Block from moves."
	is_debuff = false

func modify_block_gain(amount: float, _ctx) -> float:
	return amount + float(stacks)
