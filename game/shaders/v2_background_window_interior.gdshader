shader_type spatial;
render_mode cull_back;

// Optical room projection: UV2 is a normalized pane chart; UV remains physical PBR.
// Opaque background panes only. Do not replace interactive or transparent glazing.
uniform sampler2D glass_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D glass_roughness : filter_linear_mipmap_anisotropic;
uniform sampler2D glass_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D wood_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 glass_tint : source_color = vec3(0.12, 0.16, 0.18);
uniform vec2 physical_uv_scale = vec2(1.0);
uniform vec2 pane_size = vec2(1.2, 1.8);
uniform float room_depth : hint_range(1.0, 8.0) = 3.8;
uniform float building_seed = 1.0;
uniform int room_kind : hint_range(0, 3) = 0; // dwelling, office, workshop, shop
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
}

void fragment() {
    float depth = room_depth * mix(0.75, 1.25, room_traits.z);
    vec2 physical_uv = UV * physical_uv_scale;
    vec3 glaze = texture(glass_albedo, physical_uv).rgb * glass_tint;
    ROUGHNESS = clamp(texture(glass_roughness, physical_uv).r * 0.65 + 0.2, 0.25, 0.9);
    NORMAL_MAP = texture(glass_normal, physical_uv).rgb;
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
    vec3 pigment = floor_hit ? wood * 0.45 : wall * mix(vec3(0.55,0.60,0.52),vec3(0.72,0.61,0.50),decor_traits.x);
    pigment *= mix(0.65, 1.0, clamp((p.y - floor_y) / 3.0, 0.0, 1.0));
    float room_pixels = 1.0 / max(max(length(dx), length(dy)), 0.0001);
    float detail = smoothstep(5.0, 22.0, room_pixels);
    float wall_distance = nearest;
    float side = room_traits.y > 0.5 ? 1.0 : -1.0;
    vec3 timber = vec3(0.19, 0.09, 0.045);
    if (detail > 0.01 && interiors_enabled) {
        // Fixed bounded analytic tests; no raymarch, lights, viewport or mesh per room.
        furnish(ro, rd, vec3(-w + 0.12, floor_y, depth - 0.5),
            vec3(-w + 0.65, floor_y + 1.9, depth - 0.12), timber, nearest, pigment);
        furnish(ro, rd, vec3(w - 0.8, floor_y, depth - 0.6),
            vec3(w - 0.12, floor_y + 1.25, depth - 0.12), timber * 1.3, nearest, pigment);
        if (room_kind == 0 && room_traits.x > 0.35) {
            furnish(ro, rd, vec3(-0.65 + side * 0.35, floor_y + 0.12, 1.4),
                vec3(0.65 + side * 0.35, floor_y + 0.55, depth - 0.6),
                mix(vec3(0.21, 0.28, 0.29), vec3(0.4, 0.25, 0.18), decor_traits.y), nearest, pigment);
            furnish(ro, rd, vec3(-0.7 + side * 0.35, floor_y, depth - 0.8),
                vec3(0.7 + side * 0.35, floor_y + 1.05, depth - 0.65), timber, nearest, pigment);
            furnish(ro, rd, vec3(-0.4 + side * 0.35, floor_y + 0.55, depth - 1.25),
                vec3(0.4 + side * 0.35, floor_y + 0.68, depth - 0.85),
                vec3(0.7, 0.65, 0.51), nearest, pigment);
        } else {
            furnish(ro, rd, vec3(-0.95, floor_y + 0.65, 1.4),
                vec3(0.95, floor_y + 0.79, 2.15), timber * 1.4, nearest, pigment);
            furnish(ro, rd, vec3(-0.82, floor_y, 1.48),
                vec3(-0.65, floor_y + 0.7, 2.05), timber, nearest, pigment);
            furnish(ro, rd, vec3(0.65, floor_y, 1.48),
                vec3(0.82, floor_y + 0.7, 2.05), timber, nearest, pigment);
            furnish(ro, rd, vec3(-0.3, floor_y + 0.1, 2.2),
                vec3(0.3, floor_y + (room_kind == 2 ? 0.65 : 1.15), 2.4),
                room_kind == 2 ? vec3(0.28, 0.24, 0.18) : timber, nearest, pigment);
            if (room_kind == 3) {
                furnish(ro, rd, vec3(-w + 0.1, floor_y + 0.8, 1.0),
                    vec3(-w + 0.65, floor_y + 0.88, depth - 0.5), timber, nearest, pigment);
                furnish(ro, rd, vec3(-w + 0.1, floor_y + 1.3, 1.0),
                    vec3(-w + 0.65, floor_y + 1.38, depth - 0.5), timber, nearest, pigment);
            }
        }
        if(room_kind==0 && decor_traits.w<0.72) {
            float lamp_x=side*min(w*0.62,1.05);
            furnish(ro,rd,vec3(lamp_x-.018,floor_y,1.15),vec3(lamp_x+.018,floor_y+1.45,1.19),timber,nearest,pigment);
            rounded_shade(ro,rd,vec3(lamp_x,floor_y+1.48,1.17),vec3(.23,.14,.23),nearest,pigment);
        }
    }
    if (nearest < wall_distance) {
        vec3 furniture_point = ro + rd * nearest;
        pigment *= mix(vec3(0.72), texture(wood_albedo, furniture_point.xy * vec2(0.35, 0.65)).rgb, 0.3);
    }
    float hour = minute_of_day / 60.0;
    float offset = lamp_traits.w * 1.8;
    float activity = room_kind == 0
        ? smoothstep(16.5 + offset, 18.0 + offset, hour) * (1.0 - smoothstep(22.0 + offset, 24.0, hour))
        : smoothstep(6.0 + offset, 8.0 + offset, hour) * (1.0 - smoothstep(17.0, 19.0 + offset, hour));
    if (weekend && room_kind == 1) { activity *= 0.12; }
    activity *= step(0.22, lamp_traits.z);
    float daylight = smoothstep(6.0, 9.0, hour) * (1.0 - smoothstep(16.0, 19.0, hour));
    // Bounded tungsten/lamplight palette, approximately 2300â€“3300 K; no neon hues.
    vec3 lamp_colour = mix(vec3(1.0, 0.33, 0.085), vec3(1.0, 0.56, 0.28), lamp_traits.x);
    float lamp_level = mix(0.35, 1.25, lamp_traits.y);
    vec3 illumination = vec3(0.025, 0.035, 0.055) + daylight * vec3(0.15, 0.17, 0.18)
        + activity * lamp_colour * lamp_level;
    float curtain_width = mix(0.025, 0.42, decor_traits.z);
    float curtain = 1.0 - smoothstep(curtain_width - 0.015, curtain_width + 0.015,
        min(st.x, 1.0 - st.x));
    float roller = step(0.72, decor_traits.w) * (1.0-smoothstep(mix(0.35,0.75,decor_traits.z)-0.01, mix(0.35,0.75,decor_traits.z)+0.01, UV2.y));
    vec3 interior = mix(pigment, wall * mix(0.48,0.78,decor_traits.x), max(curtain,roller) * detail);
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
    float pane_valid = step(0.0, UV2.y) * step(UV2.y, 1.0);
    ALBEDO = glaze;
    EMISSION = interiors_enabled ? interior * illumination * (1.0 - fresnel * 0.85) * pane_valid : vec3(0.0);
}
