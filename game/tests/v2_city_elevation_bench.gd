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
	if OS.get_environment("ORISON_CITY_TANK_LOD_CHECK")=="1":
		var tank_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_tanks.json"))
		var tank_counts: Dictionary={}
		for row: Dictionary in tank_fixture.parts:tank_counts[str(row.name)]=int(row.triangles)
		var tank_parts:=0
		for draw: MeshInstance3D in city.get_node("RooftopTanks").find_children("*","MeshInstance3D",true,false):
			var surface:=RenderingServer.mesh_get_surface(draw.mesh.get_rid(),0)
			check((surface.get("lods",[]) as Array).is_empty(),"retained tank has no destructive automatic tail: "+str(draw.name))
			check(tank_counts.has(str(draw.name)) and draw.mesh.surface_get_array_index_len(0)==int(tank_counts.get(str(draw.name),-1))*3,"retained tank LOD0 stock remains exact: "+str(draw.name))
			tank_parts+=1
		check(tank_parts==tank_counts.size() and tank_parts==166,"nonempty complete retained tank LOD inventory")
	fixture = preload("res://tests/v2_city_context_review.gd").placed_fixture(fixture)
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var body_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_elevations.json"))
	var lower_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations_lod1.json"))
	var lower_counts: Dictionary={}
	for part: Dictionary in lower_fixture.parts:lower_counts[str(part.name)]=int(part.triangles)
	var lower: Node3D=(load("res://assets/props/city_elevations_lod1.glb") as PackedScene).instantiate()
	var lower_seen:=0
	for part: MeshInstance3D in lower.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(part.mesh,true)
		check(lower_counts.has(str(part.name)) and part.mesh.surface_get_array_index_len(0)==int(lower_counts.get(str(part.name),-1))*3,"complete imported replacement body: "+str(part.name))
		lower_seen+=1
	check(lower_seen==lower_counts.size() and lower_seen==body_data.body_lod.parts.size() and lower_seen>0,"nonempty complete replacement roster")
	lower.free()
	var shells: Dictionary={}
	var draws := 0
	var body_parts:=0
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		draws += 1
		var stock: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		stock=stock.get_meta("v2_weather_source",stock)
		if draw.get_meta("v2_city_streets",false):
			var loaded:=draw.material_override as ShaderMaterial
			check(loaded!=null and loaded.get_meta("v2_weather_source",null)==stock and is_equal_approx(float(loaded.get_shader_parameter("weather_exposure")),1.),"street exterior weather adapter: "+str(draw.name))
		if stock is StandardMaterial3D:
			check(not stock.uv1_triplanar,"authored charts: "+str(draw.name))
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				check(texture!=null and texture.get_image().has_mipmaps(),"loaded PBR/mips: "+str(draw.name))
		else: check(false,"unhandled city finish: "+str(draw.name))
		if draw.get_meta("v2_city_body_lod",false):
			body_parts+=1
			var surface:=RenderingServer.mesh_get_surface(draw.mesh.get_rid(),0)
			var lods: Array=surface.get("lods",[])
			var reduces: bool=int(lower_counts[str(draw.name)])*3<draw.mesh.surface_get_array_index_len(0)
			check((lods.size()==1 and is_equal_approx(float(lods[0].edge_length),float(body_data.body_lod.error_m))) if reduces else lods.is_empty(),"authored body replacement without destructive automatic tail: "+str(draw.name))
		if draw.get_meta("retained_city_shell",false):
			var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
			shells[body.get_rid()]=str(draw.name)
			var shape := body.get_child(0) as CollisionShape3D
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"identical visible/collision stock: "+str(draw.name))
	check(body_parts==lower_counts.size(),"every declared replacement is installed")
	var apron := (load("res://assets/props/city_ground_apron.glb") as PackedScene).instantiate() as Node3D
	var apron_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	var apron_parts := 0
	for draw: MeshInstance3D in apron.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		apron_parts+=1
	check(apron_parts==int(apron_data.export_check.primitives) and apron_parts>=4,"retained apron geometry roster")
	apron.free()
	var frontage := preload("res://scripts/building/v2_street_end_details.gd").new()
	add_child(frontage)
	frontage.build_boundaries_only(frontage,true)
	var frontage_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_frontage.json"))
	var frontage_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_frontage.json"))
	check(FileAccess.get_sha256(str(frontage_data.asset))==frontage_fixture.asset_sha256,"native street barricade export is installed")
	var frontage_model := frontage.get_node("WestFrontageNative") as Node3D
	var frontage_draws := 0
	var frontage_bounds := AABB()
	for draw: MeshInstance3D in frontage_model.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		var bounds: AABB=draw.global_transform*draw.get_aabb()
		frontage_bounds=bounds if frontage_draws==0 else frontage_bounds.merge(bounds)
		frontage_draws+=1
		var stock := draw.material_override as StandardMaterial3D
		check(stock!=null and not stock.uv1_triplanar,"barricade consumes its authored metre charts")
		if stock!=null:
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				check(texture!=null and texture.get_image().has_mipmaps(),"barricade custom maps have loaded mip chains")
	var boundary := frontage.get_node("StreetEndConstructionBoundary/WestNorthWorks") as CollisionShape3D
	var boundary_box := boundary.shape as BoxShape3D
	var physical_bounds: AABB=boundary.global_transform*AABB(-boundary_box.size*.5,boundary_box.size)
	check(frontage_draws==2 and frontage_bounds.position.distance_to(physical_bounds.position)<.0001 and frontage_bounds.end.distance_to(physical_bounds.end)<.0001,"two native barricade draws fit the retained closed-boundary footprint and new physical height")
	frontage.free()
	check(metrics.failures.is_empty(),"imported UV/normal/tangent checks")
	metrics.free()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in city.find_children("*","CollisionObject3D",true,false):
		if not shells.has(body.get_rid()):exclude.append(body.get_rid())
	var contacts := 0
	for family: String in ["elevations","masts","aerials","tanks","beacons"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+family+".json"))
		data = preload("res://tests/v2_city_context_review.gd").placed_fixture(data)
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
	check(fixture.portals.size()==24,"twenty-three retained passive portals and west narrow-house leaf; east ground floor belongs to Bodega")
	var factory_portals:=0
	var terrace_portals:=0
	var court_portals:=0
	var commercial_portals: Dictionary={"site_nw1":0,"site_nw3":0,"site_nw4":0,"site_se3":0,"site_sw3":0,"site_far_nw":0,"site_ne1":0,"site_ne2":0,"site_ne3":0,"site_ne4":0,"site_nbr_w":0,"site_nbr_e":0}
	for portal: Dictionary in fixture.portals:
		check(str(portal.building) in ["site_far_e","site_nw2","site_far_se","site_far_w","site_far_n","site_far_sw","site_far_ne","site_far_s","site_nw1","site_nw3","site_nw4","site_se3","site_sw3","site_far_nw","site_ne1","site_ne2","site_ne3","site_ne4","site_nbr_w","site_nbr_e"],"portal belongs to an explicitly adapted building")
		if str(portal.building)=="site_far_e":factory_portals+=1
		elif str(portal.building)=="site_nw2":terrace_portals+=1
		elif commercial_portals.has(str(portal.building)):commercial_portals[str(portal.building)]+=1
		else:court_portals+=1
		var source: Array=portal.point
		var normal: Vector3=[Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][int(portal.side)]
		var point:=city.to_global(Vector3(source[0],source[2],-source[1]))
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.1,point-normal*.4,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(point+normal*float(portal.front))<.0001
				and str(shells.get(hit.collider.get_rid(),"")).ends_with("__door_paint"),"raised portal leaf has real closed backing")
	check(factory_portals==2 and terrace_portals==1 and court_portals==7,"original portals remain nonempty alongside seven passive apartment entries")
	for identity: String in commercial_portals:
		check(int(commercial_portals[identity])==(0 if identity=="site_nbr_e" else 3 if identity=="site_ne1" else 2 if identity=="site_sw3" else 1),"explicitly counted genuinely closed scenic leaves: "+identity)
	var commercial_panes: Dictionary={"site_nw1":0,"site_nw3":0,"site_nw4":0,"site_se3":0,"site_sw3":0,"site_far_nw":0,"site_ne1":0,"site_ne2":0,"site_ne3":0,"site_ne4":0,"site_nbr_w":0,"site_nbr_e":0}
	var paired_attic_control:=0
	for window: Dictionary in fixture.window_rows:
		var identity:=str(window.building)
		if not commercial_panes.has(identity):continue
		var a: Array=window.pane_sample
		var source_normal: Array=window.get("normal",[[0,-1,0],[1,0,0],[0,1,0],[-1,0,0]][int(window.side)])
		var normal: Vector3=city.global_basis*Vector3(source_normal[0],source_normal[2],-source_normal[1])
		var point:=city.to_global(Vector3(a[0],a[2],-a[1]))
		var expected:=point-normal*float(window.get("pane_depth_m",float(window.recess_m)+.044))
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.1,point-normal*.4,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(expected)<.0001 and str(shells.get(hit.collider.get_rid(),"")).ends_with("__mirror_aged"),"actual commercial pane remains behind its masonry and joinery: "+identity)
		commercial_panes[identity]+=1
		if identity=="site_nw4" and int(window.side)==0 and int(window.floor)==3:
			var c: Array=window.center
			var center:=city.to_global(Vector3(c[0],c[2],-c[1]))
			var solid:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.1,center-normal*.4,1,exclude))
			check(not solid.is_empty() and solid.position.distance_to(center-normal*.1)<.0001 and str(shells.get(solid.collider.get_rid(),"")).ends_with("__door_paint"),"paired attic center is a solid mullion, not a falsely clear pane")
			paired_attic_control+=1
	check(commercial_panes=={"site_nw1":21,"site_nw3":39,"site_nw4":19,"site_se3":28,"site_sw3":26,"site_far_nw":175,"site_ne1":57,"site_ne2":67,"site_ne3":19,"site_ne4":61,"site_nbr_w":16,"site_nbr_e":14} and paired_attic_control==1,"all542 studied panes and the obstructed center control execute; Bodega glazing remains separately owned")
	var court_details: Array=fixture.court_details
	check(court_details.size()==6,"six real open recesses across five court-building identities")
	var expected_courts: Dictionary={"site_far_se":"elm","site_far_w":"cambridge","site_far_n":"greystone","site_far_sw":"laburnum","site_far_ne":"towers"}
	for detail: Dictionary in court_details:
		check(expected_courts.has(str(detail.building)) and expected_courts.get(str(detail.building))==str(detail.style),"distinct court identity has an explicit source owner")
		check(int(detail.entry_count)==(2 if str(detail.style)=="laburnum" else 1) and float(detail.recess_depth_m)>=.9,"declared supported entry count and a real open recess")
		var probe: Array=detail.void_probe
		var start:=city.to_global(Vector3(probe[0],probe[2],-probe[1]))
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*(float(detail.roof_height)+1.),1,exclude))
		check(not hit.is_empty() and hit.position.y<=city.global_position.y+float(detail.porch_top)+.001,"court is genuinely sky-open above the porch, no hidden roof slab")
	var roofs: Array=fixture.roof_details
	check(roofs.size()==14,"two original roof families and twelve distinct commercial/apartment adaptations")
	var roof_owners: Dictionary={}
	var original_roofs:=0
	var commercial_roofs: Dictionary={"site_nw1":"germania","site_nw3":"robbins","site_nw4":"scheffel","site_se3":"ottendorfer","site_sw3":"engine258","site_far_nw":"hampton","site_ne1":"faber","site_ne2":"fulton","site_ne3":"terracotta_works","site_ne4":"jamaica","site_nbr_w":"linford119","site_nbr_e":"hayden113"}
	var found_commercial: Dictionary={}
	for roof: Dictionary in roofs:
		roof_owners[str(roof.building)]=true
		if str(roof.style)=="towers":
			original_roofs+=1
			check(str(roof.building)=="site_far_ne" and str(roof.finish)=="city_roof_clay" and int(roof.arches)==12,"tiled belvedere keeps twelve real arch openings")
			var r: Array=roof.rect
			var elevation: float=float(roof.base)+1.30
			var frames: Array=[
				[Vector3(r[2],r[1],elevation),Vector3.LEFT,Vector3(0,-1,0),float(r[2])-float(r[0])],
				[Vector3(r[2],r[3],elevation),Vector3(0,-1,0),Vector3.RIGHT,float(r[3])-float(r[1])],
				[Vector3(r[0],r[3],elevation),Vector3.RIGHT,Vector3(0,1,0),float(r[2])-float(r[0])],
				[Vector3(r[0],r[1],elevation),Vector3(0,1,0),Vector3.LEFT,float(r[3])-float(r[1])]]
			var openings:=0
			for frame: Array in frames:
				for i in range(3):
					var source_normal: Vector3=frame[2]
					var normal:=city.global_basis*Vector3(source_normal.x,source_normal.z,-source_normal.y)
					for is_open: bool in [true,false]:
						var along: float=(float(i)+.5)*float(frame[3])/3. if is_open else float(i)*float(frame[3])/3.+.10
						var source_point: Vector3=frame[0]+frame[1]*along
						var point:=city.to_global(Vector3(source_point.x,source_point.z,-source_point.y))
						var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.10,point-normal*.65,1,exclude))
						if is_open:check(hit.is_empty(),"belvedere arch is physically open beyond its front face")
						else:check(not hit.is_empty() and hit.position.distance_to(point)<.0001 and hit.normal.dot(normal)>.99,"adjacent belvedere jamb remains solid and outward-facing")
					openings+=1
			check(openings==12,"open-arch probes have twelve actual solid-jamb controls")
		elif str(roof.style)=="chateau":
			original_roofs+=1
			check(str(roof.building)=="site_far_s" and str(roof.finish)=="city_slate" and int(roof.dormers)==4 and float(roof.knee_height)>float(roof.mansard_base)+2.,"slate mansard keeps its steep lower pitch and four dormers")
		elif commercial_roofs.has(str(roof.building)):
			check(commercial_roofs[str(roof.building)]==str(roof.style) and float(roof.roof_top)>float(roof.mansard_base),"distinct adapted roof retains a physical deck above its wall datum")
			check(bool(roof.edited_legacy_roof)==(str(roof.style) not in ["ottendorfer","faber","fulton","jamaica","linford119","hayden113"]),"retained library/northeast decks are distinguished from reconstructed roofs")
			found_commercial[str(roof.building)]=true
		else:check(false,"unexpected roof identity")
	check(original_roofs==2 and found_commercial.size()==12 and roof_owners.size()==14,"both original roof studies remain alongside twelve individually owned adaptations")
	for x: float in [-53.1,-51.5]:
		var point:=city.to_global(Vector3(x,17.25,28.52))
		var normal:=city.global_basis*Vector3.FORWARD
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.10,point-normal*.30,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(point)<.0001 and str(shells.get(hit.collider.get_rid(),""))=="site_sw3__arcade_brick_bond","outside the firehouse arch remains real masonry,not an unfilled rectangular corner")
	var openwork_controls:=0
	for panel_center: float in [-91.7,-80.,-68.3]:
		for shift: float in [-.8,0.,.8]:
			var center:=city.to_global(Vector3(panel_center+shift,17.27,-30.15))
			var normal:=city.global_basis*Vector3.BACK
			var hole:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.10,center-normal*.40,1,exclude))
			check(hole.is_empty(),"Hampton openwork ellipse is real air through the parapet")
			var ring:=center+city.global_basis*Vector3(.34,0,0)
			var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ring+normal*.10,ring-normal*.40,1,exclude))
			check(not hit.is_empty() and hit.position.distance_to(ring)<.0001 and str(shells.get(hit.collider.get_rid(),""))=="site_far_nw__limestone","adjacent openwork ring is actual supported stone")
			openwork_controls+=1
	check(openwork_controls==9,"all nine openwork holes have adjacent solid controls")
	var roof_probes:=0
	for sample: Dictionary in fixture.roof_samples:
		var a: Array=sample.point;var b: Array=sample.normal
		var point:=city.to_global(Vector3(a[0],a[2],-a[1]))
		var normal:=Vector3(b[0],b[2],-b[1])
		var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.05,point-normal*.05,1,exclude))
		check(not hit.is_empty() and hit.position.distance_to(point)<.0001 and hit.normal.dot(normal)>.99 and str(shells.get(hit.collider.get_rid(),"")).ends_with("__"+str(sample.finish)),"imported closed roof stock keeps its actual outward surface")
		roof_probes+=1
	check(roof_probes>=20,"roof stock checks cannot pass as an empty loop")
	var terrace_details: Array=fixture.townhouse_details
	check(terrace_details.size()==1,"one individual terrace study")
	for detail: Dictionary in terrace_details:
		check(str(detail.building)=="site_nw2" and int(detail.brackets)==4 and int(detail.storeys)==3 and int(detail.terraces)==1,"the townhouse retains one four-bracket cornice group")
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
		var capture_ids:=OS.get_environment("ORISON_CITY_CAPTURE_IDS").split(",",false)
		for building: Dictionary in fixture.buildings:
			if not building.has("previous_roof_height") and str(building.id)!="site_nw2" and not commercial_roofs.has(str(building.id)):continue
			if not capture_ids.is_empty() and str(building.id) not in capture_ids:continue
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
			var toward_city := Vector3.BACK if str(building.id)=="site_nw2" or commercial_roofs.has(str(building.id)) else Vector3(-target.x,0.,-target.z).normalized()
			if str(building.id) in ["site_se3","site_sw3"]:toward_city=Vector3.FORWARD
			var tangent := Vector3(toward_city.z,0.,-toward_city.x)
			var offset := toward_city*span*1.35+tangent*span*.5+Vector3.UP*float(building.roof_height)*.35
			if str(building.id)=="site_nw2" or commercial_roofs.has(str(building.id)):offset=toward_city*span*1.35+Vector3.UP*float(building.roof_height)*.1
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
	if OS.get_environment("ORISON_CITY_PROFILE")=="1":await _profile_commercial(city)
	city.free()
	await get_tree().process_frame
	print("CITY NATIVE BENCH: %d checks, %d roof samples, %d draws, %d failures" % [checks,contacts,draws,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _profile_sha(path: String) -> String:
	if path.get_extension() in ["gd","json","gdshader","gdshaderinc","import"]:
		return FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return FileAccess.get_sha256(path)

func _profile_sources(city: Node3D) -> Dictionary:
	var paths: Dictionary={}
	for path: String in ["res://assets/props/city_elevations_lod1.glb","res://assets/props/city_elevations_lod1.glb.import","res://tests/fixtures/orison_city_elevations_lod1.json"]:
		paths[path]=_profile_sha(path)
	for path: String in ["res://scripts/building/orison_v2_street_boundaries.gd","res://scripts/building/orison_v2_public_region_programmes.gd","res://scripts/building/orison_v2_exterior_spatial_resolver.gd","res://data/orison_v2/exterior/public_region_programmes.json","res://data/orison_v2/exterior/street_frame.json"]:
		paths[path]=_profile_sha(path)
	for path: String in ["res://tests/v2_city_elevation_bench.gd","res://scripts/building/orison_v2_city_shells.gd","res://scripts/building/orison_v2_city_placement.gd","res://data/orison_v2/exterior/city_elevations.json","res://assets/props/city_elevations.glb","res://assets/props/city_elevations.glb.import","res://tests/fixtures/orison_city_elevations.json","res://data/runtime_material_sets.json","res://scripts/material_library.gd","res://scripts/building/surface_pass.gd","res://shaders/orison_surface.gdshader"]:
		paths[path]=_profile_sha(path)
	for family: String in ["masts","aerials","tanks","beacons","transport","streets"]:
		for path: String in ["res://scripts/building/orison_v2_city_"+family+".gd","res://data/orison_v2/exterior/city_"+family+".json","res://assets/props/city_"+family+".glb","res://assets/props/city_"+family+".glb.import"]:
			if FileAccess.file_exists(path):paths[path]=_profile_sha(path)
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		var loaded: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		var stock:=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
		if stock==null:continue
		for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
			if texture==null or texture.resource_path.is_empty():continue
			if not paths.has(texture.resource_path):paths[texture.resource_path]=_profile_sha(texture.resource_path)
			if not paths.has(texture.resource_path+".import") and FileAccess.file_exists(texture.resource_path+".import"):paths[texture.resource_path+".import"]=_profile_sha(texture.resource_path+".import")
	return paths

func _profile_probe(camera: Camera3D,center: Vector3,direction: Vector3,distance_m: float) -> Dictionary:
	camera.global_position=center+direction*distance_m
	camera.look_at(center)
	for frame in 4:await RenderingServer.frame_post_draw
	var viewport:=get_viewport()
	return {"distance_m":distance_m,"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func _profile_natural(_city: Node3D,camera: Camera3D,draws: Array,identity: String,key: String,directory: String) -> Dictionary:
	var focus: MeshInstance3D=null
	for draw: MeshInstance3D in draws:
		draw.visible=str(draw.name)==identity+"__"+key
		if draw.visible:focus=draw
	check(focus!=null,"commercial body material exists for natural LOD: "+identity)
	if focus==null:return {}
	var arrays: Array=focus.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var direction: Vector3=((Vector3.FORWARD if identity in ["site_se3","site_sw3"] else Vector3.BACK)+Vector3.RIGHT*.18+Vector3.UP*.12).normalized()
	var bounds:=focus.get_aabb()
	var center:=focus.global_transform*bounds.get_center()
	var best:=INF
	for i in range(0,indices.size(),3):
		var a: int=indices[i];var b: int=indices[i+1];var c: int=indices[i+2]
		var area: float=(points[b]-points[a]).cross(points[c]-points[a]).length()*.5
		var normal: Vector3=(focus.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
		if area<.2 or normal.dot(direction)<.5:continue
		var local_point: Vector3=(points[a]+points[b]+points[c])/3.
		var distance_sq: float=local_point.distance_squared_to(bounds.get_center())
		if distance_sq<best:
			best=distance_sq
			center=focus.global_transform*local_point
	check(is_finite(best),"natural LOD aims at broad actual surface stock: "+identity)
	var radius:=0.
	for corner in 8:radius=maxf(radius,center.distance_to(focus.global_transform*bounds.get_endpoint(corner)))
	camera.fov=75.;get_viewport().mesh_lod_threshold=1.
	var start:=maxf(2.,radius/sin(deg_to_rad(camera.fov*.5))*1.25)
	var probes: Array[Dictionary]=[]
	var before: Dictionary={};var after: Dictionary={}
	for i in 12:
		var row:=await _profile_probe(camera,center,direction,start*pow(1.5,i))
		probes.append(row)
		check(int(row.draws)==1 and int(row.primitives)>0,"natural probe retains complete isolated body part: "+identity)
		if not before.is_empty() and int(row.primitives)<int(before.primitives):after=row;break
		before=row
	check(not after.is_empty(),"actual distance selects a replacement body LOD: "+identity)
	var images: Array[Dictionary]=[]
	if not after.is_empty():
		for i in 12:
			var row:=await _profile_probe(camera,center,direction,(float(before.distance_m)+float(after.distance_m))*.5)
			if int(row.primitives)==int(before.primitives):before=row
			else:after=row
		check(int(after.primitives)<int(before.primitives),"bisected natural bracket retains an actual index reduction: "+identity)
		var programmes: Variant=preload("res://scripts/building/orison_v2_public_region_programmes.gd").load_default()
		var limit_frame: Transform3D=programmes.body_transform("StreetBoundaries")
		var limit_local: Vector3=limit_frame.affine_inverse()*(center+direction*float(after.distance_m))
		after["exploration_radius_m"]=Vector2(limit_local.x,limit_local.z).length()
		check(float(after.exploration_radius_m)<preload("res://scripts/building/orison_v2_street_boundaries.gd").EXPLORATION_RADIUS_M,"body replacement occurs inside registered temporary exploration wall: "+identity)
		for spec: Dictionary in [{"id":"before","distance":before.distance_m,"fov":75.,"minimum":before.primitives},{"id":"after","distance":after.distance_m,"fov":75.,"minimum":after.primitives},{"id":"narrow","distance":after.distance_m,"fov":5.,"minimum":before.primitives},{"id":"return","distance":before.distance_m,"fov":75.,"minimum":before.primitives}]:
			camera.fov=float(spec.fov)
			var row:=await _profile_probe(camera,center,direction,float(spec.distance))
			var expected:=int(row.primitives)>=int(spec.minimum) if str(spec.id)=="narrow" else int(row.primitives)==int(spec.minimum)
			check(int(row.draws)==1 and expected,"natural transition, narrow optical recovery and inward return: "+identity+"/"+str(spec.id))
			var frame:=get_viewport().get_texture().get_image()
			var pixel:=frame.get_pixel(frame.get_width()/2,frame.get_height()/2);var background:=frame.get_pixel(0,0)
			var contrast:=Vector3(pixel.r-background.r,pixel.g-background.g,pixel.b-background.b).length()
			check(contrast>.02,"physical structural stock remains at image center: "+identity+"/"+str(spec.id))
			row["file"]=identity+"_natural_"+str(spec.id)+".png";row["fov"]=camera.fov;row["center_contrast"]=contrast
			check(frame.save_png(directory.path_join(str(row.file)))==OK,"natural commercial image saved")
			images.append(row)
	return {"part":str(focus.name),"scope":"One whole material body part, default pixel threshold1, bisected first observed distance reduction, narrow-FOV recovery and inward return. Not a whole-building/world LOD or artistic acceptance.","before":before,"after":after,"probes":probes,"images":images}

func _profile_commercial(city: Node3D) -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(),"render profiling requires an explicit image/diagnostic directory")
	if directory.is_empty():return
	var profile_scope:=OS.get_environment("ORISON_CITY_PROFILE_SCOPE")
	if profile_scope.is_empty():profile_scope="northwest"
	check(profile_scope in ["northwest","opposing","northeast","northeast_completion","narrow"],"known explicit city profiling scope")
	if profile_scope not in ["northwest","opposing","northeast","northeast_completion","narrow"]:return
	var selected: Array=["site_nbr_w","site_nbr_e"] if profile_scope=="narrow" else ["site_ne3","site_ne4"] if profile_scope=="northeast_completion" else ["site_ne1","site_ne2"] if profile_scope=="northeast" else ["site_se3","site_sw3","site_far_nw"] if profile_scope=="opposing" else ["site_nw1","site_nw3","site_nw4"]
	var sources:=_profile_sources(city)
	var draws: Array=city.find_children("*","MeshInstance3D",true,false)
	var visibility: Dictionary={}
	for draw: MeshInstance3D in draws:visibility[draw]=draw.visible
	var camera:=Camera3D.new();add_child(camera);camera.make_current();camera.fov=75.;camera.far=20000.
	var viewport:=get_viewport();var threshold:=viewport.mesh_lod_threshold;var taa:=viewport.use_taa
	var vsync:=DisplayServer.window_get_vsync_mode();var cap:=Engine.max_fps
	viewport.use_taa=false;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	var observations: Array[Dictionary]=[];var transitions: Dictionary={}
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_elevations.json"))
	for profile: Dictionary in profiles.buildings:
		var identity:=str(profile.id)
		if identity not in selected:continue
		var bounds:=AABB();var first:=true
		for draw: MeshInstance3D in draws:
			draw.visible=str(draw.name).begins_with(identity+"__")
			if draw.visible:
				bounds=draw.global_transform*draw.get_aabb() if first else bounds.merge(draw.global_transform*draw.get_aabb())
				first=false
		check(not first,"profile includes actual building and retained equipment: "+identity)
		var center:=bounds.get_center();var direction: Vector3=((Vector3.FORWARD if identity in ["site_se3","site_sw3"] else Vector3.BACK)+Vector3.RIGHT*.18+Vector3.UP*.12).normalized()
		var distance_m:=bounds.size.length()*.5/sin(deg_to_rad(37.5))*1.25
		camera.fov=75.;camera.global_position=center+direction*distance_m;camera.look_at(center)
		var family_rows: Array[Dictionary]=[]
		for spec: Dictionary in [{"id":"near","threshold":0.},{"id":"far","threshold":10000.},{"id":"natural","threshold":1.},{"id":"far_repeat","threshold":10000.},{"id":"near_repeat","threshold":0.}]:
			viewport.mesh_lod_threshold=float(spec.threshold)
			for frame in 12:await RenderingServer.frame_post_draw
			var samples: Array[Dictionary]=[];var previous:=Time.get_ticks_usec()
			for frame in 90:
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				samples.append({"wall_ms":(now-previous)/1000.,"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())});previous=now
			var row: Dictionary={"building":identity,"id":spec.id,"threshold":spec.threshold,"distance_m":distance_m,"frame_samples":samples,"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
			family_rows.append(row);observations.append(row)
			if str(spec.id) in ["near","far"]:check(viewport.get_texture().get_image().save_png(directory.path_join(identity+"_profile_"+str(spec.id)+".png"))==OK,"actual complete building profile capture saved")
		check(int(family_rows[1].primitives)<int(family_rows[0].primitives),"far rendering actually uses fewer complete-body indices: "+identity)
		transitions[identity]=await _profile_natural(city,camera,draws,identity,"terracotta" if identity=="site_ne3" else "wood_dark" if identity in ["site_ne1","site_nbr_w","site_nbr_e"] else "limestone" if identity=="site_far_nw" else str(profile.wall_key),directory)
	for draw: MeshInstance3D in draws:draw.visible=bool(visibility[draw])
	check(sources==_profile_sources(city),"profile sources remain unchanged through measurement")
	var record: Dictionary={"evidence_class":"INERT","scope":"Isolated current imported buildings/equipment,90 warmed uncapped frames per case, repeated near/far and actual material-body LOD transitions. Screenshots excluded from timings. No matched baseline, whole-world performance, route contract or artistic acceptance.","profile_scope":profile_scope,"observations":observations,"natural_transitions":transitions,"source_hashes":sources,"checks":checks,"failures":failures,"settings":{"resolution":str(viewport.get_visible_rect().size),"msaa":viewport.msaa_3d,"taa":viewport.use_taa,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps}}
	var file:=FileAccess.open(directory.path_join("city_elevation_profile.json"),FileAccess.WRITE)
	check(file!=null,"test-written rendering diagnostic opens")
	record["checks"]=checks
	if file!=null:
		file.store_string(JSON.stringify(record,"\t")+"\n")
		file.close()
	viewport.mesh_lod_threshold=threshold;viewport.use_taa=taa;DisplayServer.window_set_vsync_mode(vsync);Engine.max_fps=cap
	camera.queue_free()
