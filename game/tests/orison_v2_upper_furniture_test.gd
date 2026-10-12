extends Node
## Prepared full-composition/lifetime check. Not a played or visual receipt.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("UPPER FURNITURE: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_furniture_probes.json"))
	check(source.furniture.size() == 51, "complete furniture category roster")
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full world starts with upper furniture")
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		await get_tree().physics_frame
		var refs: Array[WeakRef] = []
		var wardrobes := 0
		for record: Dictionary in source.furniture:
			var body := world.adapter.resolve(record.id) as StaticBody3D
			check(body != null, "one furniture consumer: " + str(record.id))
			if body == null: continue
			refs.append(weakref(body))
			check(str(body.get_meta("v2_furniture_id", "")) == record.id, "semantic owner retained")
			check(not body.find_children("*", "CollisionShape3D", true, false).is_empty(), "solid furniture")
			var meshes := body.find_children("*", "MeshInstance3D", true, false)
			check(not meshes.is_empty(), "authored surfaces exist")
			for mesh: MeshInstance3D in meshes:
				if mesh.mesh == null: continue # Retained source pivots with retired visual payloads.
				check(mesh.mesh.get_surface_count()>0,"visible mesh has surfaces")
				for surface in mesh.mesh.get_surface_count():
					var material := mesh.get_active_material(surface)
					check(material!=null,"active native surface material: "+str(record.id)+"/"+str(mesh.name))
					if material is StandardMaterial3D:
						check(material.albedo_texture!=null and material.roughness_texture!=null and material.normal_texture!=null,"active surface retains all PBR maps")
			if record.kind == "wardrobe":
				wardrobes += 1
				check(body.get("_case_wood") == record.mechanism.case_wood, "authored suite wood")
				body.call("interact", world.player)
				check("Close" in str(body.call("interact_prompt")), "native wardrobe opens")
				check(body.get_node_or_null("LeftLeaf") != null and body.get_node_or_null("RightLeaf") != null,
						"one native pair of wardrobe leaves")
			if record.id == "6A_deskwall":
				var space := world.get_world_3d().direct_space_state
				var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(body.to_global(Vector3(0,.95,0)),body.to_global(Vector3(0,.65,0)),1,[world.player.get_rid()]))
				check(not top.is_empty() and top.collider==body and absf(body.to_local(top.position).y-.77)<.01,"desk has actual bearing top at source height")
				for z: float in [-1.14,1.14]:
					var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(body.to_global(Vector3(-.5,.35,z)),body.to_global(Vector3(.5,.35,z)),1,[world.player.get_rid()]))
					check(not support.is_empty() and support.collider==body,"desk has physical end support at "+str(z))
				var query := PhysicsShapeQueryParameters3D.new();var box := BoxShape3D.new();box.size=Vector3(.12,.2,.12);query.shape=box
				query.transform=body.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,.35,0));query.collision_mask=1
				var blocked := false
				for overlap: Dictionary in space.intersect_shape(query):
					if overlap.collider==body:blocked=true
				check(not blocked,"desk retains open central leg space")
		check(wardrobes == 8, "all eight bedroom wardrobes mounted")
		# Exercise existing teardown while all eight wardrobe tweens are active.
		world.shutdown_for_tests()
		world.free()
		for ref: WeakRef in refs:check(ref.get_ref() == null, "furniture retires with its world")
	print("UPPER FURNITURE: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
