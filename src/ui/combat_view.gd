extends Control
## Animated combat screen.
##
## This is where docs/DECISIONS.md D-13 pays for itself. The simulation has
## already resolved by the time anything here runs; this class drains the event
## queue and plays it back as a timed sequence. Playback can be slow, fast, or
## skipped entirely without the rules noticing, and a bug in here cannot corrupt
## a single point of HP.

signal combat_finished(result)

const ENEMY_Y := 205.0
const PLAYER_POS := Vector2(180, 246)   # clear of the PP gauge label at y=324
## Gap between the lowest pixel of the fan and the bottom of the frame.
const HAND_MARGIN := 8.0
const DRAW_PILE_POS := Vector2(70, 500)
const DISCARD_POS := Vector2(890, 500)
const PLAY_CENTRE := Vector2(480, 300)

var combat: Combat
var run: RunState = null

## The 960x540 design frame (D-07). The cloud layers are sized to it explicitly
## rather than anchored, because they slide and must not be stretched.
const FRAME_W := 960.0
const FRAME_H := 540.0
## Art direction: 3 px/s, right to left.
const CLOUD_DRIFT := 3.0

var _backdrop: TextureRect
var _relics: RelicStrip
var _tip: TipPanel
var _fx: MoveFx
var _weather: WeatherFx
var _cloud_layers: Array[TextureRect] = []
var _cloud_x: float = 0.0
var _world: Node2D
var _popups: Node2D
var _hand: HandView
var _gauge: PPGauge
var _player_view: EntityView
var _enemy_views: Array[EntityView] = []

var _top: RichTextLabel
var _pile_buttons: Dictionary = {}
var _pile_panel: Control = null
var _end_btn: Button
var _speed_btn: Button
var _dev_btn: Button = null
var _auto_btn: Button
## Autoplay is a player preference, not per-fight state. `static` so it outlives
## the view: every fight builds a fresh CombatView, which is exactly why a
## per-instance flag meant re-arming it at the start of each one.
##
## Not on Juice, where speed_scale lives, despite being the same kind of control:
## Juice is presentation only (D-13) and this one plays cards.
static var auto_play := false
var _continue_btn: Button
var _potion_bar: HBoxContainer
var _banner: Label

## Drag-to-play. A press that never travels far is still a click, so the
## select-then-click flow keeps working for anyone who prefers it (and for
## keyboard users, who cannot drag at all).
const DRAG_SLOP := 6.0
## Above this line the board begins. A self-targeted card dropped above it is
## played; dropped back down among the fan it is returned.
const DROP_LINE := 384.0

var _drag_view: CardView = null
var _drag_grab: Vector2 = Vector2.ZERO
var _dragging := false

var _selected_card: Card = null
var _selected_potion: PotionData = null
var _playing := false
var _finished := false

