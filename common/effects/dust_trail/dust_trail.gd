class_name DustTrail
extends GPUParticles3D
## Puffs of dust kicked up behind a running character.
##
## Place it at the character's feet and call [method set_motion] every physics
## frame. It emits nothing below [member min_speed], more and more up to
## [member full_speed], and nothing while airborne. Particles live in world
## space, so they stay where they were kicked up and form a trail.
##
## The puff texture is the draw pass material's albedo texture (a generated
## soft circle for now); replace it with an authored one there.

## Speed in m/s where dust starts (above a walk).
@export_range(0.0, 10.0, 0.01, "suffix:m/s") var min_speed := 1.5
## Speed in m/s where dust is at its fullest.
@export_range(0.0, 15.0, 0.01, "suffix:m/s") var full_speed := 3.6


func _ready() -> void:
	amount_ratio = 0.0
	emitting = true


## Sets how much dust to kick up from the character's ground [param speed].
func set_motion(speed: float, on_floor: bool) -> void:
	var amount := 0.0
	if on_floor and full_speed > min_speed:
		amount = clampf(inverse_lerp(min_speed, full_speed, speed), 0.0, 1.0)
	amount_ratio = amount
