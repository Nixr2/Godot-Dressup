@tool
class_name DayNightCycle
extends Node
## Drives a sun, a moon, the sky and the ambient light through a 24-hour day.
##
## [member time_of_day] advances by itself (one in-game day every
## [member day_length] seconds) unless [member paused]. Colors come from
## gradients sampled by time of day (0 = midnight, 0.5 = noon), so the look of
## every hour can be tuned in the Inspector. The sky must use
## day_night_sky.gdshader. Characters using toon.gdshader take their color from
## the ambient light, so the ambient gradient is what tints them; the sun and
## moon only add a pale, dither-edged shaded side. It shares the ambient light
## with the toon shader through the toon_ambient_* global shader parameters,
## and restores their defaults when it leaves the tree.
##
## Works in the editor too: scrub [member time_of_day] to preview any hour.

## Emitted when the in-game minute changes.
signal time_changed(hours: float)

# Global shader parameters that tell the toon shader the ambient light.
const AMBIENT_COLOR_PARAMETER := &"toon_ambient_color"
const AMBIENT_ENERGY_PARAMETER := &"toon_ambient_energy"

## Hours since midnight, 0-24.
@export_range(0.0, 24.0, 0.01, "suffix:h") var time_of_day := 9.0:
	set(value):
		time_of_day = wrapf(value, 0.0, 24.0)
		_apply()
## Real seconds for one full day.
@export_range(10.0, 3600.0, 1.0, "suffix:s") var day_length := 240.0
@export var paused := false
## Tilt of the sun's path away from straight overhead, so noon light has an angle.
@export_range(0.0, 80.0, 1.0, "suffix:°") var sun_path_tilt := 35.0

@export_group("Nodes")
@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Colors")
@export var sky_top_colors: Gradient
@export var sky_horizon_colors: Gradient
@export var sun_colors: Gradient
@export var ambient_colors: Gradient
## Sun light energy at full height; it fades out around sunrise and sunset.
@export_range(0.0, 5.0, 0.01) var sun_energy := 1.2
@export_range(0.0, 2.0, 0.01) var moon_energy := 0.25
@export_range(0.0, 4.0, 0.01) var day_ambient_energy := 1.0
@export_range(0.0, 4.0, 0.01) var night_ambient_energy := 0.55

var _last_minute := -1


func _ready() -> void:
	# The lights turn every frame, so physics interpolation would only make
	# them step.
	for light: DirectionalLight3D in [sun, moon]:
		if light:
			light.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply()


func _exit_tree() -> void:
	for parameter: StringName in [AMBIENT_COLOR_PARAMETER, AMBIENT_ENERGY_PARAMETER]:
		var setting: Dictionary = ProjectSettings.get_setting("shader_globals/" + parameter, {})
		if setting.has("value"):
			RenderingServer.global_shader_parameter_set(parameter, setting.value)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or paused:
		return
	time_of_day += delta / day_length * 24.0
	var minute := floori(time_of_day * 60.0)
	if minute != _last_minute:
		_last_minute = minute
		time_changed.emit(time_of_day)


## How far the sun is above the horizon, from -1 (midnight) to 1 (noon).
func get_sun_height() -> float:
	return sin((time_of_day - 6.0) / 12.0 * PI)


func _apply() -> void:
	if not is_inside_tree():
		return
	var day := time_of_day / 24.0
	var angle := (time_of_day - 6.0) / 12.0 * PI
	var tilt := deg_to_rad(sun_path_tilt)
	# Rises in the east (+X), peaks south-ish, sets in the west.
	var to_sun := Vector3(cos(angle), sin(angle) * cos(tilt), sin(angle) * sin(tilt)).normalized()
	var height := to_sun.y
	var daylight := smoothstep(-0.08, 0.12, height)

	if sun:
		_point_light(sun, to_sun)
		sun.light_color = _sample(sun_colors, day, Color.WHITE)
		sun.light_energy = sun_energy * smoothstep(-0.02, 0.18, height)
		sun.visible = height > -0.05
	if moon:
		_point_light(moon, -to_sun)
		moon.light_energy = moon_energy * smoothstep(-0.02, 0.18, -height)
		moon.visible = -height > -0.05

	if world_environment and world_environment.environment:
		var environment := world_environment.environment
		environment.ambient_light_color = _sample(ambient_colors, day, Color.WHITE)
		environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
		RenderingServer.global_shader_parameter_set(
				AMBIENT_COLOR_PARAMETER, environment.ambient_light_color
		)
		RenderingServer.global_shader_parameter_set(
				AMBIENT_ENERGY_PARAMETER, environment.ambient_light_energy
		)
		var sky_material: ShaderMaterial = null
		if environment.sky:
			sky_material = environment.sky.sky_material as ShaderMaterial
		if sky_material:
			var horizon := _sample(sky_horizon_colors, day, Color.LIGHT_BLUE)
			var top := _sample(sky_top_colors, day, Color.CORNFLOWER_BLUE)
			sky_material.set_shader_parameter(&"top_color", top)
			sky_material.set_shader_parameter(&"horizon_color", horizon)
			# Stars come out once dusk has faded.
			var stars := 1.0 - smoothstep(-0.4, -0.15, height)
			sky_material.set_shader_parameter(&"star_intensity", stars)
			var cloud := _sample(sun_colors, day, Color.WHITE).lerp(horizon, 1.0 - daylight)
			sky_material.set_shader_parameter(&"cloud_color", cloud * lerpf(0.35, 1.0, daylight))


## Aims [param light] so it shines from [param toward_light] onto the scene.
func _point_light(light: DirectionalLight3D, toward_light: Vector3) -> void:
	var up := Vector3.UP if absf(toward_light.y) < 0.99 else Vector3.BACK
	light.global_basis = Basis.looking_at(-toward_light, up)


func _sample(gradient: Gradient, offset: float, fallback: Color) -> Color:
	return gradient.sample(offset) if gradient else fallback
