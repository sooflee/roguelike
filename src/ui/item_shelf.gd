class_name ItemShelf
extends Control
## A shelf of held items and consumables, drawn as objects on a shelf rather
## than as a list of "Name — description (40 gold)" text rows.
##
## The shop's whole job is comparison, and a wall of prose is the worst possible
## surface for it: the price, the sprite and the name all arrive at once here,
## and a sold-out slot reads as an empty peg instead of the word SOLD.
##
## Descriptions move to the hover tooltip -- the same trade the relic strip and
## the card picker already make, so the meta screens all behave the same way.

signal item_chosen(index)
## Emitted with the entry under the cursor, or an empty dict when it leaves.
signal item_hovered(entry)

const TILE := Vector2(132.0, 96.0)
const GAP := 12.0
const ICON := 44.0

## Each entry: {icon, title, price, sold, buyable, note}.
var entries: Array = []
var _hot := -1
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	set_process(true)

func setup(p_entries: Array) -> void:
	entries = p_entries
	_hot = -1
	custom_minimum_size = Vector2(0, TILE.y + GAP)
	queue_redraw()

func _process(delta: float) -> void:
	if Juice.intensity <= 0.0:
		return
	_time += delta
	queue_redraw()

func _rect_of(i: int) -> Rect2:
	var per_row: int = maxi(1, int((size.x + GAP) / (TILE.x + GAP)))
	var count: int = mini(per_row, entries.size() - (i / per_row) * per_row)
	var total := (TILE.x + GAP) * float(count) - GAP
	var start := (size.x - total) * 0.5
	return Rect2(Vector2(start + float(i % per_row) * (TILE.x + GAP),
		float(i / per_row) * (TILE.y + GAP)), TILE)

func _draw() -> void:
	var per_row: int = maxi(1, int((size.x + GAP) / (TILE.x + GAP)))
	var rows: int = int(ceil(float(entries.size()) / float(per_row)))
	custom_minimum_size = Vector2(0, (TILE.y + GAP) * float(rows))

	var font := ThemeDB.fallback_font
	for i in entries.size():
		var e: Dictionary = entries[i]
		var r := _rect_of(i)
		var sold: bool = e.get("sold", false)
		var buyable: bool = e.get("buyable", true) and not sold

		draw_rect(r.grow(1.0), Palette.OUTLINE)
		draw_rect(r, Palette.SURFACE if buyable else Palette.GROUND)
		var border := Palette.SPARK if (i == _hot and buyable) else Palette.BORDER
		draw_rect(r, border, false, 2.0)

		if sold:
			# An empty peg, not the word SOLD: the shelf says what is gone by
			# looking gone.
			draw_string(font, r.position + Vector2(0, TILE.y * 0.5 + 4), "sold",
				HORIZONTAL_ALIGNMENT_CENTER, TILE.x, 13, Palette.INK_MUTED)
			continue

		# Each item bobs on its own phase, so a shelf reads as objects sitting
		# on it rather than as a grid of buttons.
		var bob := 0.0
		if Juice.intensity > 0.0:
			bob = sin(_time * 2.0 + float(i) * 0.9) * 1.6 * Juice.intensity
		var icon: Texture2D = e.get("icon")
		if icon:
			draw_texture_rect(icon, Rect2(
				r.position + Vector2((TILE.x - ICON) * 0.5, 8.0 + bob),
				Vector2(ICON, ICON)), false,
				Color.WHITE if buyable else Color(1, 1, 1, 0.45))

		draw_string(font, r.position + Vector2(0, TILE.y - 26.0),
			String(e.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, TILE.x, 12,
			Palette.INK_LIGHT if buyable else Palette.INK_MUTED)
		draw_string(font, r.position + Vector2(0, TILE.y - 8.0),
			"%d gold" % int(e.get("price", 0)), HORIZONTAL_ALIGNMENT_CENTER, TILE.x, 12,
			Palette.SPARK if buyable else Palette.INK_MUTED)

func _at(point: Vector2) -> int:
	for i in entries.size():
		if _rect_of(i).has_point(point):
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hot := _at(event.position)
		if hot != _hot:
			_hot = hot
			queue_redraw()
			item_hovered.emit(entries[hot] if hot >= 0 else {})
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _at(event.position)
		if i >= 0:
			var e: Dictionary = entries[i]
			if e.get("buyable", true) and not e.get("sold", false):
				Audio.play(&"gold", 1.0, 0.6)
				item_chosen.emit(i)
			else:
				Audio.play(&"ui", 0.6, 0.5)

## Why a slot is out of reach, on the tile itself. The shop used to explain a
## greyed-out row only in a tooltip attached to a disabled button, which never
## fired -- a disabled Control does not receive mouse events.
func _get_tooltip(at_position: Vector2) -> String:
	var i := _at(at_position)
	if i < 0:
		return ""
	var e: Dictionary = entries[i]
	var out := "%s\n%s" % [e.get("title", ""), e.get("text", "")]
	var note := String(e.get("note", ""))
	if note != "":
		out += "\n" + note
	return out
