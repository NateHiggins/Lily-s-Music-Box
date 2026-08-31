shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

// DREAM-VOXEL-V1 production cellular material.  The field sampler is shared
// by the active world; organism-specific presentation facts are instance
// uniforms so every bound colony can use this one material resource.
#include "res://shaders/dream_cellular_surface.gdshaderinc"

uniform sampler3D exposure_tex : filter_linear, repeat_enable;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;

uniform vec3 membrane_dark : source_color = vec3(.16,.155,.125);
uniform vec3 membrane_lit : source_color = vec3(.53,.50,.40);
uniform vec3 cytoplasm_color : source_color = vec3(.48,.41,.24);
uniform vec3 signal_color : source_color = vec3(.58,.28,.065);

instance uniform vec4 cellular_phenotype = vec4(.78,.48,.88,.42);
instance uniform vec4 cellular_state_a = vec4(.5,0.,1.,0.);
instance uniform vec4 cellular_state_b = vec4(0.,.5,0.,0.);
instance uniform vec4 cellular_state_c = vec4(0.);
instance uniform float cellular_seed = 0.0;
instance uniform float cellular_time = 0.0;
instance uniform float membrane_role = 0.0; // 0 network, 1 heart, 2 cargo/protein
instance uniform float tissue_alpha : hint_range(0.35,1.0) = 1.0;
instance uniform int voxel_response_mode = 0; // 0 disabled, 1 heatmap, 2 production

varying vec3 cell_pos;
varying vec3 cell_nrm;
varying vec3 cell_world_pos;

vec2 exposure_at(vec3 world_position) {
	// Same axis order as dream_klimt.gdshader and DreamExposureField.to_images:
	// texture X <- world X, texture Y <- world Z, texture depth <- world Y.
	vec3 uvw = vec3(world_position.x / max(exposure_extent, .001),
		world_position.z / max(exposure_extent, .001),
		clamp(world_position.y / max(exposure_height, .001), 0.0, .9999));
	return textureLod(exposure_tex, uvw, 0.0).rg;
}

