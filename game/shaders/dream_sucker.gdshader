shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// THE SUCKERS (DREAM_TENTACLE_DIRECTION §2, §16): hero suckers on the
// distal third as geometry — a MultiMesh of small domes the controller
// places on the ventral surface every frame. INSTANCE_CUSTOM carries
// (engagement, rim light, sequence phase, size): engaged suckers compress
// and flatten, their rims brighten to a soft pink light, and they release
// in sequence. The dome mesh is a unit hemisphere (y up).
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform vec3 sucker_color : source_color = vec3(0.780, 0.459, 0.565);
uniform vec3 rim_light : source_color = vec3(0.95, 0.55, 0.65);
uniform vec3 flesh_deep : source_color = vec3(0.141, 0.031, 0.122);
uniform float wetness : hint_range(0.0, 1.0) = 0.8;
uniform bool debug_gray = false;

varying float v_engage;
varying float v_rim;
varying float v_h;
varying vec2 v_uv;

void vertex() {
	float engage = INSTANCE_CUSTOM.x;
	float size = max(0.004, INSTANCE_CUSTOM.w);
	// Compression: the dome flattens to a disc and spreads a little.
	vec3 p = VERTEX;
	p.y *= mix(1.0, 0.28, engage);
	p.xz *= mix(1.0, 1.18, engage) * size;
	p.y *= size;
	// The cup: a dimple in the centre, deeper when engaged.
	float rr = length(VERTEX.xz);
	float cup = (1.0 - smoothstep(0.0, 0.55, rr)) * (0.25 + 0.35 * engage);
	p.y -= cup * size * max(0.0, VERTEX.y);
	VERTEX = p;
	v_engage = engage;
	v_rim = INSTANCE_CUSTOM.y;
	v_h = VERTEX.y / size;
	v_uv = VERTEX.xz / size;
}

void fragment() {
	float rr = length(v_uv);
	float rim = smoothstep(0.45, 0.75, rr) * (1.0 - smoothstep(0.85, 1.0, rr));
	float centre = 1.0 - smoothstep(0.0, 0.45, rr);
	vec3 col = mix(sucker_color, flesh_deep, rim * 0.6);
	col = mix(col, sucker_color * 1.15, centre * 0.5);
	ALBEDO = col;
	ROUGHNESS = mix(0.36, 0.08, wetness * (0.5 + 0.5 * v_engage));
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = rim_light * rim * v_rim * 0.9 + sucker_color * centre * v_engage * 0.15;
	BACKLIGHT = sucker_color * 0.6;
	if (debug_gray) {
		ALBEDO = vec3(0.62);
		EMISSION = vec3(0.0);
		ROUGHNESS = 0.55;
	}
}
