shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE DREAM MARGIN'S APPENDAGES (ecology architecture §5, §6, §7).
//
// One mesh, one draw, forty independently shaped organs. Each palp is a run
// of rings in the same buffer; UV2.x is its index, UV.y its place along it,
// and the vertex stage bends it onto that palp's spine AND gives it that
// palp's own cross-section progression.
//
// §7 is the reason this shader exists rather than reusing the tendril one.
// A tube with a different radius curve is still a tube; what reads as
// biological variety is the SECTION CHANGING ALONG THE LENGTH. Every palp
// carries four authored sections — root, shaft, sensory region, tip — and
// this interpolates between them, so a Flat Ribbon and a Gold Finger are
// different organs rather than differently-scaled noodles.
//
//   section = (flatten, lobes, lobe_depth, asymmetry)
//
// They wear the same shared material stack as the hero, because they are the
// same organism at a different resolution.
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

const int MAX_PALPS = 40;
const int JOINTS = 6;

uniform vec3 palp_spine[240];        // MAX_PALPS * JOINTS
uniform vec4 palp_section[160];      // MAX_PALPS * 4 stations
// x grow, y base_radius, z tip_ratio, w seed
uniform vec4 palp_params[40];
// x gold, y crystal, z suckers, w cilia
uniform vec4 palp_matter[40];
// §12 STEPS 2-4, THE PREMONITION. x how far along the swelling has got,
// y where along the organ it is happening, z spare, w spare.
//
// Steps 5 and 6 -- folded anatomy separates, secondary appendages unfold --
// were built first, and they arrived out of nowhere: an organ was simple and
// then it was branched. The canonical sequence puts three things before that,
// and all three are surface: the tissue congests with blood at the point, the
// gold structures slide aside to make room, and a crease forms. They are the
// tell. With them the wall shows you where it is about to open.
uniform vec4 palp_branch[40];
// §12 STEPS 8-9, THE FINE ANATOMY AND THE MOMENT THE JOB IS DONE.
//   x  how far the cilia are out. NOT A LENGTH -- it is the angle they are
//      turned through. At 0 they lie along the shaft, seated in its own
//      surface; at 1 they stand off it. Identical size at both ends, which is
//      the governing sentence of §12 applied one level down from the branch.
//   y  where along the organ the ciliated band sits.
//   z  the completion beat, rising and falling across step 9.
//   w  this individual's cilia density (§6: anatomy, not a constant).
uniform vec4 palp_cilia[40];
// MBIO-1 membrane response: x adapted contrast, y photoshock, z scan phase,
// w signed side of the beam. It changes the beat of existing anatomy only.
uniform vec4 palp_photo[40];
// MBIO-3: x response, y carrier/3, z seconds since reception,
// w signed direction across the organ.
uniform vec4 palp_mechanical[40];
uniform int palp_count = 0;
// Proof-only clock pin. The production default follows live TIME; lifecycle
// capture can freeze the same anatomy twice to price the remaining scene
// noise before comparing stages.
uniform float palp_time_override = -1.0;

// How many cilium slots the mesh carries per palp. Matched to
// DreamPalpRenderer.CILIA; an individual uses as many as its anatomy asks for
// and collapses the rest, the way a critter with six limbs collapses two.
const int CILIA = 10;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_thickness;
varying float v_seed;
varying vec4 v_matter;
// xy remain §12's local branch tell. z is shared lifecycle stage/7 and w is
// owner-clock progress. This reuses the two spare palp_branch components.
varying vec4 v_branch;
// x how erect this cilium is, y the completion beat, z which anatomy this
// vertex belongs to (0 shaft, 1 cilium), w how near the ciliated band it is.
varying vec4 v_cilia;
varying vec4 v_mechanical;

vec3 spine_at(int p, float s) {
	float x = clamp(s, 0.0, 1.0) * float(JOINTS - 1);
	int i = int(floor(min(x, float(JOINTS - 1) - 0.001)));
	float f = x - float(i);
	int base = p * JOINTS;
	return mix(palp_spine[base + i], palp_spine[base + min(i + 1, JOINTS - 1)], f);
}

// The cross-section at v, interpolated across the four authored stations.
vec4 section_at(int p, float v) {
	float x = clamp(v, 0.0, 1.0) * 3.0;
	int i = int(floor(min(x, 2.999)));
	float f = x - float(i);
	int base = p * 4;
	return mix(palp_section[base + i], palp_section[base + i + 1], f);
}

