class_name Shop
extends RefCounted
## Generated shop stock. Prices carry +/-10% variance so two shops in a run never
## feel like the same vending machine.

const BASE_CARD_PRICE := {
	CardData.Rarity.COMMON: 50,
	CardData.Rarity.UNCOMMON: 75,
	CardData.Rarity.RARE: 150,
}
const BASE_RELIC_PRICE := {
	RelicData.Rarity.COMMON: 150,
	RelicData.Rarity.UNCOMMON: 250,
	RelicData.Rarity.RARE: 300,
	RelicData.Rarity.BOSS: 300,
	RelicData.Rarity.SHOP: 150,
	RelicData.Rarity.EVENT: 150,
	RelicData.Rarity.STARTER: 150,
}
const REMOVAL_BASE := 75
const REMOVAL_INCREMENT := 25

var cards: Array = []      ## [{card: Card, price: int, sold: bool}]
var relics: Array = []     ## [{relic: RelicData, price: int, sold: bool}]
var potions: Array = []    ## [{potion: PotionData, price: int, sold: bool}]
var removal_price: int = REMOVAL_BASE
var removal_used: bool = false

static func generate(run: RunState, removals_so_far: int = 0) -> Shop:
	var s := Shop.new()
	# The shop is the TM counter. Two of its five slots are reserved for TMs, so
	# a player who wants an answer to a matchup always has somewhere to buy one
	# -- and the shop stops being interchangeable with a combat reward.
	var pool := CardLibrary.purchasable()
	var tm_pool := CardLibrary.tms()
	var seen := {}
	# Re-roll a repeat instead of dropping the slot. A fixed `for i in 5`
	# pass that skipped on a collision shipped a four-card shop in 27% of
	# runs and a two-potion shelf in 26% -- silently, with nothing on screen
	# to say a slot had been lost. Rewards.card_choices() has always filled
	# its slots this way; the shop simply never followed it.
	if tm_pool.is_empty():
		_stock_cards(s, pool, 5, seen)
	else:
		_stock_cards(s, tm_pool, 2, seen)
		_stock_cards(s, pool, 3, seen)

	var relic := Rewards.relic(run.relics)
	if relic:
		s.relics.append({"relic": relic, "price": _vary(BASE_RELIC_PRICE[relic.rarity]), "sold": false})

	var potion_seen := {}
	var potions := ItemLibrary.all_potions()
	var guard := 0
	while s.potions.size() < 3 and guard < 200:
		guard += 1
		var p: PotionData = Rng.pick_in(&"shop", potions)
		if p == null:
			break
		if potion_seen.has(p.id):
			continue
		potion_seen[p.id] = true
		s.potions.append({"potion": p, "price": _vary(p.base_price()), "sold": false})

	s.removal_price = REMOVAL_BASE + REMOVAL_INCREMENT * removals_so_far
	return s

## Adds `count` distinct cards from `from`, skipping anything already stocked.
## Bounded, because a pool with fewer unseen entries than slots has no answer
## and must not spin.
static func _stock_cards(s: Shop, from: Array, count: int, seen: Dictionary) -> void:
	if from.is_empty():
		return
	var added := 0
	var guard := 0
	while added < count and guard < 200:
		guard += 1
		var pick: CardData = Rng.pick_in(&"shop", from)
		if pick == null:
			return
		if seen.has(pick.id):
			continue
		seen[pick.id] = true
		s.cards.append({"card": Card.new(pick),
			"price": _vary(BASE_CARD_PRICE[pick.rarity]), "sold": false})
		added += 1

static func _vary(base: int) -> int:
	var factor := 0.9 + Rng.randf_in(&"shop") * 0.2
	return maxi(1, int(round(base * factor)))

## Returns an empty string on success, or the reason it failed.
func buy_card(run: RunState, index: int) -> String:
	if index < 0 or index >= cards.size():
		return "no such item"
	var entry: Dictionary = cards[index]
	if entry["sold"]:
		return "already sold"
	if run.gold < entry["price"]:
		return "not enough gold"
	run.gold -= entry["price"]
	run.add_card(entry["card"])
	entry["sold"] = true
	return ""

func buy_relic(run: RunState, index: int) -> String:
	if index < 0 or index >= relics.size():
		return "no such item"
	var entry: Dictionary = relics[index]
	if entry["sold"]:
		return "already sold"
	if run.gold < entry["price"]:
		return "not enough gold"
	run.gold -= entry["price"]
	run.add_relic(entry["relic"])
	entry["sold"] = true
	return ""

func buy_potion(run: RunState, index: int) -> String:
	if index < 0 or index >= potions.size():
		return "no such item"
	var entry: Dictionary = potions[index]
	if entry["sold"]:
		return "already sold"
	if run.gold < entry["price"]:
		return "not enough gold"
	if run.potions.size() >= RunState.POTION_SLOTS:
		return "no free potion slot"
	run.gold -= entry["price"]
	run.add_potion(entry["potion"])
	entry["sold"] = true
	return ""

func buy_removal(run: RunState, card: Card) -> String:
	if removal_used:
		return "removal already used"
	if run.gold < removal_price:
		return "not enough gold"
	if not run.remove_card(card):
		return "card not in deck"
	run.gold -= removal_price
	removal_used = true
	return ""
