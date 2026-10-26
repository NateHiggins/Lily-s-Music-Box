extends Node
## Nine independently started unit legs in one production world. No vertical
## connection, save reconstruction, case completion or human acceptance claim.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const DRIVER := preload("res://tests/v2_remaining_apartment_walk.gd")
const UNITS := ["3A", "3B", "4A", "5A", "5B", "5C", "6A", "6B", "6C"]
const ROOMS := ["F03_B_VESTIBULE", "F03_B_MAIN", "F03_B_KITCHEN", "F03_B_PRIVATE_HALL", "F03_B_ALCOVE", "F03_B_BATH", "F03_A_VESTIBULE", "F03_A_MAIN", "F03_A_KITCHEN", "F03_A_PRIVATE_HALL", "F03_A_BATH", "F03_A_BED", "F04_A_VESTIBULE", "F04_A_MAIN", "F04_A_KITCHEN", "F04_A_BED", "F04_A_PRIVATE_HALL", "F04_A_BATH", "F05_A_MAIN", "F05_A_VESTIBULE", "F05_A_PRIVATE_HALL", "F05_A_BATH", "F05_A_BED", "F05_A_KITCHEN", "F05_A_STUDY", "F05_B_MAIN", "F05_B_VESTIBULE", "F05_B_BATH", "F05_B_ALCOVE", "F05_B_PRIVATE_HALL", "F05_B_KITCHEN", "F05_C_VESTIBULE", "F05_C_MAIN", "F05_C_STUDIO", "F05_C_PRIVATE_HALL", "F05_C_BATH", "F05_C_KITCHEN", "F05_C_BED1", "F05_C_BED2", "F06_A_MAIN", "F06_A_VESTIBULE", "F06_A_PRIVATE_HALL", "F06_A_BATH", "F06_A_BED", "F06_A_KITCHEN", "F06_A_STUDY", "F06_B_MAIN", "F06_B_VESTIBULE", "F06_B_BATH", "F06_B_ALCOVE", "F06_B_PRIVATE_HALL", "F06_B_KITCHEN", "F06_C_VESTIBULE", "F06_C_MAIN", "F06_C_STUDIO", "F06_C_PRIVATE_HALL", "F06_C_BATH", "F06_C_KITCHEN", "F06_C_BED1", "F06_C_BED2"]
const SOURCES := ["res://tests/orison_v2_first_slice_contract_test.gd", "res://tests/OrisonV2RemainingApartmentAccessContractTest.tscn", "res://tests/orison_v2_4b_door_route_test.gd", "res://tests/orison_v2_connected_exterior_route_test.gd", "res://tests/orison_v2_remaining_apartment_access_contract_test.gd", "res://tests/orison_v2_roof_route_test.gd", "res://tests/roof_tank_hand_test.gd", "res://tests/orison_v2_vertical_route_test.gd", "res://tests/v2_remaining_apartment_walk.gd"]
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
	print("REMAINING APARTMENT ACCESS CHECK: ",label," = ",ok)

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
		world.player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		for unit: String in UNITS:

			var driver = DRIVER.new()
			driver.route_label = "REMAINING APARTMENT ACCESS "+unit
			driver.unit_id = unit
			driver.externally_managed = true
			driver.world = world
			driver.player = world.player
			add_child(driver)
			held.append(weakref(driver))
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
	_check(retained==0,"production root and all nine route drivers retire")
	_write_receipt(retained)
	print("V2 REMAINING APARTMENT ACCESS CONTRACT: %s; %d rooms; %d checks; %d failures" % ["PASS" if failures==0 else "FAIL",visited.size(),checks.size(),failures])
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
	var source := "game/tests/orison_v2_remaining_apartment_access_contract_test.gd"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Spatial room access and actual grab/motion/release in 3A, 3B, 4A, 5A, 5B, 5C, 6A, 6B and 6C. Collision queries plan paths; the normal player controller executes every route. Each unit leg starts with one placement; all subsequent travel uses the ordinary controller. No vertical connection, case completion, save reconstruction, whole-building runtime or human acceptance is claimed.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":source,"test_sha256":bindings[source],"test_dependencies":bindings,
			"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "",
			"surface_inputs_sha256":str(geometry_binding.get("sha256","")),
			"runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},
			"room_access":{"executed":legs.size()==UNITS.size(),"status":status,"rooms":visited},
			"teardown":{"executed":true,"status":status,"measurement_scope":"production root and route drivers only","tracked_nodes":UNITS.size()+1,"retained_nodes":retained}},
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