# --- setup -----------------------------------------------------------------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# A flat colour behind the art, so a hand-drawn background with any
	# transparency still lands on the locked ground colour rather than on white.
	var bg := ColorRect.new()
	bg.color = Palette.GROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# The scene supplies its own darkness where the UI lives -- a dark zenith
	# under the HUD, a shadowed bank down the left rail, forge mass down the
	# right, ground falling into SHADOW under the card fan. There is deliberately
	# NO translucent scrim: an overlay greys the whole locked palette toward
	# black, which is what makes pixel art look cheap, and it would also make
	# every colour on screen one the artist could not name.
	_backdrop = TextureRect.new()
	_backdrop.texture = PlaceholderArt.for_background(&"act1")
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	# EXPAND_IGNORE_SIZE and anchors, and NOT an explicit size. A TextureRect's
	# minimum size is its texture, so without IGNORE_SIZE it settles at its
	# native 240x135. But setting `size` on top of FULL_RECT anchors is additive
	# to the parent, not absolute -- 960 wide inside a 960 parent resolves to
	# 1920, and the frame then shows only the top-left quarter of the sky.
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Clouds drift right-to-left at 3px/s. Two copies laid end to end and wrapped
	# is the whole trick; the layer is drawn with wraparound so the seam between
	# them is invisible. This is the only true parallax in the scene -- combat
	# has no camera pan, so nothing else has anything to parallax against.
	var cloud_tex := PlaceholderArt.for_cloud_layer(&"act1")
	for i in 2:
		var c := TextureRect.new()
		c.texture = cloud_tex
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size = Vector2(FRAME_W, FRAME_H)
		c.position = Vector2(FRAME_W * float(i), 0)
		add_child(c)
		_cloud_layers.append(c)

	# Relics were visible only on the map screen, so during a fight the player
	# could not see what any of them did -- including the starter relic, which
	# silently changes turn one.
	_relics = RelicStrip.new()
	_relics.position = Vector2(12, 34)
	_relics.size = Vector2(400, 28)
	add_child(_relics)

	_world = Node2D.new()
	add_child(_world)
	Juice.register_shake_target(_world)

	_tip = TipPanel.new()
	add_child(_tip)

	_hand = HandView.new()
	# Sized for a FULL hand rather than the current one, so the fan keeps one
	# home on the screen instead of sliding up and down as cards come and go.
	_hand.centre = Vector2(FRAME_W * 0.5,
		FRAME_H - HAND_MARGIN - HandView.lowest_reach(Combat.MAX_HAND))
	_world.add_child(_hand)

	_gauge = PPGauge.new()
	_gauge.position = Vector2(12, 348)
	_world.add_child(_gauge)

	_fx = MoveFx.new()
	_world.add_child(_fx)

	_weather = WeatherFx.new()
	_weather.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weather)

	_popups = Node2D.new()
	_popups.z_index = 200
	_world.add_child(_popups)
	Juice.register_popup_layer(_popups)

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.position = Vector2(340, 120)
	_banner.modulate.a = 0.0
	add_child(_banner)

	_build_hud()
	set_process_input(true)
	set_process(true)

## Cloud drift, and nothing else. Stops dead when Juice.intensity is 0, which is
## the reduce-motion setting (D-23) -- ambient background motion is exactly the
## kind of thing that setting exists to switch off.
func _process(delta: float) -> void:
	_drift_clouds(delta)
	_step_autoplay()

func _drift_clouds(delta: float) -> void:
	if _cloud_layers.is_empty() or Juice.intensity <= 0.0:
		return
	_cloud_x = fmod(_cloud_x - CLOUD_DRIFT * delta * Juice.intensity, FRAME_W)
	for i in _cloud_layers.size():
		_cloud_layers[i].position.x = _cloud_x + FRAME_W * float(i)

## Spends the turn, then ends it -- one action per idle frame rather than a loop
## in place, so every card still animates and the player can watch what their
## turn actually did.
##
## It does NOT switch itself off at the end of a turn any more. Autoplay is a
## setting now: it stays armed through the enemy's turn, the next turn, and the
## next fight, until the player unsets it.
func _step_autoplay() -> void:
	if not auto_play or combat == null or _playing:
		return
	if combat.result != Combat.Result.ONGOING or combat.state != Combat.State.PLAYER_ACTION:
		return
	for card in combat.hand.duplicate():
		if combat.can_play(card):
			var living := combat.living_enemies()
			_play_card(card, living.front() if not living.is_empty() else null)
			return
	_on_end_turn()

