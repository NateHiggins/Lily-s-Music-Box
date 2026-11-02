extends "res://tests/orison_v2_vertical_route_test.gd"
const Occlusion := preload("res://scripts/building/orison_v2_structural_occlusion.gd")

func _init() -> void: route_label="V2 STRUCTURAL OCCLUSION REVIEW"

func _ready() -> void:
	if OS.get_environment("ORISON_OCCLUSION_SCOPE")=="slab_fixture":call_deferred("_slab_fixture")
	else:super._ready()


func _route() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var solid:=world.get_node_or_null("V2StructuralOcclusion")
	var admitted:=0
	if solid==null:
		solid=Occlusion.new();world.add_child(solid)
		admitted=solid.setup(world._blockout)
	else: admitted=solid.sources.size()
	var views: Array[SubViewport]=[]
	var cameras: Array[Camera3D]=[]
	for i in 2:
		var view:=SubViewport.new();view.size=Vector2i(1280,720)
		view.world_3d=world.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		view.use_occlusion_culling=i==1;view.msaa_3d=get_viewport().msaa_3d
		add_child(view);views.append(view)
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
		var eye:=Camera3D.new();view.add_child(eye);eye.make_current();cameras.append(eye)
	var stations: Array=[
		["lobby",Vector3(1.925,1.43,-3.5),Vector3(1.925,1.43,-7.5)],
		["street",Vector3(0,1.43,-12.2),Vector3(0,1.43,-8.5)],
		["upper_landing",Vector3(3.975,11.01,-3.4),Vector3(1.925,11.01,-3.4)],
		["mina_room",Vector3(-8.5,4.61,0),Vector3(-13.4,4.3,.75)],
		["roof",Vector3(3.975,20.61,-3.4),Vector3(8,20.1,3)]]
	var records: Array=[]
	player.set_physics_process(false)
	for station: Array in stations:
		world.process_mode=Node.PROCESS_MODE_INHERIT
		player.global_position=world.adapter.root.to_global(station[1])-Vector3.UP*player.STANDING_EYE
		player.camera.global_position=world.adapter.root.to_global(station[1])
		player.camera.look_at(world.adapter.root.to_global(station[2]))
		for eye: Camera3D in cameras:
			eye.global_transform=player.camera.global_transform;eye.fov=player.camera.fov
		for i in 30: await RenderingServer.frame_post_draw
		world.process_mode=Node.PROCESS_MODE_DISABLED
		var rows: Array=[]
		for i in 60:
			await RenderingServer.frame_post_draw
			rows.append([RenderingServer.viewport_get_measured_render_time_cpu(views[0].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_cpu(views[1].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(views[0].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(views[1].get_viewport_rid())])
		for i in 2: views[i].get_texture().get_image().save_png(directory.path_join(str(station[0])+"_"+("candidate" if i else "reference")+".png"))
		records.append({"station":station[0],"eye":str(player.camera.global_transform),"cpu0_cpu1_gpu0_gpu1_ms":rows})
	world.process_mode=Node.PROCESS_MODE_INHERIT
	for view: SubViewport in views: view.free()
	FileAccess.open(directory.path_join("occlusion.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","admitted_walls":admitted,"rejected_walls":solid.rejected,"stations":records},"\t"))
	print("STRUCTURAL OCCLUSION: ",admitted," conservative walls; ",records.size()," paired views")

var _slab_checks := 0

func _slab_check(ok: bool, label: String) -> void:
	_slab_checks += 1
	if not ok:failures.append(label);push_error("SLAB FIXTURE: "+label)

func _fixture_material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = colour
	return result

func _split_slab(material: Material, with_bottom: bool) -> ArrayMesh:
	# Reproduce the existing floor/top+side and separately owned underside
	# surface arrangement without instantiating the production building.
	var box := BoxMesh.new();box.size=Vector3(6,.2,6)
	var original := box.surface_get_arrays(0)
	var normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	var result := ArrayMesh.new()
	for bottom in ([false,true] if with_bottom else [false]):
		var arrays: Array = original.duplicate(true)
		var selected := PackedInt32Array()
		for start in range(0,indices.size(),3):
			if (normals[indices[start]].y<-.9)!=bottom:continue
			for offset in 3:selected.append(indices[start+offset])
		arrays[Mesh.ARRAY_INDEX] = selected
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,material)
	return result

func _fixture_box(parent: Node3D, position: Vector3, colour: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new();var box := BoxMesh.new()
	box.size=Vector3(.4,.4,.4);result.mesh=box
	result.material_override=_fixture_material(colour)
	result.position=position;parent.add_child(result)
	return result

func _settle_fixture() -> void:
	for frame in 20:await RenderingServer.frame_post_draw

func _fixture_objects() -> int:
	return RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)

func _slab_fixture() -> void:
	RealityState.persistence_enabled=false
	get_viewport().use_taa=false
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var root := Node3D.new();add_child(root)
	var room := Node3D.new();room.set_meta("room_id","fixture");root.add_child(room)
	var floor := MeshInstance3D.new();floor.name="Floor"
	var material := _fixture_material(Color(.4,.4,.4))
	floor.mesh=_split_slab(material,true);room.add_child(floor)
	var body := StaticBody3D.new();floor.add_child(body)
	var collision := CollisionShape3D.new();collision.shape=BoxShape3D.new()
	collision.shape.size=Vector3(6,.2,6);body.add_child(collision)
	var foreground := _fixture_box(root,Vector3(0,.7,0),Color.GREEN)
	_fixture_box(root,Vector3(0,-.7,0),Color.GREEN)
	_fixture_box(root,Vector3(2,-.7,0),Color.RED)
	_slab_check(Occlusion._complete_solid(floor.mesh,collision.shape.size),"actual split surfaces close all six box faces")
	_slab_check(not Occlusion._complete_solid(_split_slab(material,false),collision.shape.size),"missing underside is refused")
	var ring := SurfaceTool.new();ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece: Array in [[Vector3(-2,0,0),Vector3(2,.2,6)],[Vector3(2,0,0),Vector3(2,.2,6)],[Vector3(0,0,-2),Vector3(2,.2,2)],[Vector3(0,0,2),Vector3(2,.2,2)]]:
		var box := BoxMesh.new();box.size=piece[1]
		ring.append_from(box,0,Transform3D(Basis.IDENTITY,piece[0]))
	var aperture := ring.commit()
	aperture.surface_set_material(0,material)
	_slab_check(not Occlusion._complete_solid(aperture,collision.shape.size),"actual central aperture cannot become a solid box")
	var translucent := material.duplicate() as StandardMaterial3D
	translucent.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	floor.material_override=translucent
	_slab_check(not Occlusion._opaque_slab(floor),"transparent stock is refused")
	floor.material_override=material;material.fixed_size=true
	_slab_check(not Occlusion._opaque_slab(floor),"vertex-scaled fixed-size stock is refused")
	material.fixed_size=false;floor.material_override=null
	var solid := Occlusion.new();add_child(solid);solid.setup(root)
	_slab_check(solid.slab_sources.size()==1 and floor.ignore_occlusion_culling,"closed source admitted with self-occlusion exemption")
	var camera := Camera3D.new();add_child(camera);camera.make_current()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.
	camera.environment=Environment.new()
	camera.environment.background_mode=Environment.BG_COLOR
	camera.environment.background_color=Color.BLACK
	var original_culling := get_viewport().use_occlusion_culling
	var views: Array=[]
	for above in [true,false]:
		var label := "above" if above else "below"
		camera.position=Vector3(0,5 if above else -5,0)
		camera.look_at(Vector3.ZERO,Vector3.FORWARD)
		get_viewport().use_occlusion_culling=false
		await _settle_fixture()
		var reference := get_viewport().get_texture().get_image()
		var reference_objects := _fixture_objects()
		reference.save_png(directory.path_join(label+"_reference.png"))
		get_viewport().use_occlusion_culling=true
		await _settle_fixture()
		var candidate := get_viewport().get_texture().get_image()
		var candidate_objects := _fixture_objects()
		candidate.save_png(directory.path_join(label+"_candidate.png"))
		_slab_check(reference.get_data()==candidate.get_data(),label+" optical image remains byte-identical")
		_slab_check(candidate_objects<reference_objects,label+" actually occludes hidden geometry")
		var center := candidate.get_pixel(candidate.get_width()/2,candidate.get_height()/2)
		_slab_check(center.g>.5 and center.r<.2,label+" visible foreground remains green")
		views.append({"side":label,"reference_objects":reference_objects,"candidate_objects":candidate_objects})
	solid.free()
	_slab_check(not floor.ignore_occlusion_culling,"retirement restores source culling flag")
	floor.mesh=aperture
	solid=Occlusion.new();add_child(solid);solid.setup(root)
	_slab_check(solid.slab_sources.is_empty(),"apertured scene receives no solid proxy")
	camera.position=Vector3(0,5,0);camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	await _settle_fixture()
	var hole := get_viewport().get_texture().get_image()
	hole.save_png(directory.path_join("aperture.png"))
	var center := hole.get_pixel(hole.get_width()/2,hole.get_height()/2)
	# Remove the foreground stock to test sight through the actual opening.
	foreground.visible=false
	await _settle_fixture()
	hole=get_viewport().get_texture().get_image()
	hole.save_png(directory.path_join("aperture_through.png"))
	center=hole.get_pixel(hole.get_width()/2,hole.get_height()/2)
	_slab_check(center.g>.5 and center.r<.2,"actual aperture reveals the lower green stock")
	get_viewport().use_occlusion_culling=original_culling
	solid.free();camera.free();root.free()
	var record := {"evidence_class":"INERT","scope":"Small rendered slab-closure/opacity/aperture/self-occlusion and retirement fixture; no production-world or performance acceptance.","checks":_slab_checks,"failures":failures,"views":views}
	FileAccess.open(directory.path_join("fixture_result.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	print("SLAB OCCLUSION FIXTURE: %s; %d checks; %d failures"%["PASS" if failures.is_empty() else "FAIL",_slab_checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
