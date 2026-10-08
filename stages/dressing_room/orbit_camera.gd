class_name OrbitCamera
extends Node3D
## Orbits a child [Camera3D] around a [CameraFocus] point on the character.
##
## [method focus] glides to a named framing (e.g. "face" when editing
## expressions) and keeps tracking its bone while the character animates.
## Drag with the right mouse button or use the camera_* actions to orbit and
## zoom; zooming is relative to the current focus.

@export var skeleton: Skeleton3D
@export var focus_presets: Array[CameraFocus] = []
## Focus used on ready and by [method reset_focus].
@export var default_focus: StringName = &"full_body"
## Higher = snappier transitions between focus points.
@export var follow_sharpness := 6.0
@export var zoom_step := 0.15
## Zoom range as a multiple of the focus distance.
@export var min_zoom := 0.5
@export var max_zoom := 2.5
@export var mouse_sensitivity := 0.005
@export var keyboard_orbit_speed := 2.0
@export_range(-89.0, 89.0) var min_pitch_degrees := -45.0
@export_range(-89.0, 89.0) var max_pitch_degrees := 60.0

var _focus: CameraFocus
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _distance := 2.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	# Moves every frame, so physics interpolation would only make it stutter.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_yaw = rotation.y
	focus(default_focus)
	_snap()


func _process(delta: float) -> void:
	# Typing in a text field (e.g. a preset name) mustn't turn the camera.
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		var orbit_input := Input.get_axis(&"camera_orbit_left", &"camera_orbit_right")
		_yaw -= orbit_input * keyboard_orbit_speed * delta

	var weight := 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(_get_focus_point(), weight)
	_distance = lerpf(_distance, _get_target_distance(), weight)
	_camera.position = Vector3(0.0, 0.0, _distance)
	rotation = Vector3(_pitch, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_set_pitch(_pitch - motion.relative.y * mouse_sensitivity)
	elif event.is_action_pressed(&"camera_zoom_in"):
		_zoom = clampf(_zoom - zoom_step, min_zoom, max_zoom)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_zoom = clampf(_zoom + zoom_step, min_zoom, max_zoom)


## Glides to the focus preset named [param id]. Resets zoom and pitch.
func focus(id: StringName) -> void:
	for preset in focus_presets:
		if preset.id == id:
			if preset == _focus:
				return
			_focus = preset
			_zoom = 1.0
			_set_pitch(deg_to_rad(preset.pitch_degrees))
			return
	push_warning("OrbitCamera: no focus preset '%s'." % id)


## Glides back to [member default_focus].
func reset_focus() -> void:
	focus(default_focus)


## Returns the current focus preset's id.
func get_focus() -> StringName:
	return _focus.id if _focus else &""


## Returns the orbiting camera.
func get_camera() -> Camera3D:
	return _camera


func _get_focus_point() -> Vector3:
	if skeleton == null or _focus == null:
		return global_position
	var local := Vector3.ZERO
	var bone := skeleton.find_bone(_focus.bone) if not _focus.bone.is_empty() else -1
	if bone >= 0:
		local = skeleton.get_bone_global_pose(bone).origin
	return skeleton.global_transform * (local + _focus.offset)


func _get_target_distance() -> float:
	return (_focus.distance if _focus else 2.0) * _zoom


func _set_pitch(value: float) -> void:
	_pitch = clampf(value, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func _snap() -> void:
	global_position = _get_focus_point()
	_distance = _get_target_distance()
	_camera.position = Vector3(0.0, 0.0, _distance)
	rotation = Vector3(_pitch, _yaw, 0.0)
