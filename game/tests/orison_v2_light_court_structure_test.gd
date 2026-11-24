extends "res://tests/orison_v2_light_court_entry_test.gd"
## Installed native guards, supports and single-owner slab contacts.

func _init() -> void: route_label = "LIGHT COURT STRUCTURE"

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	var root: Node3D = world.adapter.root
	var model: Node3D = root.get_node("LightCourtStructure")
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_light_court_structure.json"))
	var draws := model.find_children("*", "MeshInstance3D", true, false)
	_require(draws.size() == 74, "twenty-four guarded edges and separate transfer meshes mounted")
	var checked_meshes: Dictionary = {}
	for draw: MeshInstance3D in draws:
		var key := str(draw.mesh.surface_get_material(0).resource_name)
		var finish := "iron_blackened" if key=="cast_iron" else key
		var stock := MatLib.get_mat(finish) as StandardMaterial3D
		var active := draw.get_active_material(0)
		var matches := false
		if active is StandardMaterial3D and stock != null:
			matches = active.albedo_texture == stock.albedo_texture \
					and active.normal_texture == stock.normal_texture \
					and active.roughness_texture == stock.roughness_texture \
					and not active.uv1_triplanar
		_require(key in ["metal", "cast_iron", "wood_dark"] and matches, "mapped material on " + str(draw.name))
		var mesh_id := draw.mesh.get_rid()
		if not checked_meshes.has(mesh_id):
			_check_planar_mapping(draw.mesh, true)
			checked_meshes[mesh_id] = true
	var space := world.get_world_3d().direct_space_state
	var transfer_rids: Array[RID] = [player.get_rid()]
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		if str(body.get_parent().name).begins_with("LightCourtTransfer_"):
			transfer_rids.append(body.get_rid())
	_require(transfer_rids.size() == 3, "only the two actual transfer meshes own its collision")
	for column: Dictionary in construction.columns:
		var foot := Vector3(column.base[0], column.base[1], column.base[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				root.to_global(foot + Vector3.UP*.001), root.to_global(foot - Vector3.UP*.004), 1, transfer_rids))
		_require(not hit.is_empty() and absf(root.to_local(hit.position).y - foot.y) < .00005
				and "B1_PRIMARY_STAIR_BASE" in str(hit.collider.get_path()), "actual retained base seats " + column.id)
	for z: float in [-1.8, -.55]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				root.to_global(Vector3(2.95,-.201,z)), root.to_global(Vector3(2.95,-.199,z)), 1, transfer_rids))
		_require(not hit.is_empty() and absf(root.to_local(hit.position).y + .2) < .00005
				and "F01_LIGHT_COURT_BASE" in str(hit.collider.get_path()), "actual new slab bears on crossbeam at " + str(z))
	for guard: Dictionary in construction.guards:
		for foot: Array in guard.foot_contacts:
			var at := Vector3(foot[0], foot[1], foot[2])
			var own_guard: StaticBody3D = model.get_node(guard.id + "Collision")
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					root.to_global(at + Vector3.UP*.001), root.to_global(at - Vector3.UP*.004), 1, [player.get_rid(), own_guard.get_rid()]))
			var expected_owners := [str(guard.floor_owner)]
			if guard.kind == "East":
				expected_owners.append_array(["ROOF_PUBLIC_LANDING_N", "ROOF_PUBLIC_LANDING_S"])
			if guard.kind == "ServiceReturn":
				expected_owners.append_array(["ROOF_SERVICE_LANDING", "SERVICE_F06_ROOF/FlightB_Step09"])
			var contact := str(hit.collider.get_path()) if not hit.is_empty() else ""
			var seated := expected_owners.any(func(owner: String) -> bool: return contact.contains(owner))
			seated = seated and absf(root.to_local(hit.position).y - at.y) < .00005
			# The west end of a service rail returns into masonry where the
			# wall overlaps the deck. Prove the wall at rail height as well.
			if guard.kind == "ServiceSide" and absf(at.x - float(guard.bounds[0]) - .025) < .002 \
					and "_SERVICE_CORE/WallWest_" in contact:
				var anchor := at + Vector3.UP * .55
				var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
						root.to_global(anchor + Vector3.RIGHT * .24),
						root.to_global(anchor + Vector3.LEFT * .20), 1,
						[player.get_rid(), own_guard.get_rid()]))
				seated = not wall.is_empty() and "_SERVICE_CORE/WallWest_" in str(wall.collider.get_path())
			_require(seated, "actual structure supports %s at %s (vertical contact %s)" % [guard.id, at, contact])
		_check_guard_contact(root, space, guard)
	_check_widened_stairs(root, space)
	var connected_floors: Array[String] = []
	for join: Dictionary in construction.joins:
		var floor_id: String = str(join.id).get_slice("_", 0)
		connected_floors.append(floor_id)
		var middle_z := (float(join.start[2]) + float(join.end[2])) * .5
		var foot_y := float(join.start[1])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				root.to_global(Vector3(3.84, foot_y + .7, middle_z)),
				root.to_global(Vector3(2.95, foot_y + .7, middle_z)), 1, [player.get_rid()]))
		_require(not hit.is_empty() and str(hit.collider.name) == join.id + "Collision",
				floor_id + " court guard closes the landing-to-flight joint")
		var capsule := CapsuleShape3D.new()
		capsule.radius = .33
		capsule.height = player.STANDING_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(root.global_basis, root.to_global(
				Vector3(3.975, foot_y + player.STANDING_HEIGHT * .5 + .03, middle_z)))
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		_require(space.intersect_shape(query).is_empty(), floor_id + " standing capsule clears beside the new joint")
	_require(connected_floors == ["F02", "F03", "F04", "F05", "F06", "ROOF"],
			"all upper South guards join the returning flight")
	for view: Dictionary in [
		{"id":"court_guard_ground", "at":Vector3(2.95,0,-1.4), "look":Vector3(2.95,.8,-.58)},
		{"id":"court_guard_north", "at":Vector3(2.95,0,2.5), "look":Vector3(2.95,.65,1.7)},
		{"id":"roof_court_gate", "at":Vector3(4.9,19.2,-2.2), "look":Vector3(2.95,19.85,-1.7)},
		{"id":"roof_service_gate", "at":Vector3(12.35,19.2,4.3), "look":Vector3(10.85,19.85,5.3)},
		{"id":"court_guard_upper", "at":Vector3(2.95,3.2,-2.8), "look":Vector3(2.95,3.85,-1.945)},
		{"id":"court_transfer_overview", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(2.95,-1.4,-1.2)},
		{"id":"court_transfer_feet", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(3.35,-3.188,-.55)},
		{"id":"court_transfer_slab", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(2.95,-.2,-1.8)}]:
		player.set_physics_process(false)
		player.global_position = root.to_global(view.at)
		player.camera.global_position = player.global_position + Vector3.UP*player.STANDING_EYE
		await _court_capture(view.id, view.look)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("structure-checks.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"evidence_class":"INERT", "guards":construction.guards.size(), "draws":draws.size(), "joined_floors":connected_floors,
			"failures":failures, "note":"Installed stair bearing, guard contact and material checks."}, "\t"))

