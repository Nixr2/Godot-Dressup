class_name SkinTonePalette
extends Resource
## Maps a tone value (0 = lightest, 1 = deepest) and an undertone value
## (-1 = cool/rosy, 1 = warm/golden) to a realistic skin color.
##
## Undertone shifts are kept small so every result stays a plausible skin tone.

## Realistic skin colors ordered from lightest to deepest.
@export var gradient: Gradient
## Maximum hue shift applied at full undertone, in the 0-1 hue range.
@export_range(0.0, 0.05, 0.001) var max_hue_shift := 0.012
## Maximum relative saturation change applied at full undertone.
@export_range(0.0, 0.5, 0.01) var max_saturation_shift := 0.12


## Returns the skin color for [param tone] (0-1) shifted by
## [param undertone] (-1 to 1).
func get_color(tone: float, undertone: float) -> Color:
	var color := gradient.sample(clampf(tone, 0.0, 1.0))
	var shift := clampf(undertone, -1.0, 1.0)
	return Color.from_hsv(
			wrapf(color.h + shift * max_hue_shift, 0.0, 1.0),
			clampf(color.s * (1.0 + shift * max_saturation_shift), 0.0, 1.0),
			color.v
	)
