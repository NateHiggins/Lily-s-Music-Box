// Sixteen species, sixteen optical grammars, one shared material and one shared
// DreamExposureField.  The functions below only interpret R (durable history)
// and G (current irradiance); they neither own the field nor write ecology.

struct CritterVoxelOptics {
	vec3 absorption;
	vec3 current_light;
	vec3 durable_memory;
	float relief;
	float roughness_shift;
	float scatter;
};

float critter_hash31(vec3 p) {
	p = fract(p * .1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float critter_fbm(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = critter_hash31(i);
	float b = critter_hash31(i + vec3(1.0, 0.0, 0.0));
	float c = critter_hash31(i + vec3(0.0, 1.0, 0.0));
	float d = critter_hash31(i + vec3(1.0, 1.0, 0.0));
	float e = critter_hash31(i + vec3(0.0, 0.0, 1.0));
	float g = critter_hash31(i + vec3(1.0, 0.0, 1.0));
	float h = critter_hash31(i + vec3(0.0, 1.0, 1.0));
	float j = critter_hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
			mix(mix(e, g, f.x), mix(h, j, f.x), f.y), f.z);
}

// Seam grazer: wet thin tissue, a dense ventral comb and capillaries that
// divide, rejoin and remember the architectural seam in R.
CritterVoxelOptics grazer_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float phase) {
	CritterVoxelOptics o;
	float comb = pow(.5 + .5 * sin(p.x * (38.0 + anatomy.x * 24.0)
			+ sin(p.z * 9.0) * 2.3), 8.0);
	float branch_a = exp(-abs(sin(p.z * 11.0 + p.x * 4.0 + phase * .22)) * 7.0);
	float branch_b = exp(-abs(sin(p.z * 17.0 - p.x * 7.0 - phase * .15)) * 10.0);
	float capillary = max(branch_a, branch_b * smoothstep(-.8, .4, p.z));
	float pore = pow(critter_fbm(p * (16.0 + anatomy.y * 15.0)), 7.0);
	float g = smoothstep(.004, .14, rg.g);
	float r = smoothstep(.006, .080, rg.r);
	o.absorption = mix(vec3(.21, .215, .145), vec3(.47, .45, .275), comb * .34)
			- vec3(.13, .095, .040) * capillary;
	o.current_light = vec3(.54, .76, .31) * g * (comb * .48 + capillary * .74 + .12);
	o.durable_memory = vec3(.50, .075, .24) * r * (capillary * .72 + pore * .28);
	o.relief = comb * .34 + pore * .18;
	o.roughness_shift = -.10 * comb + .08 * pore;
	o.scatter = .52 + anatomy.z * .18 + g * .20;
	return o;
}

// Crystal listener: the outer dome stays dark while a rotating angular
// resonator produces polarized caustics and an angular R-memory lattice.
CritterVoxelOptics listener_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float spin) {
	CritterVoxelOptics o;
	float angle = atan(p.x, p.z) + spin;
	float radius = length(p.xz);
	float ribs = pow(.5 + .5 * cos(angle * (8.0 + floor(anatomy.x * 5.0))
			+ radius * 24.0), 15.0);
	float prism = pow(abs(dot(n, normalize(vec3(cos(spin), .24, sin(spin))))),
			10.0 + anatomy.w * 18.0);
	float chamber = exp(-abs(sin(radius * 31.0 - p.y * 13.0)) * 13.0);
	float g = smoothstep(.004, .14, rg.g);
	float r = smoothstep(.006, .080, rg.r);
	o.absorption = mix(vec3(.035, .052, .060), vec3(.18, .28, .285),
			chamber * .46 + ribs * .34);
	o.current_light = mix(vec3(.12, .58, .63), vec3(.67, .45, .79), prism)
			* g * (ribs * .74 + prism * .62 + .06);
	o.durable_memory = vec3(.31, .12, .54) * r * (ribs * .72 + chamber * .20);
	o.relief = ribs * .22 + chamber * .12;
	o.roughness_shift = -.18 * prism + .09;
	o.scatter = .18 + anatomy.z * .16 + prism * .12;
	return o;
}

