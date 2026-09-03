class_name VisualEvent
extends RefCounted
## A record of something that happened in the simulation, for the view to replay.
##
## The simulation NEVER awaits animation. It mutates state immediately and appends
## VisualEvents to Combat.event_queue. A presentation node drains that queue and
## plays tweens at whatever speed it likes -- fast, slow, or skipped entirely.
##
## This split is why combat is headlessly testable and why animation bugs can
## never corrupt game state.

const DAMAGE := &"damage"
const BLOCK_GAIN := &"block_gain"
const BLOCK_LOST := &"block_lost"
const HEAL := &"heal"
const DEATH := &"death"
const STATUS_APPLIED := &"status_applied"
const STATUS_EXPIRED := &"status_expired"
const CARD_DRAWN := &"card_drawn"
const CARD_PLAYED := &"card_played"
const CARD_DISCARDED := &"card_discarded"
const CARD_EXHAUSTED := &"card_exhausted"
const DECK_RESHUFFLED := &"deck_reshuffled"
const PP_CHANGED := &"pp_changed"
const OVERLOADED := &"overloaded"
const EFFECTIVENESS := &"effectiveness"
const RAMP_DRAINED := &"ramp_drained"
const INTENT_SET := &"intent_set"
const TURN_START := &"turn_start"
const TURN_END := &"turn_end"
const COMBAT_END := &"combat_end"

var kind: StringName
var data: Dictionary

func _init(p_kind: StringName, p_data: Dictionary = {}) -> void:
	kind = p_kind
	data = p_data

func _to_string() -> String:
	return "[%s %s]" % [kind, data]
