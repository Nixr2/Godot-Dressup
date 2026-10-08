// World-space grid, useful for judging movement speed and foot sliding.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 base_color : source_color = vec3(0.36, 0.38, 0.42);
uniform vec3 line_color : source_color = vec3(0.22, 0.23, 0.26);
/** Grid spacing in meters. */
uniform float cell_size = 1.0;
/** Line thickness in meters. */
uniform float line_width = 0.03;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 to_line = abs(fract(world_position.xz / cell_size - 0.5) - 0.5) * cell_size;
	float on_line = step(min(to_line.x, to_line.y), line_width * 0.5);
	ALBEDO = mix(base_color, line_color, on_line);
	ROUGHNESS = 1.0;
}
