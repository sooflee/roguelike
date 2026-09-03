class_name TitleView
extends Control
## The start-up screen: full-bleed art, a partner carousel, and one button.
##
## No veil over the art. This screen has almost no text to protect, so the
## scene gets to be the whole picture -- which is the point of a title screen.

signal new_run_requested
signal continue_requested

const FRAME := Vector2(960, 540)
const SPARKS := 30

## The name on the tin. Changing it changes the wordmark and nothing else --
## the sizing below reads the rendered texture rather than counting letters.
const TITLE_TEXT := "POKEMON THUGLIFE"
## The widest the wordmark is allowed to grow. It is a ceiling, not a target:
## the scale is the largest whole number that fits under it, because D-07 says
## pixel art never rides a fractional factor and a wordmark is all straight
## edges, which is where a 4.9x blur is most obvious.
const MARK_MAX_W := 560.0
## The factor the letterforms were drawn for. Without a cap a short title would
## be scaled up into a billboard just because it had room.
const MARK_SCALE_CAP := 5
const MARK_Y := 36.0

## Sized so a 3x sprite fits: the tallest partner's art is 44px in its cell,
## and 44 * 3 = 132 needs a box bigger than the old 144 once padded.
const SLOT := Vector2(160, 160)
const SLOT_Y := 150.0
## One whole-number scale for every partner. Filling each box exactly would
## mean a different fractional factor per creature, which puts three different
## pixel sizes side by side in one row (D-05).
const SLOT_ZOOM := 3.0
const SLOT_GAP := 24.0
## Centre-to-centre distance between two neighbouring slots.
const SLOT_PITCH := SLOT.x + SLOT_GAP

## The roster, left to right, focused entry first. Charmander leads because he
## is the only one who can actually set out; the other two stand to his right
## as silhouettes, so the screen reads as a choice that opens up later rather
## than as one option dressed up to look like three. Unlocking one is a `locked`
## flag, not a rewrite of this screen.
##
## `cue` is the voice clip a partner answers with when he takes the middle slot.
## It hangs off the entry rather than off `locked` because Audio.play() no-ops
## silently on a cue with no file behind it -- so a typo would look exactly like
## a partner who is meant to stay quiet. Dratini and Ralts carry no key at all
## and say nothing, which sells the lock better than a UI blip would.
const ROSTER := [
	{"id": &"charmander", "name": "CHARMANDER", "locked": false,
		"cue": &"charmander_select"},
	{"id": &"dratini",    "name": "DRATINI",    "locked": true},
	{"id": &"ralts",      "name": "RALTS",      "locked": true},
]

## How fast the row slides to the newly focused slot. Fast enough that holding
## an arrow key does not queue up a backlog of travel.
const CAROUSEL_EASE := 16.0

var _sparks: Array[Vector3] = []
var _time: float = 0.0
var _has_save := false
var _start_btn: Button
var _slots: Array[Panel] = []
var _name_label: Label
var _hint_label: Label
## Which roster entry is in the middle. `_carousel` is where the row actually
## is; it chases `_focus` so the slide is animated, and the two only differ
## mid-move.
var _focus := 0
var _carousel := 0.0
## The entry whose cue has already been spoken for this stay in the middle.
## Keyed on arrival rather than on the keypress, so holding an arrow against the
## end of the row does not make Charmander stammer.
var _voiced := -1
var _motes: Node2D = null

func setup(has_save: bool) -> void:
	_has_save = has_save

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# And an explicit size. Anchoring alone left this Control 0x0 depending on
	# when its parent laid out, which took the full-rect background down with it
	# -- everything else here is positioned in absolute frame coordinates and so
	# carried on drawing, leaving the screen on a flat grey void.
	size = FRAME
	mouse_filter = Control.MOUSE_FILTER_PASS

	var art := TextureRect.new()
	art.texture = PlaceholderArt.for_background(&"route")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = FRAME
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var motes := _Motes.new()
	motes.owner_view = self
	add_child(motes)
	_motes = motes

	_wordmark()
	_caption("Choose your partner.", 118, 15, Palette.INK_LIGHT)

	for i in ROSTER.size():
		var entry: Dictionary = ROSTER[i]
		var locked: bool = entry["locked"]
		var tex: Texture2D = PlaceholderArt.for_partner_locked(entry["id"]) if locked \
			else PlaceholderArt.for_player_front()
		var slot := _starter_slot(tex, locked)
		_slots.append(slot)
		var index := i
		slot.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_focus_on(index))

	# The name and the reason you cannot pick it are one line each, under the
	# row, because they change together every time the carousel moves.
	_name_label = _caption("", 322, 17, Palette.BONE)
	_hint_label = _caption("", 348, 13, Palette.INK_MID)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.position = Vector2(FRAME.x * 0.5 - 120, 396)
	menu.custom_minimum_size = Vector2(240, 0)
	add_child(menu)
	if _has_save:
		_menu_button(menu, "Continue run", func(): continue_requested.emit())
	_start_btn = _menu_button(menu, "Start", func(): new_run_requested.emit())

	for i in SPARKS:
		_sparks.append(Vector3(randf() * FRAME.x, randf() * FRAME.y, 12.0 + randf() * 22.0))
	# Charmander is centred and Start is pre-selected on arrival, because
	# refusing to start until you click the only option available is a puzzle,
	# not a choice.
	_focus_on(0, false)
	_start_btn.call_deferred("grab_focus")
	set_process(true)
	set_process_input(true)

