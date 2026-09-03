class_name AddCardToPileEffect
extends CardEffect
## Shuffles a card (usually a Burn or other Status) into a pile. Powers the
## downside half of the Overload archetype.

enum Pile { DRAW, DISCARD, HAND }

@export var card_id: StringName = &"burn"
@export var count: int = 1
@export var pile: Pile = Pile.DISCARD

func execute(ctx: EffectContext) -> void:
	var data := CardLibrary.get_card(card_id)
	if data == null:
		push_error("Unknown card id: %s" % card_id)
		return
	for _i in value_for(count, ctx.upgraded):
		ctx.combat.add_card(Card.new(data), pile)

func describe(upgraded: bool, _card: CardData = null) -> String:
	var n := value_for(count, upgraded)
	var where: String = ["draw pile", "discard pile", "hand"][pile]
	return "Add %d %s to your %s." % [n, String(card_id).capitalize(), where]
