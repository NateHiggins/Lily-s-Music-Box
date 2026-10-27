shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 lamp_colour : source_color = vec4(1.0,.75,.43,1.0);
uniform float ice_level = 0.0;
uniform float lamp_level = 0.0;

void vertex() {
    // Cylindrical billboard: source and vertical axis stay in the world.
    // The same real lamp remains the foot when a mirror/telescope observes it.
    vec3 up=vec3(0.0,1.0,0.0);
    vec3 origin=MODEL_MATRIX[3].xyz;
    vec3 toward=CAMERA_POSITION_WORLD-origin;
    vec3 right=normalize(vec3(toward.z,0.0,-toward.x)+vec3(.00001,0.0,0.0));
    vec3 world=origin+right*VERTEX.x+up*VERTEX.y;
    POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
}
void fragment() {
    float height=1.0-UV.y;
    float core=exp(-pow((UV.x-.5)*7.0,2.0));
    float taper=exp(-height*3.8)*smoothstep(0.0,.035,height)*(1.0-smoothstep(.75,1.0,height));
    ALBEDO=lamp_colour.rgb;
    ALPHA=core*taper*ice_level*lamp_level*.6;
}
