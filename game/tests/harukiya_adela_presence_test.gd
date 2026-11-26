extends Node3D
## Focused production composition, civil attendance, native column and real input.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const NativeChecks := preload("res://tests/harukiya_staff_occupancy_test.gd")
const Standing := preload("res://scripts/characters/standing_occupancy.gd")
const REQUIRED := ["adela_dated_subjects", "adela_civil_presence", "adela_native_column", "adela_real_conversation", "adela_retained_shutdown", "adela_custody_cleanup"]
var world: OrisonV2RuntimeRoot
var cast: Node3D
var actor: Node3D
var native_checks: Node3D
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {"contexts": [], "native": [], "captures": []}
var output := ""
var started := 0
var prior_data: Dictionary
var prior_text := ""
var prior_files: Dictionary = {}
var prior_mode := 0
var prior_mouse := 0
var prior_frozen := false
var captured := false
var lease := false
var initial_inputs: Dictionary = {}
var logger: Logger
var actor_id := 0
var staff_ids: Dictionary = {}
var initial_stance_used := false
var retired := false
var started_speakers: Array[String] = []
var ended_speakers: Array[String] = []
var speech_witnesses: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures.append(label)
		print("HARUKIYA ADELA FAIL: ", label)
	return ok

func _contract(id: String, before: int) -> void:
	contracts[id] = {"executed": true, "status": "PASS" if failures.size() == before else "FAIL"}

