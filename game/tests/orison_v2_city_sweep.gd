extends "res://tests/orison_v2_roof_membrane_test.gd"
## Discovery only. Clear inspection stations do not prove routes or access.
var discovery: Array[Dictionary]=[]
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"composed city starts for source-owned inspection")
	if world.player==null or world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false)
	var vestibule: Dictionary=world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var r: Array=vestibule.rect
	world.player.global_position=world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,0.,(r[1]+r[3])*.5))
	await get_tree().physics_frame;await get_tree().physics_frame
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var passage: OrisonV2PassageRegion=world.passage_region
	for frame in 600:
		if passage.residency.state=="RESIDENT":break
		await get_tree().process_frame
	check(passage.residency.state=="RESIDENT","normal prefetch exposes the actual arcade geometry")
	var floor: Dictionary=passage.source_layout.floors.filter(func(row):return row.id=="F01")[0]
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/floor_01_cell_registry.json"))
	for identity: String in passage.CELLS:
		if identity=="passage":continue
		var cell: Dictionary=registry.cells.filter(func(row):return str(row.resource_path).get_file()==identity+".gltf")[0]
		var sources: Array[Dictionary]=[]
		for marker: Dictionary in floor.markers:
			if marker.id in cell.semantic_owners and str(marker.id).begins_with("SITE_SHOP_IN"):sources.append(marker)
		check(sources.size()>=2,"each original shop has authored interior stations: "+identity)
		for source: Dictionary in sources:
			var local:=GameBoot.b2g(source.pos);local.y=.03
			var target:=GameBoot.b2g(sources[-1].pos);target.y=.8
			if Vector2(local.x-target.x,local.z-target.z).length()<.25:target=GameBoot.b2g(sources[0].pos);target.y=.8
			await _city_inspect(world,passage,local,target,identity+"_"+str(source.id),"arcade shop",str(source.id))
	var bar_floor: float=floor.markers.filter(func(row):return row.id=="F01_BAR_WC_DOOR")[0].pos[2]
	for marker: Dictionary in floor.markers:
		if not str(marker.id).begins_with("F01_BAR_LT_") and marker.id!="F01_BAR_WC_SINK_01":continue
		var local:=GameBoot.b2g(marker.pos);local.y=bar_floor+.03
		var target:=GameBoot.b2g(floor.markers.filter(func(row):return row.id=="F01_BAR_POOL")[0].pos);target.y=bar_floor+.8
		if Vector2(local.x-target.x,local.z-target.z).length()<.25:target.x+=1.
		await _city_inspect(world,world.bar_region,local,target,"bar_"+str(marker.id),"bar",str(marker.id))
	# Floor-owned grid samples complement overhead markers obstructed by stock,
	# counters and the bar's separate raised lobby. They establish no access.
	for record: Dictionary in floor.furniture:
		if not str(record.id).ends_with("_floor"):continue
		var identity: String=str(record.get("batch",""))
		if identity=="shop_otis___son":identity="shop_otis_son"
		var frame: Node3D=passage if identity in passage.CELLS and identity!="passage" else null
		if str(record.id).begins_with("retail_bar_"):frame=world.bar_region
		if frame==null:continue
		var rect: Array=record.rect
		var height: float=float(record.z0)+float(record.h)
		var candidates: Array[Vector3]=[]
		for u in [.16,.33,.5,.67,.84]:
			for v in [.16,.33,.5,.67,.84]:
				var point:=GameBoot.b2g([lerpf(rect[0],rect[2],u),lerpf(rect[1],rect[3],v),height+.03])
				if _city_clear_station(world,frame.to_global(point)):candidates.append(point)
		if candidates.is_empty():
			discovery.append({"id":record.id,"owner":record.id,"bucket":"floor survey","status":"no_clear_sampled_station_requires_review"});continue
		var first: Vector3=candidates[0];var last:=first
		for point: Vector3 in candidates:
			if point.distance_squared_to(first)>last.distance_squared_to(first):last=point
		var center:=GameBoot.b2g([(rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,height+.8])
		var station:=0
		for point: Vector3 in [first,last]:
			var target:=center
			if Vector2(point.x-target.x,point.z-target.z).length()<.25:target.z+=.7
			await _city_capture(world,frame.to_global(point),frame.to_global(target),str(record.id)+"_"+str(station),"floor survey",str(record.id));station+=1
	var route: Dictionary=world.exterior_cell.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	for index in route.nodes.size()-1:
		var node: Dictionary=route.nodes[index];var at: Vector3=node.placement.position
		var target: Vector3=route.nodes[index+1].placement.position
		await _city_capture(world,at,target+Vector3.UP*.8,"street_route_"+str(index),"street",str(node.id))
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(),"city discovery requires a screenshot directory")
	if directory.is_empty():world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var inventory: Node=load("res://tests/orison_v2_breeching_test.gd").new() as Node
	inventory._write_census(world);inventory.free()
	var file:=FileAccess.open(directory.path_join("city-discovery.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","interpretation":"Source-owned stationary discovery; geometry, textures and routes require review.","stations":discovery,"checks":checks,"failures":failures},"\t"))
	print("CITY SWEEP: stations=",discovery.size()," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _city_inspect(world: OrisonV2RuntimeRoot,frame: Node3D,local: Vector3,target: Vector3,label: String,bucket: String,owner: String) -> void:
	var found:=false
	for offset: Vector2 in [Vector2.ZERO,Vector2(.4,0),Vector2(-.4,0),Vector2(0,.4),Vector2(0,-.4),Vector2(.8,.4),Vector2(-.8,-.4)]:
		var at:=frame.to_global(local+Vector3(offset.x,0,offset.y))
		if not _city_clear_station(world,at):continue
		await _city_capture(world,at,frame.to_global(target),label,bucket,owner);found=true;break
	if found:return
	# Overhead light and stock anchors can stand inside a counter. Find the
	# nearest physically clear sample on the same authored shop/bar floor,
	# retaining the requested anchor and the alternative station's provenance.
	var layout: Dictionary=frame.source_layout
	var floor: Dictionary=layout.floors.filter(func(row):return row.id=="F01")[0]
	var closest:=Vector3.INF;var distance:=INF;var floor_owner: String=""
	for record: Dictionary in floor.furniture:
		if not str(record.id).ends_with("_floor"):continue
		var identity:=str(record.get("batch",""))
		if identity=="shop_otis___son":identity="shop_otis_son"
		var belongs:=label.begins_with(identity+"_SITE_SHOP_IN") and not identity.is_empty()
		if bucket=="bar":belongs=str(record.id).begins_with("retail_bar_")
		if not belongs:continue
		var rect: Array=record.rect
		for u in [.16,.33,.5,.67,.84]:
			for v in [.16,.33,.5,.67,.84]:
				var point:=GameBoot.b2g([lerpf(rect[0],rect[2],u),lerpf(rect[1],rect[3],v),float(record.z0)+float(record.h)+.03])
				if point.distance_squared_to(local)>=distance or not _city_clear_station(world,frame.to_global(point)):continue
				distance=point.distance_squared_to(local);closest=point;floor_owner=str(record.id)
	if closest.is_finite():
		await _city_capture(world,frame.to_global(closest),frame.to_global(target),label,bucket,owner)
		discovery[-1]["station_floor_owner"]=floor_owner
		discovery[-1]["requested_local_feet"]=[local.x,local.y,local.z]
		discovery[-1]["sampling"]="nearest clear grid point on the same authored floor family"
	else:discovery.append({"id":label,"bucket":bucket,"owner":owner,"status":"no_clear_sampled_station_requires_review"})

func _city_capture(world: OrisonV2RuntimeRoot,at: Vector3,target: Vector3,label: String,bucket: String,owner: String) -> void:
	world.player.global_position=at;world.player.velocity=Vector3.ZERO
	world.player.face_world_point(target);world.player.set_lamp_enabled(true)
	await _settled_optics();await shot(label)
	discovery.append({"id":label,"bucket":bucket,"owner":owner,"status":"captured_pending_visual_review","feet":[at.x,at.y,at.z],"image":label+".png"})

func _city_clear_station(world: OrisonV2RuntimeRoot,at: Vector3) -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*PlayerController.STANDING_HEIGHT*.5);query.exclude=[world.player.get_rid()]
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.1,at-Vector3.UP*.12,1,[world.player.get_rid()])
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y>.9
