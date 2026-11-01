// Bounded stroke coordinates avoid float precision loss late in the campaign.
uniform float electrical_seed = 0.0;
uniform float electrical_age = 0.0;
// Shared scheduled phenomena; extracted without arithmetic changes from main2b7bf3db.
// Spectacle (data/weather/phenomena.json via WeatherManager): one intensity
// and one bearing per phenomenon slot. Zero costs a uniform branch, no node.
uniform float spectacle[42];
uniform float spectacle_bearing[42];
uniform float emergence_progress = 0.0;
uniform float spectacle_time = 0.0;
// V2 derives these from the existing weather/observer owner. The retained
// seasonal renderer keeps its original presentation when this switch is off.
uniform bool skywatch_extended_optics = false;
uniform vec3 skywatch_ice_complex = vec3(0.0); // ring, dogs, pillar
const int S_MAMMATUS = 0;
const int S_SHELF = 1;
const int S_WALL = 2;
const int S_LENTICULAR = 3;
const int S_MORNING_GLORY = 4;
const int S_VIRGA = 5;
const int S_MICROBURST = 6;
const int S_HABOOB = 7;
const int S_ASPERITAS = 8;
const int S_KELVIN_HELMHOLTZ = 9;
const int S_FALLSTREAK = 10;
const int S_SUPERCELL = 11;
const int S_ANVIL = 12;
const int S_OVERSHOOT = 13;
const int S_PILEUS = 14;
const int S_PYROCB = 15;
const int S_TORNADO = 16;
const int S_WATERSPOUT = 17;
const int S_NACREOUS = 18;
const int S_NOCTILUCENT = 19;
const int S_AURORA = 20;
const int S_STEVE = 21;
const int S_CRAWLER = 22;
const int S_SPRITE = 23;
const int S_BLUE_JET = 24;
const int S_GIGANTIC_JET = 25;
const int S_ELVES = 26;
const int S_PLUME_LIGHTNING = 28;
const int S_RAINBOW = 29;
const int S_HALO = 30;
const int S_SUN_DOGS = 31;
const int S_CHA = 32;
const int S_CZA = 33;
const int S_PILLARS = 34;
const int S_CREPUSCULAR = 35;
const int S_ANTICREPUSCULAR = 36;
const int S_GLORY = 37;
const int S_IRIDESCENCE = 38;
const int S_GREEN_FLASH = 39;
const int S_FATA_MORGANA = 40;
const int S_EMERGENCE = 41;


// --- Spectacle helpers ---------------------------------------------------------
vec3 bearing_axis(int s) {
    float a=spectacle_bearing[s];
    return vec3(sin(a),0.0,-cos(a));
}
float hash12(vec2 p) {
    vec3 p3=fract(vec3(p.xyx)*.1031);
    p3+=dot(p3,p3.yzx+33.33);
    return fract((p3.x+p3.y)*p3.z);
}
float vnoise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash12(i),hash12(i+vec2(1.0,0.0)),f.x),
        mix(hash12(i+vec2(0.0,1.0)),hash12(i+vec2(1.0,1.0)),f.x),f.y);
}
float fbm2(vec2 p) {
    float v=0.0; float a=.5;
    for (int i=0;i<4;i++) { v+=a*vnoise(p); p=p*2.03+vec2(17.1,9.2); a*=.5; }
    return v;
}
// Hue ramp, 0 red .. 1 violet: painterly saturated spectrum for the optics.
vec3 spectral(float t) {
    float h=clamp(t,0.0,1.0)*.78;
    return clamp(abs(fract(vec3(h)+vec3(1.0,2.0/3.0,1.0/3.0))*6.0-3.0)-1.0,0.0,1.0);
}
float azimuth_of(vec3 d) { return atan(d.x,-d.z); }
float wrap_pi(float a) { return mod(a+PI,2.0*PI)-PI; }
float angle_between(vec3 a,vec3 b) { return acos(clamp(dot(normalize(a),normalize(b)),-1.0,1.0)); }
float elevation_degrees(vec3 d) { return degrees(asin(clamp(d.y,-1.0,1.0))); }
float sun_elevation_degrees() { return elevation_degrees(normalize(sun_direction)); }
// Cellular edge distance (F2-F1): a branching network once domain-warped.
float voronoi_edge(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p);
    float f1=8.0; float f2=8.0;
    for (int y=-1;y<=1;y++) {
        for (int x=-1;x<=1;x++) {
            vec2 g=vec2(float(x),float(y));
            vec2 o=vec2(hash12(i+g),hash12(i+g+19.7));
            float d=length(g+o-f);
            if (d<f1) { f2=f1; f1=d; } else if (d<f2) { f2=d; }
        }
    }
    return f2-f1;
}
// Local frame of a sculpted phenomenon: x along the horizon, y up, z away.
vec3 object_frame(vec3 p,int s,float distance_km) {
    vec3 f=bearing_axis(s);
    vec3 r=vec3(-f.z,0.0,f.x);
    vec3 q=p-f*distance_km;
    return vec3(dot(q,r),q.y,dot(q,f));
}

// --- Deck sculpting (inside the existing cloud slab) ---------------------------
float mammatus(vec3 p) {
    // Warp the pouch lattice with the already sampled underside noise so it
    // does not read as straight rows of ceiling tiles at a grazing angle.
    vec2 field=textureLod(cloud_noise,(p-wind_offset)*.75,0.0).rg;
    float cell_size=.30;
    vec2 g=(p.xz-wind_offset.xz*.4)/cell_size+(field-.5)*.8;
    vec2 cell=floor(g); vec2 f=fract(g)-.5;
    float j=hash12(cell);
    vec3 q=vec3(f.x*cell_size,p.y-(1.18-.05*j),f.y*cell_size);
    float pouch=length(q*vec3(1.0,.82,1.0))-.125*(.78+.44*j);
    float n=field.r;
    float underside=(1.30-(1.0-n)*.16)-p.y;
    float sdf=soft_union(pouch,underside,.07);
    return 1.0-smoothstep(-.035,.03,sdf);
}
float asperitas_shift(vec3 p) {
    // A chaotic sea surface on the cloud base: crossed swells warped by noise.
    vec2 w=p.xz-wind_offset.xz*.2;
    float n=textureLod(cloud_noise,vec3(w*.35,spectacle_time*.002),0.0).r;
    return sin(w.x*1.9+n*5.0+spectacle_time*.03)*cos(w.y*1.4-n*4.0)*.30;
}
float virga(vec3 p) {
    if (p.y>1.28 || p.y<.35) return 0.0;
    // Streaks stretched downward from the parent cloud, sheared by the wind,
    // evaporating before they reach the ground.
    float shear=(1.25-p.y)*.6;
    vec3 base=vec3(p.x+shear,1.32,p.z)-wind_offset;
    float parent=smoothstep(.45,.62,textureLod(cloud_noise,base*mix(.30,.16,season_weights.z),0.0).r);
    float streak=textureLod(cloud_noise,vec3((p.x+shear-wind_offset.x)*1.8,
        p.y*.22+spectacle_time*.004,(p.z-wind_offset.z)*1.8),0.0).r;
    return parent*smoothstep(.42,.75,streak)*smoothstep(.35,1.05,p.y)*.35;
}
float fallstreak(vec3 p,out float streak) {
    // A round hole punched in the supercooled deck, ice falling from its middle.
    vec2 centre=bearing_axis(S_FALLSTREAK).xz*5.5;
    float r=length(p.xz-centre);
    streak=0.0;
    if (r<.95 && p.y<1.45 && p.y>.55) {
        float n=textureLod(cloud_noise,vec3(p.x*1.4,p.y*.25,p.z*1.4),0.0).r;
        streak=(1.0-smoothstep(.2,.95,r))*smoothstep(.55,1.0,p.y)
            *(1.0-smoothstep(1.3,1.45,p.y))*smoothstep(.35,.7,n);
    }
    return smoothstep(1.0,1.6,r+(textureLod(cloud_noise,p*1.3,0.0).g-.5)*.35);
}

