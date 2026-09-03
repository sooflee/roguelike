class_name RunEffects
extends RefCounted
## Effects that act on the RUN rather than on a combat: healing at events,
## gaining gold, adding a relic.
##
## Deliberately a separate, tiny vocabulary from CardEffect. Card effects need a
## Combat to resolve against; these need a RunState. Forcing one system to do
## both would mean every card effect carrying a null-combat branch.

## Applies one effect and returns a short human-readable line describing what
## happened, for the event log.
static func apply(run: RunState, spec: Dictionary) -> String:
	var type := StringName(spec.get("type", ""))
	var amount := int(spec.get("amount", 0))
	match type:
		&"heal":
			var healed := run.heal(amount)
			return "Healed %d HP." % healed
		&"lose_hp":
			run.lose_hp(amount)
			return "Lost %d HP." % amount
		&"max_hp":
			run.max_hp += amount
			run.hp = mini(run.hp + maxi(0, amount), run.max_hp)
			return "Max HP %s%d." % ["+" if amount >= 0 else "", amount]
		&"gold":
			run.gold += amount
			return "Gained %d gold." % amount
		&"lose_gold":
			var lost := mini(run.gold, amount)
			run.gold -= lost
			return "Lost %d gold." % lost
		&"add_card":
			var c := CardLibrary.make(StringName(spec.get("card", "")))
			if c == null:
				return ""
			run.add_card(c)
			return "Added %s to your deck." % c.title()
		&"add_relic":
			var rid := StringName(spec.get("relic", ""))
			var relic := Rewards.relic(run.relics) if rid == &"" else ItemLibrary.get_relic(rid)
			if relic == null:
				return ""
			# add_relic refuses a duplicate silently, so ask before announcing it.
			if run.has_relic(relic.id):
				return ""
			run.add_relic(relic)
			return "Obtained %s." % relic.title
		&"add_potion":
			var pid := StringName(spec.get("potion", ""))
			var pot := Rewards.potion() if pid == &"" else ItemLibrary.get_potion(pid)
			if pot == null:
				return ""
			if not run.add_potion(pot):
				return "No free potion slot -- %s was left behind." % pot.title
			return "Obtained %s." % pot.title
		&"upgrade_random":
			var pool := run.upgradeable_cards()
			if pool.is_empty():
				return "Nothing left to upgrade."
			var c2: Card = Rng.pick_in(&"events", pool)
			c2.upgrade()
			return "Upgraded %s." % c2.title()
		&"remove_random":
			if run.deck.is_empty():
				return ""
			var c3: Card = Rng.pick_in(&"events", run.deck)
			var name := c3.title()
			run.remove_card(c3)
			return "Removed %s from your deck." % name
		_:
			push_error("RunEffects: unknown effect type '%s'" % type)
			return ""

static func apply_all(run: RunState, specs) -> Array[String]:
	var lines: Array[String] = []
	for s in specs:
		var line := apply(run, s as Dictionary)
		if line != "":
			lines.append(line)
	return lines
