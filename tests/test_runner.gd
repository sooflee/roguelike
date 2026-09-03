extends Node
## Headless test suite. Run with:
##   godot --headless --path . tests/test_runner.tscn
##
## Every test here exercises the real Combat class with no view layer attached.
## That is only possible because the simulation never awaits an animation.

var _passed := 0
var _failed := 0
var _current := ""

func _ready() -> void:
	Juice.intensity = 0.0
	var suites := [
		"test_damage_pipeline_order",
		"test_type_effectiveness_resolves_last",
		"test_block_absorption",
		"test_vulnerable_and_weak",
		"test_status_decay",
		"test_pp_ramps_one_a_turn_to_the_cap",
		"test_ramp_pulls_the_curve_forward",
		"test_ramp_at_the_ceiling_refunds_instead_of_doing_nothing",
		"test_overload_debt_charges_until_it_is_paid_off",
		"test_deep_overload_costs_more_turns_not_a_bigger_turn",
		"test_dampened_freezes_the_debt",
		"test_clearing_overload_writes_off_the_debt",
		"test_drain_ramp_lowers_the_refill_but_never_past_the_floor",
		"test_pp_accounting",
		"test_draw_and_reshuffle",
		"test_exhaust_pile",
		"test_conditional_overloaded_effect",
		"test_spend_pp_payout",
		"test_afterburn_hook",
		"test_entity_tooltip_renders_every_status",
		"test_every_status_description_renders",
		"test_card_library_integrity",
		"test_generated_card_text_matches_authored_text",
		"test_upgrade_preview_reflects_the_upgrade",
		"test_enemy_intent_is_telegraphed",
		"test_enemy_max_consecutive",
		"test_enemy_opening_is_the_same_every_seed",
		"test_enemy_move_conditions_gate_on_fight_state",
		"test_enemy_conditions_read_the_players_state",
		"test_enemy_passives_restore_the_guard_every_turn",
		"test_simmer_punishes_leaving_an_enemy_alone",
		"test_enemy_content_integrity",
		"test_every_enemy_and_encounter_spawns",
		"test_seeded_shuffle_reproducible",
		"test_seeded_map_reproducible",
		"test_map_structure_rules",
		"test_victory_and_defeat",
		"test_dev_win_takes_the_real_path",
		"test_event_queue_drains",

		"test_run_state_creation",
		"test_relic_effects_apply_in_combat",
		"test_relic_max_hp_heals_on_pickup",
		"test_relic_discounts_first_card",
		"test_relic_bonus_draw",
		"test_potion_use",
		"test_potion_slots_are_capped",
		"test_potion_discard_frees_a_slot",
		"test_card_rewards_are_distinct",
		"test_shop_purchase_spends_gold",
		"test_shop_refuses_when_broke",
		"test_shop_card_removal",
		"test_shop_always_stocks_its_full_slate",
		"test_contact_reaches_the_damage_event",
		"test_event_choices_apply",
		"test_event_content_integrity",
		"test_map_traversal_is_legal",
		"test_rest_heal_amount",
		"test_save_load_roundtrip",
		"test_relic_content_integrity",
		"test_every_audio_cue_resolves",
		"test_combat_invariants_hold_under_autoplay",
		"test_full_run_simulation",
	]
	for s in suites:
		_current = s
		call(s)
	print("\n%s" % ("=".repeat(52)))
	print("  %d passed, %d failed" % [_passed, _failed])
	print("%s" % ("=".repeat(52)))
	get_tree().quit(1 if _failed > 0 else 0)

# --- assertions ------------------------------------------------------------

