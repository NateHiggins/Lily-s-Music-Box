extends Node
## Continuous roof service and guarded-drive circuits from one F06 start.
## No save reconstruction, full runtime authority or human acceptance claim.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const DRIVERS := [preload("res://tests/orison_v2_roof_program_route_test.gd"),preload("res://tests/orison_v2_roof_lift_program_route_test.gd")]
const ROOMS := ["ROOF_PUBLIC_CORE", "ROOF_SERVICE_CORE", "ROOF_DECK_WEST", "ROOF_DECK_SOUTH", "ROOF_DECK_NORTH", "ROOF_DECK_MIDDLE", "ROOF_DECK_EAST", "ROOF_DECK_SOUTHEAST", "ROOF_DECK_NORTHEAST"]
const SOURCES := ["res://tests/orison_v2_roof_lift_program_route_test.gd", "res://tests/orison_v2_roof_program_contract_test.gd", "res://tests/OrisonV2RoofProgramContractTest.tscn", "res://tests/orison_v2_roof_program_route_test.gd", "res://tests/orison_v2_roof_plant_test.gd", "res://tests/orison_v2_lift_drive_test.gd", "res://tests/orison_v2_roof_route_test.gd", "res://tests/orison_v2_4b_door_route_test.gd", "res://tests/orison_v2_connected_exterior_route_test.gd", "res://tests/orison_v2_vertical_route_test.gd"]
var checks: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var visited := {}
var failures := 0
var started := Time.get_ticks_msec()

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks.append({"label":label,"ok":ok})
	if not ok: failures += 1
	print("ROOF PROGRAM CHECK: ",label," = ",ok)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	Selector.reset_for_tests("v2")
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	_check(not world.startup_failed,"production V2 world starts")
	var held: Array[WeakRef] = [weakref(world)]
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	if not world.startup_failed:
		_check_light_rotation(world.player)
		world.player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var first_leg := true
		for script: Script in DRIVERS:
			var driver = script.new()
			driver.externally_managed = true
			driver.world = world
			driver.player = world.player
			add_child(driver)
			held.append(weakref(driver))
			if first_leg:
				driver._prepare_player_start()
				first_leg=false
			await driver._route()
			for observation: Dictionary in driver.interaction_checks:
				_check(bool(observation.ok),str(observation.label))
			_check(driver.failures.is_empty() and not driver.trace.is_empty(),"complete collision-bearing leg: "+driver.route_label)
			legs.append({"name":driver.route_label,"trace":driver.trace.duplicate(true),
				"failures":driver.failures.duplicate(),"initial_placement_only":true})
			for step: Dictionary in driver.trace:
				if not step.ok: continue
				for room: Dictionary in layout.spaces:
					if not str(room.id) in ROOMS: continue
					var floor_y: float = float(world.adapter.root.level_y[str(room.level)])
					var r: Array = room.rect
					var p: Array = step.actual
					if absf(float(p[1])-floor_y)<.15 and p[0]>r[0]+.05 and p[0]<r[2]-.05 and p[2]>r[1]+.05 and p[2]<r[3]-.05:
						visited[str(room.id)] = {"actual":p,"leg":driver.route_label}
			remove_child(driver)
			driver.free()
		for identity: String in ROOMS:
			_check(world.adapter.resolve(identity)!=null and visited.has(identity),"walk reaches authored room: "+identity)
	Input.action_release("move_forward")
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().create_timer(.25).timeout
	var retained := 0
	for reference: WeakRef in held:
		if reference.get_ref()!=null: retained += 1
	_check(retained==0,"production root and both route drivers retire")
	_write_receipt(retained)
	print("V2 ROOF PROGRAM CONTRACT: %s; %d rooms; %d checks; %d failures" % ["PASS" if failures==0 else "FAIL",visited.size(),checks.size(),failures])
	get_tree().quit(0 if failures==0 else 1)

func _write_receipt(retained: int) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	var digest: Array=[]
	var geometry: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"bind current production inputs")
	_check(OS.execute("python",[root.path_join("tools/v2_surface_evidence.py"),"--snapshot"],geometry)==0,"bind loaded geometry and surface inputs")
	var geometry_binding: Dictionary = JSON.parse_string(str(geometry[0])) if not geometry.is_empty() else {}
	var bindings := {}
	for path: String in SOURCES:
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(FileAccess.get_file_as_string(path).replace("\r\n","\n").to_utf8_buffer())
		bindings["game/"+path.trim_prefix("res://")] = hash.finish().hex_encode()
	var status := "PASS" if failures==0 else "FAIL"
	var source := "game/tests/orison_v2_roof_program_contract_test.gd"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Roof spatial access and scoped plant checks from one initial F06 placement. Both circuits use ordinary controller movement. Tank entry and reopening use player input; abort, service verbs and lift destinations are submitted directly to their production directors. Supplemental shaft-camera inspection pauses player physics, restores it before any walked step, and grants no shaft access. No case completion, save reconstruction, full authority lifecycle or human acceptance is claimed.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":source,"test_sha256":bindings[source],"test_dependencies":bindings,
			"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "",
			"surface_inputs_sha256":str(geometry_binding.get("sha256","")),
			"runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},
			"room_access":{"executed":legs.size()==2,"status":status,"rooms":visited},
			"teardown":{"executed":true,"status":status,"measurement_scope":"production root and route drivers only","tracked_nodes":3,"retained_nodes":retained}},
		"checks":checks,"legs":legs,"failures":failures}
	var directory := OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty(),"explicit receipt destination supplied")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	_check(file!=null,"open access contract output")
	if file==null:return
	file.store_string(JSON.stringify(receipt,"\t"));file.flush()
	_check(file.get_error()==OK,"flush access contract output")

func _check_light_rotation(player: PlayerController) -> void:
	var original: Transform3D = player._hand.transform
	var target: Basis = player.camera.basis.orthonormalized()
	if player.carried_device and player.carried_device.get("beam_valid"):
		target=(player.camera.transform*player.carried_device.beam_xform).basis.orthonormalized()
	player._hand.basis=Basis(Vector3.UP,.7).scaled(Vector3(1.00012,1.00001,.9999))
	for frame in 240: player._carry_service_light(1.0/60.0)
	var actual: Basis=player._hand.basis
	_check(actual.is_finite() and absf(actual.determinant()-1.0)<.00001,
		"carried light recovers a finite unit rotation from measured-size scale drift")
	_check(actual.get_rotation_quaternion().angle_to(target.get_rotation_quaternion())<.001,
		"drift correction retains the light chasing the intended camera aim")
	player._hand.transform=original
