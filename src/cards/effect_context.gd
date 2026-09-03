class_name EffectContext
extends RefCounted
## Everything a CardEffect needs to resolve. Passed down the effect array so
## effects can read the same targets and write back shared scratch values
## (e.g. damage dealt, for lifesteal-style follow-ups).

var combat            ## Combat
var source            ## Combatant who played/triggered this
var targets: Array = []  ## Array[Combatant]
var card: Card = null
var upgraded: bool = false
var scratch: Dictionary = {}

func _init(p_combat, p_source, p_targets: Array = [], p_card: Card = null) -> void:
	combat = p_combat
	source = p_source
	targets = p_targets
	card = p_card
	upgraded = p_card.upgraded if p_card else false

func primary_target():
	return targets[0] if not targets.is_empty() else null
