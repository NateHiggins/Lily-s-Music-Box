uniform sampler2D cytoplasm_scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float cytoplasm_extinction_per_m = 6.0;
varying vec3 cloud_origin;
varying vec3 cloud_x;
varying vec3 cloud_y;
varying vec3 cloud_z;
varying vec3 cloud_surface;
varying vec3 cloud_camera;
// Same affine posture as the existing Tessellate wine body. The original
// vertex program remains the sole writer of VERTEX; these axes locate optical
// samples inside its authored ellipsoid and follow the eight existing stages.
vec3 tessellate_pose(vec3 p,float stage,float t,float phase,float activity) {
 float folded=1.0-step(0.5,abs(stage));
 float bud=1.0-step(0.5,abs(stage-1.0));
 float juvenile=1.0-step(0.5,abs(stage-2.0));
 float exchange=1.0-step(0.5,abs(stage-4.0));
 float senescent=1.0-step(0.5,abs(stage-5.0));
 float shed=1.0-step(0.5,abs(stage-6.0));
 float stain=1.0-step(0.5,abs(stage-7.0));
 float slow=sin(t*0.9+phase);
 float gait=sin(t*6.28318530718*gait_hz+phase);
 p.y+=gait*gait_amount*activity*(1.0+1.15*juvenile-0.25*senescent-0.55*shed);
 p.xz*=(1.0+gait*0.06*activity)*(1.0-0.16*folded)*(1.0+(0.14+0.025*slow)*bud);
 p.x*=1.0+0.11*senescent*slow;
 p.z*=1.0-0.11*senescent*slow;
 p.x*=1.0+0.16*juvenile;
 p.z*=1.0-0.14*juvenile;
 p.x*=1.0-0.12*exchange;
 p.z*=1.0+0.18*exchange;
 p.y*=1.0-0.18*shed;
 p.z+=0.14*exchange*(0.55+0.45*slow)*p.y;
 p.xz+=p.y*0.16*shed*vec2(0.85,-0.55);
 p.y=mix(p.y,p.y*0.86,stain);
 return p;
}
vec4 tessellate_interior(vec2 screen_uv,mat4 inv_projection) {
 vec3 ray=normalize(cloud_surface-cloud_camera);
 float b=dot(cloud_camera,ray);
 float discriminant=b*b-dot(cloud_camera,cloud_camera)+1.0;
 if(discriminant<=0.0)return vec4(0.0);
 float enter=max(max(0.0,-b-sqrt(discriminant)),length(cloud_surface-cloud_camera));
 float leave=-b+sqrt(discriminant);
 vec3 world_ray=cloud_x*ray.x+cloud_y*ray.y+cloud_z*ray.z;
 float world_scale=length(world_ray);
 float depth=texture(cytoplasm_scene_depth,screen_uv).r;
 if(depth>0.000001) {
  vec4 opaque=inv_projection*vec4(screen_uv*2.0-1.0,depth,1.0);
  leave=min(leave,length(opaque.xyz/opaque.w)/max(world_scale,0.000001));
 }
 float step_local=max(leave-enter,0.0)/24.0;
 float sigma=max(cytoplasm_extinction_per_m,0.0);
 if(lamp_volume_shape.w<0.5)return vec4(0.0,0.0,0.0,1.0-exp(-sigma*max(leave-enter,0.0)*world_scale));
 float segment_t=exp(-sigma*step_local*world_scale);
 float eye_t=1.0;
 vec3 integrated=vec3(0.0);
 vec3 lamp_position=inverse(lamp_world_to_local)[3].xyz;
 mat4 to_local=inverse(mat4(vec4(cloud_x,0.0),vec4(cloud_y,0.0),vec4(cloud_z,0.0),vec4(cloud_origin,1.0)));
 vec3 lamp_local=(to_local*vec4(lamp_position,1.0)).xyz;
 for(int i=0;i<24;i++) {
  vec3 local=cloud_camera+ray*(enter+(float(i)+0.5)*step_local);
  vec3 point=cloud_origin+cloud_x*local.x+cloud_y*local.y+cloud_z*local.z;
  LampOpticalSample optical=sample_lamp_optics(point);
  vec3 toward_lamp=normalize(lamp_local-local);
  float projected=dot(local,toward_lamp);
  float source_path=max(0.0,-projected+sqrt(max(0.0,projected*projected-dot(local,local)+1.0)));
  source_path*=length(cloud_x*toward_lamp.x+cloud_y*toward_lamp.y+cloud_z*toward_lamp.z);
  float cosine=dot(normalize(point-lamp_position),-normalize(world_ray));
  float phase=(1.0-0.35*0.35)/(4.0*PI*pow(max(1.0+0.35*0.35-0.7*cosine,0.01),1.5));
  integrated+=eye_t*(1.0-segment_t)*vec3(0.60,0.28,0.55)*optical.radiance*exp(-sigma*source_path)*phase;
  eye_t*=segment_t;
 }
 return vec4(integrated,1.0-eye_t);
}