// Fold crab: ossified dorsal plates, dark sutures and load paths from socket
// to ventrum.  G walks those paths; R accumulates in seams and the rear
// transfer rosette instead of washing the animal in one colour.
CritterVoxelOptics crab_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float information) {
	CritterVoxelOptics o;
	float longitudinal = exp(-abs(sin(p.z * (20.0 + anatomy.x * 12.0)
			+ p.x * 3.1)) * 14.0);
	float cross_suture = exp(-abs(sin(p.x * 22.0 - p.z * 5.0)) * 18.0);
	float load = max(longitudinal * smoothstep(-.5, .5, -p.y),
			cross_suture * smoothstep(.15, .9, abs(p.x)));
	float rosette = pow(.5 + .5 * cos(atan(p.x, p.y) * 6.0 + length(p.xy) * 34.0), 10.0)
			* (1.0 - smoothstep(-.85, -.15, p.z));
	float g = smoothstep(.004, .14, rg.g);
	float r = smoothstep(.006, .080, rg.r);
	o.absorption = mix(vec3(.19, .175, .145), vec3(.48, .42, .265), load * .38)
			- vec3(.14, .125, .095) * cross_suture;
	o.current_light = vec3(.72, .47, .19) * g * (load * .76 + information * .24 + .05);
	o.durable_memory = vec3(.36, .075, .13) * r
			* (cross_suture * .54 + rosette * .72);
	o.relief = longitudinal * .28 + cross_suture * .20;
	o.roughness_shift = .10 - load * .13;
	o.scatter = .25 + anatomy.z * .14 + g * .08;
	return o;
}

// Cat-sized tardigrade: reticulate/pseudoporous folded cuticle over a dense
// pharynx-gut axis, storage-cell clouds, eight muscle fields and high-index
// double claws.  G reveals near-side hydrostatic work; R remains in folds,
// claws and the gut route after the cone leaves.
CritterVoxelOptics tardigrade_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase) {
	CritterVoxelOptics o;
	float annuli = pow(.5 + .5 * cos((p.z + .08 * sin(p.x * 9.0))
			* (15.0 + anatomy.x * 9.0)), 10.0);
	vec3 cell = p * (13.0 + anatomy.y * 9.0);
	float reticulum = pow(abs(sin(cell.x + sin(cell.z)) * sin(cell.y - cell.z * .7)), 4.0);
	float pseudopore = pow(critter_fbm(cell * 1.7), 13.0);
	// Project dense axial anatomy through the intact cuticle.  Omitting x here
	// is deliberate: from either flank the pharynx and gut remain optical
	// volumes behind membrane rather than vanishing when the surface point is
	// one body radius away from the centreline.
	float pharynx = exp(-((p.z - .30) * (p.z - .30) * 52.0 +
			(p.y - .035) * (p.y - .035) * 31.0));
	float gut = exp(-(p.y * p.y * 24.0))
			* (1.0 - smoothstep(-.72, .74, p.z));
	float gut_axis = exp(-pow(p.y + sin(p.z * 9.0 + phase * .08) * .045, 2.0)
			* 190.0) * (1.0 - smoothstep(-.68, .60, p.z));
	float muscle = pow(.5 + .5 * sin(p.z * 18.0 + abs(p.x) * 24.0 + phase * .28), 12.0)
			* smoothstep(.16, .82, abs(p.x));
	float claw = step(13.5, part);
	float g = smoothstep(.004, .14, rg.g);
	float r = smoothstep(.006, .080, rg.r);
	float near_side = .28 + .72 * smoothstep(-.45, .72, dot(n, normalize(vec3(.35, .28, .89))));
	float storage = critter_fbm(p * 18.0 + vec3(phase * .015, 0.0, 0.0));
	o.absorption = mix(vec3(.275, .245, .195), vec3(.53, .465, .325), annuli * .34)
			- vec3(.19, .135, .105) * pharynx
			- vec3(.14, .095, .055) * gut
			- vec3(.20, .155, .095) * gut_axis
			+ vec3(.035, .030, .018) * smoothstep(.62, .82, storage);
	o.current_light = vec3(.72, .69, .33) * g * near_side
			* (pharynx * .82 + gut * .30 + gut_axis * .70 + muscle * .62
					+ reticulum * .10 + .06);
	o.durable_memory = vec3(.48, .095, .30) * r
			* (annuli * .35 + gut * .58 + pseudopore * .16 + claw * .72);
	o.relief = annuli * .42 + reticulum * .20 + pseudopore * .28;
	o.roughness_shift = .05 + pseudopore * .12 - annuli * .10 - claw * .18;
	o.scatter = .58 + anatomy.z * .22 + g * .12;
	return o;
}

