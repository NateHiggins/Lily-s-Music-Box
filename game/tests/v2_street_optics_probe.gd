extends Node
## INERT optical diagnosis. Controls alter only this disposable review world.
## No room, interaction, simulation, surface qualification or acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var externally_managed := false
var failures := 0

func _ready() -> void:
	if not externally_managed:_run.call_deferred()

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.make_dir_recursive_absolute(directory)!=OK:
		push_error("Street optics requires windowed capture and SHOT_DIR");get_tree().quit(1);return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,10,15,750)
	Selector.reset_for_tests("v2")
	world=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.startup_failed:push_error("Production world failed");get_tree().quit(1);return
	await run(world,self)
	world.shutdown_for_tests();remove_child(world);world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("STREET OPTICS DIAGNOSIS: completed; no acceptance grant")
	get_tree().quit(0 if failures==0 else 1)

func check(ok: bool,label: String) -> void:
	if not ok:failures+=1
	print("STREET FINISH CHECK: ",label," = ",ok)

func run(current: OrisonV2RuntimeRoot,suite: Node) -> void:
	world=current;directory=OS.get_environment("SHOT_DIR")
	var prior_camera := world.player.camera.global_transform
	var prior_physics := world.player.is_physics_processing()
	var prior_lamp := world.player.lamp_is_enabled()
	var metric := preload("res://tests/v2_street_uv_bench.gd").new()
	for mesh: ArrayMesh in world.exterior_cell._mesh_cache.values():
		suite.check(metric._metric(mesh),"exterior architectural box uses physical metre charts")
	metric.free()
	var shop := world.exterior_cell.instance_node("SHOP_BODEGA")
	var tiles := 0
	var geometry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH))
	for template: Dictionary in geometry.templates:
		if str(template.id)!="TEMPLATE_BODEGA_CELL_V1":continue
		for row: Dictionary in template.boxes:
			if str(row.material_id)!="cream_tile":continue
			tiles+=1
			var draw := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,str(row.id))
			var stock := draw.get_active_material(0) as StandardMaterial3D
			suite.check(stock!=null and stock.albedo_texture==MatLib.get_mat("bath_wall_tile").albedo_texture and not stock.uv1_triplanar,"retire cracked tile on actual bodega wall: "+str(row.id))
			if stock==null:continue
			for texture: Texture2D in [stock.albedo_texture,stock.normal_texture,stock.roughness_texture]:suite.check(texture.get_image().has_mipmaps(),"replacement tile loads mip chain")
	suite.check(tiles>0,"tile checks cover actual authored walls")
	var actors := world.find_children("*","Node3D",true,false).filter(func(n):return n is BodegaSignageProp)
	suite.check(actors.size()==1,"one original bodega sign authority")
	var sign: BodegaSignageProp=actors[0]
	suite.check(sign._cabinet_mats.size()==2,"both original cabinet emission owners remain separate from the valance")
	var frontage: Dictionary=world.adapter.root.get_meta("v2_native_signage").retained.FittedBodegaSignage
	var valance := (frontage.draws[0].node.get_ref() as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	suite.check(valance.emission_enabled and valance.emission_energy_multiplier>0 and valance.emission_energy_multiplier<=.2,"sign face keeps soft transmitted light below the former clipping range")
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	var deadline := Time.get_ticks_msec()+6000
	while world.player.flashlight.visible and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
	if world.player.flashlight.visible:suite.check(false,"carried light settles off before optical controls");return
	for canvas: CanvasLayer in world.find_children("*","CanvasLayer",true,false):canvas.hide()
	var camera := world.player.camera
	camera.global_position=Vector3(19.5,1.65,3.1)
	camera.look_at(Vector3(24,1.8,1));camera.make_current()
	await _shot("approach_original")
	var samples: Array=[]
	var selected: Dictionary={}
	var viewport_size := get_viewport().get_visible_rect().size
	for point: Vector2 in [Vector2(.10,.42),Vector2(.35,.42),Vector2(.55,.20)]:
		var hits := _visible_hits(camera.project_ray_origin(point*viewport_size),camera.project_ray_normal(point*viewport_size))
		if hits.is_empty():
			suite.check(false,"optical sample has triangle witness: "+str(point));return
		var rows: Array=[]
		for hit: Dictionary in hits.slice(0,8):
			var draw: MeshInstance3D=hit.draw
			var material := draw.get_active_material(hit.surface)
			rows.append({"node":str(world.get_path_to(draw)),"record":str(draw.get_meta("authored_record_id","")),"surface":hit.surface,"distance_m":hit.distance,"position":_v(hit.position),"material":_material(material)})
			if material is StandardMaterial3D:selected[material.get_instance_id()]=material
		samples.append({"pixel_fraction":[point.x,point.y],"hits":rows})
	var normals: Dictionary={};var emissions: Dictionary={}
	for identity: int in selected:
		var material: StandardMaterial3D=selected[identity]
		normals[identity]=material.normal_enabled
		material.normal_enabled=false
	await _shot("approach_selected_normals_off")
	for identity: int in selected:
		var material: StandardMaterial3D=selected[identity]
		material.normal_enabled=normals[identity]
		emissions[identity]=material.emission_enabled
		material.emission_enabled=false
	await _shot("approach_selected_emission_off")
	for identity: int in selected:(selected[identity] as StandardMaterial3D).emission_enabled=emissions[identity]
	var pane := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,"right_store_glass")
	var pane_visible := pane.visible
	pane.hide()
	await _shot("approach_right_glazing_hidden")
	pane.visible=pane_visible
	camera.global_position=sign.to_global(Vector3(0,-.95,4.5))
	camera.look_at(sign.to_global(Vector3(0,-.32,1.07)))
	await _shot("sign_front")
	var valance_emission := valance.emission_enabled
	valance.emission_enabled=false
	await _shot("sign_front_emission_off")
	valance.emission_enabled=valance_emission
	var lights: Array=[]
	for light: Light3D in world.find_children("*","Light3D",true,false):
		if light.global_position.distance_to(camera.global_position)<12:
			lights.append({"node":str(world.get_path_to(light)),"position":_v(light.global_position),"color":[light.light_color.r,light.light_color.g,light.light_color.b],"energy":light.light_energy,"visible":light.visible})
	var file := FileAccess.open(directory.path_join("street_optical_diagnosis.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Disposable production-selected world, frozen calendar matching the existing shed capture. Camera/hidden HUD and two optical controls are fixtures. No acceptance grant.","samples":samples,"nearby_lights":lights},"\t"));file.close()
	world.player.camera.global_transform=prior_camera
	world.player.set_physics_process(prior_physics)
	world.player.set_lamp_enabled(prior_lamp)

