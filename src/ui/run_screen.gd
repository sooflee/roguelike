extends Control
## Top-level run controller: map traversal and every node type.
##
## Grey-box like the combat screen -- buttons and text, built to be replaced in
## Phase 3. It owns RunState and constructs each Combat; the combat panel owns
## presentation only.

enum Screen { MAP, COMBAT, REWARD, EVENT, SHOP, CAMPFIRE, TREASURE, DRAFT, GAME_OVER, RUN_COMPLETE }

## Cards drafted before the run starts, one per round. The starting five are
## near-identical, so without this the first fight is the same fight for
## everyone and the player's first decision does not arrive until after it.
## Five picks means half the opening deck is chosen rather than given.
const OPENING_PICKS := RunState.OPENING_DRAFT_PICKS

const COMBAT_VIEW := preload("res://src/ui/combat_view.gd")

var run: RunState
var screen: Screen = Screen.MAP
var shop: Shop = null
var current_event: Dictionary = {}
var _pending_rewards: Array = []

var _stats: StatStrip
var _clock: Label
var _body: VBoxContainer
var _footer: RichTextLabel
var _chrome: Control
var _actions: HBoxContainer
var _relic_strip: RelicStrip
var _focus_target: Control = null
var _title_view: TitleView = null
var _ending_view: EndingView = null
var _combat_panel: Control
var _map_view: Node2D
var _event_scene: EventScene = null
var _coins: Control = null

func _ready() -> void:
	# Set once, at the top level, so every screen inherits it.
	Input.set_custom_mouse_cursor(IconArt.poke_ball(24), Input.CURSOR_ARROW, Vector2(12, 12))
	_build_chrome()
	# Always the title. TitleView.setup() already decides whether "Continue run"
	# appears, so it handles a fresh install perfectly well -- gating the whole
	# screen on a save meant the one launch that most needs a front door, the
	# very first, was the only one that never got one: the game opened on the
	# map with the starter already picked and no title in sight.
	_show_title()

# --- chrome ----------------------------------------------------------------

func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.GROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# The meta screens were a flat dark plate. They are outdoors now, like the
	# fights between them.
	var art := TextureRect.new()
	art.texture = PlaceholderArt.for_background(&"route")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	# These screens are mostly text, and text over a lit landscape is unreadable.
	# A single flat veil keeps the scene present without competing with it.
	var veil := ColorRect.new()
	veil.color = Color(Palette.GROUND, 0.72)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	# margin_left is a MarginContainer constant; setting it on a VBoxContainer is
	# silently ignored, which is why every line of text sat flush against x=0.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	add_child(pad)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	pad.add_child(root)
	_chrome = pad

	_stats = StatStrip.new()
	root.add_child(_stats)

	# Top right, outside the padded column, so it sits in the corner rather than
	# in the flow of the vitals. Anchored to the frame, not to the chrome.
	_clock = Label.new()
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-96, 10)
	_clock.size = Vector2(84, 20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_size_override("font_size", 14)
	_clock.add_theme_color_override("font_color", Palette.INK_MID)
	_clock.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_clock.add_theme_constant_override("outline_size", 4)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock)
	set_process(true)

	_relic_strip = RelicStrip.new()
	root.add_child(_relic_strip)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)

	# Exit actions live OUTSIDE the scrolling body. Inside it they sit below the
	# fold on any screen with a full shop or a large deck, and a player who
	# cannot see "Leave" is a player who cannot leave.
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	root.add_child(_actions)

	_footer = RichTextLabel.new()
	_footer.bbcode_enabled = true
	_footer.fit_content = true
	_footer.custom_minimum_size = Vector2(0, 40)
	root.add_child(_footer)

## The run clock. Counts while a run is live and stops on the title and the
## ending, where there is no run to time.
func _process(delta: float) -> void:
	if _clock == null:
		return
	var live: bool = run != null and _title_view == null and _ending_view == null
	_clock.visible = live
	if not live:
		return
	run.elapsed_seconds += delta
	var total := int(run.elapsed_seconds)
	_clock.text = "%d:%02d" % [total / 60, total % 60] if total < 3600 \
		else "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]

func _clear_body() -> void:
	_focus_target = null
	for c in _body.get_children():
		c.queue_free()
	for c in _actions.get_children():
		c.queue_free()
	# The footer carries a result for the action that just happened. Leaving it
	# up meant a green "Purchased." from a shop two nodes back was still sitting
	# under an unrelated campfire.
	_footer.text = ""
	if _map_view and is_instance_valid(_map_view):
		_map_view.queue_free()
		_map_view = null
	# Whatever row Shift was flipping is gone with the body.
	_upgrade_picker = null
	if _event_scene and is_instance_valid(_event_scene):
		_event_scene.queue_free()
		_event_scene = null
	# Coins in flight belong to the screen that threw them. Left alone they
	# rain down over whatever the player opened next.
	if _coins and is_instance_valid(_coins):
		_coins.queue_free()
		_coins = null
	# Only the dressed screens centre their exit actions, so the default has to
	# come back or the map inherits a centred "Discard an item".
	_actions.alignment = BoxContainer.ALIGNMENT_BEGIN

