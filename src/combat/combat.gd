class_name Combat
extends RefCounted
## The combat simulation. Pure logic -- no nodes, no awaits, no tweens.
##
## Everything here resolves instantly and synchronously. Visual consequences are
## appended to `event_queue` for a presentation node to drain at its own pace.
## That separation is why this class is testable with `godot --headless` and why
## an animation bug can never desync game state.

signal state_changed(new_state)
signal events_available

enum State { NONE, COMBAT_START, TURN_START, PLAYER_ACTION, TURN_END, ENEMY_TURN, COMBAT_END }
enum Result { ONGOING, VICTORY, DEFEAT }

const HAND_SIZE := 5
const MAX_HAND := 10

var player: Player
var enemies: Array[Enemy] = []

var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var exhaust_pile: Array[Card] = []

var state: State = State.NONE
var result: Result = Result.ONGOING
var turn: int = 0
var cards_played_this_turn: int = 0

var event_queue: Array[VisualEvent] = []

## RelicData held for the run. Relics reuse CardEffect, so there is no second
## effect system to keep in sync -- see docs/DECISIONS.md D-16.
var relics: Array = []
var potions_used: int = 0

func _init(p_player: Player, p_enemies: Array[Enemy], deck: Array[Card], p_relics: Array = []) -> void:
	player = p_player
	enemies = p_enemies
	relics = p_relics
	player.combat = self
	for e in enemies:
		e.combat = self
	draw_pile = deck.duplicate()

# --- Event queue -----------------------------------------------------------

func push_event(kind: StringName, data: Dictionary = {}) -> void:
	event_queue.append(VisualEvent.new(kind, data))
	events_available.emit()

## The view calls this to take ownership of pending events.
func drain_events() -> Array[VisualEvent]:
	var out := event_queue.duplicate()
	event_queue.clear()
	return out

# --- Lifecycle -------------------------------------------------------------

func start() -> void:
	_set_state(State.COMBAT_START)
	Rng.shuffle_in(&"shuffle", draw_pile)
	# Innate cards jump the queue so they are guaranteed in the opening hand.
	# push_BACK, because draw() pops the back: pushing them to the front put
	# them at the bottom of the pile and guaranteed they were drawn LAST,
	# which is the exact opposite of what the card face promises.
	var innate := draw_pile.filter(func(c: Card): return c.data.innate)
	for c in innate:
		draw_pile.erase(c)
	for c in innate:
		draw_pile.push_back(c)
	for e in enemies:
		e.roll_intent()
	_apply_relic_modifiers()
	begin_turn()

## Flat relic modifiers that no CardEffect can express.
func _apply_relic_modifiers() -> void:
	# Reset first: these are recomputed from the relic list, not accumulated.
	player.pp_cap = Player.PP_CAP
	player.max_pp = Player.PP_START - 1
	player.discount_first_card = false
	for r in relics:
		# A PP relic buys both a head start on the ramp and a higher ceiling.
		# Raising only the start would be worthless the moment the curve tops out.
		player.max_pp += r.bonus_max_pp
		player.pp_cap += r.bonus_max_pp
		if r.discounts_first_card:
			player.discount_first_card = true

func _run_relic_effects(phase: StringName) -> void:
	if relics.is_empty():
		return
	var ctx := EffectContext.new(self, player, living_enemies())
	for r in relics:
		var list: Array = r.on_combat_start if phase == &"combat_start" else r.on_turn_start
		for eff in list:
			eff.execute(ctx)

func bonus_draw() -> int:
	var n := 0
	for r in relics:
		n += r.bonus_card_draw
	return n

