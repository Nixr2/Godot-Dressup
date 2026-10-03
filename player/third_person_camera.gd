class_name ThirdPersonCamera
extends Node3D
## Orbits a [SpringArm3D]-mounted camera around its parent.
##
## Drag with the right mouse button to orbit; use the camera_zoom_* actions
## to change the distance. The spring arm pulls the camera in front of walls.

@export var mouse_sensitivity := 0.005
@export_range(-89.0, 89.0) var min_pitch_degrees := -60.0
@export_range(-89.0, 89.0) var max_pitch_degrees := 20.0
@export var min_distance := 0.8
@export var max_distance := 5.0
@export var zoom_step := 0.25

## Horizontal orbit angle in radians; movement input is relative to it.
var yaw := 0.0
var _pitch := deg_to_rad(-15.0)

@onready var _spring_arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	_update_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
		_update_rotation()
	elif event.is_action_pressed(&"camera_zoom_in"):
		_zoom(-zoom_step)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_zoom(zoom_step)


func _zoom(amount: float) -> void:
	var length := _spring_arm.spring_length + amount
	_spring_arm.spring_length = clampf(length, min_distance, max_distance)


func _update_rotation() -> void:
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	rotation = Vector3(_pitch, yaw, 0.0)