func _button(text: String, cb: Callable, disabled: bool = false, tip: String = "") -> Button:
	var b := Button.new()
	# First live control on a screen takes focus, so a keyboard or controller
	# always has somewhere to start rather than needing a Tab to discover.
	if not disabled and _focus_target == null:
		_focus_target = b
		b.call_deferred("grab_focus")
	b.text = text
	b.disabled = disabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.tooltip_text = tip
	# Left-aligned so name, cost and price line up down the column. Centred rows
	# put the price at a different x on every line and give the eye no edge.
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.4)
		cb.call())
	_body.add_child(b)
	return b

## A button that must never scroll out of reach: Leave, Back, Continue, Skip.
func _action_button(text: String, cb: Callable, disabled: bool = false, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(150, 34)
	b.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.4)
		cb.call())
	_actions.add_child(b)
	if not disabled and _focus_target == null:
		_focus_target = b
		b.call_deferred("grab_focus")   # keyboard and controller get a landing point
	return b

## One line for a card, read at ITS OWN rank -- `data.text` is always the base
## rank, so a deck holding an upgraded Strike would otherwise list it as dealing 6.
## The drawn map graph occupies x 200-776 (MapView.ORIGIN plus COL_X across
## seven columns). Anything the map screen puts in the body has to stay out of
## that band, or the keyboard/screen-reader fallback prints straight over the
## picture it is a fallback for.
const MAP_GUTTER := 184.0