func ok(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s :: %s" % [_current, msg])
	else:
		_failed += 1
		printerr("  FAIL  %s :: %s" % [_current, msg])

func eq(a, b, msg: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [msg, a, b])

# --- helpers ---------------------------------------------------------------

func _deck(ids: Array) -> Array[Card]:
	var out: Array[Card] = []
	for id in ids:
		out.append(CardLibrary.make(StringName(id)))
	return out

func _combat(enemy_ids: Array = ["cinder_rat"], deck: Array = ["strike", "defend"], hp := 75) -> Combat:
	Rng.set_seed(1234)
	var p := Player.new("Charmander", hp)
	var es: Array[Enemy] = []
	for eid in enemy_ids:
		es.append(EnemyLibrary.spawn(StringName(eid)))
	var c := Combat.new(p, es, _deck(deck))
	return c

# --- tests -----------------------------------------------------------------

func test_damage_pipeline_order() -> void:
	# (6 + 3 Strength) * 0.75 Weak = 6.75 -> floor 6.
	# The wrong order, (6 * 0.75) + 3 = 7, is the classic bug this guards.
	var c := _combat()
	c.player.apply_status(StatusRegistry.get_status(&"strength"), 3)
	c.player.apply_status(StatusRegistry.get_status(&"weak"), 1)
	var e := c.enemies[0]
	eq(c.player.calculate_damage(6, e), 6, "strength applies before weak")

## The genre's defining rule. It resolves AFTER the additive and multiplicative
## status modifiers, so a super-effective hit doubles the number the player can
## already see rather than some intermediate value they cannot.
func test_type_effectiveness_resolves_last() -> void:
	eq(Element.multiplier(Element.Kind.FIRE, Element.Kind.GRASS), 2.0, "fire burns grass")
	eq(Element.multiplier(Element.Kind.FIRE, Element.Kind.WATER), 0.5, "water smothers fire")
	eq(Element.multiplier(Element.Kind.NORMAL, Element.Kind.FIRE), 1.0, "most matchups are neutral")

	var c := _combat(["cinder_rat"], ["strike"])
	c.start()
	var e: Enemy = c.enemies[0]
	var attacker := c.player

	e.element = Element.Kind.GRASS
	var supered := attacker.calculate_damage(10, e, true, Element.Kind.FIRE)
	e.element = Element.Kind.WATER
	var resisted := attacker.calculate_damage(10, e, true, Element.Kind.FIRE)
	var neutral := attacker.calculate_damage(10, e, true, Element.Kind.NORMAL)
	eq(supered, 20, "super effective doubles")
	eq(resisted, 5, "resisted halves")
	eq(neutral, 10, "a neutral matchup is unchanged")

	# Untyped damage -- an enemy move, a relic, self-damage -- skips the chart
	# entirely rather than counting as Normal, which would silently halve it.
	e.element = Element.Kind.ROCK
	eq(attacker.calculate_damage(10, e, true), 10, "untyped damage ignores the chart")
	eq(attacker.calculate_damage(10, e, true, Element.Kind.NORMAL), 5,
		"but an explicitly Normal move is resisted by Rock")

func test_block_absorption() -> void:
	var c := _combat()
	var e := c.enemies[0]
	e.gain_block(4)
	e.take_damage(6)
	eq(e.block, 0, "block fully consumed")
	eq(e.hp, e.max_hp - 2, "only overflow reaches hp")

func test_vulnerable_and_weak() -> void:
	var c := _combat()
	var e := c.enemies[0]
	e.apply_status(StatusRegistry.get_status(&"vulnerable"), 1)
	eq(c.player.calculate_damage(10, e), 15, "vulnerable multiplies incoming by 1.5")

func test_status_decay() -> void:
	var c := _combat()
	var e := c.enemies[0]
	e.apply_status(StatusRegistry.get_status(&"vulnerable"), 2)
	e.on_turn_end()
	eq(e.status_stacks(&"vulnerable"), 1, "vulnerable decays one stack per turn")
	e.on_turn_end()
	ok(not e.has_status(&"vulnerable"), "vulnerable expires at zero")

func test_pp_ramps_one_a_turn_to_the_cap() -> void:
	var p := Player.new()
	eq(p.max_pp, Player.PP_START - 1,
		"the gauge opens one below turn one, because the ramp fires on turn one too")
	var seen: Array[int] = []
	for _turn in 7:
		p.on_turn_start()
		seen.append(p.pp)
	eq(str(seen), "[1, 2, 3, 4, 5, 5, 5]", "pp climbs one a turn and stops at the cap")
	eq(p.max_pp, Player.PP_CAP, "the ceiling never passes the cap")

func test_ramp_pulls_the_curve_forward() -> void:
	var p := Player.new()
	p.on_turn_start()                       # turn 1: 1 pp
	eq(p.ramp_pp(2), 2, "ramp reports how far the ceiling actually moved")
	eq(p.max_pp, 3, "ramp raises the refill permanently")
	eq(p.pp, 1, "but grants no pp on the turn it is played -- it is an investment")
	p.on_turn_start()
	eq(p.pp, 4, "so the next turn arrives three ahead of the natural curve")

	# At the cap there is nothing left to buy, and ramp must say so rather than
	# silently doing nothing -- cards rely on the return value.
	p.ramp_pp(9)
	eq(p.max_pp, Player.PP_CAP, "ramp cannot climb past the cap")
	eq(p.ramp_pp(1), 0, "and reports zero once there")

## A card that costs PP, exhausts, and does nothing is the worst thing a deck
## can contain, because the player cannot tell it happened. At the ceiling the
## ramp is paid back as PP instead.
func test_ramp_at_the_ceiling_refunds_instead_of_doing_nothing() -> void:
	var c := _combat(["the_bellowsmith"], ["stoke", "strike", "strike", "strike", "strike"])
	c.start()
	c.player.pp_cap = Player.PP_CAP
	c.player.max_pp = Player.PP_CAP        # already at the ceiling
	c.player.pp = 3
	var stoke: Card = null
	for card in c.hand:
		if card.data.id == &"stoke":
			stoke = card
	ok(stoke != null, "stoke is in hand")
	if stoke:
		ok(c.play_card(stoke), "it is still playable at the ceiling")
		eq(c.player.max_pp, Player.PP_CAP, "the ceiling does not move past the cap")
		# Ramp 2, cost 1: pays 1 to play, refunds 2 it could not invest.
		eq(c.player.pp, 4, "and the ramp it could not buy comes back as PP")

## The central number in the class. Overload N gives N PP now and charges the
## FULL outstanding debt against every refill until it is paid off, one point a
## turn -- so borrowing N costs N + (N-1) + ... + 1 in total.
##
## This is the test that would have caught the old rule being no decision at
## all: charged-once-and-cleared meant N now for exactly N later, a loan at
## nought per cent, which is always worth taking. See D-27.
func test_overload_debt_charges_until_it_is_paid_off() -> void:
	var p := Player.new()
	p.on_turn_start()
	p.on_turn_start()                       # turn 2: 2 pp
	eq(p.pp, 2, "turn two refills to two")
	p.overload_pp(2)
	eq(p.pp, 4, "overload hands the pp over immediately")
	eq(p.overload, 2, "and records the debt")

	p.on_turn_start()                       # turn 3: refill 3, owe 2
	eq(p.max_pp, 3, "the ceiling itself is untouched")
	eq(p.pp, 1, "the refill is short by the whole outstanding debt")
	eq(p.overload, 1, "and only one point of it is written off per turn")
	ok(p.is_overloaded(), "so the debt -- and every Overloaded: bonus -- is still live")

	p.on_turn_start()                       # turn 4: refill 4, owe 1
	eq(p.pp, 3, "the second turn of the same debt still costs")
	eq(p.overload, 0, "and that clears it")
	ok(not p.is_overloaded(), "the stance ends when the books are settled")

	p.on_turn_start()
	eq(p.pp, 5, "a paid-off debt is never charged again")

	# 2 borrowed cost 3 in total, which is the whole point: the interest is what
	# makes the size of the borrow a decision rather than a formality.

	# Borrowing more than a refill must not produce negative pp.
	p.overload_pp(99)
	p.on_turn_start()
	eq(p.pp, 0, "an overwhelming debt empties the turn but never goes negative")
	ok(p.overload > 0, "and an overwhelming debt outlives the turn it empties")

## The debt costs the same on the turn it is taken however deep it is -- what
## scales is how many turns it goes on costing. Cheap to dabble, ruinous to
## live in, which is the risk curve the archetype is built on.
func test_deep_overload_costs_more_turns_not_a_bigger_turn() -> void:
	var shallow := Player.new()
	var deep := Player.new()
	for _i in 5:
		shallow.on_turn_start()
		deep.on_turn_start()
	shallow.overload_pp(1)
	deep.overload_pp(3)

	var shallow_lost := 0
	var deep_lost := 0
	for _i in 4:
		shallow.on_turn_start()
		deep.on_turn_start()
		shallow_lost += Player.PP_CAP - shallow.pp
		deep_lost += Player.PP_CAP - deep.pp
	eq(shallow_lost, 1, "borrowing 1 costs 1 PP, on one turn")
	eq(deep_lost, 6, "borrowing 3 costs 6 PP, spread over three")

## Dampened is the only status that attacks the curve rather than the numbers.
## While it is on you the debt stops draining, so waiting is no longer an answer
## and Quench stops being a spare Block card.
func test_dampened_freezes_the_debt() -> void:
	var p := Player.new()
	for _i in 5:
		p.on_turn_start()
	p.overload_pp(2)
	p.apply_status(StatusRegistry.get_status(&"dampened"), 1)
	p.on_turn_start()
	eq(p.overload, 2, "a dampened debt pays down nothing")
	eq(p.pp, 3, "and still charges in full")
	p.on_turn_end()                         # dampened decays here
	p.on_turn_start()
	eq(p.overload, 1, "once it wears off the debt drains again")

func test_clearing_overload_writes_off_the_debt() -> void:
	var p := Player.new()
	p.on_turn_start()
	p.overload_pp(3)
	eq(p.clear_overload(), 3, "clearing reports what was written off")
	p.on_turn_start()
	eq(p.pp, 2, "and the next refill comes back whole")

## An enemy eating the ceiling itself. The floor exists because a refill of zero
## is a turn with no decisions in it, which is a worse punishment than dying.
func test_drain_ramp_lowers_the_refill_but_never_past_the_floor() -> void:
	var p := Player.new()
	for _i in 4:
		p.on_turn_start()
	eq(p.max_pp, 4, "four turns of ramp reach a refill of four")
	eq(p.drain_ramp(2), 2, "draining reports what it took")
	eq(p.max_pp, 2, "the ceiling drops for the rest of the fight")
	p.on_turn_start()
	eq(p.pp, 3, "and the next refill is genuinely smaller")
	p.drain_ramp(99)
	eq(p.max_pp, Player.MANA_FLOOR, "but the curve never falls below the floor")

func test_pp_accounting() -> void:
	# High-HP target on purpose: if the enemy dies mid-loop the combat ends and
	# can_play() goes false, which would silently mask a pp bug.
	var c := _combat(["the_bellowsmith"], ["strike", "strike", "strike", "strike", "strike"])
	c.start()
	eq(c.player.pp, 1, "turn one opens on a single pp")
	var played := 0
	while c.can_play(c.hand[0]) and played < 5:
		c.play_card(c.hand[0], c.enemies[0])
		played += 1
	eq(c.player.pp, 0, "pp is spent down to zero")
	eq(played, 1, "exactly one 1-cost card fits in turn one")
	c.end_turn()
	eq(c.player.pp, 2, "and turn two affords two")

## An exhausted draw pile is refilled from the discard, so a fight is bounded by
## the enemy's HP rather than by deck size.
func test_draw_and_reshuffle() -> void:
	var c := _combat(["the_bellowsmith"],
		["strike", "defend", "strike", "defend", "strike", "defend"])
	c.start()
	eq(c.hand.size(), 5, "opening hand is 5")
	eq(c.draw_pile.size(), 1, "remainder stays in draw pile")
	c.end_turn()
	eq(c.hand.size(), 5, "hand refills next turn, reshuffling the discard in")
	var total := c.draw_pile.size() + c.hand.size() + c.discard_pile.size() + c.exhaust_pile.size()
	eq(total, 6, "and no card is lost or duplicated by the reshuffle")
	# Drawing from a genuinely empty combat -- nothing anywhere -- still stops.
	c.draw_pile.clear()
	c.discard_pile.clear()
	c.hand.clear()
	eq(c.draw(5), 0, "with no cards anywhere, drawing reports drawing nothing")

func test_exhaust_pile() -> void:
	var c := _combat(["cinder_rat"], ["stoke", "strike", "strike", "strike", "strike"])
	c.start()
	var stoke: Card = null
	for card in c.hand:
		if card.data.id == &"stoke":
			stoke = card
	ok(stoke != null, "stoke is in the opening hand")
	if stoke:
		c.play_card(stoke)
		eq(c.exhaust_pile.size(), 1, "exhausting card lands in exhaust pile")
		eq(c.discard_pile.size(), 0, "exhausted card does not reach discard")

func test_conditional_overloaded_effect() -> void:
	var cold := _combat(["cracked_golem"], ["ember_jab"])
	cold.start()
	var e1 := cold.enemies[0]
	var hp1 := e1.hp
	cold.play_card(cold.hand[0], e1)
	var cold_damage := hp1 - e1.hp

	var hot := _combat(["cracked_golem"], ["ember_jab"])
	hot.start()
	hot.player.overload_pp(1)
	var e2 := hot.enemies[0]
	var hp2 := e2.hp
	hot.play_card(hot.hand[0], e2)
	var hot_damage := hp2 - e2.hp

	ok(hot_damage > cold_damage,
		"the overloaded bonus fires only while in debt (%d vs %d)" % [hot_damage, cold_damage])

func test_spend_pp_payout() -> void:
	var c := _combat(["cracked_golem"], ["vent"])
	c.start()
	c.player.gain_pp(4)                   # 1 from the curve + 4 = 5 in hand
	var e := c.enemies[0]
	var hp := e.hp
	c.play_card(c.hand[0], e)                # Vent costs 1, leaving 4 to cash out
	eq(c.player.pp, 0, "vent spends every pp it can reach")
	eq(hp - e.hp, 12, "vent pays 3 damage per pp spent")

func test_afterburn_hook() -> void:
	var c := _combat(["cracked_golem"], ["strike"])
	c.start()
	var e := c.enemies[0]
	c.player.apply_status(StatusRegistry.get_status(&"afterburn"), 3)
	var hp := e.hp
	c.player.overload_pp(1)
	eq(hp - e.hp, 3, "afterburn triggers on overload")

## The hover panel is the one place the game explains itself, and nothing tested
## it. `show_entity` read `who.name` on a RefCounted, so it threw on every hover
## and rendered nothing -- every status description in the game was unreachable,
## silently, including the two statuses aimed at the PP curve.
func test_entity_tooltip_renders_every_status() -> void:
	var tip := TipPanel.new()
	add_child(tip)
	var p := Player.new("Charmander", 75)
	p.apply_status(StatusRegistry.get_status(&"dampened"), 2)
	p.apply_status(StatusRegistry.get_status(&"afterburn"), 3)
	tip.show_entity(p, Vector2(100, 100), Vector2(960, 540))
	var text: String = tip._text.text
	ok(text.contains("Charmander"), "the panel names the combatant")
	ok(text.contains("75/75 HP"), "and states its HP")
	ok(text.contains("Stall 2"), "and lists each status with its stack count")
	# Descriptions written with a placeholder must take the stack count, or the
	# player is shown a literal "%d".
	ok(text.contains("deal 3 damage"), "and substitutes stacks into the description")
	ok(not text.contains("%d"), "leaving no unsubstituted placeholder on screen")
	tip.queue_free()

## Every status must render in the panel at any stack count -- a description with
## a placeholder the format call cannot fill is a crash on hover.
func test_every_status_description_renders() -> void:
	var tip := TipPanel.new()
	add_child(tip)
	var bad := 0
	for proto in StatusRegistry.all():
		var p := Player.new("Charmander", 75)
		p.apply_status(proto, 2)
		tip.show_entity(p, Vector2.ZERO, Vector2(960, 540))
		var text: String = tip._text.text
		if not text.contains(proto.display_name) or text.contains("%d"):
			bad += 1
			printerr("    status '%s' does not render: %s" % [proto.id, text])
	eq(bad, 0, "all %d statuses render in the hover panel" % StatusRegistry.all().size())
	tip.queue_free()

func test_card_library_integrity() -> void:
	var all := CardLibrary.all()
	ok(all.size() >= 30, "card library loaded (%d cards)" % all.size())
	var bad := 0
	for c in all:
		if c.effects.is_empty() and c.type != CardData.Type.CURSE:
			bad += 1
			printerr("    card '%s' has no effects" % c.id)
		if c.title.is_empty():
			bad += 1
	eq(bad, 0, "every card has a title and at least one effect")
	var starters := all.filter(func(c): return c.rarity == CardData.Rarity.STARTER)
	eq(starters.size(), 3, "exactly three starter cards")

## The upgrade preview shows generated text for a card that does not exist yet,
## so the generator has to be trusted. This is what earns that trust: at base
## rank it must reproduce the authored copy exactly, for every card. If someone
## retunes a number in JSON and forgets the text -- or teaches an effect a new
## trick without teaching it to describe itself -- this fails here rather than
## quietly lying to the player on the reward screen.
func test_generated_card_text_matches_authored_text() -> void:
	var bad := 0
	for c in CardLibrary.all():
		var data: CardData = c
		var generated := data.describe(false)
		if generated != data.text:
			bad += 1
			printerr("    card '%s'\n      authored:  %s\n      generated: %s"
				% [data.id, data.text, generated])
	eq(bad, 0, "generated card text reproduces the authored text for every card")

func test_upgrade_preview_reflects_the_upgrade() -> void:
	var strike := CardLibrary.make(&"strike")
	eq(strike.describe(), "Deal 6 damage.", "a fresh card reads at base rank")
	eq(strike.upgrade_preview(), "Deal 9 damage.", "the preview shows the upgraded numbers")
	strike.upgrade()
	eq(strike.describe(), "Deal 9 damage.", "an upgraded card reads at its own rank")
	eq(strike.upgrade_preview(), "", "nothing left to preview once upgraded")

	# upgraded_effects replaces the effect list outright rather than scaling it,
	# so it is the case most likely to be missed by a preview.
	var vent := CardLibrary.make(&"vent")
	eq(vent.upgrade_preview(), "Spend your remaining PP. Deal 4 damage per PP spent.",
		"preview follows upgraded_effects, not just upgrade_bonus")

	# Every card must survive being described at both ranks.
	var blank := 0
	for c in CardLibrary.all():
		var data: CardData = c
		if data.type == CardData.Type.CURSE:
			continue
		if data.describe(true).strip_edges().is_empty():
			blank += 1
			printerr("    card '%s' has no upgraded text" % data.id)
	eq(blank, 0, "every card renders text at upgraded rank")

func test_enemy_intent_is_telegraphed() -> void:
	var c := _combat(["slag_hound"])
	c.start()
	var e := c.enemies[0]
	ok(e.intent.kind != Intent.Kind.UNKNOWN, "enemy has a visible intent before the player acts")
	ok(e.intent.move_id != &"", "intent names the move it will perform")

func test_enemy_max_consecutive() -> void:
	Rng.set_seed(99)
	var e := EnemyLibrary.spawn(&"cinder_rat")
	var c := Combat.new(Player.new(), [e] as Array[Enemy], _deck(["strike"]))
	var streak := 0
	var worst := 0
	var last := &""
	for _i in 40:
		e.roll_intent()
		e._history.append(e._pending_move.get("id", ""))
		var id: StringName = StringName(e._pending_move.get("id", ""))
		streak = streak + 1 if id == last else 1
		worst = maxi(worst, streak)
		last = id
	ok(worst <= 2, "bite never repeats more than max_consecutive (worst streak %d)" % worst)

## An opening is the difference between an enemy you learn and an enemy you
## watch. It must be identical across seeds, or it is not learnable.
func test_enemy_opening_is_the_same_every_seed() -> void:
	var seen: Array[String] = []
	for seed_value in [1, 2, 999]:
		Rng.set_seed(seed_value)
		var c := _combat(["cracked_golem"], ["strike", "strike", "strike", "strike", "strike"])
		c.start()
		var e: Enemy = c.enemies[0]
		var order: Array[String] = []
		for _turn in 2:
			order.append(String(e.intent.move_id))
			c.end_turn()
		seen.append(", ".join(order))
	eq(seen[0], "harden, slam", "the golem always guards before it swings")
	ok(seen[0] == seen[1] and seen[1] == seen[2],
		"and does it in that order on every seed (%s)" % "; ".join(seen))

## A condition is only worth having if it actually gates. Meowth only screeches
## once it is hurt, and cannot do so while it is healthy.
func test_enemy_move_conditions_gate_on_fight_state() -> void:
	Rng.set_seed(4242)
	var e := EnemyLibrary.spawn(&"coal_thief")
	var c := Combat.new(Player.new(), [e] as Array[Enemy], _deck(["strike"]))
	e.combat = c
	var gated: Array = e.moves.filter(func(m): return m.get("id", "") == "screech")
	ok(not gated.is_empty(), "the gated move still exists after the rename")
	if gated.is_empty():
		return
	var screech: Dictionary = gated.front()
	ok(not e._is_eligible(screech), "at full HP it has no reason to screech")
	e.hp = 1
	ok(e._is_eligible(screech), "hurt, the move switches on")

## `player_overloaded` is the condition that prices the player's own mechanic:
## Poliwag only turns nasty in response to something the player chose.
func test_enemy_conditions_read_the_players_state() -> void:
	Rng.set_seed(77)
	var c := _combat(["damper"], ["strike"])
	c.start()
	var e: Enemy = c.enemies[0]
	var gated: Array = e.moves.filter(func(m): return m.get("id", "") == "body_slam")
	ok(not gated.is_empty(), "the gated move still exists after the rename")
	if gated.is_empty():
		return
	var slam: Dictionary = gated.front()
	ok(not e._is_eligible(slam), "with no debt on the books it cannot use it")
	c.player.overload_pp(2)
	ok(e._is_eligible(slam), "carrying debt is what switches its big move on")

## A passive is a standing problem, so it has to come back every turn -- which
## means resolving AFTER Block clears, not before.
func test_enemy_passives_restore_the_guard_every_turn() -> void:
	Rng.set_seed(5)
	var c := _combat(["slag_shell"], ["strike", "strike", "strike", "strike", "strike"])
	c.start()
	var e: Enemy = c.enemies[0]
	eq(e.block, 7, "the shell starts the fight already guarded")
	c.play_card(c.hand[0], e)
	ok(e.block < 7, "a strike eats into the guard")
	c.end_turn()
	eq(e.block, 7, "and the passive puts exactly one guard back, not two")
	ok(e.passive_text != "", "and the shell says in words that it will keep doing that")

## Simmer is the answer to turtling: an enemy left alone gets stronger, so
## "block everything and wait for a better hand" stops being free.
func test_simmer_punishes_leaving_an_enemy_alone() -> void:
	Rng.set_seed(11)
	var idle := EnemyLibrary.spawn(&"kiln_hound")
	var c := Combat.new(Player.new(), [idle] as Array[Enemy], _deck(["strike"]))
	idle.combat = c
	eq(idle.status_stacks(&"simmer"), 2, "the hound comes with Simmer on it")
	idle.on_turn_end()
	eq(idle.status_stacks(&"strength"), 2, "left alone for a round, it grows")
	idle.take_damage(1, null, true)
	idle.on_turn_end()
	eq(idle.status_stacks(&"strength"), 2, "damaged, it does not")
	idle.on_turn_end()
	eq(idle.status_stacks(&"strength"), 4, "and the flag resets, so it grows again")

## Everything the enemy data can now say has to actually resolve: an opening
## naming a move that does not exist, or a condition nothing evaluates, is a
## silent behaviour bug rather than a crash.
func test_enemy_content_integrity() -> void:
	EnemyLibrary.load_all(true)
	var known_conditions := ["hp_below", "hp_above", "turn_at_least", "player_overloaded",
		"player_not_overloaded", "player_has_block", "alone"]
	var bad := 0
	var with_opening := 0
	var with_condition := 0
	for entry in EnemyLibrary._enemies.values():
		var id: String = entry.get("id", "?")
		var move_ids: Array = entry.get("moves", []).map(func(m): return String(m.get("id", "")))
		if move_ids.is_empty():
			bad += 1
			printerr("    enemy '%s' has no moves" % id)
		for move_id in entry.get("opening", []):
			with_opening += 1
			if not move_ids.has(String(move_id)):
				bad += 1
				printerr("    enemy '%s' opens with '%s', which is not one of its moves" % [id, move_id])
		for m in entry.get("moves", []):
			var cond = m.get("condition", {})
			if typeof(cond) == TYPE_DICTIONARY and not cond.is_empty():
				with_condition += 1
				if not known_conditions.has(String(cond.get("type", ""))):
					bad += 1
					printerr("    enemy '%s' move '%s' has unknown condition '%s'"
						% [id, m.get("id", "?"), cond.get("type", "")])
			# Every move must telegraph something the intent line can render.
			if String(m.get("intent", "UNKNOWN")).to_upper() == "UNKNOWN":
				bad += 1
				printerr("    enemy '%s' move '%s' has no intent kind" % [id, m.get("id", "?")])
		# Statuses and passives are built through the same factories as cards, so
		# a typo here surfaces as a push_error and no behaviour at all.
		for spec in entry.get("statuses", []):
			if StatusRegistry.get_status(StringName(spec.get("id", ""))) == null:
				bad += 1
				printerr("    enemy '%s' carries unknown status '%s'" % [id, spec.get("id", "")])
		for spec in entry.get("passives", []):
			if EffectFactory.build(spec) == null:
				bad += 1
				printerr("    enemy '%s' has an unbuildable passive" % id)
		# A passive the player is never told about is a rule they can only infer
		# from watching a bar refill, which is exactly what `tell` exists to stop.
		if not entry.get("passives", []).is_empty() and String(entry.get("passive_text", "")).is_empty():
			bad += 1
			printerr("    enemy '%s' has passives but no passive_text describing them" % id)
	eq(bad, 0, "every enemy's moves, opening, conditions, statuses and passives resolve")
	ok(with_opening >= 5, "the roster actually uses openings (%d scripted turns)" % with_opening)
	ok(with_condition >= 5, "and actually uses conditions (%d gated moves)" % with_condition)

## Spawning every enemy and every encounter, because a new enemy that is only
## reachable through one encounter table is a new enemy nobody tested.
func test_every_enemy_and_encounter_spawns() -> void:
	EnemyLibrary.load_all(true)
	Rng.set_seed(31337)
	var bad := 0
	for id in EnemyLibrary._enemies.keys():
		var e := EnemyLibrary.spawn(id)
		if e == null or e.max_hp <= 0 or e.moves.is_empty():
			bad += 1
			printerr("    enemy '%s' did not spawn usefully" % id)
	for entry in EnemyLibrary._encounters.values():
		var group := EnemyLibrary.encounter(StringName(entry.get("id", "")))
		if group.size() != entry.get("enemies", []).size():
			bad += 1
			printerr("    encounter '%s' spawned %d of %d enemies"
				% [entry.get("id", "?"), group.size(), entry.get("enemies", []).size()])
	eq(bad, 0, "every enemy and every encounter in the data spawns")

func test_seeded_shuffle_reproducible() -> void:
	var order_a := []
	var order_b := []
	for pass_i in 2:
		Rng.set_seed(4242)
		var deck := _deck(["strike", "defend", "kindle", "bellows", "vent", "quench", "pin"])
		Rng.shuffle_in(&"shuffle", deck)
		var ids := deck.map(func(c: Card): return String(c.data.id))
		if pass_i == 0: order_a = ids
		else: order_b = ids
	eq(order_a, order_b, "same seed produces the same shuffle")

func test_seeded_map_reproducible() -> void:
	var sig := func() -> String:
		Rng.set_seed(777)
		var m := MapGenerator.new()
		m.generate()
		var s := ""
		for r in m.rows:
			for n in r:
				s += "%d%d%d|" % [n.row, n.col, n.kind]
		return s
	eq(sig.call(), sig.call(), "same seed produces the same map")

func test_map_structure_rules() -> void:
	Rng.set_seed(20260831)
	var m := MapGenerator.new()
	m.generate()
	eq(m.rows.size(), MapGenerator.ROWS, "map has the expected row count")
	# One entrance, which then forks. The choice is the fan-out from the origin,
	# not a blind pick between several openings the player cannot compare.
	eq(m.starting_nodes().size(), 1, "the act opens on exactly one node")
	ok(m.origin != null and m.origin.kind == MapNode.Kind.DRAFT,
		"and that node is where the starting moves are drafted")
	eq(m.origin.next.size(), MapGenerator.PATHS,
		"which forks %d ways (got %d)" % [MapGenerator.PATHS, m.origin.next.size()])
	var violations := 0
	for r in MapGenerator.ROWS:
		for n in m.rows[r]:
			if n.kind == MapNode.Kind.ELITE and r < MapGenerator.NO_ELITE_BEFORE:
				violations += 1
			if n.kind == MapNode.Kind.CAMPFIRE and r < MapGenerator.NO_CAMPFIRE_BEFORE:
				violations += 1
			if r == 0 and n.kind != MapNode.Kind.COMBAT:
				violations += 1
			if r == MapGenerator.REST_ROW and n.kind != MapNode.Kind.CAMPFIRE:
				violations += 1
	eq(violations, 0, "row placement rules hold")
	ok(m.boss != null and not m.boss.prev.is_empty(), "boss is reachable from the rest row")
	# Every node must be reachable from row 0, or the map has orphans.
	var seen := {}
	var frontier: Array = m.starting_nodes().duplicate()
	while not frontier.is_empty():
		var n: MapNode = frontier.pop_back()
		if seen.has(n.key()):
			continue
		seen[n.key()] = true
		for nxt in n.next:
			frontier.append(nxt)
	var total := 0
	for r in m.rows:
		total += r.size()
	# Less the boss and the origin, neither of which lives in `rows`.
	eq(seen.size() - 2, total, "every node is reachable from the start")

func test_victory_and_defeat() -> void:
	var c := _combat(["cinder_rat"], ["crucible", "crucible", "crucible", "crucible", "crucible"])
	c.start()
	# Turn one is one pp now, and this test is about the victory check rather
	# than the curve -- so buy the 3-cost outright.
	c.player.gain_pp(2)
	ok(c.play_card(c.hand[0], c.enemies[0]), "the lethal card is affordable")
	eq(c.result, Combat.Result.VICTORY, "killing the last enemy wins")

	var d := _combat(["the_bellowsmith"], ["defend", "defend", "defend", "defend", "defend"], 5)
	d.start()
	for _i in 20:
		if d.result != Combat.Result.ONGOING:
			break
		d.end_turn()
	eq(d.result, Combat.Result.DEFEAT, "dying to enemies loses")

## The dev skip exists to test the REWARD flow, so it has to arrive there the
## same way a real win does. A shortcut that set `result` directly would prove
## nothing about the path a player takes -- and would quietly stop matching it.
func test_dev_win_takes_the_real_path() -> void:
	ok(not Dev.is_enabled(), "dev mode is off unless asked for")
	var c := _combat(["the_bellowsmith", "cinder_rat"], ["strike", "defend"])
	c.start()
	c.drain_events()
	eq(c.result, Combat.Result.ONGOING, "the fight is live to begin with")
	c.dev_win()
	eq(c.result, Combat.Result.VICTORY, "dev_win ends it as a win")
	var alive := 0
	for e in c.enemies:
		if e.is_alive():
			alive += 1
	eq(alive, 0, "every enemy is genuinely dead, not just flagged")
	ok(not c.drain_events().is_empty(),
		"and it pushed visual events, so the view animates a real kill")

func test_event_queue_drains() -> void:
	var c := _combat(["cinder_rat"], ["strike", "strike", "strike", "strike", "strike"])
	c.start()
	ok(c.event_queue.size() > 0, "simulation produced visual events")
	var drained := c.drain_events()
	ok(drained.size() > 0, "drain returns the events")
	eq(c.event_queue.size(), 0, "queue is empty after draining")
	var kinds := drained.map(func(e: VisualEvent): return e.kind)
	ok(kinds.has(VisualEvent.CARD_DRAWN), "draw produced CARD_DRAWN events")
	ok(kinds.has(VisualEvent.TURN_START), "turn start was recorded")


# --- Phase 2: run loop -----------------------------------------------------

func _run(seed_value: int = 555) -> RunState:
	return RunState.new_run(seed_value)

func test_run_state_creation() -> void:
	var r := _run()
	eq(r.deck.size(), 5, "starting deck is 5 cards")
	eq(r.hp, RunState.STARTING_HP, "starts at full HP")
	ok(r.has_relic(&"forge_mark"), "starts with the class relic")
	ok(r.map != null and not r.map.starting_nodes().is_empty(), "run has a generated map")
	eq(r.current_node, null, "run starts before the first node")

func test_relic_effects_apply_in_combat() -> void:
	Rng.set_seed(11)
	var p := Player.new("Charmander", 75)
	var es: Array[Enemy] = [EnemyLibrary.spawn(&"cracked_golem")]
	var relics := [ItemLibrary.get_relic(&"forge_mark"), ItemLibrary.get_relic(&"iron_tongs")]
	var c := Combat.new(p, es, _deck(["strike", "defend"]), relics)
	c.start()
	eq(p.max_pp, Player.PP_START + 1, "Forge Mark ramps at combat start")
	eq(p.block, 4, "Iron Tongs grants Block at combat start")

func test_relic_max_hp_heals_on_pickup() -> void:
	var r := _run()
	r.lose_hp(20)
	var hp_before := r.hp
	var max_before := r.max_hp
	r.add_relic(ItemLibrary.get_relic(&"ash_charm"))
	eq(r.max_hp, max_before + 8, "max HP relic raises the ceiling")
	eq(r.hp, hp_before + 8, "and heals for the same amount")

func test_relic_discounts_first_card() -> void:
	Rng.set_seed(12)
	var p := Player.new("Charmander", 75)
	var es: Array[Enemy] = [EnemyLibrary.spawn(&"the_bellowsmith")]
	var deck := _deck(["hammer_fall", "strike", "strike", "strike", "strike"])
	var c := Combat.new(p, es, deck, [ItemLibrary.get_relic(&"governor")])
	c.start()
	# Turn one, one pp. A 2-cost card is out of reach without the discount,
	# which makes turn one the cleanest place to prove the discount applies.
	eq(c.player.pp, 1, "turn one opens on one pp")
	var hammer: Card = null
	for card in c.hand:
		if card.data.id == &"hammer_fall":
			hammer = card
	ok(hammer != null, "the 2-cost card is in the opening hand")
	if hammer:
		eq(c.effective_cost(hammer), 1, "Governor discounts the first card of the turn")
		ok(c.play_card(hammer, c.enemies[0]), "so it is affordable on one pp")
		eq(c.player.pp, 0, "and it costs exactly the discounted price")
		# The discount is spent: everything after it pays full price.
		for card in c.hand:
			if card.data.id == &"strike":
				eq(c.effective_cost(card), 1, "the second card of the turn pays in full")
				break

func test_relic_bonus_draw() -> void:
	Rng.set_seed(13)
	var p := Player.new("Charmander", 75)
	var es: Array[Enemy] = [EnemyLibrary.spawn(&"cracked_golem")]
	var deck := _deck(["strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike"])
	var c := Combat.new(p, es, deck, [ItemLibrary.get_relic(&"ring_of_ash")])
	c.start()
	eq(c.hand.size(), Combat.HAND_SIZE + 1, "Ring of Ash draws one extra card")

func test_potion_use() -> void:
	var c := _combat(["cracked_golem"], ["strike"])
	c.start()
	var e := c.enemies[0]
	var hp := e.hp
	ok(c.use_potion(ItemLibrary.get_potion(&"fire_potion"), e), "potion resolves")
	eq(hp - e.hp, 20, "Fire Potion deals its damage")
	eq(c.player.pp, 1, "potions cost no pp")

func test_potion_slots_are_capped() -> void:
	var r := _run()
	for _i in RunState.POTION_SLOTS:
		ok(r.add_potion(ItemLibrary.get_potion(&"blood_potion")), "potion fits in a free slot")
	ok(not r.add_potion(ItemLibrary.get_potion(&"blood_potion")), "fourth potion is refused")

func test_potion_discard_frees_a_slot() -> void:
	var r := _run()
	var first := ItemLibrary.get_potion(&"blood_potion")
	r.add_potion(first)
	for _i in RunState.POTION_SLOTS - 1:
		r.add_potion(ItemLibrary.get_potion(&"fire_potion"))
	eq(r.potions.size(), RunState.POTION_SLOTS, "belt is full")
	ok(not r.add_potion(ItemLibrary.get_potion(&"fire_potion")), "and refuses a fourth")

	ok(r.discard_potion(first), "a held potion can be discarded")
	eq(r.potions.size(), RunState.POTION_SLOTS - 1, "which frees exactly one slot")
	ok(r.add_potion(ItemLibrary.get_potion(&"fire_potion")), "the freed slot takes a new potion")

	ok(not r.discard_potion(ItemLibrary.get_potion(&"blood_potion")),
		"discarding a potion you do not hold is refused")
	eq(r.potions.size(), RunState.POTION_SLOTS, "and changes nothing")

func test_card_rewards_are_distinct() -> void:
	Rng.set_seed(31337)
	for _trial in 20:
		var choices := Rewards.card_choices()
		eq(choices.size(), Rewards.CARD_CHOICES, "reward offers three cards")
		var ids := {}
		for c in choices:
			ids[c.data.id] = true
		eq(ids.size(), choices.size(), "reward cards are all different")

func test_shop_purchase_spends_gold() -> void:
	var r := _run(88)
	r.gold = 1000
	var deck_before := r.deck.size()
	var s := Shop.generate(r)
	ok(not s.cards.is_empty(), "shop stocks cards")
	var price: int = s.cards[0]["price"]
	eq(s.buy_card(r, 0), "", "purchase succeeds")
	eq(r.gold, 1000 - price, "gold is deducted")
	eq(r.deck.size(), deck_before + 1, "card enters the deck")
	ok(s.buy_card(r, 0) != "", "the same item cannot be bought twice")

func test_shop_refuses_when_broke() -> void:
	var r := _run(89)
	r.gold = 0
	var s := Shop.generate(r)
	eq(s.buy_card(r, 0), "not enough gold", "shop refuses and says why")
	eq(r.deck.size(), 5, "deck is unchanged after a failed purchase")

func test_shop_card_removal() -> void:
	var r := _run(90)
	r.gold = 1000
	var s := Shop.generate(r)
	var target: Card = r.deck[0]
	eq(s.buy_removal(r, target), "", "removal succeeds")
	eq(r.deck.size(), 4, "card leaves the deck")
	ok(s.buy_removal(r, r.deck[0]) != "", "removal is once per shop")

## Every shop stocks its full slate.
##
## Shop.generate() filled a fixed five slots with `for i in 5` and skipped the
## slot on a repeat pick, so a collision shipped a four-card shop -- silently,
## with nothing on screen to say a slot had been lost. Same for the three potion
## slots, where a repeat is far likelier because there are only eleven potions.
func test_shop_always_stocks_its_full_slate() -> void:
	var short_cards := 0
	var short_potions := 0
	var dupes := 0
	for i in 120:
		var r := _run(4000 + i)
		var s := Shop.generate(r)
		if s.cards.size() < 5:
			short_cards += 1
		if s.potions.size() < 3:
			short_potions += 1
		var ids := {}
		for e in s.cards:
			var id = e["card"].data.id
			if ids.has(id):
				dupes += 1
			ids[id] = true
	eq(short_cards, 0, "every shop stocks five cards")
	eq(short_potions, 0, "every shop stocks three potions")
	eq(dupes, 0, "no shop lists the same card twice")

## Contact reaches the view, and only for moves that make it.
##
## The animation branches on a flag threaded from the card JSON through
## DealDamageEffect and take_damage onto the DAMAGE event. Every link is silent
## if it breaks: the move simply stops charging and nothing errors.
func test_contact_reaches_the_damage_event() -> void:
	for spec in [["strike", true], ["ember_jab", false]]:
		var id: String = spec[0]
		var want: bool = spec[1]
		var c := _combat(["cinder_rat"], [id, id])
		c.start()
		c.drain_events()
		var card: Card = null
		for h in c.hand:
			if String(h.data.id) == id:
				card = h
				break
		ok(card != null, "%s is in hand to play" % id)
		if card == null:
			continue
		c.play_card(card, c.living_enemies().front())
		var seen := false
		var flag := false
		for ev in c.drain_events():
			if ev.kind == VisualEvent.DAMAGE:
				seen = true
				flag = bool(ev.data.get("contact", false))
		ok(seen, "%s produced a damage event" % id)
		eq(flag, want, "%s contact flag reaches the view" % id)

func test_event_choices_apply() -> void:
	var r := _run(91)
	r.lose_hp(30)
	var ev := EventLibrary.get_event(&"the_slag_pool")
	ok(not ev.is_empty(), "event loads by id")
	var hp_before := r.hp
	var lines := EventLibrary.choose(r, ev, 1)   # "Warm yourself": heal 12
	eq(r.hp, hp_before + 12, "event choice heals")
	ok(lines.size() > 0, "event reports what happened")

func test_event_content_integrity() -> void:
	var all := EventLibrary.all()
	ok(all.size() >= 5, "events loaded (%d)" % all.size())
	var bad := 0
	for e in all:
		if String(e.get("title", "")).is_empty() or String(e.get("text", "")).is_empty():
			bad += 1
		if (e.get("choices", []) as Array).size() < 2:
			bad += 1
			printerr("    event '%s' has fewer than two choices" % e.get("id", "?"))
	eq(bad, 0, "every event has a title, body and at least two choices")

	# Requirements can lock a choice, so the authoring rule is that no run state
	# may lock ALL of them -- an event you cannot answer is a softlock. Checked
	# against a deliberately destitute run: no gold, 1 HP, a full potion belt and
	# a deck with nothing left to upgrade and nothing safe to remove.
	var destitute := RunState.new_run(4242)
	destitute.gold = 0
	destitute.hp = 1
	destitute.deck.clear()
	destitute.deck.append(CardLibrary.make(&"strike", true))
	while destitute.add_potion(ItemLibrary.get_potion(&"fire_potion")):
		pass
	var starved := 0
	for e in all:
		if EventLibrary.available_choices(destitute, e).is_empty():
			starved += 1
			printerr("    event '%s' offers nothing to a run with nothing" % e.get("id", "?"))
	eq(starved, 0, "no event can be locked shut by the run state")

	# And the gate is real: the rules layer refuses a choice the run cannot pay
	# for, whatever the screen drawing it believes.
	var toll := EventLibrary.get_event(&"the_toll")
	# Found by what it REQUIRES, not by what it is called. Looking it up by label
	# meant the event's prose could not be rewritten without editing this test.
	var pay_index := -1
	for i in (toll.get("choices", []) as Array).size():
		if (toll["choices"][i].get("requires", {}) as Dictionary).has("gold"):
			pay_index = i
	ok(pay_index >= 0, "the toll still has a choice that costs gold")
	ok(EventLibrary.unmet_requirement(destitute, toll["choices"][pay_index]) != "",
		"a broke run cannot pay the toll")
	var relics_before := destitute.relics.size()
	eq(EventLibrary.choose(destitute, toll, pay_index).size(), 0,
		"and taking it anyway resolves to nothing")
	eq(destitute.relics.size(), relics_before, "so no relic is handed out for free")

	var rich := RunState.new_run(4242)
	rich.gold = 60
	eq(EventLibrary.unmet_requirement(rich, toll["choices"][pay_index]), "",
		"60 gold opens the toll")
	ok(EventLibrary.choose(rich, toll, pay_index).size() > 0, "and paying it resolves")
	eq(rich.gold, 0, "the toll takes the full price")

func test_map_traversal_is_legal() -> void:
	var r := _run(92)
	ok(not r.can_enter(r.map.boss), "cannot jump straight to the boss")
	var first: MapNode = r.map.starting_nodes()[0]
	ok(r.enter(first), "can enter a row 0 node")
	eq(r.current_node, first, "position updates")
	var reachable := r.available_nodes()
	ok(not reachable.is_empty(), "there is somewhere to go next")
	ok(not r.can_enter(first), "cannot re-enter the node you are standing on")
	ok(r.enter(reachable[0]), "can advance along an edge")

func test_rest_heal_amount() -> void:
	var r := _run(93)
	eq(r.rest_heal_amount(), int(round(r.max_hp * RunState.REST_HEAL_FRACTION)), "rest heals 30% of max HP")
	r.add_relic(ItemLibrary.get_relic(&"coal_ration"))
	eq(r.rest_heal_amount(), int(round(r.max_hp * RunState.REST_HEAL_FRACTION)) + 6, "Coal Ration adds to the rest heal")

func test_save_load_roundtrip() -> void:
	var r := _run(4242)
	r.gold = 237
	r.lose_hp(19)
	r.add_relic(ItemLibrary.get_relic(&"whetstone"))
	r.add_potion(ItemLibrary.get_potion(&"ember_flask"))
	r.add_card(CardLibrary.make(&"vent", true))
	r.enter(r.map.starting_nodes()[0])
	r.enter(r.available_nodes()[0])
	# Both of these used to live on RunScreen and went unsaved: reloading reset
	# the removal price to base and re-offered events the run had resolved.
	r.removals_used = 2
	r.seen_events = ["the_toll"]
	eq(r.save(), OK, "run saves to disk")

	var loaded := RunState.load_run()
	ok(loaded != null, "run loads back")
	if loaded == null:
		return
	eq(loaded.hp, r.hp, "hp survives the round trip")
	eq(loaded.gold, r.gold, "gold survives")
	eq(loaded.max_hp, r.max_hp, "max hp survives")
	eq(loaded.deck.size(), r.deck.size(), "deck size survives")
	eq(loaded.removals_used, 2, "shop removals used survive the round trip")
	eq(str(loaded.seen_events), str(["the_toll"]), "resolved events survive the round trip")
	eq(loaded.relics.size(), r.relics.size(), "relics survive")
	eq(loaded.potions.size(), r.potions.size(), "potions survive")
	eq(loaded.current_node.key(), r.current_node.key(), "map position survives")
	var upgraded_before: int = r.deck.filter(func(c: Card): return c.upgraded).size()
	var upgraded_after: int = loaded.deck.filter(func(c: Card): return c.upgraded).size()
	eq(upgraded_after, upgraded_before, "card upgrade state survives")
	# The map is regenerated from the seed rather than stored -- prove it matches.
	eq(loaded.map.rows[0].size(), r.map.rows[0].size(), "regenerated map matches the original")
	RunState.delete_save()

func test_relic_content_integrity() -> void:
	var all := ItemLibrary.all_relics()
	ok(all.size() >= 12, "relics loaded (%d)" % all.size())
	var bad := 0
	for r in all:
		if r.title.is_empty() or r.text.is_empty():
			bad += 1
			printerr("    relic '%s' missing title or text" % r.id)
		var does_something: bool = (
			r.bonus_max_hp != 0 or r.bonus_max_pp != 0 or r.bonus_card_draw != 0
			or r.discounts_first_card or r.bonus_rest_heal != 0
			or not r.on_combat_start.is_empty() or not r.on_turn_start.is_empty()
		)
		if not does_something:
			bad += 1
			printerr("    relic '%s' has no effect at all" % r.id)
	eq(bad, 0, "every relic has text and does something")
	var potions := ItemLibrary.all_potions()
	var bad_potions := 0
	for pt in potions:
		if pt.effects.is_empty() or pt.title.is_empty():
			bad_potions += 1
	eq(bad_potions, 0, "every potion has a title and an effect")


# --- integration -----------------------------------------------------------

## Plays a combat to completion with a greedy "play anything legal" policy.
## Returns the result. Deliberately dumb -- the point is to hammer state
## transitions, not to play well.
## Set when the action cap is hit, which means some card combination lets the
## player act without bound -- a free draw engine, or a card that fails to leave
## the hand. Surfaced as a test failure rather than an infinite loop.
var _loop_detected := false

const MAX_ACTIONS_PER_TURN := 80

func _auto_play(c: Combat, max_turns: int = 60) -> int:
	var turns := 0
	while c.result == Combat.Result.ONGOING and turns < max_turns:
		turns += 1
		var actions := 0
		var acted := true
		while acted and c.result == Combat.Result.ONGOING:
			acted = false
			for card in c.hand.duplicate():
				if c.can_play(card):
					var living := c.living_enemies()
					if not c.play_card(card, living.front() if not living.is_empty() else null):
						continue   # refused: try the next card rather than spinning
					acted = true
					actions += 1
					break
			if actions > MAX_ACTIONS_PER_TURN:
				_loop_detected = true
				printerr("    unbounded action loop: %d plays in one turn" % actions)
				return c.result
		if c.result != Combat.Result.ONGOING:
			break
		c.end_turn()
	return c.result

## Card conservation: every card dealt into the combat must be in exactly one
## pile at all times. A leak here means cards are being duplicated or dropped.
func _check_invariants(c: Combat, deck_size: int, added: int, where: String) -> int:
	var problems := 0
	var total := c.draw_pile.size() + c.hand.size() + c.discard_pile.size() + c.exhaust_pile.size()
	if total != deck_size + added:
		printerr("    %s: %d cards across piles, expected %d" % [where, total, deck_size + added])
		problems += 1
	if c.player.hp < 0 or c.player.hp > c.player.max_hp:
		printerr("    %s: hp out of range (%d/%d)" % [where, c.player.hp, c.player.max_hp])
		problems += 1
	if c.player.block < 0 or c.player.pp < 0:
		printerr("    %s: block or pp went negative" % where)
		problems += 1
	if c.player.max_pp > c.player.pp_cap or c.player.overload < 0:
		printerr("    %s: pp curve out of range (max %d cap %d overload %d)" % [
			where, c.player.max_pp, c.player.pp_cap, c.player.overload])
		problems += 1
	if c.hand.size() > Combat.MAX_HAND:
		printerr("    %s: hand overflowed (%d)" % [where, c.hand.size()])
		problems += 1
	for e in c.enemies:
		if e.hp < 0 or e.hp > e.max_hp:
			problems += 1
	return problems

## A cue that resolves to no file is silent, and silence is indistinguishable
## from "this action has no sound yet" -- so a typo in a cue name would only
## ever be caught by someone listening for a sound they did not know to expect.
func test_every_audio_cue_resolves() -> void:
	var missing := 0
	for cue in [&"card_draw", &"card_play", &"hit", &"hit_heavy", &"block",
			&"ramp", &"overload", &"pp", &"death", &"turn", &"gold",
			&"ui", &"victory"]:
		if not Audio.has_cue(cue):
			missing += 1
			printerr("    audio cue '%s' resolves to no file" % cue)
	eq(missing, 0, "every audio cue maps to a real sound file")

func test_combat_invariants_hold_under_autoplay() -> void:
	var encounter_ids := ["easy_rats", "easy_wisps", "norm_imp_pack", "norm_golem",
						  "norm_swarm", "norm_foundry", "elite_warden", "boss_smith"]
	var problems := 0
	var unfinished := 0
	for i in 24:
		Rng.set_seed(9000 + i)
		var eid: String = encounter_ids[i % encounter_ids.size()]
		var enemies := EnemyLibrary.encounter(StringName(eid))
		if enemies.is_empty():
			continue
		var deck := RunState.starting_deck()
		# Salt the deck so exhaust, powers, potions, ramp and overload all get exercised.
		for extra in ["ember_jab", "vent", "stoke", "afterburn", "kindling",
					  "immolate", "last_ember", "forge_guard", "tongs", "crucible"]:
			deck.append(CardLibrary.make(StringName(extra)))
		var p := Player.new("Charmander", 200)   # tanky, so combats actually finish
		var c := Combat.new(p, enemies, deck, [ItemLibrary.get_relic(&"forge_mark")])
		c.start()
		problems += _check_invariants(c, deck.size(), 0, "%s@start" % eid)
		var result := _auto_play(c)
		problems += _check_invariants(c, deck.size(), 0, "%s@end" % eid)
		if result == Combat.Result.ONGOING:
			unfinished += 1
			printerr("    %s did not terminate within the turn cap" % eid)
	eq(problems, 0, "combat invariants hold across 24 autoplayed encounters")
	eq(unfinished, 0, "every autoplayed combat terminated")
	ok(not _loop_detected, "no card combination allows unbounded actions in a turn")

func test_full_run_simulation() -> void:
	var reached_boss := 0
	var died := 0
	var stalls := 0
	var dead_ends := 0
	var boss_kills := 0
	for trial in 6:
		var run := RunState.new_run(70000 + trial * 13)
		var guard := 0
		var finished := false
		var beat_boss := false
		while guard < 40:
			guard += 1
			if run.is_dead():
				died += 1
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
					elif node.row < 3: kind = "easy"
					var pool := EnemyLibrary.encounters_of_kind(kind)
					var chosen = Rng.pick_in(&"enemy_ai", pool)
					var enemies := EnemyLibrary.encounter(StringName(chosen.get("id", "")))
					var p := Player.new("Charmander", run.max_hp)
					p.hp = run.hp
					var c := Combat.new(p, enemies, run.deck, run.relics)
					c.start()
					var res := _auto_play(c)
					run.hp = p.hp
					if res == Combat.Result.VICTORY and node.kind == MapNode.Kind.BOSS:
						beat_boss = true
					if res == Combat.Result.VICTORY:
						run.gold += Rewards.gold_for(kind)
						var choices := Rewards.card_choices()
						if not choices.is_empty():
							run.add_card(choices[0])
						if kind == "elite":
							run.add_relic(Rewards.relic(run.relics))
				MapNode.Kind.EVENT:
					var ev := EventLibrary.pick([])
					if not ev.is_empty():
						# The greedy policy takes the first choice it can afford,
						# which is also what proves a dead end is never reachable.
						var open_choices := EventLibrary.available_choices(run, ev)
						if open_choices.is_empty():
							dead_ends += 1
							printerr("    event '%s' offered nothing takeable" % ev.get("id", "?"))
						else:
							EventLibrary.choose(run, ev, open_choices[0])
				MapNode.Kind.SHOP:
					run.gold += 200
					var shop := Shop.generate(run)
					shop.buy_card(run, 0)
				MapNode.Kind.CAMPFIRE:
					run.heal(run.rest_heal_amount())
				MapNode.Kind.TREASURE:
					run.gold += Rewards.gold_for("treasure")
			run.complete_node()
			if node.kind == MapNode.Kind.BOSS:
				reached_boss += 1
				if beat_boss:
					boss_kills += 1
				finished = true
				break
		if not finished:
			stalls += 1
			printerr("    run %d neither died nor reached the boss (floors %d)" % [trial, run.floors_cleared])
		# Invariants that must hold no matter how the run went.
		if run.hp > run.max_hp:
			printerr("    run %d ended above max HP" % trial)
			stalls += 1
		if run.gold < 0:
			printerr("    run %d ended with negative gold" % trial)
			stalls += 1

	eq(dead_ends, 0, "no simulated event ever left the player with nothing to pick")
	eq(stalls, 0, "every simulated run reached a terminal state with valid stats")
	ok(reached_boss + died == 6, "all 6 runs resolved (%d reached the boss, %d died)" % [reached_boss, died])
	ok(reached_boss > 0, "a full path from stage 0 to the boss is walkable")
	# Reaching the boss and beating it are different questions, and only the
	# second one means the act can actually be completed.
	ok(boss_kills > 0, "the act is completable: %d of %d runs that reached the boss killed it"
		% [boss_kills, reached_boss])
