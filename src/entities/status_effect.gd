class_name StatusEffect
extends Resource
## A stacking buff/debuff with lifecycle hooks.
##
## Instances are duplicated per-combatant on application (see Combatant.apply_status),
## so `stacks` is safe to mutate.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var is_debuff: bool = false
## True for statuses the player learns by name, which cards then just name
## ("Apply 2 Vulnerable", "Gain 2 Strength"). False for one-off powers with no
## such shorthand, whose cards spell out `description` instead.
@export var is_keyword: bool = true
## Most Spire-style debuffs lose one stack at end of the owner's turn.
@export var decays_at_turn_end: bool = false
## Some statuses (Vulnerable/Weak on enemies) tick at end of round instead.
@export var max_stacks: int = 9999
@export var icon: Texture2D
## Lower runs first in the damage pipeline. Additive modifiers (Strength) MUST
## resolve before multiplicative ones (Weak, Vulnerable), or the arithmetic is
## silently wrong: (6+3)*0.75 = 6, but (6*0.75)+3 = 7.
@export var apply_order: int = 0

var stacks: int = 0

# --- Damage pipeline hooks -------------------------------------------------
## Applied when this status's owner is DEALING damage.
func modify_outgoing_damage(amount: float, _ctx) -> float:
	return amount

## Applied when this status's owner is RECEIVING damage.
func modify_incoming_damage(amount: float, _ctx) -> float:
	return amount

## Applied when this status's owner gains block.
func modify_block_gain(amount: float, _ctx) -> float:
	return amount

# --- Lifecycle hooks -------------------------------------------------------
func on_applied(_owner, _combat) -> void: pass
func on_turn_start(_owner, _combat) -> void: pass
func on_turn_end(_owner, _combat) -> void: pass
func on_card_played(_card, _owner, _combat) -> void: pass
func on_overload(_owner, _amount: int, _combat) -> void: pass
func on_removed(_owner, _combat) -> void: pass
