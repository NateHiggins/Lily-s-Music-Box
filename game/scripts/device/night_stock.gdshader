shader_type spatial;
render_mode cull_back;

// Carbon-bound phosphor paper: the unexposed stock reflects light; only the
// printer's physical glyphs glow. One opaque pass, registered paper maps,
// stable UV grain and derivative-filtered mineral inclusions. No screen reads.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stock_color : source_color = vec4(.006,.009,.007,1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float normal_strength = .12;
uniform float grain_strength : hint_range(0.0,1.0) = .7;

void fragment() {
    vec2 uv=UV*uv_scale;
    float fibre=texture(albedo_tex,uv).r;
    float rough=texture(rough_tex,uv).r;
    vec2 grain=uv*320.0;
    vec2 cell=floor(grain);
    float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
    vec2 flake=(fract(grain)-.5)*vec2(1.0,2.7);
    float mica=step(.975,seed)*(1.0-smoothstep(.08,.30,length(flake)));
    // Suppress subpixel sparkle as the instrument recedes into travel pose.
    float footprint=max(fwidth(grain.x),fwidth(grain.y));
    mica*=1.0-smoothstep(.5,1.2,footprint);
    mica*=grain_strength;
    ALBEDO=stock_color.rgb*mix(1.0,mix(.65,1.3,fibre),grain_strength);
    ROUGHNESS=clamp(rough*mix(1.0,.82,grain_strength)-mica*.12,.65,.98);
    METALLIC=0.0;
    SPECULAR=.18+mica*.22;
    NORMAL_MAP=texture(normal_tex,uv).rgb;
    NORMAL_MAP_DEPTH=normal_strength;
}
