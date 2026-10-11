shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stock_tint : source_color = vec4(1.0);
uniform float roughness_gain = 0.65;
uniform float normal_gain = 0.12;
uniform float meters_per_tile = 0.6;
uniform bool longitudinal_grain = true;
varying vec2 mapped_uv;
void vertex() {
    vec2 scale = INSTANCE_CUSTOM.xy;
    if (INSTANCE_CUSTOM.a > 0.5) {
        if (abs(NORMAL.x)>0.5) scale.x=INSTANCE_CUSTOM.z;
        if (abs(NORMAL.y)>0.5) scale.y=INSTANCE_CUSTOM.z;
    } else if (abs(NORMAL.x)>0.5) {
        scale=INSTANCE_CUSTOM.yz;
    }
    mapped_uv=UV*scale/max(meters_per_tile,0.001);
}
void fragment() {
    vec2 stock_uv=longitudinal_grain ? mapped_uv.yx : mapped_uv;
    ALBEDO=texture(albedo_tex,stock_uv).rgb*stock_tint.rgb;
    ROUGHNESS=clamp(texture(rough_tex,stock_uv).r*roughness_gain,0.05,1.0);
    vec3 normal_stock=texture(normal_tex,stock_uv).rgb;
    NORMAL_MAP=longitudinal_grain ? normal_stock.yxz : normal_stock;
    NORMAL_MAP_DEPTH=normal_gain;
    METALLIC=0.0;
}
