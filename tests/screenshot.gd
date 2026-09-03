extends Control
## Renders the real screens and saves PNGs, so layout bugs can be SEEN rather
## than reasoned about. Run windowed (headless cannot render).

const RUN_SCREEN := preload("res://src/ui/run_screen.gd")
const COMBAT_VIEW := preload("res://src/ui/combat_view.gd")

## Where the PNGs land. Overridable so the caller picks the directory:
##   godot --path . tests/screenshot.tscn -- --out=/some/dir
## A hardcoded absolute path here rots the moment the scratchpad changes.
var _out := "user://shots/"

var _stage := 0
var _locked_shot := false
var _frames := 0
var _screen: Control
var _combat: Combat

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if not _out.ends_with("/"):
		_out += "/"
	DirAccess.make_dir_recursive_absolute(_out)
	print("shots -> ", ProjectSettings.globalize_path(_out))
	# Otherwise a save left behind by a real play session puts the title screen
	# in the shot instead of whatever was being captured.
	RunState.delete_save()
	print("=== VIEWPORT DIAGNOSTICS ===")
	print("window size        : ", DisplayServer.window_get_size())
	print("viewport size      : ", get_viewport().get_visible_rect().size)
	print("content scale size : ", get_tree().root.content_scale_size)
	print("content scale mode : ", get_tree().root.content_scale_mode)
	print("content scale aspect: ", get_tree().root.content_scale_aspect)
	print("content scale factor: ", get_tree().root.content_scale_factor)
	print("stretch (project)  : ", ProjectSettings.get_setting("display/window/stretch/mode"),
		" / ", ProjectSettings.get_setting("display/window/stretch/aspect"))
	print("my rect            : ", get_rect())
	_show_map()

func _show_map() -> void:
	_fresh_run_screen()
	# RunScreen boots to the title and _close_title() only dismisses it -- it
	# does not start anything. Without this the map shot is an empty chrome with
	# a null run, which is not a state the real game can reach.
	_screen._start_new_run()

## A RunScreen already dismissed off the title screen.
##
## RunScreen boots to the title whenever a save exists -- and stage 0's map
## screen writes one. The title hides the run chrome and sits on top of it, so
## every later shot was a picture of the title with the screen under test built
## invisibly underneath. Pose the screen before photographing it.
func _fresh_run_screen() -> void:
	if _screen: _screen.queue_free()
	_screen = RUN_SCREEN.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_screen._close_title()

func _show_combat() -> void:
	if _screen: _screen.queue_free()
	_screen = COMBAT_VIEW.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	var run := RunState.new_run(4242)
	for id in ["ember_jab", "vent", "hammer_fall", "immolate"]:
		run.add_card(CardLibrary.make(StringName(id)))
	run.add_potion(ItemLibrary.get_potion(&"fire_potion"))
	var enemies := EnemyLibrary.encounter(&"norm_imp_pack")
	var p := Player.new("Charmander", 75)
	_combat = Combat.new(p, enemies, run.deck, run.relics)
	_screen.begin(_combat, run)

