shader_type spatial;
render_mode unshaded, cull_back;

// THE BODY'S OWN GOLD, LIT ANALYTICALLY BY THE SERVICE LAMP.
//
// This is not an emissive material. Its output is zero without the lamp, and
// every visible term is a diffuse or specular reflection derived from the
// lamp vector, surface normal and eye vector. The analytic pass is necessary
// because the service SpotLight3D is almost co-located with the eye: on a thin
// suspended knot the object and its cast shadow align, and ordinary Forward+
// shading reads the whole organism as a black cut-out against the bright
// ceiling behind it. The architecture already evaluates this same lamp in its
// own shader for the same reason.

uniform vec3 lamp_origin = vec3(0.0);
uniform vec3 lamp_splash = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_reach = 8.5;
uniform float lamp_cos_outer = 0.766;
uniform float lamp_energy = 0.0;

// DreamMazeRoot binds the shared field to every ShaderMaterial. The lineage
// does not grow from it in this slice, but exposed ancestry returns a little
// more colour than untouched ancestry. The lamp is still a hard gate.
uniform sampler3D exposure_tex : filter_linear, repeat_enable,
		hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;

uniform float gene_phase = 0.0;

varying vec3 v_world;
varying vec3 v_normal;


void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec3 to_fragment = v_world - lamp_origin;
	float distance_m = length(to_fragment);
	vec3 ray = distance_m > 0.0001
			? to_fragment / distance_m : vec3(0.0, 0.0, -1.0);
	float cone = smoothstep(lamp_cos_outer,
			mix(lamp_cos_outer, 1.0, 0.18), dot(ray, lamp_dir));
	float reach = pow(1.0 - clamp(distance_m / max(0.5, lamp_reach),
			0.0, 1.0), 0.62);
	float awake = cone * reach * clamp(lamp_energy, 0.0, 1.35);

	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	// A five-sided tube is deliberately faceted. Face the shading normal to
	// the viewer on the visible side so a winding transition in the knot does
	// not turn one entire loop black.
	if (dot(n, view_dir) < 0.0) {
		n = -n;
	}
	vec3 light_dir = normalize(lamp_origin - v_world);
	float diffuse = 0.18 + 0.82 * max(dot(n, light_dir), 0.0);
	vec3 half_dir = normalize(light_dir + view_dir);
	float specular = pow(max(dot(n, half_dir), 0.0), 38.0);

	float ex_y = clamp(v_world.y / max(0.001, exposure_height),
			0.0625, 0.9375);
	float exposed = texture(exposure_tex, vec3(v_world.x / exposure_extent,
			v_world.z / exposure_extent, ex_y)).r;
	float hammered = 0.78 + 0.22 * sin((v_world.x + v_world.z) * 31.0
			+ v_world.y * 19.0 + gene_phase);
	vec3 old_gold = vec3(0.10, 0.055, 0.012);
	vec3 warm_gold = vec3(0.72, 0.40, 0.09);
	vec3 pale_leaf = vec3(1.08, 0.82, 0.38);
	vec3 alloy = mix(old_gold, warm_gold,
			clamp(0.42 + exposed * 0.48 + hammered * 0.20, 0.0, 1.0));
	vec3 reflected = alloy * diffuse * (0.85 + hammered * 0.22)
			+ pale_leaf * specular * 1.15;
	ALBEDO = reflected * awake * 0.95;
}