void vertex() {
	cell_pos = VERTEX;
	cell_nrm = NORMAL;
	float breath = cellular_state_b.y * sin(cellular_time * 1.35 + VERTEX.x * 3.0) * .018;
	float pioneer = 1.0 - step(.5, membrane_role);
	float front = smoothstep(.12,.88,UV.y) * cellular_state_a.z;
	VERTEX.xz += NORMAL.xz * pioneer * front * sin(UV.x * 12.0 + cellular_time * .35) * .028;
	VERTEX += NORMAL * breath * (1.0 - cellular_state_c.y);
	cell_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view = normalize(VIEW);
	vec4 membrane = cell_membrane(cell_pos, normalize(cell_nrm), view,
		cellular_seed, cellular_phenotype, cellular_state_a, cellular_state_b,
		cellular_state_c, cellular_time);
	vec3 transport = cell_transport(cell_pos, cellular_seed, cellular_state_a,
		cellular_state_b, cellular_state_c, cellular_time);
	float vacuoles = smoothstep(.68,.86,cell_value(cell_pos * 5.7 + vec3(cellular_seed,.3,1.7)));
	float vesicles = smoothstep(.91,.975,cell_value(cell_pos * 24.0 - cellular_time * vec3(.18,0.,.11)));
	float filaments = pow(.5 + .5 * sin(cell_pos.x * 31.0 + cell_pos.z * 19.0 + cellular_time), 12.0);
	float domain = membrane.x;
	float thickness = clamp(membrane.y,0.,1.);
	vec3 color = mix(membrane_dark, membrane_lit, .24 + domain * .52 + thickness * .18);
	float pioneer = 1.0 - step(.5, membrane_role);
	float adhesion = smoothstep(.90,.98,cell_value(cell_pos * 19.0 + cellular_seed)) * pioneer;
	color += signal_color * adhesion * cellular_state_a.z * .18;
	color = mix(color, cytoplasm_color, membrane.w * (.38 + cellular_state_a.y * .34));
	color += signal_color * (membrane.z * .22 + transport.x * .65 + transport.y * .18 + transport.z * .45);
	color = mix(color, color * .28, vacuoles * (.48 + .30 * cellular_state_a.x));
	color += cytoplasm_color * vesicles * .38 + signal_color * filaments * transport.x * .22;
	color = mix(color, vec3(.34,.30,.20), cellular_state_c.x * .64 + cellular_state_c.y * .32);

	vec2 field = vec2(0.0);
	vec2 focused_field = vec2(0.0);
	if (voxel_response_mode > 0) {
		field = exposure_at(cell_world_pos);
		// Vacuoles are lower-density lenses: offset their lookup through the
		// actual world field instead of manufacturing a brighter scalar.
		focused_field = exposure_at(cell_world_pos
			+ normalize(cell_nrm) * vacuoles * .34);
	}
	float durable = field.r;
	float irradiance = field.g;
	if (voxel_response_mode == 1) {
		// Unmistakable diagnostic only.  Black is unowned/unlit; green-to-gold
		// is reversible G and magenta is durable R.
		float occupied = max(durable, irradiance);
		color = mix(vec3(.003,.004,.006),
			vec3(.04,.90,.35) * irradiance + vec3(1.0,.08,.62) * durable,
			step(.002, occupied));
	} else if (voxel_response_mode == 2) {
		// G is present local irradiance: wet surface, transmitted cytoplasm and
		// anatomy answer at different rates.  R is retained conversion/residue.
		float membrane_response = irradiance * (.34 + .62 * (1.0 - thickness));
		float cytoplasm_response = irradiance * membrane.w * (.50 + .30 * vacuoles);
		float organelle_occlusion = clamp(transport.y * .34 + filaments * .24, 0.0, .55);
		float deep_response = irradiance * (transport.x * .46 + filaments * .26)
			* (1.0 - thickness * .42) * (1.0 - organelle_occlusion);
		float vacuole_focus = max(irradiance, focused_field.g) * vacuoles
			* (.32 + .44 * membrane.w);
		vec3 transmitted = vec3(.92,.64,.34) * membrane_response
			+ vec3(.48,.67,.50) * cytoplasm_response
			+ vec3(.38,.31,.56) * deep_response;
		color += transmitted;
		color += vec3(.94,.72,.30) * vacuole_focus;
		// Retained R is sparse and structural, never a whole-cell tint.
		float residue_grain = smoothstep(.78,.96,
			cell_value(cell_world_pos * 7.3 + cellular_seed));
		float gold_fleck = durable * residue_grain * (.25 + .75 * membrane.z);
		color = mix(color, vec3(.60,.40,.12), durable * (.10 + .18 * membrane.z));
		color += vec3(.80,.55,.17) * gold_fleck;
	}

	ALBEDO = color;
	ROUGHNESS = clamp(.64 - membrane.z * .18 - irradiance * .08
		+ cellular_state_c.x * .28, .27, .92);
	METALLIC = .025 + transport.y * .07 + durable * membrane.z * .04;
	SSS_STRENGTH = clamp(.16 + membrane.w * .43 + irradiance * .14
		- cellular_state_c.x * .12,0.,.70);
	BACKLIGHT = vec3(.13,.105,.062) * irradiance
		* (1.0 - vacuoles * .45) * (1.0 - thickness * .28);
	EMISSION = signal_color * (membrane.z * .10 + transport.x * .22 + transport.z * .16)
		* (1.0 - cellular_state_c.y);
	if (voxel_response_mode == 1) {
		EMISSION = color * .32;
		ROUGHNESS = .82;
		METALLIC = 0.0;
		SSS_STRENGTH = 0.0;
		BACKLIGHT = vec3(0.0);
	}
	// V1 does not reintroduce whole-shell transparency. Transmission is SSS,
	// BACKLIGHT and local value/absorption response on a depth-writing surface.
	ALPHA = 1.0;
}
