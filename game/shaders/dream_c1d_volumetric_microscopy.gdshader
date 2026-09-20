shader_type spatial;

// One bounded organism-local compositor. The box is only the rasterization
// bound; the visible specimen is the integrated amoeboid density field.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform sampler2D room_color : hint_screen_texture, repeat_disable, filter_linear;
// The production DreamExposureField upload. R is durable exposure; G is
// reversible irradiance. World-space addressing matches dream_klimt exactly.
uniform sampler3D exposure_tex : filter_linear, repeat_enable, hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
uniform int diagnostic_mode = 2; // 0 physical, 1 voxel heatmap, 2 combined
uniform vec3 lamp_position_object = vec3(-1.6, 0.8, 1.7);
uniform vec3 lamp_direction_object = vec3(0.55, -0.2, -0.8);
uniform vec3 lamp_origin_world = vec3(0.0, 2.0, 0.0);
uniform vec3 lamp_direction_world = vec3(0.0, -0.2, -1.0);
uniform float lamp_range_m = 7.0;
uniform float lamp_cos_outer = 0.80;
uniform vec3 lamp_spectrum = vec3(1.0, 0.84, 0.61);
uniform float lamp_intensity : hint_range(0.0, 1.2) = 1.0;
uniform float optical_time = 2.7;
uniform float cargo_phase : hint_range(0.0, 1.0) = 0.58;
uniform float density_gain : hint_range(0.2, 3.0) = 1.18;

varying vec3 local_surface;

const int STEPS = 64;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float n = value_noise(p) * 0.58;
	n += value_noise(p * 2.03 + 7.1) * 0.27;
	n += value_noise(p * 4.17 - 3.4) * 0.15;
	return n;
}

vec3 diagnostic_heatmap(float v) {
	// Perceptually ordered black/blue/cyan/yellow/red occupancy visualization.
	vec3 c0 = vec3(0.005,0.008,0.025);
	vec3 c1 = vec3(0.04,0.12,0.78);
	vec3 c2 = vec3(0.00,0.88,0.93);
	vec3 c3 = vec3(1.00,0.86,0.05);
	vec3 c4 = vec3(0.96,0.08,0.02);
	if (v < 0.25) return mix(c0,c1,v*4.0);
	if (v < 0.50) return mix(c1,c2,(v-.25)*4.0);
	if (v < 0.75) return mix(c2,c3,(v-.50)*4.0);
	return mix(c3,c4,(v-.75)*4.0);
}

float sd_capsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa = p - a;
	vec3 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float sd_ellipsoid(vec3 p, vec3 center, vec3 radius) {
	return (length((p - center) / radius) - 1.0) * min(radius.x, min(radius.y, radius.z));
}

float amoeba_sdf(vec3 p) {
	// Low-order, asymmetric folds keep the membrane biological without ever
	// turning it into a separately shaded glass shell.
	vec3 q = p;
	q.x -= 0.030 * sin(q.y * 5.2 + q.z * 3.7);
	q.y += 0.024 * sin(q.x * 4.1 - q.z * 4.8);
	float radial = length(q);
	float lobes = 0.030 * sin(atan(q.z, q.x) * 3.0 + q.y * 2.5)
		+ 0.018 * sin(atan(q.y, q.x) * 5.0 - q.z * 3.0);
	return radial - (0.91 + lobes);
}

float route_field(vec3 p) {
	float d = sd_capsule(p, vec3(0.76,0.12,0.23), vec3(0.48,0.04,0.10), 0.038);
	d = min(d, sd_capsule(p, vec3(0.48,0.04,0.10), vec3(0.20,0.12,-0.03), 0.044));
	d = min(d, sd_capsule(p, vec3(0.20,0.12,-0.03), vec3(-0.06,0.02,-0.12), 0.050));
	d = min(d, sd_capsule(p, vec3(-0.06,0.02,-0.12), vec3(-0.34,-0.08,-0.02), 0.044));
	d = min(d, sd_capsule(p, vec3(-0.34,-0.08,-0.02), vec3(-0.57,-0.02,0.14), 0.035));
	return d;
}

