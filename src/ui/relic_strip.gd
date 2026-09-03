class_name RelicStrip
extends Control
## The relics you hold, as icons rather than a comma-separated list of names.
##
## Also fixes a real layout problem: the name list lived inline in the header,
## which grew to four wrapped lines at sixteen relics and ate the body below it.
## A row of icons is a fixed height no matter how many you own.

## 3x the 12px source art -- an integer factor, and big enough to actually
## point at. At 22 these were both slightly blurred and a small target.
const ICON := 36.0
const GAP := 6.0

var relics: Array = []
var _time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, ICON + 6.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)

func setup(p_relics: Array) -> void:
	relics = p_relics
	queue_redraw()

func _process(delta: float) -> void:
	if Juice.intensity <= 0.0:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	for i in relics.size():
		var r: RelicData = relics[i]
		# Each relic bobs on its own phase. A row of icons rising and falling
		# together reads as one bar animating; offset, it reads as objects.
		var bob := 0.0
		if Juice.intensity > 0.0:
			bob = sin(_time * 1.9 + float(i) * 0.8) * 1.2 * Juice.intensity
		draw_texture_rect(IconArt.for_relic(r.id),
			Rect2(Vector2(float(i) * (ICON + GAP), 3.0 + bob), Vector2(ICON, ICON)), false)

## Per-icon tooltip, so the names are still reachable now they are not written out.
func _get_tooltip(at_position: Vector2) -> String:
	var slot := ICON + GAP
	var i := int(at_position.x / slot)
	if i < 0 or i >= relics.size():
		return ""
	# Inside the icon, not the gap after it: hovering blank space between two
	# held items used to describe whichever one was to the left.
	if at_position.x - float(i) * slot > ICON:
		return ""
	var r: RelicData = relics[i]
	return "%s\n%s" % [r.title, r.text]
