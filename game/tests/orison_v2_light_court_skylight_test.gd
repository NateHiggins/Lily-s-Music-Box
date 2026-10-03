extends "res://tests/orison_v2_light_court_structure_test.gd"
## Installed aperture, reveal, curb bearing and six-pane physics checks.

func _init() -> void: route_label = "LIGHT COURT SKYLIGHT"

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	var root: Node3D = world.adapter.root
	var cap_owner: Node3D = root.get_node("RoofBulkheadCaps")
	var sky_owner: Node3D = root.get_node("LightCourtSkylight")
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_light_court_skylight.json"))
	var cap_native := PackedVector3Array()
	var sky_rids: Array[RID] = [player.get_rid()]
	for body: StaticBody3D in sky_owner.find_children("*", "StaticBody3D", true, false): sky_rids.append(body.get_rid())
	var cap_draws := cap_owner.find_children("*", "MeshInstance3D", true, false)
	var sky_draws := sky_owner.find_children("*", "MeshInstance3D", true, false)
	_require(cap_draws.size() == 10 and sky_draws.size() == 15, "ten bounded caps and fifteen separate native skylight parts")
	for draw: MeshInstance3D in cap_draws:
		_check_planar_mapping(draw.mesh, true)
		cap_native.append_array((root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces())
	for draw: MeshInstance3D in sky_draws:
		_check_planar_mapping(draw.mesh, true)
		var key := str(draw.mesh.surface_get_material(0).resource_name)
		if key == "glass":
			_require(draw.material_override == root.architectural_materials.material_for("Glazing", "core"), "pane uses retained architectural glass owner")
		else:
			_require(draw.material_override == MatLib.get_mat(key), "curb/frame uses mapped " + key)
	var ceiling: MeshInstance3D = root.get_node("ROOF_PUBLIC_CORE/Ceiling")
	var ceiling_native: PackedVector3Array = (root.global_transform.affine_inverse()*ceiling.global_transform)*ceiling.mesh.get_faces()
	var space := world.get_world_3d().direct_space_state
	var aperture_probes := 0
	for x: float in [2.5,2.7,2.95,3.2,3.4]:
		for z: float in [-1.85,-1.4,-1.0,-.6,-.3]:
			var a := Vector3(x,22.45,z)
			var b := Vector3(x,22.15,z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(a), root.to_global(b), 1, sky_rids))
			_require(hit.is_empty(), "actual slab aperture stays open at " + str(Vector2(x,z)))
			_require(not _native_segment_hits(cap_native,a,b) and not _native_segment_hits(ceiling_native,a,b), "native top and retained underside both open at " + str(Vector2(x,z)))
			aperture_probes += 1
	for edge: Dictionary in [
		{"a":Vector3(2.47,22.3,-1.4),"b":Vector3(2.43,22.3,-1.4),"at":Vector3(2.45,22.3,-1.4)},
		{"a":Vector3(3.43,22.3,-1.4),"b":Vector3(3.47,22.3,-1.4),"at":Vector3(3.45,22.3,-1.4)},
		{"a":Vector3(2.95,22.3,-1.88),"b":Vector3(2.95,22.3,-1.92),"at":Vector3(2.95,22.3,-1.9)},
		{"a":Vector3(2.95,22.3,-.27),"b":Vector3(2.95,22.3,-.23),"at":Vector3(2.95,22.3,-.25)}]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(edge.a),root.to_global(edge.b),1,sky_rids))
		_require(not hit.is_empty() and hit.collider.get_parent() == cap_owner and root.to_local(hit.position).distance_to(edge.at) < .00005, "solid cap owns a fitted aperture edge")
		_require(_native_segment_hits(cap_native,edge.a,edge.b), "native reveal accompanies physical aperture edge")
	for curb: Dictionary in construction.curbs:
		var r: Array = curb.rect
		var at := Vector3((r[0]+r[2])*.5,22.4,(r[1]+r[3])*.5)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.001), root.to_global(at-Vector3.UP*.004),1,sky_rids))
		_require(not hit.is_empty() and hit.collider.get_parent()==cap_owner and root.to_local(hit.position).distance_to(at)<.00005, "cap physically seats " + curb.id)
	var slope := .4/.54
	var half_vertical_thickness := .003*sqrt(1+slope*slope)
	for pane: Dictionary in construction.panes:
		var r: Array = pane.rect
		var x: float = (r[0]+r[2])*.5
		var z: float = (r[1]+r[3])*.5
		var centre_y: float = pane.ridge_y-slope*absf(x-2.95)
		for direction: float in [1.,-1.]:
			var a := Vector3(x,centre_y+direction*.02,z)
			var b := Vector3(x,centre_y-direction*.02,z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(b),1,[player.get_rid()]))
			_require(not hit.is_empty() and str(hit.collider.get_parent().name)==pane.id and absf(root.to_local(hit.position).y-(centre_y+direction*half_vertical_thickness))<.00005, "actual 6mm pane " + pane.id + " face " + str(direction))
	_require(aperture_probes==25, "all twenty-five aperture columns inspected")
	var bridge: Node3D = root.get_node("CourtRoofBridge")
	var bridge_rids: Array[RID] = [player.get_rid()]
	for body: StaticBody3D in bridge.find_children("*", "StaticBody3D", true, false): bridge_rids.append(body.get_rid())
	for draw: MeshInstance3D in bridge.find_children("*", "MeshInstance3D", true, false):
		_check_planar_mapping(draw.mesh, true)
	var bridge_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_court_roof_bridge.json"))
	for column: Dictionary in bridge_source.columns:
		var at := Vector3(column.base[0],column.base[1],column.base[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.001),root.to_global(at-Vector3.UP*.004),1,bridge_rids))
		_require(not hit.is_empty() and column.floor_owner in str(hit.collider.get_path()) and root.to_local(hit.position).distance_to(at)<.00005, "retained F06 floor seats " + column.id)
		at = Vector3(column.top[0]+.045,column.top[1],column.top[2])
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at-Vector3.UP*.001),root.to_global(at+Vector3.UP*.001),1,[player.get_rid()]))
		_require(not hit.is_empty() and hit.collider.get_parent().get_parent() == bridge and root.to_local(hit.position).distance_to(at)<.00005, "native beam seats on " + column.id)
	var beam_seat := Vector3(4.625,19.,0.)
	var beam_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(beam_seat-Vector3.UP*.001),root.to_global(beam_seat+Vector3.UP*.001),1,bridge_rids))
	_require(not beam_hit.is_empty() and "ROOF_PUBLIC_LANDING_E" in str(beam_hit.collider.get_path()) and root.to_local(beam_hit.position).distance_to(beam_seat)<.00005, "actual new east landing bears on fitted beam")
	for view: Dictionary in [
		{"id":"court_standing_skylight", "at":Vector3(2.95,0,-1.4),"look":Vector3(2.85,23,-1.4)},
		{"id":"court_lobby_glimpse", "at":Vector3(2.95,0,-2.5),"look":Vector3(2.95,23,-1.4)},
		{"id":"skylight_curbs_oblique", "at":Vector3(5.2,22.4,-3.4),"look":Vector3(2.95,22.9,-1.05)},
		{"id":"roof_bridge_f06", "at":Vector3(5.,16.,-3.2),"look":Vector3(4.625,18.3,-.3)},
		{"id":"roof_bridge_north_foot", "at":Vector3(5.,16.,2.8),"look":Vector3(4.625,16.02,1.82)},
		{"id":"skylight_aperture_up", "at":Vector3(2.95,19.2,-1.4),"look":Vector3(2.85,23,-1.4)}]:
		player.set_physics_process(false)
		player.global_position=root.to_global(view.at)
		player.camera.global_position=player.global_position+Vector3.UP*player.STANDING_EYE
		await _court_capture(view.id,view.look)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("skylight-checks.json"),FileAccess.WRITE).store_string(JSON.stringify({
			"evidence_class":"INERT","aperture_probes":aperture_probes,"panes":construction.panes.size(),"failures":failures,
			"note":"Native aperture, curb/glass contacts and standing view. Downstream main roof drainage and final materials remain open."},"\t"))

func _native_segment_hits(vertices: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	for i in range(0,vertices.size(),3):
		if Geometry3D.segment_intersects_triangle(a,b,vertices[i],vertices[i+1],vertices[i+2]) != null: return true
	return false
