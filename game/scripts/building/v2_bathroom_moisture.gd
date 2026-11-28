extends Node
## Transient optics only. Existing tap/boiler/weather owners supply every input.
const FILM := preload("res://shaders/v2_glass_film.gdshader")
const STEAM := preload("res://shaders/v2_bath_steam.gdshader")
const MIST := preload("res://shaders/v2_shower_mist.gdshader")
const PERIOD := 0.1
## Fog density at a saturated room, and how fast a hot shower wets or dries it.
const STEAM_GAIN := 0.7
const WETTING_RATE := 0.05
## Jets leave the rose at this speed (m/s) under full pressure.
const JET_SPEED := Vector2(3.5, 4.1)
const DRYING_RATE := 0.012
var _world: Node3D
var _sources: Array=[]
var _rooms: Dictionary={}
var _surfaces: Array=[]
var _mirror_surfaces: Dictionary={}
var _retiring: Array[int]=[]
var _elapsed:=0.0
var _stopped:=false
var exposure_ready:=false
var _drop_mesh: SphereMesh
var _drop_process: ParticleProcessMaterial
var _water: StandardMaterial3D
var _splash_mesh: SphereMesh
var _splash_process: ParticleProcessMaterial
var _mist_mesh: QuadMesh
var _mist_process: ParticleProcessMaterial
var _steam_mesh: QuadMesh
var _steam_process: ParticleProcessMaterial
var _clock := 0.0
var _pressure := 1.0

