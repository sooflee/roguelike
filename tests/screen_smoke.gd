extends Control
## Drives the meta screens headlessly: map, event, reward, shop, campfire,
## treasure and the potion pickers, and fails on any error.
##
## Same reasoning as view_smoke.gd, applied to the other half of the game. The
## rules suite proves gold is spent and potions are capped; it would pass just
## as happily while the screen that spends them threw on every draw. Every
## screen here is walked with a run state chosen to hit its awkward branch --
## a full potion belt, a destitute purse, a fully upgraded deck.

const RUN_SCREEN := preload("res://src/ui/run_screen.gd")

var screen: Node
var _screens := 0
var _empty := 0
var _steps: Array[Callable] = []
var _bench: RunState              ## reused; regenerating a map per assertion is 105 nodes a time
var _starting_deck: Array[StringName] = []

func _ready() -> void:
	Juice.intensity = 0.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RunState.delete_save()
	screen = RUN_SCREEN.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)          # _ready() builds chrome and shows the title
	# This suite poses each screen directly; the title would sit over all of
	# them with the chrome hidden underneath.
	screen._close_title()

	_bench = RunState.new_run(9001)
	for c in _bench.deck:
		_starting_deck.append(c.data.id)

	_steps.append(_walk_draft)
	_steps.append(_walk_map)
	# Every event, every choice, against a run that can afford everything and
	# then against one that can afford nothing.
	for flush in [true, false]:
		for e in EventLibrary.all():
			_steps.append(_walk_event.bind(e, flush))
	for step in [_walk_rewards, _walk_potions, _walk_shop, _walk_campfire,
			_walk_treasure, _walk_endings]:
		_steps.append(step)

## One walk per frame. `_clear_body()` frees with queue_free(), which only takes
## effect between frames; running the whole suite inside _ready() would leave
## thousands of live nodes behind and drown a genuine leak in the noise.
func _process(_delta: float) -> void:
	if _steps.is_empty():
		_done()
		return
	_steps.pop_front().call()

# --- helpers ---------------------------------------------------------------

## Records that a screen drew something. A screen that renders no controls at
## all is a dead end the player cannot leave, so it counts as a failure.
func _check(label: String) -> void:
	_screens += 1
	# ENABLED, not merely present. A screen whose every control is greyed out is
	# a dead end the player cannot leave, and counting disabled buttons let a
	# campfire at full HP with a fully upgraded deck pass as healthy.
	if _buttons().is_empty():
		_empty += 1
		printerr("    screen '%s' rendered no button the player can press" % label)
	# Every label on screen being blank means the text never made it to the
	# control -- which is invisible to a button-counting check, and is exactly
	# how the whole meta UI once shipped with no prose on it at all.
	var labels := 0
	var blank := 0
	for c in screen._body.get_children():
		if c is RichTextLabel and not c.is_queued_for_deletion():
			labels += 1
			if (c as RichTextLabel).text.strip_edges().is_empty():
				blank += 1
	if labels > 0 and blank == labels:
		_empty += 1
		printerr("    screen '%s' drew %d labels and every one of them is blank" % [label, labels])

## The live buttons currently on screen, in order.
##
## Two traps here. Labels are interleaved with buttons, so child position is not
## button position. And `_clear_body()` frees with queue_free(), so the PREVIOUS
## screen's buttons are still children until the frame ends -- pressing one of
## those clicks a screen the player already left.
## Body controls plus the persistent action bar. Exit actions (Leave, Back,
## Continue, Skip) deliberately live outside the scrolling body so they cannot
## fall below the fold, so a check that only reads the body sees a dead end
## where the player sees a perfectly reachable button.
func _buttons(include_disabled: bool = false) -> Array:
	var out: Array = []
	for parent in [screen._body, screen._actions]:
		for c in parent.get_children():
			if c is Button and not c.is_queued_for_deletion() \
					and (include_disabled or not c.disabled):
				out.append(c)
	return out

