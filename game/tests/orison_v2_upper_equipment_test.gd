extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("UPPER EQUIPMENT: "+label)
func _ready() -> void:
	RealityState.persistence_enabled=false
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_equipment_probes.json"))
	check(source.equipment.size()==15,"fourteen authored objects and a comparison table")
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed,"complete production world starts")
		if world.startup_failed:world.shutdown_for_tests();world.free();break
		var player := world.player
		player.set_physics_process(false);player.set_process_unhandled_input(false)
		player.camera.make_current()
		var radios: Array[BakedFurnitureInteraction]=[]
		var refs: Array[WeakRef]=[]
		var capsule := CapsuleShape3D.new();capsule.radius=.38;capsule.height=1.524
		for row: Dictionary in source.equipment:
			var prop := world.adapter.resolve(row.id) as StaticBody3D
			var stance := world.adapter.resolve(row.stance) as Node3D
			check(prop!=null and stance!=null,"one equipment owner and approach: "+str(row.id))
			if prop==null or stance==null:continue
			refs.append(weakref(prop))
			check(str(prop.get_meta("v2_furniture_id",""))==row.id,"semantic identity retained")
			var meshes := prop.find_children("*","MeshInstance3D",true,false)
			check(not meshes.is_empty(),"authored equipment geometry present")
			for mesh: MeshInstance3D in meshes:
				var material := mesh.material_override as StandardMaterial3D
				check(material!=null and material.albedo_texture!=null,"equipment retains texture-backed material")
			player.global_position=stance.global_position
			player.camera.global_position=player.global_position+Vector3.UP*player.STANDING_EYE
			var center := Vector3(0,(float(row.bounds[0][1])+float(row.bounds[1][1]))*.5,0)
			player.camera.look_at(prop.to_global(center))
			await get_tree().physics_frame
			var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*.787);query.exclude=[player.get_rid()]
			check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"equipment approach admits standing capsule: "+str(row.id))
			if row.kind=="radio":
				var radio := prop as BakedFurnitureInteraction
				radios.append(radio)
				check(radio.owner_unit==row.unit and not radio.get("_powered"),"collector set retains its resident and starts silent")
				player.use_primary_interaction()
				check(radio.get("_powered") and radio.get("_radio_bed").playing,"actual E reaches distinct specialist set: "+str(row.id))
				player.use_primary_interaction()
				check(not radio.get("_powered") and not radio.get("_radio_bed").playing,"second E stops this set")
			else:check(not prop.has_method("interact"),"fixed display equipment adds no invented mechanism")
		check(radios.size()==4,"all four upper specialist comparison sets")
		for radio: BakedFurnitureInteraction in radios:radio.interact(player)
		world.shutdown_for_tests();world.free()
		for ref: WeakRef in refs:check(ref.get_ref()==null,"equipment retires with world")
		await get_tree().create_timer(.1).timeout
	print("UPPER EQUIPMENT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