func _dock_left(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size.x = MAP_GUTTER
	return c

func _card_line(card: Card) -> String:
	return "%s  [%d]  —  %s" % [card.title(), card.cost(), card.describe()]

## The dim second line showing what the card becomes if upgraded. Nothing is
## drawn for a card that is already upgraded.
func _upgrade_preview(card: Card) -> void:
	var preview := card.upgrade_preview()
	if preview == "":
		return
	_label("[color=%s]        ↳ %s+  [%d]  —  %s[/color]" % [
		_hex(Palette.INK_MUTED), card.data.title, card.data.cost_when(true), preview])

## BBCode needs hex, but a literal hex string anywhere is how a 32-colour
## palette quietly becomes a 200-colour one (D-08). Route them through Palette.
static func _hex(c: Color) -> String:
	return c.to_html(false)

func _label(text: String) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.custom_minimum_size = Vector2(0, 24)
	l.text = text
	_body.add_child(l)
	return l

## Matches the relic strip, which is where a held item goes to live once this
## screen is gone. Handing it over at one size and then parking it at another
## makes the player match them up by name instead of by sight.
const OBTAINED_ICON := 36.0

## One item the player just picked up, led by its picture.
##
## This used to be a sentence -- "Obtained held item: Focus Sash — At the start
## of each combat, gain 9 Block." -- so the reward arrived as prose and the icon
## was first met later, on the strip, with nothing connecting the two. The
## sprite is what they will have to recognise from then on, so it goes first and
## the words explain it rather than replace it. `kind` keeps the one distinction
## the picture cannot carry: whether this is kept or spent.
func _obtained_item(icon: Texture2D, title: String, kind: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)

	var pic := TextureRect.new()
	pic.texture = icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.custom_minimum_size = Vector2(OBTAINED_ICON, OBTAINED_ICON)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	var name_line := Label.new()
	name_line.text = title
	name_line.add_theme_font_size_override("font_size", 15)
	name_line.add_theme_color_override("font_color", Palette.BONE)
	col.add_child(name_line)

	var body_line := Label.new()
	body_line.text = "%s · %s" % [kind, text]
	body_line.add_theme_font_size_override("font_size", 13)
	body_line.add_theme_color_override("font_color", Palette.INK_MID)
	# Wrapped, not clipped: a long effect line is common and the row is centred,
	# so an unwrapped one would push the icon off its own side of the plate.
	body_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_line.custom_minimum_size.x = EventScene.PLATE_W - 56.0 - OBTAINED_ICON - 10.0
	col.add_child(body_line)
	return row

# --- run lifecycle ---------------------------------------------------------

func _show_title() -> void:
	screen = Screen.MAP
	_clear_body()
	_stats.clear()
	_footer.text = ""
	# The title owns the whole frame: the run chrome underneath it is the HUD
	# for a run that has not started yet.
	_chrome.hide()
	if _title_view and is_instance_valid(_title_view):
		_title_view.queue_free()
	_title_view = TitleView.new()
	_title_view.setup(RunState.has_save())
	add_child(_title_view)
	_title_view.continue_requested.connect(func():
		_close_title()
		run = RunState.load_run()
		if run == null:
			_start_new_run()
		else:
			_show_map())
	_title_view.new_run_requested.connect(func():
		_close_title()
		RunState.delete_save()
		_start_new_run())

func _close_title() -> void:
	if _title_view and is_instance_valid(_title_view):
		_title_view.queue_free()
		_title_view = null
	_chrome.show()

func _start_new_run() -> void:
	run = RunState.new_run()
	_show_map()

## The pre-run draft. Three picks before the first fight, so the run opens on a
## decision rather than on a fixed hand -- and so the player meets the cards,
## the hover panel and the keywords somewhere nothing can kill them.
func _show_opening_draft(left: int) -> void:
	if left <= 0 or run == null:
		_finish_node()
		return
	screen = Screen.DRAFT
	_clear_body()
	_refresh_header()
	# Centred like every other dressed screen. The draft is the first thing a run
	# shows and was the last one still left-aligned against the frame edge.
	_centred(_label("[b]Take up your tools[/b]"), 20)
	_centred(_label("[i]Pick %d more card%s before you set out.[/i]"
		% [left, "" if left == 1 else "s"]), 15)
	_card_choice_row(Rewards.card_choices(), func(card: Card):
		run.add_card(card)
		_show_opening_draft(left - 1), true)
	_action_button("Take none of these", func(): _show_opening_draft(left - 1))
	_centre_actions()

func _refresh_header() -> void:
	if run == null:
		return
	_relic_strip.setup(run.relics)
	# The seed is a debugging handle, not player-facing information.
	var seed_note := "   [b]Seed[/b] %d" % run.seed_value if Dev.is_enabled() else ""
	_stats.refresh(run, seed_note)

# --- map -------------------------------------------------------------------

func _show_map() -> void:
	screen = Screen.MAP
	_clear_body()
	_refresh_header()
	if run.is_dead():
		_show_game_over()
		return
	run.save()

	var available := run.available_nodes()

	var view := MapView.new()
	view.setup(run.map, run.current_node, available)
	view.node_chosen.connect(_enter)
	_map_view = view
	add_child(view)

	# Legend, and a text fallback so the map is still usable by keyboard/screen
	# reader rather than being mouse-only.
	# No legend: the nodes are icons with hover tooltips, and a colour key for
	# something the player can simply point at was pure clutter down the side of
	# the map it was explaining.
	# No text list of the available nodes: it sat over the map it duplicated.
	# MapView answers the keyboard itself now -- arrows walk the reachable nodes,
	# Enter takes one -- so removing the list cost no accessibility.

	if not run.potions.is_empty():
		_dock_left(_button("Discard an item", _show_potion_picker, false,
			"Free a bag slot before an item you cannot carry."))

	# The footer sits at y~511, which is where the row-0 nodes are drawn.
	_footer.text = ""

func _show_potion_picker() -> void:
	_clear_body()
	_refresh_header()
	_label("[b]Discard which item?[/b]")
	for pot in run.potions:
		var p: PotionData = pot
		_button("%s — %s" % [p.title, p.text], func():
			run.discard_potion(p)
			_show_map())
	_action_button("Back", _show_map)

func _node_glyph(kind: int) -> String:
	match kind:
		MapNode.Kind.COMBAT:   return "C"
		MapNode.Kind.ELITE:    return "E"
		MapNode.Kind.EVENT:    return "?"
		MapNode.Kind.SHOP:     return "$"
		MapNode.Kind.CAMPFIRE: return "R"
		MapNode.Kind.TREASURE: return "T"
		MapNode.Kind.BOSS:     return "B"
		_: return "."

func _node_hint(kind: int) -> String:
	return MapNode.hint_for(kind)

func _enter(node: MapNode) -> void:
	if not run.enter(node):
		return
	match node.kind:
		# From the node, not from its row: the generator already decided, and two
		# copies of the threshold had already drifted apart.
		MapNode.Kind.COMBAT:   _begin_combat(String(node.encounter_id))
		MapNode.Kind.ELITE:    _begin_combat("elite")
		MapNode.Kind.BOSS:     _begin_combat("boss")
		MapNode.Kind.EVENT:    _show_event()
		MapNode.Kind.SHOP:     _show_shop()
		MapNode.Kind.CAMPFIRE: _show_campfire()
		MapNode.Kind.TREASURE: _show_treasure()
		MapNode.Kind.DRAFT:    _show_opening_draft(OPENING_PICKS)
		_:                     _finish_node()

func _finish_node() -> void:
	run.complete_node()
	if run.is_dead():
		_show_game_over()
	elif run.current_node != null and run.current_node.kind == MapNode.Kind.BOSS:
		_show_run_complete()
	else:
		_show_map()

# --- combat ----------------------------------------------------------------

func _begin_combat(kind: String) -> void:
	screen = Screen.COMBAT
	_clear_body()
	_footer.text = ""

	var pool := EnemyLibrary.encounters_of_kind(kind)
	if pool.is_empty():
		pool = EnemyLibrary.encounters_of_kind("normal")
	var chosen = Rng.pick_in(&"enemy_ai", pool)
	var enemies := EnemyLibrary.encounter(StringName(chosen.get("id", "")))

	var player := Player.new("Charmander", run.max_hp)
	player.hp = run.hp
	player.gold = run.gold

	_chrome.hide()
	_combat_panel = COMBAT_VIEW.new()
	_combat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_combat_panel)
	_combat_panel.combat_finished.connect(_on_combat_finished.bind(player, kind))

	var combat := Combat.new(player, enemies, run.deck, run.relics)
	_combat_panel.begin(combat, run)

func _on_combat_finished(result: int, player: Player, kind: String) -> void:
	run.hp = player.hp
	if _combat_panel:
		_combat_panel.queue_free()
		_combat_panel = null
	_chrome.show()
	if result == Combat.Result.DEFEAT or run.is_dead():
		_show_game_over()
		return
	_show_rewards(kind)

# --- rewards ---------------------------------------------------------------

