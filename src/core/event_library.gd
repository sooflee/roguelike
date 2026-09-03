class_name EventLibrary
extends RefCounted
## Map events, loaded from data/events/*.json.

const EVENT_DIR := "res://data/events/"

static var _events: Dictionary = {}
static var _loaded := false

static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_events.clear()
	var dir := DirAccess.open(EVENT_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(EVENT_DIR + file))
		if typeof(parsed) != TYPE_ARRAY:
			push_error("EventLibrary: %s must contain a JSON array" % file)
			continue
		for entry in parsed:
			_events[StringName(entry.get("id", ""))] = entry
	_loaded = true

static func get_event(id: StringName) -> Dictionary:
	load_all()
	return _events.get(id, {})

static func all() -> Array:
	load_all()
	return _events.values()

## Picks an event the player has not already seen this run.
static func pick(seen: Array) -> Dictionary:
	load_all()
	var pool := all().filter(func(e): return not seen.has(String(e.get("id", ""))))
	if pool.is_empty():
		pool = all()
	if pool.is_empty():
		return {}
	return Rng.pick_in(&"events", pool)

## Why a choice cannot be taken right now, or "" if it can.
##
## A choice may carry a `requires` block naming what the run must already have.
## This is the point of the whole mechanism: `lose_gold` only takes what is
## there, so "Lose 60 gold. Obtain a relic." hands a broke player a free relic.
## Requirements also keep an event from killing anyone -- an option that costs
## HP is only offered while you can survive it.
static func unmet_requirement(run: RunState, choice: Dictionary) -> String:
	var required: Dictionary = choice.get("requires", {})
	for key in required:
		var value = required[key]
		match StringName(key):
			&"gold":
				if run.gold < int(value):
					return "Requires %d gold." % int(value)
			&"hp_above":
				if run.hp <= int(value):
					return "Requires more than %d HP." % int(value)
			&"deck_above":
				if run.deck.size() <= int(value):
					return "Requires more than %d cards in your deck." % int(value)
			&"upgradeable_card":
				if bool(value) and run.upgradeable_cards().is_empty():
					return "Requires a card left to upgrade."
			&"free_potion_slot":
				if bool(value) and run.potions.size() >= RunState.POTION_SLOTS:
					return "Requires a free potion slot."
			&"relic":
				if not run.has_relic(StringName(value)):
					var r := ItemLibrary.get_relic(StringName(value))
					return "Requires %s." % (r.title if r else String(value))
			&"not_relic":
				# For a choice that hands over a NAMED held item. RunState.add_relic
				# refuses a duplicate silently, so without this the choice reads as
				# available, is taken, and gives nothing.
				if run.has_relic(StringName(value)):
					var held := ItemLibrary.get_relic(StringName(value))
					return "You already carry %s." % (held.title if held else String(value))
			_:
				push_error("EventLibrary: unknown requirement '%s'" % key)
	return ""

## Indices of the choices the run can actually take. Never empty in practice --
## every event is authored with an unconditional way out, asserted in tests.
static func available_choices(run: RunState, event: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var choices: Array = event.get("choices", [])
	for i in choices.size():
		if unmet_requirement(run, choices[i]) == "":
			out.append(i)
	return out

## Resolves one choice. Returns the lines describing what happened, or nothing
## at all if the choice was not available.
static func choose(run: RunState, event: Dictionary, index: int) -> Array[String]:
	var choices: Array = event.get("choices", [])
	if index < 0 or index >= choices.size():
		return [] as Array[String]
	var choice: Dictionary = choices[index]
	# Enforced here rather than only in the screen that draws the buttons: a
	# gate the UI owns is only as strong as the UI.
	if unmet_requirement(run, choice) != "":
		return [] as Array[String]
	return RunEffects.apply_all(run, choice.get("effects", []))
