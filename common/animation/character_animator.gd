class_name CharacterAnimator
extends AnimationTree
## Plays the character's base animation (idle or a [BodyPose]), blends in a
## stride-matched walk and jog, and layers independent left/right arm poses on
## top.
##
## The blend tree is built on ready:
## [codeblock lang=text]
## Base ───────────────────────────┐
## (idle / body poses)             ├─► Locomotion ─► LeftArmBlend ─► RightArmBlend ─► output
## Walk ─► WalkTimeScale ─┐        │                     ▲               ▲
##                        ├─► Gait ┘           LeftArmTransition  RightArmTransition
## Jog ──► JogTimeScale ──┘
## [/codeblock]
## Arm blends are filtered to one arm's bones, so an arm takes its pose while
## the rest of the body keeps playing the base or locomotion.
##
## Stride matching: each gait's natural ground speed ([member stride_speed],
## [member jog_stride_speed]) is measured from how fast the planted feet
## slide, and it plays at [code]move speed / stride speed[/code] so the feet
## never glide. Between the two speeds the walk blends into the jog; both then
## run at a shared cycle rate, with the jog offset so its footfalls line up
## with the walk's, so the legs never scissor mid-blend.
##
## Animations are exported separately from the model (.glb files imported
## with "Import As: Animation Library"). Skeleton tracks are re-pointed at
## [member skeleton], so the armature name in the export doesn't matter.

const IDLE_INPUT := &"idle"
const SIDES: Array[StringName] = [&"Left", &"Right"]
const STRIDE_SAMPLES := 120
## Fraction of a contact bone's height range treated as touching the ground.
const CONTACT_HEIGHT_FRACTION := 0.1

@export var skeleton: Skeleton3D
## Merged into one library; animation names must be unique across them.
@export var animation_libraries: Array[AnimationLibrary] = []
## Falls back to the first animation whose name contains "idle".
@export var idle_animation: StringName = &"idle"
@export var body_poses: Array[BodyPose] = []
@export var arm_poses: Array[ArmPose] = []
@export var left_arm_root_bone: StringName = &"shoulder.l"
@export var right_arm_root_bone: StringName = &"shoulder.r"
## Seconds to cross-fade between poses.
@export_range(0.0, 2.0, 0.01) var pose_blend_time := 0.25

@export_group("Locomotion")
@export var walk_animation: StringName = &"walk"
## Optional faster gait, blended in above the walk's speed.
@export var jog_animation: StringName = &"jog"
## Lowest bone of each foot (the part that touches the ground), used to
## measure stride speeds. The first one also lines up the gaits' footfalls.
@export var contact_bones: Array[StringName] = [&"toes_01.l", &"toes_01.r"]
## Natural ground speed of the walk in m/s. 0 = measure it from the feet.
@export_range(0.0, 5.0, 0.01, "or_greater") var stride_speed_override := 0.0
## Natural ground speed of the jog in m/s. 0 = measure it from the feet.
@export_range(0.0, 10.0, 0.01, "or_greater") var jog_stride_speed_override := 0.0
## Multiplies the walk and jog playback rate. Raise it if the feet slide
## backward, lower it if they slide forward.
@export_range(0.25, 2.0, 0.01) var walk_playback_multiplier := 1.0
## Movement speed (m/s) at which the walk is fully blended in.
@export_range(0.01, 1.0, 0.01) var walk_blend_speed := 0.15
## Seconds to blend between standing and walking.
@export_range(0.0, 1.0, 0.01) var locomotion_blend_time := 0.2

## The walk's natural ground speed in m/s, measured or overridden.
var stride_speed := 0.0
## The jog's natural ground speed in m/s, measured or overridden. 0 = no jog.
var jog_stride_speed := 0.0

var _body_pose: BodyPose
var _arm_pose: ArmPose
var _move_speed := 0.0
var _has_walk := false
var _has_jog := false
var _locomotion_amount := 0.0
var _gait_amount := 0.0
var _arm_amounts: Dictionary[StringName, float] = { &"Left": 0.0, &"Right": 0.0 }
var _arm_targets: Dictionary[StringName, float] = { &"Left": 0.0, &"Right": 0.0 }
var _arm_inputs: Dictionary[StringName, Array] = {}


