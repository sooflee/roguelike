extends Node
## Every sound the game makes, behind one call: `Audio.play(&"hit")`.
##
## The same shape as Juice (D-23): one autoload owning a whole layer of feel, so
## "the game sounds wrong" is a tuning session in one file rather than an
## archaeology expedition. And the same shape as PlaceholderArt (D-22): a cue
## resolves to `assets/audio/sfx/<cue>.ogg` if that file exists, so swapping the
## library out later is a file drop, not a code change.
##
## Deliberately fire-and-forget. Nothing here may block, await, or be waited on
## by the simulation -- audio is presentation, and D-13 says presentation never
## holds the rules up.

const SFX_DIR := "res://assets/audio/sfx/"
## Cues that would otherwise machine-gun: repeated hits inside one animation
## frame, or a full hand being dealt. Re-triggering inside this window is
## dropped rather than layered.
const RETRIGGER_GUARD := 0.045

## 0.0 silences everything, the same escape hatch Juice.intensity gives motion.
var volume: float = 0.7
var muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _last_played: Dictionary = {}

func _ready() -> void:
	# A small pool, so overlapping cues layer instead of cutting each other off.
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func play(cue: StringName, pitch: float = 1.0, gain: float = 1.0) -> void:
	if muted or volume <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(cue, -99.0)) < RETRIGGER_GUARD:
		return
	var stream := _stream_for(cue)
	if stream == null:
		return
	_last_played[cue] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	# A little variation each time, or the tenth hit in a fight sounds like a
	# copy of the first.
	p.pitch_scale = clampf(pitch + randf_range(-0.06, 0.06), 0.3, 2.5)
	p.volume_db = linear_to_db(clampf(volume * gain, 0.0001, 1.0))
	p.play()

func _stream_for(cue: StringName) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = SFX_DIR + String(cue) + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[cue] = stream
	return stream

## Which cues resolve to a real file. Used by the tests: a cue that silently
## resolves to nothing is indistinguishable from one that plays, and would only
## be noticed by someone listening.
func has_cue(cue: StringName) -> bool:
	return _stream_for(cue) != null
