shader_type spatial;
render_mode cull_back;

// Optical room projection: UV2 is a normalized pane chart; UV remains physical PBR.
// Opaque background panes only. Do not replace interactive or transparent glazing.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D wood_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 glass_tint : source_color = vec3(0.12, 0.16, 0.18);
uniform vec2 physical_uv_scale = vec2(1.0);
uniform vec2 pane_size = vec2(1.2, 1.8);
uniform float room_depth : hint_range(1.0, 8.0) = 3.8;
uniform float building_seed = 1.0;
uniform int room_kind : hint_range(0, 4) = 0; // walk-up, office, workshop, shop, rowhouse
uniform float minute_of_day : hint_range(0.0, 1440.0) = 1200.0;
uniform bool weekend = false;
uniform bool interiors_enabled = true;
uniform bool optical_vertex_data = false;
// A hash input must not interpolate: roundoff otherwise becomes pixel speckle.
varying flat float pane_seed;
varying flat vec2 optical_size;
varying flat vec4 room_traits;
varying flat vec4 decor_traits;
varying flat vec4 lamp_traits;
// This pane's draw for the present spell, and how much of an evening its lamp is on.
varying flat vec2 lamp_spell;
// Glazing, dressing and life: x bars and sill, y sash and grime, z dressing, w occupant.
varying flat vec4 dress_traits;
uniform vec3 joinery_colour : source_color = vec3(0.16, 0.19, 0.16);
uniform bool window_detail = true;

float hash1(float p) { return fract(sin(p * 127.1 + 311.7) * 43758.5453); }

// Slab intersection, including parallel rays without dividing by zero.
float box_hit(vec3 ro, vec3 rd, vec3 lo, vec3 hi) {
    vec3 inv = sign(rd + vec3(0.000001)) / max(abs(rd), vec3(0.00001));
    vec3 a = (lo - ro) * inv;
    vec3 b = (hi - ro) * inv;
    vec3 near_t = min(a, b);
    vec3 far_t = max(a, b);
    float enter = max(max(near_t.x, near_t.y), near_t.z);
    float leave = min(min(far_t.x, far_t.y), far_t.z);
    return leave > max(enter, 0.0) ? max(enter, 0.0) : 10000.0;
}

void furnish(vec3 ro, vec3 rd, vec3 lo, vec3 hi, vec3 color,
             inout float nearest, inout vec3 pigment) {
    float t = box_hit(ro, rd, lo, hi);
    if (t < nearest) {
        nearest = t;
        vec3 p = ro + rd * t;
        float top = step(hi.y - 0.002, p.y);
        pigment = color * mix(0.66, 1.12, top);
    }
}

void rounded_shade(vec3 ro, vec3 rd, vec3 centre, vec3 radii,
                   inout float nearest, inout vec3 pigment) {
    vec3 o=(ro-centre)/radii, d=rd/radii;
    float a=dot(d,d), b=dot(o,d), c=dot(o,o)-1.0;
    float disc=b*b-a*c;
    if(disc>0.0) {
        float t=(-b-sqrt(disc))/a;
        if(t>0.0 && t<nearest) { nearest=t; pigment=vec3(0.70,0.61,0.43); }
    }
}

void blob(vec3 ro, vec3 rd, vec3 centre, vec3 radii, vec3 color,
          inout float nearest, inout vec3 pigment) {
    vec3 o=(ro-centre)/radii, d=rd/radii;
    float a=dot(d,d), b=dot(o,d), c=dot(o,o)-1.0;
    float disc=b*b-a*c;
    if(disc>0.0) {
        float t=(-b-sqrt(disc))/a;
        if(t>0.0 && t<nearest) { nearest=t; pigment=color; }
    }
}