func _build_hud() -> void:
	_top = RichTextLabel.new()
	_top.bbcode_enabled = true
	_top.fit_content = true
	_top.position = Vector2(12, 6)
	_top.size = Vector2(700, 26)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)

	# Buttons, not a label. "What is left in my draw pile" is a first-hour
	# question in any deckbuilder, and the answer was a line of unclickable grey
	# text sitting on the busy ground plane.
	var px := 12.0
	for spec in [["draw", &"draw"], ["discard", &"discard"], ["exhaust", &"exhaust"]]:
		var b := Button.new()
		b.position = Vector2(px, 508)
		b.custom_minimum_size = Vector2(84, 28)
		b.add_theme_font_size_override("font_size", 13)
		_plate(b)
		var which: StringName = spec[1]
		b.pressed.connect(func():
			Audio.play(&"ui", 1.0, 0.4)
			_show_pile(which))
		add_child(b)
		_pile_buttons[which] = b
		px += 88.0

	_end_btn = Button.new()
	_end_btn.text = "End Turn"
	_end_btn.position = Vector2(806, 392)
	_end_btn.size = Vector2(140, 40)
	_end_btn.pressed.connect(_on_end_turn)
	_plate(_end_btn)
	add_child(_end_btn)

	_auto_btn = Button.new()
	_auto_btn.toggle_mode = true
	_auto_btn.button_pressed = auto_play
	_auto_btn.position = Vector2(806, 350)
	_auto_btn.size = Vector2(140, 34)
	_auto_btn.tooltip_text = \
		"Plays each turn for you. Stays on between fights until you switch it off."
	_auto_btn.toggled.connect(func(on: bool):
		Audio.play(&"ui", 1.0, 0.4)
		auto_play = on
		_sync_auto_btn())
	_sync_auto_btn()
	_plate(_auto_btn)
	add_child(_auto_btn)

	if Dev.is_enabled():
		_dev_btn = Button.new()
		_dev_btn.text = "DEV: win fight"
		_dev_btn.position = Vector2(806, 44)
		_dev_btn.size = Vector2(140, 26)
		_dev_btn.pressed.connect(_on_dev_win)
		_plate(_dev_btn)
		add_child(_dev_btn)

	_speed_btn = Button.new()
	# From Juice, not a literal: speed persists across fights, so a hardcoded
	# "1x" here told the player 1x while the game ran at 4x.
	_speed_btn.text = "Speed %dx" % int(Juice.speed_scale)
	_speed_btn.position = Vector2(806, 8)
	_speed_btn.size = Vector2(140, 26)
	_speed_btn.pressed.connect(_cycle_speed)
	_plate(_speed_btn)
	add_child(_speed_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.position = Vector2(806, 436)
	_continue_btn.size = Vector2(140, 40)
	_continue_btn.pressed.connect(_report_finished)
	_plate(_continue_btn)
	_continue_btn.hide()
	add_child(_continue_btn)

	_potion_bar = HBoxContainer.new()
	_potion_bar.position = Vector2(12, 400)
	add_child(_potion_bar)

## Entry point. RunScreen builds the Combat; this view only presents it.
func begin(c: Combat, p_run: RunState = null) -> void:
	combat = c
	run = p_run
	_finished = false
	_selected_card = null
	_selected_potion = null

	_player_view = EntityView.new()
	_player_view.position = PLAYER_POS
	_world.add_child(_player_view)
	_player_view.setup(c.player, CreatureArt.for_player())

	var n := c.enemies.size()
	for i in n:
		var e := c.enemies[i]
		var kind := "boss" if e.max_hp >= 100 else ("elite" if e.max_hp >= 40 else "normal")
		var v := EntityView.new()
		var spread := 200.0
		var x := 620.0 + (float(i) - float(n - 1) * 0.5) * spread
		v.position = Vector2(x, ENEMY_Y + 90)
		_world.add_child(v)
		v.setup(e, CreatureArt.for_enemy(e.enemy_id, kind))
		_enemy_views.append(v)

	combat.start()
	_gauge.set_pp(c.player.pp, c.player.max_pp, c.player.pp_cap, c.player.overload)
	_play_events()

## Autoplay: spend the turn, then end it. Drives one action per idle frame
## rather than looping in place, so every card still animates and the player can
## watch what their turn actually did.
# --- event playback --------------------------------------------------------

## Drains the simulation's queue and animates it in order. Nothing in here can
## write to combat state -- it only reads what already happened.
func _play_events() -> void:
	if _playing:
		return
	_playing = true
	await _finish_playback()

## Plays back everything queued, then hands control back to the player.
##
## Loops rather than draining once. `drain_events()` takes a snapshot, so an
## event pushed DURING playback -- a status firing mid-sequence, or an action
## that slipped in -- would otherwise be stranded on the queue behind a HUD
## still showing numbers from before it happened.
func _finish_playback() -> void:
	_refresh_hud()
	while not combat.event_queue.is_empty():
		for ev in combat.drain_events():
			await _play_one(ev)
	_playing = false
	_sync_hand()
	_refresh_hud()
	if combat.result != Combat.Result.ONGOING:
		_show_result()

func _play_one(ev: VisualEvent) -> void:
	match ev.kind:
		VisualEvent.TURN_START:
			if _weather:
				_weather.tick_turn()
			Audio.play(&"turn", 1.0, 0.5)
			await _show_banner("TURN %d" % ev.data["turn"], Palette.INK_LIGHT, 0.22)
		VisualEvent.CARD_DRAWN:
			Audio.play(&"card_draw", 1.05, 0.55)
			_deal_card(ev.data["card"])
			await _pause(0.055)
		VisualEvent.DAMAGE:
			var view := _view_for(ev.data["who"])
			var src := _view_for(ev.data.get("source"))
			var contact := bool(ev.data.get("contact", false))
			if src and src != view:
				if contact and not src.is_charging:
					src.play_charge(view.position)
					# Long enough for the wind-back and the dash, so the hit lands
					# on the frame he arrives rather than before he sets off.
					await _pause(0.22)
				else:
					src.play_attack((view.position - src.position).normalized())
					await _pause(0.11 if not contact else 0.05)
			var element := int(ev.data.get("element", -1))
			if view:
				# The volley flies from whoever swung it, so a move reads as
				# crossing the gap rather than appearing on the victim.
				if _fx and contact:
					# He is already standing on top of it. A volley crossing a gap
					# that is no longer there would describe the wrong move.
					_fx.burst(view.global_position - Vector2(0, 34), element, 1.15)
				elif _fx and element >= 0:
					var origin: Vector2 = src.global_position - Vector2(0, 40) if src \
						else PLAY_CENTRE
					_fx.fire(origin, view.global_position - Vector2(0, 40), element)
					await _pause(0.1)
				view.play_hurt(ev.data["amount"], element)
			# Heavier blows get the heavier sample, not just a louder one.
			var amount := int(ev.data["amount"])
			Audio.play(&"hit_heavy" if amount >= 10 else &"hit",
				1.0, clampf(0.5 + float(amount) * 0.03, 0.5, 1.0))
			Juice.shake(clampf(2.0 + float(ev.data["amount"]) * 0.16, 2.0, 9.0))
			Juice.hitstop(0.035)
			await _pause(0.13)
		VisualEvent.BLOCK_GAIN:
			if ev.data["amount"] > 0:
				var view := _view_for(ev.data["who"])
				if view:
					view.play_block(ev.data["amount"])
				Audio.play(&"block", 1.0, 0.7)
				await _pause(0.08)
		VisualEvent.HEAL:
			var view := _view_for(ev.data["who"])
			if view:
				view.play_heal(ev.data["amount"])
			await _pause(0.1)
		VisualEvent.STATUS_APPLIED:
			var view := _view_for(ev.data["who"])
			if view:
				view.play_status(ev.data["id"], ev.data["stacks"])
			await _pause(0.09)
		VisualEvent.PP_CHANGED:
			# Overload announces itself with its own event; Ramp does not, so the
			# ceiling moving IS the tell. Read it before set_pp overwrites it.
			var ramped: bool = int(ev.data["max"]) > _gauge.max_pp
			_gauge.set_pp(ev.data["pp"], ev.data["max"], ev.data["cap"], ev.data["overload"])
			if ramped:
				_gauge.flash_ramp()
				Audio.play(&"ramp", 1.0, 0.8)
			else:
				Audio.play(&"pp", 1.2, 0.3)
			# The simulation already tells us what was repaid; nothing was reading it.
			_gauge.flash_repaid(int(ev.data.get("owed", 0)))
			# The whole scene warms as the curve opens out.
			var tint := Palette.pp_tint(ev.data["max"], ev.data["cap"])
			var t := create_tween()
			t.tween_property(_world, "modulate", Color(1.0, lerpf(1.0, 0.93, tint.r), lerpf(1.0, 0.86, tint.r), 1.0), Juice.dur(0.2))
			await _pause(0.1)
		VisualEvent.EFFECTIVENESS:
			var hit := _view_for(ev.data["who"])
			var strong: bool = bool(ev.data["super"])
			if hit:
				# Said in colour as well as in words: the popup is easy to miss
				# in the middle of a fight, a tinted sprite is not.
				hit.play_tint(Palette.SPARK if strong else Palette.INK_MUTED,
					0.9 if strong else 0.5)
				Juice.popup("SUPER EFFECTIVE!" if strong else "not very effective...",
					Palette.SPARK if strong else Palette.INK_MUTED,
					hit.global_position - Vector2(40, 92), 1.5 if strong else 1.0)
			if strong:
				Juice.shake(5.0)
				Audio.play(&"hit_heavy", 1.15, 1.0)
			await _pause(0.2)
		VisualEvent.OVERLOADED:
			Audio.play(&"overload", 0.85, 0.9)
			_gauge.flash_overload()
			await _pause(0.3)
		VisualEvent.RAMP_DRAINED:
			# The curve going backwards is the one change to the PP gauge a
			# player would otherwise have to notice on their own, and it happens
			# during the enemy's turn while they are reading damage numbers.
			Juice.shake(8.0)
			Juice.popup("−%d REFILL" % int(ev.data["amount"]), Palette.ALARM,
				_gauge.global_position + Vector2(0, -70), 1.3)
			await _pause(0.25)
		VisualEvent.DEATH:
			var view := _view_for(ev.data["who"])
			if view:
				view.play_death()
			Audio.play(&"death", 0.9, 0.9)
			Juice.shake(6.0)
			await _pause(0.35)
		VisualEvent.DECK_RESHUFFLED:
			Juice.popup("reshuffle", Palette.INK_MID, DRAW_PILE_POS + Vector2(0, -40))
			await _pause(0.14)
		VisualEvent.COMBAT_END:
			await _pause(0.2)
		_:
			pass

## Timers ignore time_scale so a hitstop can never stall playback.
func _pause(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(Juice.dur(seconds), true, false, true).timeout

func _view_for(c) -> EntityView:
	if c == null:
		return null
	if c == combat.player:
		return _player_view
	for v in _enemy_views:
		if v.combatant == c:
			return v
	return null

func _show_banner(text: String, color: Color, hold: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.8, 0.8)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_banner, "modulate:a", 1.0, Juice.dur(0.1))
	t.tween_property(_banner, "scale", Vector2.ONE, Juice.dur(0.16)).set_trans(Tween.TRANS_BACK)
	t.chain().tween_interval(Juice.dur(hold))
	t.chain().tween_property(_banner, "modulate:a", 0.0, Juice.dur(0.14))
	await _pause(0.16 + hold)

# --- hand ------------------------------------------------------------------

func _deal_card(card: Card) -> void:
	if _hand.find_for(card) != null:
		return
	var v := CardView.new()
	_hand.add_view(v)
	v.setup(card)
	var idx := _hand.views.size() - 1
	var slot := _hand.slot_for(idx, _hand.views.size())
	v.deal_from(DRAW_PILE_POS, slot["pos"], slot["rot"])
	_hand.layout()

## Reconciles views against the real hand after playback, so any card added or
## removed by an effect we did not animate still ends up correct.
func _sync_hand() -> void:
	for v in _hand.views.duplicate():
		if not combat.hand.has(v.card):
			_hand.remove_view(v)
			v.queue_free()
	for card in combat.hand:
		if _hand.find_for(card) == null:
			_deal_card(card)
	_hand.layout()
	_update_playable()

func _update_playable() -> void:
	for v in _hand.views:
		v.set_playable(combat.can_play(v.card))
		v.set_selected(v.card == _selected_card)
	var targeting := _selected_card != null or _selected_potion != null
	for v in _enemy_views:
		v.set_selectable(targeting and v.combatant.is_alive())

# --- HUD -------------------------------------------------------------------

func _refresh_hud() -> void:
	if combat == null:
		return
	var p := combat.player
	_top.text = "[b]HP[/b] [color=#e43b44]%d/%d[/color]    [b]Block[/b] [color=#0099db]%d[/color]    [b]PP[/b] [color=#fee761]%d/%d[/color]    [b]Turn[/b] %d" % [
		p.hp, p.max_hp, p.block, p.pp, p.max_pp, combat.turn]
	for which in _pile_buttons:
		var b: Button = _pile_buttons[which]
		var pile := _pile_for(which)
		b.text = "%s %d" % [which, pile.size()]
		b.disabled = pile.is_empty()
	_end_btn.disabled = _playing or combat.state != Combat.State.PLAYER_ACTION
	# The toggle stays live even mid-animation. It used to grey out with End
	# Turn, which was right for a one-shot "do it now" button and wrong for a
	# setting: the moment you most want to switch autoplay off is while it is
	# busy playing a card you did not choose.
	_gauge.set_pp(p.pp, p.max_pp, p.pp_cap, p.overload)
	if _relics and run:
		_relics.setup(run.relics)
	_rebuild_potions()
	_update_playable()

func _rebuild_potions() -> void:
	for c in _potion_bar.get_children():
		c.queue_free()
	if run == null:
		return
	for pot in run.potions:
		var b := Button.new()
		b.text = pot.title
		b.disabled = _playing or combat.state != Combat.State.PLAYER_ACTION
		if pot == _selected_potion:
			b.modulate = Palette.SPARK
		b.pressed.connect(_on_potion.bind(pot))
		_potion_bar.add_child(b)

## Skips straight to the reward screen. The fight really is won -- same events,
## same handoff -- so what gets tested downstream is the real reward flow.
func _on_dev_win() -> void:
	if _playing or combat == null or combat.result != Combat.Result.ONGOING:
		return
	_playing = true
	combat.dev_win()
	_finish_playback()

## The hover panel: a card's full uncropped text and the meaning of every
## keyword on it, or a combatant's statuses spelled out.
func _update_tip(m: Vector2, hot: CardView) -> void:
	if _tip == null:
		return
	# A panel of rules text following the card you are already holding is in the
	# way of the thing you are aiming at.
	if _drag_view != null:
		_tip.hide()
		return
	var frame := Vector2(960, 540)
	if hot != null and hot.card != null:
		_tip.show_card(hot.card, m, frame)
		return
	for v in _enemy_views + [_player_view]:
		if v != null and v.hit_test(m):
			_tip.show_entity(v.combatant, m, frame)
			return
	_tip.hide()

func _pile_for(which: StringName) -> Array:
	match which:
		&"draw":    return combat.draw_pile
		&"discard": return combat.discard_pile
		_:          return combat.exhaust_pile

## Lists a pile's contents, grouped and counted. The draw pile is shown sorted
## rather than in order: revealing the actual sequence would hand the player the
## next five draws, which is a different game.
## Gives a HUD button an opaque plate in the palette.
##
## Godot's default button style is translucent. Over a flat menu that is fine;
## over the battle scene the dithered ground transition showed straight through
## "Auto" and left its label sitting on a checkerboard. A control the player has
## to click must be legible against whatever the scene puts behind it.
func _plate(b: Button) -> void:
	for spec in [["normal", Palette.GROUND, Palette.BORDER],
			["hover", Palette.SURFACE, Palette.INK_MUTED],
			["pressed", Palette.SURFACE, Palette.QUENCH_BRIGHT],
			["focus", Palette.GROUND, Palette.SPARK],
			["disabled", Palette.GROUND, Palette.BORDER]]:
		var style := StyleBoxFlat.new()
		style.bg_color = spec[1]
		style.border_color = spec[2]
		style.set_border_width_all(2)
		style.set_content_margin_all(4)
		b.add_theme_stylebox_override(spec[0], style)
	b.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)

