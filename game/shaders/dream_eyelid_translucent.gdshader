shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
#define DREAM_TRANSLUCENT_LID
#include "res://shaders/dream_eyelid_surface.gdshaderinc"