// Glazing bars and frame in pane units (st), with antialiasing width aa.
float bars(vec2 st, vec2 size, vec2 cells, float rail, float width_m, vec2 aa) {
    vec2 half_w = vec2(width_m) / size * 0.5;
    vec2 d = abs(fract(st * cells + 0.5) - 0.5) / cells;
    vec2 m = vec2(1.0) - smoothstep(half_w - aa, half_w + aa, d);
    float grid = max(m.x, m.y);
    float meeting = rail > 0.0
        ? 1.0 - smoothstep(half_w.y * 1.6 - aa.y, half_w.y * 1.6 + aa.y, abs(st.y - rail)) : 0.0;
    return max(grid, meeting);
}

void vertex() {
    // INSTANCE_CUSTOM.r is optional normalized identity for MultiMesh batches.
    pane_seed = building_seed + INSTANCE_CUSTOM.r * 8192.0;
    optical_size = pane_size;
    if (optical_vertex_data) {
        pane_seed = building_seed + CUSTOM0.x;
        optical_size = max(CUSTOM0.yz, vec2(0.1));
    }
    // Fixed per-pane traits are evaluated per vertex, never noisy pixel hashes.
    room_traits = vec4(hash1(pane_seed+2.0), hash1(pane_seed+5.0), hash1(pane_seed+7.0), hash1(pane_seed+9.0));
    decor_traits = vec4(hash1(pane_seed+11.0), hash1(pane_seed+17.0), hash1(pane_seed+19.0), hash1(pane_seed+23.0));
    lamp_traits = vec4(hash1(pane_seed+29.0), hash1(pane_seed+31.0), hash1(pane_seed+33.0), hash1(pane_seed+13.0));
    // Nobody keeps one lamp burning all evening. Each pane decides again every
    // so often (its own interval, its own phase) whether its lamp is on, so
    // single windows go dark and come back while the street stays lit.
    float spell = mix(14.0, 70.0, hash1(pane_seed + 37.0));
    float turn = floor((minute_of_day + hash1(pane_seed + 41.0) * spell) / spell);
    lamp_spell = vec2(hash1(pane_seed + 43.0 + turn * 1.37), mix(0.5, 0.96, hash1(pane_seed + 47.0)));
    dress_traits = vec4(hash1(pane_seed + 53.0), hash1(pane_seed + 59.0), hash1(pane_seed + 61.0), hash1(pane_seed + 67.0));
}

