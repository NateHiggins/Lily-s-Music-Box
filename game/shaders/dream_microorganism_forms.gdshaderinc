// Source-derived forms for DREAM-CRITTER-VOXEL-V3. These functions rearrange
// the controller's existing bounded primitive pool. They allocate nothing and
// make no ecological decisions.

vec3 micro_ring(vec3 tangent, vec3 ring_n, float radius) {
	vec3 t = normalize(tangent + vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(t.y) < .9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 side = normalize(cross(any, t));
	vec3 binormal = cross(t, side);
	float a = atan(ring_n.y, ring_n.x);
	return (side * cos(a) + binormal * sin(a)) * radius;
}

// xyz is the final local position; w is optical thickness. Plans 4..15 are
// deliberately unrelated silhouettes rather than scaled versions of a tower.
vec4 microorganism_body(float plan, vec3 q, vec3 size, float seed, vec4 law) {
	vec3 p = q;
	float thick = .7;
	if (plan < 4.5) { // Stentor: trumpet, holdfast and oral flare.
		float axis = q.y * .5 + .5;
		float flare = mix(.20, 1.0, pow(axis, 1.25));
		float contract = clamp(law.z, 0.0, 1.0);
		p.xz *= flare * mix(1.0, 1.28, contract);
		p.y = mix(q.y, q.y * .32 - .56, contract);
		p.x += sin(axis * 16.0 + seed) * .035;
		p *= vec3(size.y * .50, size.z * .50, size.y * .50);
		thick = mix(.82, .96, contract);
	} else if (plan < 5.5) { // Lacrymaria: anchored contractile teardrop.
		float z = q.z * .5 + .5;
		p.xy *= mix(1.05, .42, smoothstep(.15, 1.0, z));
		p.z -= .16;
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .86;
	} else if (plan < 6.5) { // Vorticella: open bell above a narrow throat.
		float y = q.y * .5 + .5;
		float bell = .22 + .78 * smoothstep(.12, .92, y);
		p.xz *= bell;
		p.y = q.y * .62 + .20 - law.z * .72;
		p *= vec3(size.y * .50, size.z * .50, size.x * .42);
		thick = .58;
	} else if (plan < 7.5) { // Euplotes: asymmetric dorsal shield.
		p.y *= .32;
		p.x *= mix(.72, 1.08, smoothstep(-.8, .55, q.z));
		p.x += .11 * (1.0 - q.z * q.z) + .035 * sin(q.z * 9.0 + seed);
		p.z -= .08;
		p *= vec3(size.y * .54, size.z * .52, size.x * .52);
		thick = .42;
	} else if (plan < 8.5) { // Spirostomum: twisting contractile spindle.
		float wave = smoothstep(-.75, .85, q.z + law.z * 1.7);
		float contract = law.z * wave;
		float a = contract * 2.2 + q.z * .18;
		p.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p.xy;
		p.z *= mix(1.0, .31, contract);
		p.xy *= mix(1.0, 1.48, contract) * (.84 + .16 * cos(q.z * 3.14159));
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .88;
	} else if (plan < 9.5) { // Heliozoan: vacuolate spherical cortex.
		p *= 1.0 + .035 * sin(q.x * 7.0 + q.y * 9.0 + q.z * 11.0 + seed);
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .74;
	} else if (plan < 10.5) { // Euglena: fusiform pellicle in metaboly.
		float z = q.z;
		float twist = law.x + z * 2.3;
		float deform = .11 * sin(law.x * 1.7 + z * 6.0);
		p.xy = mat2(vec2(cos(twist), sin(twist)), vec2(-sin(twist), cos(twist))) * p.xy;
		p.xy *= (.72 + .28 * cos(z * 1.5708)) * (1.0 + deform);
		p.x += deform * (1.0 - z * z);
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .70;
	} else if (plan < 11.5) { // Volvox: one subtly faceted cellular spheroid.
		float lattice = sin(atan(q.x, q.z) * 12.0 + seed) * sin(q.y * 15.0);
		p *= 1.0 + .022 * lattice;
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .32;
	} else if (plan < 12.5) { // Noctiluca: giant vacuolate pear.
		float y = q.y * .5 + .5;
		p.xz *= mix(.82, 1.08, smoothstep(.0, .62, y));
		p.x += .07 * (1.0 - q.y * q.y);
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .28;
	} else if (plan < 13.5) { // Bacillaria: central silica frustule of a raft.
		p *= vec3(size.y * .14, size.z * .38, size.x * .52);
		p.x += .04 * size.y;
		thick = .26;
	} else if (plan < 14.5) { // Salpingoeca: shared central ECM, cells are details.
		p *= vec3(size.y * .16, size.z * .16, size.x * .16);
		p *= .88 + .12 * sin((q.x + q.y + q.z) * 8.0 + law.x);
		thick = .64;
	} else { // Mesodinium: bilobed body and tight equatorial waist.
		float waist = .64 + .36 * smoothstep(.10, .82, abs(q.y));
		p.xz *= waist;
		p.y += sign(q.y) * .07;
		p *= vec3(size.y * .50, size.z * .50, size.x * .50);
		thick = .80;
	}
	return vec4(p, thick);
}

// Part 1: stalk/cirral mechanics. A negative w collapses the unused tube.
vec4 microorganism_limb(float plan, float index, float along, vec3 ring_n,
		vec3 size, float seed, vec4 law) {
	if (plan > 5.5 && plan < 6.5 && index < .5) { // Vorticella stalk.
		float coil = smoothstep(.05, .9, law.z);
		float turns = mix(.18, 3.7, coil) * 6.2831853;
		float radius = size.y * .095 * coil * sin(along * 3.14159);
		vec3 p = vec3(cos(turns * along + seed) * radius,
				-size.z * .48 + along * size.z * mix(.68, .20, coil),
				sin(turns * along + seed) * radius);
		vec3 tangent = vec3(-sin(turns * along + seed) * radius * turns,
				size.z * mix(.68, .20, coil), cos(turns * along + seed) * radius * turns);
		return vec4(p + micro_ring(tangent, ring_n, size.y * .018), .48);
	}
	if (plan > 6.5 && plan < 7.5 && index < 8.0) { // Euplotes cirral bundles.
		float flank = index < 4.0 ? -1.0 : 1.0;
		float row = mod(index, 4.0) / 3.0;
		float gait = mod(floor(law.x) + index, 4.0);
		float lift = step(2.5, gait) * sin(along * 3.14159);
		vec3 root = vec3(flank * size.y * .31, -size.z * .22,
				mix(size.x * .38, -size.x * .38, row));
		vec3 tip = root + vec3(flank * size.y * (.34 - .10 * row),
				-size.z * (.30 - lift * .34), size.x * (.12 - .24 * lift));
		vec3 p = mix(root, tip, along);
		p.y += lift * size.z * .42 * sin(along * 3.14159);
		return vec4(p + micro_ring(tip - root, ring_n,
				size.y * mix(.026, .010, along)), .35);
	}
	return vec4(0.0, 0.0, 0.0, -1.0);
}

// Part 2: necks, flagella, oral wreaths, axopodia and ciliary girdles.
vec4 microorganism_feeler(float plan, float index, float along, vec3 ring_n,
		vec3 size, float seed, vec4 law) {
	float count = 12.0;
	float t = (index + .5) / count;
	float a = t * 6.2831853 + seed;
	if (plan < 4.5) { // Stentor oral membranelles.
		vec3 root = vec3(cos(a) * size.y * .43, size.z * .47, sin(a) * size.y * .43);
		vec3 dir = normalize(vec3(cos(a) * .7, .46, sin(a) * .7));
		vec3 p = root + dir * along * size.y * .24;
		p += vec3(-sin(a), 0.0, cos(a)) * sin(along * 3.14159) * size.y * .07;
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.014, .004, along)), .16);
	}
	if (plan < 5.5) { // Lacrymaria: one helical telescoping neck.
		if (index > .5) return vec4(0.0, 0.0, 0.0, -1.0);
		float reach = size.x * mix(1.2, 6.4, clamp(law.z, 0.0, 1.0));
		float bend = law.y;
		vec3 dir = normalize(vec3(bend * .34, .12 + sin(law.x * .37) * .18, 1.0));
		vec3 root = vec3(0.0, size.z * .03, size.x * .37);
		vec3 p = root + dir * reach * along;
		p += vec3(cos(law.x + along * 17.0), sin(law.x * .73 + along * 13.0), 0.0)
				* size.y * .12 * sin(along * 3.14159);
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.055, .026, along)), .46);
	}
	if (plan < 6.5) { // Vorticella peristomial wreath.
		vec3 root = vec3(cos(a) * size.y * .43, size.z * (.48 - law.z * .72),
				sin(a) * size.x * .34);
		vec3 dir = normalize(vec3(cos(a) * .45, .62, sin(a) * .45));
		return vec4(root + dir * along * size.y * .18
				+ micro_ring(dir, ring_n, size.y * mix(.011, .003, along)), .12);
	}
	if (plan < 7.5) { // Euplotes oral field.
		if (index > 4.5) return vec4(0.0, 0.0, 0.0, -1.0);
		float spread = (index - 2.0) * .15;
		vec3 root = vec3(spread * size.y, -size.z * .12, size.x * .36);
		vec3 dir = normalize(vec3(spread, .35, .9));
		return vec4(root + dir * along * size.y * .22
				+ micro_ring(dir, ring_n, size.y * mix(.012, .003, along)), .13);
	}
	if (plan < 8.5) { // Spirostomum longitudinal ciliary rows.
		float az = a;
		vec3 root = vec3(cos(az) * size.y * .42, sin(az) * size.z * .42, -size.x * .44);
		vec3 tip = vec3(cos(az + law.z * 1.4) * size.y * .42,
				sin(az + law.z * 1.4) * size.z * .42, size.x * mix(.44, .12, law.z));
		vec3 p = mix(root, tip, along);
		p += normalize(vec3(cos(az), sin(az), .1)) * size.y * .08
				* sin(along * 18.0 + law.x);
		return vec4(p + micro_ring(tip - root, ring_n, size.y * .008), .10);
	}
	if (plan < 9.5) { // Heliozoan primary axopodia.
		float y = 1.0 - 2.0 * (index + .5) / 12.0;
		float radial = sqrt(max(0.0, 1.0 - y * y));
		vec3 dir = normalize(vec3(cos(a * 1.618) * radial, y, sin(a * 1.618) * radial));
		float chosen = 1.0 - step(.055, abs(index / 11.0 - law.y));
		float retract = chosen * law.z;
		float reach = size.x * mix(1.25, .48, retract);
		vec3 root = dir * vec3(size.y, size.z, size.x) * .43;
		vec3 p = root + dir * reach * along;
		p += vec3(dir.z, 0.0, -dir.x) * sin(along * 3.14159) * size.y * .09;
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.010, .003, along)), .18);
	}
	if (plan < 10.5) { // Euglena flagellum.
		if (index > .5) return vec4(0.0, 0.0, 0.0, -1.0);
		vec3 root = vec3(0.0, size.z * .04, size.x * .46);
		vec3 dir = normalize(vec3(.16, .13, 1.0));
		vec3 p = root + dir * along * size.x * 1.35;
		p += vec3(cos(along * 15.0 + law.x), sin(along * 15.0 + law.x), 0.0)
				* size.y * .13 * along;
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.020, .004, along)), .15);
	}
	if (plan < 11.5) { // Volvox outward somatic flagella.
		float y = 1.0 - 2.0 * (index + .5) / 12.0;
		float radial = sqrt(max(0.0, 1.0 - y * y));
		vec3 dir = normalize(vec3(cos(a * 1.37) * radial, y, sin(a * 1.37) * radial));
		vec3 root = dir * vec3(size.y, size.z, size.x) * .48;
		return vec4(root + dir * along * size.y * .20
				+ micro_ring(dir, ring_n, size.y * mix(.009, .002, along)), .10);
	}
	if (plan < 12.5) { // Noctiluca capture tentacle.
		if (index > 1.5) return vec4(0.0, 0.0, 0.0, -1.0);
		float flank = index < .5 ? 1.0 : -1.0;
		vec3 root = vec3(flank * size.y * .25, -size.z * .16, size.x * .34);
		vec3 dir = normalize(vec3(flank * .52, -.22, 1.0));
		vec3 p = root + dir * along * size.x * (.72 + .18 * flank);
		p.x += flank * sin(along * 5.7 + law.x) * size.y * .18 * along;
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.035, .009, along)), .42);
	}
	if (plan < 13.5) return vec4(0.0, 0.0, 0.0, -1.0);
	if (plan < 14.5) { // Salpingoeca outward flagella.
		float y = 1.0 - 2.0 * (index + .5) / 12.0;
		float radial = sqrt(max(0.0, 1.0 - y * y));
		vec3 dir = normalize(vec3(cos(a * 1.41) * radial, y, sin(a * 1.41) * radial));
		vec3 root = dir * vec3(size.y, size.z, size.x) * .34;
		vec3 p = root + dir * along * size.x * .42;
		p += vec3(dir.z, 0.0, -dir.x) * sin(along * 11.0 + law.x) * size.y * .04;
		return vec4(p + micro_ring(dir, ring_n, size.y * mix(.010, .002, along)), .11);
	}
	// Mesodinium's two equatorial ciliary girdles.
	float tier = mod(index, 2.0) < 1.0 ? -.12 : .12;
	vec3 root = vec3(cos(a) * size.y * .43, tier * size.z, sin(a) * size.x * .40);
	vec3 dir = normalize(vec3(cos(a) * .82, tier * .8, sin(a) * .82));
	return vec4(root + dir * along * size.y * .25
			+ micro_ring(dir, ring_n, size.y * mix(.014, .003, along)), .13);
}

