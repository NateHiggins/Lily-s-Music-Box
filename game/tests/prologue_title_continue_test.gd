extends Node
## Drives the real title Continue button against an isolated archived save.

var checks := {}

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var source := OS.get_environment("PROLOGUE_CONTINUE_SOURCE")
	var input_hash := FileAccess.get_sha256(source)
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or source.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Title Continue needs a source save and windowed SHOT_DIR")
		get_tree().quit(2)
		return
	var primary := output.path_join("primary.json")
	checks.copied = input_hash.length() == 64 and DirAccess.copy_absolute(source, primary) == OK
	if not checks.copied:
		_finish(output, source, input_hash, {})
		return
	RealityState.save_path = primary
	RealityState.persistence_enabled = true
	RealityState.load_game()
	GameBoot.settings.weather_network_enabled = false
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	CampaignTime.set_frozen_for_tests(true)
	var original: Dictionary = RealityState.data.get("prologue", {}).duplicate(true)
	var clock: Dictionary = RealityState.data.get("campaign_clock", {}).duplicate(true)
	var phase := OS.get_environment("PROLOGUE_CONTINUE_PHASE")
	checks.validated_primary = RealityState.load_status().status == "loaded" and RealityState.can_continue() \
		and original.get("phase") == phase and not RealityState.data.intro_complete
	if not checks.validated_primary:
		_finish(output, source, input_hash, {"load":RealityState.load_status()})
		return
	var title := (load("res://scenes/ui/title_screen.tscn") as PackedScene).instantiate() as OrisonTitleScreen
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await get_tree().process_frame
	await get_tree().process_frame
	checks.real_continue = title._primary_button.text == "CONTINUE"
	if not checks.real_continue:
		_finish(output, source, input_hash, {})
		return
	var title_ref: WeakRef = weakref(title)
	title._primary_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 220000
	var shell: CampaignShell
	var world: OrisonV2RuntimeRoot
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		shell = get_tree().current_scene as CampaignShell
		if shell == null: continue
		world = shell.active_world as OrisonV2RuntimeRoot
		if world != null and (world.startup_failed or world.startup_ms > 0.0): break
	checks.one_waking_world = title_ref.get_ref() == null and shell != null and shell.active_kind == "waking" \
		and shell.world_child_count() == 1 and world != null and not world.startup_failed
	if not checks.one_waking_world:
		_finish(output, source, input_hash, {})
		return
	for tick in 3: await get_tree().physics_frame
	var opening: Node = world.prologue_director
	var actual: Dictionary = opening.state.duplicate(true) if is_instance_valid(opening) else {}
	var carrier: Node = world.service_set_carrier
	checks.installed_owner = is_instance_valid(opening) and opening.get_parent() == world
	checks.saved_phase = actual.get("phase") == phase and actual.get("events") == original.events and actual.get("effects") == original.effects
	checks.saved_clock = RealityState.data.campaign_clock == clock and not RealityState.data.intro_complete
	checks.saved_arrival = is_instance_valid(carrier) and is_instance_valid(carrier.rig) \
		and carrier.is_story_absent() != bool(original.effects.companion_materialized)
	checks.primary_bytes = FileAccess.get_sha256(primary) == input_hash
	var report := {"phase":actual.get("phase"), "effects":actual.get("effects"), "original":original, "ready_ms":world.startup_ms}
	await RenderingServer.frame_post_draw
	checks.capture = get_viewport().get_texture().get_image().save_png(output.path_join("resumed.png")) == OK
	world.shutdown_for_tests()
	await get_tree().process_frame
	_finish(output, source, input_hash, report)

func _finish(out: String, source: String, sha: String, report: Dictionary) -> void:
	checks.producer_unchanged = FileAccess.get_sha256(source) == sha
	var file := FileAccess.open(out.path_join("continue.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"evidence_class":"INERT", "source":source,
			"source_sha256":sha, "checks":checks, "live":report}, "\t"))
		file.close()
	for label: String in checks:
		print("PROLOGUE CONTINUE: ", label, " = ", checks[label])
	get_tree().quit(0 if file != null and not checks.values().has(false) else 1)
