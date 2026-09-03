class_name ConditionalEffect
extends CardEffect
## Wraps child effects behind a condition. This is how Overloaded works:
## `{"type": "conditional", "condition": "overloaded", "effects": [...]}`
##
## Composition rather than a special case in the card resolver -- so new
## conditions cost one match arm, not a rewrite.

## How each condition reads on a card. Without this the generator prints the
## raw identifier -- "If at_pp_cap: ..." -- straight onto the card face.
const CONDITION_TEXT := {
	&"overloaded": "Overloaded: ",
	&"at_pp_cap": "At maximum PP: ",
	&"no_overload": "Free of debt: ",
	&"target_vulnerable": "If the enemy is Vulnerable: ",
	&"hand_empty": "If your hand is empty: ",
}

@export var condition: StringName = &"overloaded"
@export var invert: bool = false
@export var effects: Array[CardEffect] = []

func execute(ctx: EffectContext) -> void:
	var met := _evaluate(ctx)
	if invert:
		met = not met
	if not met:
		return
	for e in effects:
		e.execute(ctx)

func _evaluate(ctx: EffectContext) -> bool:
	match condition:
		&"overloaded":
			return ctx.source is Player and ctx.source.is_overloaded()
		&"at_pp_cap":
			return ctx.source is Player and ctx.source.at_pp_cap()
		&"no_overload":
			return ctx.source is Player and not ctx.source.is_overloaded()
		&"target_vulnerable":
			var t = ctx.primary_target()
			return t != null and t.has_status(&"vulnerable")
		&"hand_empty":
			return ctx.combat.hand.is_empty()
		_:
			push_error("Unknown condition: %s" % condition)
			return false

func describe(upgraded: bool, card: CardData = null) -> String:
	var parts: Array[String] = []
	for e in effects:
		var frag := e.describe(upgraded, card)
		if frag == "":
			continue
		# Reads as one sentence after the condition: "Overloaded: deal 3 damage."
		parts.append(frag.substr(0, 1).to_lower() + frag.substr(1))
	var prefix: String = CONDITION_TEXT.get(condition, "If %s: " % condition)
	return prefix + " ".join(parts)
