// Stylized sky for a day/night cycle (see DayNightCycle, which sets the colors).
//
// A gradient from horizon to zenith, a disk and glow for each directional
// light (sun by day, moon by night, using the light's color and angular
// size), soft drifting clouds lit in the sun's color, and twinkling stars
// that fade in with star_intensity.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.24, 0.5, 0.84);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.82, 0.96);
uniform vec3 ground_color : source_color = vec3(0.14, 0.2, 0.12);
/** Tint for the lit side of clouds; follows the sun's color. */
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.006;
uniform float star_intensity : hint_range(0.0, 1.0) = 0.0;
/** Scales every light's disk; their angular size sets the base size. */
uniform float disk_scale : hint_range(0.5, 10.0) = 3.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
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


float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}


vec3 light_disk(vec3 direction, bool enabled, vec3 light_direction, vec3 color, float energy, float size) {
	if (!enabled) {
		return vec3(0.0);
	}
	float facing = dot(direction, light_direction);
	float radius = max(size, 0.004) * disk_scale * 0.5;
	float disk = smoothstep(cos(radius), cos(radius * 0.8), facing);
	float glow = pow(max(facing, 0.0), 48.0) * 0.35 + pow(max(facing, 0.0), 6.0) * 0.08;
	return color * min(energy, 1.5) * (disk * 2.0 + glow);
}


void sky() {
	vec3 direction = EYEDIR;
	float h = direction.y;
	vec3 color = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		color = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}

	if (!AT_CUBEMAP_PASS && h > 0.0) {
		// Stars: one random point per cell of a fine grid on the sky sphere.
		vec3 cell = floor(direction * 180.0);
		float seed = hash3(cell);
		if (seed > 0.996) {
			vec3 star = (cell + 0.5) / 180.0;
			float point = smoothstep(0.004, 0.0, distance(direction, normalize(star)));
			float twinkle = 0.6 + 0.4 * sin(TIME * (2.0 + seed * 4.0) + seed * 80.0);
			color += vec3(point * twinkle * star_intensity * smoothstep(0.0, 0.25, h));
		}

		// Clouds projected onto a flat layer above the field.
		vec2 uv = direction.xz / (h + 0.12) * 0.55 + vec2(1.0, 0.35) * TIME * cloud_speed;
		float n = fbm(uv * 1.6);
		float cover = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, n);
		float shade = mix(0.75, 1.0, smoothstep(0.4, 0.9, n));
		vec3 clouds = mix(horizon_color, cloud_color, 0.8) * shade;
		color = mix(color, clouds, cover * smoothstep(0.0, 0.2, h) * 0.9);
	}

	color += light_disk(direction, LIGHT0_ENABLED, LIGHT0_DIRECTION, LIGHT0_COLOR, LIGHT0_ENERGY, LIGHT0_SIZE);
	color += light_disk(direction, LIGHT1_ENABLED, LIGHT1_DIRECTION, LIGHT1_COLOR, LIGHT1_ENERGY, LIGHT1_SIZE);
	COLOR = color;
}
