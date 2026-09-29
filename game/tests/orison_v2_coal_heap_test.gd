extends "res://tests/orison_v2_coal_delivery_test.gd"
## Preserve the ordinary delivery circuit, then test the actual replacement pile.
func _route() -> void:
	await super._route()
	route_label="COAL HEAP"
	if not failures.is_empty(): return
	var bunker := world.adapter.resolve("B1_COAL_BUNKER") as Node3D
	var mesh := bunker.find_child("CoalHeap",true,false) as MeshInstance3D
	if not _require(mesh!=null,"fabricated mound is present"):return
	var faces := mesh.mesh.get_faces()
	var contacts := 0
	for x in [-.3,0,.3]:
		for z in [-.45,0,.45]:
			var origin := Vector3(x,.7,z)
			var distance := INF
			for i in range(0,faces.size(),3):
				var h: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
				if h!=null:distance=minf(distance,origin.distance_to(h))
			var query := PhysicsRayQueryParameters3D.create(mesh.to_global(origin),mesh.to_global(origin+Vector3.DOWN*.75),1,[player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if not _require(not hit.is_empty() and mesh.is_ancestor_of(hit.collider),"pile owns its actual slope contact"):return
			if not _require(is_finite(distance) and absf(distance-origin.distance_to(mesh.to_local(hit.position)))<.001,"collision agrees with imported coal triangles"):return
			contacts+=1
	var retired := 0
	for old in world.adapter.root.get_children():
		if str(old.name).begins_with("B1_COAL_HEAP_"):
			if not _require(not old.visible and old.get_node("Collision").collision_layer==0,"old heap identity retains no visible box or phantom collision"):return
			retired+=1
	if not _require(retired==14,"all fourteen old heap boxes are replaced"):return
	player.global_position=bunker.to_global(Vector3(-1.35,.02,1.45))
	player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	await _roof_capture("angular_coal_heap_player",world.adapter.root.to_local(bunker.to_global(Vector3(0,.3,0))))
	for layer in player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	await _roof_capture("angular_coal_heap_clear",world.adapter.root.to_local(bunker.to_global(Vector3(0,.3,0))))
	print("COAL HEAP CONTACTS: contacts=%d retired_boxes=%d triangles=%d failures=%d" % [contacts,retired,faces.size()/3,failures.size()])