func _show_rewards(kind: String) -> void:
	screen = Screen.REWARD
	_clear_body()
	_refresh_header()

	# The field you just cleared, with the far platform scorched and empty. This
	# was the one screen in the game that had definitely just had a fight on it
	# and was the only one that showed no sign of one.
	_dress_scene(&"victory")

	var gold := Rewards.gold_for(kind)
	run.gold += gold
	Audio.play(&"victory", 1.0, 0.8)
	# Out of the far platform, where the thing that was carrying it stood.
	_gold_flourish(gold, Vector2(752, 416), "Victory.")

	if kind == "elite":
		var relic := Rewards.relic(run.relics)
		if relic:
			run.add_relic(relic)
			_obtained_item(IconArt.for_relic(relic.id), relic.title, "Held item", relic.text)
	elif kind == "boss":
		var br := Rewards.boss_relic(run.relics)
		if br:
			run.add_relic(br)
			_obtained_item(IconArt.for_relic(br.id), br.title, "Rare held item", br.text)

	# The card choice is drawn only after the potion is settled. Drawn together,
	# taking a card called _finish_node() and threw the undecided potion away
	# without saying so.
	if Rewards.rolls_potion():
		_offer_potion(Rewards.potion(), _show_card_choice)
	else:
		_show_card_choice()

func _show_card_choice() -> void:
	_refresh_header()
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_body.add_child(gap)
	_centred(_label("[b]Choose a card[/b]"), 18)
	_pending_rewards = Rewards.card_choices()
	_card_choice_row(_pending_rewards, _take_card, true)
	_centre_actions()
	_action_button("Skip this card", func(): _finish_node())

## A row of real cards with the hover-driven upgrade preview beneath it. Shared
## by the opening draft and every combat reward, so the two cannot drift apart.
## `centred` constrains the hint line under the row to the scene plate. The row
## itself is already centred on the frame -- CardPicker centres its cards inside
## whatever width it is given, and the body is the full frame -- so the plate and
## the cards agree without touching the picker, which the smoke walk reaches into
## by name and must stay a direct child of the body.
func _card_choice_row(cards: Array, on_pick: Callable, centred: bool = false) -> CardPicker:
	var picker := CardPicker.new()
	_body.add_child(picker)
	picker.setup(cards)
	# The card row, not the Skip button, is what the player came here to use.
	picker.call_deferred("grab_focus")
	picker.card_chosen.connect(on_pick)

	# Hold Shift and every card flips to its upgraded face at once -- the same
	# gesture the forge uses, and the same renderer, so the preview cannot
	# disagree with what upgrading actually produces. It replaced a hover-driven
	# line of prose that described one card at a time and made you point at each
	# in turn to compare them.
	for c in cards:
		var card: Card = c
		if card.upgrade_preview() != "":
			picker.set_alt(card, Card.new(card.data, true))
	_upgrade_picker = picker
	var hint := _label("[color=%s]Hold Shift to see the upgraded version.[/color]"
		% _hex(Palette.INK_MUTED))
	if centred:
		_centred(hint, 14)
	return picker

## Takes a found potion, or -- if the belt is full -- offers the trade. Telling
## the player "all slots are full" and moving on turns the reward into nothing
## and denies them the only decision that matters here: which one is worth less.
func _offer_potion(pot: PotionData, on_done: Callable = Callable()) -> void:
	var finish := func() -> void:
		if on_done.is_valid():
			on_done.call()
	if pot == null:
		finish.call()
		return
	if run.add_potion(pot):
		_obtained_item(IconArt.for_item(pot.id), pot.title, "Item", pot.text)
		finish.call()
		return

	var note := _centred(_label("[color=%s]Found [b]%s[/b] — %s. All %d slots are full.[/color]"
		% [_hex(Palette.INK_MUTED), pot.title, pot.text, RunState.POTION_SLOTS]), 15)
	var choices: Array[Button] = []
	var resolve := func(text: String) -> void:
		note.text = text
		for b in choices:
			b.queue_free()
		choices.clear()
		_refresh_header()
		finish.call()
	for i in run.potions.size():
		var h: PotionData = run.potions[i]
		# Slot number, because a belt of three Fire Potions otherwise offers
		# three identical buttons and no way to tell them apart.
		var same := " (the same potion)" if h.id == pot.id else ""
		choices.append(_centred_button(_button("Slot %d: discard %s to take %s%s" % [
				i + 1, h.title, pot.title, same], func():
			run.discard_potion(h)
			run.add_potion(pot)
			resolve.call("Discarded %s for [b]%s[/b]." % [h.title, pot.title]),
			false, h.text)))
	choices.append(_centred_button(_button("Leave %s behind" % pot.title, func():
		resolve.call("[color=%s]Left %s behind.[/color]" % [_hex(Palette.INK_MUTED), pot.title]))))

func _take_card(card: Card) -> void:
	run.add_card(card)
	_finish_node()

# --- event -----------------------------------------------------------------