func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or FileAccess.file_exists(output.path_join("runtime_contract.json")):
		output = "C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/early_error_" + str(Time.get_ticks_usec())
		_check(false, "fresh explicit SHOT_DIR required")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_check(false, "requested diagnostic destination is unwritable")
		output = "C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/early_error_" + str(Time.get_ticks_usec())
		if DirAccess.make_dir_recursive_absolute(output) != OK:
			push_error("Adela test cannot write requested or private fallback destination")
			get_tree().quit(2); return
	for id: String in REQUIRED: contracts[id] = {"executed": false, "status": "NOT_RUN"}
	logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(logger)
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data, "", true, true)
	prior_files = _save_files()
	prior_mode = GameBoot.launch_mode
	prior_mouse = Input.mouse_mode
	prior_frozen = CampaignTime._frozen_for_tests
	captured = true
	initial_inputs = _inputs()
	var profile: String = OS.get_environment("ADELA_PRESENCE_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var actual: String = OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	_check(profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/") and actual == profile and OS.get_user_data_dir().replace("\\", "/").simplify_path() == profile.path_join("PleaseRemainOnTheLine"), "dedicated APPDATA before autoload")
	_check(DisplayServer.get_name() != "headless", "real rendered production world")
	for key: String in ["SCHEDULE", "SCHEDULE_DAY", "SCHEDULE_DOY", "SCHEDULE_MINUTE", "SCHEDULE_FIRST_SAT", "AGENDA", "CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(), "no chronology override " + key)
	if not failures.is_empty(): await _finish(); return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent campaign preview"): await _finish(); return
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	if not _check(CampaignClock.new().configure_date(1929, 6, 14, 1200), "actual civil Friday stage context"): await _finish(); return
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _check(not world.startup_failed and world.bar_region != null and world.harukiya_counter != null and world.player != null, "complete actual runtime composition"):
		await _finish(); return
	cast = world.harukiya_counter.get("cast") as Node3D
	if not _check(cast != null and bool(cast.get("ready_ok")) and (cast.get("performers") as Dictionary).has("adela_voss"), "actual single existing cast owner has measured Adela"):
		await _finish(); return
	actor = (cast.get("performers") as Dictionary).adela_voss as Node3D
	actor_id = actor.get_instance_id()
	var staff: Dictionary = cast.get("actors")
	_check(staff.size() == 2 and staff.has("stacy") and staff.has("lily"), "original counter staff dictionary remains exactly two")
	for id: String in ["stacy", "lily"]: staff_ids[id] = staff[id].get_instance_id()
	world.conversations.conversation_started.connect(_on_started)
	world.conversations.conversation_ended.connect(_on_ended)
	world.conversations.dialogue.node_shown.connect(_on_line)
	var before: int = failures.size()
	await _dated_subjects()
	_contract("adela_dated_subjects", before)
	before = failures.size()
	# Empty schedule gaps are genuine resolver results, never invented shop/out blocks.
	for row: Array in [[6,14,1139,false,""], [6,14,1140,true,"harukiya_bar"], [6,15,0,true,"harukiya_bar"], [6,15,45,false,"out"], [6,18,1140,true,"harukiya_bar"], [6,18,1259,true,"harukiya_bar"], [6,18,1260,false,""], [7,19,1262,false,"roof"], [7,19,1263,false,"out"], [7,20,1200,false,"out"]]:
		await _context(int(row[0]), int(row[1]), int(row[2]), bool(row[3]), str(row[4]))
	await _context(6,14,1200,true,"harukiya_bar")
	# Civil boundary fixtures jump faster than the existing seven-second room
	# refresh. Let its real owner settle before judging ordinary bar rendering.
	var light_deadline:=Time.get_ticks_msec()+9000
	while int(world.bar_region.hours.get("_state"))!=HarukiyaStateDirector.BarState.OPEN and Time.get_ticks_msec()<light_deadline:
		await get_tree().create_timer(.1).timeout
	_check(int(world.bar_region.hours.get("_state"))==HarukiyaStateDirector.BarState.OPEN,"actual room-hours owner settles to open after civil fixture changes")
	var original_parts: Array = actor.call("worn_parts")
	var original_column: Dictionary = Standing.read(actor)
	_check(not bool(actor.call("wear", ["not_a_measured_outfit"])), "unknown performer outfit refused")
	_check(actor.call("worn_parts") == original_parts and Standing.read(actor) == original_column, "refusal preserves actual stage wardrobe and measured column")
	_contract("adela_civil_presence", before)
	before = failures.size()
	native_checks = NativeChecks.new()
	native_checks.set_meta("shared_world_validation", true)
	add_child(native_checks)
	native_checks.set("bar", world.bar_region)
	native_checks.set("cast", cast)
	native_checks.set("counter", world.harukiya_counter)
	var heads: Array = actor.get("model").find_children("Skin_head","MeshInstance3D",true,false)
	var paint: StandardMaterial3D = heads[0].material_overlay as StandardMaterial3D if heads.size()==1 else null
	if _check(paint!=null and paint.normal_enabled and paint.normal_texture!=null and paint.roughness_texture!=null and paint.metallic_texture!=null,"actual stage makeup carries complete physical maps"):
		var skin: StandardMaterial3D = heads[0].get_active_material(0) as StandardMaterial3D
		_check(skin!=paint and skin.normal_texture==paint.normal_texture and skin.roughness_texture==paint.roughness_texture and skin.metallic_texture==paint.metallic_texture,"makeup privately retains actual head maps without changing shared skin")
		for texture: Texture2D in [paint.albedo_texture,paint.normal_texture,paint.roughness_texture,paint.metallic_texture]:
			var image: Image=texture.get_image()
			_check(image!=null and image.has_mipmaps(),"actual makeup loaded texture has mipmaps")
	var column: Dictionary = Standing.read(actor)
	if _check(not column.is_empty() and not bool(column.get("invalid", false)), "actual Adela measured column before native query"):
		native_checks.call("_native_column", "adela_voss", "stage", column)
		var native_failures: Variant = native_checks.get("failures")
		_check(native_failures is Array and native_failures.is_empty(), "unchanged native support/upper/counter-negative checks pass")
		details.native = native_checks.get("details").duplicate(true)
	_contract("adela_native_column", before)
	# Keep actual native failures, but still exercise independent real input.
	before = failures.size()
	await _conversation()
	_contract("adela_real_conversation", before)
	await _capture("adela_actual_stage")
	await _retained_shutdown()
	await _finish()


## Sample the rebuilt skeleton's measured rest front before anyone calls to her.
func _dated_subjects() -> void:
	var owner := world.get_node_or_null("AdelaDatedEncounters")
	if not _check(owner != null, "installed dated Adela owner"): return
	for row: Array in [[1928,11,10,550,"photo_supplies","av_window"], [1929,7,11,1090,"roof","av_key11"], [1929,7,19,1086,"lobby","av_nineteen"]]:
		if not _check(world.campaign_clock.configure_date(row[0], row[1], row[2], row[3]) and world.campaign_clock.bind_state(), "dated mark clock " + str(row[5])): continue
		await get_tree().create_timer(.35).timeout
		await get_tree().physics_frame
		var resident := owner.get("actor") as AnimatedResident
		if not _check(is_instance_valid(resident) and resident.installed_topic == str(row[5]), "dated body present " + str(row[5])): continue
		var mark: Dictionary = owner.call("_stance", str(row[4]))
		var wanted: Vector3 = mark.facing - resident.global_position
		var body := resident.cast_body
		var facing: Vector3 = body.skeleton.global_basis * body.attention.pipeline.profile.forward
		var alignment := Vector2(wanted.x, wanted.z).normalized().dot(Vector2(facing.x, facing.z).normalized())
		_check(alignment > .99, "%s faces its authored subject (%.4f)" % [str(row[5]), alignment])

func _context(month: int, day: int, minute: int, present: bool, place: String) -> void:
	_check(world.campaign_clock.configure_date(1929, month, day, minute), "civil fixture date accepted")
	_check(world.campaign_clock.bind_state(), "actual runtime clock rebinds fixture snapshot")
	await get_tree().create_timer(.35).timeout
	await get_tree().physics_frame
	var where: Dictionary = world.resident_whereabouts("adela_voss")
	_check(str(where.get("place", "")) == place, "real resolver location " + str([month,day,minute,place]))
	_check(actor.get_instance_id() == actor_id and ((cast.get("performers") as Dictionary).size() == 1), "same single performer reused")
	var interaction: Area3D = actor.get("interaction") as Area3D
	_check(interaction != null and interaction.collision_layer == (1 if present else 0) and interaction.collision_mask == 0, "actual performer ray layer follows attendance")
	_check(actor.is_visible_in_tree() == present and actor.is_in_group("animated_residents") == present, "visible/group attendance matches civil resolver")
	var column: Dictionary = Standing.read(actor)
	_check((not column.is_empty() and not bool(column.get("invalid", false))) if present else (column.is_empty() or bool(column.get("invalid", false))), "active measured versus inactive refused column")
	var staff: Dictionary = cast.get("actors")
	var staff_here: bool = world.harukiya_counter.call("on_shift")
	for id: String in staff_ids:
		var present_here: bool = staff_here if id == "stacy" else str(world.resident_whereabouts(id).get("place", "")) == "harukiya_bar"
		_check(staff.has(id) and staff[id].get_instance_id() == int(staff_ids[id]) and staff[id].is_visible_in_tree() == present_here, "original actor follows her own attendance " + id)
	details.contexts.append({"date":[1929,month,day],"minute":minute,"whereabouts":where,"present":present,"column":column,"staff_on_shift":staff_here})

func _ray() -> Dictionary:
	var camera: Camera3D = world.player.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 2.1, 1)
	query.collide_with_areas = true
	query.exclude = [world.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _conversation() -> void:
	var marker: Node3D = world.bar_region.destination.get_node_or_null("Navigation/stage_front") as Node3D
	if not _check(marker != null and not initial_stance_used, "one authored nearby player initial stance"): return
	world.player.global_position = marker.global_position
	initial_stance_used = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var interaction: Area3D = actor.get("interaction") as Area3D
	world.player.camera.look_at(actor.global_position + Vector3.UP * 1.15, Vector3.UP)
	await get_tree().process_frame
	var hit: Dictionary = _ray()
	if not _check(not hit.is_empty() and hit.collider == interaction, "actual ordinary2.1m player ray reaches Adela interaction area"): return
	_check(not world.player.call_locked and not actor.call("interact_prompt").is_empty(), "actual player and authored target available")
	if not await _mapped_interact(): return
	await get_tree().create_timer(.4).timeout
	var panel: CaseDialoguePanel = world.conversations.dialogue
	_check(started_speakers.has("adela_voss") and str(world.conversations.get("_active_resident")) == "adela_voss" and panel.attention_active(), "ordinary mapped input starts authored Adela conversation")
	_check(str(cast.get("_speaker")) == "adela_voss", "same performer receives actual speaker callback")
	var line: Dictionary = panel.displayed_line()
	_check(not str(line.get("text", "")).strip_edges().is_empty(), "existing authored line displayed")
	_check(panel.current_node_id=="ad_singing", "actual bar interaction opens authored social entry rather than studio services")
	var spoke: bool = false
	for witness: Dictionary in speech_witnesses:
		if witness.speaker == "adela" and bool(witness.owner_speech_active): spoke = true
	_check(spoke, "actual authored Adela node activates same actor speech callback")
	details.conversation = {"line":line,"speech_witnesses":speech_witnesses,"player_at":world.player.global_position,"actor_id":actor_id,"ray_collider":str(interaction.get_path()),"speaker":cast.get("_speaker")}
	await _capture("adela_authored_conversation")
	world.conversations.cancel_for_transition()
	await get_tree().process_frame
	_check(ended_speakers.has("adela_voss") and str(cast.get("_speaker")).is_empty() and not panel.attention_active() and not world.player.call_locked, "existing transition authority closes panel and speaker/input lease")

func _mapped_interact() -> bool:
	var selected: InputEvent
	for source: InputEvent in InputMap.action_get_events("interact"):
		if source is InputEventJoypadButton: selected = source; break
	if selected == null:
		for source: InputEvent in InputMap.action_get_events("interact"):
			if source is InputEventMouseButton: selected = source; break
	if not _check(selected != null, "actual registered controller interact mapping available"): return false
	for pressed: bool in [true,false]:
		var event: InputEvent = selected.duplicate() as InputEvent
		if event is InputEventJoypadButton:
			(event as InputEventJoypadButton).pressed = pressed
		else:
			(event as InputEventMouseButton).pressed = pressed
			(event as InputEventMouseButton).position = get_viewport().get_visible_rect().size * .5
			(event as InputEventMouseButton).global_position = (event as InputEventMouseButton).position
		# Polled controller actions require global Input state, not viewport-only dispatch.
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().physics_frame
	return true

func _on_started(id: String, _entry: String) -> void: started_speakers.append(id)
func _on_ended(id: String) -> void: ended_speakers.append(id)

func _on_line(_id: String) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(world): return
	var line: Dictionary = world.conversations.dialogue.displayed_line()
	var face: Node = actor.get("face") as Node
	if face == null: return
	speech_witnesses.append({"speaker":str(line.get("speaker", "")).strip_edges().to_lower(), "text":str(line.get("text", "")), "owner_speech_active":float(face.get("_speech_ends")) > float(face.get("_speech_clock")), "cast_speaker":cast.get("_speaker")})

func _retained_shutdown() -> void:
	if retired or not is_instance_valid(world) or not is_instance_valid(cast): return
	var before: int = failures.size()
	world.conversations.cancel_for_transition()
	world.bar_region.shutdown()
	retired = true
	await get_tree().physics_frame
	for body: Node3D in (cast.get("actors") as Dictionary).values() + (cast.get("performers") as Dictionary).values():
		_check(is_instance_valid(body) and not body.is_visible_in_tree() and not body.is_in_group("animated_residents"), "retained shutdown hides/unregisters same body " + str(body.name))
	if is_instance_valid(actor):
		var interaction: Area3D = actor.get("interaction") as Area3D
		_check(interaction != null and interaction.collision_layer == 0 and str(actor.call("interact_prompt")).is_empty(), "retained performer ray/verb has no ghost")
		if initial_stance_used:
			var hit: Dictionary = _ray()
			_check(hit.is_empty() or hit.collider != interaction, "actual retained-world ray cannot hit retired performer")
	_contract("adela_retained_shutdown", before)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var path: String = output.path_join(label + ".png")
	if _check(picture != null and not picture.is_empty() and picture.save_png(path) == OK, "rendered capture " + label):
		details.captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})