func configure(world: Node3D) -> bool:
	_world=world
	_water=MatLib.get_mat("water_clear").duplicate() as StandardMaterial3D
	_water.uv1_triplanar=false;_water.normal_enabled=true;_water.normal_scale=0.1
	_water.albedo_color=Color(0.76,0.88,0.95,0.66);_water.roughness=0.12
	_water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	# A player can stand inside the cone. Fade the nearest drops rather than
	# letting a centimetre-long streak clip into a bright screen-sized polygon.
	_water.distance_fade_mode=BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_water.distance_fade_min_distance=0.25;_water.distance_fade_max_distance=0.55
	_water.emission_enabled=true;_water.emission=Color(0.85,0.92,1.0);_water.emission_energy_multiplier=0.4
	_water.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# A rose throws separate threads of water that the eye reads as streaks.
	# The former 0.8 mm drops were thinner than a pixel at arm's length.
	_drop_mesh=SphereMesh.new();_drop_mesh.radius=0.0017;_drop_mesh.height=0.13
	_drop_mesh.radial_segments=6;_drop_mesh.rings=2;_drop_mesh.material=_water
	# Every drop leaves one of the rose's holes along that hole's own line, so
	# the spray is a set of standing jets in rings rather than loose rain.
	var holes:=_rose_pattern()
	_drop_process=ParticleProcessMaterial.new()
	_drop_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	_drop_process.emission_point_texture=holes[0];_drop_process.emission_normal_texture=holes[1]
	_drop_process.emission_point_count=int(holes[2])
	# Directed points turn local +Z onto each hole's line.
	_drop_process.direction=Vector3(0,0,1);_drop_process.spread=1.1
	_drop_process.gravity=Vector3.DOWN*4.0
	_drop_process.initial_velocity_min=JET_SPEED.x;_drop_process.initial_velocity_max=JET_SPEED.y
	_drop_process.particle_flag_align_y=true
	# Where the threads land they break into a low crown of droplets.
	_splash_mesh=SphereMesh.new();_splash_mesh.radius=0.0028;_splash_mesh.height=0.0056
	_splash_mesh.radial_segments=6;_splash_mesh.rings=3;_splash_mesh.material=_water
	_splash_process=ParticleProcessMaterial.new();_splash_process.direction=Vector3.UP
	_splash_process.spread=68.0;_splash_process.gravity=Vector3.DOWN*7.0
	_splash_process.initial_velocity_min=0.5;_splash_process.initial_velocity_max=1.3
	_splash_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
	_splash_process.emission_ring_axis=Vector3.UP;_splash_process.emission_ring_radius=0.20
	_splash_process.emission_ring_inner_radius=0.0;_splash_process.emission_ring_height=0.01
	# The cone itself: soft untextured puffs that give the streaks a body.
	var mist_material:=ShaderMaterial.new();mist_material.shader=MIST
	_mist_mesh=QuadMesh.new();_mist_mesh.size=Vector2.ONE;_mist_mesh.material=mist_material
	_mist_process=ParticleProcessMaterial.new();_mist_process.direction=Vector3.DOWN
	_mist_process.spread=6.0;_mist_process.gravity=Vector3.DOWN*1.5
	_mist_process.initial_velocity_min=1.5;_mist_process.initial_velocity_max=2.1
	_mist_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_mist_process.emission_sphere_radius=0.05
	_mist_process.scale_min=0.20;_mist_process.scale_max=0.32
	var swell:=Curve.new();swell.add_point(Vector2(0,0.45));swell.add_point(Vector2(1,1.0))
	var swell_texture:=CurveTexture.new();swell_texture.curve=swell;_mist_process.scale_curve=swell_texture
	var fade:=Gradient.new();fade.set_color(0,Color(1,1,1,0));fade.set_color(1,Color(1,1,1,0));fade.add_point(0.25,Color(1,1,1,1))
	var fade_texture:=GradientTexture1D.new();fade_texture.gradient=fade;_mist_process.color_ramp=fade_texture
	# Steam you can see leave the hot water: slow buoyant puffs that swell,
	# curl and thin as they climb. The fog volume carries the room; these
	# carry the eye from the water to the ceiling.
	var steam_material:=ShaderMaterial.new();steam_material.shader=MIST
	steam_material.set_shader_parameter("tint",Color(0.90,0.91,0.90));steam_material.set_shader_parameter("strength",0.17)
	_steam_mesh=QuadMesh.new();_steam_mesh.size=Vector2.ONE;_steam_mesh.material=steam_material
	_steam_process=ParticleProcessMaterial.new();_steam_process.direction=Vector3.UP
	_steam_process.spread=24.0;_steam_process.gravity=Vector3.UP*0.10
	_steam_process.initial_velocity_min=0.22;_steam_process.initial_velocity_max=0.50
	_steam_process.damping_min=0.05;_steam_process.damping_max=0.12
	_steam_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_steam_process.emission_sphere_radius=0.24
	var bloom:=Curve.new();bloom.add_point(Vector2(0,0.35));bloom.add_point(Vector2(1,1.0))
	var bloom_texture:=CurveTexture.new();bloom_texture.curve=bloom;_steam_process.scale_curve=bloom_texture
	_steam_process.scale_max=1.55;_steam_process.scale_min=0.95
	var thin:=Gradient.new();thin.set_color(0,Color(1,1,1,0));thin.set_color(1,Color(1,1,1,0));thin.add_point(0.18,Color(1,1,1,1));thin.add_point(0.62,Color(1,1,1,0.7))
	var thin_texture:=GradientTexture1D.new();thin_texture.gradient=thin;_steam_process.color_ramp=thin_texture
	_steam_process.turbulence_enabled=true;_steam_process.turbulence_noise_strength=0.35
	_steam_process.turbulence_noise_scale=1.6;_steam_process.turbulence_noise_speed=Vector3(0.0,0.12,0.0)
	_steam_process.turbulence_influence_min=0.05;_steam_process.turbulence_influence_max=0.16
	for record: Dictionary in world.layout.spaces:
		if str(record.get("class",""))!="wet": continue
		_rooms[str(record.id)]={"humidity":0.0,"target":0.0,"record":record}
	for node: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if node is not TapProp or node.fixture!="shower":continue
		var room: String=world.room_at_world(node.global_position+Vector3.UP*0.3)
		if not _rooms.has(room):push_error("Shower has no wet-room moisture binding: "+str(node.get_path()));return false
		var spray:=GPUParticles3D.new();spray.name="ShowerSprayCone"
		spray.amount=492;spray.lifetime=0.5;spray.fixed_fps=30;spray.local_coords=true
		spray.emitting=false;spray.visible=false;spray.process_material=_drop_process
		spray.draw_pass_1=_drop_mesh;spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spray.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		spray.visibility_aabb=AABB(Vector3(-0.45,-2.15,-0.45),Vector3(0.9,2.25,0.9))
		var legacy: Node3D=node._stream.get_child(0);legacy.hide()
		node._stream.add_child(spray)
		# Children of the cone: they share its visibility and retire with it.
		var splash:=GPUParticles3D.new();splash.name="ShowerSplash"
		splash.amount=72;splash.lifetime=0.26;splash.fixed_fps=30;splash.local_coords=true
		splash.emitting=false;splash.process_material=_splash_process;splash.draw_pass_1=_splash_mesh
		splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;splash.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		splash.visibility_aabb=AABB(Vector3(-0.5,-0.1,-0.5),Vector3(1.0,0.5,1.0))
		# A tilted rose lands its jets off the plumb line; the crown stays level.
		var lean: float=maxf(0.5,node._stream.basis.y.y)
		splash.basis=node._stream.basis.inverse()
		splash.position.y=(float(node._water_empty_y)-node._stream.position.y)/lean+0.012
		spray.add_child(splash)
		var mist:=GPUParticles3D.new();mist.name="ShowerMist"
		mist.amount=22;mist.lifetime=0.85;mist.fixed_fps=30;mist.local_coords=true
		mist.emitting=false;mist.process_material=_mist_process;mist.draw_pass_1=_mist_mesh
		mist.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mist.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		mist.visibility_aabb=spray.visibility_aabb
		spray.add_child(mist)
		# Owned by the fixture, not the cone: steam outlives the last drops.
		var puffs:=GPUParticles3D.new();puffs.name="RisingSteam"
		puffs.amount=56;puffs.lifetime=5.2;puffs.fixed_fps=30;puffs.local_coords=false
		puffs.emitting=false;puffs.process_material=_steam_process;puffs.draw_pass_1=_steam_mesh
		puffs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;puffs.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		puffs.visibility_aabb=AABB(Vector3(-2.2,-0.4,-2.2),Vector3(4.4,3.6,4.4))
		puffs.position=node._stream.position+node._stream.basis*Vector3(0,(float(node._water_empty_y)-node._stream.position.y)/lean,0)+Vector3.UP*0.30
		node.add_child(puffs)
		var source: Dictionary={"tap":node,"room":room,"spray":spray,"legacy":legacy,"splash":splash,"mist":mist,"puffs":puffs}
		_sources.append(source);node.flow_changed.connect(_sync_spray.bind(_sources.size()-1));_sync_spray(_sources.size()-1)
	var rooms_in_use: Dictionary={}
	for source: Dictionary in _sources:rooms_in_use[source.room]=true
	for room: String in rooms_in_use:_make_steam(_rooms[room])
	for record: Dictionary in world.layout.windows:
		var opening: Node3D=world.adapter.root.get_node_or_null(str(record.id))
		if opening==null:continue
		var original:=opening.get_node_or_null("Glazing") as MeshInstance3D
		if original==null:continue
		var panes: Array[MeshInstance3D]=[]
		if original.visible:panes.append(original)
		else:
			# The hopper retains its old semantic opening, but its native sash
			# owns the visible moving glass. Never coat the retired placeholder.
			for draw: MeshInstance3D in opening.find_children("*","MeshInstance3D",true,false):
				if draw.visible and str(draw.get_meta("material_key",""))=="glass":panes.append(draw)
		var room_record: Dictionary=world.adapter.root._space_by_id(str(record.space))
		if room_record.is_empty():continue
		var axis:=0 if str(record.axis)=="z" else 2
		var center:=Vector3((float(room_record.rect[0])+float(room_record.rect[2]))*0.5,0.0,(float(room_record.rect[1])+float(room_record.rect[3]))*0.5)
		var normal:=Vector3.ZERO
		normal[axis]=signf(float(record.center[0 if axis==0 else 1])-center[axis])
		normal=world.adapter.root.global_basis*normal
		for pane: MeshInstance3D in panes:
			var bounds:=pane.mesh.get_aabb()
			var local_axis:=0 if bounds.size.x<bounds.size.z else 2
			var local_sign:=signf((pane.global_basis.inverse()*normal)[local_axis])
			var size:=Vector2(bounds.size.z if local_axis==0 else bounds.size.x,bounds.size.y)
			if not _bind_surface(pane,str(record.space),size,local_axis==0,local_sign,false,false):return false
	for surface: Node in get_tree().get_nodes_in_group("planar_mirror_surface"):
		if not world.is_ancestor_of(surface):continue
		var owner_node: Node=surface.get_parent()
		while owner_node!=null and not owner_node.has_method("mirror_surface"):owner_node=owner_node.get_parent()
		if owner_node==null:continue
		var room: String=world.room_at_world(owner_node.mirror_center()+owner_node.mirror_normal()*0.06)
		if not _bind_surface(surface,room,surface.get_meta("mirror_size"),false,-1.0,true,false):return false
	_cache_exposure()
	return not _sources.is_empty()

