// Shared six-incarnation surface path. Ordered production incarnations branch
// here; later profile ids remain exact pass-through until their gate lands.
// Roughness is packed in albedo alpha; height is packed in normal alpha.
uniform sampler2D incarnation_albedo_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_albedo_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_albedo_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_albedo_3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_normal_0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_normal_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_normal_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D incarnation_normal_3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D reflected_world : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float incarnation_stillness : hint_range(0.0, 1.0) = 0.0;

vec4 incarnation_antitile(sampler2D plate, vec2 uv, float seed) {
	vec2 cell = floor(uv * 0.071 + seed);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 a = uv + vec2(h * 5.17, fract(h * 7.31) * 3.83);
	vec2 b = vec2(-uv.y, uv.x) + vec2(3.7 + seed, 8.3 - seed);
	float seam = smoothstep(0.18, 0.82,
		fract(sin(dot(cell + 19.0, vec2(269.5, 183.3))) * 24634.6345));
	return mix(texture(plate, a), texture(plate, b), seam);
}

vec4 incarnation_substance(int slot, vec2 uv) {
	if (slot == 1) return incarnation_antitile(incarnation_albedo_1, uv, 2.0);
	if (slot == 2) return incarnation_antitile(incarnation_albedo_2, uv, 3.0);
	if (slot == 3) return incarnation_antitile(incarnation_albedo_3, uv, 4.0);
	return incarnation_antitile(incarnation_albedo_0, uv, 1.0);
}

vec4 incarnation_relief(int slot, vec2 uv) {
	if (slot == 1) return incarnation_antitile(incarnation_normal_1, uv, 6.0);
	if (slot == 2) return incarnation_antitile(incarnation_normal_2, uv, 7.0);
	if (slot == 3) return incarnation_antitile(incarnation_normal_3, uv, 8.0);
	return incarnation_antitile(incarnation_normal_0, uv, 5.0);
}

// Mina's editorial palimpsest: continuous lines with deliberately empty
// caption fields. It never emits glyphs and never reads annotation state.
vec4 mina_surface(vec3 world, vec2 uv, float retained, float molten,
		float awake, float grazing, int slot) {
	vec4 plate = incarnation_substance(slot, uv * 0.78);
	vec4 relief = incarnation_relief(slot, uv * 0.78);
	// Use the selected dominant surface plane. World XZ collapses to one line
	// on a vertical wall and made the editorial layout mathematically unable
	// to draw a box there.
	float baseline = smoothstep(0.055, 0.012,
		abs(fract(uv.y * 0.43 + sin(uv.x * 0.19) * 0.08) - 0.5));
	vec2 box_uv = abs(fract(uv * vec2(0.087, 0.123)) - 0.5);
	float bracket = smoothstep(0.035, 0.012,
		min(abs(box_uv.x - 0.39), abs(box_uv.y - 0.29)));
	float empty_field = (1.0 - smoothstep(0.26, 0.38, box_uv.x))
		* (1.0 - smoothstep(0.17, 0.28, box_uv.y));
	float ink = clamp(max(baseline * 0.42, bracket * 0.58)
		* (1.0 - empty_field), 0.0, 1.0);
	float calm = smoothstep(incarnation_signature.x, 1.0, retained)
		* incarnation_signature.y;
	ink *= 1.0 - calm * empty_field;
	vec3 blue_black = plate.rgb * vec3(0.18, 0.23, 0.34);
	vec3 warm_stock = incarnation_substance(1, uv * 0.64 + 5.1).rgb
		* vec3(0.20, 0.16, 0.12);
	vec3 gilt = incarnation_substance(2, uv * 0.91 - 3.7).rgb
		* vec3(0.74, 0.57, 0.28);
	vec3 dark = mix(warm_stock, blue_black, 0.58 + ink * 0.32);
	dark *= 0.78 + relief.a * 0.34;
	vec3 oblique = mix(dark, blue_black * 1.75, ink * clamp(awake * 1.4, 0.0, 1.0));
	// Gold boils outward from the surviving ink rim; the centre is spared.
	float spared = clamp(calm * empty_field + molten * (1.0 - ink) * 0.56, 0.0, 1.0);
	vec3 colour = mix(oblique, gilt, molten * (0.28 + ink * 0.72));
	colour = mix(colour, vec3(0.012, 0.018, 0.032),
		ink * (0.76 - molten * 0.38));
	colour += gilt * ink * molten * 0.24;
	colour = mix(colour, warm_stock * 0.045, spared * 0.94);
	vec3 room_after = texture(reflected_world,
		fract(uv * 0.035 + vec2(0.17, 0.43))).rgb;
	float room_luma = dot(room_after, vec3(0.299, 0.587, 0.114));
	colour += vec3(1.0, 0.72, 0.31) * room_luma * molten * grazing * 0.12;
	// The spared field keeps one pressure trace, visible only when Mina is met
	// with stillness. Broad palm plus four shallow finger dents; material
	// relief, never a hand, person, label or gameplay signal.
	vec2 palm_q = fract(uv / 9.0 + vec2(0.31, 0.57)) - 0.5;
	float palm = smoothstep(0.24, 0.16,
		length(palm_q / vec2(0.78, 1.0)));
	float pressure = palm * calm
		* incarnation_stillness * empty_field;
	float roughness = mix(plate.a, 0.34, molten * ink);
	roughness = mix(roughness, 0.16, pressure * 0.38);
	return vec4(colour, roughness);
}

