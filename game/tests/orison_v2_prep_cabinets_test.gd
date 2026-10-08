extends "res://tests/orison_v2_city_sweep.gd"
## Native visuals under unchanged twelve cabinet mechanisms, in one world.
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
var batch_mode := true
var capture_enabled := true
var mounted_ids: Array[int] = []
var factory_id := 0
func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_prep_cabinets.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256,"native cabinet export matches construction")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_prep_factory")
	factory_id = factory.get_instance_id()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_furniture.json"))
	var records: Dictionary = {}
	for row: Dictionary in source.furniture:
		if row.kind == "prep_cabinet": records[str(row.id)] = row
	var anchors: Dictionary = {}
	var levels: Dictionary = {}
	for row: Dictionary in world.layout.anchors: anchors[str(row.id)] = row
	for row: Dictionary in world.layout.levels: levels[str(row.id)] = float(row.y)
	var actors: Array[Prep] = []
	var original: Dictionary = {}
	var meshes: Dictionary = {}
	var count := 0
	var triangles := 0
	var care: Node = world.get_node("Caretaking")
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var body := world.adapter.resolve(identity) as Prep
		check(body != null and body.get_script().resource_path == "res://scripts/building/orison_v2_prep_cabinet.gd","original cabinet script remains sole mechanism owner: "+identity)
		if body == null: continue
		actors.append(body); mounted_ids.append(body.get_instance_id())
		original[identity] = {"opened":body.opened,"track_clean":body.track_clean}
		var anchor: Dictionary = anchors[identity]
		var p: Array = anchor.position
		check(body.global_position.is_equal_approx(world.adapter.root.to_global(Vector3(p[0],float(p[1])+float(levels[str(anchor.level)]),p[2]))) and body.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))),"source cabinet pose retained")
		check(body.unit == identity.get_slice("_",0) and care.call("find_subject",body) == body,"household and care ownership retained")
		var slide := body.get_node("SlidingPanel") as AnimatableBody3D
		check(slide == body._slide and slide.sync_to_physics,"original synchronized sliding owner retained")
		mounted_ids.append(slide.get_instance_id())
		var shapes := body.find_children("*","CollisionShape3D",false,false)
		var expected: Array = records[identity].collision_boxes.duplicate(true)
		expected.append([[.006,.1,-.238],[.376,.85,-.22]])
		check(shapes.size() == expected.size(),"original fixed collision count retained")
		for bounds: Array in expected:
			var lo := Vector3(bounds[0][0],bounds[0][1],bounds[0][2])
			var hi := Vector3(bounds[1][0],bounds[1][1],bounds[1][2])
			var found := false
			for node: CollisionShape3D in shapes:
				if node.shape is BoxShape3D and node.position.is_equal_approx((lo+hi)*.5) and (node.shape as BoxShape3D).size.is_equal_approx(hi-lo): found=true
			check(found,"original fixed collision dimensions retained")
		var moving_shapes := slide.find_children("*","CollisionShape3D",false,false)
		var moving_collision := moving_shapes[0] as CollisionShape3D if moving_shapes.size()==1 else null
		check(moving_collision != null and moving_collision.shape is BoxShape3D and moving_collision.position.is_equal_approx(Vector3(-.191,.475,-.253)) and (moving_collision.shape as BoxShape3D).size.is_equal_approx(Vector3(.37,.75,.018)),"original moving collision retained")
		for part: Dictionary in fixture.runtime.assemblies[0].parts:
			var parent: Node3D = body if part.component=="Body" else slide
			var draw := parent.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.owner==null and draw.get_meta("native_prep_part","")==part.name,"native visual retains its proper existing motion owner")
			if draw == null: continue
			count+=1
			if actors.size()==1:
				meshes[str(part.name)]=draw.mesh.get_instance_id()
				_check_cap_mapping(draw.mesh,true)
				var spec: Dictionary = fixture.parts.filter(func(row): return row.name==part.name)[0]
				check(draw.mesh.get_faces().size()/3==int(spec.triangles),"exact native cabinet partition")
				triangles+=draw.mesh.get_faces().size()/3
				var mat := draw.mesh.surface_get_material(0) as StandardMaterial3D
				var library := MatLib.get_mat(str(part.catalog_key))
				check(mat!=library and mat.albedo_texture==library.albedo_texture and mat.normal_texture==library.normal_texture and mat.roughness_texture==library.roughness_texture,"local cabinet finish uses registered maps")
				check(not mat.uv1_triplanar and mat.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)) and is_equal_approx(mat.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(mat.roughness,float(part.finish.roughness)),"cabinet metre charts and local finish retained")
			else:check(draw.mesh.get_instance_id()==meshes[str(part.name)],"all twelve cabinets share immutable native partitions")
		for probe: Dictionary in fixture.contacts:
			var v: Array = probe.point
			var at := body.to_global(Vector3(v[0],v[1],v[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"original plinth meets actual floor")
		body.restore_open_state(false)
	check(actors.size()==12 and triangles==int(fixture.triangles),"all twelve mechanisms and native partitions accounted for")
	var accessories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/household_accessories.json"))
	for row: Dictionary in accessories.accessories:
		if row.kind!="toaster":continue
		var support := world.adapter.resolve(str(row.support)) as Prep
		var toaster := support.get_node(str(row.id)) as Node3D
		check(toaster.position.is_equal_approx(Vector3(0,.9,0)),"existing toaster keeps cabinet support height")
		for x in [-.105,.105]:
			for z in [-.045,.045]:
				var at := toaster.to_global(Vector3(x,0,z))
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1))
				check(not hit.is_empty() and hit.collider==support and hit.position.distance_to(at)<.00004,"existing toaster feet retain cabinet contact")
	if capture_enabled:await _captures(world,actors,"closed")
	for body: Prep in actors:
		var result: Dictionary = body.interact()
		check(result.action=="kitchen_cabinet" and result.unit==body.unit and result.open,"ordinary cabinet interaction opens existing mechanism")
	await get_tree().create_timer(.65).timeout
	var saved: Dictionary = world.household_state.snapshot()
	for body: Prep in actors:
		var identity := str(body.get_meta("v2_furniture_id"))
		check(body.opened and is_equal_approx(body._slide.position.x,Prep.TRAVEL) and saved.records[identity].value==true,"motion and original save owner agree on open state")
	if capture_enabled:await _captures(world,actors,"open")
	for body: Prep in actors:body.interact()
	await get_tree().create_timer(.65).timeout
	for body: Prep in actors:
		check(not body.opened and body._slide.position.is_zero_approx(),"ordinary interaction returns native leaf to closed position")
		var identity := str(body.get_meta("v2_furniture_id"))
		body.restore_open_state(bool(original[identity].opened))
		check(body.track_clean==bool(original[identity].track_clean),"geometry pass preserves maintenance condition")
	world.household_state.capture_now()
	return {"checks":checks,"actors":actors.size(),"parts":count,"unique_triangles":triangles,"failures":failures.duplicate()}

func _captures(world: OrisonV2RuntimeRoot,actors: Array[Prep],state: String) -> void:
	for body: Prep in actors:
		if body.unit not in ["2A","4B"]:continue
		var station := Vector3.INF
		for p in [Vector3(0,.02,-1.3),Vector3(.7,.02,-1.3),Vector3(-.7,.02,-1.3),Vector3(1.2,.02,0),Vector3(-1.2,.02,0)]:
			var feet := body.to_global(p)
			if _city_clear_station(world,feet):station=feet;break
		check(station.is_finite(),"clear standing preparation-cabinet view")
		if station.is_finite():await _city_capture(world,station,body.to_global(Vector3(0,.55,0)),body.unit+"_prep_"+state,"native preparation cabinet",str(body.get_meta("v2_furniture_id")))

func validate_after_teardown() -> Dictionary:
	for id: int in mounted_ids:check(not is_instance_id_valid(id),"original cabinet and slide retire with world")
	check(not is_instance_id_valid(factory_id),"native cabinet library retires with world")
	return {"checks":checks,"failures":failures.duplicate()}
