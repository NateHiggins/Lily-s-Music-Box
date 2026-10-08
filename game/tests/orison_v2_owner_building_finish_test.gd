extends "res://tests/orison_v2_owner_service_finish_test.gd"
## Retained construction validators share one world with the optical review.
const INSPECTORS := {
	"front_facade":preload("res://tests/orison_v2_front_facade_test.gd"),
	"roof_membrane":preload("res://tests/orison_v2_roof_membrane_test.gd"),
	"roof_ventilator":preload("res://tests/orison_v2_roof_ventilator_test.gd"),
	"city_tanks":preload("res://tests/orison_v2_city_tanks_test.gd"),
	"city_aerials":preload("res://tests/orison_v2_city_aerials_test.gd"),
	"lift_joinery":preload("res://tests/orison_v2_lift_joinery_test.gd"),
	"lift_gate":preload("res://tests/orison_v2_lift_gate_test.gd")}

var skyline_review_completed:=false

func _init() -> void:
	contract_key="owner_building_finish"
	contract_scope="Scoped facade, roof, skyline and lift optical deployment; original native triangles/charts/collisions/roof bearings, fan actuation, gate articulation, immutable source materials, mipmaps, matched day/night facade and powered/unpowered room observations, and owner retirement. Separate route module supplies passenger and entrance input proof. No save reconstruction or utility capacity claim."

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_owner_building_finish.json"))
	for path: String in fixture.bindings:
		check(FileAccess.get_file_as_string("res://"+path.trim_prefix("game/")).replace("\r\n","\n").sha256_text()==fixture.bindings[path],"reviewed finish/fitting input bound: "+path)
	var groups: Dictionary={};var maps: Dictionary={};var marked:=0
	for draw: Node in world.find_children("*","GeometryInstance3D",true,false):
		if not draw.has_meta("v2_building_finish"):continue
		var group:=str(draw.get_meta("v2_building_finish"));groups[group]=int(groups.get(group,0))+1
		var source:=draw.get_meta("v2_building_source") as StandardMaterial3D
		check(source!=null,"original opaque source retained: "+str(draw.name))
		if source==null:continue
		check([source.albedo_color,source.roughness,source.normal_scale,source.uv1_scale,source.albedo_texture,source.normal_texture,source.roughness_texture]==draw.get_meta("v2_building_source_state"),"shared source material stays immutable")
		var active: Material=draw.material_override
		check(active!=source and active.has_meta("v2_owner_finish"),"scoped finish is actually installed")
		var textures: Array=[]
		if active is ShaderMaterial:
			check(active.shader in [SurfacePass.OPAQUE,preload("res://shaders/orison_owner_component.gdshader")],"bounded opaque building shader")
			textures=[active.get_shader_parameter("albedo_tex"),active.get_shader_parameter("normal_tex"),active.get_shader_parameter("rough_tex")]
			var relief: Variant=active.get_shader_parameter("height_relief_mm")
			check(relief==null or is_zero_approx(float(relief)),"finish creates no displaced collision or false roof fall")
			if active.shader==preload("res://shaders/orison_owner_component.gdshader"):
				marked+=1
				check(active.get_shader_parameter("component_from_mesh") is Transform3D,"weather follows explicit component frame")
				check(bool(active.get_shader_parameter("component_bond_colors"))==source.vertex_color_use_as_albedo,"authored roof bond factor retained")
		else:
			check(active is StandardMaterial3D and not active.emission_enabled and active.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"numeric metal is opaque and nonemissive")
			textures=[active.albedo_texture,active.normal_texture,active.roughness_texture]
		for texture: Texture2D in textures:
			if texture!=null:maps[texture.resource_path]=texture
		if group=="lift" and str(draw.name) in ["CabJoinery","RearEnamel"]:
			check((active is ShaderMaterial and int(active.get_shader_parameter("uv_mode"))==0) or (active is StandardMaterial3D and not active.uv1_triplanar),"moving cab uses its native metre charts")
		retained.append(weakref(draw))
	for group in ["facade","roof","skyline","lift"]:check(int(groups.get(group,0))>0,"finish group deployed: "+group)
	check(marked>10,"source-local building wear actually deployed")
	for path: String in maps:check(maps[path].get_image().has_mipmaps(),"loaded building map has mip chain: "+path.get_file())
	var directory:=OS.get_environment("SHOT_DIR")
	var reports: Dictionary={}
	var names:=INSPECTORS.keys()
	var selection:=OS.get_environment("ORISON_BUILDING_INSPECTORS")
	if not selection.is_empty():names=Array(selection.split(","))
	for name: String in names:
		check(INSPECTORS.has(name),"registered detailed building inspector: "+name)
		if not INSPECTORS.has(name):continue
		var inspector: Node=INSPECTORS[name].new()
		inspector.set_meta("shared_world_validation",true);inspector.set_meta("capture_enabled",capture_enabled)
		add_child(inspector)
		var destination:=directory.path_join(name);DirAccess.make_dir_recursive_absolute(destination);OS.set_environment("SHOT_DIR",destination)
		var result: Dictionary=await inspector.validate_in_world(world)
		check(result.has_all(["checks","failures"]),"detailed inspector completed: "+name)
		if result.has("checks"):checks+=int(result.checks)
		for failure: String in inspector.failures:failures.append(name+": "+failure)
		reports[name]=result
		inspector.free()
	OS.set_environment("SHOT_DIR",directory)
	if capture_enabled:
		await _room_pairs(world)
		# Same practical world, campaign date and production sky director.
		world.campaign_clock.configure_date(1928,11,10,12*60)
		world.get_node("WakingAtmosphere").director._apply(12*60.)
		var facade: Node=INSPECTORS.front_facade.new();facade.set_meta("shared_world_validation",true);add_child(facade)
		var day:=directory.path_join("facade_day");DirAccess.make_dir_recursive_absolute(day);OS.set_environment("SHOT_DIR",day)
		var result: Dictionary=await facade.validate_in_world(world)
		checks+=int(result.get("checks",0))
		for failure: String in facade.failures:failures.append("day facade: "+failure)
		reports.facade_day=result;facade.free();OS.set_environment("SHOT_DIR",directory)
		await _city_capture(world,world.adapter.root.to_global(Vector3(-12.,19.24,-9.)),world.adapter.root.to_global(Vector3(-7.5,19.2,-7.4)),"roof_day","production daylight; existing camera station","roof")
		await _skyline_review(world)
		check(skyline_review_completed,"both corrected skyline observations completed")
		world.campaign_clock.configure_date(1928,11,10,20*60)
		world.get_node("WakingAtmosphere").director._apply(20*60.)
	validation_completed=true
	return {"checks":checks,"failures":failures,"finish_slots":groups,"local_weather_slots":marked,"loaded_maps":maps.size(),"inspectors":reports,"views":discovery.duplicate(true)}