// --- Sculpted objects (their own bounded march) --------------------------------
float vortex(vec3 p,int s,inout vec3 albedo) {
    bool spout=s==S_WATERSPOUT;
    vec3 q=object_frame(p,s,spout?4.5:3.6);
    if (q.y<0.0 || q.y>1.32) return 0.0;
    float h=q.y/1.25;
    // The funnel snakes: its axis is a slow sine in height and time.
    q.x-=(spout?.06:.16)*sin(h*2.6+spectacle_time*.35)*h;
    q.z-=(spout?.04:.10)*cos(h*2.1+spectacle_time*.27)*h;
    float radius=mix(spout?.025:.05,spout?.30:.48,pow(h,2.4));
    float radial=length(q.xz);
    float angle=atan(q.z,q.x);
    float swirl=textureLod(cloud_noise,vec3(angle*.45+spectacle_time*.9-h*3.0,h*1.6,radial*2.0),0.0).r;
    float d=(1.0-smoothstep(radius*.55,radius*(1.05+.25*swirl),radial))*(.55+.6*swirl);
    if (!spout) {
        // Multiple vortices: a central cylinder and three orbiting suction cylinders.
        for (int i=0;i<3;i++) {
            float a=spectacle_time*2.4+float(i)*2.094+h*1.7;
            vec2 c=vec2(cos(a),sin(a))*(.16+.10*h);
            float sub=1.0-smoothstep(.022+.03*h,.05+.04*h,length(q.xz-c));
            d=max(d,sub*(1.0-smoothstep(.45,.75,h)));
        }
        float debris=(1.0-smoothstep(0.0,.13,q.y))*(1.0-smoothstep(.15,.42,radial))
            *textureLod(cloud_noise,q*6.0+vec3(spectacle_time*.5),0.0).g;
        d=max(d,debris*.9);
        albedo=mix(vec3(.30,.27,.24),vec3(.50,.51,.54),smoothstep(0.0,.5,h));
    } else {
        float spray=(1.0-smoothstep(0.0,.08,q.y))*(1.0-smoothstep(.05,.30,radial))
            *textureLod(cloud_noise,q*7.0+vec3(spectacle_time*.6),0.0).g;
        d=max(d,spray*.7);
        albedo=vec3(.78,.82,.86);
    }
    // The funnel lifts into its parent cloud base.
    return max(d,smoothstep(.9,1.0,h)*(1.0-smoothstep(.2,.7,radial))*.5);
}
float wall_cloud(vec3 p,inout vec3 albedo) {
    // A descending cylinder under the storm base, slowly turning, trailing scud.
    vec3 q=object_frame(p,S_WALL,4.5);
    float lowered=1.25-.45*clamp(spectacle[S_WALL],0.0,1.0);
    float radial=length(q.xz);
    float a=atan(q.z,q.x)+spectacle_time*.05;
    float n=textureLod(cloud_noise,vec3(a*.6,q.y*1.5,radial*.8),0.0).r;
    float cylinder=1.0-smoothstep(.85,1.15+.25*n,radial);
    float span=smoothstep(lowered-.05,lowered+.08+.05*n,q.y)*(1.0-smoothstep(1.40,1.55,q.y));
    float scud=smoothstep(.62,.8,textureLod(cloud_noise,q*2.8+vec3(spectacle_time*.02),0.0).r)
        *(1.0-smoothstep(1.0,1.6,radial))*smoothstep(lowered-.25,lowered,q.y)
        *(1.0-smoothstep(lowered,lowered+.05,q.y));
    albedo=vec3(.36,.40,.44);
    return max(cylinder*span*(.7+.5*n),scud*.6);
}
float shelf_cloud(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_SHELF,4.0);
    if (abs(q.x)>9.0) return 0.0;
    float n=textureLod(cloud_noise,q*vec3(.35,1.2,.8)+vec3(spectacle_time*.01,0.0,0.0),0.0).r;
    // A slab of storm cloud minus a wedge: the leading face slopes up and back.
    float front=(q.y-.55)*1.6-.2*n;
    float body=smoothstep(front-.05,front+.12,q.z)*smoothstep(.48,.6+.08*n,q.y)
        *(1.0-smoothstep(1.2,1.32,q.y))*(1.0-smoothstep(2.5,4.0,q.z));
    float tiers=.72+.28*smoothstep(-.3,.6,sin(q.y*42.0+n*3.0));
    albedo=mix(vec3(.30,.34,.40),vec3(.56,.59,.63),smoothstep(.55,1.2,q.y));
    return body*tiers*(1.0-smoothstep(7.0,9.0,abs(q.x)));
}
float lenticular(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_LENTICULAR,8.0)-vec3(0.0,2.6,0.0);
    // Stacked squashed spheres blended with a smooth minimum: a pile of plates.
    float d=ellipsoid(q,vec3(1.9,.11,1.15));
    d=soft_union(d,ellipsoid(q-vec3(.10,.19,0.0),vec3(1.55,.10,.95)),.09);
    d=soft_union(d,ellipsoid(q-vec3(.18,.36,0.0),vec3(1.15,.09,.72)),.08);
    d=soft_union(d,ellipsoid(q-vec3(.22,.50,0.0),vec3(.62,.07,.42)),.07);
    float edge=textureLod(cloud_noise,q*1.6,0.0).g;
    albedo=vec3(.93,.91,.93);
    return 1.0-smoothstep(-.03,.03,d+(edge-.5)*.035);
}
float morning_glory(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_MORNING_GLORY,4.5);
    if (abs(q.x)>13.0) return 0.0;
    float d=0.0;
    for (int i=0;i<3;i++) {
        // Long rolling cylinders across x; the noise turns about each tube axis.
        vec2 c=vec2(q.z-(-1.5+float(i)*1.8),q.y-.85);
        float r=.30-float(i)*.06;
        float roll=spectacle_time*.08+float(i);
        vec2 rc=mat2(vec2(cos(roll),sin(roll)),vec2(-sin(roll),cos(roll)))*c;
        float n=textureLod(cloud_noise,vec3(q.x*.25,rc*2.4),0.0).r;
        d=max(d,1.0-smoothstep(r*.8,r*(1.1+.25*n),length(c)));
    }
    albedo=vec3(.82,.79,.80);
    return d*(1.0-smoothstep(10.0,13.0,abs(q.x)));
}
float microburst(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_MICROBURST,3.5);
    if (q.y<0.0 || q.y>1.32) return 0.0;
    float radial=length(q.xz);
    // The rain shaft stretched to the ground, flaring as it lands, and an
    // outflow curl rolling away along the ground.
    float flare=mix(1.0,1.9,1.0-smoothstep(0.0,.35,q.y));
    float n=textureLod(cloud_noise,vec3(q.x*1.6,q.y*.25-spectacle_time*.05,q.z*1.6),0.0).r;
    float shaft=1.0-smoothstep(.30*flare,.65*flare,radial+(n-.5)*.5);
    float ring=.55+.7*fract(spectacle_time*.05);
    float curl=1.0-smoothstep(.06,.14,length(vec2(radial-ring,q.y-.08)));
    albedo=vec3(.42,.45,.50);
    return max(shaft*(.45+.55*n),curl*.7);
}
float kelvin_helmholtz(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_KELVIN_HELMHOLTZ,6.0);
    q=vec3(q.x*.5,2.05+(q.y-2.05)*.5,q.z*.5);
    if (abs(q.z)>.8 || abs(q.x)>6.0) return 0.0;
    // Breaking waves on a sheared layer: each crest a leaning, hollow curl.
    float wavelength=1.1;
    float w=(fract(q.x/wavelength+spectacle_time*.004)-.5)*wavelength;
    float h=q.y-2.05;
    float layer=1.0-smoothstep(0.0,.06,abs(h+.03));
    vec2 c=vec2(w+.35*max(h,0.0),h-.16);
    float crest=1.0-smoothstep(.14,.19,length(c*vec2(1.0,.85)));
    float hollow=1.0-smoothstep(.05,.09,length(c-vec2(-.04,-.02)));
    float edge=textureLod(cloud_noise,q*2.6,0.0).g;
    albedo=vec3(.88,.87,.88);
    return clamp(max(layer,crest-hollow*.9),0.0,1.0)*(.65+.5*edge)
        *(1.0-smoothstep(.45,.8,abs(q.z)))*(1.0-smoothstep(4.5,6.0,abs(q.x)));
}
float supercell(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_SUPERCELL,8.0);
    float radial=length(q.xz); float a=atan(q.z,q.x);
    // A banded mesocyclone: stacked flaring plates turning about the updraft.
    float band=sin(q.y*13.0+a-spectacle_time*.03);
    float n=textureLod(cloud_noise,vec3(a*.5,q.y*.9,radial*.4),0.0).r;
    float r=2.2+.25*band+.35*(q.y-.7);
    float body=(1.0-smoothstep(r-.15,r+.25+.2*n,radial))*smoothstep(.65,.85,q.y)*(1.0-smoothstep(3.4,3.7,q.y));
    float striation=.6+.4*smoothstep(-.4,.5,band+n-.5);
    float anvil=(1.0-smoothstep(4.2,5.3,radial+(n-.5)))*smoothstep(3.4,3.55,q.y)*(1.0-smoothstep(3.9,4.2,q.y));
    albedo=mix(vec3(.36,.40,.45),vec3(.70,.72,.74),smoothstep(.8,3.6,q.y));
    return max(body*striation,anvil*.85);
}
float anvil_tower(vec3 p,inout vec3 albedo) {
    int s=spectacle[S_ANVIL]>0.0?S_ANVIL:S_OVERSHOOT;
    vec3 q=object_frame(p,s,12.0);
    float n=textureLod(cloud_noise,q*.45,0.0).r;
    // Fused, offset updraft lobes rather than a capped cylinder under a disc.
    // All remain within the original bounded march; no new density taps.
    float tower=ellipsoid(q-vec3(-.15,2.0,.10),vec3(1.20,1.30,1.10));
    tower=soft_union(tower,ellipsoid(q-vec3(.22,3.65,-.18),vec3(1.50,1.65,1.35)),.65);
    tower=soft_union(tower,ellipsoid(q-vec3(-.12,5.20,.15),vec3(1.90,1.65,1.55)),.65);
    tower=soft_union(tower,ellipsoid(q-vec3(.40,6.50,-.12),vec3(2.10,1.30,1.85)),.65);
    float anvil=ellipsoid(q-vec3(2.0,7.20,0.0),vec3(5.5,.60,3.0));
    float cloud=soft_union(tower,anvil,.65);
    if (spectacle[S_OVERSHOOT]>0.0) {
        // Overshooting top: the updraft's dome punching through the lid.
        float dome=ellipsoid(q-vec3(0.0,7.75,0.0),vec3(1.1,.75,1.1));
        cloud=mix(cloud,soft_union(cloud,dome,.35),spectacle[S_OVERSHOOT]);
    }
    albedo=vec3(.87,.87,.87);
    return 1.0-smoothstep(-.16,.16,cloud+(n-.5)*.45);
}
float pileus(vec3 p,inout vec3 albedo) {
    vec3 q=object_frame(p,S_PILEUS,6.0);
    if (q.y<1.15) return 0.0;
    float n=textureLod(cloud_noise,q*1.1,0.0).r;
    // A cauliflower tower pushing up and the smooth cap condensed just above it.
    float tower=ellipsoid(q-vec3(0.0,2.2,0.0),vec3(.95,1.15,.95))+(n-.5)*.35;
    albedo=vec3(.90,.90,.92);
    return 1.0-smoothstep(-.05,.05,tower);
}
float pileus_cap(vec3 p) {
    vec3 q=object_frame(p,S_PILEUS,6.0);
    // A smooth silk cap condensed in the moist layer pushed up over the tower.
    float cap=ellipsoid(q-vec3(0.0,3.72,0.0),vec3(1.7,.08,1.7));
    float arch=ellipsoid(q-vec3(0.0,3.62,0.0),vec3(1.5,.22,1.5));
    return (1.0-smoothstep(-.02,.02,max(cap,-arch)))*.9;
}
float pyrocumulonimbus(vec3 p,inout vec3 albedo,inout vec3 glow) {
    vec3 q=object_frame(p,S_PYROCB,7.0);
    if (q.y<0.0 || q.y>6.2) return 0.0;
    float h=q.y/5.6;
    q.x-=.6*h*h;
    float n=textureLod(cloud_noise,vec3(q.x,q.y-spectacle_time*.02,q.z)*.7,0.0).r;
    float r=.18+.75*h+.5*smoothstep(.75,1.0,h);
    float lobes=textureLod(cloud_noise,q*vec3(.9,.6,.9)+vec3(0.0,-spectacle_time*.015,0.0),0.0).g;
    float plume=(1.0-smoothstep(r*.55,r*(.95+.7*lobes),length(q.xz)))*(1.0-smoothstep(5.2,6.2,q.y+(n-.5)*1.2));
    // Black-brown oil smoke below, condensing into white cumulus above.
    float condensed=smoothstep(.38,.62,h+(n-.5)*.25);
    albedo=mix(vec3(.10,.075,.055),vec3(.88,.86,.84),condensed);
    float flicker=.6+.4*sin(spectacle_time*9.0+n*12.0)*sin(spectacle_time*5.3+q.x*20.0);
    glow+=vec3(1.0,.42,.10)*(1.0-smoothstep(0.0,.35,q.y))*flicker*1.6*plume;
    if (spectacle[S_PLUME_LIGHTNING]>0.0) {
        // Lightning in the ash: a branching flash inside the plume.
        float branch=1.0-smoothstep(0.0,.035,abs(textureLod(cloud_noise,
            q*vec3(1.4,.5,1.4)+vec3(floor(spectacle_time*3.0)),0.0).g-.5));
        glow+=vec3(.85,.85,1.0)*branch*spectacle[S_PLUME_LIGHTNING]*6.0*smoothstep(.15,.5,h)*(1.0-smoothstep(.6,.8,h));
    }
    return plume*(.55+.6*n);
}
bool any_objects() {
    return spectacle[S_SHELF]+spectacle[S_WALL]+spectacle[S_LENTICULAR]+spectacle[S_MORNING_GLORY]
        +spectacle[S_MICROBURST]+spectacle[S_KELVIN_HELMHOLTZ]+spectacle[S_SUPERCELL]
        +spectacle[S_ANVIL]+spectacle[S_OVERSHOOT]+spectacle[S_PILEUS]+spectacle[S_PYROCB]
        +spectacle[S_TORNADO]+spectacle[S_WATERSPOUT]>0.0;
}
// Bounding sphere (xyz centre, w radius, km) for an object slot.
vec4 object_bounds(int s) {
    vec3 f=bearing_axis(s);
    if (s==S_TORNADO) return vec4(f*3.6+vec3(0.0,.7,0.0),1.0);
    if (s==S_WATERSPOUT) return vec4(f*4.5+vec3(0.0,.7,0.0),.9);
    if (s==S_WALL) return vec4(f*4.5+vec3(0.0,1.0,0.0),1.6);
    if (s==S_SHELF) return vec4(f*4.0+vec3(0.0,.9,0.0),9.2);
    if (s==S_LENTICULAR) return vec4(f*8.0+vec3(0.0,2.8,0.0),2.4);
    if (s==S_MORNING_GLORY) return vec4(f*4.5+vec3(0.0,.9,0.0),13.0);
    if (s==S_MICROBURST) return vec4(f*3.5+vec3(0.0,.65,0.0),1.6);
    if (s==S_KELVIN_HELMHOLTZ) return vec4(f*6.0+vec3(0.0,2.1,0.0),9.0);
    if (s==S_SUPERCELL) return vec4(f*8.0+vec3(0.0,2.4,0.0),5.8);
    if (s==S_ANVIL) return vec4(f*12.0+vec3(0.0,5.0,0.0),8.8);
    if (s==S_OVERSHOOT) return vec4(f*12.0+vec3(0.0,5.0,0.0),8.8);
    if (s==S_PILEUS) return vec4(f*6.0+vec3(0.0,2.6,0.0),1.9);
    return vec4(f*7.0+vec3(0.0,3.0,0.0),4.2);
}
float objects_at(vec3 p,out vec3 albedo,out vec3 glow) {
    albedo=vec3(.8); glow=vec3(0.0);
    // Warp the sample point so every sculpted silhouette billows.
    vec3 warp=vec3(textureLod(cloud_noise,p*.8,0.0).r,textureLod(cloud_noise,p*.8+vec3(.37),0.0).g,
        textureLod(cloud_noise,p*.8+vec3(.71),0.0).r)-.5;
    vec3 raw=p;
    p+=warp*vec3(.30,.18,.30);
    bool smooth_shape=false;
    bool thin=false;
    float best=0.0; vec3 a=vec3(.8); float d=0.0;
#ifndef QUEENS_CLOUD_DECK
    if (spectacle[S_TORNADO]>0.0) { d=vortex(raw,S_TORNADO,a)*1.6*spectacle[S_TORNADO]; if (d>best) { best=d; albedo=a; thin=true; } }
#endif
    if (spectacle[S_WATERSPOUT]>0.0) { d=vortex(raw,S_WATERSPOUT,a)*1.6*spectacle[S_WATERSPOUT]; if (d>best) { best=d; albedo=a; thin=true; } }
    if (spectacle[S_WALL]>0.0) { d=wall_cloud(p,a)*min(1.0,spectacle[S_WALL]*1.5); if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_SHELF]>0.0) { d=shelf_cloud(p,a)*spectacle[S_SHELF]; if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_LENTICULAR]>0.0) { d=lenticular(raw,a)*spectacle[S_LENTICULAR]; if (d>best) { best=d; albedo=a; smooth_shape=true; } }
    if (spectacle[S_MORNING_GLORY]>0.0) { d=morning_glory(p,a)*spectacle[S_MORNING_GLORY]; if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_MICROBURST]>0.0) { d=microburst(p,a)*spectacle[S_MICROBURST]; if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_KELVIN_HELMHOLTZ]>0.0) { d=kelvin_helmholtz(p,a)*spectacle[S_KELVIN_HELMHOLTZ]; if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_SUPERCELL]>0.0) { d=supercell(p,a)*spectacle[S_SUPERCELL]; if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_ANVIL]+spectacle[S_OVERSHOOT]>0.0) { d=anvil_tower(p,a)*max(spectacle[S_ANVIL],spectacle[S_OVERSHOOT]); if (d>best) { best=d; albedo=a; } }
    if (spectacle[S_PILEUS]>0.0) { d=pileus(p,a)*spectacle[S_PILEUS]; if (d>best) { best=d; albedo=a; } float cap=pileus_cap(raw)*spectacle[S_PILEUS]; if (cap>best) { best=cap; albedo=vec3(.96); smooth_shape=true; } }
    if (spectacle[S_PYROCB]>0.0) { vec3 g=vec3(0.0); d=pyrocumulonimbus(p,a,g)*spectacle[S_PYROCB]; glow+=g*spectacle[S_PYROCB]; if (d>best) { best=d; albedo=a; } }
    // Billowed edges: two octaves of erosion keep the sculpted shapes cloud, not plaster.
    if (best>0.0 && !smooth_shape) {
        float e1=textureLod(cloud_noise,p*2.3-vec3(0.0,spectacle_time*.004,0.0),0.0).g;
        float e2=textureLod(cloud_noise,p*7.1,0.0).r;
        best=max(0.0,best*(.45+.75*e1)-(thin?0.0:(1.0-e2)*.18));
    }
    return best;
}
vec4 spectacle_objects(vec3 direction,float jitter,out float near_t) {
    // Union of the active objects' bounding spheres: march only that span.
    float t0=1e6; float t1=0.0;
    for (int s=1;s<=17;s++) {
        if (spectacle[s]<=0.0) continue;
#ifdef QUEENS_CLOUD_DECK
        if (s==S_TORNADO) continue; // Queens joins its single funnel to the deck.
#endif
        if (s==S_HABOOB || s==S_ASPERITAS || s==S_FALLSTREAK || s==S_VIRGA) continue;
        vec4 b=object_bounds(s);
        float mid=dot(direction,b.xyz);
        float disc=b.w*b.w-(dot(b.xyz,b.xyz)-mid*mid);
        if (disc<=0.0) continue;
        float half_chord=sqrt(disc);
        t0=min(t0,mid-half_chord); t1=max(t1,mid+half_chord);
    }
    near_t=t0;
    t0=max(t0,.05);
    if (t1<=t0) return vec4(0.0);
    float dt=(t1-t0)/48.0;
    vec3 source=normalize(sun_direction);
    float day=smoothstep(-.12,.1,source.y);
    vec3 ambient=mix(fog_horizon_color*.9,vec3(.55,.62,.74),day);
    vec3 sum=vec3(0.0); float transmittance=1.0;
    for (int i=0;i<48;i++) {
        vec3 p=direction*(t0+(float(i)+jitter)*dt);
        vec3 albedo; vec3 glow;
        float d=objects_at(p,albedo,glow);
        if (d>.01) {
            vec3 a2; vec3 g2;
            float light_density=objects_at(p+source*.18,a2,g2);
            float shade=exp(-light_density*2.2);
            float alpha=1.0-exp(-d*dt*4.5);
            vec3 lit=albedo*(ambient*.45+celestial_color*day*shade*.85)*mix(vec3(1.0),vec3(.30,.33,.39),smoothstep(.05,.55,storm_strength))+glow;
#ifdef QUEENS_CLOUD_DECK
            // Share the installed deck's powder, twilight and green-storm
            // response instead of illuminating rare formations as white props.
            lit=albedo*wx_powder_light(d,light_density*2.2,dot(direction,source),
                clamp(p.y/8.0,0.0,1.0),celestial_color*day,ambient,source)+glow;
#endif
            lit+=celestial_color*weather_flash*.6;
            sum+=lit*alpha*transmittance;
            transmittance*=1.0-alpha;
            if (transmittance<.01) break;
        }
    }
    return vec4(sum,1.0-transmittance);
}

