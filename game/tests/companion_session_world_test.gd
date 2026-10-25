extends "res://tests/companion_session_bench.gd"
## Production composition + actual native text input + validated disk reload.
## This contract covers correspondence; it does not accept the whole V2 world.
var world: OrisonV2RuntimeRoot
var runtime_before := ""
var authority_before: Dictionary = {}
var worlds_ready := 0
var owned_nodes := {}
var owned_resources := {}
var owned_playbacks := {}
const AUTHORITIES := ["inventories", "maintenance_items", "maintenance_jobs", "work_orders", "cases", "resident_trust", "conversation_visits", "knowledge_flags"]
const Selector = preload("res://scripts/building/building_root_selector.gd")

func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(740.0).timeout.connect(func():
		if not finished: check(false, "occupied correspondence deadline"); finish())

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	runtime_before = digest()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings["weather_network_enabled"] = false
	# The retired V2 handheld switch must no longer select the old gadget.
	OS.set_environment("ORISON_COMPANION_WORLD", "0")
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	Engine.max_fps = 120
	if not await build_world(): finish(); return
	# Read through the existing inventory owner once before freezing authority
	# facts; its normal legacy seeding is not a companion inventory transaction.
	PersonInventory.pocket_lines()
	for key_name: String in AUTHORITIES: authority_before[key_name] = RealityState.data.get(key_name, {}).duplicate(true)
	await exercise()

