shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, blend_mix;
#define DREAM_CORNEA_PASS
#include "res://shaders/dream_eye_surface.gdshaderinc"
