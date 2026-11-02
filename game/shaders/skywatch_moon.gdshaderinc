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

// A name cut into the near side (design/ORISON_MOON_NAME_2026-11-02.md). It is
// terrain, not a mark: only raking light and a large enough disc can read it.
uniform float moon_name_amount = 0.0;
const float MOON_NAME_DEPTH = .0065;
const float MOON_NAME_WIDTH = .033;
const vec4 MOON_NAME[16] = {
    vec4(-.76,-.17,-.64,.21),vec4(-.64,.21,-.52,-.17),vec4(-.71,-.03,-.57,-.03),
    vec4(-.42,-.17,-.42,.21),vec4(-.42,.21,-.23,.10),vec4(-.23,.10,-.23,-.07),vec4(-.23,-.07,-.42,-.17),
    vec4(-.11,-.17,-.11,.21),vec4(-.11,.21,.11,.21),vec4(-.11,.03,.15,.04),vec4(-.11,-.17,.09,-.17),
    vec4(.23,.21,.23,-.17),vec4(.23,-.17,.42,-.17),
    vec4(.50,-.17,.62,.21),vec4(.62,.21,.74,-.17),vec4(.55,-.03,.69,-.03)
};
float moon_name_cut(vec3 n) {
    if(moon_name_amount<=0.0 || n.z<=0.0) return 0.0;
    vec3 u=normalize(n);
    // The first letter slid downhill in the last two bars of the exposure.
    // The disc basis runs right-to-left on screen; the name reads left-to-right.
    vec2 q=vec2(-u.x,u.y+.07*(1.0-smoothstep(-.82,-.40,-u.x)));
    if(abs(q.x)>.86 || abs(q.y-.02)>.31) return 0.0;
    float nearest=1.0;
    for(int i=0;i<16;i++) {
        vec2 a=MOON_NAME[i].xy;
        vec2 b=MOON_NAME[i].zw-a;
        nearest=min(nearest,length(q-a-b*clamp(dot(q-a,b)/dot(b,b),0.0,1.0)));
    }
    // A hand, not a stencil.
    nearest+=.0035*sin(q.x*83.0+q.y*59.0);
    return moon_name_amount*MOON_NAME_DEPTH*(1.0-smoothstep(MOON_NAME_WIDTH,MOON_NAME_WIDTH+.014,nearest));
}

// How much light the cut floor loses. In low sun its walls shade it whole, which
// reads even at the naked eye's few pixels. In high sun only the darker exposed
// rock remains, and that resolves only under magnification.
float moon_name_shade(vec3 n,vec3 solar,float disc_per_pixel) {
    if(moon_name_amount<=0.0) return 0.0;
    float floor_mask=moon_name_cut(n)/(moon_name_amount*MOON_NAME_DEPTH);
    float rake=1.0-smoothstep(.10,.50,dot(normalize(n),solar));
    float glass=1.0-smoothstep(.008,.022,disc_per_pixel);
    return floor_mask*max(.8*rake,.4*glass);
}

vec2 lunar_coordinates(vec3 n) {
    return vec2(atan(n.x,n.z)/(2.0*PI)+.5,.5-asin(clamp(n.y,-1.0,1.0))/PI);
}
float lunar_height(vec3 n) {
    vec2 code=textureLod(moon_height,lunar_coordinates(normalize(n)),0.0).rg;
    return ((code.r*65280.0+code.g*255.0)*.5-10000.0)/1737400.0*moon_relief_gain-moon_name_cut(n);
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