func _show_pile(which: StringName) -> void:
	if _pile_panel and is_instance_valid(_pile_panel):
		_pile_panel.queue_free()
	var counts := {}
	for c in _pile_for(which):
		var title: String = c.title()
		counts[title] = int(counts.get(title, 0)) + 1
	var names := counts.keys()
	names.sort()

	var panel := PanelContainer.new()
	panel.z_index = 250
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.GROUND
	style.border_color = Palette.BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	panel.add_child(col)
	var head := Label.new()
	head.text = "%s pile — %d card%s" % [
		String(which), _pile_for(which).size(),
		"" if _pile_for(which).size() == 1 else "s"]
	head.add_theme_color_override("font_color", Palette.BONE)
	col.add_child(head)
	if which == &"draw":
		var note := Label.new()
		note.text = "(shown sorted, not in draw order)"
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Palette.INK_MUTED)
		col.add_child(note)
	for n in names:
		var row := Label.new()
		row.text = "%d x %s" % [counts[n], n]
		row.add_theme_color_override("font_color", Palette.INK_LIGHT)
		col.add_child(row)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.4)
		panel.queue_free()
		_pile_panel = null)
	col.add_child(close)

	panel.position = Vector2(12, 150)
	add_child(panel)
	_pile_panel = panel
	close.call_deferred("grab_focus")

