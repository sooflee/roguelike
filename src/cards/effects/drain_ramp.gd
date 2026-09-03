class_name DrainRampEffect
extends CardEffect
## Eats the PP curve itself: lowers the target's refill for the rest of the
## combat, never below Player.MANA_FLOOR.
##
## The point is not the tempo it costs -- it is that Ramp suddenly has a job on
## defence. Until something could take the curve away, ramping was purely a
## greed play, and the class's signature investment had no reason to exist in a
## hand you were losing with.

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	for target in ctx.targets:
		if target is Player:
			target.drain_ramp(value_for(amount, ctx.upgraded))

func describe(upgraded: bool, _card: CardData = null) -> String:
	return "Lower their PP refill by %d." % value_for(amount, upgraded)
