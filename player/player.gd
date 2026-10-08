class_name Player
extends CharacterBody3D
## Walks a customized [Mannequin] around, relative to the camera.
##
## Movement follows where the [ThirdPersonCamera] looks, so the mouse steers
## while moving; standing still, the character doesn't turn and the camera
## orbits freely around it. move_autorun toggles running forward until
## move_forward or move_back is pressed.
##
## Holding move_jog jogs and holding move_sprint sprints. The body turns the
## model toward its movement and reports its real ground speed to the
## [CharacterAnimator], which blends the gaits and scales their playback so
## the feet stay planted (walking into a wall slows the walk instead of
## gliding). Running kicks up a [DustTrail] behind the feet.

## Walking speed in m/s. 0 = the walk animation's natural stride speed, so
## it plays at exactly 1x.
@export_range(0.0, 5.0, 0.01, "or_greater") var move_speed := 0.0:
	set(value):
		move_speed = value
		_update_gait_speeds()
## Jogging speed in m/s. 0 = the jog animation's natural stride speed.
@export_range(0.0, 10.0, 0.01, "or_greater") var jog_speed := 0.0:
	set(value):
		jog_speed = value
		_update_gait_speeds()
## Sprinting speed in m/s. 0 = the sprint animation's natural stride speed.
## Any speed works: the sprint plays faster or slower to keep its feet planted.
@export_range(0.0, 15.0, 0.01, "or_greater") var sprint_speed := 0.0:
	set(value):
		sprint_speed = value
		_update_gait_speeds()
## Ground speed used when move speed is 0 and the stride can't be measured.
@export var fallback_move_speed := 1.0
@export var acceleration := 6.0
## How quickly the model turns to face its movement direction.
@export var turn_speed := 10.0

var _autorun := false

@onready var mannequin: Mannequin = $Mannequin
@onready var _camera_rig: ThirdPersonCamera = $CameraRig
@onready var _dust_trail: DustTrail = $DustTrail


func _ready() -> void:
	_update_gait_speeds()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_autorun"):
		_autorun = not _autorun
	elif event.is_action_pressed(&"move_forward") or event.is_action_pressed(&"move_back"):
		_autorun = false


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if _autorun:
		input = Vector2(input.x, -1.0).limit_length(1.0)
	var direction := Basis(Vector3.UP, _camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	var sprinting := Input.is_action_pressed(&"move_sprint")
	var jogging := not sprinting and Input.is_action_pressed(&"move_jog")
	var speed := get_effective_move_speed()
	if sprinting:
		speed = get_effective_sprint_speed()
	elif jogging:
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
	_dust_trail.set_motion(ground_velocity.length(), is_on_floor())
	var moving := horizontal.length() > 0.05
	_camera_rig.set_motion(moving, jogging, sprinting)
	if moving:
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


## Returns the speed the player sprints at, in m/s, resolving
## [member sprint_speed] = 0 to the sprint's stride speed. Without a sprint
## animation, this is the jogging speed.
func get_effective_sprint_speed() -> float:
	if sprint_speed > 0.0:
		return sprint_speed
	var sprint_stride_speed := mannequin.animator.sprint_stride_speed
	return sprint_stride_speed if sprint_stride_speed > 0.0 else get_effective_jog_speed()


# Tells the animator which gait belongs to which of the player's speeds.
func _update_gait_speeds() -> void:
	if mannequin == null: # Speeds set before the node is ready.
		return
	var speeds: Array[float] = [
		get_effective_move_speed(), get_effective_jog_speed(), get_effective_sprint_speed()
	]
	mannequin.animator.set_gait_speeds(speeds)
