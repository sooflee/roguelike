class_name WeatherFx
extends Control
## Weather, drawn over the battle.
##
## Sunny Day and Rain Dance are already moves in the pool, and in Pokemon they
## visibly change the field. Purely presentational for now: nothing here reads
## or writes combat state, so it can never desync the rules (D-13).

const TURNS := 5.0

var _kind: StringName = &""
var _left: float = 0.0
var _time: float = 0.0
var _drops: Array[Vector2] = []

## card id -> weather. Keyed by id, not by title, so renaming a move does not
## silently switch its weather off.
const MOVES := {
	&"forge_light": &"sun",     # Sunny Day
	&"soot_cloud": &"rain",     # Growl -- placeholder until a Rain Dance card exists
}

func _ready() -> void:
	z_index = 120
	set_process(true)
	for i in 90:
		_drops.append(Vector2(randf() * 960.0, randf() * 540.0))

func on_move(card_id: StringName) -> void:
	if not MOVES.has(card_id):
		return
	_kind = MOVES[card_id]
	_left = TURNS
	Juice.popup("SUNLIGHT" if _kind == &"sun" else "RAIN",
		Palette.SPARK if _kind == &"sun" else Palette.QUENCH_BRIGHT,
		Vector2(430, 120), 1.4)
	queue_redraw()

## Weather with nothing to expire it. The ending screen rains on a defeat and
## never calls tick_turn(), so this simply keeps raining -- which is the point:
## on that screen the weather is the mood, not a five-turn effect.
func set_weather(kind: StringName) -> void:
	_kind = kind
	_left = INF
	queue_redraw()

## Called by the view at the start of each turn, so weather runs on game time
## rather than on wall-clock seconds.
func tick_turn() -> void:
	if _left > 0.0:
		_left -= 1.0
		if _left <= 0.0:
			_kind = &""
	queue_redraw()

func _process(delta: float) -> void:
	if _kind == &"" or Juice.intensity <= 0.0:
		return
	_time += delta
	if _kind == &"rain":
		for i in _drops.size():
			var d := _drops[i]
			d.y += 620.0 * delta
			d.x -= 130.0 * delta
			if d.y > 540.0:
				d = Vector2(randf() * 1200.0, -8.0)
			_drops[i] = d
	queue_redraw()

func _draw() -> void:
	if _kind == &"":
		return
	if _kind == &"sun":
		# A warm wash plus slow diagonal shafts. Kept faint: the battle has to
		# stay the most readable thing on screen.
		draw_rect(Rect2(0, 0, 960, 540), Color(Palette.FLAME, 0.10))
		for i in 7:
			var x := fmod(float(i) * 190.0 + _time * 14.0, 1300.0) - 200.0
			draw_line(Vector2(x, -20), Vector2(x + 150.0, 560.0),
				Color(Palette.SPARK, 0.07), 26.0)
	else:
		draw_rect(Rect2(0, 0, 960, 540), Color(Palette.QUENCH_DEEP, 0.16))
		for d in _drops:
			draw_line(d, d + Vector2(-5, 22), Color(Palette.QUENCH_BRIGHT, 0.5), 1.0)