func _ready() -> void:
	assert(skeleton != null, "CharacterAnimator requires a Skeleton3D.")
	if animation_libraries.is_empty():
		return
	add_animation_library(&"", _merge_libraries())
	var idle := _find_idle_animation()
	if idle.is_empty():
		push_warning("CharacterAnimator: no idle animation found.")
		return

	_has_walk = has_animation(walk_animation)
	for animation in _get_looping_animations(idle):
		get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	if _has_walk:
		stride_speed = stride_speed_override
		if is_zero_approx(stride_speed):
			stride_speed = measure_stride_speed(walk_animation)
	if _has_walk and has_animation(jog_animation):
		jog_stride_speed = jog_stride_speed_override
		if is_zero_approx(jog_stride_speed):
			jog_stride_speed = measure_stride_speed(jog_animation)
		_has_jog = stride_speed > 0.0 and jog_stride_speed > stride_speed
		if not _has_jog:
			push_warning("CharacterAnimator: the jog must be faster than the walk; jog disabled.")
			jog_stride_speed = 0.0

	tree_root = _build_tree(idle)
	active = true


func _process(delta: float) -> void:
	if tree_root == null:
		return
	if _has_walk:
		var target := clampf(_move_speed / walk_blend_speed, 0.0, 1.0)
		_locomotion_amount = _step_toward(_locomotion_amount, target, delta, locomotion_blend_time)
		set(&"parameters/Locomotion/blend_amount", _locomotion_amount)
		_update_gait(delta)
	for side in SIDES:
		if not _arm_inputs.has(side):
			continue
		_arm_amounts[side] = _step_toward(
				_arm_amounts[side], _arm_targets[side], delta, pose_blend_time
		)
		set("parameters/%sArmBlend/blend_amount" % side, _arm_amounts[side])


## Horizontal movement speed in m/s; drives the walk/jog blend and playback
## rate.
func set_move_speed(speed: float) -> void:
	_move_speed = maxf(speed, 0.0)


## Cross-fades the base animation to [param pose]. Pass null for the idle.
func set_body_pose(pose: BodyPose) -> void:
	_body_pose = pose
	var input := IDLE_INPUT
	if pose and has_animation(pose.animation):
		input = pose.animation
	set(&"parameters/Base/transition_request", input)


## Returns the active body pose, or null while idling.
func get_body_pose() -> BodyPose:
	return _body_pose


## Cross-fades the arms to [param pose]. Pass null to follow the body.
func set_arm_pose(pose: ArmPose) -> void:
	_arm_pose = pose
	_request_arm(&"Left", pose.left_arm_animation if pose else &"")
	_request_arm(&"Right", pose.right_arm_animation if pose else &"")


## Returns the active arm pose, or null when the arms follow the body.
func get_arm_pose() -> ArmPose:
	return _arm_pose


## Measures how fast [param animation]'s feet travel backward while touching
## the ground, in m/s: net distance / time over each contact. For an in-place
## walk this equals the speed the character should move at.
func measure_stride_speed(animation_name: StringName) -> float:
	var animation := get_animation(animation_name)
	var tracks := _index_bone_tracks(animation)
	var step := animation.length / STRIDE_SAMPLES
	var distance := 0.0
	var duration := 0.0
	for bone_name in contact_bones:
		var positions := _sample_contact_bone(animation, tracks, bone_name)
		for contact in _find_contacts(positions):
			var first := positions[contact.x % STRIDE_SAMPLES]
			var last := positions[contact.y % STRIDE_SAMPLES]
			distance += Vector2(last.x - first.x, last.z - first.z).length()
			duration += (contact.y - contact.x) * step
	if is_zero_approx(duration):
		push_warning("CharacterAnimator: couldn't measure stride speed of '%s'." % animation_name)
		return 0.0
	return distance / duration * skeleton.global_basis.get_scale().x


## Where in [param animation_name]'s cycle (0-1) the first contact bone
## touches down, or 0 if it never does.
func measure_contact_phase(animation_name: StringName) -> float:
	var animation := get_animation(animation_name)
	var tracks := _index_bone_tracks(animation)
	var contacts := _find_contacts(_sample_contact_bone(animation, tracks, contact_bones[0]))
	if contacts.is_empty():
		return 0.0
	return float(contacts[0].x % STRIDE_SAMPLES) / STRIDE_SAMPLES