// --- High dome layers ------------------------------------------------------------
// Noctilucent clouds are lit only while the sun is 6-12 degrees down: the
// mesosphere still sees it while the lower air is already in shadow.
float noctilucent_light() {
    float e=sun_elevation_degrees();
    return smoothstep(-13.5,-11.0,e)*(1.0-smoothstep(-6.5,-4.5,e));
}
vec3 noctilucent(vec3 dir) {
    if (dir.y<.02) return vec3(0.0);
    vec3 sun=normalize(sun_direction);
    float facing=.35+.65*pow(max(0.0,dot(normalize(dir.xz),normalize(sun.xz+vec2(1e-4)))),1.2);
    float band=smoothstep(.02,.08,dir.y)*(1.0-smoothstep(.30,.55,dir.y));
    vec2 uv=dir.xz/max(dir.y,.05)*.55+vec2(spectacle_time*.0015,0.0);
    float wisps=texture(cirrus_tex,uv).r;
    // Fine billows ("herringbone") across the bands.
    float billow=.6+.4*sin(dot(uv,vec2(38.0,11.0))+vnoise(uv*6.0)*4.0);
    return mix(vec3(.28,.55,1.0),vec3(.80,.88,1.0),wisps)*wisps*billow*facing*band*noctilucent_light()*1.8;
}
vec3 nacreous(vec3 dir) {
    if (dir.y<.03) return vec3(0.0);
    vec3 sun=normalize(sun_direction);
    float e=sun_elevation_degrees();
    float lit=smoothstep(-8.0,-5.0,e)*(1.0-smoothstep(-1.0,1.5,e));
    float near=.25+.75*pow(max(0.0,dot(normalize(dir.xz),normalize(sun.xz+vec2(1e-4)))),2.0);
    float band=smoothstep(.03,.10,dir.y)*(1.0-smoothstep(.28,.50,dir.y));
    vec2 uv=dir.xz/max(dir.y,.05)*vec2(.25,.6);
    float lens=smoothstep(.40,.72,fbm2(uv*3.0+vec2(spectacle_time*.002,0.0)));
    float thickness=fbm2(uv*7.0+3.1);
    // Thin-film colours: phase grows with crystal path. Mother-of-pearl.
    vec3 film=.65+.35*cos(6.2832*(thickness*.7+vec3(0.0,.33,.67)));
    // A bounded pearl sheen, not luminous rainbow stripes across the dome.
    return mix(vec3(.9,.86,.9),film,.80)*lens*near*band*lit*.60;
}
vec3 aurora(vec3 dir) {
    if (dir.y<0.0) return vec3(0.0);
    float e=elevation_degrees(dir);
    float az=wrap_pi(azimuth_of(dir)-spectacle_bearing[S_AURORA]);
    if (abs(az)>1.75) return vec3(0.0);
    vec3 total=vec3(0.0);
    for (int k=0;k<3;k++) {
        float fk=float(k);
        // Domain warp, then panning sines: the folds drift along the arc.
        float w=az*2.0+fbm2(vec2(az*3.0+fk*7.0,spectacle_time*.03))*1.4;
        float base=7.0+fk*6.0+5.0*sin(w*1.3+spectacle_time*.05+fk)+3.0*sin(w*3.1-spectacle_time*.08);
        float above=e-base;
        if (above<-2.0) continue;
        float lower_edge=smoothstep(-1.2,.4,above);
        float height=exp(-max(above,0.0)/(9.0+4.0*fk));
        float rays=.35+.65*pow(vnoise(vec2(w*24.0+spectacle_time*.6,fk*13.0)),1.6);
        float curtain=lower_edge*height*rays*(1.0-smoothstep(1.2,1.75,abs(az)));
        vec3 colour=mix(vec3(.10,1.0,.35),vec3(.95,.18,.62),smoothstep(4.0,16.0,above));
        colour=mix(colour,vec3(.50,.25,.95),smoothstep(14.0,26.0,above));
        total+=colour*curtain*(1.0-fk*.25);
    }
    return total*.9;
}
vec3 steve(vec3 dir) {
    if (dir.y<0.0) return vec3(0.0);
    // A narrow mauve arc east to west, tilted poleward of the zenith, with
    // a green stepped picket fence hanging on its equatorward side.
    vec3 f=bearing_axis(S_STEVE);
    vec3 r=vec3(-f.z,0.0,f.x);
    vec3 top=normalize(vec3(0.0,cos(.35),0.0)+f*sin(.35));
    vec3 n=normalize(cross(r,top));
    float d=dot(dir,n);
    float along=dot(dir,r);
    float flow=.7+.3*vnoise(vec2(along*30.0-spectacle_time*2.5,0.0));
    float core=exp(-pow(d/.010,2.0))*flow;
    float halo=exp(-pow(d/.03,2.0))*.25;
    float below=d*sign(dot(-f,n));
    float pickets=step(.5,fract(along*55.0+.5*vnoise(vec2(along*9.0,spectacle_time*.3))))
        *smoothstep(.012,.02,below)*(1.0-smoothstep(.04,.06,below))
        *(.5+.5*vnoise(vec2(along*80.0,spectacle_time*.5)));
    return (vec3(.78,.34,1.0)*(core*1.5+halo)+vec3(.25,1.0,.45)*pickets)*smoothstep(0.0,.12,dir.y);
}
vec3 transient_luminous(vec3 dir) {
    vec3 total=vec3(0.0);
    float e=elevation_degrees(dir);
    float seed=electrical_seed;
    if (spectacle[S_SPRITE]>0.0) {
        // Red sprite: a crown high over the storm with blue-violet tendrils.
        float x=degrees(wrap_pi(azimuth_of(dir)-spectacle_bearing[S_SPRITE]))-(hash12(vec2(seed,1.0))-.5)*10.0;
        float crown=exp(-pow(x/1.4,2.0)-pow((e-10.0)/1.1,2.0));
        float tendrils=0.0;
        for (int i=0;i<5;i++) {
            float o=(hash12(vec2(seed,float(i)+3.0))-.5)*3.0+.25*sin(e*2.3+float(i));
            tendrils+=exp(-pow((x-o)/.14,2.0));
        }
        tendrils*=smoothstep(5.0,6.5,e)*(1.0-smoothstep(8.5,10.0,e));
        total+=(vec3(1.0,.16,.22)*crown*2.2+vec3(.65,.25,.85)*tendrils*.9)*spectacle[S_SPRITE];
    }
    if (spectacle[S_BLUE_JET]>0.0) {
        // Blue jet: a narrow cone climbing from the cloud top.
        float x=degrees(wrap_pi(azimuth_of(dir)-spectacle_bearing[S_BLUE_JET]));
        float h=clamp((e-3.0)/5.0,0.0,1.0);
        float cone=exp(-pow(x/(.15+.55*h),2.0))*step(3.0,e)*(1.0-smoothstep(7.0,8.5,e));
        total+=vec3(.25,.48,1.0)*cone*1.8*(1.0-h*.6)*spectacle[S_BLUE_JET];
    }
    if (spectacle[S_GIGANTIC_JET]>0.0) {
        // Gigantic jet: a tree of light from the cloud top to the ionosphere.
        float x=degrees(wrap_pi(azimuth_of(dir)-spectacle_bearing[S_GIGANTIC_JET]));
        float h=clamp((e-3.0)/14.0,0.0,1.0);
        float axis=-.6*sin(e*.7);
        float trunk=exp(-pow((x-axis)/(.16+.28*h),2.0))*step(3.0,e)*(1.0-smoothstep(15.0,18.0,e));
        float branches=0.0;
        // Connected leaders grow out of the trunk, rather than thresholded
        // noise islands floating above it. All coordinates remain bounded.
        for(int i=0;i<8;i++) {
            float fi=float(i);
            float start=6.5+hash12(vec2(seed,fi+11.0))*3.0;
            float end=14.0+hash12(vec2(seed,fi+29.0))*4.5;
            float u=clamp((e-start)/(end-start),0.0,1.0);
            float side=mod(fi,2.0)<1.0 ? -1.0 : 1.0;
            float spread=1.4+hash12(vec2(seed,fi+47.0))*2.5;
            float path=-.6*sin(start*.7)+side*spread*pow(u,1.15)+sin(u*15.0+fi)*u*.16;
            float width=mix(.11,.035,u);
            branches+=exp(-pow((x-path)/width,2.0))*smoothstep(start,start+.5,e)*(1.0-smoothstep(end-.6,end,e));
        }
        total+=(mix(vec3(.35,.5,1.0),vec3(1.0,.25,.35),h)*trunk*1.8+vec3(1.0,.3,.4)*branches)*spectacle[S_GIGANTIC_JET];
    }
    if (spectacle[S_ELVES]>0.0) {
        // ELVES: a red ring expanding at the foot of the ionosphere.
        float x=degrees(wrap_pi(azimuth_of(dir)-spectacle_bearing[S_ELVES]));
        float expansion=smoothstep(.035,.30,electrical_age);
        float radius=mix(5.0,16.0,expansion);
        // A horizontal ionospheric ring seen obliquely from a rooftop. A
        // great-circle outline incorrectly produced two vertical red pillars.
        float ellipse=length(vec2(x/radius,(e-24.0)/(radius*.13)));
        float ring=exp(-pow((ellipse-1.0)/.12,2.0))*smoothstep(.02,.08,dir.y);
        total+=vec3(1.0,.22,.18)*ring*1.4*spectacle[S_ELVES];
    }
    return total;
}

