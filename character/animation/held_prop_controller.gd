class_name HeldPropController
extends Node
## Puts an arm pose's [HeldProp] in the character's hand and plays the prop's
## animation cues in time with the pose.
##
## Call [method hold] when the pose starts and [method release] when it ends;
## a released prop plays its release animation, then disappears. At the
## prop's [member HeldProp.look_time], [signal look_target_changed] hands out
## a point on the prop for the head and eyes to follow, and null on release.
## The prop's materials are converted to [member toon_material] so it matches
## the character.

## Emitted with the point to look at once the prop should be looked at, and
## with null when it shouldn't be any more.
signal look_target_changed(target: Node3D)

@export var skeleton: Skeleton3D
## Template for the prop's materials. Must use toon.gdshader.
@export var toon_material: ShaderMaterial

var _prop: HeldProp
var _attachment: BoneAttachment3D
var _instance: Node3D
var _player: AnimationPlayer
var _cue_times: Array[float] = []
var _next_cue := 0
var _time := 0.0
var _look_target: Node3D


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if not _instance.visible and _time >= _prop.show_time:
		_instance.visible = true
	while _next_cue < _cue_times.size() and _time >= _cue_times[_next_cue]:
		_play(_player, _prop.cues[_cue_times[_next_cue]])
		_next_cue += 1
	var look_pending := _prop.look_time >= 0.0 and _look_target == null
	if look_pending and _time >= _prop.look_time:
		_look_target = Marker3D.new()
		_look_target.name = &"LookTarget"
		_look_target.position = _prop.look_offset
		_instance.add_child(_look_target)
		look_target_changed.emit(_look_target)
		look_pending = false
	if _next_cue >= _cue_times.size() and _instance.visible and not look_pending:
		set_process(false)


## Attaches [param prop] to its bone and restarts its timeline. Replaces any
## prop already held; null just releases it.
func hold(prop: HeldProp) -> void:
	release()
	if prop == null or prop.scene == null:
		return
	_prop = prop
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = prop.bone
	skeleton.add_child(_attachment)
	_instance = prop.scene.instantiate()
	_instance.position = prop.position
	_instance.rotation_degrees = prop.rotation_degrees
	_instance.visible = prop.show_time <= 0.0
	_attachment.add_child(_instance)
	_convert_materials(_instance)
	_player = _find_animation_player(_instance)
	if not prop.start_animation.is_empty() and _play(_player, prop.start_animation):
		# Jump to the state the animation ends in (its start when played backwards).
		var backwards := _player.get_playing_speed() < 0.0
		_player.seek(0.0 if backwards else _player.current_animation_length, true)
	_cue_times.assign(prop.cues.keys())
	_cue_times.sort()
	_next_cue = 0
	_time = 0.0
	set_process(true)


## Removes the held prop, if any, after its release animation.
func release() -> void:
	if _attachment == null:
		return
	var attachment := _attachment
	if _look_target:
		_look_target = null
		look_target_changed.emit(null)
	var animate := _instance.visible and not _prop.release_animation.is_empty()
	if animate and _play(_player, _prop.release_animation):
		_player.animation_finished.connect(
				func(_animation: StringName) -> void: attachment.queue_free(), CONNECT_ONE_SHOT
		)
	else:
		attachment.queue_free()
	_attachment = null
	_instance = null
	_player = null
	_prop = null
	set_process(false)


## Returns the held prop's scene instance, or null.
func get_prop_instance() -> Node3D:
	return _instance


## Returns the point on the prop the character looks at, or null before its
## look time (or with no prop).
func get_look_target() -> Node3D:
	return _look_target


## Returns the held prop's [member HeldProp.look_offset] (e.g. its screen), or
## zero with no prop.
func get_look_offset() -> Vector3:
	return _prop.look_offset if _prop else Vector3.ZERO


# Plays [param cue] on [param player]; a leading "-" plays it backwards.
# Returns false if the prop has no such animation.
func _play(player: AnimationPlayer, cue: StringName) -> bool:
	var animation := StringName(cue.trim_prefix("-"))
	if player == null or not player.has_animation(animation):
		push_warning("HeldPropController: prop has no animation '%s'." % animation)
		return false
	if cue.begins_with("-"):
		player.play_backwards(animation)
	else:
		player.play(animation)
	return true


func _find_animation_player(root: Node) -> AnimationPlayer:
	var players := root.find_children("*", "AnimationPlayer", true, false)
	return null if players.is_empty() else players[0]


func _convert_materials(root: Node) -> void:
	if toon_material == null:
		return
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			var material: ShaderMaterial = toon_material.duplicate()
			if source is BaseMaterial3D:
				material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
			mesh.set_surface_override_material(surface, material)
