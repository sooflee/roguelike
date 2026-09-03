class_name CardData
extends Resource
## Static definition of a card. Saved as .tres in data/cards/.
##
## Behaviour lives in `effects` -- an array of composable CardEffect resources.
## Adding a card is a data edit, not a code change. This is what makes classes
## 2 and 3 content work rather than engineering work.

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Target { ENEMY, ALL_ENEMIES, RANDOM_ENEMY, SELF, NONE }
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""

@export var type: Type = Type.ATTACK
## The move's type, for the matchup chart. Distinct from `type` above, which is
## the deckbuilder category (attack / skill / power).
@export var element: int = Element.Kind.NORMAL
## A TM move: something Charmander cannot learn by levelling, only by being
## taught. TMs are bought and found, never offered as a combat reward -- which
## is what keeps the draft faithful to the movepool while shops still supply
## the off-type cards the matchup chart needs to matter.
@export var tm: bool = false
## Whether the move makes contact, as the Pokemon games mean it: Scratch and
## Flare Blitz do, Ember and Rock Throw do not. A contact move is animated as
## the Pokemon crossing the field and striking, rather than something thrown.
@export var contact: bool = false
@export var target: Target = Target.ENEMY
@export var rarity: Rarity = Rarity.COMMON

## -1 means "unplayable" (curses/statuses); -2 means X-cost.
@export var cost: int = 1
@export var upgraded_cost: int = -99  ## -99 = unchanged by upgrade

@export var exhaust: bool = false
@export var ethereal: bool = false
@export var innate: bool = false
@export var retain: bool = false

## Marks a card that gains a bonus while you are Overloaded, so the view can
## flag it without re-walking the effect tree.
@export var overload_bonus: bool = false

@export var effects: Array[CardEffect] = []
## If empty, upgrading scales `effects` via each effect's own upgrade rules.
@export var upgraded_effects: Array[CardEffect] = []

@export var art: Texture2D

func cost_when(upgraded: bool) -> int:
	if upgraded and upgraded_cost != -99:
		return upgraded_cost
	return cost

func effects_when(upgraded: bool) -> Array[CardEffect]:
	if upgraded and not upgraded_effects.is_empty():
		return upgraded_effects
	return effects

## Card text generated from the effects themselves.
##
## This exists so an UPGRADED card can be rendered before it exists -- for the
## preview on the reward and campfire screens, and for an already-upgraded card
## in hand, which would otherwise show its base `text` while dealing upgraded
## damage. `text` stays the authored copy; a test asserts the two agree for
## every card at base rank, and that agreement is what makes the generated
## upgraded text trustworthy.
func describe(upgraded: bool) -> String:
	var parts: Array[String] = []
	for e in effects_when(upgraded):
		var frag := e.describe(upgraded, self)
		if frag != "":
			parts.append(frag)
	parts.append_array(keywords())
	return " ".join(parts)

## Card-level rules that no single effect owns, in the order they read on a card.
func keywords() -> Array[String]:
	var out: Array[String] = []
	if innate:
		out.append("Innate.")
	if ethereal:
		out.append("Ethereal.")
	if retain:
		out.append("Retain.")
	if exhaust:
		out.append("Exhaust.")
	return out

func is_playable_type() -> bool:
	return type != Type.STATUS and type != Type.CURSE

func needs_target() -> bool:
	return target == Target.ENEMY
