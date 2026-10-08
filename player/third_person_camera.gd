class_name ThirdPersonCamera
extends Node3D
## Smooth, cinematic third-person camera (in the style of Skyrim) orbiting a
## point on its parent on a [SpringArm3D].
##
## The mouse looks around while the cursor is captured. The [Player] runs
## where the camera looks, and stands still while it orbits, so a standing
## character can be viewed from any side. To use the HUD, hold
## camera_free_cursor (Alt) for the cursor and let go to look again, or press
## ui_cancel (Esc) to free it until you click the world. With the cursor
## free, right-drag still orbits.
##
## Turning, following and zooming are all smoothed. While the character moves,
## the view shifts over its shoulder; standing, the character is centered.
## The spring arm pulls the camera in front of walls.

@export var mouse_sensitivity := 0.0025
@export var invert_y := false
## Capture the cursor for mouse look as soon as the camera enters the tree.
@export var capture_on_start := true
@export_range(-89.0, 89.0) var min_pitch_degrees := -65.0
@export_range(-89.0, 89.0) var max_pitch_degrees := 35.0
## The point orbited, relative to the parent (about chest height).
@export var pivot_offset := Vector3(0.0, 0.9, 0.0)

@export_group("Smoothing")
## How quickly the view catches up with the mouse. Lower = floatier.
@export_range(1.0, 40.0, 0.5) var rotation_smoothing := 14.0
## How quickly the camera catches up with the moving character.
@export_range(1.0, 40.0, 0.5) var follow_smoothing := 10.0
@export_range(1.0, 40.0, 0.5) var zoom_smoothing := 10.0
## How quickly the shoulder offset and field of view change.
@export_range(0.5, 20.0, 0.5) var framing_smoothing := 3.0

@export_group("Framing")
@export var min_distance := 0.6
@export var max_distance := 4.0
@export var zoom_step := 0.3
## Sideways shift of the view while the character moves (meters, + = right).
@export var shoulder_offset := 0.3
@export_range(20.0, 120.0, 0.5) var base_fov := 55.0
## Extra field of view while jogging, for a sense of speed.
@export_range(0.0, 30.0, 0.5) var jog_fov_boost := 6.0
## Extra field of view while sprinting.
@export_range(0.0, 30.0, 0.5) var sprint_fov_boost := 11.0

## Horizontal look angle in radians that the view is heading to (0 = -Z);
## the [Player] moves relative to it.
var yaw := 0.0
var _pitch := deg_to_rad(-12.0)
var _view_yaw := 0.0
var _view_pitch := _pitch
var _target_distance := 0.0
var _moving := false
# True while the cursor is only freed for as long as camera_free_cursor is held.
var _cursor_held_free := false
var _fov_boost := 0.0

# Cached because get_parent_node_3d() returns null once top_level is set.
@onready var _target: Node3D = get_parent()
@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	# Follows the parent smoothly instead of rigidly. It moves every frame, so
	# it opts out of physics interpolation and follows the parent's
	# interpolated position instead.
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_position = _get_pivot()
	_target_distance = _spring_arm.spring_length
	_camera.fov = base_fov
	_apply_rotation()
	if capture_on_start:
		set_mouse_captured(true)


func _exit_tree() -> void:
	# Leave the cursor usable for whatever scene comes next.
	if is_mouse_captured():
		set_mouse_captured(false)


func _process(delta: float) -> void:
	_view_yaw = lerp_angle(_view_yaw, yaw, _smooth(rotation_smoothing, delta))
	_view_pitch = lerpf(_view_pitch, _pitch, _smooth(rotation_smoothing, delta))
	_apply_rotation()
	global_position = global_position.lerp(_get_pivot(), _smooth(follow_smoothing, delta))
	_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length, _target_distance, _smooth(zoom_smoothing, delta)
	)
	var framing := _smooth(framing_smoothing, delta)
	_camera.h_offset = lerpf(_camera.h_offset, shoulder_offset if _moving else 0.0, framing)
	_camera.fov = lerpf(_camera.fov, base_fov + _fov_boost, framing)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var looking := is_mouse_captured() or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if looking:
			var motion := event as InputEventMouseMotion
			yaw -= motion.relative.x * mouse_sensitivity
			_pitch -= motion.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)
			_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event.is_action_pressed(&"camera_free_cursor") and is_mouse_captured():
		_cursor_held_free = true
		set_mouse_captured(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and is_mouse_captured():
		set_mouse_captured(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not is_mouse_captured():
		# Only reaches here when the click missed the HUD.
		set_mouse_captured(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_zoom_in"):
		_target_distance = clampf(_target_distance - zoom_step, min_distance, max_distance)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_target_distance = clampf(_target_distance + zoom_step, min_distance, max_distance)


# Caught before the GUI, so letting go of the key over the HUD still counts.
func _input(event: InputEvent) -> void:
	if event.is_action_released(&"camera_free_cursor") and _cursor_held_free:
		_cursor_held_free = false
		set_mouse_captured(true)


## Tells the camera how the character moves, for its framing: over the
## shoulder while moving, a wider view while jogging, wider still sprinting.
func set_motion(moving: bool, jogging: bool, sprinting := false) -> void:
	_moving = moving
	_fov_boost = 0.0
	if moving and sprinting:
		_fov_boost = sprint_fov_boost
	elif moving and jogging:
		_fov_boost = jog_fov_boost


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func set_mouse_captured(captured: bool) -> void:
	if captured:
		_cursor_held_free = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _get_pivot() -> Vector3:
	return _target.get_global_transform_interpolated() * pivot_offset


func _apply_rotation() -> void:
	rotation = Vector3(_view_pitch, _view_yaw, 0.0)


# Frame-rate independent weight for exponential smoothing.
func _smooth(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
