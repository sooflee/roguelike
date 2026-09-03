class_name PotionData
extends Resource
## A one-shot consumable. Playable at any point during the player's turn and
## costs no PP -- that is the whole reason potions exist as a safety valve.

enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var target: CardData.Target = CardData.Target.SELF
@export var effects: Array[CardEffect] = []
@export var icon: Texture2D

func needs_target() -> bool:
	return target == CardData.Target.ENEMY

func base_price() -> int:
	return [50, 75, 100][rarity]
