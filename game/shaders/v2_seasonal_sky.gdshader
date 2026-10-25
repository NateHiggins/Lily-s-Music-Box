shader_type sky;
render_mode use_half_res_pass, disable_fog;
uniform sampler2D panorama_a : source_color, filter_linear_mipmap,
		repeat_enable;
uniform sampler2D panorama_b : source_color, filter_linear_mipmap,
		repeat_enable;
uniform bool panorama_a_celestial = false;
uniform bool panorama_b_celestial = false;
uniform vec3 equatorial_axis_x = vec3(1.0, 0.0, 0.0);
uniform vec3 equatorial_axis_y = vec3(0.0, 1.0, 0.0);
uniform vec3 equatorial_axis_z = vec3(0.0, 0.0, 1.0);
uniform float sky_blend = 0.0;
uniform float exposure = 0.76;
uniform vec3 fog_horizon_color = vec3(0.05, 0.06, 0.10);
uniform vec3 celestial_direction = vec3(0.0, 0.6, -0.8);
uniform vec3 sun_direction = vec3(0.0, -0.6, 0.8);
uniform vec3 celestial_color = vec3(0.60, 0.68, 0.88);
uniform float celestial_strength = 0.30;
uniform float celestial_core_radius = 0.038;
uniform float celestial_halo_radius = 0.31;
uniform bool moon_phase_enabled = false;
uniform float moon_illumination = 1.0;
uniform sampler2D moon_surface : source_color, filter_linear_mipmap,
		repeat_enable;
uniform float ray_strength = 0.0;
uniform float lower_cloud_strength = 0.28;
uniform float cloud_coverage = 0.28;
uniform float high_cloud_strength = 0.0;
uniform float cloud_phase = 0.0;
uniform vec3 cloud_wind_direction = vec3(1.0, 0.0, 0.0);
uniform float cloud_wind_speed = 8.0;
uniform float weather_flash = 0.0;
uniform vec3 bright_stars[12];
uniform float star_strength = 0.0;
uniform float urban_horizon_gain = 0.0;
uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cirrus_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 season_weights = vec4(0.0,0.0,0.0,1.0);
uniform float humidity = 0.52;
uniform float storm_strength = 0.0;
uniform vec3 wind_offset = vec3(0.0);
uniform int shape_kind = 0;
uniform float shape_opacity = 0.0;
uniform float temporal_phase = 0.0;
// Spectacle (data/weather/phenomena.json via WeatherManager): one intensity
// and one bearing per phenomenon slot. Zero costs a uniform branch, no node.
uniform float spectacle[41];
uniform float spectacle_bearing[41];
uniform float spectacle_time = 0.0;
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