func begin_turn() -> void:
	turn += 1
	cards_played_this_turn = 0
	_set_state(State.TURN_START)
	push_event(VisualEvent.TURN_START, {"turn": turn})
	player.on_turn_start()
	# Order matters: on_turn_start() clears Block, so a relic that grants Block at
	# combat start has to resolve after it or it is wiped before turn one begins.
	var ceiling_before := player.max_pp
	if turn == 1:
		_run_relic_effects(&"combat_start")
	_run_relic_effects(&"turn_start")
	# ...but on_turn_start() has also already filled the pp pool, so a relic
	# that ramps here would raise the ceiling and hand over nothing until the
	# following turn. "At the start of each combat, Ramp 1" has to be worth
	# something on turn one. The Kindling status needs no such help: it resolves
	# inside on_turn_start(), before the refill.
	if player.max_pp > ceiling_before:
		player.gain_pp(player.max_pp - ceiling_before)
	draw(HAND_SIZE + bonus_draw())
	_set_state(State.PLAYER_ACTION)

func end_turn() -> void:
	if state != State.PLAYER_ACTION:
		return
	_set_state(State.TURN_END)
	push_event(VisualEvent.TURN_END, {"turn": turn})
	_discard_hand()
	player.on_turn_end()
	if _check_result() != Result.ONGOING:
		return
	_enemy_phase()
	if _check_result() != Result.ONGOING:
		return
	begin_turn()

func _enemy_phase() -> void:
	_set_state(State.ENEMY_TURN)
	for e in enemies:
		if not e.is_alive():
			continue
		e.on_turn_start()
		e.perform(self)
		e.on_turn_end()
		if not player.is_alive():
			return
	for e in living_enemies():
		e.roll_intent()

# --- Card play -------------------------------------------------------------

## What a card actually costs right now. Card cost is static; the discount a
## relic grants to the first card each turn is not, and both can_play() and
## play_card() have to agree about it or a card is playable but unaffordable.
func effective_cost(card: Card) -> int:
	var c := card.cost()
	if c <= 0:
		return c
	if player.discount_first_card and cards_played_this_turn == 0:
		return maxi(0, c - 1)
	return c

func can_play(card: Card) -> bool:
	if state != State.PLAYER_ACTION:
		return false
	if not card.data.is_playable_type():
		return false
	if card.cost() < 0:
		return false
	return player.pp >= effective_cost(card)

## Plays a card from hand. Returns false if illegal -- callers should check
## can_play() first and surface the reason in the UI.
func play_card(card: Card, target: Combatant = null) -> bool:
	if not can_play(card) or not hand.has(card):
		return false
	if card.data.needs_target() and (target == null or not target.is_alive()):
		target = living_enemies().front() if not living_enemies().is_empty() else null
		if target == null:
			return false
	player.spend_pp(effective_cost(card))
	hand.erase(card)
	cards_played_this_turn += 1
	push_event(VisualEvent.CARD_PLAYED, {"card": card, "target": target})

	var targets := _targets_for(card, target)
	var ctx := EffectContext.new(self, player, targets, card)
	for eff in card.effects():
		if not player.is_alive():
			break
		eff.execute(ctx)

	for st in player._ordered_statuses():
		st.on_card_played(card, player, self)

	if card.data.exhaust:
		exhaust_pile.append(card)
		push_event(VisualEvent.CARD_EXHAUSTED, {"card": card})
	else:
		discard_pile.append(card)
		push_event(VisualEvent.CARD_DISCARDED, {"card": card})

	_cleanup_dead()
	_check_result()
	return true

## Potions cost no PP and can be used at any point in the player's turn.
## They are the deckbuilder's safety valve; gating them behind PP removes
## the whole reason they exist.
func use_potion(potion: PotionData, target: Combatant = null) -> bool:
	if state != State.PLAYER_ACTION or potion == null:
		return false
	var targets: Array
	match potion.target:
		CardData.Target.ALL_ENEMIES:
			targets = living_enemies()
		CardData.Target.ENEMY:
			if target == null or not target.is_alive():
				target = living_enemies().front() if not living_enemies().is_empty() else null
			if target == null:
				return false
			targets = [target]
		CardData.Target.SELF:
			targets = [player]
		_:
			targets = []
	var ctx := EffectContext.new(self, player, targets)
	for eff in potion.effects:
		eff.execute(ctx)
	potions_used += 1
	push_event(&"potion_used", {"potion": potion.id})
	_cleanup_dead()
	_check_result()
	return true

