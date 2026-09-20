shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// Opaque flesh lids must stay in the opaque pipeline for native SSS.
#include "res://shaders/dream_eyelid_surface.gdshaderinc"