func _room_pairs(world: OrisonV2RuntimeRoot) -> void:
	var switches:=world.get_node("V2RoomSwitches") as SwitchSystem
	for view: Dictionary in preload("res://tests/orison_v2_finish_calibration.gd").VIEWS.slice(0,4):
		var at: Vector3=world.adapter.root.to_global(view.feet);var target: Vector3=world.adapter.root.to_global(view.target)
		await _city_capture(world,at,target,str(view.id)+"_production","fixed production light and calm shared finishes",str(view.id))
		var closest: LightFixtureProp;var distance:=INF
		for actor: Node in world.find_children("*","Node3D",true,false):
			if actor is LightFixtureProp and absf(actor.global_position.y-target.y)<3. and actor.global_position.distance_squared_to(target)<distance:
				closest=actor;distance=actor.global_position.distance_squared_to(target)
		check(closest!=null,"room has an existing practical")
		if closest==null:continue
		var room:=""
		for identity: String in switches._room_fixtures:
			if str(closest.name) in switches._room_fixtures[identity]:room=identity;break
		check(not room.is_empty(),"practical resolves original room circuit")
		if room.is_empty():continue
		var before:=switches.room_snapshot(room);var off:=before.duplicate()
		for identity: String in off:off[identity]=false
		check(switches.restore_room(room,off),"existing switch owner turns room off")
		await _city_capture(world,at,target,str(view.id)+"_off","same camera; original room circuit off; carried service lamp remains",str(view.id))
		check(switches.restore_room(room,before) and switches.room_snapshot(room)==before,"original room circuit restored")

func _skyline_review(world: OrisonV2RuntimeRoot) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_tanks.json"))
	var city: Node3D=world.get_node("CityShells")
	var tanks: Node3D=city.get_node("RooftopTanks")
	var candidates: Array[Vector3]=[]
	for x: float in [-30.,-24.,-18.,-12.,-6.,0.,6.,12.,18.,24.,30.]:
		for z: float in [6.,9.,12.,16.,20.]:candidates.append(Vector3(x,.02,z))
	for scope: String in ["street","roof"]:
		var best:=INF;var chosen:=Vector3.INF;var target:=Vector3.INF;var identity:=""
		var stations: Array=candidates if scope=="street" else [world.adapter.root.to_global(Vector3(-14.,19.25,-7.5)),world.adapter.root.to_global(Vector3(14.,19.25,-7.5))]
		for at: Vector3 in stations:
			var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.5,1,[world.player.get_rid()]))
			if floor_hit.is_empty() or floor_hit.normal.y<.9:continue
			at=floor_hit.position+Vector3.UP*.02
			if not _city_clear_station(world,at):continue
			for row: Dictionary in fixture.tanks:
				var p: Array=row.center
				var aim:=city.to_global(Vector3(p[0],p[2],-p[1]))
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*world.player.STANDING_EYE,aim,1,[world.player.get_rid()]))
				if hit.is_empty() or not tanks.is_ancestor_of(hit.collider):continue
				var distance:=at.distance_squared_to(aim)
				if distance<best:best=distance;chosen=at;target=aim;identity=str(row.id)
		check(chosen.is_finite(),"clear supported "+scope+" station sees actual native tank")
		if not chosen.is_finite():continue
		await _city_capture(world,chosen,target,"skyline_"+scope+"_day","production daylight; floor/capsule and visible-tank ray verified",identity)
		discovery[-1]["target"]=[target.x,target.y,target.z]
		discovery[-1]["draws"]=RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	skyline_review_completed=true
