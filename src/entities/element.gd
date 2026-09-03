class_name Element
extends RefCounted
## Move and creature types, and the matchup chart between them.
##
## Effectiveness here is a FLAT ADJUSTMENT, not a multiplier: a good matchup adds
## 2 damage and a bad one takes 2 away, floored at 0. Pokemon doubles and halves;
## this does not, deliberately.
##
## A multiplier scales with the hit, which makes the matchup worth almost nothing
## on a cheap card and enormous on an expensive one -- doubling a 20-damage
## finisher is worth +20, doubling Ember is worth +3. A flat 2 is worth the most
## to the small, frequent cards and barely registers on the big ones, so type is
## a reason to play a different card rather than a multiplier on the card you
## were always going to play.
##
## Applied LAST, after Strength-style bonuses and after Weak/Vulnerable, so the
## adjustment lands on the number the player can already see.

enum Kind { NORMAL, FIRE, WATER, GRASS, ELECTRIC, ROCK, FLYING, POISON,
	STEEL, FIGHTING, PSYCHIC, DRAGON }

const SUPER := 2
const RESIST := -2
## Poison cannot touch Steel at all. Additive effectiveness has no way to
## spell "nothing happens", so immunity stays its own value rather than a
## bigger negative that a large enough hit would punch through.
## Unreachable in Act 1 -- no enemy is Steel -- but the rule is real.
const IMMUNE := -9999

## attacker -> { defender: damage adjustment }. Only non-neutral pairs are
## listed; anything absent is 0. Trimmed to the eight types this act uses rather than
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
	Kind.POISON:   {Kind.GRASS: SUPER, Kind.POISON: RESIST, Kind.ROCK: RESIST, Kind.STEEL: IMMUNE},
	Kind.STEEL:    {Kind.ROCK: SUPER, Kind.FIRE: RESIST, Kind.WATER: RESIST,
					Kind.ELECTRIC: RESIST, Kind.STEEL: RESIST},
	Kind.FIGHTING: {Kind.NORMAL: SUPER, Kind.ROCK: SUPER, Kind.STEEL: SUPER,
					Kind.POISON: RESIST, Kind.FLYING: RESIST, Kind.PSYCHIC: RESIST},
	Kind.PSYCHIC:  {Kind.FIGHTING: SUPER, Kind.POISON: SUPER, Kind.PSYCHIC: RESIST,
					Kind.STEEL: RESIST},
	Kind.DRAGON:   {Kind.DRAGON: SUPER, Kind.STEEL: RESIST},
}

## Damage to add for this matchup. 0 is neutral, and the caller floors the
## total at zero -- a resisted 1-damage hit does nothing rather than healing.
static func bonus(attack: int, defend: int) -> int:
	var row: Dictionary = CHART.get(attack, {})
	return int(row.get(defend, 0))

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
