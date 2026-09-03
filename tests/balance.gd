extends Node
## Self-play balance harness. Runs N complete runs and reports NUMBERS.
##
## Everything else in tests/ answers yes/no: do the rules hold, does the view
## agree with the simulation, can a player finish. None of them can say which
## cards are dead weight, where runs actually die, or whether the class's two
## verbs are worth drafting. The act was halved (15 stages to 8) and the class
## was replaced (Heat to PP) with no retuning, and the only balance signal in
## existence is a single line reading "2 of 6 killed the boss".
##
## Usage (always via tools/balance.sh, which bounds the run):
##   --policy=greedy|curve-blind|curve-aware
##   --runs=60
##   --seeds=fixed|holdout
##
## The GAP between curve-blind and curve-aware is the measurement that matters.
## If a bot that never touches Ramp or Overload does as well as one that plays
## around them, the mechanic is not paying for its complexity -- which is the
## closest thing to a machine-checkable answer for D-11.
##
## READ THAT GAP WITH CARE SINCE D-27. Overload now charges interest, so its
## value is entirely "what does this borrow unlock, and is that worth the bill?"
## -- and no policy here can answer the first half, because none of them can
## value a card. `_choose_greedy` takes the first playable card in hand order,
## so "unlocking" a card means playing an arbitrary one a turn early. Under a
## nought-per-cent loan that was free; under interest it loses.
##
## The measured consequence (40 runs, fixed seeds): curve-aware kills the boss
## 45% of the time against curve-blind's 62.5%. That is NOT evidence the class
## mechanic is worthless. It is evidence that borrowing without being able to
## price what you buy is now punished -- which is what D-27 was for, and which
## no bot could have shown before it, because nothing was punished.
##
## So: this harness can currently prove there is a WRONG way to play Overload.
## It cannot yet demonstrate a right one. That gap is a limitation of the
## policies, not a verdict on the class, and closing it needs either a bot that
## evaluates cards or the human playtest D-18 is waiting on.

const DEFAULT_RUNS := 60
const MAX_TURNS := 60
const MAX_ACTIONS_PER_TURN := 40
## The biggest single borrow the curve-aware bot will take. Two costs three PP
## over two turns, which a real player would pay for a turn they need; three
## costs six, which is where a borrow starts losing more than it buys.
const MAX_SENSIBLE_BORROW := 2
## The cheapest card worth going into debt to reach. Borrowing to play a 1-cost
## card one turn early is a loss the moment the debt charges interest.
const MIN_UNLOCK_COST := 2

## Two disjoint seed sets. Tuning is measured against `fixed` so before/after is
## comparable; `holdout` exists because numbers tuned against a fixed set
## eventually describe that set rather than the game.
const FIXED_BASE := 70000
const FIXED_STEP := 13
const HOLDOUT_BASE := 910000
const HOLDOUT_STEP := 17

var policy := "greedy"
var runs := DEFAULT_RUNS
var seeds := "fixed"

# --- accumulators ----------------------------------------------------------
var _resolved := 0
var _reached_boss := 0
var _boss_kills := 0
var _stalls := 0
var _deaths_by_stage: Dictionary = {}      ## stage -> deaths
var _hp_by_stage: Dictionary = {}          ## stage -> [hp, ...]
var _seen: Dictionary = {}                 ## card id -> turns it sat in hand
var _affordable: Dictionary = {}           ## card id -> turns it was affordable
var _played: Dictionary = {}               ## card id -> times played
var _fights := 0
var _turns := 0
var _turn_ends := 0
var _unspent_mana := 0
var _turns_at_cap := 0
var _ramp_plays := 0
var _ramp_wasted := 0                      ## ramp that moved the ceiling zero
var _overload_plays := 0
var _overload_borrowed := 0                ## total PP borrowed
var _turns_in_debt := 0                    ## turn-ends still carrying a debt
var _deck_at_boss: Array[int] = []

func _ready() -> void:
	_parse_args()
	print("balance: policy=%s seeds=%s runs=%d" % [policy, seeds, runs])
	for i in runs:
		_simulate(_seed_for(i))
	_report()
	get_tree().quit(0)

func _parse_args() -> void:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--policy="):
			policy = a.split("=")[1]
		elif a.begins_with("--runs="):
			runs = maxi(1, int(a.split("=")[1]))
		elif a.begins_with("--seeds="):
			seeds = a.split("=")[1]

