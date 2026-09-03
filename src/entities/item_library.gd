class_name ItemLibrary
extends RefCounted
## Loads relics and potions from data/. Kept separate from CardLibrary so the
## draft pool and the reward pools can never accidentally contaminate each other.

const RELIC_DIR := "res://data/relics/"
const POTION_DIR := "res://data/potions/"

static var _relics: Dictionary = {}
static var _potions: Dictionary = {}
static var _loaded := false

static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_relics.clear()
	_potions.clear()
	_read(RELIC_DIR, _relics, _relic_from_dict)
	_read(POTION_DIR, _potions, _potion_from_dict)
	_loaded = true

static func _read(dir_path: String, target: Dictionary, builder: Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path + file))
		if typeof(parsed) != TYPE_ARRAY:
			push_error("ItemLibrary: %s must contain a JSON array" % file)
			continue
		for entry in parsed:
			var built = builder.call(entry as Dictionary)
			if built:
				if target.has(built.id):
					push_error("ItemLibrary: duplicate id '%s' in %s" % [built.id, file])
				target[built.id] = built

static func _relic_from_dict(d: Dictionary) -> RelicData:
	var r := RelicData.new()
	r.id = StringName(d.get("id", ""))
	if r.id == &"":
		return null
	r.title = String(d.get("title", String(r.id).capitalize()))
	r.text = String(d.get("text", ""))
	r.rarity = EffectFactory._enum_of(RelicData.Rarity, d.get("rarity", "COMMON"))
	r.bonus_max_hp = int(d.get("bonus_max_hp", 0))
	r.bonus_max_pp = int(d.get("bonus_max_pp", 0))
	r.discounts_first_card = bool(d.get("discounts_first_card", false))
	r.bonus_card_draw = int(d.get("bonus_card_draw", 0))
	r.bonus_rest_heal = int(d.get("bonus_rest_heal", 0))
	r.on_combat_start = EffectFactory.build_list(d.get("on_combat_start", []))
	r.on_turn_start = EffectFactory.build_list(d.get("on_turn_start", []))
	return r

static func _potion_from_dict(d: Dictionary) -> PotionData:
	var p := PotionData.new()
	p.id = StringName(d.get("id", ""))
	if p.id == &"":
		return null
	p.title = String(d.get("title", String(p.id).capitalize()))
	p.text = String(d.get("text", ""))
	p.rarity = EffectFactory._enum_of(PotionData.Rarity, d.get("rarity", "COMMON"))
	p.target = EffectFactory._enum_of(CardData.Target, d.get("target", "SELF"))
	p.effects = EffectFactory.build_list(d.get("effects", []))
	return p

static func get_relic(id: StringName) -> RelicData:
	load_all()
	return _relics.get(id)

static func get_potion(id: StringName) -> PotionData:
	load_all()
	return _potions.get(id)

static func all_relics() -> Array:
	load_all()
	return _relics.values()

static func all_potions() -> Array:
	load_all()
	return _potions.values()

## Relics that can appear as rewards -- starter relics are excluded.
static func droppable_relics() -> Array:
	return all_relics().filter(func(r: RelicData): return r.rarity != RelicData.Rarity.STARTER)
