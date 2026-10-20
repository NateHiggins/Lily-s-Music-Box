extends Node
## Reuse one production world for complete existing spatial route families.
## Each declared initial placement is retained; no inter-floor walk is claimed.
const Selector := preload("res://scripts/building/building_root_selector.gd")
@export var groups: PackedStringArray
@export var families: Array[Script]
var checks: Array[Dictionary]=[]
var legs: Array[Dictionary]=[]
var visited := {}
var expected := {}
var failures := 0
var started := Time.get_ticks_msec()
var initial_inputs := {}
var bindings := {}

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok:failures+=1
	print("ACCESS COHORT CHECK: ",label," = ",ok)

func _run() -> void:
	initial_inputs=_inputs()
	bindings=_dependencies()
	_check(not groups.is_empty(),"explicit route families supplied by the bound scene")
	_check(groups.size()==families.size(),"bound scene supplies one route definition per family")
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	_check(CampaignClock.new().configure_date(1928,11,10,20*60),"night campaign fixture is valid")
	Selector.reset_for_tests("v2")
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	_check(not world.startup_failed,"production-selected V2 world starts")
	var held: Array[WeakRef]=[weakref(world)]
	var previous_filter := OS.get_environment("V2_TEST_UNIT")
	var completed_groups: Array[String]=[]
	if failures==0:
		world.player.camera.make_current()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		for family_index in groups.size():
			var group: String=groups[family_index]
			_check(group in ["apartments","completion","remaining","roof"],"known complete route family: "+group)
			if failures>0:break
			var definition: Script=families[family_index]
			var constants: Dictionary=definition.get_script_constant_map()
			for room: String in constants.ROOMS:expected[room]=true
			var descriptors: Array[Dictionary]=[]
			if constants.has("UNITS"):
				for unit: String in constants.UNITS:descriptors.append({"script":constants.DRIVER,"unit":unit})
			else:
				for script: Script in constants.DRIVERS:descriptors.append({"script":script,"unit":""})
			if group=="roof":
				# Preserve the existing carried-light drift control without adding
				# another world or allowing its synthetic transform into gameplay.
				var optical_check: Node=definition.new()
				held.append(weakref(optical_check))
				optical_check._check_light_rotation(world.player)
				for row: Dictionary in optical_check.checks:_check(row.ok,row.label)
				optical_check.free()
			for index in descriptors.size():
				var descriptor: Dictionary=descriptors[index]
				OS.set_environment("V2_TEST_UNIT",descriptor.unit if group=="completion" else "")
				var driver: Node=(descriptor.script as Script).new()
				driver.externally_managed=true;driver.world=world;driver.player=world.player
				if group=="remaining":driver.unit_id=descriptor.unit
				if not str(descriptor.unit).is_empty():driver.route_label=group.to_upper()+" ACCESS "+str(descriptor.unit)
				add_child(driver);held.append(weakref(driver))
				if group=="roof" and index==0:driver._prepare_player_start()
				await driver._route()
				var name: String=group+"/"+str(driver.route_label)
				for row: Dictionary in driver.interaction_checks:_check(row.ok,row.label)
				_check(driver.failures.is_empty() and not driver.trace.is_empty(),"complete collision-bearing leg: "+name)
				legs.append({"name":name,"group":group,"trace":driver.trace.duplicate(true),"failures":driver.failures.duplicate(),"initial_placement_only":true})
				for step: Dictionary in driver.trace:
					if not step.ok:continue
					for room: Dictionary in world.layout.spaces:
						if str(room.id) not in constants.ROOMS:continue
						var y: float=world.adapter.root.level_y[str(room.level)]
						var r: Array=room.rect
						var p: Array=step.actual
						if absf(float(p[1])-y)<.15 and p[0]>r[0]+.05 and p[0]<r[2]-.05 and p[2]>r[1]+.05 and p[2]<r[3]-.05:
							visited[str(room.id)]={"actual":p,"leg":name}
				remove_child(driver);driver.free()
				if failures>0:break
			if failures>0:break
			completed_groups.append(group)
		_check(completed_groups.size()==groups.size(),"every requested family completes before proof is written")
		for room: String in expected:_check(world.adapter.resolve(room)!=null and visited.has(room),"actual walk reaches authored room: "+room)
	OS.set_environment("V2_TEST_UNIT",previous_filter)
	Input.action_release("move_forward")
	world.shutdown_for_tests();remove_child(world);world.free()
	await get_tree().create_timer(.25).timeout
	var retained := 0
	for reference: WeakRef in held:
		if reference.get_ref()!=null:retained+=1
	_check(retained==0,"shared production root and every route/check driver retire")
	var final_inputs := _inputs()
	_check(initial_inputs==final_inputs,"runtime and geometry/surface inputs stay fixed throughout the cohort")
	_check(bindings==_dependencies(),"root, scene and all transitive route sources stay fixed throughout the cohort")
	_write_receipt(retained,held.size(),completed_groups,final_inputs)
	print("V2 SPATIAL ACCESS COHORT: %s; %d rooms; %d legs; %d checks; %d failures" % ["PASS" if failures==0 else "FAIL",visited.size(),legs.size(),checks.size(),failures])
	get_tree().quit(0 if failures==0 else 1)

