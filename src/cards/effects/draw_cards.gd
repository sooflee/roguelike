class_name DrawCardsEffect
extends CardEffect

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	ctx.combat.draw(value_for(amount, ctx.upgraded))

func describe(upgraded: bool, _card: CardData = null) -> String:
	var n := value_for(amount, upgraded)
	return "Draw %d card%s." % [n, "" if n == 1 else "s"]
