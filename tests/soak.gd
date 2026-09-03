extends Control
## Self-play soak. Drives the REAL animated combat view through many fights and
## checks, every time the view goes idle, that what is on screen still agrees
## with what the simulation believes.
##
## D-13 says the simulation never waits for the view. The cost of that trade is
## that the two can silently drift apart -- the sim can be perfectly right while
## the gauge shows a stale number, a played card leaves a view behind, or an
## animation never finishes and the player is stuck looking at a dead screen.
## None of those corrupt a save, which is exactly why none of them fail a rules
## test. They are found here or by a player.
##
## This is a BUG hunt, not a balance run: it reports defects, not win rates.

const COMBAT_VIEW := preload("res://src/ui/combat_view.gd")

## Frames the view may stay busy before we call the animation stuck. Generous:
## at speed 8 a long sequence is well under this.
const STUCK_LIMIT := 900
const MAX_FIGHTS := 14
## Per-fight and whole-run frame budgets. A soak that can hang is a soak nobody
## runs, so a stall is converted into a reported defect and the walk continues.
const FIGHT_FRAMES := 3000
const TOTAL_FRAMES := 40000
const FRAME := 960.0
const FRAME_H := 540.0

var run: RunState
var view: Control
var combat: Combat

var _fights := 0
var _actions := 0
var _busy := 0
var _checks := 0
var _idle_ticks := 0
var _queue: Array = []
var _defects: Dictionary = {}       ## kind -> first example, so one bug is one line
var _node_samples: Array[int] = []
var _drags := 0
var _fight_frames := 0
var _total_frames := 0

func _ready() -> void:
	Juice.speed_scale = 20.0   # animations still run, just not in real time
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Every encounter kind, several seeds each: the point is coverage of the
	# view's branches (deaths, multi-enemy layouts, powers, potions), not of any
	# one fight.
	for seed_value in [31337, 4242, 99]:
		for kind in ["easy", "normal", "elite", "boss"]:
			for entry in EnemyLibrary.encounters_of_kind(kind):
				_queue.append({"seed": seed_value, "encounter": StringName(entry.get("id", ""))})
	_next_fight()

func _next_fight() -> void:
	if _queue.is_empty() or _fights >= MAX_FIGHTS:
		_done()
		return
	var job: Dictionary = _queue.pop_front()
	Rng.set_seed(job["seed"])
	run = RunState.new_run(job["seed"])
	# Salt the deck so ramp, overload, powers, exhaust and potions all animate.
	for id in ["ember_jab", "vent", "stoke", "kindling", "afterburn", "immolate",
			"bellows", "last_ember", "quench", "temper", "crucible"]:
		run.add_card(CardLibrary.make(StringName(id)))
	run.add_potion(ItemLibrary.get_potion(&"fire_potion"))
	run.add_potion(ItemLibrary.get_potion(&"block_potion"))

	if view:
		view.queue_free()
	view = COMBAT_VIEW.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	var enemies := EnemyLibrary.encounter(job["encounter"])
	var p := Player.new("Charmander", run.max_hp)
	p.hp = run.hp
	combat = Combat.new(p, enemies, run.deck, run.relics)
	view.begin(combat, run)
	_fights += 1
	_busy = 0
	_fight_frames = 0
	print("  fight %d/%d  %s (seed %d)" % [_fights, MAX_FIGHTS, job["encounter"], job["seed"]])

func _defect(kind: String, detail: String) -> void:
	if not _defects.has(kind):
		_defects[kind] = detail
		printerr("    DEFECT [%s] %s" % [kind, detail])

# --- the invariants --------------------------------------------------------

## Only ever called when the view is idle. Mid-animation the two are SUPPOSED to
## disagree -- that is the whole point of the queue -- so checking then would
## just produce noise.
func _check_idle_agreement() -> void:
	_checks += 1
	var p: Player = combat.player

	var g = view._gauge
	if g.pp != p.pp or g.max_pp != p.max_pp or g.cap != p.pp_cap or g.overload != p.overload:
		_defect("gauge desync", "gauge shows %d/%d cap %d overload %d, sim has %d/%d cap %d overload %d" % [
			g.pp, g.max_pp, g.cap, g.overload, p.pp, p.max_pp, p.pp_cap, p.overload])

	# home_pos is in HandView space; the fan node itself may be offset.
	var _hand_offset: Vector2 = view._hand.global_position
	var views: Array = view._hand.views
	if views.size() != combat.hand.size():
		_defect("hand view leak", "%d card views for %d cards in hand" % [views.size(), combat.hand.size()])
	for card in combat.hand:
		if view._hand.find_for(card) == null:
			_defect("card without a view", "%s is in hand with nothing drawn for it" % card.title())
	var seen := {}
	for entry in views:
		var v: CardView = entry
		var label: String = v.card.title() if v.card else "<null>"
		if v.card != null and seen.has(v.card):
			_defect("duplicate card view", "two views drawn for %s" % label)
		seen[v.card] = true
		if not combat.hand.has(v.card):
			_defect("orphan card view", "a view is still drawn for %s, which left the hand" % label)
		# A card whose RULES TEXT is off screen is a card the player cannot read,
		# which is as bad as one they cannot see. Check the whole card rect, not
		# just its centre: the fan droops its outer cards well below the centre,
		# and centre-only bounds happily passed a hand clipped by the frame.
		# home_pos is the slot the fan settled the card into, not wherever it
		# happens to be mid-flight. Cards are dealt from a draw pile anchored
		# below the frame edge on purpose, so checking the live position would
		# just flag every card in transit.
		var home: Vector2 = v.home_pos + _hand_offset
		var half := Vector2(CardView.W, CardView.H) * 0.5
		if home.x - half.x < 0.0 or home.x + half.x > FRAME \
				or home.y - half.y < 0.0 or home.y + half.y > FRAME_H:
			_defect("card clipped by frame", "%s settles spanning %s..%s, outside the %dx%d frame" % [
				label, home - half, home + half, int(FRAME), int(FRAME_H)])

	for e in combat.living_enemies():
		var found := false
		for ev in view._enemy_views:
			if ev.combatant == e:
				found = true
		if not found:
			_defect("living enemy not drawn", "%s is alive with no view" % e.display_name)

	if not combat.event_queue.is_empty():
		_defect("undrained events", "%d events left on the queue while idle" % combat.event_queue.size())

	if p.pp < 0 or p.max_pp > p.pp_cap or p.overload < 0:
		_defect("pp out of range", "pp %d max %d cap %d overload %d" % [
			p.pp, p.max_pp, p.pp_cap, p.overload])