// Existing detail spheres/tubes become internal anatomy, colony members or
// structural fibers. Parts that a plan does not own collapse at the origin.
vec4 microorganism_detail(float plan, float part, float index, float along,
		vec3 q, vec3 ring_n, vec3 size, float seed, vec4 law) {
	float ordinal = part - 3.0;
	bool tube = (part > 9.5 && part < 10.5) || (part > 12.5);
	if (plan < 4.5) { // Stentor macronucleus and cortical myonemes.
		if (!tube && part < 7.5) {
			float y = mix(-.20, .25, ordinal / 4.0);
			vec3 p = q * vec3(size.y * .13, size.z * .10, size.x * .15)
					+ vec3(sin(ordinal * 2.2) * size.y * .09, y * size.z, 0.0);
			return vec4(p, .75);
		}
		if (part > 12.5 && part < 13.5) {
			float a = (index + .5) / 8.0 * 6.2831853;
			vec3 root = vec3(cos(a) * size.y * .08, -size.z * .42, sin(a) * size.y * .08);
			vec3 tip = vec3(cos(a) * size.y * .38, size.z * .42, sin(a) * size.y * .38);
			return vec4(mix(root, tip, along) + micro_ring(tip-root, ring_n, size.y*.009), .22);
		}
	} else if (plan < 5.5) { // Lacrymaria head plus internal nucleus.
		if (!tube && part < 3.5) {
			float reach = size.x * mix(1.2, 6.4, law.z);
			vec3 dir = normalize(vec3(law.y * .34, .12 + sin(law.x * .37) * .18, 1.0));
			vec3 tip = vec3(0.0, size.z*.03, size.x*.37) + dir * reach;
			return vec4(q * vec3(size.y*.15, size.z*.13, size.y*.19) + tip, .78);
		}
		if (!tube && part < 5.5) {
			return vec4(q * vec3(size.y*.15,size.z*.13,size.x*.16)
					+ vec3(0.0,0.0,-size.x*.08), .82);
		}
	} else if (plan < 6.5) { // Vorticella nucleus and food vacuoles.
		if (!tube && part < 8.5) {
			float a = ordinal * 2.31 + seed;
			vec3 p = vec3(cos(a)*size.y*.13, size.z*(.23 + .045*sin(a)) - law.z*size.z*.72,
					sin(a)*size.x*.14);
			return vec4(q * vec3(size.y*.065,size.z*.055,size.x*.065) + p, .72);
		}
	} else if (plan < 7.5) { // Euplotes dorsal plates and dual nuclei.
		if (!tube && part < 9.5) {
			float row = ordinal / 6.0;
			vec3 p = vec3((mod(ordinal,2.0)-.5)*size.y*.34, size.z*.12,
					mix(size.x*.32,-size.x*.31,row));
			vec3 scale = part < 5.5 ? vec3(size.y*.18,size.z*.09,size.x*.20)
					: vec3(size.y*.11,size.z*.07,size.x*.11);
			return vec4(q * scale + p, part < 5.5 ? .34 : .72);
		}
		if (part > 13.5) { // paired tips make fourteen cirral branches legible.
			float leg = floor(index*.5);
			float branch = mod(index,2.0)<.5 ? -1.0 : 1.0;
			float flank = leg<4.0 ? -1.0 : 1.0;
			float row = mod(leg,4.0)/3.0;
			vec3 root=vec3(flank*size.y*.46,-size.z*.31,mix(size.x*.38,-size.x*.38,row));
			vec3 tip=root+vec3(branch*size.y*.10,-size.z*.13,size.x*.08);
			return vec4(mix(root,tip,along)+micro_ring(tip-root,ring_n,size.y*.008),.18);
		}
	} else if (plan < 8.5) { // Spirostomum entangled RER/vacuoles and fishnet.
		if (!tube && part < 9.5) {
			float z = mix(-.36,.36,ordinal/6.0)*size.x;
			vec3 p=vec3(sin(ordinal*2.4)*size.y*.15,cos(ordinal*1.7)*size.z*.13,z);
			return vec4(q*vec3(size.y*.13,size.z*.12,size.x*.11)+p,.80);
		}
		if (part > 12.5) {
			float a=(index+.5)/8.0*6.2831853;
			vec3 root=vec3(cos(a)*size.y*.37,sin(a)*size.z*.37,-size.x*.44);
			vec3 tip=vec3(cos(a+law.z*1.4)*size.y*.37,sin(a+law.z*1.4)*size.z*.37,
					size.x*mix(.44,.12,law.z));
			return vec4(mix(root,tip,along)+micro_ring(tip-root,ring_n,size.y*.007),.17);
		}
	} else if (plan < 9.5) { // Heliozoan vacuoles and secondary axopodia.
		if (!tube && part < 9.5) {
			float a=ordinal*2.4+seed;
			vec3 p=vec3(cos(a),sin(a*.71),sin(a))*vec3(size.y,size.z,size.x)*.22;
			return vec4(q*vec3(size.y*.12,size.z*.12,size.x*.12)+p,.34);
		}
		if (part > 13.5) {
			float y=1.0-2.0*(index+.5)/16.0;
			float r=sqrt(max(0.0,1.0-y*y));
			float a=index*2.39996+seed;
			vec3 dir=normalize(vec3(cos(a)*r,y,sin(a)*r));
			vec3 root=dir*vec3(size.y,size.z,size.x)*.42;
			return vec4(root+dir*along*size.x*.92+micro_ring(dir,ring_n,size.y*.006),.12);
		}
	} else if (plan < 10.5) { // Euglena chloroplast helices, nucleus and eyespot.
		if (!tube && part < 9.5) {
			float z=mix(-.30,.31,ordinal/6.0)*size.x;
			float a=ordinal*2.2+law.x;
			vec3 p=vec3(cos(a)*size.y*.19,sin(a)*size.z*.18,z);
			vec3 scale=part>7.5 ? vec3(size.y*.09,size.z*.09,size.x*.07)
					: vec3(size.y*.15,size.z*.10,size.x*.16);
			return vec4(q*scale+p,part>7.5?.32:.66);
		}
		if (part > 12.5 && part < 13.5) {
			float a=index/8.0*6.2831853+along*5.8+law.x;
			vec3 p=vec3(cos(a)*size.y*.37,sin(a)*size.z*.37,mix(-size.x*.40,size.x*.40,along));
			return vec4(p+micro_ring(vec3(-sin(a),cos(a),.3),ring_n,size.y*.007),.14);
		}
	} else if (plan < 11.5) { // Volvox daughter colonies and bridges.
		if (!tube && part < 9.5) {
			float a=ordinal*2.39996+seed;
			float surface_daughter=1.0-step(2.5,ordinal);
			float daughter_radius=mix(.19,.37,surface_daughter);
			vec3 p=vec3(cos(a)*daughter_radius,sin(a*.63)*daughter_radius*.82,
					sin(a)*daughter_radius)*vec3(size.y,size.z,size.x);
			float invert=mix(.09,.14,law.z)+surface_daughter*.035;
			return vec4(q*vec3(size.y,size.z,size.x)*invert+p,.26);
		}
		if (part > 12.5 && part < 13.5) {
			float a=index/8.0*6.2831853+seed;
			vec3 tip=normalize(vec3(cos(a),sin(a*.71),sin(a)))*vec3(size.y,size.z,size.x)*.39;
			return vec4(mix(vec3(0.0),tip,along)+micro_ring(tip,ring_n,size.y*.006),.12);
		}
	} else if (plan < 12.5) { // Noctiluca nucleus, vacuolar islands and cords.
		if (!tube && part < 9.5) {
			float a=ordinal*2.1+seed;
			vec3 p=vec3(cos(a)*size.y*.25,sin(a*.7)*size.z*.21,sin(a)*size.x*.25);
			vec3 scale=part<4.5?vec3(size.y*.15,size.z*.13,size.x*.14)
					:vec3(size.y*.075,size.z*.065,size.x*.075);
			return vec4(q*scale+p,part<4.5?.88:.22);
		}
		if (part > 12.5) {
			float a=index/8.0*6.2831853+law.x;
			vec3 tip=vec3(cos(a)*size.y*.39,sin(a*.73)*size.z*.38,sin(a)*size.x*.39);
			return vec4(mix(vec3(size.y*.07,-size.z*.04,0.0),tip,along)
					+micro_ring(tip,ring_n,size.y*.007),.10);
		}
	} else if (plan < 13.5) { // Bacillaria sliding frustule raft.
		if (!tube) {
			float cell=ordinal;
			float lane=cell-4.0;
			float slide=sin(law.x+cell*.72)*size.x*.34;
			vec3 p=vec3(lane*size.y*.105,0.0,slide);
			return vec4(q*vec3(size.y*.075,size.z*.34,size.x*.48)+p,.22);
		}
		if (part>9.5&&part<10.5) {
			float flank=index<.5?-1.0:1.0;
			vec3 root=vec3(flank*size.y*.025,size.z*.34,-size.x*.45);
			vec3 tip=vec3(flank*size.y*.025,size.z*.34,size.x*.45);
			return vec4(mix(root,tip,along)+micro_ring(tip-root,ring_n,size.y*.006),.12);
		}
	} else if (plan < 14.5) { // Salpingoeca cell rosette and ECM bridges.
		if (!tube) {
			float a=ordinal*2.39996+seed;
			vec3 dir=normalize(vec3(cos(a),sin(a*.71),sin(a)));
			vec3 p=dir*vec3(size.y,size.z,size.x)*.32;
			return vec4(q*vec3(size.y*.10,size.z*.10,size.x*.12)+p,.70);
		}
		if (part>12.5&&part<13.5) {
			float a=index/8.0*6.2831853+seed;
			vec3 tip=normalize(vec3(cos(a),sin(a*.71),sin(a)))*vec3(size.y,size.z,size.x)*.28;
			return vec4(mix(vec3(0.0),tip,along)+micro_ring(tip,ring_n,size.y*.006),.16);
		}
	} else { // Mesodinium host nuclei, kleptokaryon and plastid packets.
		if (!tube) {
			float a=ordinal*2.39996+law.x*.22;
			vec3 p=vec3(cos(a)*size.y*.24,sin(a*.83)*size.z*.22,sin(a)*size.x*.24);
			vec3 scale=part<4.5?vec3(size.y*.18,size.z*.15,size.x*.16)
					:vec3(size.y*.10,size.z*.075,size.x*.12);
			return vec4(q*scale+p,part<4.5?.92:.68);
		}
		if (part>12.5&&part<13.5) {
			float a=index/8.0*6.2831853;
			vec3 root=vec3(cos(a)*size.y*.16,0.0,sin(a)*size.x*.16);
			vec3 tip=vec3(cos(a)*size.y*.38,0.0,sin(a)*size.x*.38);
			return vec4(mix(root,tip,along)+micro_ring(tip-root,ring_n,size.y*.006),.12);
		}
	}
	return vec4(0.0, 0.0, 0.0, -1.0);
}
