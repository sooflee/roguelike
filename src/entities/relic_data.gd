class_name RelicData
extends Resource
## A permanent passive modifier held for the whole run.
##
## Relics reuse the CardEffect system rather than introducing a second one: a
## relic that says "at the start of combat, Ramp 2" is literally the same
## RampPPEffect a card would use. Flat modifiers that no effect can express
## (a higher PP ceiling, a discounted first card) are plain fields applied
## by Combat.

enum Rarity { STARTER, COMMON, UNCOMMON, RARE, BOSS, SHOP, EVENT }

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""
@export var rarity: Rarity = Rarity.COMMON

## Applied once, when the relic is picked up.
@export var bonus_max_hp: int = 0

## Applied every combat.
## Raises both the ramp's starting point and its ceiling.
@export var bonus_max_pp: int = 0
@export var bonus_card_draw: int = 0
## The first card played each turn costs 1 less PP.
@export var discounts_first_card: bool = false
## Extra HP healed when resting at a campfire.
@export var bonus_rest_heal: int = 0

@export var on_combat_start: Array[CardEffect] = []
@export var on_turn_start: Array[CardEffect] = []

@export var icon: Texture2D
