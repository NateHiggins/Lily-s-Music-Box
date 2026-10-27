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
#include "res://shaders/sky_spectacle.gdshaderinc"
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
        float finish=min(18.0,ceiling/direction.y);
        int steps=base_low<1.25 ? 64 : 40;
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