## Says which state it is in. The toggled-on stylebox alone is a border colour,
## which is not enough to hang "the game is playing my turns for me" on.
func _sync_auto_btn() -> void:
	if _auto_btn:
		_auto_btn.text = "Auto: on" if auto_play else "Auto: off"

func _cycle_speed() -> void:
	Juice.speed_scale = {1.0: 2.0, 2.0: 4.0, 4.0: 1.0}.get(Juice.speed_scale, 1.0)
	_speed_btn.text = "Speed %dx" % int(Juice.speed_scale)

# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if combat == null or _playing or combat.state != Combat.State.PLAYER_ACTION:
		return
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		if _drag_view != null:
			_drag_to(m)
			for v in _enemy_views:
				v.set_hover(v.hit_test(m) and v.combatant.is_alive())
			return
		var hot := _hand.card_at(m)
		for v in _hand.views:
			v.set_hover(v == hot and v.playable)
		for v in _enemy_views:
			v.set_hover(v.hit_test(m))
		_update_tip(m, hot)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed:
			var hot := _hand.card_at(m)
			if hot != null and hot.playable:
				_begin_drag(hot, m)
				return
			for v in _enemy_views:
				if v.hit_test(m) and v.combatant.is_alive():
					_on_target(v.combatant)
					return
			if hot:
				_on_card(hot.card)
		else:
			_end_drag(m)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_drag()
		_selected_card = null
		_selected_potion = null
		_update_playable()

