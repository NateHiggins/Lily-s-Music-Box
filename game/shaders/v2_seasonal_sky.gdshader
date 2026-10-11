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
float density(vec3 p) {
    float summer=season_weights.z;
    float winter=season_weights.x;
    float height=clamp((p.y-1.25)/mix(.60,3.0,summer),0.0,1.0);
    float deck=smoothstep(0.0,.12,height)*(1.0-smoothstep(.72,1.0,height));
    vec3 advected=p-wind_offset;
    float scale=mix(.30,.16,summer);
    vec2 n=textureLod(cloud_noise,advected*scale,0.0).rg;
    float erosion=textureLod(cloud_noise,advected*scale*4.3,0.0).g;
    float cover=clamp(cloud_coverage,0.0,1.0);
    float threshold=mix(.70,.34,cover);
    float shape=clamp((n.r-threshold)/.14,0.0,1.0);
    // Winter flattens the deck; summer's tall envelope and coarse base form towers.
    float stratus=mix(shape,.9,smoothstep(.65,.95,cover)*winter);
    float result=max(0.0,stratus-(1.0-erosion)*mix(.55,.07,winter))*deck;
    if (shape_kind>0 && shape_opacity>0.0) {
        vec3 q=advected-vec3(1.6,2.3,-2.6);
        float sdf=cloud_object(q);
        float edge_noise=textureLod(cloud_noise,q*1.8,0.0).g;
        float fluffy=1.0-smoothstep(-.045,.045,sdf+(edge_noise-.5)*.10);
        result=max(result,fluffy*.60*shape_opacity);
    }
    return result*mix(.85,1.4,max(winter,storm_strength));
}
vec4 volumetric_clouds(vec3 direction,vec2 screen_uv) {
    if (direction.y<.035) return vec4(0.0);
    float start=1.25/direction.y;
    float ceiling=1.85+3.0*season_weights.z;
    if (shape_kind>0 && shape_opacity>0.0) ceiling=max(ceiling,3.15);
    float finish=min(18.0,ceiling/direction.y);
    int steps=(shape_kind>0 && shape_opacity>0.0) ? 64 : 40;
    float step_size=(finish-start)/float(steps);
    // Stratified per-pixel jitter removes slab bands. The engine's TAA owns
    // camera reprojection/history; this shader does not fabricate a history buffer.
    float jitter=fract(sin(dot(screen_uv*vec2(1280.0,720.0),vec2(12.9898,78.233))
        +temporal_phase*13.17)*43758.5453);
    vec3 sum=vec3(0.0); float transmittance=1.0;
    vec3 source=normalize(sun_direction);
    float day=smoothstep(-.12,.1,source.y);
    vec3 diffuse=mix(fog_horizon_color*.95,vec3(.61,.68,.80),day);
    for (int i=0;i<64;i++) {
        if (i>=steps) break;
        vec3 p=direction*(start+(float(i)+jitter)*step_size);
        float d=density(p);
        if (d>.005) {
            float shadow=exp(-density(p+source*.12)*2.5-density(p+source*.35)*1.4);
            float alpha=1.0-exp(-d*step_size*5.0);
            vec3 lit=diffuse*.38+celestial_color*day*shadow*.80;
            lit+=vec3(.34,.18,.075)*urban_horizon_gain*.12;
            sum+=lit*alpha*transmittance;
            transmittance*=1.0-alpha;
            if (transmittance<.005) break;
        }
    }
    float horizon_fade=smoothstep(.025,.10,direction.y);
    return vec4(sum*horizon_fade,(1.0-transmittance)*horizon_fade);
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
        COLOR=base*(1.0-HALF_RES_COLOR.a)+HALF_RES_COLOR.rgb;
    }
}
