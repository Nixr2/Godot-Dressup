// Transparent decal drawn over the toon-shaded character, e.g. blush.
//
// Matches toon.gdshader's look: lit only by the environment's ambient light,
// crisp pixel-art sampling and per-instance tinting. The texture's alpha
// blends the decal over whatever is behind it, so it needs a mesh that sits
// just above the surface it decorates.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, hint_default_white;
/** The texture's main color, i.e. the value that maps exactly to the tint. */
uniform vec3 texture_base_color : source_color = vec3(1.0);
/** Fades the whole decal. */
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);


void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	vec3 tinted = texel.rgb / max(texture_base_color, vec3(0.001)) * tint.rgb;
	ALBEDO = clamp(mix(texel.rgb, tinted, tint.a), 0.0, 1.0);
	ALPHA = texel.a * opacity;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}


void light() {
	// Intentionally empty: only ambient light contributes.
}