func _shot(label: String) -> void:
	for frame in 5:await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	if pixels.save_png(directory.path_join("street_"+label+".png"))!=OK:push_error("Could not save "+label)

func _visible_hits(origin: Vector3,direction: Vector3) -> Array:
	var hits: Array=[]
	for draw: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree() or draw.mesh==null:continue
		var inverse := draw.global_transform.affine_inverse()
		var local_origin := inverse*origin
		var local_direction := inverse.basis*direction
		if draw.mesh.get_aabb().intersects_ray(local_origin,local_direction)==null:continue
		for surface in draw.mesh.get_surface_count():
			if draw.mesh is ArrayMesh and (draw.mesh as ArrayMesh).surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
			var arrays := draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			var nearest := INF;var at := Vector3.ZERO
			for triangle in range(0,count,3):
				var a: int=indices[triangle] if not indices.is_empty() else triangle
				var b: int=indices[triangle+1] if not indices.is_empty() else triangle+1
				var c: int=indices[triangle+2] if not indices.is_empty() else triangle+2
				var hit: Variant=Geometry3D.ray_intersects_triangle(local_origin,local_direction,vertices[a],vertices[b],vertices[c])
				if hit==null:continue
				var point: Vector3=draw.global_transform*hit
				var distance := origin.distance_to(point)
				if distance<nearest:nearest=distance;at=point
			if is_finite(nearest):hits.append({"draw":draw,"surface":surface,"distance":nearest,"position":at})
	hits.sort_custom(func(a: Dictionary,b: Dictionary):return a.distance<b.distance)
	return hits

func _material(material: Material) -> Dictionary:
	if material==null:return {"type":"missing"}
	var row := {"type":material.get_class(),"name":material.resource_name}
	if material is StandardMaterial3D:
		row.merge({"albedo":[material.albedo_color.r,material.albedo_color.g,material.albedo_color.b],"normal_enabled":material.normal_enabled,"normal_scale":material.normal_scale,"roughness":material.roughness,"metallic":material.metallic,"emission_enabled":material.emission_enabled,"emission":[material.emission.r,material.emission.g,material.emission.b],"emission_energy":material.emission_energy_multiplier,"uv_scale":_v(material.uv1_scale),"vertex_color":material.vertex_color_use_as_albedo,"maps":{}})
		for key: String in ["albedo_texture","roughness_texture","normal_texture"]:
			var texture: Texture2D=material.get(key)
			row.maps[key]=texture.resource_path if texture!=null else ""
	elif material is ShaderMaterial:
		row.shader=material.shader.resource_path
	return row

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]
