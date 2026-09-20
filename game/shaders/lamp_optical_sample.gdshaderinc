// One camera-independent lamp-to-froxel mapping for all material participants.
uniform bool lamp_optical_bound = false;
uniform sampler3D lamp_radiance : filter_linear, repeat_disable;
uniform sampler3D lamp_optics : filter_linear, repeat_disable;
uniform sampler3D lamp_near_radiance : filter_linear, repeat_disable;
uniform sampler3D lamp_near_optics : filter_linear, repeat_disable;
uniform vec4 lamp_near_shape=vec4(0.0);
// Diagnostic timing control: same material transfer, bypass texture sampling only.
uniform bool optical_benchmark_bypass=false;
uniform mat4 lamp_world_to_local;
uniform float lamp_physical_range=9.0;
uniform vec4 lamp_volume_shape = vec4(0.05,8.0,0.7,0.0); // near, far, tan(outer), enabled
struct LampOpticalSample {
 vec3 radiance;
 float visibility;
 float transmittance;
 float beam_depth;
 float scattering;
 float temporal_stability;
};
LampOpticalSample sample_lamp_optics(vec3 world_position){
 LampOpticalSample s=LampOpticalSample(vec3(0.0),0.0,0.0,0.0,0.0,1.0);
 vec3 p=(lamp_world_to_local*vec4(world_position,1.0)).xyz;
 float depth=-p.z;
 if(lamp_volume_shape.w<0.5 || depth<lamp_volume_shape.x || depth>lamp_volume_shape.y)return s;
 float distance_to_lamp=length(p);
 if(distance_to_lamp>lamp_physical_range || depth/max(distance_to_lamp,1e-7)<inversesqrt(1.0+lamp_volume_shape.z*lamp_volume_shape.z))return s;
 vec2 xy=p.xy/(depth*lamp_volume_shape.z)*0.5+0.5;
 if(any(lessThan(xy,vec2(0.0))) || any(greaterThan(xy,vec2(1.0))))return s;
 float z=sqrt((depth-lamp_volume_shape.x)/(lamp_volume_shape.y-lamp_volume_shape.x));
 if(optical_benchmark_bypass)return LampOpticalSample(vec3(0.2),1.0,1.0,depth,0.02,1.0);
 vec4 r=texture(lamp_radiance,vec3(xy,z));
 vec4 o=texture(lamp_optics,vec3(xy,z));
 if(lamp_near_shape.w>0.5 && depth<lamp_near_shape.y){
  float nz=sqrt((depth-lamp_near_shape.x)/(lamp_near_shape.y-lamp_near_shape.x));
  float blend=1.0-smoothstep(lamp_near_shape.y*0.8,lamp_near_shape.y,depth);
  r=mix(r,texture(lamp_near_radiance,vec3(xy,nz)),blend);
  o=mix(o,texture(lamp_near_optics,vec3(xy,nz)),blend);
 }
 s.radiance=r.rgb;s.transmittance=r.a;s.visibility=o.r;
 s.beam_depth=depth;s.scattering=o.b;s.temporal_stability=o.a;
 return s;
}
