extends Node
## Transient optics only. Existing tap/boiler/weather owners supply every input.
const FILM := preload("res://shaders/v2_glass_film.gdshader")
const STEAM := preload("res://shaders/v2_bath_steam.gdshader")
const PERIOD := 0.1
var _world: Node3D
var _sources: Array=[]
var _rooms: Dictionary={}
var _surfaces: Array=[]
var _retiring: Array[int]=[]
var _elapsed:=0.0
var _stopped:=false
var exposure_ready:=false
var _drop_mesh: SphereMesh
var _drop_process: ParticleProcessMaterial
var _water: StandardMaterial3D

func configure(world: Node3D) -> bool:
	_world=world
	_water=MatLib.get_mat("water_clear").duplicate() as StandardMaterial3D
	_water.uv1_triplanar=false;_water.normal_enabled=true;_water.normal_scale=0.1
	_water.albedo_color=Color(0.72,0.86,0.94,0.58);_water.roughness=0.12
	_water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.emission_enabled=true;_water.emission=Color(0.85,0.92,1.0);_water.emission_energy_multiplier=0.3
	_water.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_drop_mesh=SphereMesh.new();_drop_mesh.radius=0.003;_drop_mesh.height=0.035
	_drop_mesh.radial_segments=6;_drop_mesh.rings=2;_drop_mesh.material=_water
	_drop_process=ParticleProcessMaterial.new();_drop_process.direction=Vector3.DOWN
	_drop_process.spread=10.0;_drop_process.gravity=Vector3.DOWN*3.0
	_drop_process.initial_velocity_min=4.0;_drop_process.initial_velocity_max=4.5
	_drop_process.particle_flag_align_y=true
	_drop_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_drop_process.emission_sphere_radius=0.025
	for record: Dictionary in world.layout.spaces:
		if str(record.get("class",""))!="wet": continue
		_rooms[str(record.id)]={"humidity":0.0,"target":0.0,"record":record}
	for node: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if node is not TapProp or node.fixture!="shower":continue
		var room: String=world.room_at_world(node.global_position+Vector3.UP*0.3)
		if not _rooms.has(room):push_error("Shower has no wet-room moisture binding: "+str(node.get_path()));return false
		var spray:=GPUParticles3D.new();spray.name="ShowerSprayCone"
		spray.amount=128;spray.lifetime=0.38;spray.fixed_fps=30;spray.local_coords=true
		spray.emitting=false;spray.visible=false;spray.process_material=_drop_process
		spray.draw_pass_1=_drop_mesh;spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spray.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		spray.visibility_aabb=AABB(Vector3(-0.4,-1.85,-0.4),Vector3(0.8,1.95,0.8))
		var legacy: Node3D=node._stream.get_child(0);legacy.hide()
		node._stream.add_child(spray)
		var source: Dictionary={"tap":node,"room":room,"spray":spray,"legacy":legacy}
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
	state["steam"]=volume;state["material"]=material;state["density"]=-1.0

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
	_surfaces.append({"pane":pane,"room":room,"material":film,"mirror":mirror,"exposed":exposed,"inside":0.0,"outside":0.0,"last_inside":-1.0,"last_outside":-1.0})
	return true

func _sync_spray(index: int) -> void:
	if _stopped:return
	var source: Dictionary=_sources[index]
	var amount: float=float(source.tap.get_flow_state().flow)
	var emitting:=amount>0.0001
	if source.spray.emitting!=emitting:
		source.spray.emitting=emitting
		if not emitting and not _retiring.has(index):_retiring.append(index)
	if emitting:
		_retiring.erase(index)
		if source.spray.amount_ratio!=amount:source.spray.amount_ratio=amount
		source.spray.visible=true

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
	for state: Dictionary in _rooms.values():state.target=0.0
	for source: Dictionary in _sources:
		var flow: Dictionary=source.tap.get_flow_state()
		var amount:=float(flow.flow)
		var warm:=clampf((float(flow.temperature)-0.15)/0.5,0.0,1.0)*amount
		_rooms[source.room].target=maxf(float(_rooms[source.room].target),warm)
	var eye: Vector3=_world.player.camera.global_position
	for state: Dictionary in _rooms.values():
		state.humidity=move_toward(float(state.humidity),float(state.target),step*(0.035 if float(state.target)>float(state.humidity) else 0.012))
		if state.has("steam"):
			var visible_steam: bool=float(state.humidity)>0.003 and state.steam.global_position.distance_squared_to(eye)<144.0
			state.steam.visible=visible_steam
			var density: float=float(state.humidity)*0.28 if visible_steam else 0.0
			if density!=float(state.density):
				state.material.set_shader_parameter("density_gain",density);state.density=density
	var weather: Dictionary=_world.get_node("WeatherFX")._live_conditions
	var rain:=clampf(float(weather.get("rain_intensity",1.0 if weather.get("wet",false) else 0.0)),0.0,1.0)
	for surface: Dictionary in _surfaces:
		var humidity: float=float(_rooms[surface.room].humidity) if _rooms.has(surface.room) else 0.0
		surface.inside=move_toward(float(surface.inside),humidity,step*0.05)
		surface.outside=move_toward(float(surface.outside),rain if surface.exposed else 0.0,step*(0.12 if rain>float(surface.outside) else 0.02))
		var film: ShaderMaterial=surface.material
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
			if surface.mirror:surface.pane.remove_meta("v2_condensation")
	for index in _sources.size():
		var source: Dictionary=_sources[index]
		if is_instance_valid(source.tap) and source.tap.flow_changed.is_connected(_sync_spray.bind(index)):
			source.tap.flow_changed.disconnect(_sync_spray.bind(index))
		if is_instance_valid(source.legacy):source.legacy.show()
		if is_instance_valid(source.spray):source.spray.free()
	for state: Dictionary in _rooms.values():
		if state.has("steam") and is_instance_valid(state.steam):state.steam.free()
	_sources.clear();_retiring.clear();_rooms.clear();_surfaces.clear();_drop_mesh=null;_drop_process=null;_water=null

func _exit_tree() -> void:shutdown()
