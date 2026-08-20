// R2: meter-scaled architectural infection and real relief masks.
//
// This include is deliberately colourless.  It describes where the Orison's
// construction invites the organism in, and how far tesserae / medallions
// stand proud of the photographed substrate.  dream_klimt.gdshader remains
// the sole owner of colour, exposure and the final material response.

#ifndef DREAM_ARCHITECTURE_RELIEF
#define DREAM_ARCHITECTURE_RELIEF

#define DREAM_ARCH_NONE 0
#define DREAM_ARCH_WALL 1
#define DREAM_ARCH_FLOOR 2
#define DREAM_ARCH_CEILING 3
#define DREAM_ARCH_MILLWORK 4
#define DREAM_ARCH_PANEL 5
#define DREAM_ARCH_DOOR 6
#define DREAM_ARCH_SHAFT 7

float dream_relief_hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float dream_relief_line(float distance_m, float width_m) {
	return 1.0 - smoothstep(0.0, max(0.001, width_m), distance_m);
}


// The corruption favours joints which exist in the real building.  This is a
// bias on the one durable exposure field, never another growth simulation.
float dream_architecture_anchor(vec3 world_pos, vec3 world_normal,
		vec4 bounds_xz, float clear_ceiling, int surface_kind) {
	float dx = min(abs(world_pos.x - bounds_xz.x),
			abs(bounds_xz.z - world_pos.x));
	float dz = min(abs(world_pos.z - bounds_xz.y),
			abs(bounds_xz.w - world_pos.z));
	float room_edge = min(dx, dz);
	float floor_joint = dream_relief_line(abs(world_pos.y), 0.24);
	float ceiling_joint = dream_relief_line(
			abs(world_pos.y - clear_ceiling), 0.26);
	float anchor = 0.0;

	if (surface_kind == DREAM_ARCH_WALL) {
		// Endpoint means a real room corner on the wall's dominant axis.
		float endpoint = abs(world_normal.x) > abs(world_normal.z) ? dz : dx;
		float historic_levels = max(
				dream_relief_line(abs(world_pos.y - 0.14), 0.085),
				dream_relief_line(abs(world_pos.y - 1.32), 0.105));
		historic_levels = max(historic_levels,
				dream_relief_line(abs(world_pos.y - 2.18), 0.095));
		historic_levels = max(historic_levels,
				dream_relief_line(abs(world_pos.y
				- (clear_ceiling - 0.13)), 0.12));
		anchor = max(dream_relief_line(endpoint, 0.34), historic_levels);
		anchor = max(anchor, max(floor_joint, ceiling_joint));
	} else if (surface_kind == DREAM_ARCH_FLOOR) {
		anchor = dream_relief_line(room_edge, 0.46);
	} else if (surface_kind == DREAM_ARCH_CEILING) {
		vec2 centre = (bounds_xz.xy + bounds_xz.zw) * 0.5;
		float room_radius = min(bounds_xz.z - bounds_xz.x,
				bounds_xz.w - bounds_xz.y);
		float rose_radius = clamp(room_radius * 0.17, 0.19, 0.42);
		float rose = dream_relief_line(abs(distance(world_pos.xz, centre)
				- rose_radius * 0.82), 0.13);
		anchor = max(dream_relief_line(room_edge, 0.38), rose);
	} else if (surface_kind == DREAM_ARCH_MILLWORK) {
		anchor = 0.92;
	} else if (surface_kind == DREAM_ARCH_PANEL) {
		anchor = 0.68;
	} else if (surface_kind == DREAM_ARCH_DOOR) {
		anchor = 0.84;
	} else if (surface_kind == DREAM_ARCH_SHAFT) {
		anchor = 1.0;
	}
	return clamp(anchor, 0.0, 1.0);
}


// One hand-set tessera every 82 mm.  The face is slightly irregular, while
// the zero-valued border is honest recessed grout rather than a painted line.
float dream_tessera_face(vec2 metres) {
	const float TILE_M = 0.082;
	vec2 cell = floor(metres / TILE_M);
	vec2 local = fract(metres / TILE_M);
	float jitter = dream_relief_hash21(cell) * 0.012;
	// 3.3-4.3 mm to an edge: a narrow 7-9 mm joint between imperfect
	// 82 mm pieces, not the black graph-paper lattice of the rejected pass.
	float border = 0.040 + jitter;
	float face = smoothstep(border, border + 0.028, local.x)
			* smoothstep(border, border + 0.028, local.y)
			* (1.0 - smoothstep(1.0 - border - 0.028,
			1.0 - border, local.x))
			* (1.0 - smoothstep(1.0 - border - 0.028,
			1.0 - border, local.y));
	return face;
}


float dream_tessera_height(vec2 metres) {
	vec2 cell = floor(metres / 0.082);
	float set = 0.72 + dream_relief_hash21(cell + 17.3) * 0.28;
	return dream_tessera_face(metres) * set;
}


// Large, deterministic concentric bosses.  They repeat slowly enough that a
// room reads one or two principal discs rather than wallpaper.
float dream_medallion_height(vec2 metres) {
	const float CELL_M = 2.80;
	vec2 cell = floor(metres / CELL_M);
	vec2 local = (fract(metres / CELL_M) - 0.5) * CELL_M;
	float seed = dream_relief_hash21(cell + 31.7);
	local -= (vec2(seed, dream_relief_hash21(cell - 8.1)) - 0.5) * 0.24;
	float radius = length(local);
	float disc_radius = 0.82 + seed * 0.16;
	float disc = 1.0 - smoothstep(disc_radius - 0.025,
			disc_radius + 0.025, radius);
	float rings = 0.5 + 0.5 * cos(radius * 38.0 + seed * 6.28318530718);
	float ring_relief = smoothstep(0.42, 0.88, rings);
	float boss = 1.0 - smoothstep(0.0, disc_radius, radius);
	return disc * (0.30 + ring_relief * 0.46 + boss * 0.34);
}


float dream_medallion_edge(vec2 metres) {
	const float CELL_M = 2.80;
	vec2 cell = floor(metres / CELL_M);
	vec2 local = (fract(metres / CELL_M) - 0.5) * CELL_M;
	float seed = dream_relief_hash21(cell + 31.7);
	local -= (vec2(seed, dream_relief_hash21(cell - 8.1)) - 0.5) * 0.24;
	float radius = length(local);
	float disc_radius = 0.82 + seed * 0.16;
	return dream_relief_line(abs(radius - disc_radius), 0.035);
}


float dream_leaf_crack(vec2 metres) {
	vec2 cell = floor(metres * 7.3);
	vec2 local = fract(metres * 7.3);
	float seed = dream_relief_hash21(cell);
	float diagonal = abs(local.y - fract(local.x * (0.55 + seed * 1.15)
			+ seed));
	float branch = abs(local.x - fract(local.y * (0.80 + seed) + seed * 0.7));
	return max(dream_relief_line(diagonal, 0.026),
			dream_relief_line(branch, 0.018))
			* step(0.34, dream_relief_hash21(cell + 91.0));
}


float dream_architecture_height(vec2 metres, float stage_one,
		float stage_two, float tessera_relief_m,
		float medallion_relief_m) {
	return dream_tessera_height(metres) * stage_one * tessera_relief_m
			+ dream_medallion_height(metres) * stage_two
			* medallion_relief_m;
}

#endif
