shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/prologue_mirror_film.gdshaderinc"

uniform sampler2D mirror_view : source_color, filter_linear_mipmap;
uniform float reflection_gain : hint_range(0.5, 1.5) = 0.92;
uniform float age_strength : hint_range(0.0, 1.0) = 0.24;

uniform vec2 glass_size = vec2(0.42, 0.57);
uniform float condensation = 0.0;
// Bounded authored time, never shader TIME: pause and reload own this effect.
uniform vec2 crossing = vec2(0.0);
varying vec2 glass_uv;

void vertex() {
	// BoxMesh atlas UVs cover six faces, not the entire front rectangle.
	glass_uv = VERTEX.xy / glass_size + vec2(0.5);
}

void fragment() {
	vec2 feed_uv = vec2(glass_uv.x, 1.0 - glass_uv.y);
	vec3 reflected = texture(mirror_view, feed_uv).rgb * reflection_gain;
	if(crossing.x>0.0){
		vec2 centered=feed_uv-vec2(.5);
		float aperture=1.0-smoothstep(.32,.51,length(centered));
		vec3 folded=reflected;
		for(int i=1;i<=5;i++){
			float depth=float(i);
			float angle=crossing.x*.055*depth*sin(crossing.y*.65);
			mat2 turn=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
			vec2 nested=turn*centered*pow(1.38,depth)+vec2(.5);
			float inside=step(0.0,nested.x)*step(nested.x,1.0)*step(0.0,nested.y)*step(nested.y,1.0);
			float rim=smoothstep(.43,.49,max(abs(nested.x-.5),abs(nested.y-.5)));
			vec3 view=texture(mirror_view,clamp(nested,vec2(.001),vec2(.999))).rgb*reflection_gain;
			folded=mix(folded,view*(1.0-depth*.09),inside*(.35+rim*.4));
		}
		reflected=mix(reflected,folded,crossing.x*aperture);
	}
	float wet=prologue_mirror_wet(glass_uv,condensation);
	if (wet>0.01) {
		vec2 blur=vec2(0.008)*wet;
		vec3 diffused=texture(mirror_view,feed_uv+vec2(blur.x,0.0)).rgb
			+texture(mirror_view,feed_uv-vec2(blur.x,0.0)).rgb
			+texture(mirror_view,feed_uv+vec2(0.0,blur.y)).rgb
			+texture(mirror_view,feed_uv-vec2(0.0,blur.y)).rgb;
		reflected=mix(reflected,diffused*0.25*reflection_gain,wet*0.8);
	}
	if(prologue_film.x>=0.0)reflected=mix(reflected,vec3(.58,.62,.60),wet*.985);
	float edge = smoothstep(0.42, 0.50, max(abs(glass_uv.x - 0.5), abs(glass_uv.y - 0.5)));
	float broad = sin(glass_uv.x * 19.0 + sin(glass_uv.y * 13.0) * 2.2)
		* sin(glass_uv.y * 27.0 - glass_uv.x * 8.0);
	float fine = sin(glass_uv.x * 63.0 + glass_uv.y * 41.0) * 0.18;
	float foxing = smoothstep(0.58, 0.92, broad * 0.5 + 0.5 + fine)
		* age_strength;
	float veil = edge * 0.34 + foxing * (0.22 + edge * 0.38);
	vec3 old_silver = vec3(0.52, 0.54, 0.50);
	ALBEDO = mix(reflected, old_silver, clamp(veil, 0.0, 0.68));
	ROUGHNESS = 0.10 + veil * 0.52;
	METALLIC = 0.08;
}
