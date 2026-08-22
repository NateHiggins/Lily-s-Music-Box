shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_add, unshaded;
// THE HALOS (DREAM_TENTACLE_DIRECTION §8): luminous structures around the
// eye that are not attached to the body — evidence of surrounding geometry
// the player cannot completely perceive. A MultiMesh of small flat beads
// (unit quads facing +y, billboarded in the vertex stage): the inner ring
// ceremonial, the outer sparse, the phase ring only visible at grazing
// angles and in phase events. INSTANCE_CUSTOM: (ring 0/1/2, brightness,
// phase visibility, size).
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform vec3 gold_hot : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 gold : source_color = vec3(0.859, 0.659, 0.298);
uniform float energy : hint_range(0.0, 3.0) = 1.0;
uniform bool debug_gray = false;

varying vec2 v_q;
varying float v_ring;
varying float v_bright;
varying float v_vis;

void vertex() {
	float size = max(0.002, INSTANCE_CUSTOM.w);
	// Billboard: the quad faces the camera, keeping its instance position.
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec2 q = VERTEX.xz;
	vec3 world = centre + (right * q.x + up * q.y) * size;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	v_q = q;
	v_ring = INSTANCE_CUSTOM.x;
	v_bright = INSTANCE_CUSTOM.y;
	v_vis = INSTANCE_CUSTOM.z;
}

void fragment() {
	float r = length(v_q) * 2.0;
	// A bead with depth: a bright core, a soft body, a faint halo; the outer
	// ring's beads are points; the phase ring's are slivers.
	float core = 1.0 - smoothstep(0.0, 0.25, r);
	float body = 1.0 - smoothstep(0.15, 0.7, r);
	float glow = 1.0 - smoothstep(0.5, 1.0, r);
	vec3 col = gold_hot * core + gold * body * 0.6 + gold * glow * 0.12;
	if (v_ring > 1.5) {
		float sliver = 1.0 - smoothstep(0.0, 0.08, abs(v_q.y)) ;
		col = mix(gold, vec3(0.55, 0.35, 0.75), 0.5) * sliver * (1.0 - smoothstep(0.3, 1.0, r));
	}
	float a = v_bright * v_vis * energy;
	ALBEDO = col * a;
	ALPHA = clamp(a * (core + body * 0.8 + glow * 0.3), 0.0, 1.0);
	if (debug_gray) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	}
}
