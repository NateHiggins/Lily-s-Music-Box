uniform float organ_time = 0.0;
uniform float limb_phase = 0.0;
uniform float growth = 1.0;
uniform float retreat = 0.0;
uniform float alarm = -1.0;
uniform vec3 reach_offset=vec3(0.0);
uniform float balance_grain=0.0;
uniform float lamp_rate=0.0;
uniform float search_drive=0.0;
uniform float panic_age=-1.0;
varying vec3 optical_world;
varying vec3 organ_local;
varying float organ_height;
// glTF +Z (Blender) becomes +Y. All organ coordinates are baked alike.
vec3 gang_deform(vec3 p, float dense, mat4 model_world) {
 float t=clamp(p.y/.70,0.0,1.0);
 float moving=sin(3.14159265*t);
 float bend=sin(organ_time*1.25+limb_phase+t*4.0)*.018*moving;
 float contraction=1.0+.055*sin(t*16.0-organ_time*2.0+limb_phase)*moving;
 // Read the instantaneous shared field at the common centreline, so every
 // internal depth band receives the same deformation rather than sliding.
 vec3 centre_world=(model_world*vec4(0.0,p.y,0.0,1.0)).xyz;
 LampOpticalSample light_sample=sample_lamp_optics(centre_world);
 float stimulus=clamp(length(light_sample.radiance)*120.0*light_sample.visibility,0.0,1.0)/(1.0+abs(lamp_rate)*.01);
 vec2 away=vec2(0.0);
 if(lamp_optical_bound && lamp_volume_shape.w>.5){
  vec3 lamp_world=inverse(lamp_world_to_local)[3].xyz;
  vec3 lamp_local=(inverse(model_world)*vec4(lamp_world,1.0)).xyz;
  away=normalize(vec2(-lamp_local.x,-lamp_local.z)+vec2(.00001));
 }
 p.xz*=contraction;
 float torsion=.04*moving*sin(organ_time*.6+limb_phase+t*2.0);
 p.xz=mat2(vec2(cos(torsion),-sin(torsion)),vec2(sin(torsion),cos(torsion)))*p.xz;
 p.xz+=away*stimulus*.022*moving;
 p.x+=bend;
 p.y/=contraction*contraction;
 float withdrawn=smoothstep(1.0-t,1.0-t+.22,retreat*(1.22+dense*.25));
 if(retreat<.001)withdrawn=0.0;
 p.xz*=mix(1.0,.12,withdrawn);
 p.y*=growth*(1.0-withdrawn);
 p.y-=withdrawn*.045;
 p+=reach_offset*t*t*(1.0-withdrawn)*growth;
 // All tissue layers share these waves. Fixed endpoints keep the represented
 // distal pad aligned while the middle curls, knots and recoils underneath it.
 float arch=sin(3.14159265*t);
 vec2 searching=vec2(sin(organ_time*3.7+limb_phase*2.1+t*7.0),cos(organ_time*2.3-limb_phase+t*5.0));
 p.xz+=searching*.026*arch*arch*search_drive*growth*(1.0-withdrawn);
 if(panic_age>=0.0){
  float onset=smoothstep(limb_phase*.012,limb_phase*.012+.07,panic_age);
  float struggle=onset*(1.0-smoothstep(2.6,4.6,panic_age));
  float lash=sin(panic_age*23.0-limb_phase*1.7-t*9.0);
  p.xz+=vec2(lash,cos(panic_age*17.0+limb_phase-t*8.0))*.075*arch*arch*struggle*(1.0-withdrawn);
  p.y-=.065*arch*arch*struggle*(.65+.35*lash)*(1.0-withdrawn);
 }
 // The statolith settles against the downward side of the bent chamber.
 float slope=(.018/.70)*(4.0*cos(organ_time*1.25+limb_phase+t*4.0)*moving+3.14159265*sin(organ_time*1.25+limb_phase+t*4.0)*cos(3.14159265*t));
 p.x+=balance_grain*clamp(-.009*slope,-.003,.003)*(1.0-withdrawn);
 p.y+=balance_grain*.0045*slope*slope*(1.0-withdrawn);
 return p;
}
