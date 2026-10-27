// Emissive astronomical projections inside the existing sky submission. City
// depth and the subsequent cloud composite occlude these; no foreground quads.
uniform vec4 skywatch_planets[5]; // horizon direction XYZ; artistic radiance W
uniform vec3 skywatch_planet_suns[5]; // planet-to-Sun vectors in the same horizon basis
uniform float skywatch_seconds = 0.0;

vec3 skywatch_planet_light(vec3 ray, vec3 sun) {
    vec3 result=vec3(0.0);
    float dusk=1.0-smoothstep(-.12,.025,sun.y);
    for(int i=0;i<5;i++) {
        vec4 state=skywatch_planets[i];
        if(state.w<=0.0 || state.y<-.02) continue;
        vec3 center=normalize(state.xyz);
        // Deliberately enlarged discs, with Jupiter the dominant outer planet.
        float radius=i==3 ? .0028 : (i==4 ? .0020 : .0016);
        vec3 right=normalize(cross(abs(center.y)>.96 ? vec3(1,0,0) : vec3(0,1,0),center));
        vec3 up=normalize(cross(center,right));
        vec2 p=vec2(dot(ray,right),dot(ray,up))/radius;
        if(dot(ray,center)<.9998) continue;
        float r=length(p);
        float aa=max(fwidth(r),.008);
        float disc=1.0-smoothstep(1.0-aa,1.0+aa,r);
        vec3 pigment=vec3(.65,.76,.85);
        if(i==1) pigment=vec3(.80,1.12,1.38);
        if(i==2) pigment=vec3(1.12,.25,.065);
        if(i==3) {
            float shear=.016*sin(p.x*7.0);
            float belts=exp(-pow((p.y-.26+shear)/.085,2.0))+exp(-pow((p.y+.26+shear)/.11,2.0));
            pigment=mix(vec3(.80,.66,.45),vec3(.40,.19,.075),clamp(belts*.65,0.0,1.0));
            pigment*=.96+.04*sin(p.y*37.0+shear*4.0);
        }
        if(i==4) pigment=vec3(.96,.81,.36);
        float z=sqrt(max(0.0,1.0-r*r));
        vec3 n=right*p.x+up*p.y-center*z;
        float lit=smoothstep(-.04,.05,dot(n,normalize(skywatch_planet_suns[i])));
        float edge=pow(max(0.0,z),.35);
        float ring=0.0;
        if(i==4) {
            vec2 tilted=mat2(vec2(.94,-.342),vec2(.342,.94))*p;
            float ellipse=length(tilted/vec2(2.1,.72));
            ring=exp(-pow((ellipse-.83)/.11,2.0))*.48;
            ring*=1.0-disc*.8;
        }
        float shimmer=1.0+mix(.16,.012,smoothstep(.02,.65,center.y))*
            sin(skywatch_seconds*17.0+float(i)*2.3)*sin(skywatch_seconds*29.1+float(i));
        float horizon=smoothstep(-.01,.09,center.y);
        float halo=exp(-r*r*.8)*.12;
        vec3 glow=i==3 ? vec3(.80,.66,.45) : pigment;
        result+=(pigment*disc*(.04+.96*lit)*edge+glow*(ring+halo))*state.w*dusk*horizon*shimmer;
    }
    return result;
}
