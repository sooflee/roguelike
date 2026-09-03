class_name TipPanel
extends PanelContainer
## The one place the game explains itself.
##
## Emberwright had no tooltips at all outside the relic strip. Every status
## already carries a written `description` and none was ever rendered; Ramp,
## Overload and "Overloaded:" were never defined anywhere; and a card's rules
## text is clipped by its own 96x132 frame, so the reward screen could show a
## card whose text the player cannot finish reading.
##
## One hover panel answers all three.

const KEYWORDS := {
	"Ramp": "Ramp N — your PP refill grows by N for the rest of the fight. You gain nothing the turn you play it. Already at maximum, you gain N PP instead.",
	"Overload": "Overload N — gain N PP now and owe N. Every refill is reduced by what you owe, and you pay off only 1 a turn. Borrowing 1 costs 1; borrowing 4 costs 10.",
	"Overloaded": "Overloaded — this bonus applies for as long as you still owe PP, so a deep debt keeps it switched on for several turns.",
	"Exhaust": "Exhaust — the card leaves play for the rest of this combat.",
	"Block": "Block — absorbs damage, then is lost at the start of your turn.",
	"Dampened": "Dampened — your Overload debt stops paying itself down. Kill the source or write the debt off yourself.",
	"Simmer": "Simmer — this enemy grows stronger at the end of its turn unless you damaged it since its last one.",
}

var _text: RichTextLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300
	custom_minimum_size = Vector2(280, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.GROUND
	style.border_color = Palette.BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(264, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	hide()

## Everything worth saying about a card: its full text, uncropped, plus a line
## for every keyword it uses.
func show_card(card: Card, at: Vector2, frame: Vector2) -> void:
	var body := "[b]%s[/b]   [color=%s]%d PP[/color]   [color=%s]%s[/color]\n%s" % [
		card.title(), Palette.SPARK.to_html(false), card.cost(),
		Element.colour(card.data.element).to_html(false),
		Element.label(card.data.element), card.describe()]
	_present(body + _keyword_lines(card.describe()), at, frame)

func show_entity(who: Combatant, at: Vector2, frame: Vector2) -> void:
	# `display_name`, not `name`: a Combatant is a RefCounted, so `who.name`
	# threw on every hover and the panel rendered nothing at all. Every status in
	# the game carries a written description and not one of them had ever
	# reached the screen.
	var body := "[b]%s[/b]   %d/%d HP" % [who.display_name, who.hp, who.max_hp]
	var seen := ""
	for st in who._ordered_statuses():
		var line: String = st.description
		# Only the descriptions written with a placeholder take the stack count;
		# the others are complete sentences already.
		if line.contains("%d"):
			line = line % st.stacks
		seen += "\n[color=%s]%s %d[/color] — %s" % [
			Palette.INK_MID.to_html(false), st.display_name, st.stacks, line]
	if seen == "":
		hide()
		return
	_present(body + seen, at, frame)

func _keyword_lines(text: String) -> String:
	var out := ""
	for word in KEYWORDS:
		if text.contains(word):
			out += "\n[color=%s]%s[/color]" % [Palette.INK_MID.to_html(false), KEYWORDS[word]]
	return out

func _present(body: String, at: Vector2, frame: Vector2) -> void:
	_text.text = body
	show()
	# Placed after a frame so fit_content has produced a real height to clamp
	# against; otherwise the panel hangs off the bottom on its first showing.
	await get_tree().process_frame
	var s := size
	position = Vector2(
		clampf(at.x + 18.0, 4.0, frame.x - s.x - 4.0),
		clampf(at.y - s.y - 12.0, 4.0, frame.y - s.y - 4.0))