func _seed_for(i: int) -> int:
	if seeds == "holdout":
		return HOLDOUT_BASE + i * HOLDOUT_STEP
	return FIXED_BASE + i * FIXED_STEP

# --- card classification ---------------------------------------------------

## What a card does, for policy purposes. Derived from the effects themselves so
## it cannot drift out of step with the JSON the way a hand-kept list would.
func _traits(card: Card) -> Dictionary:
	var t := {"ramp": 0, "overload": 0, "cash_out": false, "damage": false}
	_scan(card.effects(), t)
	return t

func _scan(effects: Array, t: Dictionary) -> void:
	for e in effects:
		if e is RampPPEffect:
			t["ramp"] += (e as RampPPEffect).amount
		elif e is OverloadEffect:
			t["overload"] += (e as OverloadEffect).amount
		elif e is SpendPPEffect:
			t["cash_out"] = true
		elif e is DealDamageEffect:
			t["damage"] = true
		elif e is ConditionalEffect:
			_scan((e as ConditionalEffect).effects, t)

# --- policies --------------------------------------------------------------

## Returns the card to play, or null to end the turn.
func _choose(c: Combat) -> Card:
	match policy:
		"curve-blind":  return _choose_curve_blind(c)
		"curve-aware":  return _choose_curve_aware(c)
		_:              return _choose_greedy(c)

func _choose_greedy(c: Combat) -> Card:
	for card in c.hand:
		if c.can_play(card):
			return card
	return null

## Never plays a card carrying Ramp or Overload. The control group: this is the
## player who ignores the class entirely and just curves out.
func _choose_curve_blind(c: Combat) -> Card:
	for card in c.hand:
		if not c.can_play(card):
			continue
		var t := _traits(card)
		if t["ramp"] > 0 or t["overload"] > 0:
			continue
		return card
	return null

## Plays the class as intended: ramp while it still buys something, overload
## when the borrowed PP actually unlocks a card that is otherwise stranded,
## and never ramps into the ceiling.
##
## Since D-27 the debt carries interest, so "does this borrow unlock a card"
## stopped being the whole question -- borrowing on top of an existing debt
## compounds into turns with no PP in them. A bot that keeps borrowing is
## measuring recklessness rather than the class played well, which would make
## the curve-blind/curve-aware gap say the opposite of what it is for.
func _choose_curve_aware(c: Combat) -> Card:
	var p := c.player
	# 1. Ramp early, while there is headroom for it to buy anything at all.
	if not p.at_pp_cap() and c.turn <= 3:
		for card in c.hand:
			if c.can_play(card) and _traits(card)["ramp"] > 0:
				return card
	# 2. Overload only when it reaches a card the current PP cannot -- never on
	#    top of an existing debt, and never for a card too cheap to be worth the
	#    interest. Both guards exist because of D-27: the debt is charged in full
	#    every turn until it is paid down, so compounding it is the trap, and
	#    borrowing to play a 1-cost card one turn early loses outright.
	for card in c.hand:
		if not c.can_play(card):
			continue
		var gained: int = _traits(card)["overload"]
		if gained <= 0 or gained > MAX_SENSIBLE_BORROW:
			continue
		if p.is_overloaded():
			continue
		var after: int = p.pp - c.effective_cost(card) + gained
		for other in c.hand:
			if other == card:
				continue
			var cost := c.effective_cost(other)
			if cost > p.pp and cost <= after and cost >= MIN_UNLOCK_COST:
				return card
	# 3. Otherwise play normally, but never burn a Ramp card into the ceiling and
	#    never take a borrow INCIDENTALLY on top of a debt.
	#
	#    That second guard is the one this policy was missing. Step 2 is the only
	#    place it borrows on purpose, and it fires rarely -- so nearly every
	#    Overload it played arrived here, chosen for no reason beyond being next
	#    in hand order. Under D-27 that compounds a debt that is charged in full
	#    every turn, which is the single worst thing the class can do, and it was
	#    being counted as "the class played as intended".
	for card in c.hand:
		if not c.can_play(card):
			continue
		var traits := _traits(card)
		if p.at_pp_cap() and traits["ramp"] > 0:
			continue
		if p.is_overloaded() and traits["overload"] > 0:
			continue
		return card
	# 4. Nothing better left; take whatever is legal rather than stalling.
	return _choose_greedy(c)

# --- one fight -------------------------------------------------------------