# --- drag to play ----------------------------------------------------------

func _begin_drag(view: CardView, at: Vector2) -> void:
	_drag_view = view
	_dragging = false
	_drag_grab = view.position - _hand.to_local(at)

## Follows the cursor once the press has travelled past the slop threshold.
func _drag_to(at: Vector2) -> void:
	if _drag_view == null or not is_instance_valid(_drag_view):
		_drag_view = null
		return
	var local := _hand.to_local(at)
	if not _dragging:
		if (local + _drag_grab).distance_to(_drag_view.home_pos) < DRAG_SLOP:
			return
		_dragging = true
		_drag_view.set_dragging(true)
		# A card in hand is the selected card while it is being carried, so the
		# targeting highlight is the same one the click flow already lights up.
		_selected_card = _drag_view.card
		_selected_potion = null
		_update_playable()
	_drag_view.position = local + _drag_grab

## Resolves the release. A press that never became a drag falls through to the
## original click behaviour rather than being swallowed.
func _end_drag(at: Vector2) -> void:
	var view := _drag_view
	_drag_view = null
	if view == null or not is_instance_valid(view):
		return
	if not _dragging:
		_on_card(view.card)
		return
	_dragging = false
	view.set_dragging(false)
	var card := view.card
	if card == null or not combat.can_play(card):
		_return_card(view)
		return
	if card.data.needs_target():
		for v in _enemy_views:
			if v.hit_test(at) and v.combatant.is_alive():
				_play_card(card, v.combatant)
				return
		_return_card(view)
		return
	# Untargeted: dropping it onto the board plays it, dropping it back into the
	# fan is how you change your mind.
	if at.y < DROP_LINE:
		_play_card(card, null)
	else:
		_return_card(view)

