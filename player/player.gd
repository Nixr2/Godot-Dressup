class_name Player
extends CharacterBody3D
## Walks a customized [Mannequin] around, relative to the camera.
##
## Holding the move_sprint action jogs. The body turns the model toward its
## movement and reports its real ground speed to the [CharacterAnimator],
## which blends walk and jog and scales their playback so the feet stay
## planted (walking into a wall slows the walk instead of gliding).

## Walking speed in m/s. 0 = the walk animation's natural stride speed, so
## it plays at exactly 1x.
@export_range(0.0, 5.0, 0.01, "or_greater") var move_speed := 0.0
## Jogging speed in m/s. 0 = the jog animation's natural stride speed.
@export_range(0.0, 10.0, 0.01, "or_greater") var jog_speed := 0.0
## Ground speed used when move speed is 0 and the stride can't be measured.
@export var fallback_move_speed := 1.0
@export var acceleration := 6.0
## How quickly the model turns to face its movement direction.
@export var turn_speed := 10.0

@onready var mannequin: Mannequin = $Mannequin
@onready var _camera_rig: ThirdPersonCamera = $CameraRig


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := Basis(Vector3.UP, _camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	var speed := get_effective_move_speed()
	if Input.is_action_pressed(&"move_sprint"):
		speed = get_effective_jog_speed()
	var target := direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	var ground_velocity := get_real_velocity()
	ground_velocity.y = 0.0
	mannequin.animator.set_move_speed(ground_velocity.length())
	if horizontal.length() > 0.05:
		var facing := atan2(horizontal.x, horizontal.z)
		var weight := 1.0 - exp(-turn_speed * delta)
		mannequin.rotation.y = lerp_angle(mannequin.rotation.y, facing, weight)


## Returns the speed the player walks at, in m/s, resolving
## [member move_speed] = 0 to the walk's stride speed.
func get_effective_move_speed() -> float:
	if move_speed > 0.0:
		return move_speed
	var stride_speed := mannequin.animator.stride_speed
	return stride_speed if stride_speed > 0.0 else fallback_move_speed


## Returns the speed the player jogs at, in m/s, resolving [member jog_speed]
## = 0 to the jog's stride speed. Without a jog animation, this is the walking
## speed.
func get_effective_jog_speed() -> float:
	if jog_speed > 0.0:
		return jog_speed
	var jog_stride_speed := mannequin.animator.jog_stride_speed
	return jog_stride_speed if jog_stride_speed > 0.0 else get_effective_move_speed()