## Asserts a screen actually says the thing it is supposed to say. Button
## presence proves a screen works; only its prose proves it communicates.
func _expect_text(fragment: String, where: String) -> void:
	for c in screen._body.get_children():
		if c is RichTextLabel and (c as RichTextLabel).text.contains(fragment):
			return
	printerr("    screen '%s' never says '%s'" % [where, fragment])
	_empty += 1

## Clicks a card in the first CardPicker on screen. The shop, the forge and the
## removal service stopped being lists of buttons when they became shelves of
## cards, and a button-only walker cannot reach any of their real choices.
func _pick_card(index: int, where: String) -> bool:
	var picker := _picker()
	if picker == null:
		printerr("    screen '%s' has no card shelf to pick from" % where)
		_empty += 1
		return false
	if index >= picker._views.size():
		printerr("    screen '%s' shelf has %d cards, wanted #%d"
			% [where, picker._views.size(), index])
		_empty += 1
		return false
	picker._take(picker._views[index])
	return true

func _picker() -> CardPicker:
	for c in screen._body.get_children():
		if c is CardPicker and not c.is_queued_for_deletion():
			return c
	return null

func _shelf() -> ItemShelf:
	for c in screen._body.get_children():
		if c is ItemShelf and not c.is_queued_for_deletion():
			return c
	return null

