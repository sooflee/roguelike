class_name EffectFactory
extends RefCounted
## Builds CardEffect instances from plain dictionaries (parsed JSON).
##
## Content lives in data/*.json rather than .tres: JSON is diffable in review,
## editable without opening the Godot editor, and loadable in headless tests.
## The runtime objects are still Resources, so a .tres pipeline remains possible
## later without touching any effect code.

static func build(spec: Dictionary) -> CardEffect:
	var type := StringName(spec.get("type", ""))
	var e: CardEffect = null
	match type:
		&"damage":
			var d := DealDamageEffect.new()
			d.amount = int(spec.get("amount", 6))
			d.hits = int(spec.get("hits", 1))
			d.bypass_block = bool(spec.get("bypass_block", false))
			d.contact = bool(spec.get("contact", false))
			d.target_mode = _enum_of(DealDamageEffect.TargetMode, spec.get("target_mode", "TARGETS"))
			e = d
		&"block":
			var b := GainBlockEffect.new()
			b.amount = int(spec.get("amount", 5))
			b.to_targets = bool(spec.get("to_targets", false))
			e = b
		&"status":
			var s := ApplyStatusEffect.new()
			s.status_id = StringName(spec.get("status", "vulnerable"))
			s.stacks = int(spec.get("stacks", 1))
			s.to_self = bool(spec.get("to_self", false))
			e = s
		&"ramp":
			var rm := RampPPEffect.new()
			rm.amount = int(spec.get("amount", 1))
			e = rm
		&"overload":
			var ov := OverloadEffect.new()
			ov.amount = int(spec.get("amount", 1))
			e = ov
		&"clear_overload":
			e = ClearOverloadEffect.new()
		&"drain_ramp":
			var dp := DrainRampEffect.new()
			dp.amount = int(spec.get("amount", 1))
			e = dp
		&"draw":
			var dr := DrawCardsEffect.new()
			dr.amount = int(spec.get("amount", 1))
			e = dr
		&"pp":
			var gm := GainPPEffect.new()
			gm.amount = int(spec.get("amount", 1))
			e = gm
		&"spend_pp":
			var sm := SpendPPEffect.new()
			sm.max_spend = int(spec.get("max_spend", 5))
			sm.per_pp = int(spec.get("per_pp", 2))
			sm.payout = _enum_of(SpendPPEffect.Payout, spec.get("payout", "DAMAGE"))
			e = sm
		&"heal":
			var hl := HealEffect.new()
			hl.amount = int(spec.get("amount", 4))
			hl.to_targets = bool(spec.get("to_targets", false))
			e = hl
		&"conditional":
			var c := ConditionalEffect.new()
			c.condition = StringName(spec.get("condition", "overloaded"))
			c.invert = bool(spec.get("invert", false))
			c.effects = build_list(spec.get("effects", []))
			e = c
		&"add_card":
			var ac := AddCardToPileEffect.new()
			ac.card_id = StringName(spec.get("card", "burn"))
			ac.count = int(spec.get("count", 1))
			ac.pile = _enum_of(AddCardToPileEffect.Pile, spec.get("pile", "DISCARD"))
			e = ac
		_:
			push_error("EffectFactory: unknown effect type '%s'" % type)
			return null
	e.upgrade_bonus = int(spec.get("upgrade_bonus", 0))
	return e

static func build_list(specs) -> Array[CardEffect]:
	var out: Array[CardEffect] = []
	for s in specs:
		var e := build(s as Dictionary)
		if e:
			out.append(e)
	return out

static func _enum_of(enum_dict: Dictionary, key) -> int:
	var k := String(key).to_upper()
	return int(enum_dict.get(k, enum_dict.values()[0]))
