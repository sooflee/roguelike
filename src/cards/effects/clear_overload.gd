class_name ClearOverloadEffect
extends CardEffect
## Writes off borrowed PP before it comes due.

func execute(ctx: EffectContext) -> void:
	if ctx.source is Player:
		ctx.source.clear_overload()

func describe(_upgraded: bool, _card: CardData = null) -> String:
	return "Clear your Overload."
