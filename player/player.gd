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
##
## The toggle_phone action takes the phone out with [member phone_pose]: the
## character stops, mouse look pauses, and [signal phone_opened] fires once
## the phone is open, for a menu to appear. Pressing it again (or calling
## [method put_away_phone]) puts it away. While the phone is out,
## [method set_selfie_mode] holds it out for a selfie with its front camera
## ([SelfieCamera]).

## Emitted once the phone is out and open, ready for its menu.
signal phone_opened
## Emitted when the phone is put away.
signal phone_closed

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
## Arm pose that takes the phone out; its prop is the phone.
@export var phone_pose: ArmPose
## Seconds from taking the phone out until it's open and its menu can show.
@export_range(0.0, 5.0, 0.05, "suffix:s") var phone_open_delay := 1.1

var _autorun := false
var _phone_out := false
# Counts phone requests, so a timer from an earlier one is ignored.
var _phone_request := 0

@onready var mannequin: Mannequin = $Mannequin
@onready var _camera_rig: ThirdPersonCamera = $CameraRig
@onready var _dust_trail: DustTrail = $DustTrail
@onready var _selfie_camera: SelfieCamera = $SelfieCamera


func _ready() -> void:
	_update_gait_speeds()
	_selfie_camera.setup(mannequin)


# Caught before the GUI, so the phone menu's buttons can't swallow it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_phone"):
		if _phone_out:
			put_away_phone()
		else:
			take_out_phone()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _phone_out:
		return
	if event.is_action_pressed(&"move_autorun"):
		_autorun = not _autorun
	elif event.is_action_pressed(&"move_forward") or event.is_action_pressed(&"move_back"):
		_autorun = false


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if _phone_out:
		input = Vector2.ZERO
	elif _autorun:
		input = Vector2(input.x, -1.0).limit_length(1.0)
	var direction := Basis(Vector3.UP, _camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	var sprinting := not _phone_out and Input.is_action_pressed(&"move_sprint")
	var jogging := not _phone_out and not sprinting and Input.is_action_pressed(&"move_jog")
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


## Takes the phone out: plays [member phone_pose], stops the character and
## pauses mouse look. [signal phone_opened] follows once the phone is open.
func take_out_phone() -> void:
	if _phone_out or phone_pose == null:
		return
	_phone_out = true
	_autorun = false
	_phone_request += 1
	mannequin.animator.set_arm_pose(phone_pose)
	_camera_rig.set_look_enabled(false)
	get_tree().create_timer(phone_open_delay).timeout.connect(
			_on_phone_open_delay_elapsed.bind(_phone_request)
	)


## Puts the phone away and resumes mouse look.
func put_away_phone() -> void:
	if not _phone_out:
		return
	set_selfie_mode(false)
	_phone_out = false
	mannequin.animator.set_arm_pose(null)
	_camera_rig.set_look_enabled(true)
	phone_closed.emit()


func is_phone_out() -> bool:
	return _phone_out


## Holds the phone out for a selfie with its front camera (only while the
## phone is out), or back in the phone pose.
func set_selfie_mode(enabled: bool) -> void:
	if enabled and not _phone_out:
		return
	_selfie_camera.activate(enabled)


## Returns the phone's front camera, for a viewfinder to render from.
func get_selfie_camera() -> SelfieCamera:
	return _selfie_camera


func is_selfie_mode() -> bool:
	return _selfie_camera.is_active()


## Switches the phone camera between its normal and wide (0.5x) lens.
func set_wide_lens(wide: bool) -> void:
	_selfie_camera.set_wide_lens(wide)


func _on_phone_open_delay_elapsed(request: int) -> void:
	if _phone_out and request == _phone_request:
		phone_opened.emit()


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