func _save_files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".txn", ".tmp"]:
		var path: String = RealityState.save_path + suffix
		result[suffix] = {"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _inputs() -> Dictionary:
	var root: String = ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime_digest: Array = []; var physical: Array = []
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime_digest) == 0, "runtime source binding")
	_check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical) == 0, "physical source binding")
	var dependencies: Dictionary = {}
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/harukiya_staff_occupancy_test.gd", "res://tests/guide_bell_error_capture.gd"]:
		dependencies[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return {"runtime_inputs_sha256":str(runtime_digest[0]).strip_edges() if not runtime_digest.is_empty() else "", "physical_inputs_sha256":str(physical[0]).strip_edges() if not physical.is_empty() else "", "dependencies":dependencies}

func _finish() -> void:
	var before: int = failures.size()
	await _retained_shutdown()
	if is_instance_valid(native_checks): native_checks.free()
	if is_instance_valid(world): world.shutdown_for_tests(); world.free()
	if lease:
		_check(RealityState.end_preview_campaign(self), "preview returned")
		lease = false
	if captured:
		GameBoot.launch_mode = prior_mode
		Input.mouse_mode = prior_mouse
		CampaignTime.set_frozen_for_tests(prior_frozen)
		_check(is_same(RealityState.data,prior_data) and JSON.stringify(RealityState.data,"",true,true) == prior_text, "original campaign identity and values restored")
		_check(_save_files() == prior_files, "save backup/transaction bytes unchanged")
		_check(_inputs() == initial_inputs, "source inputs unchanged")
	var engine_errors: Array = logger.get("errors") if logger != null else []
	if logger != null: OS.remove_logger(logger)
	_check(engine_errors.is_empty(), "genuine engine errors empty")
	_contract("adela_custody_cleanup", before)
	for id: String in REQUIRED:
		_check(bool(contracts[id].executed) and str(contracts[id].status) == "PASS", "required focused contract " + id)
	var passed: bool = failures.is_empty()
	var result: Dictionary = {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":true,"selector":"v2","suite":"HarukiyaAdelaPresenceTest","status":"PASS" if passed else "FAIL","scope":"Actual RuntimeRoot Adela stage attendance via civil resolver, same actor and original two staff, measured native column/support/upper-obstruction/counter-negative, ordinary mapped player interaction and authored conversation callbacks, retained-world ghost-free shutdown. One declared initial nearby player stance. No natural all21 arrival, walking/seated fit, performance qualification, seven-stop/NPC lift or artistic acceptance.","execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},"source":initial_inputs,"contracts":contracts,"checks":checks,"failures":failures,"engine_errors":engine_errors,"details":details}
	result.source.test_path = "game/" + get_script().resource_path.trim_prefix("res://")
	result.source.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
	result.source.test_scene_path = "game/" + scene_file_path.trim_prefix("res://")
	result.source.test_scene_sha256 = FileAccess.get_sha256(scene_file_path)
	var file: FileAccess = FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	get_tree().quit(0 if passed and written else 1)
