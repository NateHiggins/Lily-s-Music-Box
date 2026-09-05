shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform mat4 volume_to_world;
uniform vec3 half_extent=vec3(0.29,0.30,0.225);
uniform float absorption=2.0;
uniform float thickness=0.08;
varying vec3 local_surface;
varying vec3 local_camera;
void vertex(){
 local_surface=VERTEX;
 local_camera=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
}
void fragment(){
 vec3 ray=normalize(local_surface-local_camera);
 vec3 inv=1.0/mix(vec3(1e-7),ray,greaterThan(abs(ray),vec3(1e-7)));
 vec3 a=(-half_extent-local_camera)*inv,b=(half_extent-local_camera)*inv;
 vec3 mn=min(a,b),mx=max(a,b);
 float enter=max(0.0,max(mn.x,max(mn.y,mn.z)));
 float leave=min(mx.x,min(mx.y,mx.z));
 float step_length=max(0.0,leave-enter)/24.0;
 float extinction=absorption*(0.5+thickness/0.08);
 float segment_t=exp(-extinction*step_length);
 float eye_t=1.0;
 vec3 integrated=vec3(0.0);
 for(int i=0;i<24;i++){
  vec3 local_point=local_camera+ray*(enter+(float(i)+0.5)*step_length);
  vec3 world=(volume_to_world*vec4(local_point,1.0)).xyz;
  LampOpticalSample s=sample_lamp_optics(world);
  // Incident field already includes lamp-to-sample occlusion. Beer attenuation
  // below is the separate sample-to-eye segment, never ecological history.
  vec3 incident=normalize(world-inverse(lamp_world_to_local)[3].xyz);
  vec3 eye_direction=normalize((volume_to_world*vec4(-ray,0.0)).xyz);
  float phase=0.05+0.15*pow(max(dot(incident,eye_direction),0.0),6.0);
  integrated+=eye_t*(1.0-segment_t)*s.radiance*phase;
  eye_t*=segment_t;
 }
 ALPHA=1.0-eye_t;
 ALPHA_HASH_SCALE=1.0;
 ALBEDO=integrated/max(ALPHA,0.0001);
}
