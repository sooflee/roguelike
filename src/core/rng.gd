extends Node
## Seeded RNG with independent named streams.
##
## Every consumer of randomness gets its own stream. This is not a nicety:
## if the map generator and the combat shuffler share a stream, then drawing
## one extra card changes the map, runs stop being reproducible, and seeded
## bug reports become worthless. Streams must stay independent.

const STREAMS := [&"map", &"shuffle", &"rewards", &"shop", &"events", &"enemy_ai", &"cosmetic"]

var seed_value: int = 0
var _streams: Dictionary = {}

func _ready() -> void:
	if seed_value == 0:
		randomize_seed()

func randomize_seed() -> void:
	set_seed(randi())

func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_streams.clear()
	for name in STREAMS:
		var r := RandomNumberGenerator.new()
		# Hash the stream name into the seed so streams differ but stay deterministic.
		r.seed = hash("%d:%s" % [new_seed, name])
		_streams[name] = r

## Returns the RandomNumberGenerator for a named stream.
func stream(name: StringName) -> RandomNumberGenerator:
	assert(_streams.has(name), "Unknown RNG stream: %s" % name)
	return _streams[name]

func randi_range_in(name: StringName, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)

func randf_in(name: StringName) -> float:
	return stream(name).randf()

## Fisher-Yates using the named stream. Godot's Array.shuffle() uses the global
## RNG, which would silently break determinism -- never use it here.
func shuffle_in(name: StringName, arr: Array) -> void:
	var r := stream(name)
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func pick_in(name: StringName, arr: Array):
	if arr.is_empty():
		return null
	return arr[stream(name).randi_range(0, arr.size() - 1)]

## --- persistence ---------------------------------------------------------
## Saves the seed plus each stream's cursor. Restoring only the seed would rewind
## every stream to the start of the run, so a reloaded save would re-roll rewards
## the player has already seen.
func save_state() -> Dictionary:
	var states := {}
	for name in STREAMS:
		states[String(name)] = str(_streams[name].state)
	return {"seed": str(seed_value), "streams": states}

func load_state(d: Dictionary) -> void:
	# Only reseed if the save actually carries one. An absent or truncated rng
	# block used to mean set_seed(0), which silently re-derived every stream
	# from the constant 0 -- identical rewards, shops and enemy rolls for
	# everyone who loaded such a file, while the header still showed the run's
	# real seed. RunState has already seeded from the top-level save seed.
	if d.has("seed"):
		set_seed(int(str(d["seed"])))
	var states: Dictionary = d.get("streams", {})
	for name in STREAMS:
		if states.has(String(name)):
			_streams[name].state = int(str(states[String(name)]))

## Picks `count` distinct elements without mutating the source array.
func sample_in(name: StringName, arr: Array, count: int) -> Array:
	var pool := arr.duplicate()
	shuffle_in(name, pool)
	return pool.slice(0, mini(count, pool.size()))