func _fight(c: Combat) -> int:
	_fights += 1
	var turns := 0
	while c.result == Combat.Result.ONGOING and turns < MAX_TURNS:
		turns += 1
		_turns += 1
		_record_hand(c)
		var actions := 0
		while c.result == Combat.Result.ONGOING:
			var card := _choose(c)
			if card == null:
				break
			var id := String(card.data.id)
			var traits := _traits(card)
			var ceiling_before: int = c.player.max_pp
			var living := c.living_enemies()
			if not c.play_card(card, living.front() if not living.is_empty() else null):
				break        # refused: stop rather than spinning on it
			_played[id] = int(_played.get(id, 0)) + 1
			if traits["ramp"] > 0:
				_ramp_plays += 1
				# A Ramp that moved the ceiling zero is a card that cost PP,
				# left the deck, and did nothing. This is the number to watch.
				if c.player.max_pp == ceiling_before:
					_ramp_wasted += 1
			if traits["overload"] > 0:
				_overload_plays += 1
				_overload_borrowed += int(traits["overload"])
			actions += 1
			if actions > MAX_ACTIONS_PER_TURN:
				printerr("    unbounded action loop: %d plays in one turn" % actions)
				return c.result
		if c.result != Combat.Result.ONGOING:
			break
		_unspent_mana += c.player.pp
		_turn_ends += 1
		if c.player.is_overloaded():
			_turns_in_debt += 1
		if c.player.at_pp_cap():
			_turns_at_cap += 1
		c.end_turn()
	return c.result

## Once per turn, after the draw: what was in hand and what could be afforded.
## Sampling inside the action loop instead would count a card once per decision
## and make wide turns look like popular cards.
func _record_hand(c: Combat) -> void:
	for card in c.hand:
		var id := String(card.data.id)
		_seen[id] = int(_seen.get(id, 0)) + 1
		if c.can_play(card):
			_affordable[id] = int(_affordable.get(id, 0)) + 1

## Mirrors RunState.OPENING_DRAFT_PICKS rounds of pick-one-of-three, using the same
## preference the policy applies to combat rewards -- so curve-blind arrives at
## the first fight without the two verbs it refuses to play, rather than holding
## a hand of cards it will never use.
func _opening_draft(run: RunState) -> void:
	for _pick in RunState.OPENING_DRAFT_PICKS:
		var choices := Rewards.card_choices()
		if choices.is_empty():
			return
		run.add_card(_draft_pick(choices))

func _draft_pick(choices: Array) -> Card:
	if policy == "curve-blind":
		# Refuses the class's verbs at the draft too, or the comparison is
		# between two decks rather than between two ways of playing one.
		for c in choices:
			var t := _traits(c)
			if t["ramp"] == 0 and t["overload"] == 0:
				return c
	elif policy == "curve-aware":
		for c in choices:
			var t := _traits(c)
			if t["ramp"] > 0 or t["overload"] > 0:
				return c
	return choices[0]

# --- one run ---------------------------------------------------------------

func _simulate(seed_value: int) -> void:
	var run := RunState.new_run(seed_value)
	# The opening draft is part of the game, not part of the UI: a run reaches
	# its first fight on ten cards, five of them chosen. Simulating from the
	# starting five would measure a deck half the size of the real one.
	_opening_draft(run)
	var guard := 0
	var finished := false
	var beat_boss := false
	while guard < 40:
		guard += 1
		if run.is_dead():
			var stage: int = run.current_node.row if run.current_node else -1
			_deaths_by_stage[stage] = int(_deaths_by_stage.get(stage, 0)) + 1
			_resolved += 1
			finished = true
			break
		var avail := run.available_nodes()
		if avail.is_empty():
			break
		var node: MapNode = avail[Rng.randi_range_in(&"map", 0, avail.size() - 1)]
		if not run.enter(node):
			break
		match node.kind:
			MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS:
				var kind := "normal"
				if node.kind == MapNode.Kind.ELITE: kind = "elite"
				elif node.kind == MapNode.Kind.BOSS: kind = "boss"
				elif node.row < 2: kind = "easy"
				var pool := EnemyLibrary.encounters_of_kind(kind)
				var chosen = Rng.pick_in(&"enemy_ai", pool)
				var enemies := EnemyLibrary.encounter(StringName(chosen.get("id", "")))
				var p := Player.new("Emberwright", run.max_hp)
				p.hp = run.hp
				var c := Combat.new(p, enemies, run.deck, run.relics)
				c.start()
				var res := _fight(c)
				run.hp = p.hp
				if res == Combat.Result.VICTORY:
					if node.kind == MapNode.Kind.BOSS:
						beat_boss = true
					run.gold += Rewards.gold_for(kind)
					var choices := Rewards.card_choices()
					if not choices.is_empty():
						run.add_card(choices[0])
					if kind == "elite":
						run.add_relic(Rewards.relic(run.relics))
			MapNode.Kind.EVENT:
				var ev := EventLibrary.pick([])
				if not ev.is_empty():
					var open_choices := EventLibrary.available_choices(run, ev)
					if not open_choices.is_empty():
						EventLibrary.choose(run, ev, open_choices[0])
			MapNode.Kind.SHOP:
				var shop := Shop.generate(run)
				shop.buy_card(run, 0)          # only if affordable; it refuses otherwise
			MapNode.Kind.CAMPFIRE:
				run.heal(run.rest_heal_amount())
			MapNode.Kind.TREASURE:
				run.gold += Rewards.gold_for("treasure")
		if not _hp_by_stage.has(node.row):
			_hp_by_stage[node.row] = []
		_hp_by_stage[node.row].append(run.hp)
		run.complete_node()
		if node.kind == MapNode.Kind.BOSS:
			_reached_boss += 1
			_deck_at_boss.append(run.deck.size())
			if beat_boss:
				_boss_kills += 1
			else:
				var s: int = node.row
				_deaths_by_stage[s] = int(_deaths_by_stage.get(s, 0)) + 1
			_resolved += 1
			finished = true
			break
	if not finished:
		_stalls += 1

