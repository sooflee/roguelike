class_name SimmerStatus
extends StatusEffect
## Enemy passive: grows stronger at the end of its turn UNLESS it was damaged
## since its last one.
##
## A clock aimed squarely at turtling. Blocking everything and waiting for a
## better hand is the default line in every deckbuilder, and nothing in Act 1
## charged for it -- so a Simmering enemy makes "did I put damage on the board
## this turn?" a question the player has to answer every single turn.

func _init() -> void:
	id = &"simmer"
	display_name = "Bide"
	description = "Attack rises by %d at the end of its turn unless it was damaged."
	is_debuff = false
	is_keyword = false

func on_turn_end(owner, _combat) -> void:
	if owner.took_damage or stacks <= 0:
		return
	owner.apply_status(StatusRegistry.get_status(&"strength"), stacks)
