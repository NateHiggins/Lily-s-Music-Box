extends Node
var failures: Array[String]=[]
func _ready() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	print("INFESTATION ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _run() -> void:
	if DisplayServer.get_name()=="headless": get_tree().quit(2); return
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.DEBUG
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(2).timeout
	var infestation=world.mina_infestation
	_check(is_instance_valid(infestation) and infestation.ready_for_play,"debug infestation built")
	if not is_instance_valid(infestation) or not infestation.ready_for_play:
		world.shutdown_for_tests(); world.free(); get_tree().quit(1); return
	_check(infestation.roster.critters.size()==16,"all sixteen production species alive")
	_check(infestation.originals.size()>20,"actual apartment surfaces carry encroachment")
	_check(infestation.contacts.size()>=16,"all spawn supports come from real collision")
	_check(infestation.hero!=null and infestation.margin.palps.size()>0,"hero and live margin present")
	for controller in infestation.controllers:
		_check(controller.blender_visuals!=null,"accepted Blender bodies active")
	world.player.set_physics_process(false)
	world.building_debug._go_to_building_position(infestation.stand)
	world.player.camera.look_at(infestation.target)
	world.player.camera.make_current()
	var before: float=infestation.roster.critters[0].age
	world.player.world_modified.emit(infestation.target,"test_maintenance")
	_check(infestation.director.attention_active(),"production player action reaches ecology")
	await get_tree().create_timer(8).timeout
	_check(infestation.roster.critters[0].age>before,"specimens continue live behavior")
	_check(infestation.living.steps>0,"living architecture advances")
	var shape := CapsuleShape3D.new()
	shape.radius=.25; shape.height=1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,infestation.stand+Vector3.UP*.9)
	query.exclude=[world.player.get_rid()]
	_check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"visit stance clears actual body collision")
	await _shot("mina_infestation")
	var specimen: Dictionary=infestation.roster.critters[10]
	world.player.camera.global_position=specimen.pos+specimen.up*1.1+Vector3.UP*.2
	world.player.camera.look_at(specimen.pos)
	await get_tree().create_timer(.5).timeout
	await _shot("mina_critter_close")
	var case_before: Dictionary=RealityState.data.cases.duplicate(true)
	var mesh: MeshInstance3D=infestation.originals[0].mesh
	var original: Material=infestation.originals[0].whole
	world.clear_mina_infestation()
	_check(world.mina_infestation==null and mesh.material_override==original,"clear restores actual surface material")
	await world.reset_mina_infestation()
	_check(world.mina_infestation.roster.critters.size()==16,"reset restores full roster without duplicates")
	_check(RealityState.data.cases==case_before,"debug reset preserves case progress")
	world.reset_mina_infestation()
	world.clear_mina_infestation()
	await get_tree().physics_frame
	_check(world.mina_infestation==null,"clear cancels a pending reset")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	await world.reset_mina_infestation()
	_check(world.mina_infestation==null,"ordinary play refuses debug infestation")
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
func _shot(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