vec3 celestial_base(vec3 direction) {
	float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	// Half-dome source: top edge is zenith; bottom edge is horizon.
	// Views below the horizon hold on that final skyline texel instead of
	// exposing the dome's lower half. Fade that edge into distance haze
	// immediately so skyline pixels never stretch into vertical bars.
	float elevation = asin(clamp(direction.y, 0.0, 1.0));
	float v = 1.0 - elevation / (0.5 * PI);
	// A measured night map lives in inertial Galactic coordinates, not on the
	// building. Recover J2000 equatorial direction from the observer's local
	// horizon basis, then apply the standard IAU equatorial-to-Galactic matrix.
	vec3 equatorial = vec3(dot(direction, equatorial_axis_x),
			dot(direction, equatorial_axis_y),
			dot(direction, equatorial_axis_z));
	vec3 galactic = mat3(
			vec3(-0.0548755604, 0.4941094279, -0.8676661490),
			vec3(-0.8734370902, -0.4448296300, -0.1980763734),
			vec3(-0.4838350155, 0.7469822445, 0.4559837762)) * equatorial;
	vec2 galactic_uv = vec2(atan(galactic.y, galactic.x)
			/ (2.0 * PI) + 0.5,
			0.5 - asin(clamp(galactic.z, -1.0, 1.0)) / PI);
	vec4 authored_a = texture(panorama_a,
			panorama_a_celestial ? galactic_uv : vec2(u, v));
	vec4 authored_b = texture(panorama_b,
			panorama_b_celestial ? galactic_uv : vec2(u, v));
	vec4 authored = mix(authored_a, authored_b, sky_blend);
	float high_opacity = 0.0;
	float thickness = 0.0;
	vec3 color = authored.rgb * exposure;
	// Rayleigh angular phase and Henyey-Greenstein Mie halo, intentionally
	// overdriven at twilight. PhysicalSky mechanics, not a second sky owner.
	float mu = dot(direction,normalize(sun_direction));
	float daylight = smoothstep(-0.12,0.12,sun_direction.y);
	float twilight = (1.0-smoothstep(0.03,0.28,abs(sun_direction.y)))*daylight;
	float rayleigh = 0.75*(1.0+mu*mu);
	float g = mix(0.68,0.86,humidity);
	float mie = (1.0-g*g)/max(0.04,pow(1.0+g*g-2.0*g*mu,1.5));
	float horizon = pow(1.0-clamp(direction.y,0.0,1.0),3.0);
	vec3 blue = mix(vec3(0.075,0.20,0.48),vec3(0.018,0.075,0.34),season_weights.w);
	vec3 atmosphere = blue*rayleigh*(0.65+direction.y*.65);
	atmosphere += vec3(1.0,.82,.57)*mie*humidity*.045;
	atmosphere = mix(atmosphere,vec3(.84,.19,.16)*rayleigh+vec3(.65,.08,.45)*(1.0-mu)*.25,twilight*horizon*.82);
	color = mix(color,atmosphere,daylight);
	float source_angle = acos(clamp(dot(direction,
			normalize(celestial_direction)), -1.0, 1.0));
	float halo = 1.0 - smoothstep(celestial_core_radius,
			celestial_halo_radius, source_angle);
	float core = 1.0 - smoothstep(0.0, celestial_core_radius, source_angle);
	vec3 lunar_surface = vec3(1.0);
	if (moon_phase_enabled) {
		// Project the visible hemisphere and light it from the real Sun vector.
		// This draws crescent/gibbous geometry in the existing sky submission;
		// illumination is not a circular opacity mask.
		vec3 moon = normalize(celestial_direction);
		vec3 reference = abs(moon.y) > 0.96 ? vec3(1.0, 0.0, 0.0)
				: vec3(0.0, 1.0, 0.0);
		vec3 right = normalize(cross(reference, moon));
		vec3 disc_up = normalize(cross(moon, right));
		float radius_sine = max(sin(celestial_core_radius), 0.00001);
		vec2 disc = vec2(dot(direction, right), dot(direction, disc_up))
				/ radius_sine;
		float radial2 = dot(disc, disc);
		float sphere_z = sqrt(max(0.0, 1.0 - radial2));
		vec3 surface_normal = normalize(right * disc.x + disc_up * disc.y
				- moon * sphere_z);
		float sunlit = smoothstep(-0.018, 0.018,
				dot(surface_normal, normalize(sun_direction)));
		float disc_edge = 1.0 - smoothstep(0.96, 1.0, sqrt(radial2));
		core = disc_edge * sunlit;
		// NASA LROC's cylindrical map is centered on the familiar near side.
		// Keep lunar north upright; libration is deliberately outside this
		// visual ephemeris, but geography is measured rather than invented.
		float lunar_lon = atan(disc.x, sphere_z);
		float lunar_lat = asin(clamp(disc.y, -1.0, 1.0));
		vec2 lunar_uv = vec2(lunar_lon / (2.0 * PI) + 0.5,
				0.5 - lunar_lat / PI);
		lunar_surface = texture(moon_surface, lunar_uv).rgb;
		halo *= sqrt(max(moon_illumination, 0.0));
	}
	float obscured = pow(1.0 - thickness, 2.4)
			* (1.0 - high_opacity * 0.78);
	float star_field = 0.0;
	for (int i = 0; i < 12; i++) {
		float star_dot = dot(direction, normalize(bright_stars[i]));
		star_field = max(star_field, smoothstep(0.99991, 0.99998, star_dot));
	}
	color += vec3(0.76, 0.82, 1.0) * star_field * star_strength * obscured;
	color += celestial_color * celestial_strength * halo * 0.42 * obscured;
	color += celestial_color * lunar_surface * celestial_strength
			* core * 0.48 * obscured;
	// Rare, vague fingers belong to the same hidden source. Cloud density
	// breaks them up; no crisp radial god-ray fan survives the rain.
	float fingers = pow(max(0.0, sin((u * 18.0 + cloud_phase) * 2.0 * PI)), 12.0);
	color += celestial_color * ray_strength * fingers * halo
			* (1.0 - thickness) * 0.18;
	// Long atmospheric paths extinguish stars before the zenith. This also
	// keeps any equirectangular pole stretch out of the playable horizon.
	float horizon_haze = smoothstep(0.60, 0.96, v);
	color = mix(color, fog_horizon_color, horizon_haze * 0.82);
	// Queens never owns a coal-black horizon. Keep the glow shallow so the
	// measured Milky Way survives overhead while distant building feet belong
	// to the same atmosphere as their silhouettes.
	float urban_band = smoothstep(0.72, 1.0, v);
	vec3 urban_glow = mix(vec3(0.055, 0.042, 0.036),
			fog_horizon_color * 1.35, 0.42);
	color += urban_glow * urban_horizon_gain * urban_band * 0.72;
	color += celestial_color * weather_flash * (0.09 + (1.0 - thickness) * 0.14);
	if (direction.y < 0.0) {
		float haze = smoothstep(0.0, 0.025, -direction.y);
		vec3 lower_air = fog_horizon_color
				* (0.34 + urban_horizon_gain * 0.74);
		color = mix(color, lower_air, haze);
	}
	return color;
}

