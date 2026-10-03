// Flat shading lit only by the environment's ambient light, with crisp
// pixel-art textures, per-instance tinting and clothing-driven body masking.
//
// Direct lights (directional, omni, spot) are ignored, so the character's
// color is texture x tint x the WorldEnvironment's ambient color/energy.
// Change the ambient light to re-tint the whole character for a scene or mood.
//
// Tinting: texels equal to `texture_base_color` become exactly `tint.rgb`;
// darker/lighter texels (painted shading, highlights) keep their relative value.
// `tint.a` blends from the untouched texture (0.0) to fully tinted (1.0).
//
// Body masking: each worn garment can supply a hide mask painted over the
// same UVs (white = hidden). Pixels white in any of the first
// `hide_mask_count` masks are not drawn, so skin covered by clothing can't
// poke through it.
shader_type spatial;
render_mode cull_disabled, specular_disabled, shadows_disabled;

const int MAX_HIDE_MASKS = 8;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, hint_default_white;
/** The texture's main color, i.e. the value that maps exactly to the tint. */
uniform vec3 texture_base_color : source_color = vec3(1.0);
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

group_uniforms body_hiding;
/** Set at runtime by the Wardrobe from the worn items' hide masks. */
uniform sampler2D hide_masks[MAX_HIDE_MASKS] : filter_nearest, repeat_enable;
uniform int hide_mask_count = 0;


bool is_hidden(vec2 uv) {
	for (int i = 0; i < min(hide_mask_count, MAX_HIDE_MASKS); i++) {
		if (texture(hide_masks[i], uv).r > 0.5) {
			return true;
		}
	}
	return false;
}


void fragment() {
	if (is_hidden(UV)) {
		discard;
	}
	vec3 texel = texture(albedo_texture, UV).rgb;
	vec3 tinted = texel / max(texture_base_color, vec3(0.001)) * tint.rgb;
	ALBEDO = clamp(mix(texel, tinted, tint.a), 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}


void light() {
	// Intentionally empty: only ambient light contributes.
}