func build_world() -> bool:
	world = load(Selector.scene_path()).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0: await get_tree().process_frame
	if not check(not world.startup_failed, "occupied production V2 starts with companion session"): return false
	player = world.player; carrier = world.service_set_carrier
	# Boundary fixtures below deliberately jump civil time back and forward.
	# Freeze autonomous shopping while measuring correspondence's authority
	# neutrality; normal resident movement/presentation remain composed.
	world.resident_agenda.set_process(false)
	player.camera.make_current(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ready := check(carrier.get("session") != null and carrier.get("witness") != null, "production companion binds conversation and witnessed context")
	if ready:
		worlds_ready += 1
		collect_owned()
		var printer: Node = carrier.device.teletype
		check(carrier.device.phosphor_stock and printer.phosphor_stock, "V2 always installs the autonomous phosphor companion despite the retired handheld flag")
		check(printer._hot_writer.phosphor_stock and printer._hot_writer._puff == null, "radioactive companion type creates no thermal smoke emitter")
		var stock: StandardMaterial3D = printer._paper.get_active_material(0)
		check(stock.albedo_color.get_luminance() < .04 and not stock.emission_enabled and not printer.ink.shaded and printer.ink.modulate.g > printer.ink.modulate.r * 2., "charcoal stock and unshaded green glyphs keep independent illumination")
		var maps_valid := true
		for texture: Texture2D in [stock.albedo_texture, stock.roughness_texture, stock.normal_texture]:
			maps_valid = maps_valid and texture != null and texture.get_image().has_mipmaps()
		check(maps_valid, "private phosphor stock retains loaded custom diffuse roughness and normal mip chains")
	return ready

func measure_foreground_cost(_allow_switching := true) -> void:
	# Runtime qualification exercises the shipping foreground path. The ABBA
	# camera-mask/viewport-toggle experiment remains an isolated diagnostic;
	# its original occupied errors are retained, not accepted as clean proof.
	await super.measure_foreground_cost(false)

func capture(filename: String) -> void:
	collect_owned()
	await super.capture(filename)
	if filename in ["typing.png", "reply.png", "calendar_correspondence.png"]:
		var rendered := Image.load_from_file(directory.path_join(filename))
		var region := projected_bounds(carrier.device.teletype._paper).grow(-8.0).intersection(Rect2(Vector2.ZERO, Vector2(rendered.get_size())))
		var green := 0; var dark := 0; var count := 0
		for y in range(ceili(region.position.y), floori(region.end.y)):
			for x in range(ceili(region.position.x), floori(region.end.x)):
				var color := rendered.get_pixel(x,y)
				green += int(color.g > .18 and color.g > color.r * 1.3 and color.g > color.b * 1.15)
				dark += int(maxf(color.r,maxf(color.g,color.b)) < .20)
				count += 1
		var measurement := {"evidence_class":"INERT", "region":str(region), "pixels":count, "green_pixels":green, "dark_fraction":float(dark)/maxi(1,count), "scope":"Rendered colour/framing diagnostic, not human readability acceptance."}
		FileAccess.open(directory.path_join(filename+".pixels.json"),FileAccess.WRITE).store_string(JSON.stringify(measurement,"\t"))

func remember(table: Dictionary, value: Object) -> void:
	if is_instance_valid(value): table[value.get_instance_id()] = weakref(value)

func collect_owned() -> void:
	for node: Node in [carrier] + carrier.find_children("*", "Node", true, false):
		remember(owned_nodes, node)
		if node is CollisionShape3D: remember(owned_resources, node.shape)
		if node is MultiMeshInstance3D: remember(owned_resources, node.multimesh)
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			if node.playing: remember(owned_playbacks, node.call("get_stream_playback"))
	for resource: RefCounted in [carrier._hand, carrier.session.dialogue, carrier.session.dialogue.memory,
			carrier.motion._probe, carrier.motion._ray, carrier.rig.glazing_film,
			carrier.screen_frame._environment, carrier.screen_frame.image.texture]: remember(owned_resources, resource)
	var printer: Node = carrier.device.teletype
	remember(owned_resources, printer.torch_lens.get_active_material(0))
	remember(owned_resources, printer._paper.get_active_material(0))
	for jewel: MeshInstance3D in printer._jewels: remember(owned_resources, jewel.get_active_material(0))

func retained(table: Dictionary) -> int:
	var count := 0
	for reference: WeakRef in table.values():
		if reference.get_ref() != null: count += 1
	return count

func reading_catalog() -> NewspaperCatalog:
	return world.newspapers

func additional_checks() -> void:
	var context: Dictionary = carrier.witness.context()
	check(str(context.get("objective", "")) == world.objective_tracker.supplied_body, "physical help reads current owner-supplied objective even with overlay disabled")
	var weather := await ask_actual("weather")
	var date: Dictionary = world.campaign_clock.local_datetime()
	var as_of := "%sT%02d:%02d" % [CampaignWeather.date_key(date), date.hour, date.minute]
	check(str(weather.get("intent", "")) == "weather" and str(weather.get("output", "")).contains(CampaignWeather.print_time(as_of)), "actual typed weather query prints the campaign as-of observation")
	var news := await ask_actual("newspaper")
	check(str(news.get("intent", "")) == "newspaper" and str(news.get("output", "")).contains("Count of Tuesday") \
		and str(news.get("output", "")).contains(world.newspapers.long_date("1928-11-10")), "actual typed newspaper query uses the edition witnessed by the production reading owner")
	await capture("calendar_correspondence.png")
	await key(KEY_ENTER)
	if await wait_for(func(): return carrier.session.typing):
		await type_text("help")
		await key(KEY_ESCAPE)
	check(carrier.session.draft == "help", "actual Escape keeps unsent draft after calendar exchanges")

func ask_actual(text: String) -> Dictionary:
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "native keyboard ready for " + text): return {}
	await select_all()
	await type_text(text)
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return not carrier.device.teletype.printing), "physical reply finishes for " + text): return {}
	await get_tree().create_timer(.5).timeout
	var ink: Label3D = carrier.device.teletype.ink
	check(projected_bounds(carrier.rig.glazing).grow(2.0).encloses(projected_aabb(ink, ink.get_aabb())), "settled calendar page fits inside reading glass for " + text)
	return carrier.session.dialogue.memory.history.back().duplicate(true) if not carrier.session.dialogue.memory.history.is_empty() else {}

