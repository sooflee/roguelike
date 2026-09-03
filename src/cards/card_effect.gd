class_name CardEffect
extends Resource
## Base class for a single composable card behaviour.
##
## Effects mutate combat state IMMEDIATELY and push VisualEvents. They must
## never await, never call into the view layer, and never read node state --
## that is what keeps combat headlessly testable.

## Amount added to the effect's magnitude when the card is upgraded.
@export var upgrade_bonus: int = 0

func execute(_ctx: EffectContext) -> void:
	push_error("CardEffect.execute() not implemented in %s" % get_script().resource_path)

## Human-readable fragment used to generate card text and tooltips.
##
## `card` is the CardData the effect belongs to, or null when an effect is
## described outside a card (enemy moves). It is needed because an effect alone
## cannot know who it hits: a `damage` effect in TARGETS mode reads "Deal 6
## damage" on a single-target card and "Deal 6 damage to ALL enemies" on a
## sweeping one, and only the card knows which.
func describe(_upgraded: bool, _card: CardData = null) -> String:
	return ""

## Names who an effect hits, as a suffix (" to ALL enemies") or "" when the
## target is the obvious single enemy. Shared so damage and status text on the
## same card cannot drift apart.
static func scope_phrase(card: CardData) -> String:
	if card == null:
		return ""
	match card.target:
		CardData.Target.ALL_ENEMIES:
			return " to ALL enemies"
		CardData.Target.RANDOM_ENEMY:
			return " to a random enemy"
		_:
			return ""

func value_for(base: int, upgraded: bool) -> int:
	return base + (upgrade_bonus if upgraded else 0)