func _targets_for(card: Card, chosen: Combatant) -> Array:
	match card.data.target:
		CardData.Target.ALL_ENEMIES:
			return living_enemies()
		CardData.Target.RANDOM_ENEMY:
			var pick = Rng.pick_in(&"enemy_ai", living_enemies())
			return [pick] if pick else []
		CardData.Target.SELF:
			return [player]
		CardData.Target.NONE:
			return []
		_:
			return [chosen] if chosen else []

# --- Piles -----------------------------------------------------------------

func draw(count: int) -> int:
	var drawn := 0
	for _i in count:
		if hand.size() >= MAX_HAND:
			break
		if draw_pile.is_empty():
			# The discard pile becomes the new draw pile. Without this a fight is
			# one pass through the deck: with a six-card deck and a hand of five
			# the player draws nothing from turn three and simply stands there.
			if discard_pile.is_empty():
				break
			_reshuffle()
		var card: Card = draw_pile.pop_back()
		hand.append(card)
		drawn += 1
		push_event(VisualEvent.CARD_DRAWN, {"card": card, "hand_size": hand.size()})
	return drawn

func _reshuffle() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	Rng.shuffle_in(&"shuffle", draw_pile)
	push_event(VisualEvent.DECK_RESHUFFLED, {"count": draw_pile.size()})

func _discard_hand() -> void:
	for card in hand.duplicate():
		if card.data.retain:
			continue
		if card.data.ethereal:
			hand.erase(card)
			exhaust_pile.append(card)
			push_event(VisualEvent.CARD_EXHAUSTED, {"card": card, "reason": "ethereal"})
			continue
		hand.erase(card)
		card.cost_override = -99
		discard_pile.append(card)
		push_event(VisualEvent.CARD_DISCARDED, {"card": card, "reason": "end_of_turn"})

func add_card(card: Card, pile: int) -> void:
	match pile:
		AddCardToPileEffect.Pile.DRAW:
			draw_pile.append(card)
			Rng.shuffle_in(&"shuffle", draw_pile)
		AddCardToPileEffect.Pile.HAND:
			if hand.size() < MAX_HAND:
				hand.append(card)
			else:
				discard_pile.append(card)
		_:
			discard_pile.append(card)

# --- Queries & resolution --------------------------------------------------

func living_enemies() -> Array:
	return enemies.filter(func(e: Enemy): return e.is_alive())

## Developer shortcut: end the fight as a win right now.
##
## Deliberately routed through the same damage and event path as a real kill
## rather than by setting `result` directly -- a skip that bypassed the queue
## would exercise a code path no player ever takes, and would stop being a
## useful test of the reward flow the moment the two diverged.
func dev_win() -> void:
	if state == State.COMBAT_END:
		return
	for e in enemies:
		if e.is_alive():
			e.take_damage(e.hp, player, true)
	_cleanup_dead()
	_check_result()

func _cleanup_dead() -> void:
	for e in enemies:
		if not e.is_alive():
			e.intent = Intent.new(Intent.Kind.UNKNOWN)

func _check_result() -> Result:
	if result != Result.ONGOING:
		return result
	if not player.is_alive():
		result = Result.DEFEAT
	elif living_enemies().is_empty():
		result = Result.VICTORY
	if result != Result.ONGOING:
		_set_state(State.COMBAT_END)
		push_event(VisualEvent.COMBAT_END, {"result": result, "turns": turn})
	return result

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

## Compact snapshot for tests, save/load and telemetry.
func snapshot() -> Dictionary:
	return {
		"turn": turn,
		"state": State.keys()[state],
		"result": Result.keys()[result],
		"player": {"hp": player.hp, "block": player.block, "pp": player.pp,
			"max_pp": player.max_pp, "overload": player.overload},
		"enemies": enemies.map(func(e): return {"id": String(e.enemy_id), "hp": e.hp, "block": e.block}),
		"piles": {"draw": draw_pile.size(), "hand": hand.size(), "discard": discard_pile.size(), "exhaust": exhaust_pile.size()},
	}
