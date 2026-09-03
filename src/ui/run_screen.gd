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
	if _event_scene and is_instance_valid(_event_scene):
		_event_scene.queue_free()
		_event_scene = null

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
	_label("[b]Take up your tools[/b]")
	_label("[i]Pick %d more card%s before you set out. Hover one to read it in full.[/i]"
		% [left, "" if left == 1 else "s"])
	_card_choice_row(Rewards.card_choices(), func(card: Card):
		run.add_card(card)
		_show_opening_draft(left - 1))
	_action_button("Take none of these", func(): _show_opening_draft(left - 1))

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
	for node in available:
		# The entrance has no stage or path number -- it is what the paths come
		# out of, so numbering it would name a stage the player never plays.
		var where := "the way in" if node.row < 0 \
			else "stage %d, path %d" % [node.row + 1, node.col + 1]
		_dock_left(_button("%s\n%s" % [MapNode.label_for(node.kind), where],
			func(): _enter(node), false, _node_hint(node.kind)))

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

	var gold := Rewards.gold_for(kind)
	run.gold += gold
	Audio.play(&"victory", 1.0, 0.8)
	Audio.play(&"gold", 1.1, 0.6)
	_label("[b]Victory.[/b]  Gained [color=%s]%d gold[/color]." % [_hex(Palette.SPARK), gold])

	if kind == "elite":
		var relic := Rewards.relic(run.relics)
		if relic:
			run.add_relic(relic)
			_label("Obtained held item: [b]%s[/b] — %s" % [relic.title, relic.text])
	elif kind == "boss":
		var br := Rewards.boss_relic(run.relics)
		if br:
			run.add_relic(br)
			_label("Obtained rare held item: [b]%s[/b] — %s" % [br.title, br.text])

	# The card choice is drawn only after the potion is settled. Drawn together,
	# taking a card called _finish_node() and threw the undecided potion away
	# without saying so.
	if Rewards.rolls_potion():
		_offer_potion(Rewards.potion(), _show_card_choice)
	else:
		_show_card_choice()

func _show_card_choice() -> void:
	_refresh_header()
	_label("")
	_label("[b]Choose a card[/b]")
	_pending_rewards = Rewards.card_choices()
	_card_choice_row(_pending_rewards, _take_card)
	_action_button("Skip this card", func(): _finish_node())

## A row of real cards with the hover-driven upgrade preview beneath it. Shared
## by the opening draft and every combat reward, so the two cannot drift apart.
func _card_choice_row(cards: Array, on_pick: Callable) -> CardPicker:
	var picker := CardPicker.new()
	_body.add_child(picker)
	picker.setup(cards)
	# The card row, not the Skip button, is what the player came here to use.
	picker.call_deferred("grab_focus")
	picker.card_chosen.connect(on_pick)

	# One preview line, driven by hover. An upgrade describes a card that does
	# not exist yet, so there is nothing to draw for it -- but a stack of three
	# preview lines under a row of three cards says nothing about which is which.
	var idle := "[color=%s]Hover a card to see what upgrading it gives.[/color]" \
		% _hex(Palette.INK_MUTED)
	var preview := _label(idle)
	picker.card_hovered.connect(func(card):
		if card == null:
			preview.text = idle
			return
		var up: String = card.upgrade_preview()
		if up == "":
			preview.text = "[color=%s]%s is already upgraded.[/color]" % [
				_hex(Palette.INK_MUTED), card.title()]
		else:
			preview.text = "[color=%s]↳ %s+  [%d]  —  %s[/color]" % [
				_hex(Palette.INK_MUTED), card.data.title, card.data.cost_when(true), up])
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
		_label("Obtained item: [b]%s[/b] — %s" % [pot.title, pot.text])
		finish.call()
		return

	var note := _label("[color=%s]Found [b]%s[/b] — %s. All %d slots are full.[/color]"
		% [_hex(Palette.INK_MUTED), pot.title, pot.text, RunState.POTION_SLOTS])
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
		choices.append(_button("Slot %d: discard %s to take %s%s" % [
				i + 1, h.title, pot.title, same], func():
			run.discard_potion(h)
			run.add_potion(pot)
			resolve.call("Discarded %s for [b]%s[/b]." % [h.title, pot.title]),
			false, h.text))
	choices.append(_button("Leave %s behind" % pot.title, func():
		resolve.call("[color=%s]Left %s behind.[/color]" % [_hex(Palette.INK_MUTED), pot.title])))

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

## Puts the event's scene behind the chrome: after the veil so it is not dimmed
## twice, before _chrome so the words stay on top of it.
func _dress_event() -> void:
	_event_scene = EventScene.new()
	_event_scene.setup(StringName(current_event.get("scene", "field")), _body)
	add_child(_event_scene)
	move_child(_event_scene, _chrome.get_index())

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
	_label("[b]A banked fire[/b]")
	_label("[i]Coals still live under the ash. Enough for one thing, not two.[/i]")
	var heal := run.rest_heal_amount()
	# Promise what it will actually heal, not the full amount, or resting at
	# 74/75 offers "heal 23 HP" and delivers 1.
	var real_heal: int = mini(heal, run.max_hp - run.hp)
	_button("Rest — heal %d HP" % real_heal, func():
		var healed := run.heal(heal)
		_clear_body()
		_refresh_header()
		_label("You rest. [color=%s]Healed %d HP.[/color]" % [_hex(Palette.MOSS), healed])
		_action_button("Continue", func(): _finish_node()),
		run.hp >= run.max_hp)
	_button("Smith — upgrade a card", _show_upgrade_picker,
		run.upgradeable_cards().is_empty(),
		"Nothing left in the deck to upgrade." if run.upgradeable_cards().is_empty() else "")
	# Both options above can be unavailable at once -- full HP with a fully
	# upgraded deck -- and a screen whose every control is disabled is a run the
	# player cannot continue. There is always a way to walk on.
	_button("Move on without resting", func(): _finish_node())

func _show_upgrade_picker() -> void:
	_clear_body()
	_refresh_header()
	_label("[b]Which move should Charmander sharpen?[/b]")
	_label("[color=%s]Hold Shift to see every upgraded version at once.[/color]"
		% _hex(Palette.INK_MUTED))
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
		_label("[b]%s[/b] sharpened." % card.title())
		var shown := CardPicker.new()
		shown.fly_to_deck = false
		shown.display_only = true
		_body.add_child(shown)
		shown.setup([card])
		_action_button("Continue", func(): _finish_node()))
	_action_button("Back", func():
		_upgrade_picker = null
		_show_campfire())

# --- treasure --------------------------------------------------------------

func _show_treasure() -> void:
	screen = Screen.TREASURE
	_clear_body()
	var gold := Rewards.gold_for("treasure")
	run.gold += gold
	_label("[b]A cache in the slag[/b]")
	_label("Gained [color=%s]%d gold[/color]." % [_hex(Palette.SPARK), gold])
	if Rng.randf_in(&"rewards") < 0.5:
		var relic := Rewards.relic(run.relics)
		if relic:
			run.add_relic(relic)
			_label("Obtained held item: [b]%s[/b] — %s" % [relic.title, relic.text])
	_refresh_header()
	_action_button("Continue", func(): _finish_node())

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