func _inputs() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array=[];var surface: Array=[]
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"bind current production inputs")
	_check(OS.execute("python",[root.path_join("tools/v2_surface_evidence.py"),"--snapshot"],surface)==0,"bind current geometry/surface inputs")
	var optical: Dictionary=JSON.parse_string(str(surface[0])) if not surface.is_empty() else {}
	return {"runtime":str(runtime[0]).strip_edges() if not runtime.is_empty() else "","surface":str(optical.get("sha256",""))}

func _dependencies() -> Dictionary:
	var pending: Array[String]=[get_script().resource_path]
	_check(scene_file_path.begins_with("res://tests/") and FileAccess.file_exists(scene_file_path),"actual entry scene is source-bound")
	if not scene_file_path.is_empty():pending.append(scene_file_path)
	var result := {}
	var references := RegEx.new()
	references.compile("res://tests/[A-Za-z0-9_/.-]+")
	while not pending.is_empty():
		var path: String=pending.pop_back()
		var relative := "game/"+path.trim_prefix("res://")
		if result.has(relative):continue
		if not FileAccess.file_exists(path):
			_check(false,"transitive test dependency exists: "+path)
			continue
		var text := FileAccess.get_file_as_string(path).replace("\r\n","\n")
		result[relative]=text.sha256_text()
		for match: RegExMatch in references.search_all(text):
			var dependency: String=match.get_string()
			if not result.has("game/"+dependency.trim_prefix("res://")):pending.append(dependency)
	return result

func _write_receipt(retained: int,tracked: int,completed_groups: Array[String],inputs: Dictionary) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	var directory := OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit writable receipt destination")
	var file := FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	_check(file!=null,"open cohort runtime contract")
	if file==null:return
	var status := "PASS" if failures==0 else "FAIL"
	var entry: String="game/"+get_script().resource_path.trim_prefix("res://")
	var contract := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Played room access in one shared production world. Complete route families retain their declared initial placements; roof circuits share one F06 arrival. Subsequent travel uses the normal collision-bearing controller. Physical input replaces inherited E-key toggles. The lift travel request remains a declared stimulus. No inter-floor connection, case completion, disk save, whole-building runtime or human acceptance grant.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":entry,"test_sha256":bindings.get(entry,""),"test_dependencies":bindings,"scene_path":scene_file_path,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":inputs.runtime,"surface_inputs_sha256":inputs.surface},
		"groups":groups,"completed_groups":completed_groups,
		"contracts":{"production_composition":{"executed":true,"status":status},"room_access":{"executed":completed_groups.size()==groups.size(),"status":status,"rooms":visited},"teardown":{"executed":true,"status":status,"measurement_scope":"shared production root and all route/check drivers only","tracked_nodes":tracked,"retained_nodes":retained}},
		"checks":checks,"legs":legs,"failures":failures}
	file.store_string(JSON.stringify(contract,"\t"));file.flush()
	if file.get_error()!=OK:failures+=1;push_error("Cohort runtime contract did not flush")