func _cancel_drag() -> void:
	if _drag_view != null and is_instance_valid(_drag_view):
		if _dragging:
			_drag_view.set_dragging(false)
			_return_card(_drag_view)
	_drag_view = null
	_dragging = false

func _return_card(view: CardView) -> void:
	_selected_card = null
	view.glide_to(view.home_pos, view.home_rot)
	_update_playable()

func _on_card(card: Card) -> void:
	if not combat.can_play(card):
		return
	if card.data.needs_target():
		_selected_card = null if _selected_card == card else card
		_selected_potion = null
		_update_playable()
		return
	_play_card(card, null)

func _on_target(target: Combatant) -> void:
	if _selected_potion != null:
		_drink(_selected_potion, target)
	elif _selected_card != null:
		_play_card(_selected_card, target)

func _play_card(card: Card, target: Combatant) -> void:
	var view := _hand.find_for(card)
	if not combat.play_card(card, target):
		return
	_selected_card = null
	# The simulation has ALREADY resolved by this line. Mark the view busy here
	# rather than when playback starts: otherwise the card's whole flight is a
	# window in which _playing is false, the end-turn button is live and a
	# second click is accepted -- and that second action strands the first
	# card's events on the queue behind a stale gauge.
	_playing = true
	_update_playable()
	if view:
		_hand.remove_view(view)
		_hand.layout()
		# Effects resolve when the card lands, not when it leaves the hand --
		# so the number appears at the moment of impact.
		# The motion matches the card's own illustration: attacks lunge at the
		# thing they hit, ramp rises into the gauge, cash-out pours downward.
		var style := CardArt.motif_for(card.data)
		# A contact move is carried by the Pokemon crossing the field, so the card
		# stays at the centre and fades. Sending both at the enemy is two things
		# animating one swing.
		if card.data.contact:
			style = &""
		var aim := PLAY_CENTRE
		match style:
			&"blade":
				var tv := _view_for(target)
				if tv:
					aim = tv.global_position - Vector2(0, 30)
			&"ramp":
				aim = _gauge.global_position + Vector2(40, 12)
		# Weather moves change the sky as well as the rules. Keyed by card id so
		# adding another is a one-line edit rather than a new mechanism.
		if _weather:
			_weather.on_move(card.data.id)
		Audio.play(&"card_play", 1.0, 0.6)
		# The burst fires on the same callback the effects resolve on, so the
		# flourish and the damage number land on the same frame instead of the
		# card quietly reaching the middle and something happening later.
		var land := aim if style == &"blade" else PLAY_CENTRE
		view.play_to(PLAY_CENTRE, DISCARD_POS, func():
			_card_landed(card, land)
			_finish_playback(), style, aim)
	else:
		_finish_playback()

