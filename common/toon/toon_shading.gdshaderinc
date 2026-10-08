// Hard two-tone shading with a dithered edge, shared by the toon shaders.
//
// The lit side keeps the flat ambient look (texture x tint x ambient light).
// Each light carves a shaded side into the surfaces facing away from it: the
// same color multiplied by toon_shade_color, so it stays the texture's color,
// just slightly tinted, however bright or dark the scene is. The two tones
// meet at a hard edge, and across toon_dither_width the edge breaks into an
// ordered (Bayer) dither pattern instead of a gradient.
//
// Shading follows the lights' strength: it reaches toon_shade_color once a
// light is toon_shade_light_energy bright and fades with it, so a setting
// sun's shading fades away instead of popping off.

// The settings are global shader parameters, shared by every toon material:
// edit them in Project Settings > Globals > Shader Globals, or at runtime with
// RenderingServer.global_shader_parameter_set().
//   toon_ambient_color,      The scene's ambient light, which the shaded side
//   toon_ambient_energy      is a fraction of. Kept in sync with the
//                            environment by DayNightCycle; the defaults match
//                            stages with plain white ambient light.
//   toon_shade_color         Multiplies the shaded side. Closer to white = the
//                            two tones are closer.
//   toon_shade_threshold     Where the shaded side starts (-1 to 1): higher
//                            puts more of the surface in shade.
//   toon_dither_width        How wide the dithered band at the edge is (0 to 1):
//                            0 = a clean hard line.
//   toon_dither_pixel_size   Size of one dither dot in screen pixels.
//   toon_shade_light_energy  Light energy at which the shading reaches full
//                            strength; dimmer lights shade less.
global uniform vec4 toon_ambient_color;
global uniform float toon_ambient_energy;
global uniform vec4 toon_shade_color;
global uniform float toon_shade_threshold;
global uniform float toon_dither_width;
global uniform float toon_dither_pixel_size;
global uniform float toon_shade_light_energy;

// 4x4 Bayer matrix: the order in which dots switch on as the edge crosses.
const float BAYER_4X4[16] = {
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
};


// Global colors arrive as picked (sRGB), but lighting runs in linear space.
vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(0.04045, color));
}


// Threshold for this screen position, between 0 and 1.
float bayer_threshold(vec2 frag_coord) {
	ivec2 cell = ivec2(mod(floor(frag_coord / max(toon_dither_pixel_size, 1.0)), 4.0));
	return (BAYER_4X4[cell.y * 4 + cell.x] + 0.5) / 16.0;
}


// Call from light() with its built-ins; returns what to add to DIFFUSE_LIGHT.
vec3 toon_shade(vec3 normal, vec3 light, vec3 light_color, float attenuation, vec2 frag_coord) {
	float facing = dot(normal, light);
	float half_width = max(toon_dither_width * 0.5, 0.0001);
	// 0 at the shaded end of the band, 1 at the lit end; each dot turns lit
	// once this passes its Bayer threshold.
	float coverage = clamp(
			(facing - toon_shade_threshold + half_width) / (2.0 * half_width), 0.0, 1.0);
	float lit = step(bayer_threshold(frag_coord), coverage);
	// LIGHT_COLOR includes a factor of PI.
	float energy = dot(light_color / PI * attenuation, vec3(0.299, 0.587, 0.114));
	float strength = clamp(energy / max(toon_shade_light_energy, 0.01), 0.0, 1.0);
	// Negative light takes away the share of the ambient light that turns the
	// lit color into lit color x shade color.
	vec3 ambient = srgb_to_linear(toon_ambient_color.rgb) * toon_ambient_energy;
	vec3 shade = srgb_to_linear(toon_shade_color.rgb);
	return -(1.0 - lit) * strength * (vec3(1.0) - shade) * ambient;
}
