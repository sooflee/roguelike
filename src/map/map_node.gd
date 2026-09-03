class_name MapNode
extends RefCounted

enum Kind { COMBAT, ELITE, EVENT, SHOP, CAMPFIRE, TREASURE, BOSS, DRAFT }

var row: int = 0
var col: int = 0
var kind: Kind = Kind.COMBAT
var next: Array[MapNode] = []
var prev: Array[MapNode] = []
var encounter_id: StringName = &""
var visited: bool = false

func _init(p_row: int, p_col: int) -> void:
	row = p_row
	col = p_col

## What this kind of stop is, in one line. Lives here because two different
## views need it: the drawn map's hover tooltip and run_screen's keyboard
## fallback buttons. It used to exist only on the buttons, so hovering the
## actual map -- the thing the player is looking at -- said nothing.
static func label_for(k: int) -> String:
	match k:
		Kind.COMBAT:   return "Combat"
		Kind.ELITE:    return "Elite"
		Kind.EVENT:    return "Event"
		Kind.SHOP:     return "Shop"
		Kind.CAMPFIRE: return "Campfire"
		Kind.TREASURE: return "Treasure"
		Kind.BOSS:     return "Boss"
		Kind.DRAFT:    return "Your first moves"
		_: return "?"

static func hint_for(k: int) -> String:
	match k:
		Kind.COMBAT:   return "A fight. Card reward and gold."
		Kind.ELITE:    return "A hard fight. Guaranteed relic."
		Kind.EVENT:    return "An encounter with a choice."
		Kind.SHOP:     return "Spend gold on cards, relics, potions, or removal."
		Kind.CAMPFIRE: return "Rest to heal, or upgrade a card."
		Kind.TREASURE: return "Gold, and a chance of a relic."
		Kind.BOSS:     return "Blastoise."
		Kind.DRAFT:    return "Choose the moves you set out with."
		_: return ""

func key() -> String:
	return "%d,%d" % [row, col]

func _to_string() -> String:
	return "%s@%s" % [Kind.keys()[kind], key()]
