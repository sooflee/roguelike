class_name DealDamageEffect
extends CardEffect
## Deals attack damage. Runs the full status pipeline via Combatant.calculate_damage.

enum TargetMode { TARGETS, ALL_ENEMIES, RANDOM_ENEMY, SELF }

@export var amount: int = 6
@export var hits: int = 1
@export var target_mode: TargetMode = TargetMode.TARGETS
## Ignores Block. Used by self-damage and a few boss moves.
@export var bypass_block: bool = false
## Whether this damage makes contact. Cards carry it on CardData, but an enemy
## move has no card -- Tackle and Bite are contact moves and were animating as
## a 14px nudge because nothing could say so.
@export var contact: bool = false

func execute(ctx: EffectContext) -> void:
	var base := value_for(amount, ctx.upgraded)
	var total := 0
	var element := _element(ctx)
	# Announced once per card, not once per hit: a four-hit move should not
	# shout "super effective" four times.
	var announced := false
	var makes_contact := contact \
		or (ctx.card != null and ctx.card.data != null and ctx.card.data.contact)
	for target in _resolve_targets(ctx):
		if target == null or not target.is_alive():
			continue
		# Announced once per card rather than once per hit: a four-hit move
		# should not shout "super effective" four times.
		if not announced and element >= 0:
			announced = true
			var bonus := Element.bonus(element, target.element)
			if bonus != 0:
				ctx.combat.push_event(VisualEvent.EFFECTIVENESS, {
					"who": target, "super": bonus > 0, "bonus": bonus})
		for _i in hits:
			if not target.is_alive():
				break
			var dmg: int = ctx.source.calculate_damage(base, target, true, element)
			total += target.take_damage(dmg, ctx.source, bypass_block, element, makes_contact)
	ctx.scratch["damage_dealt"] = int(ctx.scratch.get("damage_dealt", 0)) + total

## The move's type, or untyped when this damage has no card behind it -- an
## enemy move, a relic, self-damage. Untyped damage skips the chart rather than
## defaulting to Normal, which would silently halve it against Rock.
func _element(ctx: EffectContext) -> int:
	if ctx.card != null and ctx.card.data != null:
		return ctx.card.data.element
	return -1

func _resolve_targets(ctx: EffectContext) -> Array:
	match target_mode:
		TargetMode.ALL_ENEMIES:
			return ctx.combat.living_enemies()
		TargetMode.RANDOM_ENEMY:
			var living: Array = ctx.combat.living_enemies()
			var pick = Rng.pick_in(&"enemy_ai", living)
			return [pick] if pick else []
		TargetMode.SELF:
			return [ctx.source]
		_:
			return ctx.targets

func describe(upgraded: bool, card: CardData = null) -> String:
	var n := value_for(amount, upgraded)
	var who := ""
	match target_mode:
		TargetMode.ALL_ENEMIES:
			who = " to ALL enemies"
		TargetMode.RANDOM_ENEMY:
			who = " to a random enemy"
		TargetMode.SELF:
			who = " to yourself"
		_:
			who = scope_phrase(card)
	if hits > 1:
		return "Deal %d damage %d times%s." % [n, hits, who]
	return "Deal %d damage%s." % [n, who]
