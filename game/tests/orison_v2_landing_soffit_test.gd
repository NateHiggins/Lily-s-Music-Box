extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Static construction inspection of exposed slab undersides and retained bodies.

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var roof_envelopes:=_roof_platform_envelopes(root)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var levels: Dictionary={}
	for level: Dictionary in layout.levels:levels[str(level.id)]=float(level.y)
	var draws: Array[MeshInstance3D]=[]
	for space: Dictionary in layout.spaces:
		var holder:=root.get_node_or_null(str(space.id))
		if holder!=null:
			if holder.has_node("Ceiling"):draws.append(holder.get_node("Ceiling"))
			if holder.has_node("Floor"):draws.append(holder.get_node("Floor"))
	for platform: Dictionary in layout.platforms:draws.append(root.get_node(str(platform.id)))
	var cache: Array=[]
	for draw: MeshInstance3D in draws:
		if not draw.is_visible_in_tree():continue
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		cache.append({"owner":str(root.get_path_to(draw)),"bounds":pose*draw.mesh.get_aabb(),"faces":pose*draw.mesh.get_faces()})
	var samples:=0;var missing:=0;var duplicate:=0;var platform_bearing_contacts:=0
	for platform: Dictionary in layout.platforms:
		var draw:=root.get_node(str(platform.id)) as MeshInstance3D
		if draw.mesh.get_surface_count()==2:
			var arrays: Array=draw.mesh.surface_get_arrays(1)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			check(uv.size()==vertices.size() and normals.size()==vertices.size() and tangents.size()==vertices.size()*4,"new underside exports complete mapping arrays")
			var mapped:=true
			for i in vertices.size():
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				# ArrayMesh's 16-bit octahedral normal/tangent storage returns
				# 15.26 microradians on an exact axis; inspect within two codes.
				mapped=mapped and vertices[i].is_finite() and uv[i].is_finite() and normals[i].distance_to(Vector3.DOWN)<.00003
				mapped=mapped and tangent.distance_to(Vector3.RIGHT)<.00003 and is_equal_approx(tangents[i*4+3],1.0)
				mapped=mapped and absf(normals[i].length()-1)<.000001 and absf(tangent.length()-1)<.000001 and absf(tangent.dot(normals[i]))<.000001
				if i%3<2:mapped=mapped and absf(vertices[i].distance_to(vertices[i+1])-uv[i].distance_to(uv[i+1]))<.00005
			check(mapped,"underside retains metre scale and its downward orthogonal tangent basis: "+str(platform.id)+" n="+str(normals[0])+" t="+str(tangents.slice(0,4)))
			var cls:=str(platform.get("class","core"))
			check(draw.mesh.surface_get_material(0)==root.architectural_materials.material_for(str(platform.id),cls),"original walking surface keeps its material: "+str(platform.id))
			check(draw.mesh.surface_get_material(1)==root.architectural_materials.material_for("Ceiling",cls),"new underside uses the existing ceiling finish: "+str(platform.id))
			check(draw.get_active_material(1)==draw.mesh.surface_get_material(1),"production rendering keeps the landing's separate underside finish")
		var body:=draw.get_node("Collision") as StaticBody3D
		_check_platform_shapes(body,str(platform.id),roof_envelopes.get(str(platform.id),[]))
		var rect: Array=platform.rect
		var underside: float=levels[str(platform.level)]-float(layout.dimensions.slab_thickness)
		var body_shape:=body.get_child(0).shape as BoxShape3D
		check(body_shape.size.is_equal_approx(Vector3(float(rect[2])-float(rect[0]),.2,float(rect[3])-float(rect[1]))),"source platform body dimensions remain unchanged")
		for ux: float in [.08,.5,.92]:
			for uz: float in [.08,.5,.92]:
				var point:=Vector3(lerpf(float(rect[0]),float(rect[2]),ux),underside-.08,lerpf(float(rect[1]),float(rect[3]),uz))
				var surfaces:=0
				for record: Dictionary in cache:
					if not (record.bounds as AABB).grow(.001).has_point(point+Vector3.UP*.08):continue
					var distance:=_mesh_distance(record.faces,point,Vector3.UP)
					if is_finite(distance) and absf(distance-.08)<.00003:surfaces+=1
				if surfaces==0:missing+=1
				if surfaces>1:duplicate+=1
				check(surfaces==1,"one visible underside at "+str(platform.id)+" "+str(point)+" owners="+str(surfaces))
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(point),root.to_global(point+Vector3.UP*.16),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and absf(point.distance_to(root.to_local(hit.position))-.08)>=.0001:
					var first_owner:=str(root.get_path_to(hit.collider))
					var fitted_support: bool=(str(platform.id)=="F01_LIGHT_COURT_BASE" and first_owner.begins_with("LightCourtStructure/LightCourtTransfer_cast_iron/")) or (str(platform.id)=="ROOF_PUBLIC_LANDING_E" and first_owner.begins_with("CourtRoofBridge/RoofCourtBridgeTransfer_cast_iron/"))
					var support:=hit.collider.get_parent() as MeshInstance3D
					var seated:=false
					if fitted_support and support!=null:
						var support_pose: Transform3D=root.global_transform.affine_inverse()*support.global_transform
						var support_bounds: AABB=support_pose*support.mesh.get_aabb()
						seated=absf(support_bounds.end.y-underside)<.00002
					check(fitted_support and seated,"foreground is the fitted native slab support with its top seated at the underside: "+str(platform.id)+" "+first_owner)
					if fitted_support and seated:
						print("PLATFORM SOFFIT BEARING: ",platform.id," target=",point+Vector3.UP*.08," first=",first_owner," at=",root.to_local(hit.position))
						# Only this measured seated bearing is excluded for the separate
						# retained-slab datum query; actual first contact remains checked.
						query.exclude=[world.player.get_rid(),hit.collider.get_rid()]
						hit=world.get_world_3d().direct_space_state.intersect_ray(query)
						platform_bearing_contacts+=1
				check(not hit.is_empty() and hit.collider==body and absf(point.distance_to(root.to_local(hit.position))-.08)<.0001,"visible underside meets its named retained structural collision: "+str(platform.id)+" target="+str(point+Vector3.UP*.08))
				samples+=1
	check(platform_bearing_contacts==6,"six native court/roof bearing contacts precede their independently checked retained slabs")
	var room_draws:=0;var room_samples:=0;var foreground_contacts:=0
	var world_bodies: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):world_bodies.append(body.get_rid())
	for space: Dictionary in layout.spaces:
		var draw:=root.get_node_or_null(str(space.id)+"/Floor") as MeshInstance3D
		if draw==null or draw.mesh.get_surface_count()!=2:continue
		room_draws+=1
		var slab_body:=draw.get_node_or_null("Collision") as StaticBody3D
		check(slab_body!=null,"exposed room slab retains its physical owner: "+str(space.id))
		if slab_body==null:continue
		var slab_exclude: Array[RID]=[]
		for rid: RID in world_bodies:
			if rid!=slab_body.get_rid():slab_exclude.append(rid)
		var arrays: Array=draw.mesh.surface_get_arrays(1)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		check(uv.size()==vertices.size() and normals.size()==vertices.size() and tangents.size()==vertices.size()*4,"exposed room slab exports complete mapping arrays")
		var mapped:=true
		for i in vertices.size():
			var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			mapped=mapped and vertices[i].is_finite() and uv[i].is_finite() and normals[i].distance_to(Vector3.DOWN)<.00003 and tangent.distance_to(Vector3.RIGHT)<.00003
			mapped=mapped and absf(normals[i].length()-1)<.000001 and absf(tangent.length()-1)<.000001 and absf(tangent.dot(normals[i]))<.000001 and is_equal_approx(tangents[i*4+3],1.0)
			if i%3<2:mapped=mapped and absf(vertices[i].distance_to(vertices[i+1])-uv[i].distance_to(uv[i+1]))<.00005
		check(mapped,"room underside uses metre mapping and an orthogonal tangent basis: "+str(space.id))
		check(draw.mesh.surface_get_material(0)==root.architectural_materials.material_for("Floor",str(space.get("class","unresolved"))),"room walking surface keeps its material: "+str(space.id))
		var finish_part: String="ExteriorSoffit" if str(space.id).begins_with("ROOF_DECK_") else "Ceiling"
		check(draw.mesh.surface_get_material(1)==root.architectural_materials.material_for(finish_part,str(space.get("class","unresolved"))),"room underside uses its source-appropriate finish: "+str(space.id))
		check(draw.get_active_material(1)==draw.mesh.surface_get_material(1),"production rendering keeps the room's separate underside finish: "+str(space.id))
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		for index in range(0,vertices.size(),3):
			for weights: Vector3 in [Vector3(1,1,1)/3.0,Vector3(.6,.2,.2),Vector3(.2,.6,.2)]:
				var contact:=pose*(vertices[index]*weights.x+vertices[index+1]*weights.y+vertices[index+2]*weights.z)
				var point:=contact-Vector3.UP*.08
				var surfaces:=0
				for record: Dictionary in cache:
					if not (record.bounds as AABB).grow(.001).has_point(contact):continue
					var distance:=_mesh_distance(record.faces,point,Vector3.UP)
					if is_finite(distance) and absf(distance-.08)<.00003:surfaces+=1
				check(surfaces==1,"one rendered surface at an exposed room underside: "+str(space.id)+" "+str(contact)+" owners="+str(surfaces))
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(point),root.to_global(point+Vector3.UP*.16),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and absf(point.distance_to(root.to_local(hit.position))-.08)>=.0001:
					foreground_contacts+=1
					print("ROOM SOFFIT FOREGROUND: ",space.id," target=",contact," first=",root.get_path_to(hit.collider)," at=",root.to_local(hit.position))
				# A retained wall may extend below a buried slab/wall joint. This
				# separate query checks the named slab body without changing any
				# physics masks or granting obstacle-clearance/walk evidence.
				query.exclude=slab_exclude
				var slab_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not slab_hit.is_empty() and slab_hit.collider==slab_body and absf(point.distance_to(root.to_local(slab_hit.position))-.08)<.0001,"room underside matches its retained slab body: "+str(space.id)+" "+str(contact))
				room_samples+=1
	await _capture_soffits(world,root)
	print("ROOM SOFFITS: additional_draws=%d samples=%d foreground_contacts=%d" % [room_draws,room_samples,foreground_contacts])
	print("LANDING SOFFITS: platforms=%d samples=%d missing=%d duplicate=%d checks=%d failures=%d startup_ms=%f" % [layout.platforms.size(),samples,missing,duplicate,checks,failures.size(),world.startup_ms])
	for failure: String in failures:print("LANDING SOFFIT FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _roof_platform_envelopes(root: Node3D) -> Dictionary:
	# The two already-fitted roof-door landings retain their original boxes
	# and add exact native curb envelopes under the same body owner.
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_falls.json"))
	var specs: Dictionary={}
	for spec: Dictionary in fixture.door_fittings:specs[str(spec.id)]=spec
	var result: Dictionary={}
	for draw: MeshInstance3D in root.get_node("RoofFalls").find_children("*","MeshInstance3D",true,false):
		var identity:=str(draw.name).split("__")[0]
		var kind:=str(draw.name).split("__")[-1]
		if kind!="InteriorPhysicalEnvelope":continue
		check(specs.has(identity),"roof envelope retains its source door identity: "+identity)
		if not specs.has(identity):continue
		var owner: String=specs[identity].interior_floor_owner
		var body:=root.get_node(owner+"/Collision") as StaticBody3D
		var faces: PackedVector3Array=preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh)
		if not result.has(owner):result[owner]=[]
		result[owner].append((body.global_transform.affine_inverse()*draw.global_transform)*faces)
	check(result.size()==2,"both published roof-door landing envelopes are accounted")
	return result

