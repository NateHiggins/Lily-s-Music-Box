extends "res://tests/v2_bathroom_paper_review.gd"
## INERT combined installed geometry/material inspection and actual curtain input.
func _init() -> void:route_label="V2 BATHROOM FINISHING REVIEW"
func _route() -> void:
	if OS.get_environment("ORISON_BATH_FINISH_PROFILE")=="1":
		_moisture=world.bathroom_moisture
		if not _require(is_instance_valid(_moisture) and not _moisture._sources.is_empty(),"production moisture owner is available before inherited phase checks"):return
		await _profile_route()
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	for child: Node in player.carried_device.get_children():
		if child is CanvasLayer:child.hide()
	var inspector:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var metric:=preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var draws: Array=[];var meshes: Dictionary={};var materials: Dictionary={};var contacts: Array=[]
	var rooms:=0;var showers:=0
	for record: Dictionary in world.layout.spaces:
		if record.get("class","")!="wet" or record.get("open_shell",false):continue
		rooms+=1
		var room:=world.adapter.resolve(str(record.id)) as Node3D
		_require(room!=null,"wet room exists: "+str(record.id))
		if room==null:continue
		_require(room.get_node_or_null("HistoricMillwork")==null,"wet room floor joints replace wooden skirting: "+str(record.id))
		for label: String in ["BathroomTileWainscot","BathroomGroutJoints","BathroomTileEdging"]:
			var draw:=room.get_node_or_null(label) as MeshInstance3D
			if not _require(draw!=null,"installed architectural finish: "+str(record.id)+"/"+label):continue
			_require(draw.get_child_count()==0,"finish adds no collision or process owner")
			var key: String=str(record.id)+"/"+label
			meshes[key]=inspector._mesh(draw.mesh);materials[key]=inspector._material(draw.get_active_material(0));draws.append({"path":str(draw.get_path()),"mesh":key,"materials":[key],"records":draw.get_meta("finish_records")})
			metric._check_cap_mapping(draw.mesh,true)
	_require(rooms==19,"all nineteen existing wet rooms receive the finish pass")
	for source: Dictionary in world.bathroom_moisture._sources:
		var tap: TapProp=source.tap;showers+=1
		var model:=tap.get_node("StaticFixture").get_child(0) as Node3D
		var support: Node3D
		var visible:=0
		for node: Node3D in model.find_children("WallMount*","Node3D",true,false):
			if node is MeshInstance3D:continue
			if node.visible:visible+=1;support=node
		_require(visible==1,"exactly one measured native support set: "+str(tap.get_path()))
		if support==null:continue
		for at: Vector2 in [Vector2(-.34,2.02),Vector2(.34,2.02),Vector2(-.34,2.19),Vector2(.34,2.19),Vector2(-.095,.98),Vector2(.095,.98),Vector2(0,1.18),Vector2(0,1.65)]:
			var depth: float=tap.shower_wall_setback
			var ray:=PhysicsRayQueryParameters3D.create(tap.to_global(Vector3(at.x,at.y,depth-.03)),tap.to_global(Vector3(at.x,at.y,depth+.02)),1,[player.get_rid()])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
			var error:=INF if hit.is_empty() else absf(tap.to_local(hit.position).z-depth)
			_require(error<.002,"native shower plate has actual structural wall backing")
			contacts.append({"tap":str(tap.get_path()),"at":at,"wall_depth":depth,"error":error,"finish_inset":tap.shower_finish_inset})
		for branch: Node3D in [model,tap._curtain_closed,tap._curtain_gathered,tap._handles[0],tap._handles[1]]:
			for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
				if branch==model and not draw.is_visible_in_tree():continue
				var key:=str(draw.get_path());meshes[key]=inspector._mesh(draw.mesh);materials[key]=inspector._material(draw.get_active_material(0));draws.append({"path":key,"mesh":key,"materials":[key]})
	_require(showers==18,"all eighteen installed showers use fitted supports")
	_require(metric.failures.is_empty(),"imported architectural UV/normal/tangent checks: "+str(metric.failures))
	metric.free()
	for path: String in inspector.texture_rows:
		var row: Dictionary=inspector.texture_rows[path]
		var size:=maxi(int(row.width),int(row.height))
		var expected:=int(log(float(size))/log(2.0)+.000001)
		_require(bool(row.mips) and int(row.mip_levels)==expected,"loaded full finish mip chain: "+path)
	_tap=world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	player.global_position=_tap.to_global(Vector3(0,.02,-.9));player.velocity=Vector3.ZERO
	for frame in 3:await get_tree().physics_frame
	player.set_lamp_enabled(false)
	if _tap._curtain_hand.travel>.001:
		if not await _drag_part(_tap,_tap.to_global(Vector3(.34,1.18,.23)),0.0,"finishing_prepare_drawn"):return
	await _finish_shot("bathroom_finish_drawn",Vector3(1.0,2.4,-.8),Vector3(0,2.02,.1))
	await _finish_shot("shower_head_union",Vector3(.20,1.99,-.08),Vector3(0,1.883,.18))
	await _finish_shot("bathroom_wainscot",Vector3(1.5,1.6,-.75),Vector3(0,1.1,.2))
	await _finish_shot("tile_finishing_edges",Vector3(.95,2.42,-.35),Vector3(.38,1.72,.40))
	await _finish_shot("tile_cap_corner",Vector3(1.05,1.5,-.10),Vector3(.46,1.2192,.40))
	if await _drag_part(_tap,_tap.to_global(Vector3(0,1.18,-.32)),1.78,"finishing_curtain_open"):
		await _finish_shot("bathroom_finish_gathered",Vector3(.85,2.3,-.55),Vector3(.25,2.015,.23))
		await _drag_part(_tap,_tap.to_global(Vector3(.34,1.18,.23)),0.0,"finishing_curtain_close")
	var casings:=preload("res://tests/orison_v2_door_casings_test.gd").new()
	casings.set_meta("shared_world_validation",true);add_child(casings)
	await casings.inspect_world(world)
	for failure: String in casings.failures:_require(false,"casing: "+failure)
	_require(casings.batch_checks>1000 and casings.failures.is_empty(),"retained installed casing/contact checks: "+str(casings.batch_checks))
	casings.queue_free()
	FileAccess.open(output.path_join("finishes.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Combined actual-world geometry and curtain input diagnostic, no runtime_contract or human acceptance","rooms":rooms,"showers":showers,"contacts":contacts,"draws":draws,"meshes":meshes,"materials":materials,"textures":inspector.texture_rows,"failures":failures},"\t"))
	inspector.free()

func _finish_shot(label: String,at: Vector3,target: Vector3) -> void:
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=60.0;camera.attributes=player.camera.attributes;camera.cull_mask=player.camera.cull_mask
	camera.global_position=_tap.to_global(at);camera.look_at(_tap.to_global(target));camera.make_current()
	for frame in 12:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label+".png"))
	player.camera.make_current();camera.queue_free()
