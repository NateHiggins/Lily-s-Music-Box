extends Node3D
const Selector := preload("res://scripts/building/building_root_selector.gd")
const Hand := preload("res://tests/heating_hand_driver.gd")
var checks := 0
var failures: Array[String] = []
var results: Array[Dictionary] = []
var capture_paths: Array[String] = []
var started_ms := 0
var source_before := ""
var worlds_ready := 0
var pointer_grabs := 0

func runtime_digest() -> String:
	var output: Array=[]
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0: return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func write_contract(directory: String) -> void:
	var after := runtime_digest()
	check(not source_before.is_empty() and after==source_before,"runtime inputs remain unchanged through disk reconstruction")
	var sources := {}
	for path: String in ["front_lighting_integration_test.gd","heating_hand_driver.gd","watch_station_hand_test.gd","v2_front_restoration_review.gd"]:
		sources["game/tests/"+path]=FileAccess.get_file_as_string("res://tests/"+path).replace("\r\n","\n").sha256_text()
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"35 installed restored-front fixtures, 20 physical switches, actual pointer motion/release, lobby alcove approach and real disk reconstruction. Captures require separate visual review; whole-world surface/mip, performance and human acceptance are not claimed.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started_ms)/1000.0},
		"source":{"test_path":"game/tests/front_lighting_integration_test.gd","test_sha256":sources["game/tests/front_lighting_integration_test.gd"],"runtime_inputs_sha256":after,"test_sources":sources},
		"contracts":{"production_composition":{"executed":worlds_ready==2,"status":status},"direct_manipulation":{"executed":pointer_grabs==50,"status":status},"save_reconstruction":{"executed":worlds_ready==2,"status":status}},
		"checks":checks,"failures":failures,"observations":results}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))

func shot(label: String, world: OrisonV2RuntimeRoot, eye: Vector3, target: Vector3) -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":
		check(false,"render requires windowed SHOT_DIR"); return
	DirAccess.make_dir_recursive_absolute(out)
	var camera := Camera3D.new(); world.add_child(camera); camera.fov=55
	camera.global_position=world.adapter.root.to_global(eye)
	camera.look_at(world.adapter.root.to_global(target)); camera.make_current()
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var path := out.path_join(label+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"render saved: "+label)
	capture_paths.append(path); camera.free(); world.player.camera.make_current()