// Stentor: the incident field spirals through membranelles and longitudinal
// myonemes; durable exposure settles into alternating cortical pigment bands.
CritterVoxelOptics stentor_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float phase, float contraction) {
	CritterVoxelOptics o;
	float angle = atan(p.x, p.z);
	float oral = smoothstep(.18, .92, p.y);
	float spiral = pow(.5 + .5 * sin(angle * 11.0 + p.y * 28.0 - phase), 10.0);
	float myoneme = pow(.5 + .5 * cos(angle * 8.0 + p.y * 2.4), 16.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.12,.19,.18),vec3(.26,.37,.31),spiral*.48)
			-vec3(.08,.06,.02)*myoneme;
	o.current_light=vec3(.28,.78,.52)*g*(oral*spiral*.88+myoneme*.34+.04);
	o.durable_memory=vec3(.42,.08,.32)*r*(myoneme*.70+spiral*.22);
	o.relief=spiral*.28+myoneme*.20; o.roughness_shift=.06-spiral*.14;
	o.scatter=.50+anatomy.z*.18+contraction*.08; return o;
}

// Lacrymaria: a traveling light pulse and its memory braid occupy the neck;
// the anchored body remains optically quiet.
CritterVoxelOptics lacrymaria_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase) {
	CritterVoxelOptics o;
	float neck=step(1.5,part)*(1.0-step(2.5,part));
	float helix=pow(.5+.5*sin(atan(p.x,p.y)*3.0+p.z*19.0-phase*2.0),12.0);
	float pulse=exp(-pow(fract(p.z*.22-phase*.035)-.5,2.0)*90.0);
	float head=1.0-smoothstep(.0,.7,abs(part-3.0));
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.18,.16,.11),vec3(.35,.28,.19),helix*.35+head*.20);
	o.current_light=vec3(.72,.66,.25)*g*(neck*(pulse*.92+helix*.22)+head*.52);
	o.durable_memory=vec3(.48,.07,.30)*r*(neck*helix*.82+head*.28);
	o.relief=helix*.30; o.roughness_shift=-.08*neck+.08; o.scatter=.44+anatomy.z*.20;
	return o;
}

// Vorticella: present light circles the peristome and runs down the elastic
// stalk; exposure memory preserves a tight helical spasmoneme trace.
CritterVoxelOptics vorticella_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase, float coil) {
	CritterVoxelOptics o;
	float stalk=step(.5,part)*(1.0-step(1.5,part));
	float oral=step(1.5,part)*(1.0-step(2.5,part));
	float helix=pow(.5+.5*sin(atan(p.x,p.z)*5.0+p.y*35.0-phase),14.0);
	float vortex=pow(.5+.5*cos(atan(p.x,p.z)*12.0-phase*3.0),12.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.13,.17,.15),vec3(.34,.33,.23),helix*.30+vortex*.22);
	o.current_light=vec3(.35,.76,.50)*g*(oral*vortex*.88+stalk*helix*.66+.04);
	o.durable_memory=vec3(.44,.08,.26)*r*(stalk*helix*.92+oral*.14);
	o.relief=helix*.25+vortex*.20; o.roughness_shift=.04-vortex*.12;
	o.scatter=.42+anatomy.z*.18+coil*.10; return o;
}