# --- report ----------------------------------------------------------------

func _report() -> void:
	var pct := func(n: int, d: int) -> float:
		return 0.0 if d == 0 else float(n) * 100.0 / float(d)

	print("\n%s" % "=".repeat(66))
	print("  BALANCE  policy=%s  seeds=%s  runs=%d" % [policy, seeds, runs])
	print("%s" % "=".repeat(66))

	print("METRIC runs=%d" % runs)
	print("METRIC boss_reach_pct=%.1f" % pct.call(_reached_boss, runs))
	print("METRIC boss_kill_pct=%.1f" % pct.call(_boss_kills, runs))
	print("METRIC stalls=%d" % _stalls)
	print("METRIC avg_turns_per_fight=%.2f" % (0.0 if _fights == 0 else float(_turns) / float(_fights)))
	print("METRIC avg_unspent_mana=%.2f" % (0.0 if _turn_ends == 0 else float(_unspent_mana) / float(_turn_ends)))
	print("METRIC turns_at_cap_pct=%.1f" % pct.call(_turns_at_cap, _turn_ends))
	print("METRIC ramp_plays=%d" % _ramp_plays)
	print("METRIC ramp_wasted_pct=%.1f" % pct.call(_ramp_wasted, _ramp_plays))
	print("METRIC overload_plays=%d" % _overload_plays)
	print("METRIC overload_borrowed=%d" % _overload_borrowed)
	# The interest bill: what the debt actually cost, against what it bought.
	print("METRIC turns_in_debt_pct=%.1f" % pct.call(_turns_in_debt, _turn_ends))
	var deck_avg := 0.0
	for d in _deck_at_boss:
		deck_avg += float(d)
	print("METRIC avg_deck_at_boss=%.1f" % (0.0 if _deck_at_boss.is_empty() else deck_avg / float(_deck_at_boss.size())))

	print("\n-- where runs end (stage) --")
	var stages := _deaths_by_stage.keys()
	stages.sort()
	for s in stages:
		print("METRIC deaths_stage_%s=%d" % [s, _deaths_by_stage[s]])

	print("\n-- attrition: median HP on leaving each stage --")
	var hp_stages := _hp_by_stage.keys()
	hp_stages.sort()
	for s in hp_stages:
		var vals: Array = _hp_by_stage[s].duplicate()
		vals.sort()
		print("METRIC hp_stage_%s=%d  (n=%d)" % [s, vals[vals.size() / 2], vals.size()])

	print("\n-- cards: played / affordable / seen --")
	var ids := _seen.keys()
	ids.sort_custom(func(a, b):
		return int(_played.get(a, 0)) < int(_played.get(b, 0)))
	for id in ids:
		var seen := int(_seen.get(id, 0))
		var aff := int(_affordable.get(id, 0))
		var play := int(_played.get(id, 0))
		print("CARD %-16s played=%-5d affordable=%-5d seen=%-5d  play_rate_when_affordable=%.0f%%"
			% [id, play, aff, seen, pct.call(play, aff)])
	print("%s" % "=".repeat(66))