// THE ORGAN'S OWN SURFACE, at v along it and a around it, as an offset from
// the spine in the local frame -- plus the radius reached along that offset.
//
// §7 is the reason this is a function rather than four lines inline: the
// SECTION CHANGES ALONG THE LENGTH, and a cilium is seated on that surface,
// not on an idealised cylinder through it. A flat ribbon's hairs have to sit
// on a ribbon. TIME arrives as an argument because built-ins do not reach into
// user functions.
vec3 palp_surface(int p, float v, float a, vec3 sd, vec3 bn, float t,
		out float r_out) {
	vec4 sec = section_at(p, v);
	vec4 par = palp_params[p];
	// The section: an ellipse that flattens, carrying longitudinal lobes and
	// pushed off its own axis so nothing is symmetrical.
	float ca = cos(a);
	float sa = sin(a);
	float ex = ca * (1.0 + sec.x);
	float ez = sa * (1.0 - sec.x);
	float nl = max(0.0001, length(vec2(ex, ez)));
	ex /= nl;
	ez /= nl;
	float lobe = 1.0 + sec.z * cos(sec.y * a + par.w * 2.0);
	float asym = 1.0 + sec.w * cos(a + par.w);
	float taper = mix(par.y, par.y * par.z, pow(v, 1.15));
	float flare = 1.0 + 0.55 * exp(-v * 7.0);
	float stain = step(6.5, palp_branch[p].z * 7.0);
	float breathe = 1.0 + (1.0 - stain) * 0.04 * sin(t * 1.9 + par.w * 3.0);
	r_out = taper * flare * lobe * asym * breathe;
	return sd * ex + bn * ez;
}


