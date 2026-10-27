// BSC5 points are analytical PSFs, never enlarged pixels from a sky photograph.
// Fixed celestial cells: camera magnification changes footprint, not identity.
uniform bool skywatch_stars_enabled = false;
uniform bool skywatch_faint_stars = true;
uniform sampler2D star_headers : filter_nearest, repeat_disable;
uniform sampler2D star_points : filter_nearest, repeat_disable;
uniform sampler2D star_properties : filter_nearest, repeat_disable;
uniform float star_epoch_years = 0.0; // years since baked 1929-01-01 positions
uniform float star_animation_seconds = 0.0;
uniform float camera_fov = 1.3613568; // vertical radians; optical frusta included
uniform float star_turbulence = .3;
uniform float star_aperture_m = .10;
uniform float star_diffraction_spikes = .05; // restrained artistic addition

float stellar_hash(vec3 p) {
    p=fract(p*.1031);p+=dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}
vec3 stellar_colour(float bv) {
    // Artistic spectral ramp in linear light; photometry stays independent.
    vec3 blue=vec3(.52,.73,1.0),silver=vec3(.88,.94,1.0);
    vec3 gold=vec3(1.0,.82,.49),ochre=vec3(1.0,.33,.075);
    if(bv<0.0) return mix(blue,silver,smoothstep(-.35,0.0,bv));
    if(bv<.65) return mix(silver,gold,smoothstep(0.0,.65,bv));
    return mix(gold,ochre,smoothstep(.65,1.8,bv));
}
float stellar_phase(float seconds,int cycles) {
    // Exact integer modular cycles avoid precision loss in a large trig angle.
    int whole=int(floor(seconds));
    float fraction=fract(seconds);
    float turns=float((whole*cycles)%4096)/4096.0+fraction*float(cycles)/4096.0;
    return fract(turns)*(2.0*PI);
}
float stellar_scintillation(float id,vec3 star,float altitude,float magnitude,float bv,out vec3 hue) {
    float seed=stellar_hash(star*901.0+vec3(id+bv*.23));
    // Integer cycles per 4096-second clock window keep the precision wrap
    // continuous, without locking different stars to a common phase.
    int speed=int(floor((1.0+3.0*seed)*4096.0));
    int secondary=int(floor((1.3+4.0*stellar_hash(star+id))*4096.0));
    float airmass=1.0/max(altitude,.05);
    float amplitude=clamp((airmass-1.0)*.022,.008,.34)*mix(.35,1.0,star_turbulence);
    amplitude*=mix(.6,1.0,1.0-smoothstep(-1.0,6.0,magnitude));
    float phase=seed*2.0*PI;
    float wave=.65*sin(stellar_phase(star_animation_seconds,speed)+phase)
        +.35*sin(stellar_phase(star_animation_seconds,secondary)+phase*5.7);
    hue=vec3(1.0+wave*amplitude*.32,1.0,1.0-wave*amplitude*.32);
    return max(.1,1.0+wave*amplitude);
}
float stellar_j1(float x) {
    if(x<7.0) {
        // Convergent J1 power series, evaluated only around bright optical PSFs.
        float term=x*.5,sum=term;
        for(int k=1;k<=12;k++) {
            term*=(-x*x)/(4.0*float(k)*float(k+1));sum+=term;
        }
        return sum;
    }
    float phase=x-.75*PI;
    return sqrt(2.0/(PI*x))*(cos(phase)*(1.0+15.0/(128.0*x*x))-sin(phase)*3.0/(8.0*x));
}
float stellar_psf(vec3 ray,vec3 star,float pixel_angle,float magnitude) {
    float angle=length(ray-star); // acos(dot) loses tiny angles in float32
    float optical=1.0-smoothstep(.012,.03,camera_fov);
    float diffraction=550e-9/max(star_aperture_m,.02);
    float sigma=max(pixel_angle*.62,diffraction*.35*optical);
    float gaussian=exp(-.5*angle*angle/(sigma*sigma));
    if(optical>.001 && magnitude<=1.0 && angle<max(pixel_angle*24.0,diffraction*12.0)) {
        float x=PI*angle/max(diffraction,pixel_angle*.6);
        float airy=x<.001 ? 1.0 : pow(2.0*stellar_j1(x)/x,2.0);
        vec3 right=normalize(cross(abs(star.z)>.95 ? vec3(0,1,0) : vec3(0,0,1),star));
        vec3 up=cross(star,right);
        vec2 p=vec2(dot(ray-star,right),dot(ray-star,up))/max(pixel_angle,diffraction*.25);
        float spikes=exp(-min(abs(p.x),abs(p.y))*2.0)/(1.0+pow(max(abs(p.x),abs(p.y))*.22,3.0));
        return mix(gaussian,airy+spikes*star_diffraction_spikes,optical);
    }
    return gaussian;
}
vec3 stellar_cube(vec3 n) {
    vec3 a=abs(n);vec2 uv;float face;
    if(a.x>=a.y && a.x>=a.z) {face=n.x>=0.0 ? 0.0 : 1.0;uv=vec2(n.x>=0.0 ? -n.z : n.z,n.y)/a.x;}
    else if(a.y>=a.z) {face=n.y>=0.0 ? 2.0 : 3.0;uv=vec2(n.x,n.y>=0.0 ? -n.z : n.z)/a.y;}
    else {face=n.z>=0.0 ? 4.0 : 5.0;uv=vec2(n.z>=0.0 ? n.x : -n.x,n.y)/a.z;}
    return vec3(uv,face);
}
vec3 stellar_cube_ray(vec2 uv,int face) {
    if(face==0) return normalize(vec3(1.0,uv.y,-uv.x));
    if(face==1) return normalize(vec3(-1.0,uv.y,uv.x));
    if(face==2) return normalize(vec3(uv.x,1.0,-uv.y));
    if(face==3) return normalize(vec3(uv.x,-1.0,uv.y));
    if(face==4) return normalize(vec3(uv.x,uv.y,1.0));
    return normalize(vec3(-uv.x,uv.y,-1.0));
}
vec3 stellar_bucket(vec3 query,vec3 ray,float pixel_angle,vec3 observer_up) {
    vec3 cube=stellar_cube(query);
    ivec2 cell=ivec2(clamp(floor((cube.xy*.5+.5)*64.0),vec2(0.0),vec2(63.0)));
    vec2 header=texelFetch(star_headers,ivec2(cell.x,cell.y+int(cube.z)*64),0).rg;
    vec3 result=vec3(0.0);
    for(int j=0;j<32;j++) {
        if(j>=int(header.y)) break; // actual BSC5 maximum 11, mean 0.37
        int index=int(header.x)+j;
        ivec2 uv=ivec2(index%512,index/512);
        vec4 point=texelFetch(star_points,uv,0);
        vec4 properties=texelFetch(star_properties,uv,0);
        vec3 star=normalize(point.xyz);
        vec3 east=normalize(vec3(-star.y,star.x,0.0));
        vec3 north=cross(star,east);
        star=normalize(star+(east*properties.y+north*properties.z)*star_epoch_years*(PI/(180.0*3600.0)));
        float psf=stellar_psf(ray,star,pixel_angle,point.w);
        if(psf<.00001) continue;
        float altitude=dot(star,observer_up);
        vec3 hue;
        float scintillation=stellar_scintillation(properties.w,star,altitude,point.w,properties.x,hue);
        float flux=pow(10.0,-.4*(point.w-1.0));
        float extinction=exp(-.065/max(altitude,.05));
        result+=stellar_colour(properties.x)*hue*flux*psf*scintillation*extinction*2.8;
    }
    return result;
}
vec3 stellar_faint_grid(vec3 ray,vec3 observer_up,float pixel_angle,float galactic_latitude) {
    const float frequency=900.0;
    vec3 cell=floor(ray*frequency);
    vec3 result=vec3(0.0);
    float selection=mix(.008,.035,exp(-abs(galactic_latitude)*9.0));
    for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        vec3 id=cell+vec3(float(x),float(y),float(z));
        float seed=stellar_hash(id);
        if(seed>selection) continue;
        vec3 p=id+vec3(stellar_hash(id+11.0),stellar_hash(id+23.0),stellar_hash(id+41.0));
        if(abs(length(p)-frequency)>.55) continue;
        vec3 star=normalize(p);
        float angle=length(ray-star);
        float psf=exp(-.5*pow(angle/max(pixel_angle*.52,1e-8),2.0));
        if(psf<.00001) continue;
        vec3 hue;
        float twinkle=stellar_scintillation(seed*2047.0,star,dot(star,observer_up),7.0,seed*1.8-.2,hue);
        result+=stellar_colour(seed*1.8-.2)*hue*psf*twinkle*.008;
    }
    return result;
}
vec3 stellar_light(vec3 equatorial,vec3 observer_up,float galactic_latitude) {
    vec3 ray=normalize(equatorial);
    float pixel_angle=max(length(dFdx(ray)),length(dFdy(ray)));
    pixel_angle=max(pixel_angle,1e-8);
    vec3 cube=stellar_cube(ray);
    vec2 fraction=fract((cube.xy*.5+.5)*64.0);
    float cutoff=max(pixel_angle*4.0,camera_fov<.03 ? 550e-9/max(star_aperture_m,.02)*12.0 : 0.0);
    float border=min(.49,cutoff*64.0*1.7+.004); // proper-motion/cube-edge guard
    vec3 result=vec3(0.0);
    int visited[9];int visited_count=0;
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        if(x<0 && fraction.x>border) continue;
        if(x>0 && fraction.x<1.0-border) continue;
        if(y<0 && fraction.y>border) continue;
        if(y>0 && fraction.y<1.0-border) continue;
        vec3 query=stellar_cube_ray(cube.xy+vec2(float(x),float(y))*(2.0/64.0),int(cube.z));
        vec3 query_cube=stellar_cube(query);
        ivec2 query_cell=ivec2(clamp(floor((query_cube.xy*.5+.5)*64.0),vec2(0.0),vec2(63.0)));
        int identity=(int(query_cube.z)*64+query_cell.y)*64+query_cell.x;
        bool duplicate=false;
        for(int v=0;v<9;v++) {
            if(v>=visited_count) break;
            if(visited[v]==identity) duplicate=true;
        }
        if(duplicate) continue;
        visited[visited_count]=identity;visited_count++;
        result+=stellar_bucket(query,ray,pixel_angle,observer_up);
    }
    if(skywatch_faint_stars) result+=stellar_faint_grid(ray,observer_up,pixel_angle,galactic_latitude);
    // A diffuse analytical Galactic band, not magnified stellar image texels.
    result+=vec3(.005,.007,.010)*exp(-abs(galactic_latitude)*22.0);
    return result;
}
