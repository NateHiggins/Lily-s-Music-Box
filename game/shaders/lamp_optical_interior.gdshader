shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 half_extent = vec3(0.25);
uniform float extinction_per_m = 2.8;
uniform vec3 scattering_albedo = vec3(0.85);
uniform float phase_anisotropy : hint_range(-0.7,0.7) = 0.35;
varying vec3 local_surface;
varying vec3 local_camera;
varying vec3 volume_origin;
varying vec3 volume_x;
varying vec3 volume_y;
varying vec3 volume_z;
vec3 interior_world(vec3 p) {
 return volume_origin+volume_x*p.x+volume_y*p.y+volume_z*p.z;
}
void vertex() {
 local_surface=VERTEX;
 local_camera=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
 volume_origin=MODEL_MATRIX[3].xyz;
 volume_x=MODEL_MATRIX[0].xyz;
 volume_y=MODEL_MATRIX[1].xyz;
 volume_z=MODEL_MATRIX[2].xyz;
}
void fragment() {
 vec3 ray=normalize(local_surface-local_camera);
 vec3 safe_ray=mix(vec3(0.000001),ray,greaterThan(abs(ray),vec3(0.000001)));
 vec3 a=(-half_extent-local_camera)/safe_ray;
 vec3 b=(half_extent-local_camera)/safe_ray;
 vec3 lo=min(a,b),hi=max(a,b);
 float enter=max(0.0,max(lo.x,max(lo.y,lo.z)));
 float leave=min(hi.x,min(hi.y,hi.z));
 vec3 world_ray=volume_x*ray.x+volume_y*ray.y+volume_z*ray.z;
 float world_scale=length(world_ray);
 float depth=texture(scene_depth,SCREEN_UV).r;
 if(depth>0.000001) {
  vec4 opaque=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
  leave=min(leave,length(opaque.xyz/opaque.w)/max(world_scale,0.000001));
 }
 float step_local=max(leave-enter,0.0)/24.0;
 float segment_t=exp(-max(extinction_per_m,0.0)*step_local*world_scale);
 float eye_t=1.0;
 vec3 integrated=vec3(0.0);
 vec3 lamp_position=inverse(lamp_world_to_local)[3].xyz;
 for(int i=0;i<24;i++) {
  vec3 point=interior_world(local_camera+ray*(enter+(float(i)+0.5)*step_local));
  LampOpticalSample optical=sample_lamp_optics(point);
  float cosine=dot(normalize(point-lamp_position),-normalize(world_ray));
  float g=phase_anisotropy;
  float phase=(1.0-g*g)/(4.0*PI*pow(max(1.0+g*g-2.0*g*cosine,0.01),1.5));
  integrated+=eye_t*(1.0-segment_t)*clamp(scattering_albedo,vec3(0.0),vec3(1.0))*optical.radiance*phase;
  eye_t*=segment_t;
 }
 // Ordinary alpha composition transmits the already-rendered internal
 // geometry. The depth limit above prevents scattering behind that geometry.
 ALPHA=1.0-eye_t;
 ALBEDO=integrated/max(ALPHA,0.00001);
 EMISSION=vec3(0.0);
}
