// Short stylized grass blades for a MultiMesh (see GrassField).
//
// Blades sway in layered wind with slow travelling gusts, bend away from a
// point (the player), and shade from a dark root to a sunlit tip. Normals
// point straight up so a field shades evenly like the ground under it, and a
// little backlight lets low sun glow through the blades.
//
// Per instance: COLOR tints the blade (variation), INSTANCE_CUSTOM.x is a
// random phase so neighbours don't sway in lockstep.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert_wrap, specular_disabled;

group_uniforms colors;
uniform vec3 root_color : source_color = vec3(0.12, 0.27, 0.11);
uniform vec3 tip_color : source_color = vec3(0.56, 0.76, 0.34);
/** Translucency when lit from behind, strongest at the tips. */
uniform float backlight : hint_range(0.0, 1.0) = 0.35;

// Wind and bending amounts are fractions of each blade's height, so short and
// tall blades lean by the same angle.
group_uniforms wind;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.22;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.6;
/** Size of the travelling gust bands, in meters. */
uniform float gust_scale : hint_range(1.0, 40.0) = 9.0;
uniform float gust_strength : hint_range(0.0, 1.0) = 0.35;

group_uniforms bending;
/** World position blades bend away from, set every frame by GrassField. */
uniform vec3 bend_center = vec3(0.0, -1000.0, 0.0);
uniform float bend_radius : hint_range(0.05, 2.0) = 0.35;
uniform float bend_strength : hint_range(0.0, 1.5) = 0.8;

varying float height;
varying vec3 variation;


void vertex() {
	height = UV.y;
	variation = COLOR.rgb;
	vec3 root = MODEL_MATRIX[3].xyz;
	float blade_height = length(MODEL_MATRIX[1].xyz);
	vec2 wind = normalize(wind_direction);

	// Slow bands of gusts roll across the field, small flutter on top.
	float travel = dot(root.xz, wind) / gust_scale - TIME * wind_speed * 0.25;
	float gust = smoothstep(0.0, 1.0, sin(travel) * 0.5 + 0.5);
	float flutter = sin(TIME * wind_speed * 2.3 + INSTANCE_CUSTOM.x * 6.2832 + root.x * 1.7);
	vec2 offset = wind * (gust * gust_strength + flutter * wind_strength * (0.4 + gust));

	vec2 away = root.xz - bend_center.xz;
	float distance_to_center = length(away);
	float push = (1.0 - smoothstep(0.0, bend_radius, distance_to_center)) * bend_strength;
	if (distance_to_center > 0.001) {
		offset += away / distance_to_center * push;
	}

	// Only the upper blade moves; it dips as it leans so it keeps its length.
	offset *= blade_height;
	float bend = height * height;
	VERTEX.xz += offset * bend;
	VERTEX.y -= dot(offset, offset) / max(blade_height, 0.01) * bend * 0.6;
	NORMAL = vec3(0.0, 1.0, 0.0);
}


void fragment() {
	vec3 color = mix(root_color, tip_color, smoothstep(0.0, 1.0, height)) * variation;
	ALBEDO = color;
	BACKLIGHT = color * backlight * height;
	// Roots sit in the blades' shade.
	AO = mix(0.45, 1.0, height);
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = 1.0;
}
