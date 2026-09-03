class_name Enemy
extends Combatant
## An enemy with a scripted move list and a telegraphed intent.
##
## Moves are chosen one turn AHEAD so the player always sees the intent before
## deciding. `roll_intent()` picks; `perform()` executes what was picked.
##
## Three things above a weighted roll turn an enemy into a puzzle rather than a
## damage faucet, and every Act 1 enemy used to be the latter (D-28):
##
##   OPENING    -- a fixed opening the player can learn and plan around, the way
##                 you learn that a Cracked Golem guards before it swings.
##   CONDITION  -- a move that is only legal in a state the player controls, so
##                 the enemy's behaviour is an argument with the player's own
##                 choices rather than a dice roll they watch.
##   PASSIVE    -- effects that resolve at the start of its turn no matter what
##                 it does, which is how an enemy poses a standing problem
##                 (a guard that comes back) instead of a per-turn one.

var enemy_id: StringName = &""
var moves: Array = []              ## Array[Dictionary] from data
## Move ids performed on the first turns of the fight, in order, before the
## weighted roll takes over. Not `script` -- that name is taken by Object.
var opening: Array = []
## Effects resolved at the start of every one of its turns, after Block clears.
var passives: Array[CardEffect] = []
## What those passives do, in words, shown beside the enemy's statuses. A
## passive is the one thing an enemy does that neither the intent line nor a
## status icon names, so without this the player learns it by watching a Block
## bar refill and guessing why.
var passive_text: String = ""
var intent: Intent = Intent.new()
var _pending_move: Dictionary = {}
var _history: Array[StringName] = []
var turn_count: int = 0

func _init(p_id: StringName = &"", p_name: String = "", p_max_hp: int = 1) -> void:
	super(p_name, p_max_hp)
	enemy_id = p_id

## Chooses the next move: the opening first while it lasts, then a weighted roll
## over whatever is currently legal. `max_consecutive` stops an enemy spamming a
## single dangerous attack; `condition` gates a move on the state of the fight.
func roll_intent() -> void:
	var chosen := _scripted_move()
	if chosen.is_empty():
		chosen = _weighted_pick(_eligible_moves())
	if chosen.is_empty():
		return
	_pending_move = chosen
	intent = _intent_for(_pending_move)
	_emit(VisualEvent.INTENT_SET, {"who": self, "intent": intent})

## The opening. Indexed by turns already taken, so it is still correct when the
## intent for turn N is rolled at the end of turn N-1.
func _scripted_move() -> Dictionary:
	if turn_count >= opening.size():
		return {}
	var want := StringName(opening[turn_count])
	for m in moves:
		if StringName(m.get("id", "")) == want:
			return m
	push_error("Enemy %s: scripted move '%s' is not in its move list" % [enemy_id, want])
	return {}

func _eligible_moves() -> Array:
	var eligible: Array = []
	for m in moves:
		if _is_eligible(m):
			eligible.append(m)
	if eligible.is_empty():
		# Never leave an enemy with nothing to do. Conditions narrow the choice;
		# they must not be able to stall the fight into a draw.
		eligible = moves.filter(func(m): return not m.has("condition"))
		if eligible.is_empty():
			eligible = moves.duplicate()
	return eligible

func _weighted_pick(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total := 0
	for m in pool:
		total += int(m.get("weight", 1))
	var roll := Rng.stream(&"enemy_ai").randi_range(1, maxi(1, total))
	var acc := 0
	for m in pool:
		acc += int(m.get("weight", 1))
		if roll <= acc:
			return m
	return pool[0]

func _is_eligible(m: Dictionary) -> bool:
	if not _condition_met(m.get("condition", {})):
		return false
	var limit := int(m.get("max_consecutive", 0))
	if limit <= 0:
		return true
	var id := StringName(m.get("id", ""))
	if _history.size() < limit:
		return true
	for i in range(_history.size() - limit, _history.size()):
		if _history[i] != id:
			return true
	return false

## Gates on the state of the fight. Every condition here is something the player
## can see and act on -- that is the requirement for one to exist at all, since
## a hidden condition just reads as the enemy behaving at random.
func _condition_met(cond) -> bool:
	if typeof(cond) != TYPE_DICTIONARY or cond.is_empty():
		return true
	var value := float(cond.get("value", 0))
	match StringName(cond.get("type", "")):
		&"hp_below":
			return float(hp) / maxf(1.0, float(max_hp)) < value
		&"hp_above":
			return float(hp) / maxf(1.0, float(max_hp)) >= value
		&"turn_at_least":
			return turn_count >= int(value)
		&"player_overloaded":
			return combat != null and combat.player.is_overloaded()
		&"player_not_overloaded":
			return combat != null and not combat.player.is_overloaded()
		&"player_has_block":
			return combat != null and combat.player.block >= int(value)
		&"alone":
			return combat != null and combat.living_enemies().size() <= 1
		_:
			push_error("Enemy %s: unknown move condition '%s'" % [enemy_id, cond.get("type", "")])
			return true

func _intent_for(m: Dictionary) -> Intent:
	var kind_name := String(m.get("intent", "UNKNOWN")).to_upper()
	var kind: int = Intent.Kind.get(kind_name, Intent.Kind.UNKNOWN) if Intent.Kind.has(kind_name) else Intent.Kind.UNKNOWN
	var i := Intent.new(kind, int(m.get("damage", 0)), int(m.get("hits", 1)), StringName(m.get("id", "")))
	# A new mechanic the intent line cannot name is a mechanic the player only
	# learns by being hit with it. `tell` is how each move says what it is about
	# to do to you in its own words.
	i.tell = String(m.get("tell", ""))
	return i

## Standing effects, resolved before the move. Runs after Combatant.on_turn_start
## has cleared Block, which is what lets a passive put the same guard back up
## every turn instead of stacking one on top of the last.
func on_turn_start() -> void:
	super()
	if passives.is_empty() or combat == null:
		return
	var ctx := EffectContext.new(combat, self, [combat.player])
	for eff in passives:
		if not is_alive():
			return
		eff.execute(ctx)

## Executes the telegraphed move. Effects are the same CardEffect resources the
## player uses -- one effect system, no duplicated combat rules.
func perform(combat_ref) -> void:
	if _pending_move.is_empty():
		return
	turn_count += 1
	_history.append(StringName(_pending_move.get("id", "")))
	var ctx := EffectContext.new(combat_ref, self, [combat_ref.player])
	for eff in EffectFactory.build_list(_pending_move.get("effects", [])):
		if not is_alive():
			break
		eff.execute(ctx)