func _process(_d: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames > 30:
				await _snap("01_map")
				_report_layout("map", _screen)
				_stage = 1
				_frames = 0
		1:
			_show_combat()
			_stage = 2
			_frames = 0
		2:
			if _frames > 45:
				await _snap("02_combat_start")
				_report_layout("combat", _screen)
				_stage = 3
				_frames = 0
		3:
			# Play a card so the mid-animation state is captured too.
			if _combat and _combat.state == Combat.State.PLAYER_ACTION and not _screen._playing:
				for card in _combat.hand.duplicate():
					if _combat.can_play(card):
						_screen._play_card(card, _combat.living_enemies().front())
						break
			if _frames > 26:
				await _snap("03_combat_after_play")
				_stage = 4
				_frames = 0
		4:
			if _frames > 10:
				_screen._on_end_turn()
				_stage = 5
				_frames = 0
		5:
			if _frames > 90:
				await _snap("04_after_end_turn")
				print("time_scale after end turn: ", Engine.time_scale)
				_stage = 6
		6:
			# The reward screen: the choice the whole run is about.
			_fresh_run_screen()
			_stage = 7
			_frames = 0
		7:
			if _frames > 20:
				_screen.run = RunState.new_run(2468)
				_screen._show_rewards("elite")
				_stage = 8
				_frames = 0
		8:
			if _frames > 25:
				# Parked on a stage nothing matches, first: _process() keeps
				# running while the awaits below are pending, and re-entering
				# here re-shot the reward screen every frame and then called
				# _close_deck() on whatever _screen had become by then.
				_stage = 99
				await _snap("05_reward")
				var run_screen := _screen
				# The deck overlay, over the reward screen on purpose: the whole
				# point of it being an overlay is that what is underneath is
				# still there when it closes.
				run_screen._show_deck()
				for _i in 6:
					await get_tree().process_frame
				await _snap("19_deck")
				run_screen._close_deck()
				_stage = 9
		9:
			if _screen: _screen.queue_free()
			var t := TitleView.new()
			t.setup(true)
			add_child(t)
			_screen = t
			_stage = 10
			_frames = 0
		10:
			if _frames > 30 and not _locked_shot:
				await _snap("06_title")
				# Then a LOCKED slot focused -- the only state that withholds the name,
				# and one the default shot never shows because Charmander leads the row.
				_screen._focus_on(1)
				_locked_shot = true
				_frames = 0
			elif _locked_shot and _frames > 26:
				await _snap("18_title_locked")
				_stage = 11
		11:
			_fresh_run_screen()
			_stage = 12
			_frames = 0
		12:
			if _frames > 20:
				_screen.run = RunState.new_run(6161)
				_screen._show_opening_draft(3)
				_stage = 13
				_frames = 0
		13:
			if _frames > 25:
				await _snap("07_opening_draft")
				_stage = 14
		14:
			if _frames > 12:
				_screen.run = RunState.new_run(7272)
				_screen.run.gold = 400
				_screen._show_shop()
				_stage = 15
				_frames = 0
		15:
			if _frames > 25:
				await _snap("08_shop")
				_screen.run = RunState.new_run(7272)
				_screen._show_upgrade_picker()
				_stage = 16
				_frames = 0
		16:
			if _frames > 25:
				await _snap("09_forge")
				# And the same shelf with every card flipped to its upgraded
				# face, which is the half of the comparison Shift reveals.
				for c in _screen._body.get_children():
					if c is CardPicker:
						(c as CardPicker).set_previewing(true)
				_stage = 17
				_frames = 0
		17:
			if _frames > 12:
				await _snap("10_forge_preview")
				_stage = 18
		18:
			# How the run ends is the screen a player retells. It was the only
			# major screen this harness never looked at.
			if _screen: _screen.queue_free()
			var dead := EndingView.new()
			var r := RunState.new_run(8642)
			r.floors_cleared = 5
			dead.setup(false, r)
			add_child(dead)
			_screen = dead
			_stage = 19
			_frames = 0
		19:
			if _frames > 40:
				await _snap("11_defeat")
				_stage = 20
		20:
			# Two events with different scenes, because the whole point of the
			# change is that they should no longer look like the same screen.
			_pose_event(&"the_slag_pool")
			_stage = 21
			_frames = 0
		21:
			if _frames > 30:
				await _snap("12_event_spring")
				_pose_event(&"the_long_shift")
				_stage = 22
				_frames = 0
		22:
			if _frames > 30:
				await _snap("13_event_night")
				# Four choices, which is the case that needs the plate to grow: on a
				# fixed one the last button lands on bare art below it.
				_pose_event(&"the_old_workings")
				_stage = 23
				_frames = 0
		23:
			if _frames > 30:
				await _snap("16_event_workings")
				_stage = 24
		24:
			# The card-play burst, fired deliberately and snapped a known number
			# of frames later. Catching a real card landing means guessing at
			# tween timings that move whenever the play animations are touched.
			_show_combat()
			_stage = 25
			_frames = 0
		25:
			if _frames == 30:
				_screen._fx.burst(Vector2(480, 290), Element.Kind.FIRE, 1.6)
			if _frames > 36:
				await _snap("14_card_burst")
				_stage = 26
		26:
			# A contact move mid-charge. Fired directly and snapped on a known
			# frame: catching it off a real card means guessing when the damage
			# event drains, which moves whenever the play animations are touched.
			_show_combat()
			_stage = 27
			_frames = 0
		27:
			if _frames == 30 and not _screen._enemy_views.is_empty():
				_screen._player_view.play_charge(_screen._enemy_views[0].position)
			if _frames > 60:
				await _snap("15_contact_charge")
				_stage = 28
		28:
			# The victory ending, snapped AFTER the evolution resolves. The sequence
			# is ~2.3s of alternating white silhouettes; catching it mid-flash would
			# photograph a strobe frame rather than the thing it lands on.
			if _screen: _screen.queue_free()
			var won := EndingView.new()
			var wr := RunState.new_run(1357)
			wr.floors_cleared = 7
			won.setup(true, wr)
			add_child(won)
			_screen = won
			_stage = 29
			_frames = 0
		29:
			if _frames > 420:
				await _snap("17_victory_evolution")
				_stage = 30
		30:
			print("=== done ===")
			get_tree().quit(0)

## Poses one named event. _show_event() picks at random, which is no use when
## the thing being looked at is whether a particular scene reads.
func _pose_event(id: StringName) -> void:
	_fresh_run_screen()
	_screen.run = RunState.new_run(4321)
	_screen.run.gold = 200
	_screen.current_event = EventLibrary.get_event(id)
	_screen.screen = RUN_SCREEN.Screen.EVENT
	_screen._clear_body()
	_screen._refresh_header()
	_screen._dress_event()
	_screen._centred(_screen._label("[b]%s[/b]" % _screen.current_event.get("title", "?")), 20)
	_screen._centred(_screen._label("[i]%s[/i]" % _screen.current_event.get("text", "")), 15)
	_screen._label("")
	for c in _screen.current_event.get("choices", []):
		_screen._centred_button(_screen._button("%s — %s" % [c.get("label", "..."), c.get("hint", "")],
			func(): pass))

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + name + ".png")
	print("saved %s  (%dx%d)" % [name, img.get_width(), img.get_height()])

func _report_layout(label: String, node: Control) -> void:
	print("--- layout: %s ---" % label)
	print("  root control rect: ", node.get_rect())
	for child in node.get_children():
		if child is Control:
			print("    %-22s rect=%s vis=%s" % [child.get_class() + "/" + child.name, child.get_rect(), child.visible])
		elif child is Node2D:
			print("    %-22s pos=%s vis=%s" % [child.get_class() + "/" + child.name, child.position, child.visible])
