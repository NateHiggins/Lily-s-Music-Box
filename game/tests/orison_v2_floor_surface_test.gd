extends Node
var failures: Array[String]=[]
func _ready() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.6).timeout
	world.player.set_physics_process(false)
	var floors := 0
	var ceilings := 0
	var probes := 0
	for record: Dictionary in world.layout.spaces:
		var room: Node=world.adapter.resolve(str(record.id))
		if room==null: continue
		for part in ["Floor","Ceiling"]:
			var surface := room.get_node_or_null(part) as MeshInstance3D
			if surface==null: continue
			var arrays: Array=surface.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var up := 0; var down := 0
			for i in range(0,indices.size(),3):
				if normals[indices[i]].y>.9: up+=1
				if normals[indices[i]].y<-.9: down+=1
			if part=="Floor":
				floors+=1
				check(up==2 and down==0,str(record.id)+" floor owns top only")
				var body := surface.get_node("Collision") as StaticBody3D
				var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if shape==null:
					for child in body.get_children():
						if child is CollisionShape3D: shape=child
				check(shape!=null and shape.shape is BoxShape3D,str(record.id)+" retains full collision slab")
				var at := surface.global_position+Vector3.UP*float(world.layout.dimensions.slab_thickness)*.5
				var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.025,at-Vector3.UP*.025,1)
				var excluded: Array[RID]=[]
				var hit: Dictionary={}
				# Furniture/rugs may cover the room centre. Probe the retained slab,
				# excluding only individually identified intervening collision bodies.
				for attempt in range(20):
					hit=world.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.is_empty() or hit.collider==body: break
					excluded.append(hit.rid); query.exclude=excluded
				check(not hit.is_empty() and hit.collider==body and absf(hit.position.y-at.y)<.003,str(record.id)+" actual floor collision at authored height")
				probes+=1
			else:
				ceilings+=1
				check(up==0 and down==2 and indices.size()==6,str(record.id)+" ceiling owns underside only")
	check(floors>100 and ceilings>100,"audit covers the composed building")
	var captures := 0
	var captured_levels: Array[String]=[]
	for record: Dictionary in world.layout.spaces:
		if record.get("class","")!="private" or record.level not in ["F02","F03","F04"]: continue
		if str(record.level) in captured_levels or not str(record.id).ends_with("_MAIN"): continue
		var r: Array=record.rect
		var y: float=world.adapter.root.level_y[record.level]
		var center := Vector3((r[0]+r[2])*.5,y,(r[1]+r[3])*.5)
		world.player.global_position=world.adapter.root.to_global(Vector3(center.x,y+.05,r[1]+.65))
		world.player.camera.make_current()
		world.player.face_world_point(world.adapter.root.to_global(center))
		await get_tree().create_timer(.25).timeout
		await shot(str(record.id))
		captures+=1
		captured_levels.append(str(record.level))
		if captures==3: break
	print("FLOOR OWNERSHIP: floors=%d ceilings=%d collision_probes=%d failures=%d" % [floors,ceilings,probes,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))