float vascular_field(vec3 p) {
	// A fused density network wrapping the nucleus; soft edges make it read as
	// channels in cytoplasm rather than tubes suspended in air.
	float d = sd_capsule(p, vec3(-0.58,0.17,0.00), vec3(-0.31,0.35,-0.08), 0.026);
	d = min(d, sd_capsule(p, vec3(-0.31,0.35,-0.08), vec3(0.02,0.38,0.02), 0.031));
	d = min(d, sd_capsule(p, vec3(0.02,0.38,0.02), vec3(0.34,0.25,0.12), 0.025));
	d = min(d, sd_capsule(p, vec3(-0.45,-0.27,0.05), vec3(-0.18,-0.40,-0.02), 0.029));
	d = min(d, sd_capsule(p, vec3(-0.18,-0.40,-0.02), vec3(0.18,-0.34,0.12), 0.034));
	d = min(d, sd_capsule(p, vec3(0.18,-0.34,0.12), vec3(0.48,-0.17,0.05), 0.025));
	d = min(d, sd_capsule(p, vec3(-0.31,0.35,-0.08), vec3(-0.45,-0.27,0.05), 0.022));
	d = min(d, sd_capsule(p, vec3(0.34,0.25,0.12), vec3(0.48,-0.17,0.05), 0.020));
	return d;
}

float fiber_field(vec3 p) {
	float d = sd_capsule(p, vec3(-0.73,-0.23,0.20), vec3(0.62,0.34,-0.18), 0.010);
	d = min(d, sd_capsule(p, vec3(-0.68,-0.28,0.16), vec3(0.67,0.29,-0.22), 0.008));
	d = min(d, sd_capsule(p, vec3(-0.63,-0.33,0.12), vec3(0.70,0.24,-0.26), 0.007));
	d = min(d, sd_capsule(p, vec3(-0.43,0.43,-0.20), vec3(0.52,-0.39,0.18), 0.008));
	return d;
}

vec3 route_position(float phase) {
	float x = clamp(phase, 0.0, 0.999) * 5.0;
	int i = int(floor(x));
	float f = smoothstep(0.0, 1.0, fract(x));
	vec3 a = vec3(0.76,0.12,0.23);
	vec3 b = vec3(0.48,0.04,0.10);
	if (i == 1) { a=b; b=vec3(0.20,0.12,-0.03); }
	else if (i == 2) { a=vec3(0.20,0.12,-0.03); b=vec3(-0.06,0.02,-0.12); }
	else if (i == 3) { a=vec3(-0.06,0.02,-0.12); b=vec3(-0.34,-0.08,-0.02); }
	else if (i >= 4) { a=vec3(-0.34,-0.08,-0.02); b=vec3(-0.57,-0.02,0.14); }
	return mix(a,b,f);
}

void vertex() {
	local_surface = VERTEX;
}

