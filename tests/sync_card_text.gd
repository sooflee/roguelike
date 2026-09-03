extends Node
## Maintenance tool: rewrites every card's authored `text` from its own effects.
##
## Card text must exactly equal CardData.describe(false) -- a test asserts it for
## all 61 (D-24). That guard is what makes the upgraded-rank text trustworthy,
## but it also means any rename of a status, keyword or resource invalidates
## every card that mentions it. Editing those by hand is how a rename becomes a
## day's work and a source of typos.
##
## Run it after any wording change:  ./tools/sync_text.sh

const PATH := "res://data/cards/emberwright.json"

func _ready() -> void:
	CardLibrary.load_all()
	var raw := FileAccess.get_file_as_string(PATH)
	var rows = JSON.parse_string(raw)
	if typeof(rows) != TYPE_ARRAY:
		printerr("could not parse %s" % PATH)
		get_tree().quit(1)
		return
	var changed := 0
	for row in rows:
		var data := CardLibrary.get_card(StringName(row.get("id", "")))
		if data == null:
			continue
		var want := data.describe(false)
		if String(row.get("text", "")) != want:
			print("  %-16s %s" % [row["id"], want])
			row["text"] = want
			changed += 1
	if changed > 0:
		# Rewritten in place; the compact house formatting is restored by the
		# shell wrapper, which owns the layout rules.
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "  "))
		f.close()
	print("sync_card_text: %d card%s rewritten" % [changed, "" if changed == 1 else "s"])
	get_tree().quit(0)
