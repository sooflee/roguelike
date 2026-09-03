class_name RampPPEffect
extends CardEffect
## Permanently raises this combat's PP refill. Arrives at the ceiling early.
##
## Grants no PP on the turn it is played -- that cost is the whole decision.

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	if not (ctx.source is Player):
		return
	var want := value_for(amount, ctx.upgraded)
	var moved: int = ctx.source.ramp_pp(want)
	# At the ceiling there is nothing left to buy, and a Ramp card there used to
	# cost a PP, exhaust itself, and do literally nothing -- silently. Whatever
	# the ceiling could not absorb arrives as PP now instead, so a ramp card is
	# never a blank draw. Ramp stays an investment while the curve is climbing
	# and degrades into a small refund once it cannot.
	if moved < want:
		ctx.source.gain_pp(want - moved)

func describe(upgraded: bool, _card: CardData = null) -> String:
	return "Ramp %d." % value_for(amount, upgraded)
