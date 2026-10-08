class_name LookAtController
extends Node
## Makes a character's head and eyes follow a target (e.g. the camera).
##
## Drives [LookAtModifier3D]s on the skeleton, fading their influence when
## head or eye following is toggled. An override target (see
## [method set_override_target], e.g. a phone in the hand) takes priority:
## head and eyes follow it even when following is toggled off, then return
## to the normal target, or fade back to the animated pose. The modifiers must come before any
## RetargetModifier3D in the skeleton's children so clothing follows the
## turned head.

@export var head_modifiers: Array[LookAtModifier3D] = []
@export var eye_modifiers: Array[LookAtModifier3D] = []
## Seconds to fade following in or out.
@export_range(0.0, 2.0, 0.01) var fade_time := 0.35
@export var head_follow := true
@export var eyes_follow := true

var _target: Node3D
var _override: Node3D
# Holds the last looked-at point while following fades out, so the modifiers
# never point at a node that's gone (e.g. a phone being put away).
var _fade_anchor: Node3D


func _ready() -> void:
	for modifier in _all_modifiers():
		modifier.influence = 0.0


func _process(delta: float) -> void:
	var overridden := is_instance_valid(_override)
	var active := _target != null
	_fade(head_modifiers, 1.0 if overridden or (active and head_follow) else 0.0, delta)
	_fade(eye_modifiers, 1.0 if overridden or (active and eyes_follow) else 0.0, delta)


## Follows [param target]. Pass null to fade back to the animated pose.
func set_target(target: Node3D) -> void:
	_hold_current_point()
	_target = target
	_point_modifiers()


## Looks at [param target] with head and eyes, whatever the follow toggles
## say, until called with null.
func set_override_target(target: Node3D) -> void:
	_hold_current_point()
	_override = target
	_point_modifiers()


## Fades head following on or off.
func set_head_follow(enabled: bool) -> void:
	head_follow = enabled


## Fades eye following on or off.
func set_eyes_follow(enabled: bool) -> void:
	eyes_follow = enabled


# Points the modifiers at the override, else the target, else (while fading
# out) at where the last one was.
func _point_modifiers() -> void:
	var look_target := _get_look_target()
	if look_target == null:
		look_target = _get_fade_anchor()
	for modifier in _all_modifiers():
		modifier.target_node = modifier.get_path_to(look_target)


func _get_look_target() -> Node3D:
	return _override if is_instance_valid(_override) else _target


# Parks the fade anchor where the head is looking now, so fading out after a
# target goes away eases back from there.
func _hold_current_point() -> void:
	var current := _get_look_target()
	if current and current.is_inside_tree():
		_get_fade_anchor().global_position = current.global_position


func _get_fade_anchor() -> Node3D:
	if _fade_anchor == null:
		_fade_anchor = Node3D.new()
		_fade_anchor.name = &"LookFadeAnchor"
		_fade_anchor.top_level = true
		add_child(_fade_anchor)
	return _fade_anchor


func _fade(modifiers: Array[LookAtModifier3D], target: float, delta: float) -> void:
	for modifier in modifiers:
		var step := 1.0 if is_zero_approx(fade_time) else delta / fade_time
		modifier.influence = move_toward(modifier.influence, target, step)
		modifier.active = modifier.influence > 0.0


func _all_modifiers() -> Array[LookAtModifier3D]:
	var modifiers: Array[LookAtModifier3D] = head_modifiers.duplicate()
	modifiers.append_array(eye_modifiers)
	return modifiers
