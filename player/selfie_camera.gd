class_name SelfieCamera
extends Camera3D
## The phone's front camera: while active, the character holds the phone out
## at arm's length, this camera sits on the phone looking back at them, and
## their head and eyes look into the lens. It doesn't take over the main view:
## a viewfinder (see PhoneMenu) renders from it.
##
## The phone's spot is aimed around the shoulder: drag with the right mouse
## button to swing the arm, use the camera_zoom_* actions to reach nearer or
## farther. Angles and reach are clamped to what an arm can comfortably do.
## The higher the phone, the more the lens aims down the body (see
## [member body_aim]) for high-angle shots, and [method set_wide_lens]
## switches to a wider lens, like a phone's 0.5x camera.
## A [TwoBoneIK3D] reaches the arm to that spot and a [LookAtModifier3D]
## turns the hand so the phone's screen faces the head; both are created on
## [method activate] and fade in and out.

## Shoulder bone the phone is aimed around.
@export var shoulder_bone: StringName = &"arm_stretch.l"
@export var forearm_bone: StringName = &"forearm_stretch.l"
@export var hand_bone: StringName = &"hand.l"
@export var head_bone: StringName = &"head.x"
## Bone the lens aims toward when the phone is held high (about the hips).
@export var body_bone: StringName = &"root.x"
## Which side the phone arm is on: 1 = the character's left, -1 = right.
@export_range(-1, 1, 2) var side := 1

@export_group("Aim")
@export var mouse_sensitivity := 0.004
## Sideways swing around the shoulder: negative = across the body.
@export_range(-90.0, 90.0, 1.0, "suffix:°") var min_yaw := -35.0
@export_range(-90.0, 90.0, 1.0, "suffix:°") var max_yaw := 70.0
## Up and down swing around the shoulder.
@export_range(-90.0, 90.0, 1.0, "suffix:°") var min_pitch := -20.0
@export_range(-90.0, 90.0, 1.0, "suffix:°") var max_pitch := 48.0
## Reach as a fraction of the arm's full length.
@export_range(0.2, 1.0, 0.01) var min_reach := 0.55
@export_range(0.2, 1.0, 0.01) var max_reach := 0.97
@export var reach_step := 0.05
## Starting aim: a bit to the side, a bit up, nearly at full reach.
@export var start_aim := Vector3(25.0, 15.0, 0.9)

@export_group("Feel")
## Seconds for the arm to move into and out of the selfie pose.
@export_range(0.0, 2.0, 0.01) var blend_time := 0.35
## How quickly the arm follows the aim. Lower = floatier.
@export_range(1.0, 40.0, 0.5) var aim_smoothing := 12.0
## How far in front of the phone's screen the lens sits, toward the face.
@export var lens_offset := 0.02

@export_group("Lens")
## Field of view of the normal lens and of the wide (0.5x) lens.
@export_range(30.0, 120.0, 1.0, "suffix:°") var normal_fov := 70.0
@export_range(30.0, 120.0, 1.0, "suffix:°") var wide_fov := 100.0
## How far down the body the lens aims at the highest angle: 0 = always at
## the face, 1 = at [member body_bone]. Starts above [member body_aim_from].
@export_range(0.0, 1.0, 0.01) var body_aim := 0.4
## Phone height (pitch) where the lens starts aiming down the body.
@export_range(-90.0, 90.0, 1.0, "suffix:°") var body_aim_from := 20.0

var _mannequin: Mannequin
var _skeleton: Skeleton3D
var _active := false
var _yaw := 0.0
var _pitch := 0.0
var _reach := 0.0
var _arm_length := 0.0
var _ik: TwoBoneIK3D
var _hand_look: LookAtModifier3D
var _target: Marker3D
var _pole: Marker3D
var _head_marker: Marker3D
var _wide := false


func _ready() -> void:
	# Placed every frame from the phone, not by its parent.
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(false)


## Points this camera at [param mannequin]'s skeleton. Call before
## [method activate].
func setup(mannequin: Mannequin) -> void:
	_mannequin = mannequin
	_skeleton = mannequin.animator.skeleton


func is_active() -> bool:
	return _active


## Switches between the normal and the wide (0.5x) lens.
func set_wide_lens(wide: bool) -> void:
	_wide = wide


func is_wide_lens() -> bool:
	return _wide


## Turns the selfie camera on or off. Turning it off fades the arm back.
func activate(enabled: bool) -> void:
	if enabled == _active or _skeleton == null:
		return
	_active = enabled
	if enabled:
		_yaw = start_aim.x
		_pitch = start_aim.y
		_reach = start_aim.z
		_wide = false
		fov = normal_fov
		_create_modifiers()
		_mannequin.look_at.set_override_target(self)
		_update_markers(1.0)
		set_process(true)
	else:
		_mannequin.look_at.set_override_target(_mannequin.held_prop.get_look_target())


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		_yaw = clampf(_yaw - motion.relative.x * mouse_sensitivity * 57.3, min_yaw, max_yaw)
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity * 57.3, min_pitch, max_pitch)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_zoom_in"):
		_reach = clampf(_reach - reach_step, min_reach, max_reach)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_reach = clampf(_reach + reach_step, min_reach, max_reach)


