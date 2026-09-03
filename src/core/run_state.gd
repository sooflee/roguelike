class_name RunState
extends RefCounted
## Everything that persists across one run: deck, HP, gold, relics, potions and
## position on the map.
##
## The map itself is NOT serialised. It is regenerated from the run seed on load,
## which is only safe because map generation draws from its own RNG stream
## (see docs/DECISIONS.md D-15). Deriving it rather than storing it means a save
## file cannot disagree with the generator.

const SAVE_PATH := "user://run.json"
const SAVE_VERSION := 1

const STARTING_HP := 60
const POTION_SLOTS := 3
## Cards drafted before the first fight, one per round. A rule, not a UI
## detail: the simulation has to draft the same five or it measures a deck half
## the size of the real one.
const OPENING_DRAFT_PICKS := 5
const REST_HEAL_FRACTION := 0.3

var seed_value: int = 0
var act: int = 1
var max_hp: int = STARTING_HP
var hp: int = STARTING_HP
var gold: int = 99

var deck: Array[Card] = []
var relics: Array[RelicData] = []
var potions: Array[PotionData] = []

var map: MapGenerator = null
var current_node: MapNode = null
var visited_keys: Array[String] = []
var floors_cleared: int = 0
## Events already resolved this run, and shop removals already bought.
##
## These live here rather than on RunScreen because they are facts about the
## RUN, and the screen is rebuilt on every load. Held there they were never
## serialised: reloading reset the removal price to its base (buy two, quit,
## continue, buy two more) and re-offered events the run had already seen.
var seen_events: Array = []
var removals_used: int = 0
## Wall-clock seconds spent on this run. Accumulated by the run screen and
## saved, so quitting and continuing resumes the clock rather than restarting
## it -- a run timer that forgets is worse than none.
var elapsed_seconds: float = 0.0

## Set when a node is entered so the UI knows which screen to show.
var pending_node: MapNode = null

# --- creation --------------------------------------------------------------

static func new_run(p_seed: int = 0) -> RunState:
	var r := RunState.new()
	r.seed_value = p_seed if p_seed != 0 else randi()
	Rng.set_seed(r.seed_value)
	r.deck = RunState.starting_deck()
	var starter := ItemLibrary.get_relic(&"forge_mark")
	if starter:
		r.add_relic(starter)
	r.map = MapGenerator.new()
	r.map.generate()
	return r

static func starting_deck() -> Array[Card]:
	var d: Array[Card] = []
	# Five to start, and the opening draft adds five more before the first fight
	# (RunScreen.OPENING_PICKS). Half the deck a run begins with is therefore
	# chosen rather than given, which is the point: the starting five are the
	# floor, not the deck.
	# What a Charmander actually starts with: Scratch and Growl at level five,
	# Ember almost immediately after. Opening a run without Ember was the single
	# most obviously wrong thing about the deck.
	for _i in 2:
		d.append(CardLibrary.make(&"strike"))       # Scratch
	d.append(CardLibrary.make(&"defend"))           # Smokescreen
	d.append(CardLibrary.make(&"kindle"))           # Focus Energy
	d.append(CardLibrary.make(&"ember_jab"))        # Ember
	return d

# --- inventory -------------------------------------------------------------

func add_relic(r: RelicData) -> void:
	if r == null or has_relic(r.id):
		return
	relics.append(r)
	if r.bonus_max_hp != 0:
		max_hp += r.bonus_max_hp
		hp += r.bonus_max_hp   # Spire convention: max-HP relics heal you too

func has_relic(id: StringName) -> bool:
	for r in relics:
		if r.id == id:
			return true
	return false

func rest_heal_amount() -> int:
	var bonus := 0
	for r in relics:
		bonus += r.bonus_rest_heal
	return int(round(max_hp * REST_HEAL_FRACTION)) + bonus

func add_potion(p: PotionData) -> bool:
	if p == null or potions.size() >= POTION_SLOTS:
		return false
	potions.append(p)
	return true

## Slots are the only constraint on potions (D-21), which makes freeing one a
## real decision: without this a full belt turns every later potion into a
## non-reward.
func discard_potion(p: PotionData) -> bool:
	var i := potions.find(p)
	if i < 0:
		return false
	potions.remove_at(i)
	return true