// Euplotes: voxel G marches through ventral fiber bundles in gait order while
// R records stressed cirral roots and engraved dorsal plate sutures.
CritterVoxelOptics euplotes_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float gait) {
	CritterVoxelOptics o;
	float cirrus=step(.5,part)*(1.0-step(1.5,part))+step(13.5,part);
	float plates=pow(.5+.5*sin(p.x*27.0+abs(p.z)*18.0),18.0);
	float fibers=pow(.5+.5*cos(p.z*24.0-p.x*9.0-gait*2.0),14.0);
	float step_wave=exp(-pow(fract(p.z*.8-gait*.11)-.5,2.0)*48.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.11,.13,.12),vec3(.31,.29,.20),plates*.46)-vec3(.05)*fibers;
	o.current_light=vec3(.63,.72,.29)*g*(cirrus*(step_wave*.78+fibers*.36)+.03);
	o.durable_memory=vec3(.40,.075,.25)*r*(cirrus*.62+plates*.48);
	o.relief=plates*.36+fibers*.16; o.roughness_shift=.10-plates*.15;
	o.scatter=.30+anatomy.z*.17; return o;
}

// Spirostomum: a calcium-like G front races through a diagonal myoneme
// fishnet; R becomes spatially trapped in the RER-vacuolar damping mesh.
CritterVoxelOptics spirostomum_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float phase, float contraction) {
	CritterVoxelOptics o;
	float net_a=pow(.5+.5*sin(p.z*31.0+p.x*17.0),18.0);
	float net_b=pow(.5+.5*sin(p.z*31.0-p.y*19.0),18.0);
	float fishnet=max(net_a,net_b);
	float front=exp(-pow(p.z-mix(-.8,.8,contraction),2.0)*34.0);
	float rer=critter_fbm(p*15.0+vec3(phase*.03,0.0,0.0));
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.12,.15,.14),vec3(.30,.34,.26),fishnet*.34)-vec3(.08)*rer;
	o.current_light=vec3(.33,.78,.62)*g*(front*.88+fishnet*.38+.03);
	o.durable_memory=vec3(.46,.08,.31)*r*(smoothstep(.58,.78,rer)*.72+fishnet*.24);
	o.relief=fishnet*.31; o.roughness_shift=.06-fishnet*.12;
	o.scatter=.56+anatomy.z*.20+rer*.12; return o;
}

// Heliozoan: the field climbs birefringent axonemes; capture memory condenses
// along one selected ray and in low-density food vacuoles.
CritterVoxelOptics heliozoan_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float chosen, float capture) {
	CritterVoxelOptics o;
	float ray=step(1.5,part)*(1.0-step(2.5,part))+step(13.5,part);
	float vacuole=step(2.5,part)*(1.0-step(9.5,part));
	float axial=pow(abs(dot(n,normalize(vec3(.62,.38,.69)))),12.0+anatomy.w*12.0);
	float knots=pow(critter_fbm(p*21.0+chosen*7.0),9.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.075,.105,.11),vec3(.25,.30,.27),knots*.35+vacuole*.16);
	o.current_light=mix(vec3(.22,.67,.66),vec3(.68,.48,.74),axial)*g
			*(ray*(.48+axial*.54)+vacuole*.18+.02);
	o.durable_memory=vec3(.47,.07,.32)*r*(ray*capture*.62+vacuole*knots*.48);
	o.relief=ray*.16+knots*.22; o.roughness_shift=.08-ray*.20;
	o.scatter=.36+anatomy.z*.17+vacuole*.18; return o;
}

// Euglena: spiral pellicle strips phase-shift with metaboly, the eyespot clips
// incident G, and durable R settles into stressed photophobic strips.
CritterVoxelOptics euglena_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase, float eye_side) {
	CritterVoxelOptics o;
	float spiral=pow(.5+.5*sin(atan(p.x,p.y)*8.0+p.z*24.0-phase*2.0),14.0);
	float plastid=step(2.5,part)*(1.0-step(8.5,part));
	float eyespot=step(7.5,part)*(1.0-step(9.5,part));
	float shade=mix(.30,1.0,smoothstep(-.8,.7,dot(n,normalize(vec3(eye_side,.2,.85)))));
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.10,.18,.12),vec3(.28,.38,.20),plastid*.48+spiral*.22)
			-vec3(.09,.03,.01)*eyespot;
	o.current_light=vec3(.40,.78,.27)*g*shade*(plastid*.68+spiral*.28+eyespot*.18+.03);
	o.durable_memory=vec3(.45,.075,.26)*r*(spiral*.65+eyespot*.54);
	o.relief=spiral*.34; o.roughness_shift=.05-spiral*.13;
	o.scatter=.45+anatomy.z*.20+plastid*.08; return o;
}

