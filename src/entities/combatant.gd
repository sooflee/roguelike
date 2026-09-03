class_name Combatant
extends RefCounted
## Base for anything with HP, Block and statuses. Pure data + rules; no nodes.

signal died(who)

var display_name: String = ""
var max_hp: int = 1
var hp: int = 1
var block: int = 0
## This creature's own type, for incoming matchups.
var element: int = Element.Kind.NORMAL
var statuses: Dictionary = {}  ## StringName -> StatusEffect instance
var combat = null              ## back-reference, set by Combat
var is_player: bool = false
## Real height in metres, as the Pokedex gives it. Drives how large the view
## draws this creature -- see CreatureScale.
var height_m: float = 0.6
## Whether HP was lost since this combatant's own last turn ended. Read by
## statuses that care about being left alone (see SimmerStatus); reset in
## on_turn_end AFTER the hooks, so the flag covers the whole round.
var took_damage: bool = false

func _init(p_name: String = "", p_max_hp: int = 1) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp

func is_alive() -> bool:
	return hp > 0

# --- Statuses --------------------------------------------------------------

func _ordered_statuses() -> Array:
	var list := statuses.values()
	list.sort_custom(func(a, b): return a.apply_order < b.apply_order)
	return list

func has_status(id: StringName) -> bool:
	return statuses.has(id) and statuses[id].stacks != 0

func status_stacks(id: StringName) -> int:
	return statuses[id].stacks if statuses.has(id) else 0

## `proto` is duplicated so each combatant owns its own stack counter.
func apply_status(proto: StatusEffect, amount: int) -> void:
	if amount == 0:
		return
	var st: StatusEffect
	if statuses.has(proto.id):
		st = statuses[proto.id]
	else:
		st = proto.duplicate(true)
		st.stacks = 0
		statuses[st.id] = st
		st.on_applied(self, combat)
	st.stacks = clampi(st.stacks + amount, -st.max_stacks, st.max_stacks)
	_emit(VisualEvent.STATUS_APPLIED, {"who": self, "id": st.id, "stacks": st.stacks, "delta": amount})
	if st.stacks == 0:
		remove_status(st.id)

func remove_status(id: StringName) -> void:
	if not statuses.has(id):
		return
	var st: StatusEffect = statuses[id]
	st.on_removed(self, combat)
	statuses.erase(id)
	_emit(VisualEvent.STATUS_EXPIRED, {"who": self, "id": id})

# --- Damage pipeline -------------------------------------------------------

## Order is load-bearing: additive source modifiers, then multiplicative source
## modifiers, then target modifiers, then floor. See StatusEffect.apply_order.
## `move_element` is the TYPE OF THE MOVE, not of the attacker -- a Charmander
## using a Normal move gets no fire matchup. -1 means "untyped", used by effects
## with no move behind them (relics, potions, self-damage).
func calculate_damage(base: int, target: Combatant, is_attack: bool = true,
		move_element: int = -1) -> int:
	var ctx := {"is_attack": is_attack, "source": self, "target": target}
	var amount := float(base)
	for st in _ordered_statuses():
		amount = st.modify_outgoing_damage(amount, ctx)
	for st in target._ordered_statuses():
		amount = st.modify_incoming_damage(amount, ctx)
	# Type effectiveness resolves LAST, so the adjustment lands on the number
	# the player can already see rather than on an intermediate value. Flat,
	# not a multiplier -- see Element.
	if is_attack and move_element >= 0:
		amount += float(Element.bonus(move_element, target.element))
	return maxi(0, int(floor(amount)))

## Applies already-calculated damage. Block absorbs first.
## `element` is carried purely so the VIEW can colour the hit to the move that
## caused it. Nothing in the rules reads it; -1 means untyped.
func take_damage(amount: int, source = null, bypass_block: bool = false,
		element: int = -1, contact: bool = false) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var remaining := amount
	if not bypass_block and block > 0:
		var absorbed := mini(block, remaining)
		block -= absorbed
		remaining -= absorbed
		_emit(VisualEvent.BLOCK_LOST, {"who": self, "amount": absorbed, "block": block})
	if remaining > 0:
		hp = maxi(0, hp - remaining)
		took_damage = true
		_emit(VisualEvent.DAMAGE, {"who": self, "source": source, "amount": remaining,
			"hp": hp, "max_hp": max_hp, "element": element, "contact": contact})
	if hp == 0:
		_emit(VisualEvent.DEATH, {"who": self})
		died.emit(self)
	return remaining

func gain_block(base: int) -> int:
	if base <= 0:
		return 0
	var amount := float(base)
	var ctx := {"source": self}
	for st in _ordered_statuses():
		amount = st.modify_block_gain(amount, ctx)
	var final := maxi(0, int(floor(amount)))
	block += final
	_emit(VisualEvent.BLOCK_GAIN, {"who": self, "amount": final, "block": block})
	return final

func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	var healed := hp - before
	if healed > 0:
		_emit(VisualEvent.HEAL, {"who": self, "amount": healed, "hp": hp})
	return healed

# --- Turn lifecycle --------------------------------------------------------

func on_turn_start() -> void:
	# Block does not persist between your own turns (Spire convention).
	if block > 0:
		block = 0
		_emit(VisualEvent.BLOCK_LOST, {"who": self, "amount": 0, "block": 0, "reason": "turn_start"})
	for st in _ordered_statuses():
		st.on_turn_start(self, combat)

func on_turn_end() -> void:
	for st in _ordered_statuses():
		st.on_turn_end(self, combat)
	# Decay after hooks so a status is still active for its own end-of-turn effect.
	for st in _ordered_statuses():
		if st.decays_at_turn_end and st.stacks > 0:
			apply_status(st, -1)
	took_damage = false

func _emit(kind: StringName, data: Dictionary) -> void:
	if combat:
		combat.push_event(kind, data)
