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
	_require(draws.size() == 44, "fourteen guarded edges and separate transfer meshes mounted")
	for draw: MeshInstance3D in draws:
		var key := str(draw.mesh.surface_get_material(0).resource_name)
		var finish := "iron_blackened" if key=="cast_iron" else key
		_require(key in ["metal", "cast_iron", "wood_dark"] and draw.material_override == MatLib.get_mat(finish), "mapped material on " + str(draw.name))
		_check_planar_mapping(draw.mesh, true)
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
			_require(not hit.is_empty() and absf(root.to_local(hit.position).y - at.y) < .00005
					and guard.floor_owner in str(hit.collider.get_path()), "actual landing seats " + guard.id + " foot " + str(at.x))
		var north: bool = guard.kind == "North"
		var z_start: float = 2.6 if north else (-2.8 if guard.kind == "South" else -1.4)
		var direction := -1.0 if north else 1.0
		# Narrow court starts must clear the retained sloping side rails before
		# sweeping into this edge. Use five positions within the standing capsule's
		# actual available width; the whole native span gets separate first rays.
		var fractions: Array[float] = []
		fractions.assign([.15,.35,.5,.65,.85] if north else [.38,.44,.5,.56,.62])
		for fraction: float in fractions:
			var x: float = lerpf(guard.bounds[0], guard.bounds[3], fraction)
			var query := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = .33
			capsule.height = player.STANDING_HEIGHT
			query.shape = capsule
			query.transform = Transform3D(root.global_basis, root.to_global(Vector3(x, guard.bounds[1]+player.STANDING_HEIGHT*.5+.01, z_start)))
			query.motion = root.global_basis*Vector3(0,0,direction*1.5)
			query.collision_mask = 1
			query.exclude = [player.get_rid()]
			var result := space.cast_motion(query)
			_require(result[0] < .99 and result[0] > .01, "standing capsule stopped at " + guard.id + " station " + str(fraction))
			var ray_height: float = guard.bounds[1] + .7
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					root.to_global(Vector3(x,ray_height,z_start)), root.to_global(Vector3(x,ray_height,z_start+direction*1.5)), 1, [player.get_rid()]))
			_require(not hit.is_empty() and str(hit.collider.name) == guard.id + "Collision", "the fitted guard owns first contact at " + guard.id)
	for view: Dictionary in [
		{"id":"court_guard_ground", "at":Vector3(2.95,0,-1.4), "look":Vector3(2.95,.8,-.58)},
		{"id":"court_guard_north", "at":Vector3(2.95,0,2.5), "look":Vector3(2.95,.65,1.7)},
		{"id":"court_guard_upper", "at":Vector3(2.95,3.2,-2.8), "look":Vector3(2.95,3.85,-1.945)},
		{"id":"court_transfer_overview", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(2.95,-1.4,-1.2)},
		{"id":"court_transfer_feet", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(3.35,-3.188,-.55)},
		{"id":"court_transfer_slab", "at":Vector3(4.9,-3.2,-1.1), "look":Vector3(2.95,-.2,-1.8)}]:
		player.set_physics_process(false)
		player.global_position = root.to_global(view.at)
		player.camera.global_position = player.global_position + Vector3.UP*player.STANDING_EYE
		await _court_capture(view.id, view.look)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("structure-checks.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"evidence_class":"INERT", "guards":construction.guards.size(), "draws":draws.size(),
			"failures":failures, "note":"Installed contact/capsule/mapping checks; no structural capacity or roof acceptance."}, "\t"))

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