# --- driving ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if combat == null or view == null:
		return
	_total_frames += 1
	_fight_frames += 1
	if _total_frames > TOTAL_FRAMES:
		_defect("soak overran", "hit the global %d frame budget" % TOTAL_FRAMES)
		_done()
		return
	if _fight_frames > FIGHT_FRAMES:
		_defect("fight stalled", "fight %d ran %d frames without finishing (turn %d, state %d, playing %s)" % [
			_fights, _fight_frames, combat.turn, combat.state, view._playing])
		_next_fight()
		return

	if view._playing:
		_busy += 1
		if _busy > STUCK_LIMIT:
			_defect("stuck animation", "view stayed busy %d frames in fight %d" % [_busy, _fights])
			view._playing = false        # break out so the soak keeps covering ground
			_busy = 0
		return
	_busy = 0

	if combat.result != Combat.Result.ONGOING:
		_check_idle_agreement()
		_node_samples.append(get_tree().get_node_count())
		_next_fight()
		return

	if combat.state != Combat.State.PLAYER_ACTION:
		return

	_idle_ticks += 1
	_check_idle_agreement()

	# Potions occasionally, so the potion path animates too.
	if _actions % 17 == 0 and run and not run.potions.is_empty():
		var pot: PotionData = run.potions[0]
		view._drink(pot, combat.living_enemies().front() if not combat.living_enemies().is_empty() else null)
		_actions += 1
		return

	for card in combat.hand.duplicate():
		if combat.can_play(card):
			var living := combat.living_enemies()
			# Alternate between the two ways a player can actually play a card.
			# Calling _play_card directly would leave the whole drag path -- the
			# one most people will use -- covered by nothing at all.
			if _actions % 3 == 0 and _try_drag(card):
				_actions += 1
				return
			view._play_card(card, living.front() if not living.is_empty() else null)
			_actions += 1
			return
	view._on_end_turn()
	_actions += 1
	if combat.turn > 40:
		_defect("combat never ends", "fight %d passed 40 turns" % _fights)
		_next_fight()

## Plays a card the way a mouse does: press it, carry it past the slop
## threshold, drop it on an enemy (or on the board, if it needs no target).
func _try_drag(card: Card) -> bool:
	var v = view._hand.find_for(card)
	if v == null:
		return false
	var start: Vector2 = v.global_position
	var drop: Vector2
	if card.data.needs_target():
		var living := combat.living_enemies()
		if living.is_empty():
			return false
		var target_view = null
		for ev in view._enemy_views:
			if ev.combatant == living.front():
				target_view = ev
		if target_view == null:
			return false
		drop = target_view.global_position
	else:
		drop = Vector2(480, 300)          # the board, above DROP_LINE

	view._begin_drag(v, start)
	view._drag_to(start + Vector2(0, -90))   # past DRAG_SLOP, so it becomes a drag
	view._drag_to(drop)
	view._end_drag(drop)
	# Whether THIS card left the hand -- not whether the hand shrank. Kindle is
	# "Ramp 1. Draw 1 card", so it replaces itself and the hand size never moves.
	if combat.hand.has(card):
		_defect("drag did not play",
			"%s (target=%s cost=%d) dropped at %s and stayed in hand; playable=%s pp=%d/%d"
			% [card.title(), CardData.Target.keys()[card.data.target], card.cost(), drop,
				combat.can_play(card), combat.player.pp, combat.player.max_pp])
		return false
	_drags += 1
	return true

func _done() -> void:
	# Node count is sampled at the end of each fight, when the previous view has
	# been freed. A steady climb means the view is leaving nodes behind.
	if _node_samples.size() >= 4:
		var first: int = _node_samples[1]
		var last: int = _node_samples[_node_samples.size() - 1]
		if last > first * 2:
			_defect("node leak", "node count grew %d -> %d across %d fights" % [
				first, last, _node_samples.size()])

	print("\n====================================================")
	print("  soak: %d fights, %d actions (%d by drag), %d idle checks" % [
		_fights, _actions, _drags, _checks])
	if _drags == 0:
		_defect("drag never exercised", "no card was played by dragging")
	print("  defect kinds: %d" % _defects.size())
	for kind in _defects:
		print("    %-26s %s" % [kind, _defects[kind]])
	print("====================================================")
	get_tree().quit(1 if _defects.size() > 0 else 0)
