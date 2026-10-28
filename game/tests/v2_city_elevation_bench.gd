extends Node
## Imported production owner and support diagnostics, not whole-world acceptance.
var checks := 0
var failures: Array[String] = []
func _clock_tip(hand: Dictionary) -> Vector3:
	var draw: MeshInstance3D=hand.draw
	var pivot: Vector3=hand.pivot
	var normal: Vector3=hand.normal
	var result:=Vector3.ZERO
	var largest:=-1.0
	for vertex: Vector3 in draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var relative:=draw.transform*vertex-pivot
		relative-=normal*relative.dot(normal)
		if relative.length_squared()>largest:
			largest=relative.length_squared()
			result=relative
	return result.normalized()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY NATIVE BENCH: "+label)
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	for path: String in ["res://tests/v2_city_horizon_review.gd","res://tests/v2_city_elevation_review.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_city_closure_test.gd","res://tests/orison_v2_city_composition_test.gd"]:
		var source := load(path) as Script
		check(source!=null and source.can_instantiate(),"dependent city source parses: "+path)
	var city := Node3D.new()
	city.set_script(load("res://scripts/building/orison_v2_city_shells.gd"))
	add_child(city)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var shells: Dictionary={}
	var draws := 0
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		draws += 1
		var stock: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		if stock is StandardMaterial3D:
			check(not stock.uv1_triplanar,"authored charts: "+str(draw.name))
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				check(texture!=null and texture.get_image().has_mipmaps(),"loaded PBR/mips: "+str(draw.name))
		else: check(false,"unhandled city finish: "+str(draw.name))
		if draw.get_meta("retained_city_shell",false):
			var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
			shells[body.get_rid()]=str(draw.name)
			var shape := body.get_child(0) as CollisionShape3D
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"identical visible/collision stock: "+str(draw.name))
	var apron := (load("res://assets/props/city_ground_apron.glb") as PackedScene).instantiate() as Node3D
	var apron_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	var apron_parts := 0
	for draw: MeshInstance3D in apron.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		apron_parts+=1
	check(apron_parts==int(apron_data.export_check.primitives) and apron_parts>=4,"retained apron geometry roster")
	apron.free()
	check(metrics.failures.is_empty(),"imported UV/normal/tangent checks")
	metrics.free()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in city.find_children("*","CollisionObject3D",true,false):
		if not shells.has(body.get_rid()):exclude.append(body.get_rid())
	var contacts := 0
	for family: String in ["elevations","masts","aerials","tanks","beacons"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+family+".json"))
		check(FileAccess.get_sha256("res://assets/props/city_"+family+".glb")==data.asset_sha256,"installed source hash: "+family)
		if family not in ["masts","aerials","tanks"]:continue
		for contact: Dictionary in data.contacts:
			var n := Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
			for sample: Array in [contact.point]+contact.footprint:
				var p := city.to_global(Vector3(sample[0],sample[2],-sample[1]))
				var hit := city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+n*.03,p-n*.03,1,exclude))
				check(not hit.is_empty() and shells.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"real roof bearing: "+str(contact.id))
				contacts+=1
	check(contacts>=1205 and shells.size()==fixture.parts.size() and draws>600,"nonempty complete family inventory")
	var factory_studies: Array=fixture.get("architecture_checks",[])
	check(factory_studies.size()==1,"one explicit factory study, not a promotion of all height repairs")
	check(fixture.portals.size()==5,"two factory portals and three individual terrace entrances")
	var factory_portals:=0
	var terrace_portals:=0
	for portal: Dictionary in fixture.portals:
		check(str(portal.building) in ["site_far_e","site_nw2"],"portal belongs to an explicitly adapted building")
		if str(portal.building)=="site_far_e":factory_portals+=1
		else:terrace_portals+=1
		var source: Array=portal.point
		var normal: Vector3=[Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][int(portal.side)]
		var point:=city.to_global(Vector3(source[0],source[2],-source[1]))
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.1,point-normal*.4,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(point+normal*float(portal.front))<.0001
				and str(shells.get(hit.collider.get_rid(),"")).ends_with("__door_paint"),"raised portal leaf has real closed backing")
	check(factory_portals==2 and terrace_portals==3,"original factory portals and all three terrace entrances remain nonempty")
	var terrace_details: Array=fixture.townhouse_details
	check(terrace_details.size()==1,"one individual terrace study")
	for detail: Dictionary in terrace_details:
		check(str(detail.building)=="site_nw2" and int(detail.brackets)==12 and int(detail.storeys)==3 and int(detail.terraces)==3,"three houses retain their own four-bracket cornice groups")
		var p: Array=detail.probe
		var n: Array=detail.normal
		var point:=city.to_global(Vector3(p[0],p[2],-p[1]))
		var normal:=Vector3(n[0],n[2],-n[1])
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.1,point-normal*.4,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(point)<.0001 and hit.normal.dot(normal)>.99
				and str(shells.get(hit.collider.get_rid(),"")).ends_with("__"+str(detail.finish)),"real outward-facing terrace cornice, not a hidden or reversed facade")
	for study: Dictionary in factory_studies:
		check(str(study.building)=="site_far_e" and int(study.arch_windows)==300
				and int(study.tower_support_samples)==9 and int(study.clock_face_normals)==4
				and float(study.tower_top)>float(study.tower_seat)+7.,"nonempty native factory form controls")
		var foundation_exclude: Array[RID]=exclude.duplicate()
		for rid: RID in shells:
			var identity: String=shells[rid]
			if not identity.begins_with(str(study.building)+"__") or identity.split("__")[-1] not in ["roof_bitumen","bronze_sheet","concrete"]:
				foundation_exclude.append(rid)
		var bounds: Array=study.tower_rect
		for x: float in [.05,.5,.95]:
			for z: float in [.05,.5,.95]:
				var point:=city.to_global(Vector3(lerpf(bounds[0],bounds[2],x),float(study.tower_seat),-lerpf(bounds[1],bounds[3],z)))
				var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.03,point-Vector3.UP*.03,1,foundation_exclude))
				check(not hit.is_empty() and hit.position.distance_to(point)<.0001,"tower seats on actual roof stock, excluding its own underside")
	check(city._clock_hands.size()==8 and fixture.clock_hands.size()==8,"four physical clock faces retain eight independent hands")
	var clock:=CampaignClock.new()
	for minute: int in [0,180,735,0]:
		check(clock.configure_date(1928,11,10,minute) and city.refresh_clock_from_campaign(),"city clock reads authoritative civil time including reversal")
		for hand: Dictionary in city._clock_hands:
			var tip:=_clock_tip(hand)
			var normal: Vector3=hand.normal
			var right:=Vector3.UP.cross(normal)
			if minute==0:check(tip.dot(Vector3.UP)>.999,"both hands return to twelve after time reversal")
			elif minute==180:check(tip.dot(right if hand.period==720. else Vector3.UP)>.999,"three o'clock has a rightward hour hand and upright minute hand")
			elif hand.period==60.:check(tip.dot(right)>.999,"quarter past has a rightward minute hand on every face")
			check(hand.collision.global_transform.is_equal_approx(hand.draw.global_transform),"clock visual and physical stock remain aligned")
	check(clock.configure_date(1928,11,10,195),"live clock update uses the existing time owner")
	await get_tree().create_timer(.65).timeout
	check(is_equal_approx(city.displayed_minute,195.),"clock presentation polls changed campaign time without a manual refresh")
	get_tree().paused=true
	check(clock.configure_date(1928,11,10,240),"paused fixture changes time only through the authoritative owner")
	await get_tree().create_timer(.65).timeout
	check(is_equal_approx(city.displayed_minute,195.),"paused presentation holds its pose")
	get_tree().paused=false
	await get_tree().create_timer(.65).timeout
	check(is_equal_approx(city.displayed_minute,240.),"resumed presentation observes the latest campaign time")
	check(clock.configure_date(1928,11,10,0) and city.refresh_clock_from_campaign(),"live clock fixture returns to its initial civil time")
	var repaired := 0
	for building: Dictionary in fixture.buildings:
		if not building.has("previous_roof_height"):continue
		repaired+=1
		var floor_total := 0.
		for height: float in building.floor_heights:floor_total+=height
		check(is_equal_approx(floor_total,float(building.roof_height)),"explicit storeys span repaired body: "+str(building.id))
		var cap := 0.
		for record: Dictionary in fixture.original_records:
			if str(record.id).begins_with(str(building.id)+"_c"):cap=maxf(cap,float(record.z0)+float(record.h))
		var bounds: Array=building.original_roof_rect
		var found_roof := false
		for fraction: float in [.2,.5,.8]:
			var roof := city.to_global(Vector3(lerpf(bounds[0],bounds[2],fraction),cap,-lerpf(bounds[1],bounds[3],fraction)))
			var hit := city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(roof+Vector3.UP*.03,roof-Vector3.UP*.03,1,exclude))
			found_roof=found_roof or (not hit.is_empty() and str(shells.get(hit.collider.get_rid(),"")).begins_with(str(building.id)+"__"))
			var old := roof+Vector3.UP*(float(building.previous_roof_height)-float(building.roof_height))
			check(city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(old+Vector3.UP*.03,old-Vector3.UP*.03,1,exclude)).is_empty(),"old tower roof rejected: "+str(building.id))
		check(found_roof,"repaired roof physically present: "+str(building.id))
	check(repaired==8,"all eight height repairs receive real roof and old-height controls")
	if not OS.get_environment("SHOT_DIR").is_empty():
		check(DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))==OK,"capture directory available")
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(.24,.30,.38)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color(.65,.73,.85)
		environment.environment.ambient_light_energy=.7
		add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.light_energy=2.5;sun.rotation_degrees=Vector3(-35,-35,0);sun.shadow_enabled=true
		add_child(sun)
		var camera := Camera3D.new()
		add_child(camera);camera.make_current();camera.fov=45
		for building: Dictionary in fixture.buildings:
			if not building.has("previous_roof_height") and str(building.id)!="site_nw2":continue
			var top := 0.
			var boxes: Array[AABB]=[]
			for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
				draw.visible=str(draw.name).begins_with(str(building.id)+"__")
				if draw.visible:
					var box: AABB=draw.global_transform*draw.get_aabb()
					boxes.append(box)
					top=maxf(top,box.end.y-city.global_position.y)
			var bounds: Array=building.main_rect
			var target := Vector3((bounds[0]+bounds[2])*.5,top*.48,-(bounds[1]+bounds[3])*.5)
			var span := maxf(float(bounds[2]-bounds[0]),float(bounds[3]-bounds[1]))
			var toward_city := Vector3(-target.x,0.,-target.z).normalized()
			var tangent := Vector3(toward_city.z,0.,-toward_city.x)
			var offset := toward_city*span*1.35+tangent*span*.5+Vector3.UP*float(building.roof_height)*.35
			var viewport_size := get_viewport().get_visible_rect().size
			var safe := Rect2(viewport_size*.05,viewport_size*.9)
			var framed := false
			for attempt in 12:
				camera.global_position=city.to_global(target+offset*pow(1.2,attempt))
				camera.look_at(city.to_global(target))
				framed=true
				for box: AABB in boxes:
					for corner in 8:
						if not safe.has_point(camera.unproject_position(box.get_endpoint(corner))):framed=false
				if framed:break
			check(framed,"complete building and equipment fit the actual viewport: "+str(building.id))
			await get_tree().create_timer(.6).timeout
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(str(building.id)+".png"))==OK,"actual optical capture saved: "+str(building.id))
			if str(building.id)=="site_far_e":
				var study: Dictionary=factory_studies[0]
				var tower: Array=study.tower_rect
				var center:=Vector3((tower[0]+tower[2])*.5,float(study.tower_seat)+2.0,-(tower[1]+tower[3])*.5)
				camera.global_position=city.to_global(center+Vector3(-11,3,-11))
				camera.look_at(city.to_global(center))
				for minute: int in [0,180,735]:
					check(clock.configure_date(1928,11,10,minute) and city.refresh_clock_from_campaign(),"rendered tower pose reads the campaign owner")
					await get_tree().create_timer(.1).timeout
					await RenderingServer.frame_post_draw
					check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("factory_clock_%04d.png"%minute))==OK,"actual rendered clock pose saved")
				check(clock.configure_date(1928,11,10,0) and city.refresh_clock_from_campaign(),"clock returns from optical review time")
	city.free()
	await get_tree().process_frame
	print("CITY NATIVE BENCH: %d checks, %d roof samples, %d draws, %d failures" % [checks,contacts,draws,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