// --- Optics ------------------------------------------------------------------------
vec3 ice_optics(vec3 dir) {
    bool lunar=skywatch_extended_optics && moon_phase_enabled;
    vec3 sun=normalize(lunar ? celestial_direction : sun_direction);
    float theta=degrees(angle_between(dir,sun));
    float es=elevation_degrees(sun);
    float e=elevation_degrees(dir);
    float daz=wrap_pi(azimuth_of(dir)-azimuth_of(sun));
    float veil=.55+.45*texture(cirrus_tex,dir.xz/max(dir.y,.1)*.2-wind_offset.xz*.14).r;
    vec3 total=vec3(0.0);
    float moon_gain=lunar ? .42*sqrt(max(moon_illumination,0.0))*smoothstep(0.0,8.0,es) : 1.0;
    float ring_level=max(spectacle[S_HALO],skywatch_ice_complex.x)*moon_gain;
    float dog_level=max(spectacle[S_SUN_DOGS],skywatch_ice_complex.y)*moon_gain;
    float pillar_level=max(spectacle[S_PILLARS],skywatch_ice_complex.z)*moon_gain;
    if (ring_level>0.0) {
        // 22 degree halo: a sharp red inner rim fading white-blue outward.
        float ring=smoothstep(21.4,22.2,theta)*exp(-max(theta-22.2,0.0)/1.1);
        vec3 c=mix(vec3(1.0,.45,.25),vec3(.85,.9,1.0),smoothstep(22.0,24.5,theta));
        total+=c*ring*.6*ring_level*veil;
        if(skywatch_extended_optics) {
            float outer=smoothstep(45.4,46.0,theta)*exp(-max(theta-46.0,0.0)/1.4);
            vec3 dispersion=mix(vec3(1.0,.30,.16),vec3(.42,.65,1.0),smoothstep(45.8,48.0,theta));
            total+=dispersion*outer*.16*ring_level*veil;
        }
    }
    if (dog_level>0.0) {
        // Parhelia at the sun's altitude, pushed outward as the sun climbs.
        float er=radians(es); float sep=radians(22.0+es*.12);
        float offset=acos(clamp((cos(sep)-sin(er)*sin(er))/max(cos(er)*cos(er),.01),-1.0,1.0));
        for (int k=-1;k<=1;k+=2) {
            float x=degrees(wrap_pi(daz-float(k)*offset))*cos(er)*float(k);
            float de=e-es;
            float spot=exp(-pow(x/.9,2.0)-pow(de/1.6,2.0));
            float tail=step(0.0,x)*exp(-x/5.0)*exp(-pow(de/.7,2.0))*.35;
            vec3 c=mix(vec3(1.0,.35,.2),vec3(1.0,.95,.85),smoothstep(-1.0,1.2,x));
            if(skywatch_extended_optics)c=mix(c,vec3(.36,.60,1.0),smoothstep(.4,2.0,x));
            total+=(c*spot*1.4+vec3(1.0)*tail)*dog_level;
        }
    }
    if (spectacle[S_CHA]>0.0) {
        // Circumhorizontal arc: a flat spectrum band 46 degrees under a high sun.
        float band=e-(es-46.0);
        float span=exp(-pow(degrees(daz)/55.0,2.0));
        float inside=smoothstep(-2.6,-1.6,band)*(1.0-smoothstep(1.6,2.6,band));
        total+=spectral(1.0-clamp((band+2.2)/4.4,0.0,1.0))*inside*span*1.2*spectacle[S_CHA]*veil;
    }
    if (spectacle[S_CZA]>0.0) {
        // Circumzenithal arc: a bow around the zenith, red toward the sun.
        float band=(90.0-e)-max(2.0,44.0-es);
        float span=exp(-pow(degrees(daz)/45.0,2.0));
        float inside=smoothstep(-2.2,-1.4,band)*(1.0-smoothstep(1.4,2.2,band));
        total+=spectral(1.0-clamp((band+1.8)/3.6,0.0,1.0))*inside*span*1.6*spectacle[S_CZA];
    }
    if (pillar_level>0.0) {
        // A sun pillar standing on the low sun, and at night pillars over the
        // city lamps, raised by plate crystals settling in still frost.
        float x=degrees(daz);
        float column=exp(-pow(x/.55,2.0))*smoothstep(es-1.0,es+.5,e)*exp(-max(e-es,0.0)/9.0)*smoothstep(-6.0,-1.0,es);
        if(skywatch_extended_optics)column=exp(-pow(x/.55,2.0))*exp(-abs(e-es)/9.0)*smoothstep(-.5,1.0,e)*smoothstep(-6.0,-1.0,es)*(1.0-smoothstep(20.0,35.0,es));
        total+=mix(vec3(1.0,.62,.32),vec3(.63,.77,1.0),lunar ? 1.0 : 0.0)*column*1.6*pillar_level;
        float night=1.0-smoothstep(-8.0,-3.0,sun_elevation_degrees());
        float lamp_az=degrees(azimuth_of(dir))*.8;
        float cell=floor(lamp_az); float j=hash12(vec2(cell,4.0));
        float lamp=step(.82,j)*exp(-pow((fract(lamp_az)-.5)/.07,2.0))*smoothstep(1.0,2.0,e)*exp(-max(e-2.0,0.0)/(4.0+6.0*j));
        // V2's actual street-lamp owner now carries the urban pillars. Keep
        // these old synthetic bearings only for the retained seasonal shader.
        if(!skywatch_extended_optics)total+=mix(vec3(1.0,.78,.5),vec3(.85,.9,1.0),hash12(vec2(cell,7.0)))*lamp*night*1.2*spectacle[S_PILLARS];
    }
    return total;
}

