class_name HealEffect
extends CardEffect

@export var amount: int = 4
@export var to_targets: bool = false

func execute(ctx: EffectContext) -> void:
	var n := value_for(amount, ctx.upgraded)
	for r in (ctx.targets if to_targets else [ctx.source]):
		if r and r.is_alive():
			r.heal(n)

func describe(upgraded: bool, _card: CardData = null) -> String:
	return "Heal %d HP." % value_for(amount, upgraded)