// The frame at a point along a palp's spine: where it is, which way it runs,
// and two axes across it.
void palp_frame(int p, float s, out vec3 pos, out vec3 tng, out vec3 sd,
		out vec3 bn) {
	pos = spine_at(p, s);
	tng = normalize(spine_at(p, min(s + 0.08, 1.0)) - spine_at(p, max(s - 0.08, 0.0))
			+ vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(tng.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	sd = normalize(cross(any, tng));
	bn = cross(tng, sd);
}


// §12 STEP 8 -- ONE CILIUM, AS A HAIR THAT PIVOTS.
//
// This is why step 8 was the unbuilt one. A cilium that faded in, or grew out,
// or was a puff of emissive noise on the shaft, would be the banned thing at a
// smaller scale: "never spawn a branch by scaling a cylinder from zero" is a
// statement about how anatomy arrives, and it does not stop applying because
// the cylinder is a millimetre across.
//
// So the hair is FULL LENGTH THROUGHOUT. It is built as a circular arc of
// fixed arc length whose launch direction and curvature are what `erect`
// moves. Folded, it leaves its socket along the shaft and presses back into
// the skin, and reads as fine longitudinal relief ON the organ -- which is the
// point: a player can see the hairs lying down before they stand up, so the
// deployment is unmistakably a pivot and not a growth. Erect, it stands off
// the surface with a distal droop.
//
// The arc-length parameterisation is not decoration. Mixing between a folded
// pose and an erect pose would shorten the hair through the middle of the
// move, and a hair that is shorter halfway through is a hair that scaled.
void cilium(int p, int ci, float along, vec3 ring_n, float grow, float t,
		out vec3 out_pos, out vec3 out_nrm, out vec3 out_tng, out vec3 out_bin,
		out float out_erect, out float out_alive) {
	vec4 par = palp_params[p];
	vec4 cil = palp_cilia[p];
	vec4 photo = palp_photo[p];
	vec4 mechanical = palp_mechanical[p];
	float band = clamp(cil.y, 0.10, 0.92);
	// HOW MANY, AND HOW LONG, ARE PER INDIVIDUAL (§6). A ciliated whisker is
	// made of these; a gold finger has almost none. Six is the floor because
	// below that a band reads as a few stray bristles rather than as a field.
	float n = floor(6.0 + clamp(cil.w, 0.0, 1.0) * float(CILIA - 6));
	float t_i = float(ci) / max(1.0, n - 1.0);
	// Spread ALONG the band and spiralled around it, so it is a field of them
	// and not a ring. A ring is jewellery, which is the mistake §12 step 3
	// already had to be talked out of once.
	float v_root = clamp(band + (t_i - 0.5) * 0.26, 0.06, 0.96);
	float scan_wave = sin(photo.z * 6.2831853 + t_i * 6.2831853 * 1.35);
	float ang = par.w + t_i * 6.2831853 * 2.6
			+ photo.w * photo.x * 0.42 + scan_wave * photo.x * 0.12;

	out_alive = smoothstep(0.0, 0.05, grow - v_root)
			* step(float(ci), n - 0.5) * step(0.00001, par.y);
	if (out_alive <= 0.0) {
		out_pos = spine_at(p, 0.0);
		out_nrm = vec3(0.0, 1.0, 0.0);
		out_tng = vec3(1.0, 0.0, 0.0);
		out_bin = vec3(0.0, 0.0, 1.0);
		out_erect = 0.0;
		return;
	}

	vec3 pos;
	vec3 tng;
	vec3 sd;
	vec3 bn;
	palp_frame(p, v_root, pos, tng, sd, bn);
	float r_band;
	vec3 radial = normalize(palp_surface(p, v_root, ang, sd, bn, t, r_band));

	// ORDERED TIMING. They do not all come up at once: deployment runs DOWN the
	// band from the proximal end, so what is on screen is a wave passing along
	// the organ rather than a switch being thrown. One clock in the controller,
	// and the order in it comes from here.
	float lead = 0.55;
	float erect = clamp((cil.x - t_i * lead) / max(0.001, 1.0 - lead), 0.0, 1.0);
	float beat = cil.z;
	out_erect = erect;

	float len = r_band * (3.5 + 4.0 * clamp(cil.w, 0.0, 1.0));
	// Seated in a socket it rises very slightly out of as it erects. A
	// translation, deliberately, and never a scale.
	vec3 base = pos + radial * (r_band * mix(0.92, 1.0, erect));

	vec3 out_dir = normalize(radial + tng * 0.30);
	vec3 d0 = normalize(mix(tng, out_dir, erect));
	// A cilium carpet resolves direction by phase differences across the
	// field. Contrast advances one side and retards the other; a photoshock
	// reverses the power stroke briefly. No cilium changes length.
	vec3 across = normalize(cross(tng, radial) + vec3(1e-5, 0.0, 0.0));
	// A carpet is many motors with neighbouring phase offsets. Sustained hum
	// loads and slows the field; an impulse reverses the local power stroke.
	float carrier = floor(mechanical.y * 3.0 + 0.5);
	float is_impulse = 1.0 - step(0.45, abs(carrier - 1.0));
	float is_hum = 1.0 - step(0.45, abs(carrier - 3.0));
	float motor_rate = mix(7.2, 2.0, is_hum * mechanical.x);
	float motor_direction = mix(1.0, -1.0, is_impulse * mechanical.x);
	float motor_wave = sin(t * motor_rate * motor_direction
			+ t_i * 6.2831853 * 1.65 + par.w);
	d0 = normalize(d0 + across * photo.x
			* (scan_wave * 0.32 + photo.w * 0.38));
	d0 = normalize(d0 + across * motor_wave * erect
			* (0.12 + 0.20 * cil.w) * (1.0 - mechanical.x * is_hum * 0.72)
			+ across * mechanical.w * mechanical.x * 0.16);
	d0 = normalize(mix(d0, normalize(-tng * 1.15 + radial * 0.22),
			photo.y * (0.72 + 0.18 * t_i)));
	// FOLDED MEANS LYING ALONG THE SURFACE, NOT BURIED IN IT.
	//
	// The first version curled a folded cilium back INTO the shaft, on the
	// reasoning that §12's "folded inside simple anatomy" should apply to a
	// hair the way it applies to a branch. Photographed, that is a disaster:
	// the folded frame has no hairs in it at all, so what a player sees is
	// nothing becoming something, which is indistinguishable from the spawn
	// effect the whole section exists to ban. The proof of "these are the same
	// hairs at the same length" is that you can SEE them lying down.
	//
	// A cylinder is developable, so a line running along the axis stays on the
	// surface: a folded cilium is nearly straight and hugs the shaft, reading
	// as fine longitudinal relief. Erect, it stands off with a distal droop.
	float curl = mix(0.12, 0.45, erect)
			+ photo.x * (0.10 + 0.10 * scan_wave) + photo.y * 0.52;
	// §12 STEP 9 -- THE CLOSE. The job is finished, so the whole band pitches
	// forward onto the thing it was working and draws in together. One gesture
	// of the fine anatomy, which is what makes completion a BEAT rather than a
	// flag: the branch stops, the cilia close, the band under them floods.
	d0 = normalize(mix(d0, normalize(tng * 1.25 + radial * 0.30), beat * 0.85));
	curl += beat * 0.85;

	vec3 d90 = -radial - d0 * dot(-radial, d0);
	float d90l = length(d90);
	d90 = d90l > 1e-5 ? d90 / d90l
			: normalize(cross(d0, tng) + vec3(1e-5, 0.0, 0.0));

	float th = curl * along;
	// An arc of total turn `curl` over arc length `len`. Exact for any curl,
	// and the degenerate case is the straight hair.
	vec3 offset = curl < 0.0001
			? d0 * (len * along)
			: (d0 * sin(th) + d90 * (1.0 - cos(th))) * (len / curl);
	vec3 seg = normalize(d0 * cos(th) + d90 * sin(th));

	float thick = r_band * 0.26 * (1.0 - 0.70 * along);
	vec3 any_c = abs(seg.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 cs = normalize(cross(any_c, seg));
	vec3 cb = cross(seg, cs);
	float ring_a = atan(ring_n.y, ring_n.x);
	vec3 ring = cs * cos(ring_a) + cb * sin(ring_a);
	out_pos = base + offset + ring * thick;
	out_nrm = normalize(ring);
	out_tng = seg;
	out_bin = cross(ring, seg);
}


void vertex() {
	int p = int(UV2.x + 0.5);
	vec4 par = palp_params[p];
	float grow = par.x;
	float palp_time = palp_time_override >= 0.0 ? palp_time_override : TIME;

	// WHICH ANATOMY THIS VERTEX IS. UV2.y 0 is the shaft, 1 is one of the
	// individual's cilia. One vertex program, two structures, one draw --
	// dream_critter.gdshader does the same with bodies, limbs and feelers, and
	// for the same reason: the frame is submission-bound, so new anatomy is
	// paid for in vertices and never in submissions.
	//
	// An if/else and not an early return: Godot rejects `return` in a
	// processor function outright, and it does so at shader COMPILE time --
	// which the headless contract runs never reach, so the margin test passed
	// green while nothing drew at all. `ShaderParseCheck.tscn` is the run that
	// catches it.
	if (UV2.y > 0.5) {
		vec3 c_pos;
		vec3 c_nrm;
		vec3 c_tng;
		vec3 c_bin;
		float c_erect;
		float c_alive;
		cilium(p, int(UV.x + 0.5), UV.y, NORMAL, grow, palp_time,
				c_pos, c_nrm, c_tng, c_bin, c_erect, c_alive);
		VERTEX = c_pos;
		NORMAL = c_nrm;
		TANGENT = c_tng;
		BINORMAL = c_bin;
		v_uv = vec2(UV.x, UV.y);
		v_world = VERTEX;
		// Fine anatomy is THIN, and thin dream tissue transmits: a cilium lit
		// from behind should carry light through it, which a shaft should not.
		v_thickness = 0.10;
		v_seed = par.w;
		v_matter = palp_matter[p];
		v_branch = vec4(0.0, 0.0, palp_branch[p].z, palp_branch[p].w);
		v_cilia = vec4(c_erect, palp_cilia[p].z, 1.0, 1.0);
		v_mechanical = palp_mechanical[p];
	} else {

		float v = UV.y;
		float u = UV.x;
		float s = min(v, grow);
		float alive = smoothstep(0.0, 0.06, grow - v * 0.9);

		vec3 pos;
		vec3 tng;
		vec3 sd;
		vec3 bn;
		palp_frame(p, s, pos, tng, sd, bn);

		float r;
		vec3 radial = palp_surface(p, v, u * 6.2831853 + par.w, sd, bn,
				palp_time, r);
		r *= alive;

		VERTEX = pos + radial * r;
		NORMAL = normalize(radial);
		TANGENT = tng;
		BINORMAL = cross(radial, tng);
		v_uv = vec2(u, v);
		v_world = VERTEX;
		v_thickness = clamp(0.85 - 0.7 * v, 0.0, 1.0);
		v_seed = par.w;
		v_matter = palp_matter[p];
		// How strongly this vertex is inside the swelling, and how close it is to
		// the crease itself.
		vec4 br = palp_branch[p];
		float from_line = abs(v - br.y);
		float near_crease = 1.0 - smoothstep(0.0, 0.20, from_line);
		v_branch = vec4(br.x, near_crease, br.z, br.w);
		// And how close it is to the CILIATED BAND, which is where §12 step 9 puts
		// its flush -- the same tissue signal as step 2's congestion, at the other
		// end of the sequence.
		float from_band = abs(v - palp_cilia[p].y);
		v_cilia = vec4(0.0, palp_cilia[p].z, 0.0,
				1.0 - smoothstep(0.0, 0.18, from_band));
		v_mechanical = palp_mechanical[p];
		// STEP 2, in the geometry as well as the colour: congested tissue is
		// SWOLLEN. And STEP 4: the crease itself is a furrow, so the middle of
		// the swelling goes back in further than the shoulders come out.
		float furrow = 1.0 - smoothstep(0.0, 0.075, from_line);
		VERTEX += normalize(radial) * br.x
				* (near_crease * 0.024 - furrow * 0.040);
	}
}


void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float palp_time = palp_time_override >= 0.0 ? palp_time_override : TIME;
	DeCtx ctx;
	ctx.thickness = v_thickness;
	ctx.vein = 0.4;
	// Which anatomy this fragment belongs to, and how far through §12 step 9
	// the individual carrying it is.
	float part = v_cilia.z;
	float beat = v_cilia.y;
	// The membrane event is local and travels root-to-tip. This band changes
	// perfusion in the existing tissue stack; it is not an emissive game flash.
	float relay_front = v_mechanical.z * 0.82;
	float relay = (1.0 - smoothstep(0.025, 0.16,
			abs(v_uv.y - relay_front))) * v_mechanical.x;
	ctx.vein = clamp(ctx.vein + relay * (0.58 + 0.22 * part), 0.0, 1.0);
	// §12 STEP 9 -- THE COMPLETION BEAT, ON THE SURFACE. The band under the
	// fine anatomy floods while the job is being finished, exactly the way the
	// crease floods before the branch opens at step 2. The same tissue doing
	// the same thing at the other end of the sequence, so a player who has
	// learned to read one reads the other.
	ctx.vein = clamp(ctx.vein + beat * v_cilia.w * 0.75, 0.0, 1.0);
	// §12 STEP 2 — LOCAL VASCULAR CONGESTION. Blood arrives before anatomy
	// does, so the tissue about to open runs dark and full.
	float swell = v_branch.x;
	float at_crease = v_branch.y;
	float life_stage = floor(clamp(v_branch.z, 0.0, 1.0) * 7.0 + 0.5);
	float is_folded = 1.0 - step(0.5, abs(life_stage - 0.0));
	float is_bud = 1.0 - step(0.5, abs(life_stage - 1.0));
	float is_juvenile = 1.0 - step(0.5, abs(life_stage - 2.0));
	float is_exchange = 1.0 - step(0.5, abs(life_stage - 4.0));
	float is_senescent = 1.0 - step(0.5, abs(life_stage - 5.0));
	float is_shed = 1.0 - step(0.5, abs(life_stage - 6.0));
	float is_stain = 1.0 - step(0.5, abs(life_stage - 7.0));
	// Perfusion arrives, peaks during function/exchange, then withdraws. It is
	// surface state on complete tissue, never opacity or scale.
	ctx.vein = clamp(ctx.vein * (1.0 - is_folded * 0.55)
			+ is_bud * 0.34 + is_juvenile * 0.22 + is_exchange * 0.38,
			0.0, 1.0);
	ctx.thickness = clamp(ctx.thickness + is_bud * 0.16
			- is_senescent * 0.12 - is_shed * 0.22, 0.05, 1.0);
	ctx.vein = clamp(ctx.vein + swell * at_crease * 0.85, 0.0, 1.0);
	ctx.thickness = clamp(ctx.thickness + swell * at_crease * 0.30, 0.0, 1.0);
	// §6: gold percentage is per-individual anatomy, not decoration.
	// §12 STEP 3 — GOLD STRUCTURES REPOSITION. The mineral cannot open, so it
	// gets out of the way: CLEARED from the line and crowded into the
	// shoulders either side, which is what makes the crease read as something
	// the body is doing rather than as a stripe painted on it.
	//
	// The first version added metal at the centre as well as the shoulders,
	// because the term meant to remove it was multiplied by the individual's
	// own gold fraction and lost to the term adding it. Photographed, that is
	// a gold RING -- an ornament, which is the one thing this must not be.
	float centre = smoothstep(0.45, 0.92, at_crease);
	float shoulder = at_crease * (1.0 - centre);
	ctx.gold_root = clamp(v_matter.x
			+ swell * (shoulder * 0.70 - centre * (v_matter.x + 0.35) * 1.6),
			0.0, 1.0);
	// A cilium has no sucker pad and no mineral socket -- those are distal
	// specialisations of the SHAFT, and painting them onto a hair would make
	// the fine anatomy read as a scaled copy of the coarse anatomy.
	ctx.contact = v_matter.z * smoothstep(0.55, 1.0, v_uv.y) * (1.0 - part);
	ctx.socket = v_matter.y * smoothstep(0.7, 1.0, v_uv.y) * (1.0 - part);
	ctx.gold_root *= mix(1.0, 0.30, part);
	ctx.stretch = 0.3;
	ctx.lod = 1.0 - smoothstep(1.5, 6.0, length(VERTEX));
	DeMasks m = de_masks(v_world, v_uv, n, view_dir, palp_time, v_seed, ctx);
	DeOut o = de_shade(m, v_world, v_uv, n, view_dir, palp_time, v_seed, ctx);
	// §12 STEP 4 — THE CREASE. A line that is darker, wetter and deeply
	// occluded: the inside of a fold, seen edge on.
	//
	// WIDE ENOUGH TO SURVIVE THE DISTANCE IT IS SEEN FROM. The first version
	// was a hairline over five per cent of the organ's length, which on a
	// three-centimetre appendage across a room is less than a pixel -- the
	// swelling was doing everything and the crease itself contributed
	// nothing. It runs over about a seventh of the length now.
	float line = smoothstep(0.55, 0.95, at_crease) * swell;
	ALBEDO = mix(o.albedo, o.albedo * 0.14, line);
	vec3 exchange_wet = mix(ALBEDO, vec3(0.16, 0.22, 0.48), 0.42);
	vec3 bruise = ALBEDO * vec3(0.62, 0.48, 1.18);
	ALBEDO = mix(ALBEDO, exchange_wet, is_exchange * 0.42);
	ALBEDO = mix(ALBEDO, bruise, is_senescent * 0.52 + is_shed * 0.72);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.16, 0.70, 1.22), relay * 0.38);
	// What remains is not a decal. It is the organ's authored silhouette
	// pressed into the wall: wet hematoma, mineral trace and cold violet
	// secretion, beautiful enough to invite inspection and wrong enough to
	// make the visit remember where tissue ended.
	vec3 stain_colour = mix(vec3(0.035, 0.008, 0.055),
			vec3(0.17, 0.035, 0.22), m.vein);
	stain_colour += vec3(0.10, 0.065, 0.025) * ctx.gold_root;
	ALBEDO = mix(ALBEDO, stain_colour, is_stain * 0.88);
	METALLIC = o.metallic * (1.0 - line * 0.9);
	ROUGHNESS = clamp(o.roughness - line * 0.30 - is_stain * 0.20, 0.03, 1.0);
	SPECULAR = o.specular;
	// 2.2 was tuned when these were 5 cm tendrils that had to be seen at all.
	// At primary scale it blows every archetype out to the same molten gold,
	// which is exactly the failure §37 names: they must differ WITHOUT
	// relying on colour, and they cannot differ at all if they are all
	// saturated. The gold fraction is per-individual anatomy (§6), so let it
	// decide how much light a given organ actually carries.
	EMISSION = o.emission * (0.55 + 1.25 * v_matter.x)
			* (1.0 - is_folded * 0.62 - is_shed * 0.48 - is_stain * 0.72);
	BACKLIGHT = o.backlight;
	AO = o.ao * (1.0 - line * 0.85);
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.6 + BINORMAL * nm.y * 0.6);
}
