class_name GainBlockEffect
extends CardEffect
## Grants Block to the source (or to every enemy, for enemy moves).

@export var amount: int = 5
@export var to_targets: bool = false

func execute(ctx: EffectContext) -> void:
	var n := value_for(amount, ctx.upgraded)
	var recipients := ctx.targets if to_targets else [ctx.source]
	for r in recipients:
		if r and r.is_alive():
			r.gain_block(n)

func describe(upgraded: bool, card: CardData = null) -> String:
	var n := value_for(amount, upgraded)
	if to_targets:
		return "Give %d Block%s." % [n, scope_phrase(card)]
	return "Gain %d Block." % n
