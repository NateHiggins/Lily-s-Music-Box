shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// Solid tissue, enclosed organs, and legacy presentation.
#include "res://shaders/dream_critter_body.gdshaderinc"