void fragment() {
    bool dwelling = room_kind == 0 || room_kind == 4;
    float layout = room_traits.w;
    float depth = room_depth * mix(0.75, 1.25, room_traits.z) * (room_kind == 4 ? 1.15 : 1.0);
    vec2 physical_uv = UV * physical_uv_scale;
    vec3 glaze = texture(albedo_tex, physical_uv).rgb * glass_tint;
    ROUGHNESS = clamp(texture(rough_tex, physical_uv).r * 0.65 + 0.2, 0.25, 0.9);
    NORMAL_MAP = texture(normal_tex, physical_uv).rgb;
    NORMAL_MAP_DEPTH = 0.12;
    METALLIC = 0.0;
    SPECULAR = 0.45;

    vec2 st = vec2(UV2.x, 1.0 - UV2.y);
    vec2 dx = dFdx(st), dy = dFdy(st);
    float determinant = dx.x * dy.y - dx.y * dy.x;
    vec3 tangent_u = (dFdx(VERTEX) * dy.y - dFdy(VERTEX) * dx.y)
        / (abs(determinant) > 0.00000001 ? determinant : 0.00000001);
    vec3 tangent_v = (dFdy(VERTEX) * dx.x - dFdx(VERTEX) * dy.x)
        / (abs(determinant) > 0.00000001 ? determinant : 0.00000001);
    vec3 incoming = -VIEW;
    vec3 rd = normalize(vec3(dot(incoming, normalize(tangent_u + vec3(0.000001, 0.0, 0.0))),
        dot(incoming, normalize(tangent_v + vec3(0.0, 0.000001, 0.0))), max(0.04, -dot(incoming, NORMAL))));
    vec3 ro = vec3((st - 0.5) * optical_size, 0.001);
    float w = optical_size.x * 1.25;
    float floor_y = -optical_size.y * 0.5 - 0.65;
    float ceiling_y = optical_size.y * 0.5 + 0.45;
    vec3 inv = sign(rd + vec3(0.000001)) / max(abs(rd), vec3(0.00001));
    vec3 far_t = max((vec3(-w, floor_y, 0.0) - ro) * inv,
                     (vec3(w, ceiling_y, depth) - ro) * inv);
    float nearest = min(min(far_t.x, far_t.y), far_t.z);
    vec3 p = ro + rd * nearest;
    bool floor_hit = p.y < floor_y + 0.005;
    bool back_hit = p.z > depth - 0.005;
    vec2 room_uv = floor_hit ? p.xz : (back_hit ? p.xy : p.zy);
    vec3 wall = texture(wall_albedo, room_uv * 0.4).rgb;
    vec3 wood = texture(wood_albedo, room_uv * vec2(0.35, 0.65)).rgb;
    vec3 plaster = mix(vec3(0.52, 0.60, 0.53), vec3(0.76, 0.63, 0.49), decor_traits.x);
    plaster = mix(plaster, vec3(0.56, 0.52, 0.50), layout * 0.35);
    vec3 pigment = floor_hit ? wood * 0.45 : wall * plaster;
    pigment *= mix(0.65, 1.0, clamp((p.y - floor_y) / 3.0, 0.0, 1.0));
    float room_pixels = 1.0 / max(max(length(dx), length(dy)), 0.0001);
    float detail = smoothstep(5.0, 22.0, room_pixels);
    float wall_distance = nearest;
    float side = room_traits.y > 0.5 ? 1.0 : -1.0;
    vec3 timber = vec3(0.19, 0.09, 0.045);
    vec3 fabric = mix(vec3(0.24, 0.34, 0.30), vec3(0.47, 0.28, 0.19), decor_traits.y);
    if (detail > 0.01 && interiors_enabled) {
        // At most a few large silhouettes per room; no per-room draw or lights.
        float edge = side * min(w * 0.62, 1.05);
        float table_z = mix(1.35, min(depth - 0.85, 2.2), room_traits.x);
        if (dwelling && layout < (room_kind == 4 ? 0.55 : 0.34)) {
            // Parlour settee and low table.
            float seat_x = side * 0.34;
            furnish(ro, rd, vec3(seat_x - 0.64, floor_y, depth - 1.08),
                vec3(seat_x + 0.64, floor_y + 0.46, depth - 0.4), fabric, nearest, pigment);
            furnish(ro, rd, vec3(seat_x - 0.65, floor_y + 0.43, depth - 0.6),
                vec3(seat_x + 0.65, floor_y + 0.99, depth - 0.4), fabric, nearest, pigment);
            furnish(ro, rd, vec3(-0.42, floor_y + 0.35, table_z),
                vec3(0.42, floor_y + 0.46, table_z + 0.38), timber, nearest, pigment);
        } else if (dwelling && layout < 0.73) {
            // Bedroom with a bedstead and offset chest.
            float bed_x = side * 0.36;
            furnish(ro, rd, vec3(bed_x - 0.55, floor_y + 0.22, depth - 1.52),
                vec3(bed_x + 0.55, floor_y + 0.54, depth - 0.25), fabric, nearest, pigment);
            furnish(ro, rd, vec3(bed_x - 0.58, floor_y, depth - 0.38),
                vec3(bed_x + 0.58, floor_y + 1.02, depth - 0.26), timber, nearest, pigment);
            furnish(ro, rd, vec3(-edge - 0.30, floor_y, depth - 0.62),
                vec3(-edge + 0.30, floor_y + 0.81, depth - 0.19), timber * 1.25, nearest, pigment);
        } else {
            // Kitchen table, office desk or workshop bench with an open span underneath.
            float width = min(w * 0.8, mix(0.58, 1.08, room_traits.y));
            float height = room_kind == 2 ? 0.94 : 0.76;
            furnish(ro, rd, vec3(-width, floor_y + height - 0.11, table_z),
                vec3(width, floor_y + height, table_z + 0.58), timber * 1.4, nearest, pigment);
            furnish(ro, rd, vec3(-width, floor_y, table_z + 0.08),
                vec3(-width + 0.12, floor_y + height, table_z + 0.49), timber, nearest, pigment);
            furnish(ro, rd, vec3(width - 0.12, floor_y, table_z + 0.08),
                vec3(width, floor_y + height, table_z + 0.49), timber, nearest, pigment);
            float object_height = room_kind == 2 ? 0.38 : 0.17;
            furnish(ro, rd, vec3(edge * 0.35 - 0.19, floor_y + height, table_z + 0.16),
                vec3(edge * 0.35 + 0.19, floor_y + height + object_height, table_z + 0.44),
                room_kind == 2 ? vec3(0.25, 0.24, 0.18) : vec3(0.56, 0.49, 0.35), nearest, pigment);
        }
        if (dwelling && decor_traits.w < 0.62 && layout < 0.55) {
            furnish(ro, rd, vec3(edge - 0.018, floor_y, 1.15),
                vec3(edge + 0.018, floor_y + 1.45, 1.19), timber, nearest, pigment);
            rounded_shade(ro, rd, vec3(edge, floor_y + 1.48, 1.17), vec3(0.23, 0.14, 0.23), nearest, pigment);
        } else if (room_kind == 2 || room_kind == 3 || decor_traits.w > 0.43) {
            float cabinet_x = -edge;
            float cabinet_h = mix(1.08, 1.91, room_traits.x);
            furnish(ro, rd, vec3(cabinet_x - 0.27, floor_y, depth - 0.62),
                vec3(cabinet_x + 0.27, floor_y + cabinet_h, depth - 0.18), timber, nearest, pigment);
        }
        if (window_detail) {
            float sill_y = -optical_size.y * 0.5;
            if (dwelling && dress_traits.x > 0.55) {
                // A pot plant on the inside sill.
                float px = (dress_traits.y - 0.5) * optical_size.x * 0.6;
                furnish(ro, rd, vec3(px - 0.07, sill_y, 0.06), vec3(px + 0.07, sill_y + 0.13, 0.2),
                    vec3(0.42, 0.20, 0.11), nearest, pigment);
                blob(ro, rd, vec3(px, sill_y + 0.24, 0.13), vec3(0.17, 0.14, 0.12),
                    mix(vec3(0.10, 0.20, 0.08), vec3(0.18, 0.26, 0.10), dress_traits.z), nearest, pigment);
            } else if (dwelling && dress_traits.x > 0.42) {
                // A bottle or a vase.
                float bx = (dress_traits.w - 0.5) * optical_size.x * 0.5;
                furnish(ro, rd, vec3(bx - 0.035, sill_y, 0.08), vec3(bx + 0.035, sill_y + 0.24, 0.15),
                    mix(vec3(0.30, 0.42, 0.40), vec3(0.55, 0.36, 0.22), dress_traits.z), nearest, pigment);
            }
            if (dress_traits.w > 0.62 && room_kind != 2) {
                // Someone at home, crossing the room now and then.
                float fx = sin(TIME * mix(0.05, 0.14, dress_traits.y) + pane_seed) * w * 0.55;
                float fz = mix(1.1, max(1.2, depth - 0.7), dress_traits.z);
                vec3 figure = vec3(0.05, 0.045, 0.04);
                furnish(ro, rd, vec3(fx - 0.21, floor_y, fz - 0.12), vec3(fx + 0.21, floor_y + 1.38, fz + 0.12),
                    figure, nearest, pigment);
                blob(ro, rd, vec3(fx, floor_y + 1.52, fz), vec3(0.11, 0.13, 0.11), figure, nearest, pigment);
            }
        }
    }
    if (nearest < wall_distance) {
        vec3 furniture_point = ro + rd * nearest;
        pigment *= mix(vec3(0.72), texture(wood_albedo, furniture_point.xy * vec2(0.35, 0.65)).rgb, 0.3);
    }
    float hour = minute_of_day / 60.0;
    float offset = lamp_traits.w * 1.8;
    float activity = dwelling
        ? smoothstep(16.5 + offset, 18.0 + offset, hour) * (1.0 - smoothstep(22.0 + offset, 24.0, hour))
        : smoothstep(6.0 + offset, 8.0 + offset, hour) * (1.0 - smoothstep(17.0, 19.0 + offset, hour));
    if (weekend && room_kind == 1) { activity *= 0.12; }
    // The hours set how likely a lamp is to be on; the pane's own draw decides.
    // A few dwellers sit up after the street has gone to bed.
    float late = dwelling ? 0.05 * (smoothstep(22.5, 24.0, hour) + 1.0 - smoothstep(0.0, 4.5, hour)) : 0.0;
    activity = step(lamp_spell.x, max(activity * lamp_spell.y, late));
    activity *= step(0.22, lamp_traits.z);
    float daylight = smoothstep(6.0, 9.0, hour) * (1.0 - smoothstep(16.0, 19.0, hour));
    // Bounded tungsten/lamplight palette, approximately 2300â€“3300 K; no neon hues.
    vec3 lamp_colour = mix(vec3(1.0, 0.33, 0.085), vec3(1.0, 0.56, 0.28), lamp_traits.x);
    // Some flats still burn gas: an incandescent mantle reads whiter and greener.
    if (window_detail && dwelling && dress_traits.z < 0.14) { lamp_colour = vec3(0.92, 1.0, 0.78); }
    float lamp_level = mix(0.35, 1.25, lamp_traits.y);
    // A few rooms are lit by a coal fire after dark: low, orange and never still.
    float fire = (window_detail && dwelling && dress_traits.w < 0.09) ? 1.0 - daylight : 0.0;
    float flicker = 0.82 + 0.18 * sin(TIME * 7.3 + pane_seed) * sin(TIME * 3.1 + pane_seed * 0.7);
    vec3 illumination = vec3(0.025, 0.035, 0.055) + daylight * vec3(0.15, 0.17, 0.18)
        + activity * lamp_colour * lamp_level
        + fire * vec3(1.0, 0.38, 0.10) * 0.55 * flicker;
    float curtain_width = mix(0.025, dwelling ? 0.38 : 0.18, decor_traits.z);
    float curtain_edge = min(st.x + 0.06 * side, 1.0 - st.x - 0.06 * side);
    float curtain = 1.0 - smoothstep(curtain_width - 0.015, curtain_width + 0.015, curtain_edge);
    float roller = step(0.72, decor_traits.w) * (1.0-smoothstep(mix(0.35,0.75,decor_traits.z)-0.01, mix(0.35,0.75,decor_traits.z)+0.01, UV2.y));
    vec3 interior = mix(pigment, wall * mix(0.48,0.78,decor_traits.x), max(curtain,roller) * detail);
    vec3 light_in = illumination;
    if (window_detail && interiors_enabled) {
        vec2 m = st * optical_size;  // metres across the pane
        if (dwelling && decor_traits.z > 0.55) {
            // Lace nets: a fine mesh with a repeating flower, pale by day, amber when lit.
            vec2 cell = fract(m * 7.0) - 0.5;
            float mesh = smoothstep(0.38, 0.5, max(abs(cell.x), abs(cell.y)));
            vec2 motif = fract(m * vec2(1.6, 1.25)) - 0.5;
            float flower = (1.0 - smoothstep(0.20, 0.24, length(motif)))
                * (0.6 + 0.4 * sin(atan(motif.y, motif.x) * 6.0));
            float lace = clamp(mesh * 0.55 + flower * 0.8, 0.0, 1.0) * detail;
            float cover = 0.55 + 0.25 * lace;
            interior = mix(interior, vec3(0.86, 0.84, 0.78), cover * 0.85);
            light_in = illumination * (1.0 - cover * 0.35 + lace * 0.25);
        } else if (room_kind == 3 && decor_traits.z > 0.4) {
            // A cafe curtain on a rod across the lower part of a shop window.
            float rod = 0.42 + 0.08 * decor_traits.y;
            float cafe = 1.0 - smoothstep(rod - 0.004, rod + 0.004, st.y);
            float pleat = 0.85 + 0.15 * sin(m.x * 38.0);
            vec3 cloth = mix(vec3(0.62, 0.55, 0.42), vec3(0.32, 0.42, 0.34), decor_traits.x);
            interior = mix(interior, cloth * pleat, cafe * detail);
        } else if (room_kind == 1 && dress_traits.z < 0.65) {
            // An office Venetian blind let down to its own height, slats at their own tilt.
            float down = mix(0.35, 0.95, dress_traits.y);
            float covered = step(1.0 - down, st.y);
            float slat = smoothstep(0.0, 0.08, abs(fract(m.y * 18.0) - 0.5) - mix(0.05, 0.42, dress_traits.w));
            interior = mix(interior, vec3(0.78, 0.74, 0.62) * (0.75 + 0.25 * slat),
                covered * (1.0 - slat * 0.6) * detail);
        }
    }
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
    float pane_valid = step(0.0, UV2.y) * step(UV2.y, 1.0);
    vec3 glass_colour = glaze;
    float glass_strength = 1.0;
    float frame_mask = 0.0;
    if (window_detail) {
        // Glazing bars by type: six-over-six or two-over-two sashes in dwellings,
        // a meeting rail in offices, a steel grid in workshops, a transom in shops.
        vec2 cells = dwelling ? (dress_traits.x < 0.5 ? vec2(3.0, 4.0) : vec2(1.0, 2.0))
            : (room_kind == 2 ? vec2(4.0, 6.0) : vec2(1.0));
        float rail = room_kind == 1 ? 0.5 : (room_kind == 3 ? 0.82 : 0.0);
        vec2 aa = fwidth(st) * 0.75 + vec2(0.0005);
        frame_mask = bars(st, optical_size, cells, rail, room_kind == 2 ? 0.035 : 0.03, aa) * pane_valid;
        // Now and then a lower sash is pushed up for air: the room shows without glass.
        if ((dwelling || room_kind == 1) && dress_traits.y < 0.11 && st.y < 0.5) {
            glass_strength = 0.0;
        }
        // City grime gathers at the edges of the glass.
        vec2 e = min(st, 1.0 - st);
        float grime = (1.0 - smoothstep(0.0, 0.18, min(e.x, e.y))) * mix(0.15, 0.55, dress_traits.y) * glass_strength;
        glass_colour = mix(glaze, glaze * vec3(0.72, 0.66, 0.55), grime);
        light_in *= 1.0 - grime * 0.35;
    }
    ALBEDO = mix(mix(vec3(0.02), glass_colour, glass_strength), joinery_colour, frame_mask);
    ROUGHNESS = mix(mix(0.9, ROUGHNESS, glass_strength), 0.62, frame_mask);
    SPECULAR = mix(SPECULAR * glass_strength, 0.3, frame_mask);
    float glass_mute = mix(1.0, 1.0 - fresnel * 0.85, glass_strength);
    EMISSION = interiors_enabled
        ? interior * light_in * glass_mute * (1.0 - frame_mask) * pane_valid : vec3(0.0);
}