float ellipsoid(vec3 p,vec3 radii) {
    float k0=length(p/radii);
    float k1=length(p/(radii*radii));
    if (k0<.00001) return -min(radii.x,min(radii.y,radii.z));
    return k0*(k0-1.0)/max(k1,.00001);
}
float soft_union(float a,float b,float k) {
    float h=clamp(.5+.5*(b-a)/k,0.0,1.0);
    return mix(b,a,h)-k*h*(1.0-h);
}
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
    // A grid of smooth spheres hung under the storm base, smooth-min blended
    // into an inverted-noise underside: pouches, not a lumpy floor.
    float cell_size=.30;
    vec2 g=(p.xz-wind_offset.xz*.4)/cell_size;
    vec2 cell=floor(g); vec2 f=fract(g)-.5;
    float j=hash12(cell);
    vec3 q=vec3(f.x*cell_size,p.y-(1.18-.05*j),f.y*cell_size);
    float pouch=length(q*vec3(1.0,.82,1.0))-.125*(.78+.44*j);
    float n=textureLod(cloud_noise,(p-wind_offset)*.75,0.0).r;
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
    float h=clamp((q.y-1.0)/7.0,0.0,1.0);
    float tower=(1.0-smoothstep(1.2+.5*h,1.6+.5*h+.4*n,length(q.xz)))*smoothstep(.95,1.2,q.y)*(1.0-smoothstep(7.4,7.8,q.y));
    // The anvil spreads downwind under the tropopause lid.
    vec2 a=vec2((q.x-2.2)/6.5,q.z/3.5);
    float anvil=(1.0-smoothstep(.8,1.05,length(a)+(n-.5)*.25))*smoothstep(6.8,7.1,q.y)*(1.0-smoothstep(7.5+.3*n,7.9,q.y));
    float dome=0.0;
    if (spectacle[S_OVERSHOOT]>0.0) {
        // Overshooting top: the updraft's dome punching through the lid.
        dome=(1.0-smoothstep(-.04,.06,ellipsoid(q-vec3(0.0,7.75,0.0),vec3(1.1,.75,1.1))+(n-.5)*.15))*spectacle[S_OVERSHOOT];
    }
    albedo=vec3(.87,.87,.87);
    return max(max(tower*(.6+.5*n),anvil),dome);
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
    if (spectacle[S_TORNADO]>0.0) { d=vortex(raw,S_TORNADO,a)*1.6*spectacle[S_TORNADO]; if (d>best) { best=d; albedo=a; thin=true; } }
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
            float shade=exp(-objects_at(p+source*.18,a2,g2)*2.2);
            float alpha=1.0-exp(-d*dt*4.5);
            vec3 lit=albedo*(ambient*.45+celestial_color*day*shade*.85)*mix(vec3(1.0),vec3(.30,.33,.39),smoothstep(.05,.55,storm_strength))+glow;
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
    vec3 film=.55+.45*cos(6.2832*(thickness*1.7+vec3(0.0,.33,.67)));
    return mix(vec3(.9,.86,.9),film,.78)*lens*near*band*lit*1.5;
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
    float seed=floor(spectacle_time*7.0);
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
        float trunk=exp(-pow((x+.6*sin(e*.7))/(.2+1.6*h*h),2.0))*step(3.0,e)*(1.0-smoothstep(15.0,18.0,e));
        float branches=smoothstep(.55,.8,vnoise(vec2(x*2.0,e*1.5)))*smoothstep(10.0,14.0,e)
            *(1.0-smoothstep(16.0,18.5,e))*exp(-pow(x/4.0,2.0));
        total+=(mix(vec3(.35,.5,1.0),vec3(1.0,.25,.35),h)*trunk*1.8+vec3(1.0,.3,.4)*branches)*spectacle[S_GIGANTIC_JET];
    }
    if (spectacle[S_ELVES]>0.0) {
        // ELVES: a red ring expanding at the foot of the ionosphere.
        vec3 centre=normalize(bearing_axis(S_ELVES)+vec3(0.0,.12,0.0));
        float radius=radians(6.0+10.0*hash12(vec2(seed,9.0)));
        float ring=exp(-pow((angle_between(dir,centre)-radius)/radians(1.6),2.0))*smoothstep(.02,.08,dir.y);
        total+=vec3(1.0,.22,.18)*ring*1.4*spectacle[S_ELVES];
    }
    return total;
}

