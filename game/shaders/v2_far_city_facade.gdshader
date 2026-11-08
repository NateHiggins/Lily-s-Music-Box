shader_type spatial;
render_mode cull_back;
// Distant district facades (city_far_districts.glb). Catalogue PBR on metric UV0, with
// a window grid drawn from the same metres. COLOR_0 carries optical traits only:
// r building seed, g kind / 4 (0 dwelling, 1 office, 2 factory, 3 blank), b storey / 6,
// a lit bias. Lamps follow the same campaign-clock schedule and tungsten palette as
// v2_background_window_interior.gdshader. Beyond the pixel scale of a pane the grid
// resolves to its average, so kilometre-distant walls do not shimmer.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec2 physical_uv_scale = vec2(1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float minute_of_day : hint_range(0.0, 1440.0) = 1200.0;
uniform bool weekend = false;
uniform float dusk_fill = 0.0;
// The live depth fog (copied from the Environment by the composer). Lit windows are
// point sources that read through haze long after a wall has gone to fog colour, so
// lamp emission is raised by what the fog removes; the wall itself is fogged as usual.
uniform float fog_density = 0.0;
uniform float fog_begin = 10.0;
uniform float fog_end = 1000.0;
uniform float fog_curve = 1.0;
uniform vec3 fog_colour : source_color = vec3(0.3, 0.33, 0.4);

varying vec4 traits;
varying float facade;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

void vertex() {
    traits = COLOR;
    facade = 1.0 - step(0.5, abs(NORMAL.y));
}

float activity_for(float kind, float hour, float offset) {
    float dwelling = smoothstep(16.5 + offset, 18.0 + offset, hour) * (1.0 - smoothstep(22.0 + offset, 24.0, hour))
        + 0.35 * smoothstep(5.5 + offset, 6.5 + offset, hour) * (1.0 - smoothstep(7.5 + offset, 8.5 + offset, hour));
    float office = smoothstep(6.0 + offset, 8.0 + offset, hour) * (1.0 - smoothstep(17.0, 19.0 + offset, hour));
    float factory = smoothstep(6.0, 7.0 + offset, hour) * (1.0 - smoothstep(17.0, 18.5 + offset, hour));
    if (kind < 0.5) return dwelling * 0.55 + 0.05; // not every flat is home at once
    if (kind < 1.5) return (weekend ? office * 0.12 : office) + 0.03;
    return (weekend ? factory * 0.2 : factory) + 0.08; // night shifts and watchmen
}

void fragment() {
    vec2 physical_uv = UV * physical_uv_scale;
    vec3 base = texture(albedo_tex, physical_uv).rgb * tint;
    float rough = texture(rough_tex, physical_uv).r;
    NORMAL_MAP = texture(normal_tex, physical_uv).rgb;
    NORMAL_MAP_DEPTH = 0.35;

    float kind = floor(traits.g * 4.0 + 0.5);
    float storey = max(traits.b * 6.0, 2.6);
    float bay = mix(2.1, 3.0, hash1(traits.r * 97.0));
    float has_windows = facade * (1.0 - step(2.5, kind));
    vec2 cell = vec2(bay, storey);
    vec2 grid = UV / cell;
    vec2 st = fract(grid);
    vec2 id = floor(grid);
    vec2 pane = kind > 1.5 ? vec2(0.72, 0.62) : vec2(0.48, 0.52);
    vec2 aa = fwidth(grid);
    vec2 lo = 0.5 - pane * 0.5;
    vec2 hi = 0.5 + pane * 0.5;
    vec2 edge = max(aa, vec2(0.002));
    vec2 inside = smoothstep(lo - edge, lo + edge, st) * (1.0 - smoothstep(hi - edge, hi + edge, st));
    float sharp = inside.x * inside.y;
    // A pane smaller than about two pixels resolves to the wall's mean glazing.
    float far = smoothstep(0.18, 0.55, max(aa.x, aa.y));
    float coverage = pane.x * pane.y;
    float ground_floor = step(id.y, 0.5);
    float window = mix(sharp, coverage, far) * has_windows * (1.0 - ground_floor * 0.7);

    float hour = minute_of_day / 60.0;
    float seed = traits.r * 1000.0 + id.x * 7.0 + id.y * 131.0;
    float offset = hash1(seed + 13.0) * 1.8;
    float activity = clamp(activity_for(kind, hour, offset) + (traits.a - 0.5) * 0.25, 0.0, 1.0);
    float lit_sharp = step(hash2(id + traits.r * 31.0), activity);
    float lit_mean = clamp(activity_for(kind, hour, 0.9) + (traits.a - 0.5) * 0.25, 0.0, 1.0);
    float lit = mix(lit_sharp, lit_mean, far);
    vec3 lamp_colour = mix(vec3(1.0, 0.33, 0.085), vec3(1.0, 0.56, 0.28), hash1(seed + 29.0));
    float lamp_level = mix(0.35, 1.25, hash1(seed + 31.0));

    vec3 glass = vec3(0.07, 0.085, 0.10);
    ALBEDO = mix(base, glass, window);
    ROUGHNESS = mix(clamp(rough * 0.9 + 0.08, 0.35, 1.0), 0.22, window);
    // dusk_fill lifts the wall slightly at blue hour so facades do not drop to black.
    float depth = -VERTEX.z;
    float fog_amount = fog_density * pow(clamp((depth - fog_begin) / max(fog_end - fog_begin, 1.0), 0.0, 1.0), fog_curve);
    vec3 lamp = window * lit * lamp_colour * lamp_level;
    EMISSION = lamp * 1.4 + base * dusk_fill * 0.04 * facade;
    // This material writes its own fog (replacing the environment's for these walls) so
    // a lit pane can thin the haze in front of it; unlit wall takes the full fog.
    float lamp_presence = clamp(max(lamp.r, max(lamp.g, lamp.b)) * mix(1.2, 0.7, far), 0.0, 0.75);
    FOG = vec4(fog_colour, fog_amount * (1.0 - lamp_presence));
}
