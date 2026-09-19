// Shared S1 cellular material language. Phenotype shaders choose palette and
// anatomy; these bounded analytic fields provide a common fictional biology.

float cell_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float cell_value(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cell_hash(i), cell_hash(i + vec3(1,0,0)), f.x),
		mix(cell_hash(i + vec3(0,1,0)), cell_hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(cell_hash(i + vec3(0,0,1)), cell_hash(i + vec3(1,0,1)), f.x),
		mix(cell_hash(i + vec3(0,1,1)), cell_hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

vec4 cell_membrane(vec3 p, vec3 n, vec3 view, float seed,
		vec4 phenotype, vec4 state_a, vec4 state_b, vec4 state_c, float time) {
	float large = cell_value(p * (1.2 + phenotype.x * 1.8) + seed);
	float medium = cell_value(p * 7.0 + vec3(seed, -seed, seed * .3));
	float micro = cell_value(p * 31.0 + seed * 2.7);
	float compartment = smoothstep(.06, .015, abs(fract(large * 3.0 + medium * .32) - .5));
	float thickness = clamp(.20 + large * .52 + medium * .20 - state_c.x * .18, 0.04, .94);
	float clearing = smoothstep(.72, .93, medium + state_b.x * .18 + state_a.w * .12) * phenotype.y;
	float boundary = smoothstep(.10, .0, abs(medium - .5));
	float meaningful_edge = boundary * (0.25 + abs(dot(normalize(n), normalize(view))) * .35);
	float dic = dot(normalize(vec2(dFdx(thickness), dFdy(thickness)) + vec2(.0001)), normalize(vec2(.72,.28)));
	float streaming = cell_value(p * vec3(3.0, 11.0, 3.0) + vec3(0,time * (.08 + state_b.x * .16),0));
	float protein = smoothstep(.86 - phenotype.z * .18, .96, micro + compartment * .12);
	float failed = state_c.x;
	protein *= mix(.55 + .45 * sin(time * 1.7 + medium * 14.0), smoothstep(.38,.62,large), failed);
	float transmission = clearing * (1.0 - thickness) * (1.0 - max(state_c.y, failed * .55));
	float halo = meaningful_edge * phenotype.w * (1.0 - state_c.y) * (.35 + .65 * state_a.x);
	float cytoplasm = (streaming * .55 + protein * .45) * transmission;
	return vec4(compartment, thickness + dic * .055, halo, cytoplasm);
}

vec3 cell_transport(vec3 p, float seed, vec4 state_a, vec4 state_b,
		vec4 state_c, float time) {
	float direction = mix(-1.0, 1.0, step(.5, state_b.x + state_b.y));
	float lane = smoothstep(.88, .98, cell_value(p * vec3(3.,17.,3.) + seed));
	float cargo = pow(max(0.0, sin(p.y * 24.0 - time * direction * (1.0 + state_b.x * 2.0))), 18.0);
	float activity = state_a.x * (1.0 - state_c.x) * (1.0 - state_c.y);
	float gate = smoothstep(.35,.7,state_a.w + state_b.x) * activity;
	return vec3(lane * cargo * activity, lane * gate, lane * state_a.y * activity);
}
