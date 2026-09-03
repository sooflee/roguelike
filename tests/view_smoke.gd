extends Control
## Drives the animated combat view headlessly: starts a real combat, plays cards
## and ends turns on a timer, and fails on any error.
##
## The unit suite proves the RULES are right. This proves the VIEW survives
## contact with them -- every animation path, the event player, card dealing,
## death dissolves, and the win/lose handoff.

const COMBAT_VIEW := preload("res://src/ui/combat_view.gd")

var run: RunState
var view: Control
var combat: Combat
var _ticks := 0
var _actions := 0
var _fights := 0
var _errors := 0
## Fight 3 is handed to the Auto toggle instead of being driven here.
var _auto_armed_ok := false
var _auto_ticks := 0
## Latched when fight 3 is armed, and never cleared. Gating the hands-off
## branch on COMBAT_VIEW.auto_play instead would let the code under test
## disarm itself and quietly hand the wheel back -- the harness would finish
## the fight by hand and report a pass, which is what the first version of
## this check did.
var _hands_off := false

func _ready() -> void:
	Juice.speed_scale = 8.0   # run the animations fast, but actually run them
	COMBAT_VIEW.auto_play = false   # process-global now; start from a known state
	set_anchors_preset(Control.PRESET_FULL_RECT)
	run = RunState.new_run(31337)
	for id in ["ember_jab", "vent", "hammer_fall", "afterburn", "immolate", "stoke"]:
		run.add_card(CardLibrary.make(StringName(id)))
	_start_fight("norm_imp_pack")

func _start_fight(encounter: StringName) -> void:
	if view:
		view.queue_free()
	# The last fight is left to the Auto toggle. Autoplay is a setting that
	# outlives the view now, so the thing worth proving is that a FRESH
	# CombatView comes up already armed and finishes a fight with nobody
	# driving it -- the per-fight re-arming is exactly what was wrong before.
	if _fights == 2:
		COMBAT_VIEW.auto_play = true
		_hands_off = true
	view = COMBAT_VIEW.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	if COMBAT_VIEW.auto_play:
		_auto_armed_ok = view._auto_btn.button_pressed
	view.combat_finished.connect(_on_finished)
	var enemies := EnemyLibrary.encounter(encounter)
	var p := Player.new("Charmander", run.max_hp)
	p.hp = run.hp
	combat = Combat.new(p, enemies, run.deck, run.relics)
	view.begin(combat, run)
	_fights += 1

func _process(_delta: float) -> void:
	_ticks += 1
	if _ticks % 12 != 0:
		return
	if combat == null or view == null:
		return
	if combat.result != Combat.Result.ONGOING:
		if _fights < 3:
			_start_fight([&"easy_rats", &"norm_golem", &"elite_warden"][_fights % 3])
		else:
			_done()
		return
	if view._playing or combat.state != Combat.State.PLAYER_ACTION:
		return
	if _hands_off:
		# The toggle is driving, and nothing here will touch the fight again.
		# If autoplay stops, the fight stops with it and the budget below is
		# what reports that -- rather than the suite's timeout, which cannot
		# say which scene stalled or why.
		if not COMBAT_VIEW.auto_play:
			printerr("  DEFECT autoplay switched itself off mid-fight")
			_errors += 1
			_done()
			return
		_auto_ticks += 1
		if _auto_ticks > 400:
			printerr("  DEFECT autoplay armed but the turn never advanced")
			_errors += 1
			_done()
		return
	# Play anything legal; otherwise end the turn.
	for card in combat.hand.duplicate():
		if combat.can_play(card):
			var living := combat.living_enemies()
			view._play_card(card, living.front() if not living.is_empty() else null)
			_actions += 1
			return
	view._on_end_turn()
	_actions += 1
	if combat.turn > 40:
		_done()

func _on_finished(_result) -> void:
	pass

func _done() -> void:
	print("\n====================================================")
	print("  view smoke: %d fights, %d actions driven" % [_fights, _actions])
	if not _auto_armed_ok:
		printerr("  DEFECT a fresh CombatView did not come up with Auto already on")
		_errors += 1
	if _errors == 0:
		print("  autoplay: carried into a new fight and drove it unattended")
	print("  card views alive: %d   enemy views: %d" % [
		view._hand.views.size() if view else -1,
		view._enemy_views.size() if view else -1])
	print("  pp gauge: %d/%d  cap=%d  overload=%d" % [
		view._gauge.pp, view._gauge.max_pp, view._gauge.cap, view._gauge.overload])
	print("====================================================")
	get_tree().quit(1 if _errors > 0 else 0)
