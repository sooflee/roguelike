class_name Dev
extends RefCounted
## Developer conveniences. Off unless explicitly asked for, so nothing here can
## reach a player by accident.
##
## Enabled by launching with `--dev`:
##     godot --path . scenes/main.tscn -- --dev
## Tests turn it on directly with Dev.enable().

static var _checked := false
static var _enabled := false

static func is_enabled() -> bool:
	if not _checked:
		_checked = true
		# `--` separates engine args from ours; accept it either side so the
		# flag works however it was passed.
		_enabled = OS.get_cmdline_args().has("--dev") \
			or OS.get_cmdline_user_args().has("--dev")
	return _enabled

static func enable() -> void:
	_checked = true
	_enabled = true

static func disable() -> void:
	_checked = true
	_enabled = false
