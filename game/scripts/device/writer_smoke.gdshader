shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void vertex() {
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
        vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),
        vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),
        vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),
        MODEL_MATRIX[3]);
}
void fragment() {
    float radius=length(UV*2.0-1.0);
    float falloff=max(0.0,1.0-radius*radius);
    ALBEDO=COLOR.rgb;ALPHA=COLOR.a*falloff*falloff;
}