func _cache_exposure() -> void:
	# Collision broadphase must contain the completed building before probing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _stopped:return
	var space:=_world.get_world_3d().direct_space_state
	for surface: Dictionary in _surfaces:
		if surface.mirror:continue
		var pane: MeshInstance3D=surface.pane
		var axis:=0 if surface.material.get_shader_parameter("along_z") else 2
		var normal:=Vector3.ZERO;normal[axis]=float(surface.material.get_shader_parameter("outside_sign"))
		normal=(pane.global_basis*normal).normalized()
		# A shallow outward/upward rain path clears small cornices, while deep
		# canopies and enclosed shafts still protect the face. Cache once.
		var start:=pane.global_position+normal*0.04
		var outside:=start+normal*2.5+Vector3.UP*1.5
		var query:=PhysicsRayQueryParameters3D.create(start,outside,1)
		surface.exposed=space.intersect_ray(query).is_empty() and _world.get_node("WeatherFX").exposed(outside)
	exposure_ready=true

func _make_steam(state: Dictionary) -> void:
	if RenderingServer.get_current_rendering_method()!="forward_plus":return
	var rect: Array=state.record.rect
	var floor_y: float=_world.adapter.root.level_y[state.record.level]
	var volume:=FogVolume.new();volume.name="LocalSteam"
	volume.set_meta("space_id",str(state.record.id))
	volume.size=Vector3(float(rect[2])-float(rect[0])-0.08,2.65,float(rect[3])-float(rect[1])-0.08)
	volume.position=Vector3((float(rect[0])+float(rect[2]))*0.5,floor_y+1.45,(float(rect[1])+float(rect[3]))*0.5)
	var material:=ShaderMaterial.new();material.shader=STEAM
	material.set_shader_parameter("cloud_noise",preload("res://scripts/building/weather_noise.gd").load_volume())
	volume.material=material;volume.visible=false;_world.adapter.root.add_child(volume)
	material.set_shader_parameter("floor_y",volume.global_position.y-volume.size.y*0.5)
	material.set_shader_parameter("ceiling_y",volume.global_position.y+volume.size.y*0.5)
	state["steam"]=volume;state["material"]=material;state["density"]=-1.0
	state["plume"]=0.0;state["shown_plume"]=-1.0;state["shown_fill"]=-1.0;state["source_at"]=Vector3.INF