func _process(delta: float) -> void:
	var step := 1.0 if is_zero_approx(blend_time) else delta / blend_time
	var influence := move_toward(_ik.influence, 1.0 if _active else 0.0, step)
	_ik.influence = influence
	_hand_look.influence = influence
	_update_markers(1.0 - exp(-aim_smoothing * delta))
	if _active:
		fov = lerpf(fov, wide_fov if _wide else normal_fov, 1.0 - exp(-aim_smoothing * delta))
		_place_lens()
	elif is_zero_approx(influence):
		_free_modifiers()
		set_process(false)


# Moves the IK target to the aimed spot (smoothed by [param weight]), the pole
# below and behind the elbow, and the head marker to the head.
func _update_markers(weight: float) -> void:
	var body := _mannequin.global_basis
	var shoulder := _bone_position(shoulder_bone)
	# 0 yaw / 0 pitch points straight ahead; positive yaw swings outward.
	var direction := (
			Basis(Vector3.UP, deg_to_rad(_yaw) * side)
			* Basis(Vector3.LEFT, deg_to_rad(_pitch))
			* Vector3.BACK
	)
	var aimed := shoulder + body * direction * _arm_length * _reach
	_target.global_position = _target.global_position.lerp(aimed, weight)
	var outward := body.x * side
	_pole.global_position = shoulder + (outward * 0.6 + Vector3.DOWN - body.z * 0.3) * _arm_length
	_head_marker.global_position = _bone_position(head_bone) + Vector3.UP * 0.03


# Puts the lens on the phone's screen, looking at the face, or further down
# the body the higher the phone is held.
func _place_lens() -> void:
	var phone := _mannequin.held_prop.get_prop_instance()
	var head := _bone_position(head_bone) + Vector3.UP * 0.02
	var screen := _target.global_position
	if phone:
		screen = phone.global_transform * _mannequin.held_prop.get_look_offset()
	var height := clampf(inverse_lerp(body_aim_from, max_pitch, _pitch), 0.0, 1.0)
	var aim := head.lerp(_bone_position(body_bone), body_aim * height)
	global_position = screen + (head - screen).normalized() * lens_offset
	var forward := aim - global_position
	if forward.length() > 0.001:
		# Looking straight down, world up can't be the camera's up: use the
		# body's forward instead.
		var up := Vector3.UP if absf(forward.normalized().y) < 0.95 else _mannequin.global_basis.z
		look_at(aim, up)


func _create_modifiers() -> void:
	if _ik:
		return # Still fading out from last time: reuse it.
	var shoulder := _skeleton.find_bone(shoulder_bone)
	var forearm := _skeleton.find_bone(forearm_bone)
	var hand := _skeleton.find_bone(hand_bone)
	_arm_length = (
			_skeleton.get_bone_global_rest(shoulder).origin.distance_to(
					_skeleton.get_bone_global_rest(forearm).origin)
			+ _skeleton.get_bone_global_rest(forearm).origin.distance_to(
					_skeleton.get_bone_global_rest(hand).origin)
	)
	_target = _add_marker(&"SelfieArmTarget")
	_pole = _add_marker(&"SelfieArmPole")
	_head_marker = _add_marker(&"SelfieHeadMarker")
	_target.global_position = _bone_position(hand_bone)

	_ik = TwoBoneIK3D.new()
	_ik.name = &"SelfieArmIK"
	_ik.setting_count = 1
	_ik.set_root_bone_name(0, shoulder_bone)
	_ik.set_middle_bone_name(0, forearm_bone)
	_ik.set_end_bone_name(0, hand_bone)
	_ik.influence = 0.0
	_hand_look = LookAtModifier3D.new()
	_hand_look.name = &"SelfieHandLook"
	_hand_look.bone_name = hand_bone
	# The phone's screen faces along the hand's -Z.
	_hand_look.forward_axis = SkeletonModifier3D.BONE_AXIS_MINUS_Z
	_hand_look.primary_rotation_axis = Vector3.AXIS_Y
	_hand_look.use_secondary_rotation = true
	_hand_look.influence = 0.0
	# Before the clothing rig, so sleeves follow the moved arm.
	var clothing_rig := _mannequin.wardrobe.clothing_rig
	for modifier: SkeletonModifier3D in [_ik, _hand_look]:
		_skeleton.add_child(modifier)
		if clothing_rig:
			_skeleton.move_child(modifier, clothing_rig.get_index())
	_ik.set_target_node(0, _ik.get_path_to(_target))
	_ik.set_pole_node(0, _ik.get_path_to(_pole))
	_hand_look.target_node = _hand_look.get_path_to(_head_marker)


func _free_modifiers() -> void:
	for node: Node in [_ik, _hand_look, _target, _pole, _head_marker]:
		if node:
			node.queue_free()
	_ik = null
	_hand_look = null
	_target = null
	_pole = null
	_head_marker = null


func _add_marker(marker_name: StringName) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.top_level = true
	_mannequin.add_child(marker)
	return marker


func _bone_position(bone: StringName) -> Vector3:
	var pose := _skeleton.get_bone_global_pose(_skeleton.find_bone(bone))
	return _skeleton.global_transform * pose.origin
