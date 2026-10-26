// Included inside fragment(): finite organ tissue and transmissive shell passes.
if(micro_pc_only && distance(CAMERA_POSITION_WORLD,micro_pc_eye)>.03) discard;
float role=floor(v_region.r*10.0+.5);
#ifdef DREAM_CRITTER_MEMBRANE
ALPHA=1.0;
#endif
bool exterior=role<.5 || role>7.5;
bool fiber=role>5.5 && role<7.5;
bool mineral=role>5.5 && role<6.5;
if (((micro_diagnostic==1 || micro_diagnostic==5) && !exterior) || (micro_diagnostic==2 && exterior) || (micro_diagnostic==3 && !fiber)) discard;
vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
vec3 stock=(exterior || role>6.5) ? texture(micro_membrane_albedo,v_uv).rgb : (mineral ? texture(micro_mineral_albedo,v_uv).rgb : texture(micro_organ_albedo,v_uv).rgb);
// Euplotes retains the same mapped biological stocks with a cool cortical tint.
if(micro_species>6.5) stock*=exterior ? vec3(.68,.95,.86) : vec3(.58,.9,.66);
float rough=(exterior || role>6.5) ? texture(micro_membrane_roughness,v_uv).r : (mineral ? texture(micro_mineral_roughness,v_uv).r : texture(micro_organ_roughness,v_uv).r);
vec3 relief=((exterior || role>6.5) ? texture(micro_membrane_normal,v_uv).rgb : (mineral ? texture(micro_mineral_normal,v_uv).rgb : texture(micro_organ_normal,v_uv).rgb))*2.0-1.0;
// Reconstruct UV derivatives: the merged pose atlas intentionally has no tangent buffer.
vec3 qx=dFdx(v_world), qy=dFdy(v_world);
vec2 tx=dFdx(v_uv), ty=dFdy(v_uv);
float chart_orientation=tx.x*ty.y-tx.y*ty.x<0.0 ? -1.0 : 1.0;
vec3 udir=normalize((qx*ty.y-qy*tx.y)*chart_orientation+vec3(1e-8));
vec3 vdir=normalize((-qx*ty.x+qy*tx.x)*chart_orientation+vec3(1e-8));
wn=normalize(wn+udir*relief.x+vdir*relief.y);
vec3 eye=normalize(CAMERA_POSITION_WORLD-v_world);
vec3 lamp_position=inverse(lamp_world_to_local)[3].xyz;
vec3 light_dir=normalize(lamp_position-v_world);
vec3 local_eye=micro_direction(eye);
vec3 local_light=micro_direction(light_dir);
LampOpticalSample optical=sample_lamp_optics(v_world);
vec3 incoming=lamp_optical_bound ? optical.radiance : vec3(0.0);
vec3 entry_incoming=(lamp_optical_bound && optical.beam_depth>0.0) ? micro_entry_radiance(v_local,v_world,local_light) : vec3(0.0);
// A private lamp-revealed percept must not leave black opaque organ cutouts
// over the real room when the source is off or its beam is blocked.
if(micro_diagnostic==0 && length(incoming)+length(entry_incoming)<.00001) discard;
if(!exterior && role<6.5) incoming=entry_incoming;
float thickness=mix(.075,.012,clamp(v_region.g,0.0,1.0));
float facing=abs(dot(wn,eye));
float front=max(dot(wn,light_dir),0.0);
float back=max(dot(-wn,light_dir),0.0);
float fold=.5+.5*sin(v_local.z*38.0+sin(v_local.x*13.0));
float pore=clamp((rough-.25)*18.0+.45,0.0,1.0);
vec3 half_vector=normalize(eye+light_dir);
float wet=micro_wet_reflection(wn,eye,light_dir,rough);
wet*=smoothstep(.42,.73,pore);
vec3 tissue=stock;
vec3 transmission=exp(-vec3(7.0,13.0,24.0)*thickness/max(.18,abs(dot(wn,light_dir))));
vec3 response=vec3(0.0);
vec3 transmitted_light=vec3(0.0);
vec3 transport_debug=vec3(0.0);
if(exterior) {
 vec3 pearl=mix(vec3(.22,.32,.34),vec3(.32,.25,.37),fold)*pow(1.0-facing,4.0);
 // No diffuse floor on the unlit side: it would project the field's hard
 // organ shadow onto the outer film and defeat volumetric transmission.
 response=tissue*(1.2*front)+pearl*front*.12;
 transmitted_light=entry_incoming*micro_transport(v_local,local_light,micro_exit(v_local,local_light))*transmission*back*.5;
 if(role>7.5) { response=vec3(wet)+pearl*.025; transmitted_light=vec3(0.0); }
 #ifdef DREAM_CRITTER_MEMBRANE
 // Beer-Lambert optical depth, not an arbitrary visibility window.
 ALPHA=clamp(1.0-exp(-thickness*(1.4+fold*1.0)/max(.22,facing)),.025,.38);
 if(role<.5 && micro_diagnostic!=1) {
  // Bounded cytoplasm integration stops at real opaque scene depth. The
  // density stays in organism coordinates; the lamp samples stay world-space.
  vec3 ray=-local_eye;
  vec3 world_step=micro_side*ray.x*micro_dimensions.x+micro_up*ray.y*micro_dimensions.y+micro_forward*ray.z*micro_dimensions.z;
  float scale=length(world_step);
  float leave=micro_exit(v_local,ray);
  // Finite scattering footprint: average optical path lengths, not nonlinear
  // depth values. Foreground remains rejected by the scene depth test.
  float fluid_path=0.0;
  for(int tap=0;tap<16;tap++) {
   float angle=float(tap)*2.39996323;
   vec2 offset=vec2(cos(angle),sin(angle))*sqrt((float(tap)+.5)/16.0)*.009;
   vec2 uv=clamp(SCREEN_UV+offset,vec2(.001),vec2(.999));
   float scene_z=texture(micro_scene_depth,uv).r;
   float path=leave;
   if(scene_z>0.000001) {
    vec4 opaque=INV_PROJECTION_MATRIX*vec4(uv*2.0-1.0,scene_z,1.0);
    path=min(path,max(0.0,length(opaque.xyz/opaque.w)-length(VERTEX))/max(scale,.00001));
   }
   fluid_path+=path/16.0;
  }
  leave=fluid_path;
  float step_length=leave/12.0;
  float eye_t=1.0;
  vec3 volume=vec3(0.0);
  for(int i=0;i<12;i++) {
   float t=(float(i)+.5)*step_length;
   vec3 local_p=v_local+ray*t;
   vec3 point=v_world+world_step*t;
   float segment=exp(-micro_density(local_p)*step_length*.85);
   LampOpticalSample sample_at=sample_lamp_optics(point);
   float cosine=dot(normalize(point-lamp_position),eye);
   float phase=.18/pow(max(.1,1.28-1.05*cosine),1.5);
   vec3 local_lamp=micro_direction(lamp_position-point);
   vec3 incident=sample_at.beam_depth>0.0 ? micro_entry_radiance(local_p,point,local_lamp) : vec3(0.0);
   incident*=micro_transport(local_p,local_lamp,micro_exit(local_p,local_lamp));
   volume+=eye_t*(1.0-segment)*incident*vec3(.28,.31,.30)*phase;
   eye_t*=segment;
  }
  float surface_alpha=ALPHA;
  transport_debug=vec3(leave,eye_t,surface_alpha);
  ALPHA=1.0-(1.0-surface_alpha)*eye_t;
  response*=surface_alpha/max(ALPHA,.001);
  transmitted_light=(transmitted_light*surface_alpha+volume*(1.0-surface_alpha))/max(ALPHA,.001);
 }
 if(role>7.5) ALPHA=.18+.4*pow(1.0-facing,4.0);
 #endif
} else {
 float eye_depth=micro_exit(v_local,local_eye);
 float lamp_depth=micro_exit(v_local,local_light);
 vec3 filter_light=micro_transport(v_local,local_light,lamp_depth);
 vec3 filter_eye=micro_transport(v_local,local_eye,eye_depth);
 float density=micro_density(v_local);
 // Temporal instability changes internal contrast, without changing identity
 // or randomly blinking a surface. Physical radiance remains field-owned.
 float clarity=mix(.68,1.0,optical.temporal_stability);
 filter_eye=mix(vec3(dot(filter_eye,vec3(.333))),filter_eye,clarity);
 if(role<1.5) tissue=stock*.35; // dense irregular nucleus
 else if(role<2.5) tissue=stock; // low density vacuoles
 else if(role<3.5) tissue=stock*.85; // elastic sac
 else if(role<4.5) tissue=stock*.65; // folded gut
 else tissue=stock*.8;
 response=tissue*(.16+.7*front+1.0*back)*filter_light*filter_eye;
 response+=vec3(.16,.13,.09)*(1.0-filter_eye)*(.15+.4*back)*density;
 if(role>5.5 && role<6.5) {
  // Tangent-direction reflection: no emission and no constant gold floor.
  vec3 tangent=normalize(udir-wn*dot(udir,wn));
  vec3 across=cross(wn,tangent);
  float ax=mix(.025,.07,optical.temporal_stability)*clamp(rough/.22,.5,2.0);
  float ay=max(.08,rough*1.36);
  float hx=dot(half_vector,tangent)/ax,hy=dot(half_vector,across)/ay,hz=max(dot(wn,half_vector),0.0);
  float distribution=1.0/(PI*ax*ay*pow(max(hx*hx+hy*hy+hz*hz,.0001),2.0));
  float glint=distribution*front/(4.0*max(.15,facing));
  vec3 mineral_color=mix(vec3(dot(stock,vec3(.333))),stock,exp(-eye_depth*5.0));
  response=mineral_color*glint*filter_light*filter_eye;
 } else if(role>6.5) {
  response=vec3(.46,.39,.28)*(front*.18+back*.65+wet)*filter_light;
 }
}
ALBEDO=max(vec3(0.0),incoming*response+transmitted_light);
#ifdef MICRO_ORGAN_ALPHA
// A suspended organ has finite optical depth. Its grazing boundary thins
// continuously instead of punching an opaque silhouette into the fluid.
float organ_tau=role<1.5 ? 2.6 : (role<3.5 ? .8 : 1.8);
ALPHA=fiber ? 1.0 : 1.0-exp(-organ_tau*pow(facing,1.4));
#endif
#ifdef DREAM_CRITTER_MEMBRANE
if(role<.5 && micro_diagnostic!=1 && micro_diagnostic!=5) {
 // Composite over the actual translucent organ pass. Surface reflection is
 // independent of Beer opacity; compensate for the framebuffer blend once.
 ALBEDO+=incoming*vec3(wet)/max(ALPHA,.001);
}
#endif
EMISSION=vec3(0.0);
#ifdef MICRO_VACUOLE
// Only the pocket wall reflects here. A screen sample contains opaque room
// geometry, not earlier transparent organs, so painting it at high opacity
// would punch a false dark window through the animal.
ALBEDO=incoming*(vec3(wet)+response*.15);
ALPHA=.025+.12*pow(1.0-facing,3.0);
#endif
ALPHA*=1.0-.92*micro_meal.y;
if(micro_diagnostic==4) ALBEDO=vec3(optical.visibility,optical.transmittance,clamp(optical.beam_depth/lamp_physical_range,0.0,1.0))*min(length(incoming),1.0);
if(micro_diagnostic==5) {
 ALBEDO=vec3(.4);
 #ifdef DREAM_CRITTER_MEMBRANE
 ALPHA=1.0;
 #endif
}
#ifdef DREAM_CRITTER_MEMBRANE
if(micro_diagnostic==1 && exterior) ALPHA=1.0;
if(micro_diagnostic==6) { ALBEDO=transport_debug; ALPHA=1.0; }
if(micro_diagnostic==8) { ALBEDO=vec3(front,facing,clamp(wet,0.0,1.0)); ALPHA=1.0; }
if(micro_diagnostic==9) { ALBEDO=vec3(length(incoming),length(entry_incoming),rough); ALPHA=1.0; }
#endif
