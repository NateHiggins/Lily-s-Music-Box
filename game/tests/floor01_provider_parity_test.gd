extends Node
## Actual CampaignShell/BuildingRoot preparation. Controlled reconstruction,
## not player traversal, streaming, performance, art or human acceptance.

const Surface := preload("res://scripts/building/surface_pass.gd")
const LEGACY_SCENE := "res://scenes/building/orison_root.tscn"
const CANDIDATE_SCENE := "res://tests/fixtures/floor01_provider_candidate_root.tscn"
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var setup_failures: Array[Dictionary] = []
var failures := 0
var mode := ""
var shell: CampaignShell
var world
var directory := ""


func _ready() -> void:
	mode = OS.get_environment("F01_PROVIDER_MODE")
	directory = OS.get_environment("F01_PROVIDER_RECEIPT_DIR")
	if mode not in ["legacy", "owner_first_cells"] or directory.is_empty():
		push_error("provider fixture requires declared mode and fresh receipt directory")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("calendar seeded independently of host time", CampaignClock.new().configure_date(1928, 11, 10, 180.0))
	shell = CampaignShell.new()
	shell.sleep_manual_clock = true
	shell.waking_scene_path = CANDIDATE_SCENE if mode == "owner_first_cells" else LEGACY_SCENE
	add_child(shell)
	world = shell.active_world
	if not _check("real waking root initially composed", _root_ready_for_observation("initial")):
		await _finish()
		return
	await _settle()
	_observe("initial")
	var old_root_id: int = world.get_instance_id()
	var provider = world.get("floor01_geometry_provider")
	var old_target_ids: Array = provider.public_census().registry.get("target_ids", []) if provider != null else []
	world = null
	_check("actual shell replaces waking root", shell._replace_world("waking"))
	world = shell.active_world
	await _settle()
	_check("previous root retired by the shell", not is_instance_id_valid(old_root_id))
	_check("provider references cleared at root exit", provider != null and provider.registry == null)
	var retired := true
	for identity: int in old_target_ids:
		retired = retired and not is_instance_id_valid(identity)
	_check("all previous imported targets retired", retired)
	provider = null
	if _check("real waking destination composed", _root_ready_for_observation("reconstructed")):
		_observe("reconstructed")
	await _finish()


func _root_ready_for_observation(stage: String) -> bool:
	if not is_instance_valid(world):
		setup_failures.append({"stage":stage, "reason":"waking root absent"})
		return false
	var floors: Variant = world.get("floor_nodes")
	var valid_floor: bool = floors is Dictionary and is_instance_valid(floors.get("F01")) and floors.get("F01") is Node3D
	if world.get("startup_failed") != false or not valid_floor:
		var provider = world.get("floor01_geometry_provider")
		setup_failures.append({"stage":stage, "reason":"waking root refused setup or F01 host absent",
				"startup_failed":world.get("startup_failed"), "valid_f01":valid_floor,
				"provider_error":str(provider.error) if provider != null else "provider absent"})
		return false
	return true


func _settle() -> void:
	if world != null and world.get("player") != null:
		world.player.set_physics_process(false)
		world.player.set_process_unhandled_input(false)
	# Root physics/governor and production builders remain live. This is a
	# recorded settle interval, not a fabricated builder-completion signal.
	await get_tree().create_timer(1.6).timeout
	for frame in range(8):
		await get_tree().process_frame