## Eye candy for the instant a card is placed, scaled by what it cost.
##
## A 0-cost cantrip gets a small pop and no screen movement; a three-Mana
## finisher gets a wide ring, a shower of sparks, a real shake and a frame of
## hitstop. Cost is the only thing the player spends, so it is the thing the
## feedback should be keyed to.
func _card_landed(card: Card, at: Vector2) -> void:
	var cost := card.cost()
	var power := clampf(0.55 + float(cost) * 0.38, 0.55, 1.8)
	# A contact move gets its burst where the Pokemon actually connects,
	# fired from the damage event. One here as well would flash at the centre
	# of an empty field a beat before anything was hit.
	if _fx and not card.data.contact:
		_fx.burst(at, card.data.element, power)
	Juice.shake(1.6 * power)
	# Only the expensive ones stop time. A hitstop on every cantrip turns a
	# fast turn into a stutter.
	if cost >= 2:
		Juice.hitstop(0.035)

func _on_potion(pot: PotionData) -> void:
	# The potion buttons are only re-enabled by _refresh_hud(), which does not
	# run until the card in flight lands -- so for the whole of a card's
	# animation they look live and _drink() had nothing stopping it. A potion
	# taken in that window really did resolve, folding its events into the
	# middle of the card's playback.
	if _playing or combat == null or combat.state != Combat.State.PLAYER_ACTION:
		return
	if pot.needs_target():
		_selected_potion = null if _selected_potion == pot else pot
		_selected_card = null
		_update_playable()
		return
	_drink(pot, null)

func _drink(pot: PotionData, target: Combatant) -> void:
	if not combat.use_potion(pot, target):
		return
	if run:
		run.discard_potion(pot)
	_selected_potion = null
	Juice.popup(pot.title, Palette.VIOLET, PLAY_CENTRE)
	_play_events()

func _on_end_turn() -> void:
	if _playing or combat.state != Combat.State.PLAYER_ACTION:
		return
	_selected_card = null
	_selected_potion = null
	for v in _hand.views:
		var t := create_tween()
		t.tween_property(v, "position", DISCARD_POS, Juice.dur(0.2)).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(v, "modulate:a", 0.0, Juice.dur(0.2))
		t.tween_callback(v.queue_free)
	_hand.views.clear()
	combat.end_turn()
	_play_events()

func _show_result() -> void:
	var won := combat.result == Combat.Result.VICTORY
	_end_btn.hide()
	_continue_btn.show()
	await _show_banner("VICTORY" if won else "DEFEAT",
		Palette.SPARK if won else Palette.ALARM, 0.8)
	_banner.text = "VICTORY" if won else "DEFEAT"
	_banner.modulate.a = 1.0

func _report_finished() -> void:
	if _finished:
		return
	_finished = true
	Juice.speed_scale = 1.0
	Juice.reset()
	combat_finished.emit(combat.result)

func _exit_tree() -> void:
	# A hitstop in flight must never outlive the screen that started it.
	Juice.reset()
