class_name Player
extends Combatant
## The Emberwright. Owns the PP curve.
##
## PP is both the cost of every card and the thing the class plays games with.
## It opens at 1 and climbs by one each turn to a ceiling, so the shape of a
## combat is fixed: turn one is a single cheap card, turn five is a full hand.
## The class earns its identity by breaking that curve in two directions --
## RAMP arrives at the ceiling early, OVERLOAD borrows against the future.
##
## Overload is a debt, not a swap. It shrinks every refill until it is paid off,
## and it only pays down one point a turn, so the interest is quadratic: one
## borrowed costs one, four borrowed costs ten. That curve is the whole gamble.

## PP available on turn one, and the ceiling the ramp climbs to.
const PP_START := 1
const PP_CAP := 5
## The refill can be drained by enemies, but never below this -- a curve at zero
## is a turn with no decisions in it, which is a worse punishment than losing.
const MANA_FLOOR := 1
## How much Overload debt is written off at the start of each turn. One, so the
## interest on Overload N is N + (N-1) + ... + 1: borrowing a little is nearly
## free, borrowing deep digs a hole you climb out of a rung at a time.
const OVERLOAD_DECAY := 1

var gold: int = 0

## Spendable right now.
var pp: int = 0
## This combat's refill. Climbs by one at the start of every turn, and
## permanently by any Ramp effect -- never past `pp_cap`.
##
## Opens one BELOW the turn-one value: the ramp fires on every turn including
## the first, so this is what leaves turn one sitting at PP_START.
var max_pp: int = PP_START - 1
## The hard ceiling. Relics raise it; the ramp cannot climb past it.
var pp_cap: int = PP_CAP
## PP borrowed against the future. Subtracted from EVERY refill until it is
## paid off, and it only pays down `OVERLOAD_DECAY` a turn. See D-27.
var overload: int = 0
## Relic-set. Combat applies it; the player never sees a cost below zero.
var discount_first_card: bool = false

## Defaults to RunState.STARTING_HP rather than repeating it: two copies of the
## starting HP is two places to change and one to forget.
func _init(p_name: String = "Charmander", p_max_hp: int = RunState.STARTING_HP) -> void:
	super(p_name, p_max_hp)
	is_player = true
	element = Element.Kind.FIRE

func is_overloaded() -> bool:
	return overload > 0

func at_pp_cap() -> bool:
	return max_pp >= pp_cap

# --- spending --------------------------------------------------------------

func spend_pp(amount: int) -> bool:
	if pp < amount:
		return false
	pp -= amount
	_emit_pp()
	return true

func gain_pp(amount: int) -> void:
	if amount == 0:
		return
	pp = maxi(0, pp + amount)
	_emit_pp()

## Spends up to `amount` and reports what was actually spent -- the cash-out
## half of the class, where leftover PP becomes damage or Block.
func drain_pp(amount: int) -> int:
	var spent := mini(pp, maxi(0, amount))
	if spent > 0:
		pp -= spent
		_emit_pp()
	return spent

# --- the two ways to break the curve ---------------------------------------

## Permanently raises this combat's refill. Ramp is an INVESTMENT: it grants no
## PP now, only a bigger refill from here on, which is what makes it a real
## turn-one decision rather than a free accelerant.
## Returns how much the ceiling actually moved -- zero once already at the cap.
func ramp_pp(amount: int) -> int:
	var before := max_pp
	max_pp = clampi(max_pp + amount, 0, pp_cap)
	if max_pp != before:
		_emit_pp()
	return max_pp - before

## Borrows against the future: PP now, and a debt that shrinks your refill
## every turn until it is paid off one point at a time.
##
## This used to be charged once and wiped, which made it a nought-per-cent loan:
## N PP now for exactly N PP later, always worth taking, never a decision.
## Carrying the debt is what turns it into a gamble -- and it is also what makes
## `Overloaded:` a stance you hold and pay rent on rather than a one-turn combo.
func overload_pp(amount: int) -> void:
	if amount <= 0:
		return
	pp += amount
	overload += amount
	_emit(VisualEvent.OVERLOADED, {"who": self, "amount": amount, "overload": overload})
	_emit_pp()
	for st in _ordered_statuses():
		st.on_overload(self, amount, combat)

## Writes off the debt before it comes due -- the release valve.
func clear_overload() -> int:
	var cleared := overload
	if cleared > 0:
		overload = 0
		_emit_pp()
	return cleared

# --- turn ------------------------------------------------------------------

func on_turn_start() -> void:
	super()
	max_pp = mini(max_pp + 1, pp_cap)
	# Charged in full BEFORE any of it is written off, so a debt of 1 still costs
	# exactly one PP on exactly one turn -- the small borrow behaves as it
	# always did, and only the greedy one lingers.
	var owed := overload
	pp = maxi(0, max_pp - owed)
	if not has_status(&"dampened"):
		overload = maxi(0, overload - OVERLOAD_DECAY)
	_emit_pp(owed)

## An enemy eating the curve itself. Lowers the refill for the rest of the
## combat; Ramp is the answer, which is what finally makes Ramp a defensive
## card rather than purely a greedy one.
func drain_ramp(amount: int) -> int:
	var before := max_pp
	max_pp = maxi(MANA_FLOOR, max_pp - maxi(0, amount))
	var lost := before - max_pp
	if lost > 0:
		_emit(VisualEvent.RAMP_DRAINED, {"who": self, "amount": lost, "max": max_pp})
		_emit_pp()
	return lost

func _emit_pp(owed: int = 0) -> void:
	_emit(VisualEvent.PP_CHANGED, {
		"who": self, "pp": pp, "max": max_pp, "cap": pp_cap,
		"overload": overload, "owed": owed,
	})
