shader_type spatial;
render_mode depth_prepass_alpha;
// Relief overlay on registered steel. UV is physical metres; UV2 is the
// font atlas. No screen read, TIME animation, shadowed light or extra pass.
uniform sampler2D type_plate : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float excitation : hint_range(0.0, 1.0) = 0.0;
uniform float idle_excitation : hint_range(0.0, 1.0) = 0.0;
uniform vec3 radiance_color : source_color = vec3(.85, .12, .012);
uniform float selected_cell = -1.0;
uniform float spin_blur : hint_range(0.0, 1.0) = 0.0;
uniform vec3 steel_color : source_color = vec3(0.15, 0.17, 0.18);
uniform sampler2D steel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metres_per_tile = 0.08;
void fragment() {
    vec4 plate=texture(type_plate,UV2);
    // Three local atlas taps smear the letter during selection. This does
    // not blur the world or require multiple copies of the type head.
    vec2 cell=floor(UV2*vec2(8.0,6.0));
    vec2 lo=(cell+vec2(.06))/vec2(8.0,6.0);
    vec2 hi=(cell+vec2(.94))/vec2(8.0,6.0);
    float sweep=.025*spin_blur;
    float mask=(plate.a+texture(type_plate,clamp(UV2+vec2(sweep,0.0),lo,hi)).a+
        texture(type_plate,clamp(UV2-vec2(sweep,0.0),lo,hi)).a)/3.0;
    ALBEDO=texture(steel_albedo,UV/metres_per_tile).rgb*steel_color;
    METALLIC=.85;ROUGHNESS=texture(steel_roughness,UV/metres_per_tile).r;
    vec3 micro=texture(steel_normal,UV/metres_per_tile).rgb*2.0-1.0;
    NORMAL_MAP=normalize(vec3((plate.rg*2.0-1.0)+micro.xy*.2,1.0))*.5+.5;NORMAL_MAP_DEPTH=1.0;
    ALPHA=mask;
    float index=(5.0-cell.y)*8.0+cell.x;
    // The whole radioactive alphabet remains faintly luminous, even before
    // its first selection. Only the active stamp receives the writing pulse.
    float selected=1.0-step(.25,abs(index-selected_cell));
    float exposed=max(idle_excitation,selected*excitation);
    EMISSION=radiance_color*exposed*.65;
}
