class_name AfterburnStatus
extends StatusEffect
## Power: whenever you Overload, deal damage to a random enemy.
## Turns borrowing itself into a damage source -- the payoff that makes the
## debt half of the class worth drafting rather than merely survivable.

func _init() -> void:
	id = &"afterburn"
	display_name = "Backlash"
	description = "Whenever you Overload, deal %d damage to a random enemy."
	is_debuff = false
	is_keyword = false

func on_overload(owner, amount: int, combat) -> void:
	if amount <= 0 or combat == null:
		return
	var target = Rng.pick_in(&"enemy_ai", combat.living_enemies())
	if target:
		target.take_damage(owner.calculate_damage(stacks, target, false), owner)