func finish() -> void:
	if finished: return
	finished = true
	RealityState.persistence_enabled = false
	if is_instance_valid(world) and not world.startup_failed and saved_campaign:
		collect_owned()
		var comparisons := {}
		for key_name: String in AUTHORITIES:
			var after: Variant = RealityState.data.get(key_name, {})
			comparisons[key_name] = {"before":authority_before.get(key_name, {}), "after":after}
			check(domain_value(after) == domain_value(authority_before.get(key_name, {})), "correspondence preserves authority: " + key_name)
		FileAccess.open(directory.path_join("authority_comparison.json"), FileAccess.WRITE).store_string(JSON.stringify(comparisons, "\t"))
		var memory: Dictionary = carrier.session.dialogue.memory.snapshot()
		var draft: String = carrier.session.draft
		world.shutdown_for_tests(); world.queue_free()
		await frames(3)
		RealityState.load_game()
		if await build_world():
			check(carrier.session.dialogue.memory.snapshot() == memory and carrier.session.draft == draft, "fresh occupied world reconstructs saved companion memory and draft")
			check(carrier.witness.last_read.is_empty() and carrier.session._events.is_empty(), "fresh world has no revived transient witnesses")
			await capture("reconstructed_companion.png")
		world.shutdown_for_tests(); world.queue_free()
		await frames(3)
	await get_tree().create_timer(.2).timeout
	var live_nodes := retained(owned_nodes)
	var live_resources := retained(owned_resources)
	var live_playbacks := retained(owned_playbacks)
	check(worlds_ready == 2 and live_nodes == 0 and live_resources == 0 and live_playbacks == 0, "both companion instances retire measured owned nodes, resources and observed audio playbacks")
	var source_after := digest()
	check(not runtime_before.is_empty() and runtime_before == source_after, "runtime source remains frozen through composition and reconstruction")
	var failures := checks.filter(func(record: Dictionary): return not record.passed)
	var status := "PASS" if failures.is_empty() else "FAIL"
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head)
	var sources := {}
	for path: String in ["companion_session_world_test.gd", "companion_session_bench.gd"]:
		sources["game/tests/" + path] = FileAccess.get_file_as_string("res://tests/" + path).replace("\r\n", "\n").sha256_text()
	var contract := {"schema_version":2, "evidence_kind":"runtime_contract", "selector":"v2", "production_runtime":true,
		"execution":{"completed":true, "exit_code":0 if failures.is_empty() else 1, "timed_out":false},
		"scope":"Occupied V2 correspondence: real key events, physical keyboard/paper, protected input, power/call/pause interruptions, bounded campaign save and fresh-world reconstruction. No whole-world navigation, surface acceptance, frame-time improvement or human acceptance.",
		"source":{"test_path":"game/tests/companion_session_world_test.gd", "test_sha256":FileAccess.get_sha256(get_script().resource_path), "runtime_inputs_sha256":source_after, "repository_head":str(head[0]).strip_edges() if not head.is_empty() else "", "test_sources":sources},
		"contracts":{"production_composition":{"executed":worlds_ready == 2,"status":status,"identities":["companion", "keyboard", "paper"]},
			"companion_correspondence":{"executed":true,"status":status}, "save_reconstruction":{"executed":worlds_ready == 2,"status":status},
			"premature_action_denial":{"executed":checks.any(func(row: Dictionary): return row.name == "protected owner refuses new typing" and row.passed),"status":status},
			"teardown":{"executed":worlds_ready == 2,"status":status,"measurement_scope":"runtime_owned", "ownership_scope":"Companion subtree nodes, conversation/memory/hand, native query and collision shapes, tile/key MultiMeshes, per-instance glazing/lens/paper/jewel materials and observed active audio playbacks. Shared native meshes, catalogue materials and sound/font assets excluded.",
				"observed_nodes":owned_nodes.size(),"observed_resources":owned_resources.size(),"observed_playbacks":owned_playbacks.size(),"retained_nodes":live_nodes,"retained_resources":live_resources,"retained_playbacks":live_playbacks}},
		"checks":checks, "failures":failures}
	FileAccess.open(directory.path_join("companion_correspondence_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(contract, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func digest() -> String:
	var result: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], result) != 0: return ""
	return str(result[0]).strip_edges() if not result.is_empty() else ""

func domain_value(value: Variant) -> Variant:
	# JSON numbers read as doubles. Compare quantities exactly while allowing
	# the integer/double representation accepted by their existing validators.
	if value is int or value is float: return float(value)
	if value is Dictionary:
		var result := {}
		for key_name: String in value: result[key_name] = domain_value(value[key_name])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(domain_value(entry))
		return result
	return value
