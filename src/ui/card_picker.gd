class_name CardPicker
extends Control
## A row of real cards you click, instead of a list of text rows.
##
## The reward screen is where the player makes the choice the whole run is
## about, and it was reading that choice off a line of prose. A card you can
## see is a card you can compare -- cost, type colour, art and rules text all
## arrive at once instead of being parsed left to right.
##
## Hosts Node2D CardViews inside a Control so it can still sit in the run
## screen's VBox like any other row.

signal card_chosen(card)
## Emitted with the card under the cursor, or null when the cursor leaves them all.
signal card_hovered(card)

const GAP := 26.0
const ROW_H := 168.0
## Beyond this many cards the row becomes a grid. Six 96px cards plus gaps is
## 706px, which still clears the run screen's gutters at 960 wide.
const MAX_PER_ROW := 6

var _stage: Node2D
var _views: Array[CardView] = []
var _hot: CardView = null
var _cursor := 0
var _taking := false
## When true, picking a card does NOT fly it into the deck counter. The forge
## and the shop's remove service act ON a card already in the deck, so animating
## it into the deck would describe the opposite of what just happened.
var fly_to_deck := true
## Cards the player cannot currently take. They still draw and still preview on
## hover -- seeing the thing you cannot afford is the point of a shop.
var _locked: Dictionary = {}
## Optional alternate faces, keyed by card, shown while `previewing` is true.
var _alt: Dictionary = {}
var previewing := false
## A picker used as a RESULT rather than a choice -- the sharpened card the
## forge hands back. Same renderer, same size, but it takes no focus, does not
## hover and cannot be clicked. Left interactive it emits card_chosen into a
## signal nobody listens to: a dead card to the player, and to an automated
## walk a screen that accepts the same choice forever without advancing.
var display_only := false:
	set(v):
		display_only = v
		_apply_interactivity()

