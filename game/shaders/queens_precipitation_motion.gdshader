shader_type particles;
render_mode disable_force, disable_velocity;
uniform int kind = 0; // rain, sleet, snow, hail
uniform vec3 wind_mps = vec3(0.0);
uniform float intensity = .4;
uniform vec3 camera_forward = vec3(0.0,0.0,-1.0);
uniform vec3 camera_right = vec3(1.0,0.0,0.0);
uniform float camera_y = 0.0;
uniform float horizontal_tangent = 1.3;
uniform mat4 view_projection = mat4(1.0);
float random_value(float n) { return fract(sin(n*127.1+311.7)*43758.5453); }
vec3 spawn_offset(float seed) {
	float depth=mix(1.5,20.0,random_value(seed));
	float width=min(24.0,depth*horizontal_tangent);
	return camera_forward*depth+camera_right*((random_value(seed+1.0)*2.0-1.0)*width)
		+vec3(0.0,(random_value(seed+2.0)-.5)*8.0,0.0);
}
void start() {
	if(kind==4) {
		// Keep the position and velocity supplied by the parent impact.
		CUSTOM=vec4(0.0);
	} else {
	float seed=float(NUMBER)+float(RANDOM_SEED%uint(65521));
	TRANSFORM=EMISSION_TRANSFORM;
	TRANSFORM[3].xyz+=spawn_offset(seed);
	CUSTOM=vec4(random_value(seed+3.0)*6.283185,0.0,random_value(seed+4.0),0.0);
	COLOR=vec4(1.0);
	}
}
void process() {
	CUSTOM.y+=DELTA;
	if(kind==4) {
		VELOCITY.y-=9.8*DELTA;
		TRANSFORM[3].xyz+=VELOCITY*DELTA;
		COLOR.a=1.0-smoothstep(.18,.35,CUSTOM.y);
		if(CUSTOM.y>=.35) ACTIVE=false;
	} else {
	float age=CUSTOM.y;
	float fall=mix(7.0,32.0,intensity)*mix(.85,1.15,CUSTOM.z);
	vec2 flutter=vec2(0.0);
	if(kind==1) fall=mix(13.0,20.0,CUSTOM.z);
	if(kind==2) {
		fall=mix(1.0,2.4,CUSTOM.z);
		flutter=vec2(sin(age*2.2+CUSTOM.x),cos(age*1.6+CUSTOM.x))*0.65;
	}
	if(kind==3) fall=min(38.0,mix(16.0,22.0,CUSTOM.z)+age*12.0);
	if(kind==3 && CUSTOM.w>0.0) {
		VELOCITY.y-=9.8*DELTA;
		CUSTOM.w=max(.001,CUSTOM.w-DELTA);
	} else {
		VELOCITY=wind_mps*(kind==2 ? 0.85 : 0.55)+vec3(flutter.x,-fall,flutter.y);
	}
	if(COLLIDED) {
		// This owner uses a top-down heightfield. Its signed normal/depth can
		// both point into the floor; orient the response toward the open sky.
		vec3 contact_normal=COLLISION_NORMAL.y<0.0 ? -COLLISION_NORMAL : COLLISION_NORMAL;
		TRANSFORM[3].xyz+=contact_normal*(abs(COLLISION_DEPTH)+.001);
		if(kind==3) {
			if(dot(VELOCITY,contact_normal)<0.0) VELOCITY=reflect(VELOCITY,contact_normal)*.48;
			CUSTOM.w=.6;
		} else {
			if(kind==0 && abs(COLLISION_DEPTH)<.6) {
				vec3 splash_velocity=contact_normal*mix(.5,1.1,CUSTOM.z)+vec3(sin(CUSTOM.x),0.0,cos(CUSTOM.x))*.45;
				emit_subparticle(TRANSFORM,splash_velocity,COLOR,vec4(0.0),FLAG_EMIT_POSITION|FLAG_EMIT_VELOCITY|FLAG_EMIT_COLOR);
			}
			TRANSFORM[3].xyz=EMISSION_TRANSFORM[3].xyz+spawn_offset(float(NUMBER)+floor(age*7.0));
		}
	}
	TRANSFORM[3].xyz+=VELOCITY*DELTA;
	// Recycle the same bounded pool near the view instead of spending most of
	// its lifetime below the street. Wind remains world-space when looking around.
	vec4 clip=view_projection*vec4(TRANSFORM[3].xyz,1.0);
	if(TRANSFORM[3].y<camera_y-3.0 || clip.w<=0.0 || abs(clip.x)>clip.w || abs(clip.y)>clip.w) {
		TRANSFORM[3].xyz=EMISSION_TRANSFORM[3].xyz+spawn_offset(float(NUMBER)+floor(age*7.0));
	}
	}
}