## Blends between walk and jog by speed and scales both so the feet stay
## planted. While blended, both play the same fraction of their cycle per
## second, so their aligned footfalls stay in step.
func _update_gait(delta: float) -> void:
	var walk_length := get_animation(walk_animation).length
	var walk_cycle_rate := 1.0 / walk_length
	if stride_speed > 0.0 and _move_speed > 0.01:
		walk_cycle_rate = _move_speed / stride_speed / walk_length
	if not _has_jog:
		var walk_scale := walk_cycle_rate * walk_length * walk_playback_multiplier
		set(&"parameters/WalkTimeScale/scale", walk_scale)
		return

	var target := clampf(inverse_lerp(stride_speed, jog_stride_speed, _move_speed), 0.0, 1.0)
	_gait_amount = _step_toward(_gait_amount, target, delta, locomotion_blend_time)
	set(&"parameters/Gait/blend_amount", _gait_amount)
	var jog_length := get_animation(jog_animation).length
	var jog_cycle_rate := 1.0 / jog_length
	if _move_speed > 0.01:
		jog_cycle_rate = _move_speed / jog_stride_speed / jog_length
	var cycle_rate := lerpf(walk_cycle_rate, jog_cycle_rate, _gait_amount)
	cycle_rate *= walk_playback_multiplier
	set(&"parameters/WalkTimeScale/scale", cycle_rate * walk_length)
	set(&"parameters/JogTimeScale/scale", cycle_rate * jog_length)


func _request_arm(side: StringName, animation: StringName) -> void:
	if not _arm_inputs.has(side):
		return
	if animation.is_empty() or not animation in _arm_inputs[side]:
		_arm_targets[side] = 0.0
		return
	_arm_targets[side] = 1.0
	set("parameters/%sArmTransition/transition_request" % side, animation)


func _build_tree(idle: StringName) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()

	var base_inputs: Array[StringName] = [IDLE_INPUT]
	for pose in body_poses:
		if not has_animation(pose.animation):
			push_warning("Body pose '%s' uses missing animation '%s'." % [pose.id, pose.animation])
		elif not pose.animation in base_inputs:
			base_inputs.append(pose.animation)
	var base_animations: Array[StringName] = []
	base_animations.assign(base_inputs)
	base_animations[0] = idle
	_add_transition(tree, &"Base", base_inputs, base_animations)
	var previous := &"Base"

	if _has_walk:
		tree.add_node(&"Walk", _animation_node(walk_animation))
		tree.add_node(&"WalkTimeScale", AnimationNodeTimeScale.new())
		tree.connect_node(&"WalkTimeScale", 0, &"Walk")
		var moving := &"WalkTimeScale"
		if _has_jog:
			tree.add_node(&"Jog", _jog_node())
			tree.add_node(&"JogTimeScale", AnimationNodeTimeScale.new())
			tree.connect_node(&"JogTimeScale", 0, &"Jog")
			var gait := AnimationNodeBlend2.new()
			gait.sync = true # Keeps both gaits advancing so they stay in step.
			tree.add_node(&"Gait", gait)
			tree.connect_node(&"Gait", 0, &"WalkTimeScale")
			tree.connect_node(&"Gait", 1, &"JogTimeScale")
			moving = &"Gait"
		tree.add_node(&"Locomotion", AnimationNodeBlend2.new())
		tree.connect_node(&"Locomotion", 0, previous)
		tree.connect_node(&"Locomotion", 1, moving)
		previous = &"Locomotion"

	for side in SIDES:
		var inputs := _collect_arm_inputs(side)
		if inputs.is_empty():
			continue
		_arm_inputs[side] = inputs
		var transition_name := StringName("%sArmTransition" % side)
		var blend_name := StringName("%sArmBlend" % side)
		_add_transition(tree, transition_name, inputs, inputs)
		var blend := AnimationNodeBlend2.new()
		blend.filter_enabled = true
		var root_bone := left_arm_root_bone if side == &"Left" else right_arm_root_bone
		for bone in _get_bone_chain(root_bone):
			blend.set_filter_path(_bone_path(bone), true)
		tree.add_node(blend_name, blend)
		tree.connect_node(blend_name, 0, previous)
		tree.connect_node(blend_name, 1, transition_name)
		previous = blend_name

	tree.connect_node(&"output", 0, previous)
	return tree


