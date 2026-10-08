class_name HeldProp
extends Resource
## A prop held in the hand during an [ArmPose], such as a phone.
##
## The prop's scene is attached to [member bone] and placed by
## [member position] and [member rotation_degrees] (relative to the bone;
## tune them while the pose plays). It appears [member show_time] seconds into
## the pose, starting in the state [member start_animation] ends in, and each
## entry in [member cues] plays one of the prop's own animations at that time,
## e.g. flipping a phone open as it reaches the face. When the pose ends,
## [member release_animation] plays (e.g. closing the phone) before the prop
## is removed.

@export var scene: PackedScene
@export var bone: StringName = &"hand.l"
@export var position := Vector3.ZERO
@export var rotation_degrees := Vector3.ZERO
@export_range(0.0, 10.0, 0.01, "suffix:s") var show_time := 0.0
## Prop animation whose last frame is the prop's starting state, e.g. "close".
@export var start_animation: StringName
## Seconds into the pose -> prop animation to play then.
@export var cues: Dictionary[float, StringName] = {}
## Prop animation played when the pose ends, before the prop is removed.
@export var release_animation: StringName
# Every animation name above can be prefixed with "-" to play it backwards
# (e.g. "-open" closes a phone whose only animation opens it).
