class_name DeckView
extends Control
## Every move in the deck, as real cards, over the top of whatever asked for it.
##
## An overlay rather than a screen of its own. Checking the deck is something
## the player does in the MIDDLE of a decision -- which reward to take, which
## move to have Charmander forget, whether this shop card is a duplicate -- so
## routing it through the run screen's state machine would mean either losing
## that half-made decision or reconstructing it on the way back. Nothing
## underneath is touched here, which makes closing free and exact.

signal closed

const PAD := 20.0
const FRAME := Vector2(960, 540)

func setup(cards: Array) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# And an explicit size, BEFORE any child is added. The run screen is a plain
	# Control, not a container, so anchors alone left this at 0x0 -- the veil
	# covered a corner, the heading and the button piled up in it and the cards
	# had no room to lay out at all. TitleView hit the same trap.
	size = FRAME
	# STOP, not PASS: this is modal. A click falling through to the reward row
	# underneath would take a card the player cannot currently even see.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var veil := ColorRect.new()
	veil.color = Color(Palette.GROUND, 0.93)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, PAD)
	add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var heading := Label.new()
	heading.text = "Your moves — %d" % cards.size()
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Palette.BONE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A deck wider than the frame would mean cards half off the side with no way
	# to reach them; CardPicker already wraps to a grid, so it only needs height.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var picker := CardPicker.new()
	# Nothing here is takeable. Left interactive the picker takes focus off the
	# close button and emits card_chosen into a signal nobody is listening to.
	picker.display_only = true
	scroll.add_child(picker)
	picker.setup(_sorted(cards))

	col.add_child(_close_button())

## Cost first, then name. A deck read back in draw order is a list of
## coincidences; what the player opened this for is "what do I have, and what
## does it cost me" -- and duplicates only read as duplicates when adjacent.
func _sorted(cards: Array) -> Array:
	var out := cards.duplicate()
	out.sort_custom(func(a, b) -> bool:
		if a.cost() != b.cost():
			return a.cost() < b.cost()
		return a.title() < b.title())
	return out

func _close_button() -> Button:
	var b := Button.new()
	b.text = "Close"
	b.custom_minimum_size = Vector2(200, 36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Matches the title screen's menu chrome. Godot's default is rounded grey,
	# which reads as an operating system sitting on top of the game.
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.GROUND if state == "normal" else Palette.SURFACE
		box.border_color = Palette.SPARK if state in ["hover", "focus"] else Palette.BORDER
		box.set_border_width_all(2)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Palette.INK_LIGHT)
	b.add_theme_color_override("font_hover_color", Palette.BONE)
	b.pressed.connect(_close)
	b.call_deferred("grab_focus")
	return b

func _close() -> void:
	Audio.play(&"ui", 1.0, 0.5)
	closed.emit()

## Escape closes, because a modal that can only be dismissed by finding its
## button is a modal the player feels stuck in.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_close()

## Clicking off the cards closes too. This fires only for clicks that reached
## the overlay itself -- the scroll region and the button are both above it and
## handle their own.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_close()
