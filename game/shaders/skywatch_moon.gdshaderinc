// Measured LOLA terrain, unsigned half-metres packed in R(high), G(low).
// Linear byte interpolation preserves height; never import as source_color.
uniform sampler2D moon_height : filter_linear_mipmap, repeat_enable;
uniform bool moon_relief_enabled = false;
uniform bool moon_shadow_enabled = true;
uniform float moon_relief_gain = 2.5;
uniform float moon_visual_scale = 2.5;
uniform vec4 moon_eclipse_shadow = vec4(0.0); // XY shadow centre; umbra/penumbra radii

vec3 lunar_eclipse_transmission(vec2 disc) {
    if(moon_eclipse_shadow.w<=0.0) return vec3(1.0);
    float distance=length(disc-moon_eclipse_shadow.xy);
    float penumbra=1.0-smoothstep(moon_eclipse_shadow.z,moon_eclipse_shadow.w,distance);
    float umbra=1.0-smoothstep(moon_eclipse_shadow.z-.06,moon_eclipse_shadow.z+.06,distance);
    // Penumbra is cool/brown grey; only actual umbral immersion turns copper.
    return mix(mix(vec3(1.0),vec3(.53,.49,.46),penumbra*.62),vec3(.55,.09,.025),umbra);
}

vec2 lunar_coordinates(vec3 n) {
    return vec2(atan(n.x,n.z)/(2.0*PI)+.5,.5-asin(clamp(n.y,-1.0,1.0))/PI);
}
float lunar_height(vec3 n) {
    vec2 code=textureLod(moon_height,lunar_coordinates(normalize(n)),0.0).rg;
    return ((code.r*65280.0+code.g*255.0)*.5-10000.0)/1737400.0*moon_relief_gain;
}
vec3 lunar_terrain_normal(vec3 n) {
    float lon=atan(n.x,n.z);
    float lat=asin(clamp(n.y,-1.0,1.0));
    vec3 east=vec3(cos(lon),0.0,-sin(lon));
    vec3 north=vec3(-sin(lon)*sin(lat),cos(lat),-cos(lon)*sin(lat));
    float spacing=.0011;
    float dx=(lunar_height(normalize(n+east*spacing))-lunar_height(normalize(n-east*spacing)))/(2.0*spacing);
    float dy=(lunar_height(normalize(n+north*spacing))-lunar_height(normalize(n-north*spacing)))/(2.0*spacing);
    return normalize(n-east*dx-north*dy);
}
float lunar_terrain_shadow(vec3 n,vec3 solar) {
    // Bounded spherical heightfield horizon search; crater walls cast actual
    // relief shadows rather than painting darkness into the albedo.
    vec3 start=n*(1.0+lunar_height(n)+.000006);
    float visibility=1.0;
    for(int i=1;i<=16;i++) {
        float distance=.00032*pow(float(i),1.75);
        vec3 p=start+solar*distance;
        float clearance=length(p)-1.0-lunar_height(p);
        visibility=min(visibility,smoothstep(-.000004,.000009,clearance));
    }
    return visibility;
}
