class_name GainPPEffect
extends CardEffect
## Straight PP, no debt. Reserved for potions and relics -- a card that did
## this would just be a cheaper card.

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	if ctx.source is Player:
		ctx.source.gain_pp(value_for(amount, ctx.upgraded))

func describe(upgraded: bool, _card: CardData = null) -> String:
	return "Gain %d PP." % value_for(amount, upgraded)
