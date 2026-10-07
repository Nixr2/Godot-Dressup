// Soil-and-grass ground under a grass field: soft world-space patches of two
// greens, so the ground matches the blades' roots and never visibly tiles.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// Close to the grass's mid-tone, so where the blades fade out the ground blends in.
uniform vec3 color_a : source_color = vec3(0.26, 0.45, 0.17);
uniform vec3 color_b : source_color = vec3(0.34, 0.53, 0.21);
/** Size of the color patches, in meters. */
uniform float patch_scale : hint_range(0.5, 50.0) = 6.0;

varying vec3 world_position;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
			u.y);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 p = world_position.xz / patch_scale;
	float n = value_noise(p) * 0.6 + value_noise(p * 2.7) * 0.3 + value_noise(p * 7.1) * 0.1;
	ALBEDO = mix(color_a, color_b, smoothstep(0.3, 0.7, n));
	ROUGHNESS = 1.0;
}