func _bind_surface(pane: MeshInstance3D,room: String,size: Vector2,along_z: bool,outside_sign: float,mirror: bool,exposed: bool) -> bool:
	if pane.material_overlay!=null:push_error("Moisture refuses an occupied glass overlay: "+str(pane.get_path()));return false
	var film:=ShaderMaterial.new();film.shader=FILM;film.resource_name="water_clear_condensation_film"
	# Refractive glass carries an opaque scene copy despite being transparent.
	# Its final pass must not paint over the water film on the same surface.
	film.render_priority=1
	film.set_shader_parameter("albedo_tex",_water.albedo_texture)
	film.set_shader_parameter("rough_tex",_water.roughness_texture)
	film.set_shader_parameter("normal_tex",_water.normal_texture)
	film.set_shader_parameter("water_uv_scale",Vector2(_water.uv1_scale.x,_water.uv1_scale.y))
	film.set_shader_parameter("glass_size",size);film.set_shader_parameter("along_z",along_z)
	film.set_shader_parameter("pane_center",pane.mesh.get_aabb().get_center())
	film.set_shader_parameter("outside_sign",outside_sign)
	film.set_shader_parameter("mirror_surface",mirror)
	var surface:Dictionary={"pane":pane,"room":room,"material":film,"mirror":mirror,"exposed":exposed,"inside":0.0,"outside":0.0,"last_inside":-1.0,"last_outside":-1.0}
	_surfaces.append(surface)
	if mirror:_mirror_surfaces[pane.get_instance_id()]=surface
	return true