void fragment() {
	vec3 ro = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 rd = normalize(local_surface - ro);
	float b = dot(ro, rd);
	float c = dot(ro, ro) - 1.0;
	float h = b * b - c;
	if (h <= 0.0) { discard; }
	float root_h = sqrt(h);
	float t0 = max(-b - root_h, 0.0);
	float t1 = -b + root_h;
	float segment = max(t1 - t0, 0.001);
	float step_len = segment / float(STEPS);

	vec3 accum = vec3(0.0);
	float transmittance = 1.0;
	float previous_density = 0.0;
	float lens_integral = 0.0;
	float boundary_integral = 0.0;
	float field_peak = 0.0;
	float field_integral = 0.0;
	vec3 cargo = route_position(cargo_phase);
	vec3 light_dir = normalize(lamp_position_object);
	vec3 fiber_axis = normalize(vec3(1.30,0.57,-0.38));
	float polarization = 0.5 + 0.5 * sin(optical_time * 0.19 + dot(light_dir, fiber_axis) * 7.0);

	for (int i = 0; i < STEPS; i++) {
		float t = t0 + (float(i) + 0.5) * step_len;
		vec3 p = ro + rd * t;
		float body_sdf = amoeba_sdf(p);
		float body = smoothstep(0.018, -0.025, body_sdf);
		if (body > 0.001) {
			float depth = float(i) / float(STEPS - 1);
			vec3 world_p = (MODEL_MATRIX * vec4(p,1.0)).xyz;
			vec2 voxel_channels = textureLod(exposure_tex, vec3(
				world_p.x / exposure_extent, world_p.z / exposure_extent,
				clamp(world_p.y / exposure_height,0.0625,0.9375)),0.0).rg;
			float durable_exposure = voxel_channels.r;
			float direct_irradiance = voxel_channels.g;
			float voxel_drive = clamp(direct_irradiance + durable_exposure*.72,0.0,1.0);
			field_peak = max(field_peak,voxel_drive*body);
			field_integral += voxel_drive*body*step_len;
			float cloud = fbm(p * vec3(3.1,4.6,3.7) + vec3(optical_time * 0.012,0.0,-optical_time * 0.008));
			float slow_flow = 0.5 + 0.5 * sin(p.x * 8.0 - p.z * 5.0 + optical_time * 0.23 + cloud * 3.1);
			float cytoplasm = body * (0.13 + cloud * 0.18 + slow_flow * 0.040);

			// Low-density vacuoles warp the coordinate used by anatomy behind
			// them. Their boundaries remain phase discontinuities, not bubbles.
			vec3 vac_center = vec3(0.31,0.17,0.16);
			float vac_r = 0.205;
			float vac_dist = length(p - vac_center);
			float vac_inside = 1.0 - smoothstep(vac_r * 0.78, vac_r, vac_dist);
			float vac_edge = exp(-abs(vac_dist - vac_r) * 88.0);
			vec3 q = p;
			q.xy += (p.xy - vac_center.xy) * vac_inside * 0.27;
			// Re-sample the authoritative field through the same local lensing
			// displacement as the anatomy, so the illuminated voxel region is
			// focused rather than globally brightened.
			vec3 lensed_world_p=(MODEL_MATRIX*vec4(q,1.0)).xyz;
			vec2 lensed_voxel=textureLod(exposure_tex,vec3(
				lensed_world_p.x/exposure_extent,lensed_world_p.z/exposure_extent,
				clamp(lensed_world_p.y/exposure_height,0.0625,0.9375)),0.0).rg;
			voxel_drive=mix(voxel_drive,clamp(lensed_voxel.g+lensed_voxel.r*.72,0.0,1.0),vac_inside*.78);
			lens_integral += (vac_inside * 0.85 + vac_edge * 0.18) * step_len;

			float nucleus_sdf = sd_ellipsoid(q + vec3(0.025 * sin(q.y*14.0),0.0,0.0),
				vec3(-0.20,0.03,-0.13), vec3(0.31,0.26,0.25));
			float nucleus = smoothstep(0.035, -0.045, nucleus_sdf);
			float envelope = exp(-abs(nucleus_sdf) * 72.0);
			float folded = nucleus * (0.42 + 0.36 * sin(length((q-vec3(-0.20,0.03,-0.13))*vec3(1.0,1.15,0.9))*35.0 + q.y*16.0));

			float route_d = route_field(q);
			float route = exp(-max(route_d, 0.0) * 64.0) * smoothstep(0.075, -0.018, route_d);
			float vascular_d = vascular_field(q);
			float vascular = exp(-max(vascular_d, 0.0) * 45.0) * smoothstep(0.070, -0.012, vascular_d);
			float fiber_d = fiber_field(q);
			float fibers = exp(-max(fiber_d, 0.0) * 120.0) * smoothstep(0.030, -0.004, fiber_d);

			float cargo_d = length(q - cargo) - 0.072;
			float cargo_mass = smoothstep(0.040, -0.035, cargo_d);
			vec3 wake_axis = normalize(vec3(-0.28,-0.09,-0.13));
			float wake = exp(-max(sd_capsule(q, cargo - wake_axis*0.30, cargo, 0.035),0.0)*55.0) * 0.48;

			vec3 energy_center = vec3(0.49,-0.19,-0.20);
			float er = length((q-energy_center)/vec3(0.23,0.18,0.21));
			float energy_folds = exp(-abs(fract(er*2.4 + cloud*0.14)-0.5)*16.0) * (1.0-smoothstep(0.65,1.05,er));

			float granule_noise = value_noise(floor((q + vec3(1.2)) * 30.0));
			float granules = smoothstep(0.915,0.985,granule_noise) * body * (1.0-vac_inside) * 0.52;

			cytoplasm *= mix(1.0, 0.16, vac_inside);
			float field_density = diagnostic_mode==2 ? voxel_drive : 0.0;
			float density = cytoplasm*(1.0+field_density*.46) + nucleus*0.76 + envelope*0.34 + folded*0.22
				+ route*0.40 + vascular*0.29 + fibers*0.16 + cargo_mass*0.48
				+ wake*0.10 + energy_folds*0.17 + granules*(0.05+field_density*.31) + vac_edge*0.035;
			density *= density_gain;

			vec3 tissue_color = mix(vec3(0.43,0.34,0.24), vec3(0.57,0.47,0.30), cloud);
			tissue_color = mix(tissue_color, vec3(0.39,0.24,0.32), nucleus*0.78);
			tissue_color = mix(tissue_color, vec3(0.26,0.42,0.39), route*0.68 + vascular*0.36);
			tissue_color = mix(tissue_color, vec3(0.56,0.34,0.22), energy_folds*0.52);
			tissue_color = mix(tissue_color, vec3(0.69,0.55,0.34), cargo_mass*0.72);
			// Durable conversion and reversible irradiance have one local path:
			// the sampled voxel. Gold flecks cannot appear outside occupied voxels.
			tissue_color=mix(tissue_color,vec3(0.73,0.53,0.20),field_density*(0.28+granules*.64));

			// Oriented fibers answer the lamp/view relationship locally. This
			// is bounded spectral breakup, never a categorical rainbow label.
			vec3 fringe_a = vec3(0.40,0.62,0.70);
			vec3 fringe_b = vec3(0.76,0.46,0.43);
			vec3 fiber_color = mix(fringe_a, fringe_b, polarization + 0.18*sin(q.x*34.0));
			tissue_color = mix(tissue_color, fiber_color, fibers*0.82);

			vec3 from_lamp=world_p-lamp_origin_world;
			float to_lamp=length(from_lamp);
			float cone=to_lamp<lamp_range_m ? smoothstep(lamp_cos_outer,min(1.0,lamp_cos_outer+.11),dot(normalize(from_lamp),normalize(lamp_direction_world))) : 0.0;
			float incidence = (0.20 + 0.80*cone) * (0.48 + 0.52 * max(dot(normalize(lamp_position_object-p), -rd), 0.0));
			float nucleus_shadow = 1.0 - nucleus * 0.28 - folded * 0.10;
			float progressive = exp(-depth * (0.72 + cloud*0.34));
			vec3 illumination = lamp_spectrum * lamp_intensity * (0.13 + incidence*0.96)
				* progressive * nucleus_shadow / (1.0 + to_lamp*0.065);
			if (diagnostic_mode==2) illumination*=0.54+voxel_drive*1.58;

			float phase_gradient = abs(density - previous_density);
			float boundary_halo = exp(-abs(body_sdf) * 105.0) * 0.11;
			boundary_integral += boundary_halo * step_len;
			vec3 phase_light = vec3(0.58,0.66,0.65) * min(phase_gradient*0.72,0.16)
				+ vec3(0.55,0.48,0.34) * boundary_halo;
			float alpha_step = 1.0 - exp(-density * step_len * 3.05);
			vec3 scattered = tissue_color * illumination * (0.62 + slow_flow*0.22) + phase_light;
			accum += transmittance * alpha_step * scattered;
			transmittance *= (1.0 - alpha_step);
			previous_density = density;
		}
	}

	// Explicitly composite the room through the accumulated medium. There is
	// no uniform transparent shell and no stack of sorted organelle surfaces.
	vec2 lens_direction = vec2(0.73, -0.36) * lens_integral * 0.014;
	lens_direction += vec2(sin(local_surface.y*9.0), cos(local_surface.x*8.0)) * boundary_integral * 0.004;
	vec3 background = textureLod(room_color, clamp(SCREEN_UV + lens_direction, vec2(0.001), vec2(0.999)), 0.0).rgb;
	vec3 final_color = accum + background * transmittance;
	if (diagnostic_mode==1) {
		float occupancy=clamp(field_peak*.72+field_integral*.42,0.0,1.0);
		vec3 heat=diagnostic_heatmap(occupancy);
		float cell_presence=clamp((1.0-transmittance)*1.8+.18,0.0,1.0);
		final_color=mix(background*.10,heat,cell_presence);
	}
	// Restrained phase-contrast boundary: lighter on the transmitted side,
	// darker on the opposite side, never a glass highlight.
	float rim = pow(1.0 - abs(dot(normalize(local_surface), -rd)), 2.8);
	if (diagnostic_mode!=1) final_color += lamp_spectrum * rim * 0.040 * lamp_intensity;
	ALBEDO = clamp(final_color, vec3(0.0), vec3(1.25));
}
