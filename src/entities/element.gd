class_name Element
extends RefCounted
## Move and creature types, and the matchup chart between them.
##
## This is the genre's defining mechanic and it drops almost exactly onto the
## damage pipeline that already exists: Combatant.calculate_damage runs an
## ordered chain of multiplicative modifiers, which is what a type chart is.
## Effectiveness is applied LAST, after Strength-style additive bonuses and
## after Weak/Vulnerable, so "super effective" doubles the number the player
## actually sees rather than some intermediate value.

enum Kind { NORMAL, FIRE, WATER, GRASS, ELECTRIC, ROCK, FLYING, POISON,
	STEEL, FIGHTING, PSYCHIC, DRAGON }

const SUPER := 2.0
const RESIST := 0.5

## attacker -> { defender: multiplier }. Only non-neutral pairs are listed;
## anything absent is 1.0. Trimmed to the eight types this act uses rather than
## the full chart, because a matchup the player can never meet is a rule they
## have to learn for nothing.
const CHART := {
	Kind.NORMAL:   {Kind.ROCK: RESIST},
	Kind.FIRE:     {Kind.GRASS: SUPER, Kind.FIRE: RESIST, Kind.WATER: RESIST, Kind.ROCK: RESIST},
	Kind.WATER:    {Kind.FIRE: SUPER, Kind.ROCK: SUPER, Kind.WATER: RESIST, Kind.GRASS: RESIST},
	Kind.GRASS:    {Kind.WATER: SUPER, Kind.ROCK: SUPER, Kind.FIRE: RESIST, Kind.GRASS: RESIST,
					Kind.FLYING: RESIST, Kind.POISON: RESIST},
	Kind.ELECTRIC: {Kind.WATER: SUPER, Kind.FLYING: SUPER, Kind.ELECTRIC: RESIST, Kind.GRASS: RESIST},
	Kind.ROCK:     {Kind.FIRE: SUPER, Kind.FLYING: SUPER},
	Kind.FLYING:   {Kind.GRASS: SUPER, Kind.ELECTRIC: RESIST, Kind.ROCK: RESIST},
	Kind.POISON:   {Kind.GRASS: SUPER, Kind.POISON: RESIST, Kind.ROCK: RESIST, Kind.STEEL: 0.0},
	Kind.STEEL:    {Kind.ROCK: SUPER, Kind.FIRE: RESIST, Kind.WATER: RESIST,
					Kind.ELECTRIC: RESIST, Kind.STEEL: RESIST},
	Kind.FIGHTING: {Kind.NORMAL: SUPER, Kind.ROCK: SUPER, Kind.STEEL: SUPER,
					Kind.POISON: RESIST, Kind.FLYING: RESIST, Kind.PSYCHIC: RESIST},
	Kind.PSYCHIC:  {Kind.FIGHTING: SUPER, Kind.POISON: SUPER, Kind.PSYCHIC: RESIST,
					Kind.STEEL: RESIST},
	Kind.DRAGON:   {Kind.DRAGON: SUPER, Kind.STEEL: RESIST},
}

static func multiplier(attack: int, defend: int) -> float:
	var row: Dictionary = CHART.get(attack, {})
	return float(row.get(defend, 1.0))

static func label(kind: int) -> String:
	return String(Kind.keys()[clampi(kind, 0, Kind.size() - 1)]).capitalize()

## Parsed from JSON. Unknown or missing types fall back to Normal rather than
## erroring, so a half-written data file still loads and the game still runs.
static func from_string(s) -> int:
	var key := String(s).to_upper()
	var i: int = Kind.keys().find(key)
	return i if i >= 0 else Kind.NORMAL

## The colour a type reads as. Palette constants only (D-08).
static func colour(kind: int) -> Color:
	match kind:
		Kind.STEEL:    return Palette.INK_MID
		Kind.FIGHTING: return Palette.BLOOD
		Kind.PSYCHIC:  return Palette.ROSE
		Kind.DRAGON:   return Palette.QUENCH_DEEP
		Kind.FIRE:     return Palette.EMBER_DEEP
		Kind.WATER:    return Palette.QUENCH
		Kind.GRASS:    return Palette.MOSS
		Kind.ELECTRIC: return Palette.SPARK
		Kind.ROCK:     return Palette.LEATHER
		Kind.FLYING:   return Palette.INK_LIGHT
		Kind.POISON:   return Palette.VIOLET
		_:             return Palette.BONE
