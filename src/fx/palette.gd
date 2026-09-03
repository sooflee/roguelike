class_name Palette
extends RefCounted
## Named colours from assets/palette/endesga-32.gpl.
##
## Every colour in the game comes from here. A literal Color(...) anywhere else
## is a bug -- that is how a 32-colour palette quietly becomes a 200-colour one.
##
## EMBER is reserved for PP and the Overloaded state. Nothing else may use it, so
## "hot" always reads at a glance (docs/ART_BIBLE.md §3).

const GROUND       := Color("181425")
const SURFACE      := Color("262b44")
const BORDER       := Color("3a4466")
const INK_MUTED    := Color("5a6988")
const INK_MID      := Color("8b9bb4")
const INK_LIGHT    := Color("c0cbdc")
const WHITE        := Color("ffffff")

const EMBER        := Color("f77622")   # RESERVED: PP / Overload
const FLAME        := Color("feae34")
const SPARK        := Color("fee761")
const EMBER_DEEP   := Color("be4a2f")
const EMBER_MID    := Color("d77643")

const BLOOD        := Color("a22633")
const RED          := Color("e43b44")
const ROSE         := Color("f6757a")
const ALARM        := Color("ff0044")

const QUENCH       := Color("0099db")   # Block
const QUENCH_DEEP  := Color("124e89")
const QUENCH_BRIGHT:= Color("2ce8f5")

const MOSS         := Color("63c74d")
const MOSS_DARK    := Color("3e8948")

const VIOLET       := Color("b55088")   # buffs / powers
const VIOLET_DARK  := Color("68386c")

const RUST         := Color("733e39")
const LEATHER      := Color("b86f50")
const CLAY         := Color("c28569")
const SAND         := Color("e8b796")
const SKIN         := Color("e4a672")
const BONE         := Color("ead4aa")
const SHADOW       := Color("3e2731")
const TEAL_DARK    := Color("193c3e")

## Outline colour. Never pure black -- art bible rule 2.
const OUTLINE      := SHADOW

static func for_status(id: StringName) -> Color:
	match id:
		&"strength":   return RED
		&"dexterity":  return QUENCH
		&"vulnerable": return VIOLET
		&"weak":       return VIOLET_DARK
		&"frail":      return INK_MUTED
		&"kindling": return EMBER
		&"afterburn":  return FLAME
		_:             return INK_LIGHT

static func for_card_type(t: int) -> Color:
	match t:
		CardData.Type.ATTACK: return EMBER_DEEP
		CardData.Type.SKILL:  return QUENCH_DEEP
		CardData.Type.POWER:  return VIOLET_DARK
		_:                    return INK_MUTED

## Ramps from cool to ember as the PP curve climbs. The screen literally warms
## up as the fight opens out -- the mechanic IS the visual.
static func pp_tint(max_pp: int, cap: int) -> Color:
	var t := clampf(float(max_pp) / float(maxi(1, cap)), 0.0, 1.0)
	return INK_MUTED.lerp(EMBER, t)
