extends "res://tests/orison_v2_roof_membrane_test.gd"
## Source-preserving installation, mapping, support and presentation checks.
const FITTINGS := preload("res://scripts/building/orison_v2_bodega_fittings.gd")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var shop:=world.exterior_cell.instance_node("SHOP_BODEGA")
	var fitted:=shop.get_node("FittedRetailFabric")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bodega_fittings.json"))
	check(FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH).replace("\r\n","\n").sha256_text()==fixture.source_geometry_sha256_lf,"source exterior template bytes remain authoritative")
	check(FileAccess.get_sha256("res://assets/props/bodega_fittings.glb")==fixture.asset_sha256,"actual installed native binds its fixture")
	var stock: Array=world.exterior_cell._stock_visual_nodes["SHOP_BODEGA"]
	var stock_ids: Dictionary={}
	for draw: GeometryInstance3D in stock:stock_ids[str(draw.get_meta("authored_record_id"))]=true
	var triangles:=0;var partitions:=0
	for row: Dictionary in fixture.assemblies:
		var draw:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,str(row.id))
		var original: Dictionary=fitted.get_meta("retained")[str(row.id)]
		check(draw.transform==original.transform and draw.visible==original.visible and str(draw.get_meta("presentation_role"))==str(original.role),"retained transform, visibility and presentation owner: "+str(row.id))
		check(draw.mesh!=original.mesh and draw.mesh is ArrayMesh,"original semantic node receives native geometry: "+str(row.id))
		_check_cap_mapping(draw.mesh,true)
		for surface in draw.mesh.get_surface_count():
			var colours: PackedColorArray=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			check(not colours.is_empty(),"actual authored tint channel survives export: "+str(row.id))
			var mat:=draw.get_surface_override_material(surface) as StandardMaterial3D
			check(mat!=null and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null and not mat.uv1_triplanar and mat.vertex_color_use_as_albedo,"actual local metre chart, three catalogue maps and source tint: "+str(row.id))
			partitions+=1;triangles+=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
		if str(row.source.presentation_role)=="stock":check(stock_ids.has(str(row.id)),"native stock retains its original aggregate visibility owner: "+str(row.id))
		if str(row.id)=="aisle_a_goods_low":
			var coloured:=false
			for surface in draw.mesh.get_surface_count():
				for colour: Color in draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:coloured=coloured or (absf(colour.r-.58)<.004 and absf(colour.g-.23)<.004 and absf(colour.b-.16)<.004)
			check(coloured,"actual tin paper bands retain their warm source colour")
	check(stock_ids.size()==18,"all eighteen original aggregate stock nodes remain")
	var lettering: Label3D
	for label: Label3D in shop.find_children("*","Label3D",true,false):
		if str(label.get_meta("authored_record_id",""))=="counter_lettering":lettering=label
	check(lettering!=null and not lettering.double_sided,"original counter lettering has one readable face")
	if lettering!=null:
		var panel:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,"counter_upper_rail")
		var bounds: AABB=panel.transform*panel.mesh.get_aabb()
		var contact:=_mesh_distance(panel.transform*panel.mesh.get_faces(),lettering.position,Vector3.FORWARD)
		check(is_finite(contact) and absf(contact-.0015)<.0001,"actual display rail supports the original words")
		var measured:=lettering.font.get_string_size(lettering.text,HORIZONTAL_ALIGNMENT_CENTER,-1,lettering.font_size)*lettering.pixel_size
		check(measured.x<=bounds.size.x-.099 and measured.y<=bounds.size.y*.7+.0001 and lettering.position.y-measured.y*.5>=bounds.position.y and lettering.position.y+measured.y*.5<=bounds.end.y,"physical text fits the actual display rail")
	for adjustment: Dictionary in fixture.adaptations:
		var identity:=str(adjustment.id)
		var draw:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,identity)
		var bounds: AABB=draw.transform*draw.mesh.get_aabb()
		var base:=float(adjustment.fitted_base_y)
		check(absf(bounds.position.y-base)<.00001,"installed stock base fits its support: "+identity)
		var support_id: String
		if identity.begins_with("aisle_"):
			support_id="aisle_"+("1" if identity.begins_with("aisle_a") else "2")+"_shelf_"+("low" if identity.ends_with("low") else "middle")
		elif identity.begins_with("stock_aisle_"):support_id="aisle_"+identity.split("_")[2]+"_shelf_high"
		elif identity.begins_with("stock_left_window"):support_id="left_bulkhead"
		elif identity.begins_with("stock_right_window"):support_id="right_bulkhead"
		else:support_id="counter_case"
		var support:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,support_id)
		var faces: PackedVector3Array=support.transform*preload("res://scripts/building/orison_v2_native_faces.gd").read(support.mesh)
		var at:=bounds.get_center();at.y=base+.001
		check(absf(_mesh_distance(faces,at,Vector3.DOWN)-.001)<.00002,"actual imported shelf, case or sill meets the stock: "+identity)
	# Receiving and power have already fitted the structural collision, including
	# the original source-owned conduit opening. Compare that actual fabric.
	var original_shapes: Array=fitted.get_meta("retained_collision")
	check(original_shapes.size()==shop.get_node("Collision").get_child_count(),"finished shop collision inventory remains exact")
	for original: Dictionary in original_shapes:
		var shape: CollisionShape3D=original.node
		check(shape.get_parent()==shop.get_node("Collision") and shape.shape is BoxShape3D and shape.shape.size==original.size and shape.transform==original.transform and shape.disabled==original.disabled,"retained physical collision owner: "+str(shape.get_meta("authored_record_id")))
	for view: Array in [["aisles",Vector3(0,0,-3.6),Vector3(0,1,-6)],["stock",Vector3(-.12,0,-5),Vector3(-.75,1.15,-5.8)],["counter",Vector3(.2,0,-1),Vector3(-1.25,.63,-1.8)],["cooler",Vector3(.3,0,-7),Vector3(1.25,1,-8.1)],["window_stock",Vector3(0,0,-1.8),Vector3(-1.3,1.02,-.33)],["delivery",Vector3(.5,0,-8.7),Vector3(-.75,.7,-9.4)]]:
		world.player.global_position=shop.to_global(view[1]+Vector3.UP*.02);world.player.face_world_point(shop.to_global(view[2]));world.player.set_lamp_enabled(true)
		await get_tree().create_timer(2).timeout;await shot(view[0])
	# Controlled residents produce real ScheduleDirector facts. The original
	# registry consumes them and the existing presentation callback hides stock.
	var registry:=world.exterior_cell.shop_bucket_registry as OrisonV2ShopBucketRegistry
	var state:=registry.snapshot("SHOP_BODEGA");var cursor:=float(state.last_advanced_minute);var until:=cursor+2
	var clock:=CampaignClock.new();clock.configure_date(1928,11,10,20*60)
	var start:=1200+ceili(cursor)+1
	var schedules:=ScheduleDirector.new();add_child(schedules);schedules.setup(null,{})
	var residents: Dictionary={}
	for index in int(state.stock):residents["fittings_visitor_"+str(index)]={"blocks":[{"start_min":start,"end_min":start+1,"place":"bodega","activity":"errand"}]}
	schedules.data={"residents":residents}
	var packet:=schedules.place_activity_facts("bodega",cursor,until,clock)
	check(registry.advance_batch({"SHOP_BODEGA":packet}) and int(registry.snapshot("SHOP_BODEGA").stock)==0,"real registry consumes controlled authored visits")
	check(bool(world.exterior_cell.refresh_shop_presentation().ok),"original callback refreshes stock presentation")
	for draw: GeometryInstance3D in stock:check(not draw.visible,"aggregate depletion hides all native surfaces in the original node")
	world.player.global_position=shop.to_global(Vector3(0,.02,-3.6));world.player.face_world_point(shop.to_global(Vector3(0,.8,-6)))
	await get_tree().create_timer(1).timeout;await shot("empty_racks")
	schedules.free()
	for failure: String in failures:print("BODEGA FITTINGS FAIL: ",failure)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","assemblies":fixture.assemblies.size(),"stocks":fixture.stocks.size(),"triangles":triangles,"partitions":partitions,"stock_nodes":stock_ids.size(),"checks":checks,"failures":failures},"\t"))
	print("BODEGA FITTINGS: assemblies=",fixture.assemblies.size()," partitions=",partitions," triangles=",triangles," checks=",checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
