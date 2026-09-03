extends Control
## Plays a whole run to the end, through the REAL screens.
##
## Everything else tests a slice: the rules suite walks the map with no UI, the
## screen smoke visits each screen in isolation, the soak drives combat alone.
## None of them proves the thing a player actually cares about -- that you can
## start a run, walk every stage, fight the boss and be told you won.
##
## Two modes:
##   default  -- combats are resolved with the dev shortcut (D-26), which still
##               goes through the real event queue and handoff. Fast; proves the
##               path between screens.
##   `--play` -- every fight is actually FOUGHT through the animated combat view,
##               card by card. Slow, but it is the only thing that walks the
##               game the way a player does, start to boss.
##
## `--shots` writes a PNG of every distinct screen to user:// so the whole run
## can be looked at rather than reasoned about. Needs a real window; headless
## cannot render.

const RUN_SCREEN := preload("res://src/ui/run_screen.gd")
const SHOT_DIR := "user://run_shots/"

var screen: Node
var _frames := 0
var _stages := 0
var _combats := 0
var _rewards := 0
var _cards_taken := 0
var _really_play := false
var _shooting := false
var _shots := 0
var _turns := 0
var _busy_for := 0
var _problems := 0
var _finished := false
var _last := ""
var _seed := 0
## Map rows the run actually stood on, which is what "stages" means.
var _rows_seen := {}

func _ready() -> void:
	Juice.intensity = 0.0
	Juice.speed_scale = 20.0
	Dev.enable()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_really_play = args.has("--play")
	_shooting = args.has("--shots")
	for a in args:
		if a.begins_with("--seed="):
			_seed = int(a.substr(7))
	if _shooting:
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RunState.delete_save()
	screen = RUN_SCREEN.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	# The run seed is random by default, and that is the point -- a fixed map
	# only ever proves the one path through it. `--seed=N` replays the map a
	# failure came from; _done() prints the seed of every run for that reason.
	if _seed != 0:
		# Past the title, or _process() would press Start and roll a fresh seed
		# over the one being replayed.
		screen._close_title()
		screen.run = RunState.new_run(_seed)
		screen._show_map()

func _fail(msg: String) -> void:
	# Tagged so tools/test.sh's summary grep surfaces the reason. Without the
	# tag the suite printed a bare "problems: 2" and swallowed both messages.
	printerr("  DEFECT %s" % msg)
	_problems += 1

func _live_buttons() -> Array:
	var out: Array = []
	for parent in [screen._body, screen._actions]:
		for c in parent.get_children():
			if c is Button and not c.disabled and not c.is_queued_for_deletion():
				out.append(c)
	return out

