class_name KindlingStatus
extends StatusEffect
## Power: ramp at the start of every turn. The engine for "arrive early" --
## it turns one card into a permanently steeper curve for the rest of the fight.

func _init() -> void:
	id = &"kindling"
	display_name = "Focus"
	description = "At the start of your turn, Ramp %d."
	is_debuff = false
	is_keyword = false

func on_turn_start(owner, _combat) -> void:
	if owner is Player:
		owner.ramp_pp(stacks)
