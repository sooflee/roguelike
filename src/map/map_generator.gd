class_name MapGenerator
extends RefCounted
## Slay-the-Spire-style layered DAG.
##
## Seeds N paths down the first stage and walks each forward, drifting at most
## one lane per step. Edges that would cross are rejected, which is what keeps
## the map legible rather than a hairball.
##
## An act is STAGES long and the last stage IS the boss, so the generated grid
## is one shorter than the act: ROWS of ordinary nodes, then the boss. The
## DRAFT entrance at row -1 is not generated here and is not a stage.

## Stops in an act, boss included. SEVEN, not the eight docs/proposals/
## act1-shortened.md asked for: ROWS was STAGES - 2, one row short of the
## comment below, so the act has always been a stage briefer than designed.
## Stated as 7 here rather than silently generating 7 from an 8 -- lengthening
## it is a balance decision (it costs about 8 points of boss kill rate) and
## belongs with the other retuning, not in a constant nobody reads.
const STAGES := 7
## Ordinary stages: everything except the boss, which _attach_boss() adds at
## row ROWS. One shorter than the act, matching the docstring above -- this
## comment described a STAGES - 2 grid and the constant no longer is one.
const ROWS := STAGES - 1
const WIDTH := 7                    ## lanes
## Four rather than six: across seven stages, six paths fill almost every lane
## and the map stops offering a choice -- everything reaches everything.
const PATHS := 4

const TREASURE_ROW := 3             ## mid-act, as the run's one guaranteed windfall
## The guaranteed campfire.
##
## MEASURED, and left where it is. The obvious read of the attrition curve is
## that this rest refunds the walk right before the boss, so it was moved to
## ROWS - 2 and the harness re-run on the same 60 seeds. Median HP at the boss
## did drop 75 -> 60, but the boss simply killed the difference: kill rate stayed
## at 33.3% and the walk got SAFER, 11 deaths to 3, because the last weighted row
## now follows a full heal. Shrinking the heal to 0.2 instead moved the kill rate
## to 30.0% and left walk deaths at 3.
##
## Both levers move the boss and nothing else, which says the campfire is not the
## cause. Three weighted rows of 8-34 damage normals cannot threaten 75 HP; the
## act is decided in one fight because only one fight is dangerous. The fix is in
## the walk's content or the boss's HP, not in where the player rests.
const REST_ROW := ROWS - 1
## The row the boss hangs off. Was REST_ROW itself, which is why the rest and the
## boss's doorstep could not be moved apart to test that -- they were one
## constant. Same row today, on purpose, but no longer the same idea.
const BOSS_ROW := ROWS - 1
const NO_ELITE_BEFORE := 2
const NO_CAMPFIRE_BEFORE := 2

var rows: Array = []                ## Array[Array[MapNode]]
var boss: MapNode = null
## Where every run begins: one node, before the map fans out.
var origin: MapNode = null

func generate() -> Array:
	rows.clear()
	for r in ROWS:
		rows.append([])
	var grid := {}                  ## "row,col" -> MapNode
	var rng := Rng.stream(&"map")

	# Every path starts in its OWN column, so the origin forks exactly PATHS
	# ways. Sharing an opening column would quietly collapse the first choice.
	var columns: Array[int] = []
	for c in WIDTH:
		columns.append(c)
	Rng.shuffle_in(&"map", columns)
	for p in PATHS:
		_walk_path(columns[p % columns.size()], grid, rng)

	for key in grid:
		var n: MapNode = grid[key]
		rows[n.row].append(n)
	for r in ROWS:
		rows[r].sort_custom(func(a, b): return a.col < b.col)

	_assign_kinds(rng)
	_attach_origin()
	_attach_boss()
	return rows

func _walk_path(start_col: int, grid: Dictionary, rng: RandomNumberGenerator) -> void:
	var col := start_col
	var prev_node: MapNode = _node_at(0, col, grid)
	for r in range(1, ROWS):
		var next_col := _drift(col, r, prev_node, grid, rng)
		var node := _node_at(r, next_col, grid)
		if not prev_node.next.has(node):
			prev_node.next.append(node)
			node.prev.append(prev_node)
		prev_node = node
		col = next_col