func set_mirror_story(pane:MeshInstance3D,value:Vector2) -> bool:
	# Cached once at binding: no per-frame surface scan or second phase clock.
	if _stopped or not is_instance_valid(pane) or not _mirror_surfaces.has(pane.get_instance_id()):return false
	var surface:Dictionary=_mirror_surfaces[pane.get_instance_id()]
	if value.x<0:pane.remove_meta("prologue_mirror_film")
	else:pane.set_meta("prologue_mirror_film",value)
	if value!=surface.get("last_story",Vector2.INF):
		surface.material.set_shader_parameter("prologue_film",value);surface.last_story=value
	return true

func _sync_spray(index: int) -> void:
	if _stopped:return
	var source: Dictionary=_sources[index]
	var amount: float=float(source.tap.get_flow_state().flow)
	if source.tap.has_method("spray_flow_amount"):amount=float(source.tap.spray_flow_amount())
	var emitting:=amount>0.0001
	if source.spray.emitting!=emitting:
		source.spray.emitting=emitting
		if not emitting and not _retiring.has(index):_retiring.append(index)
	for extra: String in ["splash","mist"]:
		if source[extra].emitting!=emitting:source[extra].emitting=emitting
	source["supply"]=amount
	if emitting:
		_retiring.erase(index)
		_feed(source)
		source.spray.visible=true

## Hole positions and lines of a rain rose, as the two textures a directed
## particle emitter reads: a centre hole and three rings, fanned a little
## wider toward the rim. Metres and unit vectors in the rose's own frame,
## where the face looks along -Y.
func _rose_pattern() -> Array:
	var points: Array[Vector3]=[Vector3.ZERO]
	var lines: Array[Vector3]=[Vector3.DOWN]
	for ring: Array in [[0.016,6],[0.032,10],[0.047,24]]:
		var radius: float=ring[0]
		var fan: float=deg_to_rad(6.5)*radius/0.047
		for hole in int(ring[1]):
			var around: float=TAU*(float(hole)+0.5*float(int(ring[1])%4))/float(ring[1])
			points.append(Vector3(cos(around)*radius,0.0,sin(around)*radius))
			lines.append(Vector3(cos(around)*sin(fan),-cos(fan),sin(around)*sin(fan)))
	var at:=Image.create(points.size(),1,false,Image.FORMAT_RGBF)
	var along:=Image.create(points.size(),1,false,Image.FORMAT_RGBF)
	for index in points.size():
		at.set_pixel(index,0,Color(points[index].x,points[index].y,points[index].z))
		along.set_pixel(index,0,Color(lines[index].x,lines[index].y,lines[index].z))
	return [ImageTexture.create_from_image(at),ImageTexture.create_from_image(along),points.size()]

