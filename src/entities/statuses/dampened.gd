class_name DampenedStatus
extends StatusEffect
## Debuff: your Overload debt stops paying itself down.
##
## The one status that attacks the class mechanic rather than the numbers. Debt
## normally drains a point a turn no matter what you do, which makes a greedy
## turn survivable by simply waiting. Dampened removes waiting as an answer:
## whatever you borrowed stays on the books until you kill the source or write
## it off yourself, which is the moment Quench stops being a spare Block card.
##
## It decays on its own so it is a window to play around, not a death sentence.

func _init() -> void:
	id = &"dampened"
	display_name = "Stall"
	description = "Your Overload does not pay down at the start of your turn."
	is_debuff = true
	decays_at_turn_end = true