func _ready() -> void:
	custom_minimum_size = Vector2(0, ROW_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Turning the reward choice into pictures removed the only way to make it
	# without a mouse. Left/right walks the row, Enter takes the card.
	_apply_interactivity()
	focus_entered.connect(_refresh_marks)
	focus_exited.connect(_refresh_marks)
	_stage = Node2D.new()
	add_child(_stage)
	resized.connect(_layout)

func _apply_interactivity() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if display_only else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE if display_only else Control.FOCUS_ALL

func setup(cards: Array) -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	_locked.clear()
	_alt.clear()
	for c in cards:
		var v := CardView.new()
		_stage.add_child(v)
		v.setup(c)
		_views.append(v)
	_cursor = 0
	_layout()

## Prices the shelf. `affordable` is what greys a card out and blocks the click.
func set_price(card, amount: int, affordable: bool) -> void:
	var v := _view_of(card)
	if v == null:
		return
	v.set_badge("%d gold" % amount, affordable)
	if not affordable:
		lock(card)

func lock(card) -> void:
	var v := _view_of(card)
	if v == null:
		return
	_locked[card] = true
	v.playable = false
	v.queue_redraw()

## Registers the face to show for `card` while previewing is on -- the upgraded
## version of a card the player is deciding whether to upgrade. Holding the key
## swaps every card at once, so the whole deck can be compared in one gesture
## rather than one hover at a time.
func set_alt(card, alt) -> void:
	_alt[card] = alt

func set_previewing(on: bool) -> void:
	if on == previewing or _alt.is_empty():
		return
	previewing = on
	for v in _views:
		var base = v.card
		# The view is currently showing whichever face; find its owner either way.
		for key in _alt:
			if key == base or _alt[key] == base:
				v.refresh(_alt[key] if on else key)
				break

## The card a view is FOR, which is its base face even while the alternate is
## being shown. Everything outside this picker talks in base cards.
func _owner_of(v: CardView):
	for key in _alt:
		if _alt[key] == v.card:
			return key
	return v.card

func _view_of(card) -> CardView:
	for v in _views:
		if _owner_of(v) == card:
			return v
	return null

## The cards on this shelf that could actually be taken right now.
##
## Locked cards -- a move in a shop the run cannot afford -- still draw and
## still preview on hover, but a click on one is refused. Anything driving the
## picker from outside has to respect that, or it "takes" a card, buys nothing,
## gets the same shelf rendered back at it, and does it again forever.
func takeable() -> Array[CardView]:
	var out: Array[CardView] = []
	if display_only:
		return out
	for v in _views:
		if not _locked.has(_owner_of(v)):
			out.append(v)
	return out

## Wraps into rows. A deck of twenty cards laid out as one row would run four
## screens wide, so the picker grows downward instead and the host scrolls.
func _layout() -> void:
	if _views.is_empty():
		return
	var step := CardView.W + GAP
	var per_row := mini(MAX_PER_ROW, _views.size())
	var rows := int(ceil(float(_views.size()) / float(per_row)))
	custom_minimum_size = Vector2(0, ROW_H * float(rows))
	for i in _views.size():
		var v := _views[i]
		var row := i / per_row
		var in_row := i % per_row
		# The last row is centred on its own count, not on a full row's width.
		var count := mini(per_row, _views.size() - row * per_row)
		var total := step * float(count) - GAP
		var start := (size.x - total) * 0.5 + CardView.W * 0.5
		var pos := Vector2(start + float(in_row) * step, ROW_H * (float(row) + 0.5))
		v.position = pos
		v.home_pos = pos
		v.home_rot = 0.0
		v.rotation = 0.0
	_refresh_marks()

## The keyboard cursor is drawn with the same marker the mouse uses for a
## selected card, so there are not two competing ideas of "this one".
func _refresh_marks() -> void:
	var showing := has_focus()
	for i in _views.size():
		_views[i].selected = showing and i == _cursor
		_views[i].queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		if _views.is_empty():
			return
		var step := 1 if event.is_action_pressed("ui_right") else -1
		_cursor = wrapi(_cursor + step, 0, _views.size())
		_refresh_marks()
		accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		if _cursor >= 0 and _cursor < _views.size():
			_take(_views[_cursor])
		accept_event()
		return
	if event is InputEventMouseMotion:
		var hot := _at(get_global_mouse_position())
		if hot != _hot:
			_hot = hot
			for v in _views:
				v.set_hover(v == hot)
			card_hovered.emit(_owner_of(hot) if hot != null else null)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var picked := _at(get_global_mouse_position())
		if picked != null:
			_cursor = _views.find(picked)
			_take(picked)

## Sends the chosen card to the deck before handing control back: the card
## flies up-left toward the Deck counter in the header and shrinks into it,
## while the ones not taken fade. Picking a card was previously instantaneous,
## so the most consequential choice in a run had no acknowledgement at all.
func _take(view: CardView) -> void:
	if display_only or _taking or view.card == null:
		return
	var card = _owner_of(view)
	# Locked cards still hover and still preview; they just cannot be taken.
	if _locked.has(card):
		Audio.play(&"ui", 0.6, 0.5)
		return
	_taking = true
	Audio.play(&"card_play", 0.9, 0.7)
	# Reduce-motion (D-23) takes the card immediately. An animation the player
	# has asked not to see must not also become a delay they have to wait out.
	if Juice.intensity <= 0.0 or not fly_to_deck:
		card_chosen.emit(card)
		return
	for v in _views:
		if v == view:
			continue
		var fade := create_tween()
		fade.tween_property(v, "modulate:a", 0.0, Juice.dur(0.16))
	view.z_index = 100
	# Card positions live in the Node2D stage, and only Node2D can convert a
	# global point into that space -- Control has no to_local().
	var target: Vector2 = _stage.to_local(Vector2(150, 24))
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(view, "position", view.position + Vector2(0, -26), Juice.dur(0.12))
	t.parallel().tween_property(view, "scale", Vector2(1.15, 1.15), Juice.dur(0.12))
	t.tween_property(view, "position", target, Juice.dur(0.26))
	t.parallel().tween_property(view, "rotation", -0.5, Juice.dur(0.26))
	t.parallel().tween_property(view, "scale", Vector2(0.12, 0.12), Juice.dur(0.26))
	t.parallel().tween_property(view, "modulate:a", 0.0, Juice.dur(0.26))
	t.tween_callback(func(): card_chosen.emit(card))

## Topmost card under the point. Iterated backwards so the card drawn in front
## wins, which is the one the player believes they are pointing at.
func _at(point: Vector2) -> CardView:
	for i in range(_views.size() - 1, -1, -1):
		if _views[i].hit_test(point):
			return _views[i]
	return null