func _observe(stage: String) -> void:
	var provider = world.get("floor01_geometry_provider")
	_check(stage + "/production provider exists", provider != null)
	if provider == null:
		return
	var census: Dictionary = provider.public_census()
	_check(stage + "/explicit geometry mode", str(census.mode) == mode)
	_check(stage + "/current floor dictionary preserved", world.floor_nodes.size() == 8)
	var host: Node3D = world.floor_nodes.get("F01")
	if not _check(stage + "/direct F01 host retained", is_instance_valid(host) and host.get_parent() == world and str(host.name) == "F01"):
		return
	var other_floors := true
	for identity: String in world.FLOOR_SCENES:
		if identity != "F01":
			other_floors = other_floors and world.floor_nodes.has(identity) \
					and world.floor_nodes[identity].scene_file_path == world.FLOOR_SCENES[identity]
	_check(stage + "/off-slice floor imports preserved", other_floors)
	var row := {"stage":stage, "mode":mode, "census":census, "root_id":world.get_instance_id(),
			"readiness":"1.6 seconds plus eight frames; root physics and builders live"}
	if mode == "legacy":
		_check(stage + "/actual legacy imported root retained", host.scene_file_path == "res://assets/building/floor_01.gltf")
		_check(stage + "/candidate registry not mounted", census.registry.is_empty())
		observations.append(row)
		return
	_check(stage + "/host itself owns no imported geometry", host.scene_file_path.is_empty() and not host is GeometryInstance3D)
	_check(stage + "/17 cells and full alias target population", census.registry.cells == 17 \
			and census.registry.targets == 609 and census.registry.aliases == 531 and census.registry.semantics == 189)
	var registry_resource := load("res://data/floor01_provider_registry.tres") as Resource
	var data: Dictionary = registry_resource.get("definition")
	var protected: Dictionary = world._street_core_protected_geometry()
	var multi := 0
	var edges := 0
	var aliases_complete := true
	var import_classes := true
	var exemptions := true
	var passage := true
	var collision := true
	var per_target: Array[Dictionary] = []
	for alias: String in data.aliases:
		var actual: Array[Node3D] = provider.alias_targets(alias)
		var keys: Array = data.aliases[alias]
		if keys.size() > 1:
			multi += 1
		edges += actual.size()
		aliases_complete = aliases_complete and actual.size() == keys.size()
		for index in range(mini(actual.size(), keys.size())):
			var target := actual[index]
			var expected: Dictionary = data.targets[str(keys[index])]
			var actual_class := str(Surface._class_for(str(target.name)).get("key", ""))
			var importer_ok: bool = target.owner != null and target.owner.get_parent() == host
			var exempt_ok: bool = not expected.envelope_exempt or not target is GeometryInstance3D or protected.has(target.get_instance_id())
			var passage_ok := true
			var collision_ok := true
			if target is GeometryInstance3D:
				var role := str(expected.passage_role)
				passage_ok = world.passage_interior_nodes.has(target) == (role == "interior") \
						and world.passage_shell_nodes.has(target) == (role == "shell") \
						and world.passage_foreign_f01_nodes.has(target) == (role == "foreign")
				importer_ok = importer_ok and Surface._is_imported(target) and actual_class == str(expected.surface_class)
			if str(expected.collision_class) != "NONE":
				var shapes: Array[Node] = target.find_children("*", "CollisionShape3D", true, false)
				collision_ok = not shapes.is_empty()
				for shape: CollisionShape3D in shapes:
					collision_ok = collision_ok and shape.shape != null and not shape.disabled
			import_classes = import_classes and importer_ok
			exemptions = exemptions and exempt_ok
			passage = passage and passage_ok
			collision = collision and collision_ok
			per_target.append({"key":keys[index], "alias":alias, "path":str(world.get_path_to(target)),
					"class":target.get_class(), "instance_id":target.get_instance_id(), "import_owner_and_class":importer_ok,
					"envelope_exemption":exempt_ok, "passage_membership":passage_ok, "collision_shapes_present":collision_ok})
	_check(stage + "/all531 aliases retain609 edges including47 expansions", aliases_complete and edges == 609 and multi == 47)
	_check(stage + "/actual importer owners and surface classes agree", import_classes)
	_check(stage + "/all explicit exterior exemptions reach current root", exemptions)
	_check(stage + "/all imported Passage roles reach current root", passage)
	_check(stage + "/import-generated collision shapes remain present", collision)
	row["targets"] = per_target
	observations.append(row)


func _finish() -> void:
	var root_id: int = world.get_instance_id() if is_instance_valid(world) else 0
	world = null
	if is_instance_valid(shell):
		remove_child(shell)
		shell.free()
	shell = null
	await get_tree().process_frame
	await get_tree().process_frame
	var root_retired: bool = root_id == 0 or not is_instance_id_valid(root_id)
	_check("final actual root retired", root_retired)
	var receipt := {"scope":"actual optional all-resident F01 provider reconstruction; no traversal, streaming, save, performance or human acceptance",
			"mode":mode, "checks":checks, "observations":observations, "setup_failures":setup_failures, "failures":failures, "root_retired":root_retired}
	var file := FileAccess.open(directory.path_join("provider.json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("F01_PROVIDER_COMPLETE=" + JSON.stringify({"checks":checks.size(), "failures":failures, "mode":mode}))
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, okay: bool) -> bool:
	checks.append({"label":label, "pass":okay})
	if not okay:
		failures += 1
		print("F01_PROVIDER_FAIL=" + label)
	return okay