vec3 skywatch_twilight_geometry(vec3 dir,vec3 colour) {
    float es=sun_elevation_degrees();
    float civil=smoothstep(-8.0,-6.0,es)*(1.0-smoothstep(-1.0,0.0,es));
    if(civil<.0001)return colour;
    vec2 anti=-sun_direction.xz/max(length(sun_direction.xz),.0001);
    float antisolar=smoothstep(.0,.85,dot(dir.xz/max(length(dir.xz),.0001),anti));
    float elevation=elevation_degrees(dir);
    float edge=clamp(-es*.75,.8,6.0);
    float shadow=(1.0-smoothstep(edge-1.2,edge+1.2,elevation))*smoothstep(-.5,1.0,elevation);
    float belt=exp(-pow((elevation-edge-3.0)/2.6,2.0));
    colour=mix(colour,vec3(.045,.055,.15),shadow*antisolar*civil*.65);
    colour+=vec3(.24,.075,.16)*belt*antisolar*civil;
    return colour;
}

vec3 skywatch_night_dust(vec3 dir) {
    float night=1.0-smoothstep(-15.0,-9.0,sun_elevation_degrees());
    if(night<.0001)return vec3(0.0);
    float moon_wash=moon_phase_enabled ? 1.0-.8*sqrt(max(moon_illumination,0.0))*smoothstep(0.0,.2,celestial_direction.y) : 1.0;
    float above=smoothstep(.015,.15,dir.y);
    // Airglow and interplanetary dust are broad ray-space radiance, not stars
    // or emissive geometry attached to the camera. Existing clouds occlude it.
    float airglow=exp(-pow((elevation_degrees(dir)-22.0)/13.0,2.0));
    vec3 eq=vec3(dot(dir,equatorial_axis_x),dot(dir,equatorial_axis_y),dot(dir,equatorial_axis_z));
    float latitude=asin(clamp(-.397777*eq.y+.917482*eq.z,-1.0,1.0));
    float separation=angle_between(dir,normalize(sun_direction));
    float plane=exp(-abs(latitude)/.075);
    float cone=exp(-separation/.48)*smoothstep(.12,.30,separation)*plane;
    float gegenschein=exp(-pow((PI-separation)/.18,2.0))*plane;
    vec3 dust=vec3(1.0,.83,.65)*(cone*.08+gegenschein*.006);
    return (vec3(.0015,.0035,.0022)*airglow+dust)*night*moon_wash*above;
}
vec3 sun_beams(vec3 dir) {
    vec3 sun=normalize(sun_direction);
    float es=sun_elevation_degrees();
    float low=smoothstep(-6.0,-1.0,es)*(1.0-smoothstep(10.0,18.0,es));
    vec3 total=vec3(0.0);
    // The angle about the sun picks the beam; the same beams cross the sky and
    // converge again at the antisolar point.
    if (spectacle[S_CREPUSCULAR]>0.0) {
        vec3 r=normalize(cross(sun,vec3(1e-4,1.0,0.0))); vec3 u=cross(r,sun);
        float ang=atan(dot(dir,u),dot(dir,r));
        float beams=pow(vnoise(vec2(ang*9.0,1.0)),2.5)*1.8;
        float fade=exp(-angle_between(dir,sun)*1.4)*smoothstep(-.15,.05,dot(dir,u));
        total+=vec3(1.0,.72,.42)*beams*fade*low*.6*spectacle[S_CREPUSCULAR];
    }
    if (spectacle[S_ANTICREPUSCULAR]>0.0) {
        vec3 anti=-sun;
        vec3 r=normalize(cross(anti,vec3(1e-4,1.0,0.0))); vec3 u=cross(r,anti);
        float ang=atan(dot(dir,u),-dot(dir,r));
        float beams=pow(vnoise(vec2(ang*9.0,1.0)),2.5)*1.8;
        float fade=exp(-angle_between(dir,anti)*1.2)*smoothstep(-.02,.05,dir.y);
        total+=vec3(.95,.62,.50)*beams*fade*low*.4*spectacle[S_ANTICREPUSCULAR];
    }
    return total;
}
vec3 green_flash(vec3 dir) {
    vec3 sun=normalize(sun_direction);
    float es=sun_elevation_degrees();
    // From a Queens roof the sun sets behind the skyline, about 3 degrees up:
    // the flash rides that hard edge, as it does on a far ridge.
    float near_horizon=1.0-smoothstep(.8,2.4,abs(es-3.0));
    float theta=degrees(angle_between(dir,sun));
    float de=elevation_degrees(dir)-es;
    // The last (or first) sliver of disc, refracted green, lifted and bloomed.
    float rim=exp(-pow(theta/.75,2.0))*smoothstep(0.0,.35,de);
    float bloom=exp(-theta/2.2)*.25;
    float disc=exp(-pow(theta/.6,2.0))*smoothstep(.2,-.3,de);
    return (vec3(.25,1.0,.35)*(rim*3.0+bloom)+vec3(1.0,.55,.25)*disc*1.5)*near_horizon*spectacle[S_GREEN_FLASH];
}
vec3 fata_morgana(vec3 dir,vec3 base) {
    float x=degrees(wrap_pi(azimuth_of(dir)-spectacle_bearing[S_FATA_MORGANA]));
    if (abs(x)>32.0) return base;
    float e=elevation_degrees(dir);
    // The far shore stretched into towers: erect over inverted images in a
    // shimmering band, mirrored about the duct line.
    float duct=5.5;
    float m=abs(e-duct);
    float jit=hash12(vec2(floor(x*2.2),2.0));
    float shimmer=sin(spectacle_time*1.7+x*.9)*.15+sin(spectacle_time*3.1+x*2.3)*.08;
    float tower=(.4+2.1*pow(jit,1.6))*(.75+.25*sin(x*.4+spectacle_time*.2));
    float wall=step(m,tower+shimmer)*step(1.0,e)*(1.0-smoothstep(duct+2.2,duct+2.7,e));
    float slab=1.0-smoothstep(.5,.9,m);
    float fade=1.0-smoothstep(24.0,32.0,abs(x));
    vec3 shore=fog_horizon_color*.45+vec3(.03,.04,.06);
    return mix(base,shore,max(wall,slab)*fade*.82*spectacle[S_FATA_MORGANA]);
}
vec3 glory(vec3 dir) {
    float theta=degrees(angle_between(dir,-normalize(sun_direction)));
    // Coloured rings around the observer's shadow on the fog: violet in, red out.
    vec3 c=vec3(0.0);
    for (int k=0;k<3;k++) {
        float band=(theta-(1.6+float(k)*1.5))/.55;
        c+=spectral(clamp(.5-band*.5,0.0,1.0))*exp(-band*band)*(1.0-float(k)*.25);
    }
    return (c+vec3(1.0,.95,.9)*exp(-pow(theta/.9,2.0))*.6)*spectacle[S_GLORY]*.9;
}
vec3 rainbow(vec3 dir,vec3 colour) {
    vec3 anti=-normalize(sun_direction);
    float theta=degrees(angle_between(dir,anti));
    float level=spectacle[S_RAINBOW]*smoothstep(-.03,.02,normalize(sun_direction).y)*smoothstep(-.01,.03,dir.y);
    // Primary 40.6-42.4 (red outside), secondary 50.4-53.6 (red inside),
    // Alexander's dark band between, supernumerary fringes inside the primary.
    float p=(theta-40.6)/1.8;
    float primary=smoothstep(-.15,.1,p)*(1.0-smoothstep(.9,1.15,p));
    float s=(theta-50.4)/3.2;
    float secondary=smoothstep(-.1,.1,s)*(1.0-smoothstep(.9,1.1,s));
    vec3 bow=spectral(1.0-clamp(p,0.0,1.0))*primary*.85+spectral(clamp(s,0.0,1.0))*secondary*.38;
    float fringe=step(theta,40.6)*(1.0-smoothstep(0.0,2.6,40.6-theta));
    bow+=mix(vec3(.6,1.0,.6),vec3(1.0,.6,.8),.5+.5*sin((40.6-theta)*7.5))*fringe*.18;
    float inside=step(theta,40.6)*.10;
    float dark=step(42.4,theta)*step(theta,50.4)*.12;
    colour*=1.0+(inside-dark)*level;
    return colour+bow*level*(.6+.4*dot(colour,vec3(.333)));
}
vec3 iridescence(vec3 dir,vec3 colour,float alpha) {
    float theta=degrees(angle_between(dir,normalize(sun_direction)));
    float thin=smoothstep(.05,.25,alpha)*(1.0-smoothstep(.45,.85,alpha));
    float near=smoothstep(26.0,8.0,theta)*smoothstep(2.0,5.0,theta);
    vec3 film=.5+.5*cos(6.2832*(alpha*2.8+theta*.06+vec3(0.0,.33,.67)));
    return colour+film*thin*near*.45*spectacle[S_IRIDESCENCE];
}
vec3 anvil_crawler(vec3 dir,float alpha) {
    if (dir.y<.04) return vec3(0.0);
    // Project onto the cloud base and grow a branching network from the
    // stroke: domain-warped cellular edges with a harsh step, finer twigs.
    vec2 uv=dir.xz*(1.25/dir.y);
    vec2 origin=bearing_axis(S_CRAWLER).xz*4.0;
    float seed=electrical_seed;
    vec2 w=uv+vec2(fbm2(uv*1.3+seed),fbm2(uv*1.3-seed))*.9;
    float trunk=voronoi_edge(w*.9+seed*3.7);
    float twig=voronoi_edge(w*3.1+seed*1.3);
    float flash=spectacle[S_CRAWLER];
    float reach=1.0-smoothstep(1.5,mix(1.5,12.0,smoothstep(0.0,.20,electrical_age)),length(uv-origin));
    float lines=(1.0-smoothstep(0.0,.035,trunk))+(1.0-smoothstep(0.0,.02,twig))*.55*smoothstep(0.0,.15,.15-trunk);
    float glow=exp(-length(uv-origin)*.3)*.25;
    return vec3(.86,.84,1.0)*(lines*reach+glow)*flash*smoothstep(.15,.5,alpha)*2.0;
}
vec3 dust_wall(vec3 dir,vec3 colour) {
    float level=spectacle[S_HABOOB];
    float x=wrap_pi(azimuth_of(dir)-spectacle_bearing[S_HABOOB]);
    float e=elevation_degrees(dir);
    // An advancing wall: it climbs (comes nearer) with the envelope, its boiling
    // crest from 2D noise, and it wraps the horizon as it arrives.
    float height=level*22.0*(.45+.55*exp(-x*x*(1.6-level*1.4)));
    float crest=height+6.0*(fbm2(vec2(x*3.0+spectacle_time*.02,spectacle_time*.01))-.5)*level;
    float wall=1.0-smoothstep(crest-3.0,crest+1.0,e);
    vec3 ochre=mix(vec3(.62,.44,.24),vec3(.36,.24,.13),smoothstep(crest-14.0,crest,e)*.6+fbm2(vec2(x*8.0,e*.3))*.4);
    colour=mix(colour,ochre*(.55+.45*smoothstep(-.1,.3,normalize(sun_direction).y)),wall*clamp(level*1.4,0.0,1.0));
    // Overhead, the whole sky goes sepia and the sun is a dull coin.
    return mix(colour,vec3(.48,.34,.19)*(.4+.6*dot(colour,vec3(.333))),smoothstep(.6,1.0,level)*.85);
}
// The Emergence, 12 October 1929: up off Sandy Hook, across the borough at about a
// fist's width, and away toward Betelgeuse. It looks at no one.
vec3 emergence(vec3 dir,vec3 colour) {
    float level=spectacle[S_EMERGENCE];
    float p=clamp(emergence_progress,0.0,1.0);
    float az=radians(mix(190.0,105.0,smoothstep(.05,.9,p)));
    float el=radians(mix(.4,31.0,smoothstep(0.0,.6,p)));
    vec3 c=vec3(sin(az)*cos(el),sin(el),-cos(az)*cos(el));
    if (dot(dir,c)<.97) return colour;
    vec3 side=normalize(cross(vec3(0.0,1.0,0.0),c));
    vec3 up=cross(c,side);
    float size=radians(mix(1.6,4.0,smoothstep(0.0,.3,p))*mix(1.0,.03,smoothstep(.62,1.0,p)));
    vec2 q=vec2(dot(dir,side),dot(dir,up))/max(size,1e-4);
    float t=spectacle_time*.04;
    float x=abs(q.x);
    float beat=sin(t*3.0)*.12;
    float rough=(fbm2(q*5.0+vec2(t*.3,0.0))-.5)*.14;
    float head=1.0-smoothstep(.34,.37,length((q-vec2(0.0,.62))*vec2(1.0,.82))+rough);
    float torso=1.0-smoothstep(.5,.53,length((q-vec2(0.0,-.1))*vec2(1.0,.68))+rough);
    float top=.62+beat+.38*sin(x*2.6)-.42*x;
    float under=top-.7*(1.0-x/1.5)-.05;
    float wing=step(.25,x)*step(x,1.5)*smoothstep(under,under+.02,q.y+rough)*(1.0-smoothstep(top-.02,top,q.y+rough));
    float beard=0.0;
    for (int k=-2;k<=2;k++) {
        float line=float(k)*.11+.06*sin(q.y*8.0+t*2.0+float(k)*1.7);
        beard=max(beard,(1.0-smoothstep(.018,.05,abs(q.x-line)))*step(-.9-.16*abs(float(k)),q.y)*step(q.y,.42));
    }
    float mask=clamp(max(max(head,torso),max(wing,beard)),0.0,1.0)*level;
    float halo=exp(-length(q)*.8)*level*smoothstep(.972,.995,dot(dir,c));
    vec3 sea=vec3(.07,.2,.17);
    colour+=sea*halo*.7;
    colour=mix(colour,vec3(.004,.009,.009)+sea*.03,mask);
    // Betelgeuse, once it is nearly there.
    colour+=vec3(1.0,.42,.2)*exp(-length(q)*length(q)*40.0)*smoothstep(.78,1.0,p)*level;
    return colour;
}
// Behind the lower clouds: the high layers, electricity above the storm, ice optics.
vec3 spectacle_behind(vec3 dir,vec3 colour) {
    if (spectacle[S_NOCTILUCENT]>0.0) colour+=noctilucent(dir)*spectacle[S_NOCTILUCENT];
    if (spectacle[S_NACREOUS]>0.0) colour+=nacreous(dir)*spectacle[S_NACREOUS];
    if (spectacle[S_AURORA]>0.0) colour+=aurora(dir)*spectacle[S_AURORA];
    if (spectacle[S_STEVE]>0.0) colour+=steve(dir)*spectacle[S_STEVE];
    if (spectacle[S_SPRITE]+spectacle[S_BLUE_JET]+spectacle[S_GIGANTIC_JET]+spectacle[S_ELVES]>0.0)
        colour+=transient_luminous(dir);
    if (spectacle[S_HALO]+spectacle[S_SUN_DOGS]+spectacle[S_CHA]+spectacle[S_CZA]+spectacle[S_PILLARS]+dot(skywatch_ice_complex,vec3(1.0))>0.0)
        colour+=ice_optics(dir);
    if (spectacle[S_CREPUSCULAR]+spectacle[S_ANTICREPUSCULAR]>0.0) colour+=sun_beams(dir);
    if (spectacle[S_GREEN_FLASH]>0.0) colour+=green_flash(dir);
    if (spectacle[S_FATA_MORGANA]>0.0 && !skywatch_extended_optics) colour=fata_morgana(dir,colour);
    if (spectacle[S_GLORY]>0.0) colour+=glory(dir);
    if (spectacle[S_EMERGENCE]>0.0) colour=emergence(dir,colour);
    return colour;
}
// In front of the lower clouds: what forms in the rain, on the cloud base, in the dust.
vec3 spectacle_front(vec3 dir,vec3 colour,float alpha) {
    if (spectacle[S_RAINBOW]>0.0) colour=rainbow(dir,colour);
    if (spectacle[S_IRIDESCENCE]>0.0) colour=iridescence(dir,colour,alpha);
    if (spectacle[S_CRAWLER]>0.0) colour+=anvil_crawler(dir,alpha);
    if (spectacle[S_HABOOB]>0.0) colour=dust_wall(dir,colour);
    return colour;
}