func add_card(c: Card) -> void:
	if c:
		deck.append(c)

func remove_card(c: Card) -> bool:
	var i := deck.find(c)
	if i < 0:
		return false
	deck.remove_at(i)
	return true

func upgradeable_cards() -> Array[Card]:
	return deck.filter(func(c: Card): return not c.upgraded)

func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + amount)
	return hp - before

func lose_hp(amount: int) -> void:
	hp = maxi(0, hp - amount)

func is_dead() -> bool:
	return hp <= 0

# --- map traversal ---------------------------------------------------------

## Nodes the player may legally move to right now.
func available_nodes() -> Array:
	if map == null:
		return []
	if current_node == null:
		return map.starting_nodes()
	return current_node.next

func can_enter(node: MapNode) -> bool:
	return node != null and available_nodes().has(node)

func enter(node: MapNode) -> bool:
	if not can_enter(node):
		return false
	current_node = node
	node.visited = true
	visited_keys.append(node.key())
	pending_node = node
	return true

## Called once a node's content is finished with.
func complete_node() -> void:
	pending_node = null
	floors_cleared += 1

func is_run_complete() -> bool:
	return current_node != null and current_node.kind == MapNode.Kind.BOSS

# --- persistence -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"seed": str(seed_value),
		"act": act,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"floors_cleared": floors_cleared,
		"seen_events": seen_events,
		"removals_used": removals_used,
		"elapsed_seconds": elapsed_seconds,
		"deck": deck.map(func(c: Card): return {"id": String(c.data.id), "upgraded": c.upgraded}),
		"relics": relics.map(func(r: RelicData): return String(r.id)),
		"potions": potions.map(func(p: PotionData): return String(p.id)),
		"current_node": current_node.key() if current_node else "",
		"visited": visited_keys,
		"rng": Rng.save_state(),
	}

static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	if int(d.get("version", 0)) != SAVE_VERSION:
		push_warning("RunState: save version mismatch, loading best-effort")
	r.seed_value = int(str(d.get("seed", "0")))
	# Restore RNG cursors BEFORE regenerating the map, so the map stream is at
	# the position it held when the run started rather than mid-run.
	Rng.set_seed(r.seed_value)
	r.map = MapGenerator.new()
	r.map.generate()
	Rng.load_state(d.get("rng", {}))

	r.act = int(d.get("act", 1))
	r.max_hp = int(d.get("max_hp", STARTING_HP))
	r.hp = int(d.get("hp", r.max_hp))
	r.gold = int(d.get("gold", 0))
	r.floors_cleared = int(d.get("floors_cleared", 0))
	r.seen_events = Array(d.get("seen_events", []))
	r.removals_used = int(d.get("removals_used", 0))
	r.elapsed_seconds = float(d.get("elapsed_seconds", 0.0))

	r.deck.clear()
	for entry in d.get("deck", []):
		var c := CardLibrary.make(StringName(entry.get("id", "")), bool(entry.get("upgraded", false)))
		if c:
			r.deck.append(c)
	for rid in d.get("relics", []):
		var relic := ItemLibrary.get_relic(StringName(rid))
		if relic:
			r.relics.append(relic)   # append directly: max-HP bonus is already in the saved max_hp
	for pid in d.get("potions", []):
		var pot := ItemLibrary.get_potion(StringName(pid))
		if pot:
			r.potions.append(pot)

	for k in d.get("visited", []):
		r.visited_keys.append(String(k))
	var key := String(d.get("current_node", ""))
	if key != "":
		r.current_node = r._find_node(key)
	for vk in r.visited_keys:
		var n := r._find_node(vk)
		if n:
			n.visited = true
	return r

func _find_node(key: String) -> MapNode:
	if map == null:
		return null
	if map.boss and map.boss.key() == key:
		return map.boss
	if map.origin and map.origin.key() == key:
		return map.origin
	for row in map.rows:
		for n in row:
			if n.key() == key:
				return n
	return null

func save() -> Error:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("RunState: cannot write %s" % SAVE_PATH)
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "  "))
	f.close()
	return OK

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func load_run() -> RunState:
	if not has_save():
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunState: save file is corrupt")
		return null
	return from_dict(parsed)

static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
