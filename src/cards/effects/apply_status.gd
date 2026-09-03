class_name ApplyStatusEffect
extends CardEffect
## Applies stacks of a registered status to targets or to self.

@export var status_id: StringName = &"vulnerable"
@export var stacks: int = 1
@export var to_self: bool = false

func execute(ctx: EffectContext) -> void:
	var proto := StatusRegistry.get_status(status_id)
	if proto == null:
		push_error("Unknown status id: %s" % status_id)
		return
	var n := value_for(stacks, ctx.upgraded)
	var recipients := [ctx.source] if to_self else ctx.targets
	for r in recipients:
		if r and r.is_alive():
			r.apply_status(proto, n)

func describe(upgraded: bool, card: CardData = null) -> String:
	var n := value_for(stacks, upgraded)
	var proto := StatusRegistry.get_status(status_id)
	if proto == null:
		return "Apply %d %s." % [n, String(status_id)]
	# A power the player has no shorthand for spells itself out; a keyword the
	# player already knows is named, the way Spire writes "Apply 2 Vulnerable".
	if not proto.is_keyword:
		return proto.description % n
	# For a decaying status, `stacks` is DURATION, not magnitude: Weak always
	# costs 25% of damage whatever the count, and simply sheds one stack a turn.
	# Printing "Apply 2 Attack Down" invited the player to read 2 as strength.
	if proto.decays_at_turn_end:
		var turns := "1 turn" if n == 1 else "%d turns" % n
		# "Apply" leads, so the sentence has a verb and still reads correctly
		# when a conditional clause lowercases its first word.
		if to_self:
			return "Apply %s to yourself for %s." % [proto.display_name, turns]
		return "Apply %s%s for %s." % [proto.display_name, scope_phrase(card), turns]
	if to_self:
		return "Gain %d %s." % [n, proto.display_name]
	return "Apply %d %s%s." % [n, proto.display_name, scope_phrase(card)]