## The logo, sized off the texture rather than off the letter count.
##
## The width used to be the literal 65 that "EMBERWRIGHT" happens to measure, in
## two places -- so renaming the game left the logo off-centre and, at a long
## enough name, hanging off the frame.
func _wordmark() -> void:
	var tex := TitleArt.wordmark(TITLE_TEXT)
	var px := Vector2(tex.get_width(), tex.get_height())
	var factor := clampi(int(MARK_MAX_W / px.x), 1, MARK_SCALE_CAP)
	var mark := TextureRect.new()
	mark.texture = tex
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.stretch_mode = TextureRect.STRETCH_SCALE
	mark.size = px * factor
	mark.position = Vector2(roundf((FRAME.x - mark.size.x) * 0.5), MARK_Y)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)

func _starter_slot(tex: Texture2D, locked: bool) -> Panel:
	var slot := Panel.new()
	slot.size = SLOT
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(slot)
	var mon := StarterView.new()
	mon.set_anchors_preset(Control.PRESET_FULL_RECT)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(mon)
	mon.setup(tex, SLOT_ZOOM)
	# Centre the ART, not the cell. These sprites carry a lot of empty cell --
	# 42px of Charmander in a 96px box -- so centring the cell leaves the
	# creature adrift in the middle of its own padding.
	var cell := float(tex.get_height())
	var art := CreatureScale.content_rect(tex)
	if art.size.y > 0:
		var art_mid := Vector2(art.position) + Vector2(art.size) * 0.5
		mon.content_offset = (Vector2(cell, cell) * 0.5 - art_mid) * SLOT_ZOOM
	if locked:
		# The real sprite, tinted down to a shape. Multiplying by a dark palette
		# entry withholds the reveal without a second set of art, and it is why
		# these are the published sprites and not generated blobs: the shape has
		# to be the one you will eventually unlock.
		# The texture is already colourless (for_partner_locked); modulate here
		# would only re-tint the grey it just produced.
		# Still, not bobbing: a locked partner that breathes reads as waiting to be
		# picked rather than as shut away.
		mon.still = true
	return slot

## Move `i` into the middle slot. The single place the screen's state changes.
func _focus_on(i: int, animate: bool = true) -> void:
	# Clamped, not wrapped: at the near end of the row, "back" running round to
	# the far end is a jump, and the row is short enough that you can see there
	# is nothing further left.
	_focus = clampi(i, 0, ROSTER.size() - 1)
	if not animate or Juice.intensity <= 0.0:
		_carousel = float(_focus)

	var entry: Dictionary = ROSTER[_focus]
	var locked: bool = entry["locked"]
	# A locked partner keeps its name to itself. The slot is already a flat
	# silhouette so the species cannot be read off the art -- printing the name
	# underneath gave away the one thing the silhouette exists to withhold.
	_name_label.text = "???" if locked else entry["name"]
	_name_label.add_theme_color_override("font_color",
		Palette.INK_MUTED if locked else Palette.BONE)
	# Say why, rather than leaving a dead Start button to be interpreted. A
	# control that refuses without a reason reads as a bug -- but say it
	# without naming the partner either.
	_hint_label.text = "This one will not travel with you yet." if locked else ""

	# Also on first arrival, and it is deliberate: two of the three ways onto
	# this screen are the player pressing "Set out again", so the greeting is
	# answering something they did. Voicing him on the carousel but not on the
	# way in would be a rule with a hole in it, and the clip is a third of a
	# second -- a hello, not a stinger.
	if _voiced != _focus:
		_voiced = _focus
		var cue: StringName = entry.get("cue", &"")
		if cue != &"":
			# No pitch or retrigger handling here: Audio.play() already guards
			# 45ms and jitters the pitch itself.
			Audio.play(cue, 1.0, 0.95)

	for s in _slots.size():
		_style_slot(_slots[s], ROSTER[s]["locked"], s == _focus)
	if _start_btn:
		# Re-armed, not merely re-enabled: disabling a Button drops its focus, so
		# coming back from a locked slot would otherwise leave the keyboard
		# pointing at nothing. Only on the transition, or an accidental arrow
		# press would yank focus off "Continue run".
		var rearmed: bool = _start_btn.disabled and not locked
		_start_btn.disabled = locked
		if rearmed:
			_start_btn.call_deferred("grab_focus")
	_layout()

