shader_type particles;
render_mode disable_force, disable_velocity;
uniform int kind = 0; // rain, sleet, snow, hail
uniform vec3 wind_mps = vec3(0.0);
float random_value(float n) { return fract(sin(n*127.1+311.7)*43758.5453); }
void start() {
	float seed=float(NUMBER)+float(RANDOM_SEED%uint(65521));
	TRANSFORM=EMISSION_TRANSFORM;
	vec3 offset=vec3(random_value(seed),random_value(seed+1.0),random_value(seed+2.0));
	TRANSFORM[3].xyz+=(offset-0.5)*vec3(22.0,2.0,22.0);
	CUSTOM=vec4(random_value(seed+3.0)*6.283185,0.0,random_value(seed+4.0),0.0);
	COLOR=vec4(1.0);
}
void process() {
	CUSTOM.y+=DELTA;
	float age=CUSTOM.y;
	float fall=mix(24.0,34.0,CUSTOM.z);
	vec2 flutter=vec2(0.0);
	if(kind==1) fall=mix(13.0,20.0,CUSTOM.z);
	if(kind==2) {
		fall=mix(1.0,2.4,CUSTOM.z);
		flutter=vec2(sin(age*2.2+CUSTOM.x),cos(age*1.6+CUSTOM.x))*0.65;
	}
	if(kind==3) fall=min(38.0,mix(16.0,22.0,CUSTOM.z)+age*12.0);
	VELOCITY=wind_mps*(kind==2 ? 0.85 : 0.55)+vec3(flutter.x,-fall,flutter.y);
	TRANSFORM[3].xyz+=VELOCITY*DELTA;
}
