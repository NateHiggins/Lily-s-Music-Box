shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stock_tint : source_color = vec4(1.0);
uniform float roughness_gain = 0.7;
uniform float meters_per_tile = 0.6;
uniform vec2 cloth_metres = vec2(1.0);
uniform bool longitudinal_grain = false;
uniform bool end_grain = false;
varying vec2 stock_uv;
void vertex() {
    vec2 scale = INSTANCE_CUSTOM.xy * cloth_metres;
    if (end_grain && abs(NORMAL.x) > .9) scale = vec2(1.0);
    stock_uv = UV * scale / max(.001, meters_per_tile);
}
void fragment() {
    vec2 uv = longitudinal_grain ? stock_uv.yx : stock_uv;
    ALBEDO = texture(albedo_tex, uv).rgb * stock_tint.rgb;
    ROUGHNESS = clamp(texture(rough_tex, uv).r * roughness_gain, .05, 1.0);
    vec3 mapped = texture(normal_tex, uv).rgb;
    NORMAL_MAP = longitudinal_grain ? mapped.yxz : mapped;
    NORMAL_MAP_DEPTH = .12;
}
