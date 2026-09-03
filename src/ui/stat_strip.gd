class_name StatStrip
extends VBoxContainer
## The run's vitals, as icons rather than words.
##
## This was a two-line BBCode string reading "HP 75/75  Gold 99  Deck 5  Floor 0"
## over "Bag: Leppa Berry, Blast Seed". Four labels the player re-reads every
## screen, and a bag whose width grew with the length of the item names. Icons
## are read at a glance and are a fixed width whatever is in them -- the same
## argument RelicStrip already makes for held items.

## Exactly 2x the 12px glyphs IconArt draws. A non-integer factor puts a
## pixel-art icon on half pixels, which is the one thing the art bible does
## not forgive (D-05).
const ICON := 24
const PAIR_GAP := 5
const GROUP_GAP := 16

## The deck counter is the one vital you can act on: it opens the deck.
signal deck_clicked

var _hp: Label
var _gold: Label
var _deck: Label
var _seed: Label
var _bag_row: HBoxContainer
var _bag_empty: Label

func _ready() -> void:
	add_theme_constant_override("separation", 2)

	var vitals := HBoxContainer.new()
	vitals.add_theme_constant_override("separation", GROUP_GAP)
	add_child(vitals)
	_hp = _pair(vitals, "hud_hp", Palette.ROSE, "Health")
	_gold = _pair(vitals, "hud_gold", Palette.SPARK, "Gold")
	_deck = _pair(vitals, "hud_deck", Palette.INK_LIGHT,
		"Moves in your deck — click to look through them",
		func(): deck_clicked.emit())
	_seed = _plain(vitals, Palette.INK_MUTED)

	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", PAIR_GAP)
	add_child(_bag_row)
	var bag := TextureRect.new()
	bag.texture = IconArt.hud("hud_bag")
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bag.custom_minimum_size = Vector2(ICON, ICON)
	bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag.tooltip_text = "Bag"
	_bag_row.add_child(bag)
	_bag_empty = Label.new()
	_bag_empty.add_theme_font_size_override("font_size", 13)
	_bag_empty.add_theme_color_override("font_color", Palette.INK_MUTED)
	_bag_empty.text = "empty"
	_bag_row.add_child(_bag_empty)

## An icon and the number beside it, as one group so they never wrap apart.
## `on_click` makes the group a control rather than a readout.
func _pair(into: HBoxContainer, glyph: String, colour: Color, tip: String,
		on_click: Callable = Callable()) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", PAIR_GAP)
	box.tooltip_text = tip
	# PASS, not IGNORE: the group has to receive the hover to show its tooltip,
	# but must not swallow clicks meant for whatever is underneath.
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	into.add_child(box)
	var icon := TextureRect.new()
	icon.texture = IconArt.hud(glyph)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	if on_click.is_valid():
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		# Brightening on hover rather than switching to a hand cursor: the run
		# sets its own poke ball cursor for CURSOR_ARROW only, so asking for a
		# pointing hand here would drop the OS arrow back into the game.
		box.mouse_entered.connect(func(): icon.modulate = Color(1.35, 1.35, 1.35))
		box.mouse_exited.connect(func(): icon.modulate = Color.WHITE)
		box.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed \
					and e.button_index == MOUSE_BUTTON_LEFT:
				on_click.call())
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", colour)
	box.add_child(l)
	return l

func _plain(into: HBoxContainer, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", colour)
	into.add_child(l)
	return l

func refresh(run: RunState, seed_note: String = "") -> void:
	if run == null:
		return
	_hp.text = "%d/%d" % [run.hp, run.max_hp]
	# Red once the next hit could plausibly end the run, so the number itself
	# carries the warning rather than only the bar on the combat screen.
	_hp.add_theme_color_override("font_color",
		Palette.RED if run.hp <= run.max_hp / 4 else Palette.ROSE)
	_gold.text = str(run.gold)
	_deck.text = str(run.deck.size())
	_seed.text = seed_note

	for c in _bag_row.get_children():
		if c.has_meta("potion"):
			c.queue_free()
	_bag_empty.visible = run.potions.is_empty()
	for p in run.potions:
		var t := TextureRect.new()
		t.set_meta("potion", true)
		t.texture = IconArt.for_item(p.id)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(ICON, ICON)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# The names are no longer written out, so the tooltip is the only place
		# they survive.
		t.tooltip_text = "%s — %s" % [p.title, p.text]
		_bag_row.add_child(t)

## Blanked on the title screen, where there is no run behind it.
func clear() -> void:
	_hp.text = ""
	_gold.text = ""
	_deck.text = ""
	_seed.text = ""
	_bag_empty.visible = false
	for c in _bag_row.get_children():
		if c.has_meta("potion"):
			c.queue_free()
