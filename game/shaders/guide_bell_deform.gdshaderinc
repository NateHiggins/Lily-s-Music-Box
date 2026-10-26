uniform float organ_time=0.0;
uniform float seed_phase=0.0;
uniform float growth=1.0;
uniform float wilt=0.0;
uniform float retract=0.0;
uniform float maturity=1.0;
uniform float cilia=0.0;
uniform float organ=0.0;
uniform float particulate=0.0;
uniform bool symbiont=false;
uniform float colony_alarm=0.0;
uniform vec3 route_direction=vec3(1.0,0.0,0.0);
varying vec3 optical_world;
varying float cell_height;
vec3 bell_normal(vec3 n,vec3 rest){
 if(symbiont)return n;
 vec2 direction=normalize(route_direction.xz+vec2(.00001));
 float tilt=.82*clamp((rest.y-.34)/.26,0.0,1.0)*(1.0-wilt);
 float along=dot(n.xz,direction);
 vec3 result=n;
 result.xz+=direction*(along*cos(tilt)+n.y*sin(tilt)-along);
 result.y=n.y*cos(tilt)-along*sin(tilt);
 return normalize(result);
}
vec3 bell_deform(vec3 p,mat4 model){
 if(symbiont){
  float ventral=1.0-smoothstep(-.06,.0,p.y);
  p.y+=sin(organ_time*17.0+p.x*48.0)*.012*ventral*(1.0-colony_alarm);
  p.y-=colony_alarm*.8;
  return p;
 }
 float h=max(0.0,p.y); float cell_angle=atan(p.z,p.x);
 p.y+=particulate*.009*sin(organ_time*1.4+seed_phase+h*20.0)*(1.0-wilt);
 p.x+=particulate*.004*cos(organ_time*1.4+seed_phase+h*20.0)*(1.0-wilt);
 float stalk=clamp((h-.02)/.34,0.0,1.0);
 float bell=clamp((h-.34)/.26,0.0,1.0);
 LampOpticalSample light=sample_lamp_optics((model*vec4(0.0,.45,0.0,1.0)).xyz);
 float alarm=clamp(length(light.radiance)*light.visibility*.12,0.0,.32)*(1.0-wilt);
 float coil=max(wilt,max(alarm,colony_alarm*.85));
 vec2 direction=normalize(route_direction.xz+vec2(.00001));
 // Fixed adhesive base; successive anatomy inherits one shared centreline.
 vec2 centre=direction*.10*stalk*stalk*(1.0-wilt);
 centre+=vec2(cos(stalk*18.85+seed_phase),sin(stalk*18.85+seed_phase))*.043*sin(stalk*1.5708)*coil;
 p.xz*=1.0-.65*wilt*bell;
 p.xz*=1.0+.045*sin(seed_phase*1.7)*bell;
 p.xz+=centre;
 p.y-=stalk*.24*coil+bell*.13*wilt;
 p.y+=.012*sin(cell_angle*5.0+organ_time*(1.0-wilt)*4.0)*bell*wilt;
 float tilt=.82*bell*(1.0-wilt);
 float along=dot(p.xz-centre,direction);
 float vertical=p.y-.34*(1.0-coil*.6);
 float turned=along*cos(tilt)+vertical*sin(tilt);
 p.xz+=direction*(turned-along);
 p.y=.34*(1.0-coil*.6)+vertical*cos(tilt)-along*sin(tilt);
 float forward_lip=smoothstep(-.04,.08,dot(p.xz-centre,direction));
 float coordinated=1.0-smoothstep(.05,.65,wilt);
 float wave=mix(sin(cell_angle*17.0+organ_time*3.0+seed_phase),sin(dot(p.xz,direction)*45.0-organ_time*9.0+seed_phase),coordinated);
 float cilia_live=(1.0-wilt)*(1.0-forward_lip*smoothstep(0.0,.3,wilt));
 p.xz+=direction*cilia*.009*wave*cilia_live;
 p.y-=organ*.035*wilt;
 float develop=smoothstep(.05,.85,growth);
 p.y*=mix(.025,1.0,develop)*(1.0-retract)*(1.0+.025*sin(seed_phase));
 p.xz*=mix(.18,1.0,smoothstep(.0,.5,growth))*(1.0-.94*retract);
 p.y-=retract*.035;
 return p;
}