func _check_guard_contact(root: Node3D, space: PhysicsDirectSpaceState3D, guard: Dictionary) -> void:
	var bounds: Array = guard.bounds
	var along_z: bool = guard.kind in ["West", "East", "ServiceReturn"]
	var heading: Vector3
	var approach: float
	match guard.kind:
		"North":
			heading = Vector3.FORWARD
			approach = 2.6
		"West":
			heading = Vector3.RIGHT
			approach = .92
		"East":
			heading = Vector3.LEFT
			approach = 4.93
		"ServiceReturn":
			heading = Vector3.LEFT
			approach = 12.35
		"ServiceSide":
			heading = Vector3.BACK
			approach = (float(bounds[2]) + float(bounds[5])) * .5 - .43
		"ServiceLanding":
			heading = Vector3.BACK
			approach = 4.3
		"South":
			heading = Vector3.BACK
			approach = -2.8
		_:
			heading = Vector3.BACK
			approach = -1.4
	var capsule := CapsuleShape3D.new()
	capsule.radius = .33
	capsule.height = player.STANDING_HEIGHT
	for fraction: float in [.38, .44, .5, .56, .62]:
		var station := lerpf(bounds[2 if along_z else 0], bounds[5 if along_z else 3], fraction)
		var from := Vector3(approach if along_z else station, bounds[1], station if along_z else approach)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(root.global_basis,
				root.to_global(from + Vector3.UP * (player.STANDING_HEIGHT * .5 + .01)))
		query.motion = root.global_basis * heading * 1.5
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		var motion := space.cast_motion(query)
		var ray_origin := from + Vector3.UP * .7
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				root.to_global(ray_origin), root.to_global(ray_origin + heading * 1.5), 1, [player.get_rid()]))
		_require(not hit.is_empty() and str(hit.collider.name) == guard.id + "Collision",
				"the fitted guard owns first contact at %s station %.2f" % [guard.id, fraction])
		# At narrow junctions the neighboring slope guard can already touch
		# the capsule. Its mate must still stop the independent first ray.
		_require(motion[0] < .99, "standing capsule stopped at %s station %.2f" % [guard.id, fraction])

