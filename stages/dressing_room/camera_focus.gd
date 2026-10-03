class_name CameraFocus
extends Resource
## A framing the dressing room camera can glide to, e.g. "face" or "torso".

@export var id: StringName
## Bone the camera looks at. Empty = the skeleton's origin.
@export var bone: StringName
## Added to the bone's position, in the character's space.
@export var offset := Vector3.ZERO
## Distance from the focus point, in meters.
@export_range(0.1, 10.0, 0.01, "or_greater") var distance := 2.0
## Camera pitch in degrees (negative looks down).
@export_range(-89.0, 89.0) var pitch_degrees := -5.0