## Picks a column one step left/right/straight, rejecting moves that would make
## this edge cross an edge already drawn between the same two rows.
func _drift(col: int, row: int, from: MapNode, grid: Dictionary, rng: RandomNumberGenerator) -> int:
	var options: Array[int] = []
	for delta in [-1, 0, 1]:
		var c: int = col + delta
		if c < 0 or c >= WIDTH:
			continue
		if _would_cross(from, row, c, grid):
			continue
		options.append(c)
	if options.is_empty():
		return col
	return options[rng.randi_range(0, options.size() - 1)]

func _would_cross(from: MapNode, to_row: int, to_col: int, grid: Dictionary) -> bool:
	# An edge (from.col -> to_col) crosses an existing edge (a.col -> b.col)
	# when the two swap relative order between the rows.
	for key in grid:
		var n: MapNode = grid[key]
		if n.row != from.row:
			continue
		for m in n.next:
			if m.row != to_row:
				continue
			if n.col < from.col and m.col > to_col:
				return true
			if n.col > from.col and m.col < to_col:
				return true
	return false

func _node_at(row: int, col: int, grid: Dictionary) -> MapNode:
	var key := "%d,%d" % [row, col]
	if not grid.has(key):
		grid[key] = MapNode.new(row, col)
	return grid[key]

## Row rules first (they are guarantees), then weighted random for the rest.
func _assign_kinds(rng: RandomNumberGenerator) -> void:
	for r in ROWS:
		for node in rows[r]:
			if r == 0:
				node.kind = MapNode.Kind.COMBAT
			elif r == TREASURE_ROW:
				node.kind = MapNode.Kind.TREASURE
			elif r == REST_ROW:
				node.kind = MapNode.Kind.CAMPFIRE
			else:
				node.kind = _weighted_kind(r, node, rng)
			if node.kind == MapNode.Kind.COMBAT:
				# r < 3, matching what the run screen used to re-derive for itself.
				# The two thresholds disagreed (2 here, 3 there) and the screen won,
				# so this field was dead and row 2 quietly drew easy encounters.
				node.encounter_id = &"easy" if r < 3 else &"normal"
			elif node.kind == MapNode.Kind.ELITE:
				node.encounter_id = &"elite"

func _weighted_kind(row: int, node: MapNode, rng: RandomNumberGenerator) -> MapNode.Kind:
	var weights := {
		MapNode.Kind.COMBAT: 45,
		MapNode.Kind.EVENT: 22,
		MapNode.Kind.ELITE: 16 if row >= NO_ELITE_BEFORE else 0,
		MapNode.Kind.CAMPFIRE: 12 if row >= NO_CAMPFIRE_BEFORE else 0,
		MapNode.Kind.SHOP: 5,
	}
	# Never place a campfire directly above another -- back-to-back rests trivialise
	# the attrition the whole run structure is built on.
	for p in node.prev:
		if p.kind == MapNode.Kind.CAMPFIRE:
			weights[MapNode.Kind.CAMPFIRE] = 0
		if p.kind == MapNode.Kind.ELITE:
			weights[MapNode.Kind.ELITE] = 0
	var total := 0
	for k in weights:
		total += weights[k]
	var roll := rng.randi_range(1, maxi(1, total))
	var acc := 0
	for k in weights:
		acc += weights[k]
		if roll <= acc:
			return k
	return MapNode.Kind.COMBAT

func _attach_boss() -> void:
	boss = MapNode.new(ROWS, 3)
	boss.kind = MapNode.Kind.BOSS
	boss.encounter_id = &"boss_smith"
	for node in rows[BOSS_ROW]:
		node.next.append(boss)
		boss.prev.append(node)

## The run begins on the origin, always. Fanning out from one node rather than
## offering several entrances means the first choice a player makes is a real
## fork they can see the whole of, instead of a blind pick between openings.
func starting_nodes() -> Array:
	return [origin] if origin != null else (rows[0] if not rows.is_empty() else [])

## The single node the act opens on, where the starting moves are drafted. It
## connects to every stage-0 node, so the map fans out from one point.
func _attach_origin() -> void:
	origin = MapNode.new(-1, (WIDTH - 1) / 2)
	origin.kind = MapNode.Kind.DRAFT
	if rows.is_empty():
		return
	for node in rows[0]:
		origin.next.append(node)
		node.prev.append(origin)
