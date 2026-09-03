class_name CardLibrary
extends RefCounted
## Loads every card definition from data/cards/*.json into CardData resources.

const CARD_DIR := "res://data/cards/"

static var _cards: Dictionary = {}   ## StringName -> CardData
static var _loaded := false

static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_cards.clear()
	var dir := DirAccess.open(CARD_DIR)
	if dir == null:
		push_error("CardLibrary: cannot open %s" % CARD_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		_load_file(CARD_DIR + file)
	_loaded = true

static func _load_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("CardLibrary: empty or unreadable %s" % path)
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("CardLibrary: %s must contain a JSON array" % path)
		return
	for entry in parsed:
		var c := from_dict(entry as Dictionary)
		if c:
			if _cards.has(c.id):
				push_error("CardLibrary: duplicate card id '%s' in %s" % [c.id, path])
			_cards[c.id] = c

static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = StringName(d.get("id", ""))
	if c.id == &"":
		push_error("CardLibrary: card with no id: %s" % d)
		return null
	c.title = String(d.get("title", String(c.id).capitalize()))
	c.text = String(d.get("text", ""))
	c.cost = int(d.get("cost", 1))
	c.upgraded_cost = int(d.get("upgraded_cost", -99))
	c.type = EffectFactory._enum_of(CardData.Type, d.get("type", "ATTACK"))
	c.target = EffectFactory._enum_of(CardData.Target, d.get("target", "ENEMY"))
	c.rarity = EffectFactory._enum_of(CardData.Rarity, d.get("rarity", "COMMON"))
	c.exhaust = bool(d.get("exhaust", false))
	c.ethereal = bool(d.get("ethereal", false))
	c.innate = bool(d.get("innate", false))
	c.retain = bool(d.get("retain", false))
	c.overload_bonus = bool(d.get("overload_bonus", false))
	c.element = Element.from_string(d.get("element", "NORMAL"))
	c.tm = bool(d.get("tm", false))
	c.contact = bool(d.get("contact", false))
	c.effects = EffectFactory.build_list(d.get("effects", []))
	c.upgraded_effects = EffectFactory.build_list(d.get("upgraded_effects", []))
	return c

static func get_card(id: StringName) -> CardData:
	load_all()
	return _cards.get(id)

static func all() -> Array:
	load_all()
	return _cards.values()

## Cards eligible to appear as combat rewards.
## What a fight can teach you: level-up moves only. TMs are excluded, so combat
## rewards and the opening draft stay inside Charmander's own movepool.
static func draftable() -> Array:
	return all().filter(func(c: CardData):
		return not c.tm and c.rarity in [
			CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE])

## What a shop or an event can offer: everything draftable, plus the TMs. This
## is the only route to an off-type move, and therefore the only route to a deck
## that can answer a bad matchup.
static func purchasable() -> Array:
	return all().filter(func(c: CardData):
		return c.rarity in [
			CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE])

static func tms() -> Array:
	return all().filter(func(c: CardData): return c.tm)

static func make(id: StringName, upgraded: bool = false) -> Card:
	var data := get_card(id)
	if data == null:
		push_error("CardLibrary.make: unknown card '%s'" % id)
		return null
	return Card.new(data, upgraded)