func _show_event() -> void:
	screen = Screen.EVENT
	_clear_body()
	_refresh_header()
	current_event = EventLibrary.pick(run.seen_events)
	if current_event.is_empty():
		_finish_node()
		return
	run.seen_events.append(String(current_event.get("id", "")))
	_dress_event()
	_centred(_label("[b]%s[/b]" % current_event.get("title", "?")), 20)
	_centred(_label("[i]%s[/i]" % current_event.get("text", "")), 15)
	_label("")
	var choices: Array = current_event.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var idx := i
		# A choice the run cannot afford is shown greyed with its reason rather
		# than hidden: knowing the forge wanted 60 gold is part of the event.
		var blocked := EventLibrary.unmet_requirement(run, choice)
		# No square brackets: in a card game they read as a cost or a hotkey.
		var label := "%s — %s" % [choice.get("label", "..."), choice.get("hint", "")]
		if blocked != "":
			label += "   (%s)" % blocked
		_centred_button(_button(label, func(): _resolve_event(idx), blocked != "", blocked))

## Puts a named scene behind the chrome: after the veil so it is not dimmed
## twice, before _chrome so the words stay on top of it.
##
## Not just for events any more. A campfire, a won fight and a sprung strongbox
## are places too, and they were the screens still rendering as left-aligned
## prose on the same flat grey veil every other screen used.
func _dress_scene(scene: StringName) -> void:
	_event_scene = EventScene.new()
	_event_scene.setup(scene, _body)
	add_child(_event_scene)
	move_child(_event_scene, _chrome.get_index())

func _dress_event() -> void:
	_dress_scene(StringName(current_event.get("scene", "field")))

## Exit actions live in a bar of their own outside the scrolling body, which on
## a dressed screen left "Continue" adrift at the bottom-left corner of the art.
## Centring lines it up under the plate, which grows to cover it.
func _centre_actions() -> void:
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER

## Constrains a body row to the plate EventScene draws and centres it there.
## The body is full width for every other screen, which would run the prose
## out over the art on both sides -- and straight through Charmander.
func _centred(l: RichTextLabel, size: int) -> RichTextLabel:
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size.x = EventScene.PLATE_W - 56.0
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_font_size_override("italics_font_size", size)
	l.text = "[center]%s[/center]" % l.text
	return l

