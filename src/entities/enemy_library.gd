class_name EnemyLibrary
extends RefCounted
## Loads enemy definitions and encounter tables from data/.

const ENEMY_DIR := "res://data/enemies/"
const ENCOUNTER_DIR := "res://data/encounters/"

static var _enemies: Dictionary = {}
static var _encounters: Dictionary = {}
static var _loaded := false

static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_enemies.clear()
	_encounters.clear()
	_read_into(ENEMY_DIR, _enemies, "id")
	_read_into(ENCOUNTER_DIR, _encounters, "id")
	_loaded = true

static func _read_into(dir_path: String, target: Dictionary, key: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path + file))
		if typeof(parsed) != TYPE_ARRAY:
			push_error("EnemyLibrary: %s must contain a JSON array" % file)
			continue
		for entry in parsed:
			target[StringName(entry.get(key, ""))] = entry

static func spawn(id: StringName) -> Enemy:
	load_all()
	var d: Dictionary = _enemies.get(id, {})
	if d.is_empty():
		push_error("EnemyLibrary: unknown enemy '%s'" % id)
		return null
	var hp_range = d.get("hp", [10, 10])
	var hp := Rng.randi_range_in(&"enemy_ai", int(hp_range[0]), int(hp_range[1]))
	var e := Enemy.new(id, String(d.get("name", String(id).capitalize())), hp)
	e.element = Element.from_string(d.get("element", "NORMAL"))
	e.height_m = float(d.get("height_m", 0.6))
	e.moves = d.get("moves", [])
	e.opening = d.get("opening", [])
	e.passives = EffectFactory.build_list(d.get("passives", []))
	e.passive_text = String(d.get("passive_text", ""))
	# Starting Block, so a shell already has its guard up on turn one rather than
	# being free to hit exactly once before its passive ever fires.
	e.block = int(d.get("block", 0))
	# Passives the player reads as a status rather than as behaviour.
	for spec in d.get("statuses", []):
		var proto := StatusRegistry.get_status(StringName(spec.get("id", "")))
		if proto == null:
			push_error("EnemyLibrary: %s has unknown status '%s'" % [id, spec.get("id", "")])
			continue
		e.apply_status(proto, int(spec.get("stacks", 1)))
	return e

static func encounter(id: StringName) -> Array[Enemy]:
	load_all()
	var d: Dictionary = _encounters.get(id, {})
	var out: Array[Enemy] = []
	for eid in d.get("enemies", []):
		var e := spawn(StringName(eid))
		if e:
			out.append(e)
	return out

static func encounters_of_kind(kind: String) -> Array:
	load_all()
	return _encounters.values().filter(func(e): return String(e.get("kind", "")) == kind)