// Peter's recursive docket: nested fields remain empty while a single
// oxblood decision stroke becomes executable under full exposure. It never
// reads or mutates the demanding-door grammar.
vec4 peter_surface(vec3 world, vec2 uv, float retained, float molten,
		float awake, float grazing, int slot) {
	vec4 stock = incarnation_substance(0, uv * 0.82);
	vec4 stamp = incarnation_substance(1, uv * 0.93 + 3.1);
	vec4 carbon = incarnation_substance(2, uv * 0.74 - 4.7);
	vec4 brass = incarnation_substance(3, uv * 1.08 + 7.3);
	vec4 selected = incarnation_substance(slot, uv * 0.86);
	vec2 docket = abs(fract(uv * vec2(0.118, 0.154)) - 0.5);
	float frame = smoothstep(0.035, 0.012,
		min(abs(docket.x - 0.41), abs(docket.y - 0.34)));
	vec2 inner = abs(fract(uv * vec2(0.071, 0.093) + 0.19) - 0.5);
	frame = max(frame, smoothstep(0.028, 0.010,
		min(abs(inner.x - 0.34), abs(inner.y - 0.25))) * 0.72);
	float route_phase = fract((uv.x + uv.y * 0.37) * 0.112);
	float route = smoothstep(0.040, 0.012, abs(route_phase - 0.5));
	float decision = smoothstep(incarnation_signature.x, 1.0, retained)
		* incarnation_signature.y;
	float continuing = mix(frame, route, decision);
	vec3 paper = stock.rgb * vec3(0.34, 0.28, 0.20);
	vec3 blue_copy = carbon.rgb * vec3(0.28, 0.34, 0.54);
	vec3 oxblood = stamp.rgb * vec3(0.82, 0.34, 0.30);
	vec3 legal_brass = brass.rgb * vec3(0.72, 0.52, 0.25);
	vec3 colour = mix(paper, blue_copy, 0.24 + (1.0 - awake) * 0.18);
	colour = mix(colour, oxblood, continuing * (0.52 + awake * 0.22));
	colour = mix(colour, legal_brass,
		molten * (route * 0.78 + frame * (1.0 - decision) * 0.18));
	// The open route crosses the existing surface continuously; this is a
	// colour-space fact only and cannot open, add, or move a door.
	colour += legal_brass * route * decision * molten * 0.24;
	float room_luma = dot(texture(reflected_world,
		fract(uv * 0.031 + vec2(0.41, 0.23))).rgb,
		vec3(0.299, 0.587, 0.114));
	colour += vec3(0.72, 0.48, 0.20) * room_luma
		* molten * grazing * 0.10;
	// One lower-corner pressure indentation: roughness only, illegible and
	// incapable of completing a field for him.
	vec2 corner_q = fract(uv / 11.0 + vec2(0.08, 0.82)) - 0.5;
	float initial_pressure = smoothstep(0.11, 0.055,
		length(corner_q / vec2(1.0, 0.55)));
	float roughness = mix(selected.a, 0.30, molten * continuing);
	roughness = mix(roughness, 0.18, initial_pressure * 0.32);
	return vec4(colour, roughness);
}