func _centred_button(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = EventScene.PLATE_W - 80.0
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b

func _resolve_event(index: int) -> void:
	var before_gold: int = run.gold
	var lines := EventLibrary.choose(run, current_event, index)
	_clear_body()
	_refresh_header()
	# The outcome is the same place, so it keeps the same art rather than
	# dumping the player back onto the bare route plate mid-scene.
	_dress_event()
	_centred(_label("[b]%s[/b]" % current_event.get("title", "?")), 20)
	if lines.is_empty():
		_centred(_label("[i]Nothing happens.[/i]"), 15)
	for line in lines:
		_centred(_label("• %s" % line), 15)
	# An event that pays out gets the same coins the treasure does. The outcome
	# line already names the number, so there is no second tally here -- only
	# the coins, out of the middle of the scene the player is looking at.
	if run.gold > before_gold:
		Audio.play(&"gold", 1.05, 0.7)
		_coin_burst(run.gold - before_gold, Vector2(600, 452))
	_centre_actions()
	_action_button("Continue", func(): _finish_node())

# --- shop ------------------------------------------------------------------

## The picker currently showing before/after faces, if any. Held so the Shift
## key can flip the whole shelf at once instead of one card per hover.
var _upgrade_picker: CardPicker = null

func _unhandled_key_input(event: InputEvent) -> void:
	if _upgrade_picker == null or not is_instance_valid(_upgrade_picker):
		return
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		_upgrade_picker.set_previewing(event.pressed)

func _show_shop() -> void:
	screen = Screen.SHOP
	shop = Shop.generate(run, run.removals_used)
	_render_shop()

func _render_shop() -> void:
	_clear_body()
	_refresh_header()
	_label("[b]The Poké Mart[/b]  —  you have [color=%s]%d gold[/color]"
		% [_hex(Palette.SPARK), run.gold])

	# Cards as cards and items as items. The shop is a comparison, and the
	# player was being asked to make it by reading eleven lines of prose.
	var cards: Array = []
	for entry in shop.cards:
		if not entry["sold"]:
			cards.append(entry["card"])
	if cards.is_empty():
		_label("[color=%s]The move shelf is bare.[/color]" % _hex(Palette.INK_MUTED))
	else:
		var picker := CardPicker.new()
		_body.add_child(picker)
		picker.setup(cards)
		for i in shop.cards.size():
			var entry: Dictionary = shop.cards[i]
			if entry["sold"]:
				continue
			picker.set_price(entry["card"], entry["price"], run.gold >= entry["price"])
		picker.card_chosen.connect(func(card):
			for i in shop.cards.size():
				if shop.cards[i]["card"] == card:
					_buy(func(): return shop.buy_card(run, i))
					return)
		_shop_hint(picker.card_hovered, func(card): return _afford_note(_price_of_card(card)))

	var shelf_entries: Array = []
	for i in shop.relics.size():
		var relic: RelicData = shop.relics[i]["relic"]
		shelf_entries.append({
			"icon": IconArt.for_relic(relic.id), "title": relic.title,
			"text": relic.text, "price": shop.relics[i]["price"],
			"sold": shop.relics[i]["sold"], "kind": "relic", "index": i,
			"buyable": run.gold >= shop.relics[i]["price"],
			"note": _afford_note(shop.relics[i]["price"]),
		})
	for i in shop.potions.size():
		var pot: PotionData = shop.potions[i]["potion"]
		var price: int = shop.potions[i]["price"]
		shelf_entries.append({
			"icon": IconArt.for_item(pot.id), "title": pot.title,
			"text": pot.text, "price": price, "sold": shop.potions[i]["sold"],
			"kind": "potion", "index": i,
			"buyable": run.gold >= price and not _belt_full(),
			"note": _potion_note(price),
		})
	if not shelf_entries.is_empty():
		var shelf := ItemShelf.new()
		_body.add_child(shelf)
		shelf.setup(shelf_entries)
		shelf.item_chosen.connect(func(i: int):
			var e: Dictionary = shelf_entries[i]
			if e["kind"] == "relic":
				_buy(func(): return shop.buy_relic(run, e["index"]))
			else:
				_buy(func(): return shop.buy_potion(run, e["index"])))
		shelf.item_hovered.connect(func(e: Dictionary):
			_footer.text = "" if e.is_empty() \
				else "[b]%s[/b] — %s  [color=%s]%s[/color]" % [
					e.get("title", ""), e.get("text", ""),
					_hex(Palette.RED), e.get("note", "")])

	_button("Remove a move from your deck   (%d gold)%s" % [
			shop.removal_price, "  used" if shop.removal_used else ""],
		_show_removal_picker,
		shop.removal_used or run.gold < shop.removal_price)

	_action_button("Leave", func(): _finish_node())

## Moves still on the shelf. Used by the tests to assert that a shop with stock
## actually renders somewhere to buy it from.
func _shop_card_count() -> int:
	var n := 0
	for entry in shop.cards:
		if not entry["sold"]:
			n += 1
	return n

## The shelf price of a card still on sale, for the hover note.
func _price_of_card(card) -> int:
	for entry in shop.cards:
		if entry["card"] == card:
			return entry["price"]
	return 0

## Routes a picker's hover into the footer. Cards on the shelf carry a price the
## row of cards itself cannot spell out, so the line under them has to.
func _shop_hint(sig: Signal, note: Callable) -> void:
	sig.connect(func(card):
		if card == null:
			_footer.text = ""
			return
		var msg: String = note.call(card)
		_footer.text = "[b]%s[/b] — %s  [color=%s]%s[/color]" % [
			card.title(), card.describe(), _hex(Palette.RED), msg])

## Why a shop row is greyed out. Events already explain themselves (D-25); the
## shop looked like an unexplained bug by comparison.
func _belt_full() -> bool:
	return run.potions.size() >= RunState.POTION_SLOTS

## Shop.buy_potion refuses a full belt, but the button did not, so the row read
## as purchasable, failed on click, and blamed the player with no way to act on
## it -- the shop has no discard affordance. Refuse up front and say why.
func _potion_note(price: int) -> String:
	if _belt_full():
		return "Your bag is full (%d items). Discard one on the map first." % RunState.POTION_SLOTS
	return _afford_note(price)

func _afford_note(price: int) -> String:
	return "Costs %d gold; you have %d." % [price, run.gold] if run.gold < price else ""

func _buy(action: Callable) -> void:
	var err: String = action.call()
	_render_shop()
	if err != "":
		_footer.text = "[color=%s]%s[/color]" % [_hex(Palette.RED), err]
	else:
		_footer.text = "[color=%s]Purchased.[/color]" % _hex(Palette.MOSS)

func _show_removal_picker() -> void:
	_clear_body()
	_refresh_header()
	_label("[b]Which move should Charmander forget?[/b]  (%d gold)" % shop.removal_price)
	var picker := CardPicker.new()
	# The card leaves the deck here; flying it INTO the deck counter would
	# animate the opposite of what happened.
	picker.fly_to_deck = false
	_body.add_child(picker)
	picker.setup(run.deck.duplicate())
	picker.call_deferred("grab_focus")
	picker.card_chosen.connect(func(card):
		var err := shop.buy_removal(run, card)
		if err == "":
			run.removals_used += 1
		_render_shop()
		_footer.text = "[color=%s]%s was forgotten.[/color]" % [_hex(Palette.MOSS), card.title()] \
			if err == "" else "[color=%s]%s[/color]" % [_hex(Palette.RED), err])
	_action_button("Back", _render_shop)

# --- campfire --------------------------------------------------------------

func _show_campfire() -> void:
	screen = Screen.CAMPFIRE
	_clear_body()
	_refresh_header()
	# A place you have stopped at for the night, not a menu you have opened.
	# Dusk, a ring of stones and a fire banked down to coals -- which is what
	# the prose has always said and what the screen never showed.
	_dress_scene(&"campfire")
	_centred(_label("[b]A banked fire[/b]"), 22)
	_centred(_label("[i]Coals still live under the ash. Enough for one thing, not two.[/i]"), 15)
	_label("")
	var heal := run.rest_heal_amount()
	# Promise what it will actually heal, not the full amount, or resting at
	# 74/75 offers "heal 23 HP" and delivers 1.
	var real_heal: int = mini(heal, run.max_hp - run.hp)
	_centred_button(_button("Rest — heal %d HP" % real_heal, func():
		var healed := run.heal(heal)
		_clear_body()
		_refresh_header()
		# Still the same fire. Dropping back to the bare veil to report the
		# result walked the player out of the scene mid-rest.
		_dress_scene(&"campfire")
		_centred(_label("[b]A banked fire[/b]"), 22)
		_centred(_label("You rest. [color=%s]Healed %d HP.[/color]"
			% [_hex(Palette.MOSS), healed]), 16)
		_centre_actions()
		_action_button("Continue", func(): _finish_node()),
		run.hp >= run.max_hp))
	_centred_button(_button("Smith — upgrade a card", _show_upgrade_picker,
		run.upgradeable_cards().is_empty(),
		"Nothing left in the deck to upgrade." if run.upgradeable_cards().is_empty() else ""))
	# Both options above can be unavailable at once -- full HP with a fully
	# upgraded deck -- and a screen whose every control is disabled is a run the
	# player cannot continue. There is always a way to walk on.
	_centred_button(_button("Move on without resting", func(): _finish_node()))

func _show_upgrade_picker() -> void:
	_clear_body()
	_refresh_header()
	_centred(_label("[b]Which move should Charmander sharpen?[/b]"), 20)
	_centred(_label("[color=%s]Hold Shift to see every upgraded version at once.[/color]"
		% _hex(Palette.INK_MUTED)), 13)
	var picker := CardPicker.new()
	# Upgrading edits a card already in the deck, so it must not fly into it.
	picker.fly_to_deck = false
	_body.add_child(picker)
	var cards := run.upgradeable_cards()
	picker.setup(cards)
	# The "after" face is a real upgraded card, built and thrown away rather
	# than described in prose -- the same renderer draws both, so the preview
	# cannot disagree with what the upgrade actually produces.
	for c in cards:
		var card: Card = c
		picker.set_alt(card, Card.new(card.data, true))
	picker.call_deferred("grab_focus")
	_upgrade_picker = picker
	picker.card_chosen.connect(func(card):
		_upgrade_picker = null
		card.upgrade()
		_clear_body()
		_refresh_header()
		# The forge SHELF stays undressed -- a full deck wraps to a grid wider
		# than the plate -- but the one sharpened card it hands back does not,
		# and that is the moment worth standing in the firelight for.
		_dress_scene(&"campfire")
		_centred(_label("[b]%s[/b] sharpened." % card.title()), 20)
		var shown := CardPicker.new()
		shown.fly_to_deck = false
		shown.display_only = true
		_body.add_child(shown)
		shown.setup([card])
		_centre_actions()
		_action_button("Continue", func(): _finish_node()))
	_action_button("Back", func():
		_upgrade_picker = null
		_show_campfire())

# --- treasure --------------------------------------------------------------

func _show_treasure() -> void:
	screen = Screen.TREASURE
	_clear_body()
	# The whole node used to be two lines of prose and a Continue button, for
	# what is meant to be the run finding money. It gets a sprung strongbox to
	# have come out of, and the money comes out of it where you can see.
	_dress_scene(&"cache")
	var gold := Rewards.gold_for("treasure")
	run.gold += gold
	_centred(_label("[b]A cache in the slag[/b]"), 22)
	_centred(_label("[i]Somebody stashed this and never came back for it.[/i]"), 15)
	_gold_flourish(gold, Vector2(648, 470))
	if Rng.randf_in(&"rewards") < 0.5:
		var relic := Rewards.relic(run.relics)
		if relic:
			run.add_relic(relic)
			_obtained_item(IconArt.for_relic(relic.id), relic.title, "Held item", relic.text)
	_refresh_header()
	_centre_actions()
	_action_button("Continue", func(): _finish_node())

# --- gold ------------------------------------------------------------------

## Gold arriving, as a moment rather than a receipt.
##
## "Gained 61 gold." told the player a number and left the counter in the corner
## to tick up on its own. Coins come out of whatever gave them up, a tally rolls
## to meet them, and both use the same coin glyph the HUD does, so the eye can
## follow the money from the thing that held it to the purse that now has it.
##
## Presentation only. run.gold was committed by the caller and the header shows
## the true total before the first coin lands: the rules never wait on this
## (D-13), and skipping straight past it costs the player nothing.
func _gold_flourish(amount: int, from: Vector2, lead: String = "") -> void:
	if amount <= 0:
		return
	Audio.play(&"gold", 1.05, 0.7)
	_gold_row(amount, lead)
	_coin_burst(amount, from)

## The tally: a coin the size of the words beside it, and a number that counts.
##
## `lead` shares the line rather than taking one of its own. The reward screen
## is the tightest body in the game -- three cards, a relic, a found item and a
## hint -- and it was already scrolling its last line off the bottom before this
## row existed, so "Victory." and its payout sit together.
func _gold_row(amount: int, lead: String = "") -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)

	if lead != "":
		var head := Label.new()
		head.add_theme_font_size_override("font_size", 24)
		head.add_theme_color_override("font_color", Palette.INK_LIGHT)
		head.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		head.add_theme_constant_override("outline_size", 6)
		head.text = lead
		row.add_child(head)

	var coin := TextureRect.new()
	coin.texture = IconArt.hud("hud_gold")
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.custom_minimum_size = Vector2(30, 30)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin)

	var num := Label.new()
	num.add_theme_font_size_override("font_size", 26)
	num.add_theme_color_override("font_color", Palette.SPARK)
	num.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	num.add_theme_constant_override("outline_size", 6)
	num.text = "+%d gold" % amount
	row.add_child(num)

	# Reduce motion gets the final number immediately. A count-up nobody can see
	# counting is just a slower way to read the same figure (D-23).
	if Juice.intensity <= 0.0:
		return
	num.text = "+0 gold"
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Guarded: _clear_body() frees the row with queue_free(), and a tween mid-roll
	# outlives the label it is rolling by a frame.
	t.tween_method(func(v: float):
		if is_instance_valid(num):
			num.text = "+%d gold" % int(round(v)),
		0.0, float(amount), Juice.dur(0.7))

