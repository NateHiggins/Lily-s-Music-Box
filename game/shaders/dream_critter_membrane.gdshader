shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// One shared thin-membrane pass per controller; never one draw per animal.
#define DREAM_CRITTER_MEMBRANE
#include "res://shaders/dream_critter_body.gdshaderinc"
