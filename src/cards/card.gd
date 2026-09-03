class_name Card
extends RefCounted
## A runtime instance of a CardData. Two copies of Strike in your deck are two
## Cards sharing one CardData -- upgrades and temporary modifiers live here.

var data: CardData
var upgraded: bool = false
var cost_override: int = -99  ## temporary, e.g. "costs 0 this turn"
var uid: int

static var _next_uid: int = 1

func _init(p_data: CardData, p_upgraded: bool = false) -> void:
	data = p_data
	upgraded = p_upgraded
	uid = _next_uid
	_next_uid += 1

func cost() -> int:
	if cost_override != -99:
		return cost_override
	return data.cost_when(upgraded)

func effects() -> Array[CardEffect]:
	return data.effects_when(upgraded)

func title() -> String:
	return data.title + ("+" if upgraded else "")

## Text for THIS card at its current rank -- not `data.text`, which is always
## the base rank and so lies about an upgraded card.
func describe() -> String:
	return data.describe(upgraded)

## What the text would become if upgraded; "" once it already is.
func upgrade_preview() -> String:
	return "" if upgraded else data.describe(true)

func upgrade() -> bool:
	if upgraded:
		return false
	upgraded = true
	return true

func duplicate_card() -> Card:
	var c := Card.new(data, upgraded)
	c.cost_override = cost_override
	return c

func _to_string() -> String:
	return "%s(%d)" % [title(), cost()]
