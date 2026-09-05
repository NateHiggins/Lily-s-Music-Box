shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled,
		shadows_disabled;
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

vec2 lower_clouds(vec3 direction) {
	// Direction-space waves cross the panorama seam continuously and avoid an
	// azimuth/elevation grid. Six non-parallel bands approximate broad rolling
	// cloud cells more cheaply than a sampled 3D noise volume.
	// Advect the field in the reported horizontal wind direction. A much
	// slower opposed evolution prevents a perfectly rigid painted sheet.
	// 0.00012 rad/s per km/h approximates angular travel for a roughly 2.3 km
	// cloud base: visible over tens of seconds, never a racing texture belt.
	float advection = TIME * cloud_wind_speed * 0.00012;
	float drift_a = TIME * 0.003 + cloud_phase;
	float drift_b = TIME * -0.0017 + cloud_phase * 1.71;
	vec3 p = normalize(direction + normalize(cloud_wind_direction) * advection);
	float broad = sin(dot(p, vec3(3.7, 1.9, 5.1)) * 2.1 + drift_a) * 0.31;
	broad += sin(dot(p, vec3(-6.2, 3.4, 2.7)) * 1.7 + drift_b) * 0.23;
	broad += sin(dot(p, vec3(2.3, -5.8, 7.1)) * 2.6
			- drift_a * 0.73) * 0.18;
	broad += sin(dot(p, vec3(9.1, 4.2, -3.3)) * 3.1
			+ drift_b * 1.17) * 0.13;
	broad += sin(dot(p, vec3(-4.7, 8.6, 6.4)) * 4.3
			+ drift_a * 0.41) * 0.09;
	broad += sin(dot(p, vec3(11.3, -7.2, 5.9)) * 5.2
			- drift_b * 0.56) * 0.06;
	// Coverage moves the threshold, not merely opacity: clear is genuinely
	// empty, scattered has holes, and overcast closes the whole hemisphere.
	float threshold_a = mix(0.58, -1.15, cloud_coverage);
	float threshold_b = mix(0.78, -0.28, cloud_coverage);
	return vec2(smoothstep(threshold_a, threshold_b, broad),
			clamp(broad * 0.5 + 0.5, 0.0, 1.0));
}

void fragment() {
	vec3 direction = normalize(
			(INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
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
	vec2 cloud_field = lower_clouds(direction);
	float cloud_shape = cloud_field.x;
	float cloud_relief = smoothstep(0.34, 0.66, cloud_field.y);
	// High cloud is a thin veil, never a counterfeit low ceiling. Reuse the
	// direction field with one fine fold so the added stratum costs no texture
	// or draw and remains continuous through the panorama seam.
	// At this scenery LOD high cloud is honest cirrostratus: a homogeneous thin
	// veil. Invented procedural wisps repeatedly photographed as stripes or
	// cubic shards; reserve shaped motion for the lower/middle optical deck.
	float high_opacity = high_cloud_strength * 0.18;
	// Optical depth is exponential: a modest scattered report must still make
	// plainly visible clouds, while a zero-strength clear report stays exact.
	float lower = 1.0 - exp(-cloud_shape * lower_cloud_strength * 3.8);
	// Near-complete reports describe an optical ceiling, not a transparent
	// gray filter. Close the remaining procedural holes over the last 14% of
	// observed coverage so 100% overcast cannot leak a photographic Milky Way.
	float closed_ceiling = smoothstep(0.86, 1.0, cloud_coverage);
	float thickness = clamp(max(lower, closed_ceiling * 0.995), 0.0, 1.0);
	vec3 color = authored.rgb * exposure;
	vec3 high_color = fog_horizon_color * 1.35
			+ vec3(0.055, 0.045, 0.038) * urban_horizon_gain * 1.10;
	color = mix(color, high_color, high_opacity);
	// The close deck is cooler and slightly darker than the painted upper
	// cloud. Its changing overlap is the parallax cue. Its value is independent
	// of the panorama beneath it; otherwise bright stars make bright clouds.
	// Keep underside relief inside a stratus value range. The earlier 0.72–2.07
	// multiplier photographed like charcoal ink and blown white paint by day;
	// this 0.84–1.66 range survives tonemapping without becoming projected art.
	vec3 cloud_color = fog_horizon_color * (0.84 + cloud_relief * 0.82);
	color = mix(color, cloud_color, thickness);
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
	ALBEDO = color;
}
