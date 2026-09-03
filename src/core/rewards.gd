class_name Rewards
extends RefCounted
## Post-combat and treasure rewards. All draws come from the `rewards` RNG stream
## so reward rolls stay independent of combat shuffles (docs/DECISIONS.md D-15).

const CARD_CHOICES := 3

## Spire-adjacent weights. Rare cards should feel like an event, not a Tuesday.
const CARD_WEIGHTS := {
	CardData.Rarity.COMMON: 60,
	CardData.Rarity.UNCOMMON: 37,
	CardData.Rarity.RARE: 3,
}

const RELIC_WEIGHTS := {
	RelicData.Rarity.COMMON: 50,
	RelicData.Rarity.UNCOMMON: 33,
	RelicData.Rarity.RARE: 17,
}

## Distinct cards, so a reward screen never offers the same card twice.
static func card_choices(count: int = CARD_CHOICES) -> Array[Card]:
	var pool := CardLibrary.draftable()
	var out: Array[Card] = []
	var seen := {}
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var rarity := _roll_weighted(CARD_WEIGHTS)
		var tier := pool.filter(func(c: CardData): return c.rarity == rarity)
		if tier.is_empty():
			continue
		var pick: CardData = Rng.pick_in(&"rewards", tier)
		if pick == null or seen.has(pick.id):
			continue
		seen[pick.id] = true
		out.append(Card.new(pick))
	return out

static func gold_for(kind: String) -> int:
	match kind:
		"elite":
			return Rng.randi_range_in(&"rewards", 25, 35)
		"boss":
			return Rng.randi_range_in(&"rewards", 95, 105)
		"treasure":
			return Rng.randi_range_in(&"rewards", 45, 65)
		_:
			return Rng.randi_range_in(&"rewards", 10, 20)

static func relic(exclude: Array = []) -> RelicData:
	var owned := {}
	for r in exclude:
		owned[r.id] = true
	# Boss relics are reserved for boss rewards, not ordinary drops.
	var pool := ItemLibrary.droppable_relics().filter(
		func(r: RelicData): return not owned.has(r.id) and r.rarity != RelicData.Rarity.BOSS)
	if pool.is_empty():
		return null
	var rarity := _roll_weighted(RELIC_WEIGHTS)
	var tier := pool.filter(func(r: RelicData): return r.rarity == rarity)
	if tier.is_empty():
		tier = pool
	return Rng.pick_in(&"rewards", tier)

static func boss_relic(exclude: Array = []) -> RelicData:
	var owned := {}
	for r in exclude:
		owned[r.id] = true
	var pool := ItemLibrary.all_relics().filter(
		func(r: RelicData): return r.rarity == RelicData.Rarity.BOSS and not owned.has(r.id))
	return Rng.pick_in(&"rewards", pool)

static func potion() -> PotionData:
	var pool := ItemLibrary.all_potions()
	return Rng.pick_in(&"rewards", pool)

## 40% base, the standard Spire potion drop rate.
static func rolls_potion() -> bool:
	return Rng.randf_in(&"rewards") < 0.4

static func _roll_weighted(weights: Dictionary) -> int:
	var total := 0
	for k in weights:
		total += weights[k]
	var roll := Rng.randi_range_in(&"rewards", 1, maxi(1, total))
	var acc := 0
	for k in weights:
		acc += weights[k]
		if roll <= acc:
			return k
	return weights.keys()[0]