// Juno's reciprocal signal field: every visible send has a return, while the
// standing-wave display remains presentation only. It cannot observe or create
// channel edges, partitions, pursuit attention, sound, or sustain credit.
vec4 juno_surface(vec3 world, vec2 uv, float retained, float molten,
		float awake, float grazing, int slot) {
	vec4 cloth = incarnation_substance(0, uv * 0.76);
	vec4 brass = incarnation_substance(1, uv * 0.92 + 2.7);
	vec4 diaphragm = incarnation_substance(2, uv * 0.68 - 5.2);
	vec4 bakelite = incarnation_substance(3, uv * 1.03 + 8.4);
	vec4 selected = incarnation_substance(slot, uv * 0.82);
	float rate = min(incarnation_motion.x, 0.99);
	float phase = TIME * rate * 6.2831853 + incarnation_motion.y;
	float carrier = sin((uv.x + world.y * 0.31) * 0.84 + phase);
	float returning = sin((uv.x - world.y * 0.31) * 0.84 - phase);
	float standing = abs(carrier + returning) * 0.5;
	float node = 1.0 - smoothstep(0.03, 0.18, standing);
	float antinode = smoothstep(0.42, 0.92, standing);
	float paired_a = smoothstep(0.035, 0.014,
		abs(fract((uv.x + uv.y * 0.24) * 0.118) - 0.42));
	float paired_b = smoothstep(0.035, 0.014,
		abs(fract((uv.x + uv.y * 0.24) * 0.118) - 0.58));
	float paired = max(paired_a, paired_b);
	float sustained = smoothstep(incarnation_signature.x, 1.0, retained)
		* incarnation_signature.y;
	vec3 lapis_cloth = cloth.rgb * vec3(0.17, 0.20, 0.38);
	vec3 wine_membrane = diaphragm.rgb * vec3(0.54, 0.18, 0.30);
	vec3 oxidized = brass.rgb * vec3(0.40, 0.54, 0.34);
	vec3 warm_brass = brass.rgb * vec3(0.88, 0.62, 0.27);
	vec3 deep_node = bakelite.rgb * vec3(0.24, 0.18, 0.20);
	vec3 colour = mix(deep_node, lapis_cloth,
		0.48 + awake * antinode * 0.24);
	colour = mix(colour, wine_membrane, paired * (0.42 + awake * 0.18));
	colour = mix(colour, oxidized, node * 0.34);
	// At full retained exposure, cancellation resolves visually into one calm
	// uninterrupted band. This band has no correspondence to channel state.
	float open_band = smoothstep(0.10, 0.035,
		abs(fract((uv.y + world.x * 0.07) * 0.091) - 0.5));
	colour = mix(colour, warm_brass,
		molten * (antinode * (1.0 - sustained) * 0.62
		+ open_band * sustained * 0.88));
	// One quiet material node never moves; waves part around it. Its centre is
	// deliberately unlit and cannot encode a signal or objective.
	vec2 quiet_q = fract(uv / 10.0 + vec2(0.43, 0.19)) - 0.5;
	float quiet = smoothstep(0.16, 0.075, length(quiet_q));
	colour = mix(colour, lapis_cloth * 0.32, quiet * 0.88);
	float room_luma = dot(texture(reflected_world,
		fract(uv * 0.029 + vec2(0.29, 0.61))).rgb,
		vec3(0.299, 0.587, 0.114));
	colour += warm_brass * room_luma * molten * grazing * 0.09;
	float roughness = mix(selected.a, 0.24,
		molten * max(antinode, open_band * sustained));
	roughness = mix(roughness, 0.78, quiet * 0.42);
	return vec4(colour, roughness);
}

vec4 dream_incarnation_surface(vec3 world, vec2 uv, float retained,
		float molten, float awake, float grazing, int slot, vec4 fallback) {
	if (incarnation_id > 0.5 && incarnation_id < 1.5) {
		return mina_surface(world, uv, retained, molten, awake, grazing, slot);
	}
	if (incarnation_id > 1.5 && incarnation_id < 2.5) {
		return peter_surface(world, uv, retained, molten, awake, grazing, slot);
	}
	if (incarnation_id > 2.5 && incarnation_id < 3.5) {
		return juno_surface(world, uv, retained, molten, awake, grazing, slot);
	}
	return fallback;
}