## Coins out of the thing that just gave them up. Self-freeing, and dropped by
## _clear_body() if the player leaves before they land.
func _coin_burst(amount: int, from: Vector2) -> void:
	if Juice.intensity <= 0.0:
		return
	if _coins and is_instance_valid(_coins):
		_coins.queue_free()
	var burst := _CoinBurst.new()
	add_child(burst)
	_coins = burst
	burst.fire(from, amount)

## A handful of coins thrown up out of a point and left to gravity.
##
## Node2D sprites would need a stage, a z_index argument with the chrome and a
## teardown; this is one Control drawing one texture N times, which is all the
## effect is. It draws over everything because it is added last.
class _CoinBurst extends Control:
	const GRAVITY := 1100.0
	const SPRITE := 22.0
	var _bits: Array[Dictionary] = []
	var _tex: Texture2D
	var _t := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func fire(from: Vector2, amount: int) -> void:
		_tex = IconArt.hud("hud_gold")
		# One coin per handful, not one per gold piece. Sixty-one sprites is
		# confetti, and the number is already written out beside them.
		for i in clampi(int(amount / 6.0), 7, 18):
			_bits.append({
				"p": from + Vector2(randf_range(-30, 30), randf_range(-12, 12)),
				"v": Vector2(randf_range(-170, 170), randf_range(-500, -320)),
				"scale": randf_range(0.75, 1.35),
				"spin": randf_range(7.0, 13.0),
				"phase": randf() * TAU,
				"life": randf_range(0.9, 1.5),
				"age": 0.0,
			})
		set_process(true)

	func _process(delta: float) -> void:
		var k := Juice.intensity
		_t += delta
		var live := false
		for b in _bits:
			b["age"] += delta
			if float(b["age"]) >= float(b["life"]):
				continue
			live = true
			b["v"] = (b["v"] as Vector2) + Vector2(0.0, GRAVITY * delta * k)
			b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta * k
		queue_redraw()
		if not live:
			queue_free()

	func _draw() -> void:
		if _tex == null:
			return
		for b in _bits:
			var t: float = float(b["age"]) / float(b["life"])
			if t >= 1.0:
				continue
			# Out over the last third only, so they read as landing rather than
			# as evaporating on the way up.
			var fade: float = clampf((1.0 - t) / 0.34, 0.0, 1.0)
			var w: float = SPRITE * float(b["scale"])
			# Foreshortened by a fake spin: a coin edge-on is a line, which is
			# the cheapest thing that makes a flat sprite read as turning.
			var flat: float = absf(cos(_t * float(b["spin"]) + float(b["phase"])))
			var half := Vector2(w * maxf(0.12, flat), w) * 0.5
			var p: Vector2 = b["p"]
			draw_texture_rect(_tex, Rect2(p - half, half * 2.0), false,
				Color(Palette.WHITE, fade))

