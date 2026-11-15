// Registered tissue recipe maps for the dream's living surfaces (RUL-012: real UVs, a registered recipe's
// albedo, roughness and OpenGL normal, complete mips). The procedural colour, motion and optics of each shader
// stay its own; the recipe adds the tissue's grain and relief over it. dream_moss_colony_renderer.gd binds a
// recipe from res://assets/dream/waking_colony/ with _bind_waking_recipe().

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_tile = vec2(1.0);        // repeats of the recipe across the mesh's UV square
uniform float tissue_grain = 0.55;       // how much of the recipe's grain shows in the pigment and roughness
uniform float normal_depth = 0.6;

// The recipe maps average about 0.8; the gain keeps the shader's own pigment value.
vec3 tissue_albedo(vec3 pigment, vec2 uv) {
	vec3 grain = texture(albedo_tex, uv * uv_tile).rgb * 1.22;
	return pigment * mix(vec3(1.0), grain, tissue_grain);
}

float tissue_roughness(float procedural, vec2 uv) {
	return clamp(mix(procedural, texture(rough_tex, uv * uv_tile).r, tissue_grain), 0.04, 1.0);
}

vec3 tissue_normal(vec2 uv) {
	return texture(normal_tex, uv * uv_tile).rgb;
}