func _check_platform_shapes(body: StaticBody3D,identity: String,envelopes: Array) -> void:
	check(body.get_child_count()==1+envelopes.size() and body.get_child(0).shape is BoxShape3D,
			"original platform box and only its source-bound native envelopes remain: "+identity)
	var matched: Dictionary={}
	for index in range(1,body.get_child_count()):
		var shape_node:=body.get_child(index) as CollisionShape3D
		check(shape_node!=null and shape_node.shape is ConcavePolygonShape3D,"added landing shape is its native envelope: "+identity)
		if shape_node==null or not shape_node.shape is ConcavePolygonShape3D:continue
		var actual: PackedVector3Array=shape_node.transform*(shape_node.shape as ConcavePolygonShape3D).get_faces()
		var found:=-1
		for candidate in envelopes.size():
			if matched.has(candidate):continue
			var expected: PackedVector3Array=envelopes[candidate]
			if actual.size()!=expected.size():continue
			var exact:=true
			for vertex in actual.size():
				if actual[vertex].distance_to(expected[vertex])>.00002:exact=false;break
			if exact:found=candidate;break
		check(found>=0,"every additional collision face matches its actual imported curb within 20 microns: "+identity)
		if found>=0:matched[found]=true
	check(matched.size()==envelopes.size(),"no source landing envelope is missing or duplicated: "+identity)

func _capture_soffits(world: Node3D,root: Node3D) -> void:
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=60
	for view: Array in [
		["basement_north",Vector3(4.6,-1.676,2.7),Vector3(3.2,-.2,2.4)],
		["floor_02_south",Vector3(4.7,4.724,-3.4),Vector3(3.0,6.2,-3.0)],
		["floor_03_lift_side",Vector3(.8,7.924,2.35),Vector3(1.45,9.4,-1.5)],
		["service_basement",Vector3(11.075,-1.676,3.0),Vector3(11.2,-.2,3.8)],
		["north_second_slab",Vector3(-1.5,1.0,12.4),Vector3(-1.5,3.0,11.3)],
		["ground_west_slab",Vector3(-16.7,-1.2,-5.0),Vector3(-15.2,-.2,-5.0)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
