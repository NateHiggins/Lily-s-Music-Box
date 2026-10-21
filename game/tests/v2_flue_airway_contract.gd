extends "res://tests/v2_acoustic_ventilation_contract.gd"
## Reuse the actual world and original propagation proof for the physical repair.
const Inventory := preload("res://tests/orison_v2_surface_inventory.gd")

func _additional_scope() -> String:
	return "Also verifies the boiler chimney/roof airway and new native wall fitting. Five apartment thimbles and flue acoustic migration remain unproved."

func _additional_checks(world: OrisonV2RuntimeRoot) -> void:
	var root: Node3D=world.adapter.root
	var flue = root.get_node("BoilerFlue")
	var fitting := flue.get_node("FittedWallThimble") as Node3D
	_check(fitting!=null,"new native wall thimble is actually installed")
	var shaft: Dictionary={}
	for row: Dictionary in world.layout.risers:
		if row.id=="B1_BOILER_FLUE":shaft=row
	var rect: Array=shaft.rect
	var inlet: Vector3=flue.sections.back().to
	var center := Vector3((float(rect[0])+float(rect[2]))*.5,inlet.y,(float(rect[1])+float(rect[3]))*.5)
	var physical := world.get_world_3d().direct_space_state
	for x: float in [-.04,0.,.04]:
		for z: float in [-.08,0.,.08]:
			var a := center+Vector3(x,0,z);var b := a;b.y=float(shaft.to_y)+2.4
			var ray := PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(b),1,[world.player.get_rid()])
			var hit := physical.intersect_ray(ray)
			_check(hit.is_empty(),"continuous actual chimney and roof airway "+str(Vector2(x,z))+": "+str(hit.get("collider","clear"))+" at "+str(hit.get("position","none")))
	var excludes: Array[RID]=[world.player.get_rid()]
	for section: Dictionary in flue.sections:excludes.append(section.body.get_rid())
	for elbow: StaticBody3D in flue.elbows:excludes.append(elbow.get_rid())
	var a := center;a.x=float(rect[0])-.15
	var port := PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(center),1,excludes)
	_check(physical.intersect_ray(port).is_empty(),"breeching crosses the actual chimney wall instead of ending at a solid face")
	var inspector := Inventory.new()
	var draws := fitting.find_children("*","MeshInstance3D",true,false)
	_check(draws.size()==13,"cast sleeve and four complete anchor assemblies retained")
	for draw: MeshInstance3D in draws:
		_check(draw.mesh is ArrayMesh,"actual imported fitting mesh: "+str(draw.name))
		var mesh: Dictionary=inspector._mesh(draw.mesh)
		for row: Dictionary in mesh.surfaces:
			_check(not row.missing_uv and row.nonfinite_uv==0 and row.degenerate_uv_triangles==0,"valid loaded UVs: "+str(draw.name))
		var material := draw.material_override as StandardMaterial3D
		_check(material!=null and not material.uv1_triplanar and material.normal_enabled,"custom mapped normal surface: "+str(draw.name))
		if material!=null:inspector._material(material)
	for path: String in inspector.texture_rows:
		var row: Dictionary=inspector.texture_rows[path]
		var expected_levels := int(floor(log(float(maxi(int(row.width),int(row.height))))/log(2.)))
		_check(row.mips and int(row.mip_levels)==expected_levels,"complete actually loaded mip chain: "+path)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(directory)==OK,"create actual fitting review destination")
		var file := FileAccess.open(directory.path_join("flue_surface_fragment.json"),FileAccess.WRITE)
		_check(file!=null,"open fitting surface fragment")
		if file!=null:file.store_string(JSON.stringify({"scope":"New wall thimble only, not global surface qualification","textures":inspector.texture_rows,"parts":draws.size()},"\t"));file.flush()
		# A diagnostic camera fixture, not a walked approach. Move the actual
		# carrier as well as its camera so the existing voxel lamp lights the part.
		world.player.set_physics_process(false)
		var eye: Vector3=root.to_global(inlet+Vector3(-.85,-.4,-.35))
		world.player.global_position+=eye-world.player.camera.global_position
		world.player.camera.look_at(fitting.global_position)
		world.player.camera.make_current();world.player.set_lamp_enabled(true)
		_check(world.player.flashlight.light_projector==null,"review uses the existing carried light without the old projector")
		for frame in 12:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png(directory.path_join("wall_thimble.png"))==OK,"save actual installed fitting render")
	inspector.free()
	additional_contracts.flue_airway={"executed":true,"status":"PENDING","vertical_physics_rays":9,"wall_port_rays":1,"new_native_parts":draws.size(),"apartment_thimbles_proved":false}