## Old risers do not hold a steady head: a slow surge, a quicker shiver, and
## every few seconds a knock where the pressure drops out and comes back hard.
## One building, one supply, so every running rose shivers together. Picture
## only: the tap's own flow, fill and temperature are untouched.
static func pressure_at(seconds: float) -> float:
	var value:=0.87+0.08*sin(seconds*1.9)+0.05*sin(seconds*6.7+1.3)
	var knock:=fposmod(seconds,7.3)
	if knock<0.30:value*=0.40
	elif knock<0.80:value*=1.12
	if fposmod(seconds+2.9,11.9)<0.20:value*=0.58
	return clampf(value,0.3,1.1)

func _shake_pressure() -> void:
	var running:=false
	for source: Dictionary in _sources:running=running or source.spray.emitting
	if not running:return
	var wanted:=pressure_at(_clock)
	if is_equal_approx(wanted,_pressure):return
	_pressure=wanted
	_drop_process.initial_velocity_min=JET_SPEED.x*_pressure
	_drop_process.initial_velocity_max=JET_SPEED.y*_pressure
	for source: Dictionary in _sources:
		if source.spray.emitting:_feed(source)

## How many drops the cone and its children carry: the valves' supply, thinned
## when the pressure sags.
func _feed(source: Dictionary) -> void:
	var share:=clampf(float(source.get("supply",0.0))*lerpf(0.5,1.0,clampf(_pressure,0.0,1.0)),0.02,1.0)
	if is_equal_approx(source.spray.amount_ratio,share):return
	source.spray.amount_ratio=share
	source.splash.amount_ratio=share;source.mist.amount_ratio=share

## The crown of splashes rides the standing water in the vessel. The emitter
## is this owner's own picture of the spray; no fixture part is moved.
func _seat_splash(source: Dictionary,level: float) -> void:
	if not source.spray.emitting:return
	var tap: TapProp=source.tap
	var landing: float=(lerpf(tap._water_empty_y,tap._water_full_y,level)-tap._stream.position.y)/maxf(0.5,tap._stream.basis.y.y)+0.012
	var crown: GPUParticles3D=source.splash
	if not is_equal_approx(crown.position.y,landing):crown.set_position(Vector3(crown.position.x,landing,crown.position.z))