func check(ok: bool,label: String) -> void:
	checks += 1; results.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	print("FRONT LIGHTING: ",label," = ",ok)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	started_ms=Time.get_ticks_msec(); source_before=runtime_digest()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,750)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"production world starts")
	if world.startup_failed:
		print("FRONT STARTUP REASON: ",world.startup_failure_reason)
		if world._blockout != null: print("FRONT BLOCKOUT FAILURES: ",world._blockout.failures)
		get_tree().quit(1); return
	worlds_ready += 1
	var trim: RefCounted = world.adapter.root.get_meta("v2_native_front_trim_fittings")
	check(trim.errors.is_empty() and trim.installed.size()==86,"all eighty-six bored wood pieces mounted in production")
	check(trim.changed_batches.size()==21,"only twenty-one owning room trim batches spliced")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_front_lighting_factory")
	var supply: RefCounted = world.adapter.root.get_meta("v2_native_front_lighting_supply")
	check(factory.installed.size()==35,"all thirty-five native fixtures mounted")
	for identity: String in factory.installed:
		var fixture: LightFixtureProp=factory.installed[identity].get_ref()
		check(fixture.light.shadow_reverse_cull_face,"front light retains corrected shadow face: "+identity)
	check(supply.installed.size()==18,"eighteen fixed floor/material batches")
	check(supply.instance_groups.size()==12,"two support prototypes per floor")
	var count := 0
	for group: MultiMeshInstance3D in supply.instance_groups: count += group.multimesh.instance_count
	check(count==407,"all support instances retained")
	check(supply.replaced_covers.size()==6,"six solid covers replaced")
	var hand := Hand.new(); add_child(hand); hand.player = world.player
	var player := world.player
	player.camera.make_current(); player.carried_device.set_capture_hidden(true)
	player.set_lamp_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/room_lighting.json"))
	var circuit_index := 0
	for row: Dictionary in source.switches:
		if not str(row.id).contains("_FRONT_"): continue
		var plate: Node3D = world.adapter.resolve(str(row.id))
		var floor_y := float(str(row.id).substr(1,2).to_int()-1)*3.2
		var found := false
		var collision: CollisionShape3D = player._shape
		var blockers: Dictionary = {}
		for lateral: float in [0.0,-.25,.25,-.5,.5]:
			for distance: float in [.4,.3,.5,.65,.8]:
				var at := plate.to_global(Vector3(lateral,0,-distance)); at.y = floor_y+.02
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = collision.shape
				query.transform = Transform3D(Basis.IDENTITY,at+collision.position)
				query.collision_mask = player.collision_mask; query.exclude = [player.get_rid()]
				var hits := get_world_3d().direct_space_state.intersect_shape(query,8)
				if hits.is_empty():
					player.global_position = at; player.velocity = Vector3.ZERO; found = true; break
				for hit: Dictionary in hits: blockers[str(hit.collider.get_path())] = true
			if found: break
		check(found,str(row.id)+" clear standing operating stance")
		if not found:
			print("FRONT STANCE BLOCKERS: ",row.id," ",blockers.keys()); continue
		# Let the ordinary controller settle before comparing screen motion.
		# Falling from the query's 20 mm floor clearance moves the camera too.
		for settle in 20: await get_tree().physics_frame
		player.camera.look_at(plate.to_global(Vector3(0,0,-.06)))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var settings: Array[bool] = [false,true]
		if circuit_index%2==1: settings.append(false)
		circuit_index += 1
		for now_on: bool in settings:
			hand.click()
			var acquired: bool = player._grab.active() and player._grab.target.get("owner")==plate
			check(acquired,str(row.id)+" actual pointer grabs toggle")
			if not acquired: break
			pointer_grabs += 1
			check(await hand.move_to(deg_to_rad(22 if now_on else -22)),str(row.id)+" follows constrained mouse motion")
			hand.click()
			await get_tree().physics_frame
			check(not player._grab.active(),str(row.id)+" second click releases")
			var snapshot: Dictionary = plate.power_snapshot()
			check(not snapshot.is_empty() and snapshot.values().all(func(value):return bool(value)==now_on),str(row.id)+" room circuit follows contact")
	check(hand.follows_cursor,"toggle motion follows cursor direction")
	check(circuit_index==20 and pointer_grabs==50,"all twenty circuits exercised with fifty physical grabs")
	var walk := preload("res://tests/v2_front_restoration_review.gd").new()
	add_child(walk); walk.world=world; walk.host=self; walk.player=player
	player.global_position=world.adapter.root.to_global(Vector3(4.6,.025,-5.0)); player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	check(await walk._walk(Vector3(5.05,0,-4.25)),"ordinary lobby approach reaches alcove operating position")
	walk.free(); player.set_physics_process(false)
	await shot("front_lighting_alcove",world,Vector3(4.8,1.65,-4.3),Vector3(5.55,1.48,-3.952))
	await shot("front_lighting_gallery_day",world,Vector3(-4.6,4.85,-11.7),Vector3(6.5,5.65,-9.3))
	await shot("front_lighting_workroom",world,Vector3(5.7,1.65,-11.7),Vector3(7.5,2.35,-10.3))
	await shot("front_lighting_source",world,Vector3(8.75,5.05,1.6),Vector3(9.35,5.10,1.0))
	world.campaign_clock.configure_date(1928,11,10,1380)
	world.get_node("WakingAtmosphere").director._apply(1380)
	await shot("front_lighting_gallery_night",world,Vector3(-4.6,4.85,-11.7),Vector3(6.5,5.65,-9.3))
	var expected: Dictionary = {}
	for row: Dictionary in source.fixtures:
		if str(row.id).contains("_FRONT_"): expected[str(row.id)]=world.adapter.resolve(str(row.id)).powered
	check(expected.size()==35 and true in expected.values() and false in expected.values(),"disk test retains a nondefault mixture of all thirty-five fixture states")
	var old_path := RealityState.save_path
	var save_path := "user://tests/front_lighting_%s.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	RealityState.save_path=save_path; RealityState.persistence_enabled=true
	check(RealityState.save_game(),"existing RealityState writes a real disk save")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var records: Dictionary=disk.get("v2_household_controls",{}).get("records",{})
	for identity: String in expected:
		check(records.get(identity,{}).get("value")==expected[identity],"disk preserves fixture contact: "+identity)
	RealityState.persistence_enabled=false
	hand.free(); world.shutdown_for_tests(); world.free(); packed=null
	await get_tree().process_frame; await get_tree().process_frame
	PropAudio.clear_cache(); RealityState.reset_campaign_for_tests(); RealityState.load_game()
	check(RealityState.can_continue(),"disk document loads through existing save authority")
	Selector.reset_for_tests("v2")
	packed=load(Selector.scene_path()) as PackedScene; world=packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world); await get_tree().physics_frame; await get_tree().physics_frame
	check(not world.startup_failed,"fresh world reconstructs after disk load")
	if not world.startup_failed:
		worlds_ready += 1
		var restored_trim: RefCounted=world.adapter.root.get_meta("v2_native_front_trim_fittings")
		check(restored_trim.errors.is_empty() and restored_trim.installed.size()==86,"fresh world reconstructs all bored wood fittings")
		for identity: String in expected:
			check(world.adapter.resolve(identity).powered==expected[identity],"reconstructed fixture preserves contact: "+identity)
	world.shutdown_for_tests(); world.free(); RealityState.save_path=old_path; RealityState.persistence_enabled=false
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty(): out = "user://front_lighting_integration"
	DirAccess.make_dir_recursive_absolute(out)
	write_contract(out)
	var file := FileAccess.open(out.path_join("diagnostic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Executed composition, pointer, approach, disk reconstruction and captures; no surface/mip or human visual acceptance.","checks":checks,"results":results,"failures":failures,"captures":capture_paths},"\t")); file.close()
	await get_tree().process_frame
	print("FRONT LIGHTING RESULT: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
