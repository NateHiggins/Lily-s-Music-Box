extends "res://tests/orison_v2_owner_service_finish_test.gd"
## Native street visuals with retained original collision and actual player crossing.
class StreetWalker extends "res://tests/orison_v2_street_crossing_test.gd":
	func _ready() -> void: pass

func _init() -> void:
	contract_key="street_paving_details"
	contract_scope="Twenty installed native street detail groups, exact source records, metre UV/tangent checks, original collision owners and 223 surface bearings; supported player-height captures; original player-input street crossing and return; shared-world owner retirement. No save reconstruction or drainage/weather capacity."

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	var street: Node3D=world.exterior_cell.instance_node("STREET_ORISON_01")
	var model: Node3D=street.get_node("StreetPavingDetails")
	retained.append(weakref(model))
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_street_paving_details.json"))
	check(FileAccess.get_sha256("res://assets/props/street_paving_details.glb")==fixture.asset_sha256,"actual native detail export bound")
	for path: String in fixture.source_bindings:
		if path.begins_with("game/"):
			check(FileAccess.get_file_as_string(path.replace("game/","res://")).replace("\r\n","\n").sha256_text()==fixture.source_bindings[path],"original source dependency bound: "+path)
	var originals: Dictionary=model.get_meta("original_draws")
	check(originals.size()==20 and model.find_children("*","CollisionObject3D",true,false).is_empty(),"twenty visual groups add no replacement physics owners")
	var shapes := {}
	for shape: CollisionShape3D in street.find_children("*","CollisionShape3D",true,false):
		var identity:=str(shape.get_meta("authored_record_id",""))
		if not identity.is_empty():shapes[identity]=shape
	var parts:=0;var triangles:=0;var alpha_parts:=0
	for row: Dictionary in fixture.parts:
		var draw: MeshInstance3D=model.get_node(str(row.id))
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_cap_mapping(draw.mesh,true)
		var original: MeshInstance3D=originals[str(row.id)]
		check(not original.visible and original.mesh is BoxMesh,"original primitive retained but visually superseded: "+str(row.id))
		var source: Dictionary=row.source
		check(original.position.is_equal_approx(Vector3(source.position_m[0],source.position_m[1],source.position_m[2])) and original.mesh.size.is_equal_approx(Vector3(source.size_m[0],source.size_m[1],source.size_m[2])),"source pose and dimensions retained")
		if bool(source.collision):
			check(shapes.has(str(row.id)),"original passage floor shape remains")
			if shapes.has(str(row.id)):
				var shape: CollisionShape3D=shapes[str(row.id)]
				check(not shape.disabled and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(original.mesh.size),"original floor physics extents unchanged")
		var mat:=draw.material_override as StandardMaterial3D
		check(mat!=null and mat.albedo_texture!=null and mat.normal_texture!=null and mat.roughness_texture!=null and not mat.uv1_triplanar,"native metric charts use existing three-map finish")
		for tex: Texture2D in [mat.albedo_texture,mat.normal_texture,mat.roughness_texture]:check(tex.get_image().has_mipmaps(),"loaded street finish has mip chain")
		var finish: Dictionary=fixture.finishes[str(row.kind)]
		var base:=MatLib.get_mat(str(finish.catalog_key)) as StandardMaterial3D
		check(is_equal_approx(mat.normal_scale,float(finish.normal)) and is_equal_approx(mat.roughness,float(finish.roughness)) and mat.albedo_texture==base.albedo_texture and mat.normal_texture==base.normal_texture and mat.roughness_texture==base.roughness_texture,"deployed local recipe and immutable catalogue maps match native review")
		var bounds: AABB=draw.transform*draw.mesh.get_aabb()
		var expected: Array=row.bounds
		check(bounds.position.distance_to(Vector3(expected[0],expected[1],expected[2]))<.00003 and bounds.end.distance_to(Vector3(expected[3],expected[4],expected[5]))<.00003,"installed bounds match actual native stock")
		if str(row.kind)=="damp":
			alpha_parts+=1
			var colors: PackedColorArray=draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			var low:=1.;var high:=0.
			for color in colors:low=minf(low,color.a);high=maxf(high,color.a)
			check(low<.001 and high>.99 and mat.vertex_color_use_as_albedo and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"finite damp film retains soft vertex edge fade")
	check(parts==20 and triangles==int(fixture.triangles) and alpha_parts==3,"all native stock and wet variants installed")
	var support_samples:=0
	await get_tree().physics_frame
	for row: Dictionary in fixture.contacts:
		var p: Array=row.point;var at:=street.to_global(Vector3(p[0],p[1],p[2]))
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.04,at-Vector3.UP*.04,1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		var owner_ok:=false
		if not hit.is_empty():
			if str(row.owner)=="front_pavement":owner_ok=world.adapter.root.get_node("FrontPavement").is_ancestor_of(hit.collider)
			else:
				var shape_owner: Object=hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape))
				owner_ok=str(shape_owner.get_meta("authored_record_id",""))==str(row.owner)
		check(owner_ok and hit.position.distance_to(at)<.00003 and hit.normal.y>.99,"retained actual bearing: "+str(row.id)+" -> "+str(row.owner))
		support_samples+=1
	check(support_samples==223,"all native support samples retained")
	for guide: Node in get_tree().get_nodes_in_group("orison_v2_explicit_route_guide"):
		if street.is_ancestor_of(guide):check(not guide.visible,"original route-guide policy remains hidden")
	world.player.camera.make_current()
	if capture_enabled:
		for view: Array in [["street_paving",Vector3(3,.03,2),Vector3(9,.01,4)],
			["curb_joints",Vector3(6,.03,3.65),Vector3(9,.14,4.785)],
			["damp_edges",Vector3(6,.03,3.65),Vector3(9,.01,2.05)],
			["coping_end",Vector3(19,.03,3.7),Vector3(20.75,.14,4.785)],
			["passage_panels",Vector3(14,.03,17),Vector3(17,0,15.6)]]:
			var only:=OS.get_environment("ORISON_STREET_CAPTURE_IDS")
			if not only.is_empty() and not str(view[0]) in only.split(","):continue
			var feet:=street.to_global(view[1]);var clear:=_city_clear_station(world,feet)
			check(clear,"supported clear standing view: "+str(view[0]))
			if not clear:continue
			await _city_capture(world,feet,street.to_global(view[2]),str(view[0]),"street detail",str(model.name))
			model.hide()
			for original: MeshInstance3D in originals.values():original.show()
			await _settled_optics();await shot(str(view[0])+"_before")
			for original: MeshInstance3D in originals.values():original.hide()
			model.show()
	var walker:=StreetWalker.new();walker.world=world;walker.player=world.player;add_child(walker)
	world.player.set_physics_process(true);world.player.set_process_unhandled_input(true)
	world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	walker._prepare_player_start();await get_tree().physics_frame;await get_tree().physics_frame
	await walker._route()
	Input.action_release("move_forward")
	check(walker.failures.is_empty() and walker.trace.size()>=18,"original input/physics street crossing and return completes")
	for failure: String in walker.failures:failures.append("street route: "+failure)
	var trace:=walker.trace.duplicate(true);walker.free();world.player.set_physics_process(false)
	validation_completed=true
	return {"checks":checks,"failures":failures,"parts":parts,"triangles":triangles,"support_samples":support_samples,"route":trace,"captures":discovery}
