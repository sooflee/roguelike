class_name OverloadEffect
extends CardEffect
## Borrows PP against the future: it arrives now, and every refill from here is
## smaller until the debt is paid off -- one point a turn, so it CAN spiral.
##
## That is deliberate (D-27). Charged-once-and-cleared made this a nought-per-cent
## loan, and a loan with no interest is never a decision.

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	if ctx.source is Player:
		ctx.source.overload_pp(value_for(amount, ctx.upgraded))

func describe(upgraded: bool, _card: CardData = null) -> String:
	return "Overload %d." % value_for(amount, upgraded)
