shader_type spatial;
// Sheer glass curtains (ninon voile): the same catalogue PBR triplet and metre
// charts as v2_window_stock, drawn double-sided and translucent, with daylight
// through the cloth (backlight) and the faint stir of a draughty sash.
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stock_tint : source_color = vec4(1.0);
uniform float roughness_gain = 0.7;
uniform float meters_per_tile = 0.12;
uniform vec2 cloth_metres = vec2(1.0);
uniform float opacity = 0.42;
uniform float backlight = 0.55;
uniform float stir = 1.0;
varying vec2 stock_uv;
void vertex() {
    vec2 scale = INSTANCE_CUSTOM.xy * cloth_metres;
    stock_uv = UV * scale / max(.001, meters_per_tile);
    // Normalized cloth hangs from Y=0 to Y=-1; the hem moves, the heading does not.
    float hang = clamp(-VERTEX.y, 0.0, 1.1);
    float sway = sin(TIME * 0.55 + VERTEX.x * 5.0 + float(INSTANCE_ID) * 1.7) * 0.6
            + sin(TIME * 0.31 + VERTEX.x * 11.0) * 0.4;
    VERTEX.z += sway * 0.0045 * hang * hang * stir;
}
void fragment() {
    vec3 cloth = texture(albedo_tex, stock_uv).rgb * stock_tint.rgb;
    ALBEDO = cloth;
    ROUGHNESS = clamp(texture(rough_tex, stock_uv).r * roughness_gain, .05, 1.0);
    NORMAL_MAP = texture(normal_tex, stock_uv).rgb;
    NORMAL_MAP_DEPTH = .08;
    BACKLIGHT = cloth * backlight;
    ALPHA = opacity;
}
