extends Node
var failures: Array[String] = []
var checks := 0
var started := 0

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	started = Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase":FirstShiftDirector.PHASE_COMPLETE}
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var selector = preload("res://scripts/building/building_root_selector.gd")
	selector.reset_for_tests("v2")
	var packed := load(selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	for i in 30: await get_tree().physics_frame
	_check(not world.startup_failed,"production V2 starts")
	var bodies := world.find_children("*","DreamCritterController",true,false)
	var body: DreamCritterController
	for candidate in bodies:
		if candidate.companion != null: body = candidate
	_check(body != null,"production mounts private companion")
	if body != null:
		_check(body.companion.specimen_id >= 0 and body.critters.size()==1,"one surface-seated companion")
		var atmosphere := world.get_node("LampAtmosphere")
		for material in body.blender_visuals.micro_materials:
			_check(int(material.get_meta("_lamp_optical_field_owner",0))==atmosphere.field.get_instance_id(),"uses existing waking lamp field")
		_check(body.find_children("*","CollisionObject3D",true,false).is_empty(),"no NPC physics/perception target")
		world.work_orders.issue_job("vantry_chirp_2a","reported")
		body.companion.refresh(1.0)
		_check(body.companion.target != Vector3.INF,"live work resolves to production fault owner")
		var durable: Dictionary = RealityState.data.maintenance_jobs.duplicate(true)
		# Exercise this reader synchronously, so unrelated world authorities
		# cannot legitimately transition the job between the two observations.
		for i in 30:
			body.companion.refresh(.1)
			if not body.critters.is_empty(): body.companion.steer(body.critters[0],body,.1)
		_check(durable == RealityState.data.maintenance_jobs,"companion leaves production job state intact")
		if not body.critters.is_empty():
			world.player.set_physics_process(false)
			world.player.camera.look_at(body.critters[0].pos)
			for i in 10: await RenderingServer.frame_post_draw
			var directory := OS.get_environment("SHOT_DIR")
			if not directory.is_empty():
				DirAccess.make_dir_recursive_absolute(directory)
				get_viewport().get_texture().get_image().save_png(directory.path_join("production_companion.png"))
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
			"scope":"Production V2 companion composition, sole waking optical field binding and read-only work targeting; not full navigation or save reconstruction proof.",
			"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
			"source":{"test_path":"game/tests/tardigrade_companion_world_test.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
			"contracts":{"companion_composition":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},"checks":checks,"failures":failures}
		FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	world.queue_free()
	for i in 4: await get_tree().process_frame
	print("TARDIGRADE WORLD: ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