# --- endings ---------------------------------------------------------------

func _show_game_over() -> void:
	screen = Screen.GAME_OVER
	_clear_body()
	RunState.delete_save()
	# Full art, and the chrome out of the way: an ending screen that still shows
	# the HP bar and the bag is a menu, not an ending.
	_chrome.hide()
	if _ending_view and is_instance_valid(_ending_view):
		_ending_view.queue_free()
	_ending_view = EndingView.new()
	add_child(_ending_view)
	_ending_view.setup(false, run)
	# Death returns to the partner select, the same as victory does. 'Set out
	# again' used to rebuild the run and drop you straight onto a route, which
	# skipped the one screen where the next run is chosen rather than dealt.
	_ending_view.again_requested.connect(func():
		_close_ending()
		run = null
		_show_title())

func _show_run_complete() -> void:
	screen = Screen.RUN_COMPLETE
	_clear_body()
	RunState.delete_save()
	_chrome.hide()
	if _ending_view and is_instance_valid(_ending_view):
		_ending_view.queue_free()
	_ending_view = EndingView.new()
	add_child(_ending_view)
	_ending_view.setup(true, run)
	# Finishing the act returns to the partner select, not straight back onto a
	# route. Beating it is the end of something, and the next run should open on
	# the same choice the first one did rather than dropping you mid-journey.
	_ending_view.again_requested.connect(func():
		_close_ending()
		run = null
		_show_title())

func _close_ending() -> void:
	if _ending_view and is_instance_valid(_ending_view):
		_ending_view.queue_free()
		_ending_view = null
	_chrome.show()

