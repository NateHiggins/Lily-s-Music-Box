extends "res://tests/v2_region_access_driver.gd"
## Continue a private copy of a completed-prologue save. The clock driver
## supplies accelerated elapsed time. Place the player once on the public
## sidewalk; from there only direction and ordinary dialogue controls are used.
const REHEARSAL := "av_offer"
const HEARD := ResidentConversations.MYSTERY_HEARD_PREFIX + REHEARSAL
const LIFE := preload("res://scripts/game/prologue_state.gd")
const START := "1929-03-18T17:05:00"
var shots := OS.get_environment("SHOT_DIR")
var checks: Array[Dictionary] = []
var evidence := {}
var started := Time.get_ticks_msec()


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		checks.back()["observed"] = _snapshot()
		push_error(label)
	return ok


func _run() -> void:
	var seed := OS.get_environment("HARUKIYA_SEED_SHA256").to_lower()
	if shots.is_empty() or seed.length() != 64 or FileAccess.file_exists(shots.path_join("runtime_contract.json")):
		get_tree().quit(2)
		return
	if not _check(FileAccess.get_sha256(RealityState.save_path) == seed and RealityState.can_continue()
			and str(RealityState.data.get("prologue", {}).get("phase", "")) == "prologue_complete", "private completed-prologue primary ready to continue"):
		_finish()
		return
	evidence.seed_sha256 = seed
	# Remain as an independent witness while the real title changes scene.
	get_tree().current_scene = null
	if not _check(get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn") == OK, "normal title opens"):
		_finish()
		return
	await get_tree().scene_changed
	var primary := get_tree().current_scene.find_child("PrimaryCampaignAction", true, false) as Button
	if not _check(primary != null and primary.is_visible_in_tree() and not primary.disabled, "normal title offers its saved campaign"):
		_finish()
		return
	primary.pressed.emit()
	while Time.get_ticks_msec() - started < 300000:
		await get_tree().process_frame
		world = get_tree().get_first_node_in_group("building_root") as OrisonV2RuntimeRoot
		if world != null and world.startup_ms > 0.0 and not world.startup_failed:
			break
	if not _check(world != null and world.harukiya_counter != null and GameBoot.launch_mode == GameBoot.LaunchMode.CINEMATIC, "Continue mounted the ordinary V2 world"):
		_finish()
		return
	player = world.player
	var shell := get_tree().current_scene as CampaignShell
	while shell != null and shell.owns_opening_veil(world) and Time.get_ticks_msec() - started < 360000:
		await get_tree().process_frame
	if not _check(shell != null and shell.active_world == world and not shell.owns_opening_veil(world)
			and world.prologue_director != null and world.player_unit() == "4B" and not player.protected_input_active(), "Continue released the waking player at the real bedside"):
		_finish()
		return
	await _visit()
	_finish()


func _civil(target: String) -> bool:
	var clock := world.campaign_clock
	var initial := clock.datetime_string()
	var remaining := Time.get_unix_time_from_datetime_string(target) - Time.get_unix_time_from_datetime_string(initial)
	if remaining < 0:
		remaining += LIFE.LOOP_SECONDS
	if not _check(remaining >= 0 and remaining < LIFE.LOOP_SECONDS, "target is in the ordinary annual cycle " + target): return false
	CampaignTime._process(float(remaining))
	await get_tree().physics_frame
	await get_tree().create_timer(0.45).timeout
	evidence[target] = {"initial": initial, "elapsed_seconds": remaining, "observed": clock.datetime_string(), "player": str(player.global_position)}
	return _check(clock.datetime_string().left(16) == target.left(16) and not world.temporal_loop.in_visit(), "elapsed present time reaches " + target)


func _visit() -> void:
	var panel := world.conversations.dialogue
	var cast: Node3D = world.harukiya_counter.cast
	var nav: Node3D = world.bar_region.destination.get_node("Navigation")
	var leaf: DoorProp = world.bar_region.doors.F01_BAR_RED_DOOR
	if not _check(not RealityState.has_knowledge(HEARD) and not RealityState.has_knowledge("m_concern_letter")
			and not world.temporal_loop.in_visit() and world.conversations.playtest_date.is_empty(), "fresh narrative knowledge in an unmodified present"):
		return
	evidence.continue_position = str(player.global_position)
	if not await _civil(START): return
	var sidewalk: Vector3 = nav.get_node("entry_sidewalk").global_position
	evidence.sidewalk_target = str(sidewalk)
	player.global_position = sidewalk + Vector3.UP * 0.04
	player.velocity = Vector3.ZERO
	if not await _settle_start(sidewalk): return
	observer = Observer.new()
	observer.configure(world)
	add_child(observer)
	await get_tree().physics_frame
	var adela: Node3D = cast.performers.adela_voss
	var lily: Node3D = cast.actors.lily
	var stacy: Node3D = cast.actors.stacy
	if not _check(world.resident_whereabouts("lily").place == "harukiya_bar" and lily.is_visible_in_tree() and adela.is_visible_in_tree() and not stacy.visible
			and not world.harukiya_counter.on_shift(), "Adela and Lily attend the closed-bar Monday rehearsal; Stacy is off duty"): return
	var lilies := get_tree().get_nodes_in_group("animated_residents").filter(func(actor): return str(actor.get("resident_id")) == "lily")
	_check(lilies == [lily] and not world.resident_routes.has("lily"), "exactly one physical Lily is active")
	if not _check(leaf.leaf_state == "closed" and leaf.passage_allowed() and not leaf.open, "the ordinary closed red door allows entry in the caretaker's current state"): return
	# Player-sized west aisle from the original exterior and found-trace routes.
	# The resident crate detour clips the edge of the newspaper pile underfoot.
	evidence.crate_detour_support = _foot_support(nav.get_node("entry_crate_lower").global_position)
	var waypoints := ["entry_outside","entry_descent_01","entry_descent_02","entry_descent_03","entry_descent_foot","entry_threshold","entrance","backstage_entrance","backstage_public_axis","backstage","stage_e","stage_front"]
	for id: String in waypoints:
		var point: Vector3 = nav.get_node(id).global_position
		var previous_count := trace.size()
		var arrived := await _walk(world.adapter.root.to_local(point), 0.16)
		if trace.size() <= previous_count: return
		trace.back()["waypoint"] = id
		trace.back()["support"] = _foot_support(player.global_position)
		trace.back()["leaf"] = {"open": leaf.open, "cleared": leaf.is_ready_for_passage(), "angle": leaf._body.rotation.y}
		if not arrived:
			trace.back()["observed"] = _snapshot()
			# The failed endpoint stays in failures. Collect later evidence only
			# when we actually reached the planar mark, standing within one step.
			var gap := point - player.global_position
			if not player.is_on_floor() or Vector2(gap.x, gap.z).length() >= 0.18 or absf(gap.y) > 0.30 or trace.back().support.is_empty(): return
		if id == "entrance" and not _check(leaf.open and leaf.is_ready_for_passage(), "ordinary directional entry opened and cleared the real leaf"): return
	var target: Area3D = adela.get("interaction")
	player.camera.look_at(adela.global_position + Vector3.UP * 1.15)
	await get_tree().process_frame
	var start := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(start, start - player.camera.global_basis.z * 2.1, 1, [player.get_rid()])
	ray.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	evidence.touch = {"from": str(start), "to": str(ray.to), "desired": str(target.get_path()), "adela": str(adela.global_position),
			"point": str(hit.get("position")), "hit": str(hit.collider.get_path()) if not hit.is_empty() else ""}
	if not _check(hit.get("collider") == target, "player's 2.1 m interaction ray meets the actual Adela"): return
	for source: InputEvent in InputMap.action_get_events("interact"):
		if source is InputEventJoypadButton:
			for pressed: bool in [true, false]:
				var event := source.duplicate() as InputEventJoypadButton
				event.pressed = pressed
				Input.parse_input_event(event)
				await get_tree().process_frame
				await get_tree().physics_frame
			break
	await get_tree().create_timer(0.3).timeout
	var topic := "Don't mind me. I'm here for the radiator."
	evidence.offered = panel.offered_labels()
	if not _check(panel.attention_active() and panel.offered_labels().has(topic), "normal speech with Adela offers the authored radiator topic"): return
	var index := panel.offered_labels().find(topic)
	var button := panel._choices.get_child(index) as Button
	button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(panel.current_node_id == "av_o1" and RealityState.has_knowledge(HEARD) and RealityState.has_knowledge("m_concern_letter"), "actual topic opens the two bars and records its existing knowledge"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join("rehearsal.png"))
	var nodes: Array[String] = []
	evidence.heard_nodes = nodes
	while panel.attention_active() and nodes.size() < 80:
		nodes.append(panel.current_node_id)
		if not _check(panel.offered_labels().size() == 1, "only the authored silence on " + panel.current_node_id): return
		await _key(KEY_0)
	if not _check(nodes.size() == 66 and nodes.back() == "av_o66" and not panel.attention_active() and not player.call_locked, "all 66 authored beats end and return player control"): return
	if not await _civil("1929-03-19T16:10:00"): return
	_check(world.harukiya_counter.on_shift() and stacy.visible and world.resident_whereabouts("lily").place != "harukiya_bar" and not lily.visible and not adela.visible, "next afternoon opens Stacy's shift while Lily and Adela are elsewhere")


func _settle_start(target: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	var stable := 0
	var samples: Array[Dictionary] = []
	evidence.start_samples = samples
	var ray := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 0.3, target + Vector3.DOWN * 0.3, 1, [player.get_rid()])
	for frame in 150:
		await get_tree().physics_frame
		var ground := player.get_world_3d().direct_space_state.intersect_ray(ray)
		var support := str(ground.collider.get_path()) if not ground.is_empty() else ""
		var slope := float(ground.normal.dot(Vector3.UP)) if not ground.is_empty() else 0.0
		var distance := player.global_position.distance_to(target)
		var ok := slope > 0.8 and player.is_on_floor() and distance < 0.18
		stable = stable + 1 if ok else 0
		if frame < 5 or frame % 15 == 0 or stable == 4 or Time.get_ticks_msec() >= deadline:
			samples.append({"physics_frame": Engine.get_physics_frames(), "position": str(player.global_position),
					"on_floor": player.is_on_floor(), "distance": distance, "support": support, "normal_y": slope, "velocity": str(player.velocity)})
		if stable == 4:
			evidence.sidewalk_support = support
			break
		if Time.get_ticks_msec() >= deadline: break
	return _check(stable == 4, "ordinary public sidewalk supports the player after campaign time advances")


func _snapshot() -> Dictionary:
	var result := {"scene": str(get_tree().current_scene), "can_continue": RealityState.can_continue(),
			"prologue": RealityState.data.get("prologue", {}).get("phase"), "launch_mode": GameBoot.launch_mode}
	if not is_instance_valid(world) or not is_instance_valid(player): return result
	result.civil_time = world.campaign_clock.datetime_string()
	result.visit = world.temporal_loop.in_visit()
	result.playtest_date = world.conversations.playtest_date
	result.unit = world.player_unit()
	result.position = str(player.global_position)
	result.velocity = str(player.velocity)
	result.on_floor = player.is_on_floor()
	result.opening_placed = world._opening_placed
	result.opening_retry_live = is_instance_valid(world._opening_retry) and not world._opening_retry.is_stopped()
	result.mouse_released = player.mouse_released
	result.call_locked = player.call_locked
	result.physics = player.is_physics_processing()
	result.collision_mask = player.collision_mask
	result.heard = RealityState.has_knowledge(HEARD)
	result.letter = RealityState.has_knowledge("m_concern_letter")
	var panel := world.conversations.dialogue
	result.dialogue = {"active": panel.attention_active(), "node": panel.current_node_id, "labels": panel.offered_labels()}
	var leaf: DoorProp = world.bar_region.doors.F01_BAR_RED_DOOR
	result.leaf = {"path": str(leaf.get_path()), "allowed": leaf.passage_allowed(), "open": leaf.open, "ready": leaf.is_ready_for_passage(), "state": leaf.leaf_state}
	var cast: Node3D = world.harukiya_counter.cast
	var actors: Dictionary = cast.actors.duplicate()
	actors.merge(cast.performers)
	result.actors = {}
	for id: String in actors:
		result.actors[id] = {"place": world.resident_whereabouts(id).get("place", ""), "path": str(actors[id].get_path()),
				"position": str(actors[id].global_position), "visible": actors[id].is_visible_in_tree()}
	result.counter = world.harukiya_counter.on_shift()
	return result


func _foot_support(base: Vector3) -> Array[Dictionary]:
	var supports: Array[Dictionary] = []
	var radius := player._capsule.radius * 0.92
	for offset: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var at := base + offset * radius
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.31, at + Vector3.DOWN * 0.34, 1, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP) > 0.7:
			supports.append({"offset": str(offset * radius), "at": str(hit.position), "collider": str(hit.collider.get_path())})
	return supports


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _finish() -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	var digest: Array = []
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty()
			and OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest) == 0 and not digest.is_empty(), "receipt binds the source")
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
			"source": {"repository_head": str(head[0]).strip_edges(), "runtime_inputs_sha256": str(digest[0]).strip_edges(),
				"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
				"test_scene_path": "game/tests/HarukiyaRehearsalRouteTest.tscn", "test_scene_sha256": FileAccess.get_sha256("res://tests/HarukiyaRehearsalRouteTest.tscn")},
			"execution": {"completed": true, "timed_out": false, "exit_code": 0 if failures.is_empty() else 1, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"contracts": {"rehearsal_present_route": {"executed": not evidence.is_empty(), "status": "PASS" if failures.is_empty() else "FAIL"}},
			"scope": "Public sidewalk through March 18 closed-bar entrance to Adela, on ordinary civil time with accelerated elapsed seconds.",
			"checks": checks, "walk": trace, "observations": evidence, "failures": failures}
	var file := FileAccess.open(shots.path_join("runtime_contract.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("[HARUKIYA REHEARSAL] %d checks, %d waypoints, %d failures" % [checks.size(), trace.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