## Adds a Transition node named [param node_name] whose inputs are named
## [param inputs] and play [param animations].
func _add_transition(
		tree: AnimationNodeBlendTree,
		node_name: StringName,
		inputs: Array[StringName],
		animations: Array[StringName],
) -> void:
	var transition := AnimationNodeTransition.new()
	transition.xfade_time = pose_blend_time
	transition.input_count = inputs.size()
	tree.add_node(node_name, transition)
	for i in inputs.size():
		transition.set_input_name(i, inputs[i])
		var input_node := StringName("%s%d" % [node_name, i])
		tree.add_node(input_node, _animation_node(animations[i]))
		tree.connect_node(node_name, i, input_node)


## Returns every animation used on [param side] by an [ArmPose].
func _collect_arm_inputs(side: StringName) -> Array[StringName]:
	var inputs: Array[StringName] = []
	for pose in arm_poses:
		var animation := pose.left_arm_animation if side == &"Left" else pose.right_arm_animation
		if animation.is_empty() or animation in inputs:
			continue
		if not has_animation(animation):
			push_warning("Arm pose '%s' uses missing animation '%s'." % [pose.id, animation])
			continue
		inputs.append(animation)
	return inputs


func _get_looping_animations(idle: StringName) -> Array[StringName]:
	var looping: Array[StringName] = [idle]
	if _has_walk:
		looping.append(walk_animation)
		looping.append(jog_animation)
	for pose in body_poses:
		looping.append(pose.animation)
	for pose in arm_poses:
		looping.append(pose.left_arm_animation)
		looping.append(pose.right_arm_animation)
	var existing: Array[StringName] = []
	existing.assign(
			looping.filter(func(animation: StringName) -> bool: return has_animation(animation))
	)
	return existing


## The jog, started at an offset so its first footfall comes at the same
## point of its cycle as the walk's.
func _jog_node() -> AnimationNodeAnimation:
	var node := _animation_node(jog_animation)
	var length := get_animation(jog_animation).length
	var phase := measure_contact_phase(jog_animation) - measure_contact_phase(walk_animation)
	node.use_custom_timeline = true
	node.timeline_length = length
	node.stretch_time_scale = false
	node.start_offset = wrapf(phase, 0.0, 1.0) * length
	node.loop_mode = Animation.LOOP_LINEAR
	return node


func _animation_node(animation: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation
	return node


func _step_toward(current: float, target: float, delta: float, duration: float) -> float:
	if is_zero_approx(duration):
		return target
	return move_toward(current, target, delta / duration)


## Skeleton-space positions of [param bone_name] over one cycle, at
## [constant STRIDE_SAMPLES] + 1 evenly spaced times.
func _sample_contact_bone(
		animation: Animation, tracks: Dictionary[int, Dictionary], bone_name: StringName
) -> PackedVector3Array:
	var positions := PackedVector3Array()
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		push_warning("CharacterAnimator: contact bone '%s' not found." % bone_name)
		return positions
	var step := animation.length / STRIDE_SAMPLES
	for i in STRIDE_SAMPLES + 1:
		positions.append(_sample_bone_transform(animation, tracks, bone, i * step).origin)
	return positions


## Ground contacts in [param positions] as (first, last) sample indices; the
## last can pass [constant STRIDE_SAMPLES] when a contact spans the loop point.
func _find_contacts(positions: PackedVector3Array) -> Array[Vector2i]:
	var contacts: Array[Vector2i] = []
	if positions.is_empty():
		return contacts
	var lowest := INF
	var highest := -INF
	for position in positions:
		lowest = minf(lowest, position.y)
		highest = maxf(highest, position.y)
	var contact_height := lowest + (highest - lowest) * CONTACT_HEIGHT_FRACTION
	# Scan the loop twice so a contact spanning the loop point is whole;
	# count each contact once, by where it starts within the first cycle.
	var contact_start := -1
	for i in STRIDE_SAMPLES * 2 + 1:
		var touching := positions[i % STRIDE_SAMPLES].y <= contact_height
		if touching and contact_start < 0:
			contact_start = i
		elif not touching and contact_start >= 0:
			if contact_start > 0 and contact_start <= STRIDE_SAMPLES:
				contacts.append(Vector2i(contact_start, i - 1))
			contact_start = -1
	return contacts


## Returns [param root_bone] and all of its descendants.
func _get_bone_chain(root_bone: StringName) -> Array[StringName]:
	var chain: Array[StringName] = []
	var root_index := skeleton.find_bone(root_bone)
	if root_index < 0:
		push_warning("CharacterAnimator: arm root bone '%s' not found." % root_bone)
		return chain
	var stack: Array[int] = [root_index]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		chain.append(StringName(skeleton.get_bone_name(bone)))
		stack.append_array(skeleton.get_bone_children(bone))
	return chain


## Maps bone index -> { position/rotation/scale track index } for [param animation].
func _index_bone_tracks(animation: Animation) -> Dictionary[int, Dictionary]:
	var tracks: Dictionary[int, Dictionary] = {}
	for track in animation.get_track_count():
		var bone := skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames())
		if bone < 0:
			continue
		if not tracks.has(bone):
			tracks[bone] = {}
		tracks[bone][animation.track_get_type(track)] = track
	return tracks