// --- Optics ------------------------------------------------------------------------
vec3 ice_optics(vec3 dir) {
    vec3 sun=normalize(sun_direction);
    float theta=degrees(angle_between(dir,sun));
    float es=sun_elevation_degrees();
    float e=elevation_degrees(dir);
    float daz=wrap_pi(azimuth_of(dir)-azimuth_of(sun));
    float veil=.55+.45*texture(cirrus_tex,dir.xz/max(dir.y,.1)*.2-wind_offset.xz*.14).r;
    vec3 total=vec3(0.0);
    if (spectacle[S_HALO]>0.0) {
        // 22 degree halo: a sharp red inner rim fading white-blue outward.
        float ring=smoothstep(21.4,22.2,theta)*exp(-max(theta-22.2,0.0)/1.1);
        vec3 c=mix(vec3(1.0,.45,.25),vec3(.85,.9,1.0),smoothstep(22.0,24.5,theta));
        total+=c*ring*.6*spectacle[S_HALO]*veil;
    }
    if (spectacle[S_SUN_DOGS]>0.0) {
        // Parhelia at the sun's altitude, pushed outward as the sun climbs.
        float er=radians(es); float sep=radians(22.0+es*.12);
        float offset=acos(clamp((cos(sep)-sin(er)*sin(er))/max(cos(er)*cos(er),.01),-1.0,1.0));
        for (int k=-1;k<=1;k+=2) {
            float x=degrees(wrap_pi(daz-float(k)*offset))*cos(er)*float(k);
            float de=e-es;
            float spot=exp(-pow(x/.9,2.0)-pow(de/1.6,2.0));
            float tail=step(0.0,x)*exp(-x/5.0)*exp(-pow(de/.7,2.0))*.35;
            vec3 c=mix(vec3(1.0,.35,.2),vec3(1.0,.95,.85),smoothstep(-1.0,1.2,x));
            total+=(c*spot*1.4+vec3(1.0)*tail)*spectacle[S_SUN_DOGS];
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
    if (spectacle[S_PILLARS]>0.0) {
        // A sun pillar standing on the low sun, and at night pillars over the
        // city lamps, raised by plate crystals settling in still frost.
        float x=degrees(daz);
        float column=exp(-pow(x/.55,2.0))*smoothstep(es-1.0,es+.5,e)*exp(-max(e-es,0.0)/9.0)*smoothstep(-6.0,-1.0,es);
        total+=vec3(1.0,.62,.32)*column*1.6*spectacle[S_PILLARS];
        float night=1.0-smoothstep(-8.0,-3.0,es);
        float lamp_az=degrees(azimuth_of(dir))*.8;
        float cell=floor(lamp_az); float j=hash12(vec2(cell,4.0));
        float lamp=step(.82,j)*exp(-pow((fract(lamp_az)-.5)/.07,2.0))*smoothstep(1.0,2.0,e)*exp(-max(e-2.0,0.0)/(4.0+6.0*j));
        total+=mix(vec3(1.0,.78,.5),vec3(.85,.9,1.0),hash12(vec2(cell,7.0)))*lamp*night*1.2*spectacle[S_PILLARS];
    }
    return total;
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
    float seed=floor(spectacle_time*.5);
    vec2 w=uv+vec2(fbm2(uv*1.3+seed),fbm2(uv*1.3-seed))*.9;
    float trunk=voronoi_edge(w*.9+seed*3.7);
    float twig=voronoi_edge(w*3.1+seed*1.3);
    float flash=spectacle[S_CRAWLER];
    float reach=1.0-smoothstep(1.5,7.0+5.0*(1.0-flash),length(uv-origin));
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
// Behind the lower clouds: the high layers, electricity above the storm, ice optics.
vec3 spectacle_behind(vec3 dir,vec3 colour) {
    if (spectacle[S_NOCTILUCENT]>0.0) colour+=noctilucent(dir)*spectacle[S_NOCTILUCENT];
    if (spectacle[S_NACREOUS]>0.0) colour+=nacreous(dir)*spectacle[S_NACREOUS];
    if (spectacle[S_AURORA]>0.0) colour+=aurora(dir)*spectacle[S_AURORA];
    if (spectacle[S_STEVE]>0.0) colour+=steve(dir)*spectacle[S_STEVE];
    if (spectacle[S_SPRITE]+spectacle[S_BLUE_JET]+spectacle[S_GIGANTIC_JET]+spectacle[S_ELVES]>0.0)
        colour+=transient_luminous(dir);
    if (spectacle[S_HALO]+spectacle[S_SUN_DOGS]+spectacle[S_CHA]+spectacle[S_CZA]+spectacle[S_PILLARS]>0.0)
        colour+=ice_optics(dir);
    if (spectacle[S_CREPUSCULAR]+spectacle[S_ANTICREPUSCULAR]>0.0) colour+=sun_beams(dir);
    if (spectacle[S_GREEN_FLASH]>0.0) colour+=green_flash(dir);
    if (spectacle[S_FATA_MORGANA]>0.0) colour=fata_morgana(dir,colour);
    if (spectacle[S_GLORY]>0.0) colour+=glory(dir);
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
float cloud_object(vec3 p) {
    // Soft SDFs. Noise breaks the contour before it contributes to density.
    if (shape_kind==1) {
        float body=ellipsoid(p,vec3(.48,.30,.30));
        float head=ellipsoid(p-vec3(.29,.38,0),vec3(.21,.23,.21));
        float bill=ellipsoid(p-vec3(.49,.33,0),vec3(.20,.055,.12));
        float neck=ellipsoid(p-vec3(.23,.22,0),vec3(.16,.24,.17));
        return soft_union(soft_union(soft_union(body,neck,.10),head,.10),bill,.06);
    }
    if (shape_kind==2) {
        float body=ellipsoid(p,vec3(.75,.25,.29));
        float fin=ellipsoid(p-vec3(.0,-.18,.18),vec3(.25,.16,.06));
        float tail=ellipsoid(p-vec3(-.69,.10,0),vec3(.15,.15,.36));
        return soft_union(soft_union(body,fin,.08),tail,.08);
    }
    float ship=ellipsoid(p+vec3(0,.24,0),vec3(.75,.20,.23));
    for (int mast_index=0;mast_index<3;mast_index++) {
        float x=(float(mast_index)-1.0)*.36;
        float mast=ellipsoid(p-vec3(x,.10,0),vec3(.032,.46,.04));
        float sail=ellipsoid(p-vec3(x+.04,.22,0),vec3(.16,.25,.07));
        ship=soft_union(ship,soft_union(mast,sail,.035),.035);
    }
    return ship;
}
float density_tagged(vec3 p,out float fire) {
    fire=0.0;
    float summer=season_weights.z;
    float winter=season_weights.x;
    vec3 pd=p;
    if (spectacle[S_ASPERITAS]>0.0) pd.y-=asperitas_shift(p)*spectacle[S_ASPERITAS];
    float height=clamp((pd.y-1.25)/mix(.60,3.0,summer),0.0,1.0);
    float deck=smoothstep(0.0,.12,height)*(1.0-smoothstep(.72,1.0,height));
    vec3 advected=p-wind_offset;
    float scale=mix(.30,.16,summer);
    vec2 n=textureLod(cloud_noise,advected*scale,0.0).rg;
    float erosion=textureLod(cloud_noise,advected*scale*4.3,0.0).g;
    float cover=clamp(cloud_coverage,0.0,1.0);
    if (spectacle[S_ASPERITAS]>0.0) cover=max(cover,.82*spectacle[S_ASPERITAS]);
    float threshold=mix(.70,.34,cover);
    float shape=clamp((n.r-threshold)/.14,0.0,1.0);
    // Winter flattens the deck; summer's tall envelope and coarse base form towers.
    float stratus=mix(shape,.9,smoothstep(.65,.95,cover)*winter);
    float result=max(0.0,stratus-(1.0-erosion)*mix(.55,.07,winter))*deck;
    if (spectacle[S_FALLSTREAK]>0.0) {
        float streak;
        float hole=fallstreak(p,streak);
        result=max(mix(result,result*hole,spectacle[S_FALLSTREAK]),streak*.5*spectacle[S_FALLSTREAK]);
    }
    if (spectacle[S_VIRGA]>0.0) result=max(result,virga(p)*spectacle[S_VIRGA]);
    if (spectacle[S_MAMMATUS]>0.0 && p.y<1.42 && p.y>.85) {
        float pouches=mammatus(p)*spectacle[S_MAMMATUS];
        fire=pouches/max(max(result,pouches),.001);
        result=max(result,pouches);
    }
    if (shape_kind>0 && shape_opacity>0.0) {
        vec3 q=advected-vec3(1.6,2.3,-2.6);
        float sdf=cloud_object(q);
        float edge_noise=textureLod(cloud_noise,q*1.8,0.0).g;
        float fluffy=1.0-smoothstep(-.045,.045,sdf+(edge_noise-.5)*.10);
        result=max(result,fluffy*.60*shape_opacity);
    }
    return result*mix(.85,1.4,max(winter,storm_strength));
}
float density(vec3 p) {
    float fire;
    return density_tagged(p,fire);
}
vec4 volumetric_clouds(vec3 direction,vec2 screen_uv) {
    if (direction.y<.005) return vec4(0.0);
    // Stratified per-pixel jitter removes slab bands. The engine's TAA owns
    // camera reprojection/history; this shader does not fabricate a history buffer.
    float jitter=fract(sin(dot(screen_uv*vec2(1280.0,720.0),vec2(12.9898,78.233))
        +temporal_phase*13.17)*43758.5453);
    // Pouches and fallstreaks hang below the deck: start the march lower.
    float base_low=1.25;
    if (spectacle[S_MAMMATUS]>0.0) base_low=.88;
    if (spectacle[S_VIRGA]+spectacle[S_FALLSTREAK]>0.0) base_low=.40;
    float start=base_low/max(direction.y,.035);
    vec4 deck=vec4(0.0);
    if (direction.y>=.035) {
        float ceiling=1.85+3.0*season_weights.z;
        if (shape_kind>0 && shape_opacity>0.0) ceiling=max(ceiling,3.15);
        float finish=min(18.0,ceiling/direction.y);
        int steps=(shape_kind>0 && shape_opacity>0.0) || base_low<1.25 ? 64 : 40;
        float step_size=(finish-start)/float(steps);
        vec3 sum=vec3(0.0); float transmittance=1.0;
        vec3 source=normalize(sun_direction);
        float day=smoothstep(-.12,.1,source.y);
        vec3 diffuse=mix(fog_horizon_color*.95,vec3(.61,.68,.80),day);
        // Noctilucent twilight leaves the lower clouds black against the glow; an
        // ash wall browns them; a low sun sets mammatus pouches alight from below.
        float spectacle_dark=1.0-.9*noctilucent_light()*spectacle[S_NOCTILUCENT];
        vec3 dust_tint=mix(vec3(1.0),vec3(.80,.60,.38),spectacle[S_HABOOB]);
        float gold=smoothstep(.24,0.0,source.y)*smoothstep(-.10,.01,source.y);
        for (int i=0;i<64;i++) {
            if (i>=steps) break;
            vec3 p=direction*(start+(float(i)+jitter)*step_size);
            float fire;
            float d=density_tagged(p,fire);
            if (d>.005) {
                float shadow=exp(-density(p+source*.12)*2.5-density(p+source*.35)*1.4);
                float alpha=1.0-exp(-d*step_size*5.0);
                vec3 lit=diffuse*.38+celestial_color*day*shadow*.80;
                lit+=vec3(.34,.18,.075)*urban_horizon_gain*.12;
                // Pouches are lit from below by a low sun, dark slate otherwise.
                lit=mix(lit,mix(diffuse*.30,vec3(1.0,.40,.14)*(.35+.8*shadow),gold),fire*.9);
                lit*=spectacle_dark*dust_tint*mix(vec3(1.0),vec3(.20,.23,.29),smoothstep(.05,.55,storm_strength));
                // Asperitas: troughs of the rough sea fall into shadow, crests catch light.
                if (spectacle[S_ASPERITAS]>0.0) lit*=1.0+asperitas_shift(p)*1.8*spectacle[S_ASPERITAS];
                sum+=lit*alpha*transmittance;
                transmittance*=1.0-alpha;
                if (transmittance<.005) break;
            }
        }
        float horizon_fade=smoothstep(.025,.10,direction.y);
        deck=vec4(sum*horizon_fade,(1.0-transmittance)*horizon_fade);
    }
    if (any_objects()) {
        float near_t;
        vec4 objects=spectacle_objects(direction,jitter,near_t)*smoothstep(.005,.03,direction.y);
        if (near_t<start) deck=vec4(objects.rgb+deck.rgb*(1.0-objects.a),objects.a+deck.a*(1.0-objects.a));
        else deck=vec4(deck.rgb+objects.rgb*(1.0-deck.a),deck.a+objects.a*(1.0-deck.a));
    }
    return deck;
}
void sky() {
    if (AT_CUBEMAP_PASS) {
        // Never raymarch the six reflection faces. Uniform animation invalidates
        // radiance, so this cheap approximation is deliberate.
		COLOR=fog_horizon_color*(.9+max(0.0,EYEDIR.y))
			+vec3(.035,.075,.15)*smoothstep(-.12,.12,sun_direction.y)*(1.0-cloud_coverage);
    } else if (AT_HALF_RES_PASS) {
        vec4 clouds=volumetric_clouds(EYEDIR,SCREEN_UV);
        COLOR=clouds.rgb; ALPHA=clouds.a;
    } else {
        vec3 base=celestial_base(EYEDIR);
        vec2 uv=EYEDIR.xz/max(.15,EYEDIR.y)*.14-wind_offset.xz*.14;
        float cirrus=texture(cirrus_tex,uv).r*high_cloud_strength*mix(.16,.45,season_weights.w);
        cirrus*=smoothstep(.04,.18,EYEDIR.y);
        base=mix(base,fog_horizon_color*1.4+celestial_color*.12,cirrus);
        base=spectacle_behind(EYEDIR,base);
        base*=mix(vec3(1.0),vec3(.42,.45,.52),smoothstep(.05,.55,storm_strength));
        COLOR=base*(1.0-HALF_RES_COLOR.a)+HALF_RES_COLOR.rgb;
        COLOR=spectacle_front(EYEDIR,COLOR,HALF_RES_COLOR.a);
    }
}
