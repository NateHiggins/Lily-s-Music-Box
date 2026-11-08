// The Sun through the brass telescope (Lily's sun_telescope ruling, 2026-11-04:
// built now and reviewed on the optical bench, before any telescope is installed).
// Only narrow fields resolve any of it: a naked-eye Sun is the plain limb-darkened
// disc in queens_weather_sky.gdshader.
//
// Disc coordinates: unit disc, x across, y up, z toward the viewer (limb mu).
// Granulation is cellular noise on the visible hemisphere: bright rising cells and
// dark sinking lanes, about 1.4 arcseconds across, re-forming over minutes.
// Sunspots come from solar_surface.gd as disc positions: dark umbra, a radially
// striated penumbra, and faculae brightening around them toward the limb.
// Prominences are thin H-alpha loops standing off the limb, visible past it only.

uniform vec4 sun_spots[8]; // xy disc position, z umbra radius (disc units), w strength 0-1
uniform float sun_detail_scale = 260.0; // cells across one disc radius: larger than real granules (about 650) so a 0.5-degree eyepiece field resolves them
uniform float sun_prominence = 0.35;
uniform float sun_eye = 0.0; // Star God phase A: the spots gather into an eye

float sun_hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 sun_hash3(vec3 p) {
    return vec3(sun_hash(p), sun_hash(p + 31.7), sun_hash(p + 77.1));
}

// Distance to the nearest and second-nearest feature point; F2-F1 marks the lanes.
vec2 sun_cells(vec3 p) {
    vec3 cell = floor(p);
    vec3 local = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    for (int z = -1; z <= 1; z++)
    for (int y = -1; y <= 1; y++)
    for (int x = -1; x <= 1; x++) {
        vec3 offset = vec3(float(x), float(y), float(z));
        vec3 point = offset + sun_hash3(cell + offset) - local;
        float d = dot(point, point);
        if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
    }
    return vec2(sqrt(f1), sqrt(f2));
}

float sun_value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(sun_hash(i), sun_hash(i + vec3(1, 0, 0)), f.x), mix(sun_hash(i + vec3(0, 1, 0)), sun_hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(sun_hash(i + vec3(0, 0, 1)), sun_hash(i + vec3(1, 0, 1)), f.x), mix(sun_hash(i + vec3(0, 1, 1)), sun_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// How much telescope detail this field resolves: none at naked-eye widths.
float sun_detail_amount(float field) {
    return 1.0 - smoothstep(0.012, 0.05, field);
}

// Photosphere brightness factor for a disc point (multiplies the limb-darkened disc).
float sun_photosphere(vec2 disc, float limb_mu, float seconds, float detail) {
    if (detail <= 0.0) return 1.0;
    vec3 sphere = vec3(disc, limb_mu);
    // Slow warp: cells drift, split and merge over a few minutes.
    vec3 warp = vec3(sun_value_noise(sphere * 9.0 + seconds * 0.004), sun_value_noise(sphere * 9.0 + 19.3 - seconds * 0.003), 0.0) - 0.5;
    vec2 cells = sun_cells(sphere * sun_detail_scale + warp * 1.6 + vec3(0.0, 0.0, seconds * 0.0025));
    float lane = smoothstep(0.0, 0.18, cells.y - cells.x);
    // ~6000 K cell interiors against ~5000 K lanes: roughly 0.75 of the brightness.
    float granulation = mix(0.74, 1.04, lane) * mix(1.0, 0.97, smoothstep(0.0, 0.6, cells.x));
    float spots = 1.0;
    float faculae = 0.0;
    for (int i = 0; i < 8; i++) {
        vec4 spot = sun_spots[i];
        if (spot.w <= 0.0) continue;
        vec2 rel = disc - spot.xy;
        // Foreshortening: spots near the limb are squeezed toward it.
        vec2 radial = length(spot.xy) > 0.001 ? normalize(spot.xy) : vec2(1.0, 0.0);
        float along = dot(rel, radial);
        float side = dot(rel, vec2(-radial.y, radial.x));
        float spot_mu = sqrt(max(0.05, 1.0 - dot(spot.xy, spot.xy)));
        vec2 flat_rel = vec2(along / spot_mu, side);
        float angle = atan(flat_rel.y, flat_rel.x);
        float warp_r = (sun_value_noise(vec3(angle * 3.0, float(i) * 7.1, seconds * 0.001)) - 0.5) * 0.35;
        float r = length(flat_rel) / max(spot.z, 0.0005) * (1.0 + warp_r);
        float umbra = 1.0 - smoothstep(0.85, 1.05, r);
        float penumbra = 1.0 - smoothstep(2.0, 2.4, r);
        // Penumbral filaments run radially out from the umbra.
        float filaments = 0.5 + 0.5 * sin(angle * 90.0 + sun_value_noise(vec3(angle * 14.0, r * 3.0, float(i))) * 6.0);
        float penumbra_level = mix(0.62, 0.86, filaments);
        float level = mix(mix(1.0, penumbra_level, penumbra), 0.22, umbra);
        spots = min(spots, mix(1.0, level, spot.w));
        // Faculae: bright magnetic patches around the group, plainest near the limb.
        float plage = (1.0 - smoothstep(2.4, 6.0, r)) * smoothstep(2.0, 2.6, r);
        faculae = max(faculae, plage * spot.w * (1.0 - limb_mu) * sun_value_noise(sphere * 160.0));
    }
    float detailed = granulation * spots + faculae * 0.45;
    return mix(1.0, detailed, detail);
}

// Prominence glow just past the limb (radius 1 to about 1.15), H-alpha crimson.
vec3 sun_prominences(vec2 disc, float radius, float seconds, float detail) {
    if (detail <= 0.0 || radius < 1.0 || radius > 1.2) return vec3(0.0);
    float angle = atan(disc.y, disc.x);
    float height = 0.025 + 0.11 * pow(sun_value_noise(vec3(angle * 6.0, seconds * 0.0008, 3.0)), 3.0) * sun_prominence;
    float strands = 0.6 + 0.4 * sun_value_noise(vec3(angle * 80.0, radius * 40.0, seconds * 0.002));
    float above = radius - 1.0;
    float glow = (1.0 - smoothstep(height * 0.6, height, above)) * strands;
    return vec3(0.95, 0.12, 0.10) * glow * detail * 0.55;
}