func _process(_delta: float) -> void:
	if _finished:
		return
	_frames += 1
	if _frames > (60000 if _really_play else 9000):
		_fail("ran out of frames on screen %s after %d stages" % [_last, _stages])
		_done()
		return

	# The game boots on the title, so the walk starts by opening the front door.
	# Pressing Start rather than reaching past it: the title is now part of the
	# path a player takes, so it is part of the path this proves.
	if screen._title_view != null and is_instance_valid(screen._title_view):
		screen._title_view.new_run_requested.emit()
		return

	# A fight is up.
	if screen._combat_panel != null and is_instance_valid(screen._combat_panel):
		var view = screen._combat_panel
		if view._playing:
			_busy_for += 1
			if _busy_for > 1200:
				_fail("combat view stuck mid-animation on stage %d" % _stages)
				view._playing = false
				_busy_for = 0
			return
		_busy_for = 0
		if view.combat == null:
			return
		if view.combat.result != Combat.Result.ONGOING:
			if view._continue_btn != null and view._continue_btn.visible:
				view._continue_btn.pressed.emit()
			return
		if not _really_play:
			_combats += 1
			view._on_dev_win()
			return
		if _turns == 0 and combat_started_now(view):
			_combats += 1
		_fight(view)
		return

	# Count the rows the run stands on, not the number of times the map screen
	# comes up. _stages counted the latter and was compared against
	# MapGenerator.STAGES, so the act-length check passed on a coincidence and
	# would not have noticed the act being a stage short.
	if screen.run != null and screen.run.current_node != null:
		_rows_seen[screen.run.current_node.row] = true

	var here: int = screen.screen
	var name: String = RUN_SCREEN.Screen.keys()[here]
	if name != _last:
		_last = name
		_turns = 0
		if _shooting:
			_snap("%s_stage%d" % [name.to_lower(), _stages])
		if here == RUN_SCREEN.Screen.MAP:
			_stages += 1
		elif here == RUN_SCREEN.Screen.REWARD:
			_rewards += 1

	if here == RUN_SCREEN.Screen.RUN_COMPLETE:
		print("  reached the end of the act after %d stages" % _stages)
		_done()
		return
	if here == RUN_SCREEN.Screen.GAME_OVER:
		_fail("died before the boss, at stage %d" % _stages)
		_done()
		return

	# The map is driven through the map view, not through buttons: its docked
	# list of node buttons was removed, and clicking a node is what a player
	# actually does.
	if here == RUN_SCREEN.Screen.MAP and screen._map_view != null \
			and is_instance_valid(screen._map_view) \
			and not screen._map_view.available.is_empty():
		screen._map_view.node_chosen.emit(screen._map_view.available[0])
		return

	# Every screen must offer something to press, or the run is stuck.
	var buttons := _live_buttons()
	if buttons.is_empty():
		_fail("screen %s offers nothing the player can press" % name)
		_done()
		return
	# Prefer a real card over the Skip button, so the reward choice is actually
	# exercised rather than declined every single time.
	for c in screen._body.get_children():
		if c is CardPicker and not c.is_queued_for_deletion():
			# A picker nobody listens to is a display, not a choice, and a locked
			# card is a price this run cannot pay. Neither advances anything, so a
			# walk that fires card_chosen at them sits on the same screen taking
			# the same card 8,000 times until it runs out of frames -- which is
			# exactly what it did on the forge's "sharpened" confirmation, and
			# again on a shop whose whole shelf was out of reach.
			if c.card_chosen.get_connections().is_empty():
				continue
			var open: Array = c.takeable()
			if open.is_empty():
				continue
			_cards_taken += 1
			# Through _take(), not the bare signal: that is the path a real click
			# follows, lock check and all.
			c._take(open[0])
			return
	# Otherwise take the first live option. A dumb policy is the point: it proves
	# the path exists rather than that a clever one can be found.
	buttons[0].pressed.emit()

## Plays one action of a real fight: anything affordable, else end the turn.
## Deliberately greedy and stupid -- the point is to walk the whole game, not to
## win cleverly.
## True on the first action of a fight, so fights are counted once.
func combat_started_now(view) -> bool:
	if view.combat == null or view.combat.turn != 1:
		return false
	if _counted_fight == view.combat:
		return false
	_counted_fight = view.combat
	return true

var _counted_fight = null

func _fight(view) -> void:
	var combat = view.combat
	if combat.state != Combat.State.PLAYER_ACTION:
		return
	if _shooting and _turns == 0:
		_snap("combat_%02d_turn1" % _stages)
	for card in combat.hand.duplicate():
		if combat.can_play(card):
			var living: Array = combat.living_enemies()
			view._play_card(card, living.front() if not living.is_empty() else null)
			return
	view._on_end_turn()
	_turns += 1
	if combat.turn > 60:
		_fail("fight on stage %d never ended" % _stages)
		view._on_dev_win()

func _snap(name: String) -> void:
	if not _shooting:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [SHOT_DIR, _shots, name])
	_shots += 1

func _done() -> void:
	_finished = true
	var stops := 0
	for r in _rows_seen:
		if r >= 0:          # -1 is the entrance, which is not a stage
			stops += 1
	_stages = stops        # report what was walked, not how often the map came up
	if stops < MapGenerator.STAGES:
		_fail("walked %d of %d stages" % [stops, MapGenerator.STAGES])
	if _combats == 0:
		_fail("never actually fought anything")
	print("\n====================================================")
	print("  playthrough: %d stages, %d fights, %d rewards, %d cards drafted%s" % [
		_stages, _combats, _rewards, _cards_taken,
		"  (fought for real)" if _really_play else ""])
	if _shooting:
		print("  wrote %d screenshots to %s" % [_shots, ProjectSettings.globalize_path(SHOT_DIR)])
	print("  problems: %d   (--seed=%d to replay this map)"
		% [_problems, screen.run.seed_value if screen.run != null else 0])
	print("====================================================")
	get_tree().quit(1 if _problems > 0 else 0)