## Forward kinematics: [param bone]'s skeleton-space transform at [param time].
func _sample_bone_transform(
		animation: Animation, tracks: Dictionary[int, Dictionary], bone: int, time: float
) -> Transform3D:
	var rest := skeleton.get_bone_rest(bone)
	var bone_tracks: Dictionary = tracks.get(bone, {})
	var position := rest.origin
	var rotation := rest.basis.get_rotation_quaternion()
	var scale := rest.basis.get_scale()
	var position_track: int = bone_tracks.get(Animation.TYPE_POSITION_3D, -1)
	var rotation_track: int = bone_tracks.get(Animation.TYPE_ROTATION_3D, -1)
	var scale_track: int = bone_tracks.get(Animation.TYPE_SCALE_3D, -1)
	if position_track >= 0:
		position = animation.position_track_interpolate(position_track, time)
	if rotation_track >= 0:
		rotation = animation.rotation_track_interpolate(rotation_track, time)
	if scale_track >= 0:
		scale = animation.scale_track_interpolate(scale_track, time)
	var local := Transform3D(Basis(rotation) * Basis.from_scale(scale), position)
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return local
	return _sample_bone_transform(animation, tracks, parent, time) * local


func _bone_path(bone: StringName) -> NodePath:
	return NodePath("%s:%s" % [get_node(root_node).get_path_to(skeleton), bone])


func _merge_libraries() -> AnimationLibrary:
	var merged := AnimationLibrary.new()
	for source in animation_libraries:
		var library := _retarget_library(source)
		for animation_name in library.get_animation_list():
			if merged.has_animation(animation_name):
				push_warning("Duplicate animation '%s' ignored." % animation_name)
				continue
			merged.add_animation(animation_name, library.get_animation(animation_name))
	return merged


## Returns a copy of [param source] whose skeleton tracks target
## [member skeleton] and whose blend shape tracks target meshes by name.
func _retarget_library(source: AnimationLibrary) -> AnimationLibrary:
	var library: AnimationLibrary = source.duplicate(true)
	var mixer_root := get_node(root_node)
	for animation_name in library.get_animation_list():
		var animation := library.get_animation(animation_name)
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			if path.get_subname_count() == 0:
				continue
			match animation.track_get_type(track):
				Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
					animation.track_set_path(track, _bone_path(path.get_concatenated_subnames()))
				Animation.TYPE_BLEND_SHAPE:
					var mesh_name := path.get_name(path.get_name_count() - 1)
					var mesh := skeleton.get_node_or_null(NodePath(mesh_name))
					if mesh:
						var mesh_path := mixer_root.get_path_to(mesh)
						var shape_path := "%s:%s" % [mesh_path, path.get_concatenated_subnames()]
						animation.track_set_path(track, NodePath(shape_path))
	return library


func _find_idle_animation() -> StringName:
	if has_animation(idle_animation):
		return idle_animation
	for animation_name in get_animation_list():
		if animation_name.containsn("idle"):
			return animation_name
	return &""
