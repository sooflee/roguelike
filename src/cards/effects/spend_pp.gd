class_name SpendPPEffect
extends CardEffect
## Converts leftover PP into damage or Block at a fixed rate. The cash-out:
## a full curve you have nothing to spend on becomes a payoff instead of waste.

enum Payout { DAMAGE, BLOCK }

@export var max_spend: int = 5
@export var per_pp: int = 2
@export var payout: Payout = Payout.DAMAGE

func execute(ctx: EffectContext) -> void:
	if not (ctx.source is Player):
		return
	var spent: int = ctx.source.drain_pp(value_for(max_spend, ctx.upgraded))
	if spent <= 0:
		return
	var magnitude := spent * per_pp
	if payout == Payout.BLOCK:
		ctx.source.gain_block(magnitude)
	else:
		for target in ctx.targets:
			if target and target.is_alive():
				target.take_damage(ctx.source.calculate_damage(magnitude, target, true), ctx.source)

func describe(upgraded: bool, _card: CardData = null) -> String:
	var cap := value_for(max_spend, upgraded)
	# "Remaining", because combat.gd spends the card's own cost first: Vent at
	# 5 PP pays 1 for itself and cashes out 4, not 5.
	var head := "Spend your remaining PP." if cap >= Player.PP_CAP \
		else "Spend up to %d of your remaining PP." % cap
	if payout == Payout.BLOCK:
		return "%s Gain %d Block per PP spent." % [head, per_pp]
	return "%s Deal %d damage per PP spent." % [head, per_pp]
