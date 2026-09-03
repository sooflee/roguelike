class_name Intent
extends RefCounted
## What an enemy has telegraphed for its next turn. Shown to the player before
## they commit -- telegraphing is what makes this a game of decisions rather
## than a game of guesses.

enum Kind { ATTACK, DEFEND, BUFF, DEBUFF, ATTACK_DEBUFF, ATTACK_DEFEND, UNKNOWN, SLEEP }

var kind: Kind = Kind.UNKNOWN
var damage: int = 0
var hits: int = 1
var move_id: StringName = &""
## A short phrase naming what this move does beyond its damage number, straight
## from the move data. Without it a move that drains the PP curve and a move
## that applies Weak both read as "ATTACK 4 + weaken".
var tell: String = ""

func _init(p_kind: Kind = Kind.UNKNOWN, p_damage: int = 0, p_hits: int = 1, p_move: StringName = &"") -> void:
	kind = p_kind
	damage = p_damage
	hits = p_hits
	move_id = p_move

## The move's name as the player should read it. Every enemy move id is already
## a real Pokemon move, so the name exists -- it was simply never shown, and the
## intent line read "ATTACK 7" when it could have said "Water Gun".
func move_name() -> String:
	return String(move_id).capitalize()

func total_damage() -> int:
	return damage * hits

func _to_string() -> String:
	if damage > 0:
		return "%s %dx%d" % [Kind.keys()[kind], damage, hits]
	return Kind.keys()[kind]
