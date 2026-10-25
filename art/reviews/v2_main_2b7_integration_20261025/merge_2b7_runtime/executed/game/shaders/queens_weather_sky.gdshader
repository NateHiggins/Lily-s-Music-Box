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
#include "res://shaders/queens_weather_math.gdshaderinc"


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
	atmosphere += wx_mie_color(vec3(1.0,.82,.57),normalize(sun_direction))*mie*humidity*.045;
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
    float base=wx_cloud_base();
    float thickness=mix(0.60,3.0,season_weights.z);
    vec3 advected=wx_cyclone_warp(p-wind_offset);
    float bottom=base;
    if(wx_formation==1) bottom=mix(base,wx_asperitas_bottom(advected,base),wx_formation_strength);
    vec3 q=advected;
    if(spectacle[S_ASPERITAS]>0.0) q.y-=asperitas_shift(p)*spectacle[S_ASPERITAS];
    if(wx_formation==2) q=mix(q,wx_fluctus_warp(q,base,base+thickness),wx_formation_strength);
    float h=(q.y-bottom)/thickness;
    float deck=smoothstep(0.0,0.12,h)*(1.0-smoothstep(0.72,1.0,h));
    float result=0.0;
    if(deck>0.001) {
        float scale=mix(0.30,0.16,season_weights.z);
        vec2 n=textureLod(cloud_noise,q*scale,0.0).rg;
        float erosion=textureLod(cloud_noise,q*scale*4.3,0.0).g;
        float cover=max(cloud_coverage,0.96*max(vortex_intensity,wx_cyclone));
        cover=max(cover,0.82*spectacle[S_ASPERITAS]);
        if(wx_formation==1) cover=max(cover,0.96*wx_formation_strength);
        float shape=clamp((n.r-mix(0.70,0.34,cover))/0.14,0.0,1.0);
        float sheet=max(season_weights.x,max(wx_hail,max(wx_cyclone,vortex_intensity)));
        if(wx_formation==1) sheet=max(sheet,wx_formation_strength);
        shape=mix(shape,0.94,smoothstep(0.65,0.95,cover)*sheet);
        result=max(0.0,shape-(1.0-erosion)*mix(0.55,0.07,sheet))*deck;
    }
    if(spectacle[S_FALLSTREAK]>0.0) {
        float streak;
        float hole=fallstreak(p,streak);
        result=max(mix(result,result*hole,spectacle[S_FALLSTREAK]),streak*.5*spectacle[S_FALLSTREAK]);
    }
    if(spectacle[S_VIRGA]>0.0) result=max(result,virga(p)*spectacle[S_VIRGA]);
    if(spectacle[S_MAMMATUS]>0.0 && p.y<1.42 && p.y>.85) {
        float pouches=mammatus(p)*spectacle[S_MAMMATUS];
        fire=pouches/max(max(result,pouches),.001);
        result=max(result,pouches);
    }
    if(wx_formation==3) result=max(result,wx_lenticular_density(p)*wx_formation_strength);
    if(wx_formation==2) result=max(result,wx_fluctus_density(p)*wx_formation_strength);
    if(shape_kind>0 && shape_opacity>0.0) {
        vec3 animal=advected-vec3(1.6,2.3,-2.6);
        float sdf=cloud_object(animal);
        float erosion=textureLod(cloud_noise,animal*1.8,0.0).g;
        result=max(result,(1.0-smoothstep(-0.045,0.045,sdf+(erosion-0.5)*0.10))*0.60*shape_opacity);
    }
    result*=mix(0.85,1.5,max(season_weights.x,max(storm_strength,wx_hail)));
    return max(result,wx_vortex_density(p,base));
}
float density(vec3 p) {
    float fire;
    return density_tagged(p,fire);
}
vec4 wx_volumetric_clouds(vec3 direction,vec2 screen_uv) {
    vec3 ro=wx_camera_km;
    float base=wx_cloud_base();
    if(spectacle[S_MAMMATUS]>0.0) base=min(base,.88);
    if(spectacle[S_VIRGA]+spectacle[S_FALLSTREAK]>0.0) base=min(base,.40);
    float ceiling=base+mix(0.60,3.0,season_weights.z);
    if(shape_kind>0 && shape_opacity>0.0) ceiling=max(ceiling,3.15);
    if(wx_formation==3) ceiling=max(ceiling,wx_lens_center.y+0.55);
    if(wx_formation==2) ceiling=max(ceiling,2.80);
    vec2 deck=vec2(100000.0,-1.0);
    if(direction.y>0.0001) {
        deck=vec2(max(0.0,(base-0.50-ro.y)/direction.y),min(18.0,(ceiling-ro.y)/direction.y));
        if(deck.y<=deck.x) deck=vec2(100000.0,-1.0);
    }
    vec2 funnel=vec2(100000.0,-1.0);
    if(vortex_intensity>0.001) {
        funnel=wx_ray_box(ro,direction,
            vec3(wx_vortex_center.x-0.50,0.002,wx_vortex_center.y-0.50),
            vec3(wx_vortex_center.x+0.50,base+0.36,wx_vortex_center.y+0.50));
        funnel.x=max(funnel.x,0.0); funnel.y=min(funnel.y,18.0);
        if(funnel.y<=funnel.x) funnel=vec2(100000.0,-1.0);
    }
    if(wx_formation==3 && wx_formation_strength>0.001) {
        vec2 lenses=wx_ray_box(ro,direction,wx_lens_center+vec3(-0.80,-0.10,-0.50),wx_lens_center+vec3(0.90,0.55,0.60));
        lenses.x=max(lenses.x,0.0);lenses.y=min(lenses.y,18.0);
        if(lenses.y>lenses.x) funnel=vec2(min(funnel.x,lenses.x),max(funnel.y,lenses.y));
    }
    if(wx_formation==2 && wx_formation_strength>0.001) {
        vec2 waves=wx_ray_box(ro,direction,vec3(-3.3,2.15,-4.4),vec3(1.3,2.8,-3.6));
        waves.x=max(waves.x,0.0);waves.y=min(waves.y,18.0);
        if(waves.y>waves.x) funnel=vec2(min(funnel.x,waves.x),max(funnel.y,waves.y));
    }
    float t=min(deck.x,funnel.x), finish=max(deck.y,funnel.y);
    if(t>=finish) return vec4(0.0);
    float base_steps=(shape_kind>0 && shape_opacity>0.0) ? 64.0 : 40.0;
    float coarse=max(0.02,(deck.y-deck.x)/base_steps);
    float fine=max(0.0125,(funnel.y-funnel.x)/80.0);
    float jitter=fract(sin(dot(screen_uv*vec2(1280.0,720.0),vec2(12.9898,78.233))+temporal_phase*13.17)*43758.5453);
    vec3 source=normalize(sun_direction);
    float day=smoothstep(-0.12,0.10,source.y);
    vec3 ambient=mix(fog_horizon_color*0.95,vec3(0.61,0.68,0.80),day);
    vec3 sum=vec3(0.0); float transmittance=1.0;
    // The fine interval prevents a 70 m funnel tip disappearing between cloud samples.
    // Extra work applies only to rays intersecting its bounded volume.
    for(int i=0;i<160;i++) {
        if(t>=finish || transmittance<0.005) break;
        bool in_deck=t>=deck.x && t<deck.y;
        bool in_funnel=t>=funnel.x && t<funnel.y;
        if(!in_deck && !in_funnel) {
            float next_t=min(t<deck.x ? deck.x : 100000.0,t<funnel.x ? funnel.x : 100000.0);
            t=next_t;
            continue;
        }
        float ds=in_funnel ? min(coarse,fine) : coarse;
        if(t<funnel.x) ds=min(ds,funnel.x-t);
        if(t<deck.x) ds=min(ds,deck.x-t);
        ds=min(ds,finish-t);
        if(ds<0.000001) { t+=0.000001; continue; }
        vec3 p=ro+direction*(t+ds*(0.25+0.50*jitter));
        float fire;
        float d=density_tagged(p,fire);
        if(d>0.002) {
            // Every light tap calls the same density, including funnel and lenses.
            float tau_sun=6.0*(density(p+source*0.12)*0.12+density(p+source*0.35)*0.23);
            if(vortex_intensity>0.001 && length(p.xz-wx_vortex_center)<0.50) {
                // Deck-scale taps skip a narrow funnel. Resolve its own core
                // at shorter distances so it cannot become a luminous rope.
                tau_sun+=6.0*(density(p+source*0.012)*0.012+density(p+source*0.035)*0.023);
                tau_sun+=d*1.3;
            }
            float alpha=1.0-exp(-6.0*d*ds);
            float h=clamp((p.y-base)/max(ceiling-base,0.1),0.0,1.0);
            vec3 lit=wx_powder_light(d,tau_sun,dot(direction,source),h,celestial_color*day,ambient,source);
            float gold=smoothstep(.24,0.0,source.y)*smoothstep(-.10,.01,source.y);
            lit=mix(lit,mix(ambient*.30,vec3(1.0,.40,.14)*(.35+.8*exp(-tau_sun)),gold),fire*.9);
            lit*=1.0-.9*noctilucent_light()*spectacle[S_NOCTILUCENT];
            lit*=mix(vec3(1.0),vec3(.80,.60,.38),spectacle[S_HABOOB]);
            sum+=transmittance*alpha*lit;
            transmittance*=1.0-alpha;
        }
        t+=ds;
    }
    return vec4(sum,1.0-transmittance); // Already premultiplied: do not multiply alpha twice.
}
vec4 volumetric_clouds(vec3 direction,vec2 screen_uv) {
    vec4 deck=wx_volumetric_clouds(direction,screen_uv);
    if(direction.y<.005) return deck;
    float jitter=fract(sin(dot(screen_uv*vec2(1280.0,720.0),vec2(12.9898,78.233))+temporal_phase*13.17)*43758.5453);
    float near_t;
    vec4 objects=spectacle_objects(direction,jitter,near_t)*smoothstep(.005,.03,direction.y);
    float start=wx_cloud_base()/max(direction.y,.035);
    if(near_t<start) return vec4(objects.rgb+deck.rgb*(1.0-objects.a),objects.a+deck.a*(1.0-objects.a));
    return vec4(deck.rgb+objects.rgb*(1.0-deck.a),deck.a+objects.a*(1.0-deck.a));
}
void sky() {
    if (AT_CUBEMAP_PASS) {
        // Never raymarch the six reflection faces. Uniform animation invalidates
        // radiance, so this cheap approximation is deliberate.
		COLOR=wx_haze_color(normalize(sun_direction))*(.9+max(0.0,EYEDIR.y))
			+vec3(.035,.075,.15)*smoothstep(-.12,.12,sun_direction.y)*(1.0-cloud_coverage);
        COLOR*=1.0-0.12*wetness;
    } else if (AT_HALF_RES_PASS) {
        vec4 clouds=volumetric_clouds(EYEDIR,SCREEN_UV);
        COLOR=clouds.rgb; ALPHA=clouds.a;
    } else {
        vec3 base=celestial_base(EYEDIR);
        vec2 uv=EYEDIR.xz/max(.15,EYEDIR.y)*.14-wind_offset.xz*.14;
        float cirrus=texture(cirrus_tex,uv).r*max(high_cloud_strength,wx_formation==4 ? wx_formation_strength*0.70 : 0.0)*(wx_formation==4 ? .85 : mix(.16,.45,season_weights.w));
        cirrus*=smoothstep(.04,.18,EYEDIR.y);
        vec3 cirrus_color=fog_horizon_color*1.4+celestial_color*.12;
        if(wx_formation==4) cirrus_color*=wx_nacreous(EYEDIR,normalize(sun_direction),texture(cirrus_tex,uv).r);
        base=mix(base,cirrus_color,cirrus);
        base=spectacle_behind(EYEDIR,base);
        vec3 combined=base*(1.0-HALF_RES_COLOR.a)+HALF_RES_COLOR.rgb;
        combined=spectacle_front(EYEDIR,combined,HALF_RES_COLOR.a);
        float rho=mix(0.00035,0.045,wx_whiteout);
        float tau=wx_height_tau(wx_camera_km.y*1000.0,max(EYEDIR.y,0.0),3000.0,rho,140.0);
        COLOR=mix(combined,wx_haze_color(normalize(sun_direction)),1.0-exp(-tau));
    }
}