func _check_widened_stairs(root: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var levels: Dictionary = {}
	for level: Dictionary in world.layout.levels:
		levels[level.id] = float(level.y)
	for stair: Dictionary in world.layout.stairs:
		var exterior_wall: bool = str(stair.id).begins_with("SERVICE_")
		var bay_width: float = 2.0 * stair.width + stair.gap
		var base_y: float = levels[stair.from]
		var half: float = stair.rise * stair.risers_per_flight
		var run: float = stair.tread * stair.risers_per_flight
		for flight: String in ["A", "B"]:
			var returning := flight == "B"
			var retained_lobby_edge: bool = (stair.id == "PRIMARY_F01_F02" and not returning
					or stair.id == "PRIMARY_B1_F01" and returning)
			var middle := bay_width * .5 + (.07 if returning else -.07)
			if retained_lobby_edge:
				middle = stair.width + stair.gap + .07 if returning else stair.width - .07
			var outer := bay_width + (.113 if exterior_wall else -.07) if returning else .07
			var phase := .25 if returning else .5
			for step: int in [0, 4, 9]:
				var z: float = (run + stair.landing_depth - stair.tread * (step + .5)
						if returning else stair.tread * (step + .5))
				z += (2 + phase) * stair.tread / 6.0 - stair.tread * .5
				var y: float = base_y + (half if returning else 0.0) + (step + 1) * stair.rise
				for x: float in [middle, outer]:
					var station := Vector3(float(stair.origin[0]) + x, y, float(stair.origin[1]) + z)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
							root.to_global(station + Vector3.UP * .035), root.to_global(station - Vector3.UP * .035),
							1, [player.get_rid()]))
					var owner := "%s/Flight%s_Step%02d/" % [stair.id, flight, step]
					var contact := str(hit.collider.get_path()) if not hit.is_empty() else ""
					_require(contact.contains(owner), "tread bearings carry %s at %s (hit %s)" % [owner, station, contact])

func _check_planar_mapping(mesh: Mesh, check_derivatives: bool=false) -> void:
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		_require(vertices.size()>=4 and normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4,"planar quad has active UV, normal and tangent on every imported vertex")
		var valid:=true
		for i in vertices.size():
			valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
			if tangents.size()==vertices.size()*4:
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				valid=valid and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
		_require(valid,"finite unit normals and orthogonal tangent handedness")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		_require(indices.size()>=6 and indices.size()%3==0,"planar surface has complete native indexed triangles")
		var mapped:=true
		var widest:=0.0
		var excess:=0.0
		var derivatives:=true
		for triangle in range(0,indices.size(),3):
			if check_derivatives:
				var a:=indices[triangle]
				var b:=indices[triangle+1]
				var c:=indices[triangle+2]
				var first:=vertices[b]-vertices[a]
				var second:=vertices[c]-vertices[a]
				var uv_first:=uv[b]-uv[a]
				var uv_second:=uv[c]-uv[a]
				var determinant:=uv_first.x*uv_second.y-uv_second.x*uv_first.y
				derivatives=derivatives and absf(determinant)>1e-12
				if absf(determinant)>1e-12:
					var expected: Vector3=(first*uv_second.y-second*uv_first.y)/determinant
					var bitangent: Vector3=(second*uv_first.x-first*uv_second.x)/determinant
					for index: int in [a,b,c]:
						var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
						var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						derivatives=derivatives and projected.dot(actual)>.999
						derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
			for edge in 3:
				var a:=indices[triangle+edge]
				var b:=indices[triangle+(edge+1)%3]
				var length:=vertices[a].distance_to(vertices[b])
				var texture:=uv[a].distance_to(uv[b])
				mapped=mapped and texture<=length+.00005
				excess=maxf(excess,texture-length)
				if length>.00005: widest=maxf(widest,texture/length)
		_require(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
		if check_derivatives: _require(derivatives,"tangent direction and handedness match actual imported UV derivatives")
		print("CEILING MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest," vertices=",vertices.size()," derivatives=",derivatives)