func _process(delta: float) -> void:
	if _stopped:return
	# Offscreen systems otherwise stop aging before their last droplets retire.
	# Only recently stopped emitters request these bounded final GPU steps.
	for index: int in _retiring:RenderingServer.particles_request_process(_sources[index].spray.get_base())
	_elapsed+=delta
	if _elapsed<PERIOD:return
	var step:=_elapsed;_elapsed=0.0
	for index: int in _retiring.duplicate():
		if RenderingServer.particles_is_inactive(_sources[index].spray.get_base()):
			_sources[index].spray.visible=false;_retiring.erase(index)
	_clock+=step
	_shake_pressure()
	for state: Dictionary in _rooms.values():state.target=0.0;state["warmest"]=0.0
	for source: Dictionary in _sources:
		var flow: Dictionary=source.tap.get_flow_state()
		var amount:=float(flow.flow)
		var warm:=clampf((float(flow.temperature)-0.15)/0.5,0.0,1.0)*amount
		var wet: Dictionary=_rooms[source.room]
		wet.target=maxf(float(wet.target),warm)
		var steaming:=warm>0.04
		if source.puffs.emitting!=steaming:source.puffs.emitting=steaming
		if steaming:
			var share:=clampf(warm,0.3,1.0)
			if not is_equal_approx(source.puffs.amount_ratio,share):source.puffs.amount_ratio=share
		# The plume stands over whichever fixture is running hottest.
		if warm>float(wet.warmest):
			wet.warmest=warm
			if wet.has("steam") and wet.source_at!=source.tap._stream.global_position:
				wet.source_at=source.tap._stream.global_position
				wet.material.set_shader_parameter("source_at",wet.source_at)
		_seat_splash(source,float(flow.water_level))
	var eye: Vector3=_world.player.camera.global_position
	for state: Dictionary in _rooms.values():
		state.humidity=move_toward(float(state.humidity),float(state.target),step*(WETTING_RATE if float(state.target)>float(state.humidity) else DRYING_RATE))
		if state.has("steam"):
			# The plume answers the water within a second or two; the room takes longer.
			state.plume=move_toward(float(state.plume),float(state.warmest),step*(0.55 if float(state.warmest)>float(state.plume) else 0.30))
			var visible_steam: bool=(float(state.humidity)>0.003 or float(state.plume)>0.01) and state.steam.global_position.distance_squared_to(eye)<144.0
			state.steam.visible=visible_steam
			var density: float=float(state.humidity)*STEAM_GAIN if visible_steam else 0.0
			if density!=float(state.density):
				state.material.set_shader_parameter("density_gain",density);state.density=density
			if visible_steam and float(state.humidity)!=float(state.shown_fill):
				state.material.set_shader_parameter("fill",float(state.humidity));state.shown_fill=float(state.humidity)
			if visible_steam and float(state.plume)!=float(state.shown_plume):
				state.material.set_shader_parameter("source_heat",float(state.plume));state.shown_plume=float(state.plume)
	var weather: Dictionary=_world.get_node("WeatherFX")._live_conditions
	var rain:=clampf(float(weather.get("rain_intensity",1.0 if weather.get("wet",false) else 0.0)),0.0,1.0)
	for surface: Dictionary in _surfaces:
		var humidity: float=float(_rooms[surface.room].humidity) if _rooms.has(surface.room) else 0.0
		surface.inside=move_toward(float(surface.inside),humidity,step*0.05)
		surface.outside=move_toward(float(surface.outside),rain if surface.exposed else 0.0,step*(0.12 if rain>float(surface.outside) else 0.02))
		var film: ShaderMaterial=surface.material
		if surface.mirror:
			var story:Vector2=surface.pane.get_meta("prologue_mirror_film",Vector2(-1,0))
			if story!=surface.get("last_story",Vector2.INF):
				film.set_shader_parameter("prologue_film",story);surface.last_story=story
		if float(surface.inside)!=float(surface.last_inside) or float(surface.outside)!=float(surface.last_outside):
			film.set_shader_parameter("inside_wet",0.0 if surface.mirror else float(surface.inside))
			film.set_shader_parameter("outside_wet",float(surface.inside) if surface.mirror else float(surface.outside))
			surface.last_inside=surface.inside;surface.last_outside=surface.outside
		var pane: MeshInstance3D=surface.pane
		if surface.mirror and float(pane.get_meta("v2_condensation",-1.0))!=float(surface.inside):pane.set_meta("v2_condensation",float(surface.inside))
		var wanted: Material=film if pane.global_position.distance_squared_to(eye)<144.0 else null
		if pane.material_overlay!=wanted:pane.material_overlay=wanted

func shutdown() -> void:
	if _stopped:return
	_stopped=true;set_process(false)
	for surface: Dictionary in _surfaces:
		if is_instance_valid(surface.pane):
			if surface.pane.material_overlay==surface.material:surface.pane.material_overlay=null
			if surface.mirror:
				surface.pane.remove_meta("v2_condensation")
				surface.pane.remove_meta("prologue_mirror_film")
	for index in _sources.size():
		var source: Dictionary=_sources[index]
		if is_instance_valid(source.tap) and source.tap.flow_changed.is_connected(_sync_spray.bind(index)):
			source.tap.flow_changed.disconnect(_sync_spray.bind(index))
		if is_instance_valid(source.legacy):source.legacy.show()
		if is_instance_valid(source.spray):source.spray.free()
		if is_instance_valid(source.puffs):source.puffs.free()
	for state: Dictionary in _rooms.values():
		if state.has("steam") and is_instance_valid(state.steam):state.steam.free()
	_sources.clear();_retiring.clear();_rooms.clear();_surfaces.clear();_mirror_surfaces.clear();_drop_mesh=null;_drop_process=null;_water=null
	_splash_mesh=null;_splash_process=null;_mist_mesh=null;_mist_process=null;_steam_mesh=null;_steam_process=null

func _exit_tree() -> void:shutdown()