// Volvox: G is a traveling somatic lattice; R occupies daughters and the
// cytoplasmic bridges at different depths during inversion.
CritterVoxelOptics volvox_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase, float inversion) {
	CritterVoxelOptics o;
	float surface=1.0-step(2.5,part);
	float daughter=step(2.5,part)*(1.0-step(9.5,part));
	float bridge=step(12.5,part)*(1.0-step(13.5,part));
	float lattice=pow(.5+.5*sin(atan(p.x,p.z)*13.0+p.y*18.0-phase),15.0);
	float depth=.35+.65*smoothstep(-.8,.7,dot(n,normalize(vec3(.4,.25,.88))));
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.10,.17,.13),vec3(.27,.36,.23),lattice*.40+daughter*.22);
	o.current_light=vec3(.42,.78,.34)*g*(surface*lattice*depth*.76+bridge*.42+.03);
	o.durable_memory=vec3(.46,.075,.29)*r*(daughter*(.45+.35*inversion)+bridge*.62);
	o.relief=lattice*.27; o.roughness_shift=.08-lattice*.15;
	o.scatter=.62+anatomy.z*.13+daughter*.12; return o;
}

// Noctiluca: local G launches a wave through the thin vacuolar rind and
// discrete scintillons; durable R remains in ingested material, never emission.
CritterVoxelOptics noctiluca_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase, float flash) {
	CritterVoxelOptics o;
	float rind=1.0-step(2.5,part);
	float cord=step(12.5,part);
	float scint=pow(critter_fbm(p*29.0+vec3(phase*.08,0.0,0.0)),13.0);
	float wave=exp(-pow(fract(atan(p.x,p.z)/6.2831853-phase*.08)-.5,2.0)*70.0);
	float vacuity=1.0-smoothstep(.16,.72,length(p));
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.07,.10,.105),vec3(.27,.24,.17),scint*.24+cord*.25);
	o.current_light=vec3(.20,.63,.78)*g*(rind*scint*(.28+flash*wave*.92)+cord*.24+.02);
	o.durable_memory=vec3(.48,.085,.27)*r*((1.0-rind)*.30+scint*.18);
	o.relief=scint*.20; o.roughness_shift=.10-scint*.16;
	o.scatter=.68+anatomy.z*.12+vacuity*.20; return o;
}

// Bacillaria: silica nanopores split current light along each raphe; durable
// exposure traces mucilage contacts between sliding frustules.
CritterVoxelOptics bacillaria_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase) {
	CritterVoxelOptics o;
	float stria=pow(.5+.5*cos(p.z*(42.0+anatomy.x*30.0)),20.0);
	float pore=pow(critter_fbm(p*31.0),12.0);
	float raphe=exp(-abs(p.x)*20.0);
	float slide=pow(.5+.5*sin(p.z*15.0-phase*2.0),10.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.08,.105,.11),vec3(.34,.31,.21),stria*.32+pore*.18);
	o.current_light=mix(vec3(.20,.58,.67),vec3(.68,.58,.29),stria)*g
			*(raphe*.72+stria*.30+.03);
	o.durable_memory=vec3(.43,.075,.25)*r*(slide*.58+raphe*.34);
	o.relief=stria*.34+pore*.18; o.roughness_shift=.02-stria*.17;
	o.scatter=.18+anatomy.z*.10; return o;
}

// Salpingoeca: G runs from flagellar tips through microvillar collars toward
// prey density; R settles in clonal bridges and central extracellular matrix.
CritterVoxelOptics salpingoeca_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase) {
	CritterVoxelOptics o;
	float flagellum=step(1.5,part)*(1.0-step(2.5,part));
	float cell=step(2.5,part)*(1.0-step(12.5,part));
	float bridge=step(12.5,part)*(1.0-step(13.5,part));
	float collar=pow(.5+.5*cos(atan(p.x,p.z)*18.0-phase),14.0);
	float prey=pow(critter_fbm(p*24.0+phase*.03),11.0);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.11,.15,.135),vec3(.28,.31,.24),collar*.30+cell*.20);
	o.current_light=vec3(.34,.76,.48)*g*(flagellum*(.32+collar*.44)+cell*prey*.38+.03);
	o.durable_memory=vec3(.45,.07,.30)*r*(bridge*.78+cell*prey*.26);
	o.relief=collar*.22+prey*.15; o.roughness_shift=.06-collar*.11;
	o.scatter=.48+anatomy.z*.18; return o;
}

