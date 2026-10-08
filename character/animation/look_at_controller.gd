class_name LookAtController
extends Node
## Makes a character's head and eyes follow a target (e.g. the camera).
##
## Drives [LookAtModifier3D]s on the skeleton, fading their influence when
## head or eye following is toggled. The modifiers must come before any
## RetargetModifier3D in the skeleton's children so clothing follows the
## turned head.

@export var head_modifiers: Array[LookAtModifier3D] = []
@export var eye_modifiers: Array[LookAtModifier3D] = []
## Seconds to fade following in or out.
@export_range(0.0, 2.0, 0.01) var fade_time := 0.35
@export var head_follow := true
@export var eyes_follow := true

var _target: Node3D


func _ready() -> void:
	for modifier in _all_modifiers():
		modifier.influence = 0.0


func _process(delta: float) -> void:
	var active := _target != null
	_fade(head_modifiers, 1.0 if active and head_follow else 0.0, delta)
	_fade(eye_modifiers, 1.0 if active and eyes_follow else 0.0, delta)


## Follows [param target]. Pass null to fade back to the animated pose.
func set_target(target: Node3D) -> void:
	_target = target
	if target == null:
		return # Keep the old target while fading out.
	for modifier in _all_modifiers():
		modifier.target_node = modifier.get_path_to(target)


## Fades head following on or off.
func set_head_follow(enabled: bool) -> void:
	head_follow = enabled


## Fades eye following on or off.
func set_eyes_follow(enabled: bool) -> void:
	eyes_follow = enabled


func _fade(modifiers: Array[LookAtModifier3D], target: float, delta: float) -> void:
	for modifier in modifiers:
		var step := 1.0 if is_zero_approx(fade_time) else delta / fade_time
		modifier.influence = move_toward(modifier.influence, target, step)
		modifier.active = modifier.influence > 0.0


func _all_modifiers() -> Array[LookAtModifier3D]:
	var modifiers: Array[LookAtModifier3D] = head_modifiers.duplicate()
	modifiers.append_array(eye_modifiers)
	return modifiers
