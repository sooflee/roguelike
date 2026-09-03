class_name StatusRegistry
extends RefCounted
## Prototype instances of every status, looked up by id. Callers duplicate on
## application (see Combatant.apply_status) so prototypes stay pristine.

static var _protos: Dictionary = {}

static func _ensure() -> void:
	if not _protos.is_empty():
		return
	for st in [
		StrengthStatus.new(),
		DexterityStatus.new(),
		VulnerableStatus.new(),
		WeakStatus.new(),
		FrailStatus.new(),
		KindlingStatus.new(),
		AfterburnStatus.new(),
		DampenedStatus.new(),
		SimmerStatus.new(),
	]:
		_protos[st.id] = st

static func get_status(id: StringName) -> StatusEffect:
	_ensure()
	return _protos.get(id)

static func all() -> Array:
	_ensure()
	return _protos.values()