func _style_slot(slot: Panel, locked: bool, focused: bool) -> void:
	var box := StyleBoxFlat.new()
	# A locked slot sits back -- darker plate, dimmer border -- so the row still
	# has an obvious subject rather than three things competing for the click.
	# A locked plate is OPAQUE. At 78% the route showed through it, and a flat
	# grey silhouette over sunlit grass has nothing to read against -- Ralts all
	# but disappeared. Solid also says "shuttered" where the open slot is a
	# window onto the same country the run happens in.
	box.bg_color = Palette.GROUND if locked else Color(Palette.GROUND, 0.55)
	if focused:
		box.border_color = Palette.SPARK
	else:
		box.border_color = Palette.SURFACE if locked else Palette.BORDER
	box.set_border_width_all(3 if focused else 2)
	slot.add_theme_stylebox_override("panel", box)

## Places the row for the current `_carousel` position.
func _layout() -> void:
	for i in _slots.size():
		var offset := float(i) - _carousel
		var slot: Panel = _slots[i]
		# Rounded: a slot landing on a half pixel puts the sprite inside it on
		# the half pixel too, and nearest-neighbour turns that into a wobble.
		slot.position = Vector2(
			roundf(FRAME.x * 0.5 - SLOT.x * 0.5 + offset * SLOT_PITCH), SLOT_Y)
		# Everything off centre stands back, so the eye lands on the partner
		# being chosen and not on the row.
		# A gentle recede, not a fade to a ghost. At 0.35 per slot the far one
		# bottomed out at 0.28 alpha, which let the route show straight through
		# the plate and left Ralts' silhouette with nothing to read against.
		slot.modulate.a = clampf(1.0 - absf(offset) * 0.12, 0.82, 1.0)

func _input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("ui_right", true):
		step = 1
	elif event.is_action_pressed("ui_left", true):
		step = -1
	if step == 0:
		return
	# Claimed before the focused Start button can read it as focus navigation.
	# On this screen left and right mean the carousel and nothing else.
	get_viewport().set_input_as_handled()
	_focus_on(_focus + step)

func _caption(text: String, y: float, size: int, colour: Color,
		cx: float = 480.0, width: float = 500.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(cx - width * 0.5, y)
	l.size = Vector2(width, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _menu_button(into: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 38)
	# Godot's default chrome is rounded and grey; against pixel art it reads as
	# an operating system sitting on top of the game. Every state has to be
	# overridden or it falls back to that -- "disabled" included, now that a
	# locked partner in the middle slot keeps Start there for real stretches.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.SURFACE if state in ["hover", "pressed", "focus"] \
			else Palette.GROUND
		if state in ["hover", "focus"]:
			box.border_color = Palette.SPARK
		else:
			# Disabled keeps the plate but loses the edge, so it reads as part of
			# the frame rather than as a control that is ignoring you.
			box.border_color = Palette.SURFACE if state == "disabled" else Palette.BORDER
		box.set_border_width_all(2)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Palette.INK_LIGHT)
	b.add_theme_color_override("font_hover_color", Palette.BONE)
	b.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)
	b.pressed.connect(func():
		Audio.play(&"ui", 1.0, 0.5)
		cb.call())
	into.add_child(b)
	return b

func _process(delta: float) -> void:
	# The carousel settles even under reduce motion -- it is a layout, not a
	# flourish, and a row parked between two slots is just wrong.
	if not is_equal_approx(_carousel, float(_focus)):
		if Juice.intensity <= 0.0:
			_carousel = float(_focus)
		else:
			_carousel = lerpf(_carousel, float(_focus),
				clampf(delta * CAROUSEL_EASE, 0.0, 1.0))
			if absf(_carousel - float(_focus)) < 0.005:
				_carousel = float(_focus)
		_layout()
	if Juice.intensity <= 0.0:
		return
	_time += delta
	for i in _sparks.size():
		var s: Vector3 = _sparks[i]
		s.y -= s.z * delta
		s.x += sin(_time * 1.3 + float(i)) * 10.0 * delta
		if s.y < -4.0:
			s = Vector3(randf() * FRAME.x, FRAME.y + 20.0, 12.0 + randf() * 22.0)
		_sparks[i] = s
	# The MOTES node draws the sparks, not this Control -- which has no _draw()
	# at all, so redrawing it invalidated nothing and the specks sat still while
	# their positions kept updating in memory.
	if _motes:
		_motes.queue_redraw()
	queue_redraw()

## Drifting motes, above the art and below the wordmark.
class _Motes extends Node2D:
	var owner_view: TitleView

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		if owner_view == null:
			return
		for s in owner_view._sparks:
			var fade: float = clampf(s.y / 540.0, 0.15, 0.9)
			draw_rect(Rect2(roundf(s.x), roundf(s.y), 2, 2), Color(Palette.BONE, fade))
