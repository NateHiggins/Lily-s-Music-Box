extends "res://tests/orison_v2_roof_membrane_test.gd"
## Production joinery, retained owners, actual moving envelope and map checks.
var batch_mode := false
var capture_enabled := true
func _ready() -> void:
	if not batch_mode:call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"fitted frontage starts in actual production")
	if world.startup_failed:world.free();get_tree().quit(1);return
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var shop: Node3D=world.exterior_cell.instance_node("SHOP_BODEGA")
	var model: Node3D=shop.get_node("FittedFrontage")
	var leaf: DoorProp=world.exterior_cell.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	var infill: Node3D=model.get_meta("leaf_infill")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bodega_frontage.json"))
	for path: String in fixture.source_bindings:
		if path.begins_with("game/"):
			check(FileAccess.get_file_as_string(path.replace("game/","res://")).replace("\r\n","\n").sha256_text()==fixture.source_bindings[path],"fitted frontage binds actual source and original leaf builder")
	check(FileAccess.get_sha256("res://assets/props/bodega_frontage.glb")==fixture.asset_sha256,"installed geometry binds the native export")
	check(infill.get_parent()==leaf._body and infill.find_children("*","CollisionObject3D",true,false).is_empty(),"original hinged leaf carries the new panel with one physical owner")
	check(leaf.width==.95 and leaf.height==2.1 and not leaf.swing_out,"retained leaf dimensions and hand remain")
	var parts:=0;var triangles:=0;var contacts:=0
	var fixed_ids: Dictionary={}
	var bad_contacts:=0
	var extended_probes:=0;var longest_probe:=0.0
	for branch: Node3D in [model,infill]:
		for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			parts+=1;triangles+=draw.mesh.get_faces().size()/3
			_check_cap_mapping(draw.mesh,true)
			var key: String=draw.get_meta("material_key")
			if key=="glass":
				check(draw.material_override is ShaderMaterial and draw.material_override.shader==preload("res://shaders/lamp_glass_surface.gdshader"),"new upper lights use the retained clear dielectric")
			else:
				var mat:=draw.material_override as StandardMaterial3D
				check(mat!=null and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null and not mat.uv1_triplanar,"native timber receives three existing catalogue maps and metre charts")
				check(mat!=MatLib.get_mat("oak_quartered",Color(.42,.30,.20),.8),"fitted chart uses a local material duplicate")
			if branch==infill:continue
			var body: CollisionObject3D=draw.get_node("FittedCollision")
			fixed_ids[body.get_rid()]=true
			for surface in draw.mesh.get_surface_count():
				var arrays: Array=draw.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size(),3):
					var center: Vector3=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3.
					var normal: Vector3=normals[indices[i]]
					# Geometry3D's segment/triangle parallel test uses an absolute
					# determinant epsilon. Keep the start 3 mm outside this face,
					# but extend the inward end for the smallest contact cells.
					# The required owner and 50 micrometre hit tolerance stay fixed.
					var double_area: float=(vertices[indices[i+1]]-vertices[indices[i]]).cross(vertices[indices[i+2]]-vertices[indices[i]]).length()
					var depth: float=maxf(.003,.00002/double_area)
					if depth>.003:extended_probes+=1
					longest_probe=maxf(longest_probe,depth+.003)
					var query:=PhysicsRayQueryParameters3D.create(draw.to_global(center+normal*.003),draw.to_global(center-normal*depth),1,[world.player.get_rid()])
					var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.is_empty() or hit.collider!=body or hit.position.distance_to(draw.to_global(center))>=.00005:
						if bad_contacts<8:
							var a: Vector3=vertices[indices[i]];var b: Vector3=vertices[indices[i+1]];var c: Vector3=vertices[indices[i+2]]
							print("FRONTAGE CONTACT DIAGNOSTIC: draw=",draw.name," center=",shop.to_local(draw.to_global(center))," normal=",normal," winding_dot=",normal.dot((c-a).cross(b-a).normalized())," hit=",hit.get("collider")," distance=",hit.position.distance_to(draw.to_global(center)) if not hit.is_empty() else INF)
						bad_contacts+=1
					check(not hit.is_empty() and hit.collider==body and hit.position.distance_to(draw.to_global(center))<.00005,"actual exposed fitted face has its own matching triangle collision")
					contacts+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"actual imported counts bind the native inventory")
	check(MatLib.get_mat("oak_quartered",Color(.42,.30,.20),.8).uv1_triplanar,"shared catalogue projection remains unchanged")
	for point: Vector3 in [Vector3(-1.28,2.515,0),Vector3(1.28,2.515,0),Vector3(0,2.625,0)]:
		var query:=PhysicsRayQueryParameters3D.create(shop.to_global(point+Vector3.BACK*.2),shop.to_global(point-Vector3.BACK*.2),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and model.is_ancestor_of(hit.collider),"the actual formerly open frontage band is closed by this fitting")
	for identity: String in ["left_store_glass","right_store_glass","front_transom"]:
		var pane: MeshInstance3D=model.get_meta("authored_meshes")[identity]
		check(pane.mesh is BoxMesh and pane.material_override is ShaderMaterial,"original pane geometry and clear-glass ownership remain")
	var moving: CollisionShape3D=leaf._body.get_child(0)
	var exclusions: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not fixed_ids.has(body.get_rid()):exclusions.append(body.get_rid())
	var samples:=0
	for step in range(57):
		var angle:=deg_to_rad(float(step)*3.)
		var pose:=Transform3D(Basis(Vector3.UP,angle),Vector3(0,0,-leaf._hinge_offset))
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=moving.shape;query.margin=0.0
		query.transform=leaf.global_transform*pose*moving.transform;query.exclude=exclusions;query.collision_mask=1
		check(world.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty(),"actual original leaf box clears fitted frame throughout its 168 degree sweep")
		samples+=1
	for draw: MeshInstance3D in infill.find_children("*","MeshInstance3D",true,false):
		var box:=moving.shape as BoxShape3D
		for point: Vector3 in draw.mesh.get_faces():
			var in_leaf: Vector3=moving.transform.affine_inverse()*(infill.transform*draw.transform*point)
			check(absf(in_leaf.x)<box.size.x*.5 and absf(in_leaf.y)<box.size.y*.5 and absf(in_leaf.z)<box.size.z*.5,"actual raised infill stays inside the original moving physical leaf")
	var observations: Array[Dictionary]=[]
	for view: Array in [["front",Vector3(0,1.61,2.2),Vector3(0,1.7,0)],
		["left_band",Vector3(-1.2,1.61,.8),Vector3(-1.25,2.5,0)],
		["transom",Vector3(0,1.61,.8),Vector3(0,2.35,0)],
		["inside",Vector3(0,1.61,-1.5),Vector3(0,2.4,0)],
		["oblique",Vector3(-1.55,1.61,1),Vector3(.8,1.7,0)]]:
		if not capture_enabled:break
		world.player.global_position=shop.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(shop.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		var after:=_visible_counts()
		model.hide();infill.hide()
		var bars: Dictionary=model.get_meta("original_bars")
		var old_glass: Dictionary=model.get_meta("original_glass")
		var authored: Dictionary=model.get_meta("authored_meshes")
		for identity: String in bars:authored[identity].visible=bars[identity]
		for identity: String in old_glass:authored[identity].material_override=old_glass[identity]
		await _settled_optics();await shot(str(view[0])+"_before")
		var before:=_visible_counts()
		for identity: String in bars:authored[identity].hide()
		for identity: String in old_glass:authored[identity].material_override=world.adapter.root.architectural_materials.material_for("Glazing","public")
		model.show();infill.show()
		observations.append({"view":view[0],"before":before,"after":after,"note":"Same world/camera and retained lamps; fitted draw substitution and scoped clear-glass binding. No FPS or weather-capacity acceptance."})
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bodega-frontage-inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"contacts":contacts,"extended_probes":extended_probes,"longest_probe_m":longest_probe,"moving_samples":samples,"failures":failures,"observations":observations},"\t"))
	print("BODEGA FRONTAGE: checks=",checks," contacts=",contacts," moving_samples=",samples," parts=",parts," triangles=",triangles," extended_probes=",extended_probes," longest_probe=",longest_probe," failures=",failures.size())
	return {"checks":checks,"failures":failures}