// Mesodinium: current G excites stolen plastid packets while durable R halos
// the displaced kleptokaryon; the host ciliary equator remains a third layer.
CritterVoxelOptics mesodinium_voxel_optics(vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, float phase) {
	CritterVoxelOptics o;
	float cilia=step(1.5,part)*(1.0-step(2.5,part));
	float kleptokaryon=step(2.5,part)*(1.0-step(4.5,part));
	float plastid=step(4.5,part)*(1.0-step(12.5,part));
	float thylakoid=pow(.5+.5*sin(p.x*23.0+p.z*17.0+phase),12.0);
	float orbit=.5+.5*sin(atan(p.x,p.z)*5.0-phase*.8);
	float g=smoothstep(.004,.14,rg.g), r=smoothstep(.006,.08,rg.r);
	o.absorption=mix(vec3(.13,.14,.105),vec3(.34,.32,.19),plastid*(.30+.25*thylakoid))
			-vec3(.07,.055,.035)*kleptokaryon;
	o.current_light=vec3(.58,.72,.25)*g*(plastid*(.35+.52*thylakoid)+cilia*.28+.03);
	o.durable_memory=vec3(.50,.07,.31)*r*(kleptokaryon*.82+plastid*orbit*.24);
	o.relief=thylakoid*plastid*.25+cilia*.12; o.roughness_shift=.06-thylakoid*.12;
	o.scatter=.52+anatomy.z*.20+kleptokaryon*.12; return o;
}

CritterVoxelOptics critter_voxel_optics(float plan, vec3 p, vec3 n, vec2 rg,
		vec4 anatomy, float part, vec4 law, vec4 photo, float phase) {
	if (plan > 14.5) {
		return mesodinium_voxel_optics(p,n,rg,anatomy,part,law.x);
	}
	if (plan > 13.5) {
		return salpingoeca_voxel_optics(p,n,rg,anatomy,part,law.x);
	}
	if (plan > 12.5) {
		return bacillaria_voxel_optics(p,n,rg,anatomy,part,law.x);
	}
	if (plan > 11.5) {
		return noctiluca_voxel_optics(p,n,rg,anatomy,part,law.x,law.z);
	}
	if (plan > 10.5) {
		return volvox_voxel_optics(p,n,rg,anatomy,part,law.x,law.z);
	}
	if (plan > 9.5) {
		return euglena_voxel_optics(p,n,rg,anatomy,part,law.x,law.y);
	}
	if (plan > 8.5) {
		return heliozoan_voxel_optics(p,n,rg,anatomy,part,law.y,law.z);
	}
	if (plan > 7.5) {
		return spirostomum_voxel_optics(p,n,rg,anatomy,law.x,law.z);
	}
	if (plan > 6.5) {
		return euplotes_voxel_optics(p,n,rg,anatomy,part,law.x);
	}
	if (plan > 5.5) {
		return vorticella_voxel_optics(p,n,rg,anatomy,part,law.x,law.z);
	}
	if (plan > 4.5) {
		return lacrymaria_voxel_optics(p,n,rg,anatomy,part,law.x);
	}
	if (plan > 3.5) {
		return stentor_voxel_optics(p,n,rg,anatomy,law.x,law.z);
	}
	if (plan > 2.5) {
		return tardigrade_voxel_optics(p, n, rg, anatomy, part, phase);
	}
	if (plan > 1.5) {
		return crab_voxel_optics(p, n, rg, anatomy, photo.y);
	}
	if (plan > .5) {
		return listener_voxel_optics(p, n, rg, anatomy, law.x);
	}
	return grazer_voxel_optics(p, n, rg, anatomy, phase);
}