## Drives a UI action the way a keyboard would, without touching global input.
func _send(control: Control, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	control._gui_input(ev)

## An ending must say what happened and offer a way onward. Both live in the
## EndingView, so neither the button count nor the label scan reaches them.
func _check_ending(where: String, fragment: String) -> void:
	_screens += 1
	var view = screen._ending_view
	if view == null or not is_instance_valid(view):
		printerr("    %s drew no ending view" % where)
		_empty += 1
		return
	var said := false
	var pressable := false
	for c in view.get_children():
		if c is Label and (c as Label).text.contains(fragment):
			said = true
		if c is Button and not (c as Button).disabled:
			pressable = true
	if not said:
		printerr("    %s never says '%s'" % [where, fragment])
		_empty += 1
	if not pressable:
		printerr("    %s offers no way to start again" % where)
		_empty += 1

func _card_picker() -> CardPicker:
	for c in screen._body.get_children():
		if c is CardPicker and not c.is_queued_for_deletion():
			return c
	return null

func _press(index: int, what: String) -> bool:
	var buttons := _buttons()
	var i := index if index >= 0 else buttons.size() + index
	if i < 0 or i >= buttons.size():
		printerr("    %s: no button at index %d (%d enabled)" % [what, index, buttons.size()])
		_empty += 1
		return false
	buttons[i].pressed.emit()
	return true

# --- walks -----------------------------------------------------------------

## The pre-run draft has to end. A picker that re-offers forever, or one that
## takes a card without adding it, both leave the player unable to start.
func _walk_draft() -> void:
	screen.run = RunState.new_run(6161)
	var before: int = screen.run.deck.size()
	screen._show_opening_draft(RUN_SCREEN.OPENING_PICKS)
	for pick in RUN_SCREEN.OPENING_PICKS:
		_check("opening draft pick %d" % (pick + 1))
		var picker := _card_picker()
		if picker == null:
			printerr("    opening draft drew no card row on pick %d" % (pick + 1))
			_empty += 1
			return
		picker.card_chosen.emit(picker._views[0].card)
	if screen.run.deck.size() != before + RUN_SCREEN.OPENING_PICKS:
		printerr("    opening draft added %d cards, expected %d" % [
			screen.run.deck.size() - before, RUN_SCREEN.OPENING_PICKS])
		_empty += 1
	if screen.screen != RUN_SCREEN.Screen.MAP:
		printerr("    opening draft did not hand over to the map when it ran out of picks")
		_empty += 1

func _walk_map() -> void:
	screen._show_map()
	_check("map")

## Rewinds the shared run to a known state. Events never touch the map, so the
## expensive half is reused rather than regenerated for each of the ~80 checks.
func _bench_run(flush: bool) -> RunState:
	_bench.deck.clear()
	for id in _starting_deck:
		_bench.deck.append(CardLibrary.make(id))
	_bench.potions.clear()
	_bench.max_hp = RunState.STARTING_HP
	if flush:
		_bench.gold = 999
		_bench.hp = _bench.max_hp
	else:
		# Nothing to spend, nothing to upgrade, nowhere to put a potion, and one
		# HP -- the state most likely to leave an event with no legal answer.
		_bench.gold = 0
		_bench.hp = 1
		for c in _bench.deck:
			c.upgrade()
		while _bench.add_potion(ItemLibrary.get_potion(&"fire_potion")):
			pass
	return _bench

func _walk_event(e: Dictionary, flush: bool) -> void:
	var id: String = e.get("id", "?")
	screen.run = _bench_run(flush)
	screen.current_event = e
	screen._show_event()
	_check("event:%s" % id)
	# A run that can afford nothing must still be offered a way out.
	if not flush and _buttons().is_empty():
		printerr("    event '%s' offered a destitute run nothing to click" % id)
		_empty += 1
	for i in (e.get("choices", []) as Array).size():
		screen.run = _bench_run(flush)
		screen._resolve_event(i)
		_check("event:%s/%d" % [id, i])

func _walk_rewards() -> void:
	for kind in ["normal", "elite", "boss"]:
		screen.run = RunState.new_run(2468)
		screen._show_rewards(kind)
		_check("reward:%s" % kind)
		# Taking a card must not leave the screen broken. The choice is a row of
		# real cards now, not a button, so pressing buttons here would only ever
		# exercise "Skip".
		screen.run = RunState.new_run(2468)
		screen._show_rewards(kind)
		var picker := _card_picker()
		if picker == null:
			printerr("    reward:%s drew no card picker" % kind)
			_empty += 1
		else:
			var before: int = screen.run.deck.size()
			picker.card_chosen.emit(picker._views[0].card)
			if screen.run.deck.size() != before + 1:
				printerr("    reward:%s clicking a card did not add it to the deck" % kind)
				_empty += 1
		_check("reward:%s/taken" % kind)

		# And again with the keyboard only. Making the reward choice visual
		# removed the mouse-free path to it; this is what stops it regressing.
		screen.run = RunState.new_run(2468)
		screen._show_rewards(kind)
		var keyed := _card_picker()
		if keyed == null or keyed._views.size() < 2:
			printerr("    reward:%s has no card row to drive by keyboard" % kind)
			_empty += 1
		else:
			keyed.grab_focus()
			var wanted: Card = keyed._views[1].card
			_send(keyed, "ui_right")
			var before2: int = screen.run.deck.size()
			_send(keyed, "ui_accept")
			if screen.run.deck.size() != before2 + 1:
				printerr("    reward:%s keyboard accept took no card" % kind)
				_empty += 1
			elif screen.run.deck.back().data.id != wanted.data.id:
				printerr("    reward:%s keyboard took the wrong card" % kind)
				_empty += 1

func _walk_potions() -> void:
	# A found potion with a full belt is the branch that only exists because
	# potions can be discarded; walk both answers.
	for discard_held in [true, false]:
		var run: RunState = RunState.new_run(1357)
		while run.add_potion(ItemLibrary.get_potion(&"fire_potion")):
			pass
		screen.run = run
		screen._clear_body()
		screen._offer_potion(ItemLibrary.get_potion(&"blood_potion"))
		_check("potion offer")
		# first button discards a held potion, last leaves the new one behind
		if not _press(0 if discard_held else -1, "potion offer"):
			continue
		# Counting slots is not enough -- both answers leave the belt full. What
		# separates them is whether the found potion is on it.
		var took := run.potions.any(func(x: PotionData): return x.id == &"blood_potion")
		if took != discard_held:
			printerr("    full belt, %s: blood_potion held=%s, expected %s" % [
				"discarded a held potion" if discard_held else "left it behind",
				took, discard_held])
			_empty += 1
		if run.potions.size() != RunState.POTION_SLOTS:
			printerr("    belt held %d potions after resolving, expected %d"
				% [run.potions.size(), RunState.POTION_SLOTS])
			_empty += 1

	screen.run = RunState.new_run(1357)
	screen.run.add_potion(ItemLibrary.get_potion(&"fire_potion"))
	screen._show_potion_picker()
	_check("potion picker")
	_press(0, "potion picker")   # discard the only potion
	if not screen.run.potions.is_empty():
		printerr("    discarding from the picker left the potion in place")
		_empty += 1

func _walk_shop() -> void:
	for gold in [999, 0]:
		screen.run = RunState.new_run(1122)
		screen.run.gold = gold
		screen._show_shop()
		_check("shop:%dg" % gold)
		screen._show_removal_picker()
		_check("removal picker:%dg" % gold)
		var deck_before: int = screen.run.deck.size()
		if gold >= 999 and _pick_card(0, "removal picker") \
				and screen.run.deck.size() != deck_before - 1:
			printerr("    paying for a removal removed nothing")
			_empty += 1
		screen._render_shop()
		# The shelves themselves, which are where the shop's real choices live.
		if screen._shop_card_count() > 0 and _picker() == null:
			printerr("    shop:%dg has cards for sale and no shelf to buy from" % gold)
			_empty += 1
		var shelf := _shelf()
		if shelf != null:
			for i in shelf.entries.size():
				# Every tile must say what it is, or the shop is a row of blanks.
				if String(shelf.entries[i].get("title", "")).is_empty():
					printerr("    shop:%dg shelf tile %d has no name" % [gold, i])
					_empty += 1
		if gold >= 999:
			var gold_before: int = screen.run.gold
			if _pick_card(0, "shop:%dg" % gold) and screen.run.gold >= gold_before:
				printerr("    buying a move cost nothing")
				_empty += 1
			_check("shop/after buying")

func _walk_campfire() -> void:
	screen.run = RunState.new_run(3344)
	screen._show_campfire()
	_check("campfire")
	screen._show_upgrade_picker()
	_check("upgrade picker")
	# Upgrading must not break the picker, and the preview must vanish with it.
	# Shift swaps every card to its upgraded face and back. A preview that does
	# not restore leaves the player looking at a deck they do not own.
	var picker := _picker()
	if picker != null and not picker._views.is_empty():
		var face_before: String = picker._views[0].card.describe()
		picker.set_previewing(true)
		if picker._views[0].card.describe() == face_before:
			printerr("    holding Shift changed nothing on the forge shelf")
			_empty += 1
		picker.set_previewing(false)
		if picker._views[0].card.describe() != face_before:
			printerr("    releasing Shift did not restore the card")
			_empty += 1
	screen._show_upgrade_picker()
	_pick_card(0, "upgrade picker")
	_check("campfire/upgraded")
	if screen.run.deck.filter(func(c: Card): return c.upgraded).is_empty():
		printerr("    the smith upgraded nothing")
		_empty += 1
	# A deck with nothing left to upgrade must still render the campfire.
	screen.run = RunState.new_run(3344)
	for c in screen.run.deck:
		c.upgrade()
	screen._show_campfire()
	_check("campfire/fully upgraded")
	for c in screen.run.deck:
		if (c as Card).describe().strip_edges().is_empty():
			printerr("    starting card '%s' had no text" % (c as Card).title())
			_empty += 1
			break

func _walk_treasure() -> void:
	screen.run = RunState.new_run(5566)
	screen._show_treasure()
	_check("treasure")

func _walk_endings() -> void:
	# The endings own the whole frame now, so their controls and prose live in
	# an EndingView rather than in the scrolling body.
	screen.run = RunState.new_run(7788)
	screen._show_game_over()
	_check_ending("game over", "FAINTED")
	screen.run = RunState.new_run(7788)
	screen._show_run_complete()
	_check_ending("run complete", "CHAMPION")

func _done() -> void:
	print("\n====================================================")
	print("  screen smoke: %d screens walked, %d empty" % [_screens, _empty])
	print("====================================================")
	get_tree().quit(1 if _empty > 0 else 0)
