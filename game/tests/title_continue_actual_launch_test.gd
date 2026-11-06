extends Node
## A real title button -> GameBoot -> SceneTree scene change -> CampaignShell.
## The observer is outside the retiring title scene, not a scene-change stub.

const BEDROOM_FIXTURE_SHA := "eeca8b7a8476f5d312a74b0f481ff9118fb3d78aab82896f849e6297040633e7"
const NOOK_OWNER := "nook_books_library"
const NOOK_STOCK := "nook_books__Volume0"
const NOOK_TITLE_SCENE := "res://tests/TitleContinueActualLaunchTest.tscn"
const NOOK_CONTRACT_NAME := "nook_title_continue.runtime.json"
const NOOK_SOURCE_SNAPSHOT_CODE: String="""import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'tools'))
from v2_surface_evidence import file_hash,test_dependency_paths
from run_receipt import runtime_inputs_sha256
seeds=[root/sys.argv[2],root/sys.argv[3],root/'game/tests/native_debug_window.gd']
seeds += [root/'tools/run_receipt.py',root/'tools/v2_surface_evidence.py']
seeds += [root/'game/tests/v2_book_inspection_return_world.gd',root/'game/tests/V2BookInspectionReturnWorld.tscn']
paths=test_dependency_paths(root,seeds)
producer={key:hashlib.sha256(Path(value).read_bytes()).hexdigest()
          for key,value in zip(('manifest','wrapper','primary'),sys.argv[4:7],strict=True)}
print(json.dumps({'runtime_inputs_sha256':runtime_inputs_sha256(root),
                  'test_dependencies':{p.relative_to(root).as_posix():file_hash(p) for p in sorted(paths)},
                  'producer_raw_sha256':producer}))
"""
var _nook_export: Dictionary = {}

class LaunchObserver extends Node:
	var expected: Dictionary
	var expected_bytes: PackedByteArray
	var expected_absolute: float
	var elapsed := 0.0
	var done := false
	var action := "continue"
	var timed_bedroom := false
	var packed_washer := false
	var nook_export: Dictionary = {}
	var nook_observations: Array[Dictionary] = []
	var nook_source_before: Dictionary = {}
	var nook_source_after: Dictionary = {}
	var nook_test_path := ""
	var nook_scene_path := ""
	var nook_script_node_path := ""
	var timing := {}
	var born_anchor_utc := Time.get_unix_time_from_system()
	var born_anchor_usec := Time.get_ticks_usec()
	var action_usec := 0

	func mark(label: String) -> void:
		timing[label] = Time.get_ticks_usec()

	func owns_bedroom_control(shell: CampaignShell, world: OrisonV2RuntimeRoot) -> bool:
		var player := world.player
		var opening := world.prologue_director
		return is_instance_valid(player) and is_instance_valid(opening) \
			and opening.state.phase == "bedroom_exploration" and not get_tree().paused \
			and player.text_input_owner == null and not player.call_locked \
			and not player.protected_input_active() and not player.mouse_released \
			and not player.inspecting() and not player.noclip and player.is_on_floor() \
			and (player._grab == null or not player._grab.active()) \
			and player.camera.is_current() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not shell.owns_opening_veil(world) and shell.get_node_or_null("OpeningLoadingVeil") == null

	func measure_bedroom_control(shell: CampaignShell, world: OrisonV2RuntimeRoot, checks: Dictionary) -> void:
		var deadline := Time.get_ticks_msec() + 60000
		var observed_phases: Array[String] = []
		while true:
			var opening: Node = world.prologue_director
			if action == "continue" and is_instance_valid(opening):
				var phase: String = opening.state.phase
				if not observed_phases.has(phase):
					observed_phases.append(phase)
			if owns_bedroom_control(shell, world) or Time.get_ticks_msec() >= deadline:
				break
			await get_tree().process_frame
		if action == "continue":
			timing["observed_prologue_phases"] = observed_phases
		checks["real_bedroom_releases_all_control_owners"] = owns_bedroom_control(shell, world)
		if not checks.real_bedroom_releases_all_control_owners:
			return
		mark("bedroom_control_ready")
		var player := world.player
		var before_yaw: float = player.rotation.y
		var recoveries: int = world.safety_net.recoveries
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(12, 0)
		mark("look_input_sent")
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await get_tree().process_frame
		checks["normal_mouse_look_reaches_player"] = owns_bedroom_control(shell, world) and absf(player.rotation.y - before_yaw) > .0001
		if checks.normal_mouse_look_reaches_player:
			mark("look_confirmed")
		var start: Vector3 = player.global_position
		mark("move_input_sent")
		for input_action: String in ["move_forward", "move_back"]:
			Input.action_press(input_action)
			for frame in 18:
				await get_tree().physics_frame
				var shift: Vector3 = player.global_position - start
				if Vector2(shift.x, shift.z).length() >= .015:
					mark("horizontal_motion_confirmed")
					break
			Input.action_release(input_action)
			if timing.has("horizontal_motion_confirmed"):
				break
		checks["ordinary_movement_reaches_player_without_recovery"] = timing.has("horizontal_motion_confirmed") \
			and owns_bedroom_control(shell, world) and world.safety_net.recoveries == recoveries
		var view := get_viewport()
		timing["settings"] = {"resolution": var_to_str(view.get_visible_rect().size),
			"msaa": view.msaa_3d, "taa": view.use_taa, "scale": view.scaling_3d_scale,
			"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
			"fov": player.camera.fov, "weather_network_enabled": GameBoot.settings.weather_network_enabled}


	func bind_nook_source(test_path: String, scene_path: String, script_node_path: String) -> bool:
		nook_test_path = test_path
		nook_scene_path = scene_path
		nook_script_node_path = script_node_path
		var started := Time.get_ticks_usec()
		nook_source_before = _nook_source_snapshot()
		timing["nook_source_binding_before_title_action_usec"] = Time.get_ticks_usec() - started
		if nook_scene_path != NOOK_TITLE_SCENE or nook_source_before.is_empty() \
				or nook_source_before.runtime_inputs_sha256 != nook_export.source.runtime_inputs_sha256:
			return false
		var dependencies: Dictionary = nook_source_before.test_dependencies
		var producer_dependencies: Dictionary = nook_export.source.get("test_dependencies", {})
		if producer_dependencies.is_empty():
			return false
		for path: String in producer_dependencies:
			if dependencies.get(path) != producer_dependencies[path]:
				return false
		return dependencies.get("game/tests/v2_book_inspection_return_world.gd") == nook_export.get("test_sha256") \
			and dependencies.get("game/tests/V2BookInspectionReturnWorld.tscn") == nook_export.get("scene_sha256")

	func _nook_source_snapshot() -> Dictionary:
		var root: String = ProjectSettings.globalize_path("res://..").simplify_path()
		var test := "game/" + nook_test_path.trim_prefix("res://")
		var scene := "game/" + nook_scene_path.trim_prefix("res://")
		var output: Array = []
		var status := OS.execute("python", ["-B", "-c", NOOK_SOURCE_SNAPSHOT_CODE, root, test, scene,
			nook_export.manifest_path, nook_export.wrapper_path, nook_export.primary_path], output)
		if status != 0 or output.is_empty():
			return {}
		var data: Variant = JSON.parse_string(str(output[0]))
		if data is not Dictionary or str(data.get("runtime_inputs_sha256", "")).length() != 64:
			return {}
		var dependencies: Dictionary = data.get("test_dependencies", {})
		if str(dependencies.get(test, "")).length() != 64 or str(dependencies.get(scene, "")).length() != 64:
			return {}
		return data

	func _nook_sources_match() -> bool:
		var started := Time.get_ticks_usec()
		nook_source_after = _nook_source_snapshot()
		timing["nook_source_binding_after_controls_usec"] = Time.get_ticks_usec() - started
		return nook_source_before == nook_source_after

	func _write_nook_contract(checks: Dictionary, executed: bool, failures: int, reason := "") -> bool:
		var test := "game/" + nook_test_path.trim_prefix("res://")
		var scene := "game/" + nook_scene_path.trim_prefix("res://")
		var dependencies: Dictionary = nook_source_before.get("test_dependencies", {})
		var passed := executed and failures == 0
		var record: Dictionary = {
			"schema_version":2, "evidence_kind":"runtime_contract", "selector":"v2", "production_runtime":true,
			"scope":"Actual title Continue of one guarded real-input nook fixture through validated load, new waking world, and ordinary bedroom control.",
			"execution":{"completed":true, "exit_code":0 if passed else 1, "timed_out":false},
			"source":{"test_path":test, "test_sha256":dependencies.get(test, ""), "scene_path":nook_scene_path,
				"scene_sha256":dependencies.get(scene, ""), "script_node_path":nook_script_node_path,
				"test_dependencies":dependencies, "runtime_inputs_sha256":nook_source_before.get("runtime_inputs_sha256", "")},
			"programme":{"completed":passed, "checks":checks, "reason":reason, "source_after":nook_source_after,
				"consumer_pid":OS.get_process_id(), "fixture_sha256":nook_export.primary_sha256,
				"fixture_size":nook_export.primary_size, "pre_title_input":timing.get("pre_title_save", {}),
				"producer_manifest_sha256":nook_export.manifest_sha256, "producer_wrapper_sha256":nook_export.wrapper_sha256,
				"producer_raw_sha256":nook_source_before.get("producer_raw_sha256", {}), "producer_source":nook_export.source,
				"producer_primary_path":nook_export.primary_path, "producer_manifest_path":nook_export.manifest_path,
				"producer_wrapper_path":nook_export.wrapper_path, "expected_row":nook_export.saved_row,
				"observations":nook_observations},
			"contracts":{"nook_title_continue":{"attempted":action_usec > 0, "executed":executed, "passed":passed}}}
		var path := OS.get_environment("SHOT_DIR").path_join(NOOK_CONTRACT_NAME)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Nook title Continue contract could not be opened")
			return false
		file.store_string(JSON.stringify(record, "\t", true, true))
		var written := file.get_error() == OK
		file.close()
		if not written:
			push_error("Nook title Continue contract could not be written")
		return written

	func _same_nook_orientation(before: Array, after: Array, offset: int) -> bool:
		# The owner reconstructs a Basis before serializing its quaternion again.
		for axis in range(offset, offset + 4):
			if absf(float(before[axis]) - float(after[axis])) > .0000001:
				return false
		return true

	func _same_reconstructed_library(before: Dictionary, after: Dictionary) -> bool:
		var comparable := after.duplicate(true)
		for key: String in ["books", "bookends"]:
			for identity: String in before[key]:
				if not comparable[key].has(identity): return false
				var expected: Dictionary = before[key][identity]
				var actual: Dictionary = comparable[key][identity]
				var expected_body: Dictionary = expected.body if key == "books" else expected
				var actual_body: Dictionary = actual.body if key == "books" else actual
				if not _same_nook_orientation(expected_body.rotation, actual_body.rotation, 0): return false
				actual_body.rotation = expected_body.rotation
		if before.slots.size() != comparable.slots.size(): return false
		for index in before.slots.size():
			if not _same_nook_orientation(before.slots[index], comparable.slots[index], 3): return false
			for axis in range(3, 7): comparable.slots[index][axis] = before.slots[index][axis]
		return before == comparable

	func observe_nook(shell: CampaignShell, world: OrisonV2RuntimeRoot) -> bool:
		if world.adapter == null or not is_instance_valid(world.household_state) or not is_instance_valid(world.player):
			return false
		var owner: Node3D = world.adapter.resolve(NOOK_OWNER)
		var stock: Node3D = owner._books.get(NOOK_STOCK) if is_instance_valid(owner) else null
		var state_record: Dictionary = RealityState.data.get(world.household_state.KEY, {}).get("records", {}).get(NOOK_OWNER, {}).get("value", {})
		var record: Dictionary = JSON.parse_string(JSON.stringify(state_record, "", true, true))
		var saved_row: Dictionary = nook_export.saved_row
		var observed: Dictionary = {"waking":shell.world_kind(), "world_count":shell.world_child_count(),
			"shell_instance":shell.get_instance_id(), "world_instance":world.get_instance_id(),
			"owner_instance":owner.get_instance_id() if owner != null else 0,
			"book_instance":stock.get_instance_id() if stock != null else 0,
			"persisted_library_sha256":JSON.stringify(record, "", true, true).sha256_text()}
		nook_observations.append(observed)
		if not is_instance_valid(stock) or not owner.valid_library(record):
			return false
		var player := world.player
		var live: Dictionary = owner.library_snapshot()
		var live_ids: Array = live.books.keys()
		var saved_ids: Array = record.books.keys()
		live_ids.sort()
		saved_ids.sort()
		var body: Dictionary = saved_row.body
		var wanted := Vector3(body.position[0], body.position[1], body.position[2])
		var rotation := Quaternion(body.rotation[0], body.rotation[1], body.rotation[2], body.rotation[3])
		var saved_velocity := Vector3(body.velocity[0], body.velocity[1], body.velocity[2])
		var saved_spin := Vector3(body.spin[0], body.spin[1], body.spin[2])
		var basis: Basis = stock.basis
		observed.body = stock.book_snapshot()
		observed.library_matches_archived = _same_reconstructed_library(nook_export.library_record, record)
		observed.pose_error_m = stock.position.distance_to(wanted)
		observed.rotation_agreement = absf(rotation.dot(basis.get_rotation_quaternion()))
		observed.velocity_error_mps = stock.linear_velocity.distance_to(saved_velocity)
		observed.spin_error_radps = stock.angular_velocity.distance_to(saved_spin)
		observed.membership_matches = live_ids == saved_ids
		observed.no_hand_or_inspection = owner._hand_node == null and not stock._held \
			and not player.inspecting() and not player._grab.active() and player.held_stock_body() == null
		observed.no_carrier_exceptions = not player.get_collision_exceptions().has(stock) \
			and not stock.get_collision_exceptions().has(player)
		return observed.waking == "waking" and observed.world_count == 1 and stock.shelf == owner \
			and observed.library_matches_archived \
			and live.geometry == record.geometry and live.order == record.order and observed.membership_matches \
			and stock.shelf_slot == -1 and not stock.freeze and stock.sleeping \
			and float(observed.velocity_error_mps) < .00001 and float(observed.spin_error_radps) < .00001 \
			and float(observed.pose_error_m) < .0001 and float(observed.rotation_agreement) > .999999 \
			and is_equal_approx(float(stock.opening), float(saved_row.opening)) \
			and observed.no_hand_or_inspection and observed.no_carrier_exceptions

	func _process(delta: float) -> void:
		if done:
			return
		elapsed += delta
		var shell := get_tree().current_scene as CampaignShell
		if shell != null and shell.active_world != null:
			if timed_bedroom and not timing.has("world_published"):
				mark("world_published")
			if shell.active_world is OrisonV2RuntimeRoot:
				if shell.active_world.startup_ms <= 0.0 and not shell.active_world.startup_failed:
					return
				if action != "continue" and not shell.active_world.startup_failed:
					var opening: Node = shell.active_world.prologue_director
					if opening == null or not is_instance_valid(opening.waking) or not opening.waking.active:
						if elapsed < 45.0:return
			done = true
			_verify(shell)
		elif ((timed_bedroom or packed_washer) and action_usec > 0 \
				and Time.get_ticks_usec() - action_usec > (360000000 if packed_washer else 240000000)) \
				or (not timed_bedroom and not packed_washer and elapsed > 30.0):
			done = true
			push_error("Actual title Continue never published a CampaignShell world")
			if not nook_export.is_empty():
				_write_nook_contract({"source_fixed":_nook_sources_match(), "waking_world_published":false},
					false, 1, "waking world publication deadline")
			get_tree().quit(1)

	func _verify(shell: CampaignShell) -> void:
		var world := shell.active_world
		await get_tree().physics_frame
		await get_tree().physics_frame
		var clock := world.get("campaign_clock") as CampaignClock
		var actual := {}
		for key in expected:
			actual[key] = RealityState.data.get(key, {})
		actual = JSON.parse_string(JSON.stringify(actual))
		var checks := {
			"selected_waking_root_matches_session": world.scene_file_path == BuildingRootSelector.scene_path(),
			"actual_scene_changed_to_campaign_shell": get_tree().current_scene == shell,
			"real_world_has_player": is_instance_valid(world.get("player")) and not bool(world.get("startup_failed")),
			"exact_calendar_and_semantic_facts_preserved": actual == expected,
			"real_destination_clock_bound": clock != null and clock.bind_state()
					and (action != "continue" or absf(clock.absolute_minutes() - expected_absolute) < 0.00001),
			"title_scene_retired": get_tree().root.find_child("PrimaryCampaignAction", true, false) == null,
		}
		if action != "continue":
			checks["fresh_campaign_has_no_previous_job_or_item"] = RealityState.data.maintenance_jobs.is_empty() \
					and RealityState.data.maintenance_items.is_empty()
			checks["new_campaign_clock_starts_at_injected_time"] = clock != null \
					and int(RealityState.data.campaign_clock.start_minute_of_day) == 13 * 60 + 27
			if world is OrisonV2RuntimeRoot:
				var opening: Node = world.prologue_director
				checks["normal_title_launch_starts_real_dream"] = is_instance_valid(opening) \
						and is_instance_valid(opening.waking) and opening.waking.active and opening.state.phase == "dream"
				checks["old_arrival_does_not_manufacture_onboarding_or_shift"] = not bool(RealityState.data.intro_complete) \
						and RealityState.data.first_shift in [{}, {"phase": FirstShiftDirector.PHASE_ARRIVED}] \
						and RealityState.data.maintenance_jobs.is_empty()
				checks["opening_owns_camera_and_input_without_identity_leak"] = is_instance_valid(opening) \
						and is_instance_valid(opening.waking) and world.player.text_input_owner == opening.waking \
						and opening.waking.camera.is_current() and not world.player_avatar.visible \
						and bool(world.service_set_carrier.call("is_story_absent"))
				await get_tree().process_frame
				checks["loading_veil_retires_after_actual_opening_starts"] = shell.find_child("OpeningLoadingVeil", false, false) == null
				var preparation: Dictionary=world.opening_render_preparation
				checks["entry_render_preparation_finishes_before_handoff"] = bool(preparation.get("completed",false)) \
						and bool(preparation.get("node_pose_unchanged",false)) and not bool(preparation.get("cancelled",true))
				if DisplayServer.get_name()!="headless":
					checks["entry_render_preparation_uses_real_renderer"] = bool(preparation.get("executed",false)) \
							and int(preparation.get("render_calls",0))==10
				else:
					checks["headless_entry_does_not_claim_rendering"] = not bool(preparation.get("executed",true)) \
							and preparation.get("reason","")=="headless_no_rendering"

				# Let the real presentation run, rather than seeking its clock or
				# treating a startup flag as proof of the camera/input handoff.
				if OS.get_environment("PROLOGUE_TITLE_FULL_SEQUENCE")=="1":
					var route:=preload("res://tests/prologue_tutorial_route.gd").new()
					route.externally_managed=true;route.use_installed_director=true
					route.world=world;route.player=world.player
					get_tree().root.add_child(route)
					await route._route()
					checks["actual_title_full_input_route_passes"]=route.failures.is_empty() and is_instance_valid(route.frame_trace) and route.frame_trace.complete
					checks["full_opening_keeps_installed_director"]=is_same(opening,route.director) and world.prologue_director==opening
					checks["full_opening_acknowledges_intro_without_inventing_shift"]=opening.state.phase=="prologue_complete" and bool(RealityState.data.intro_complete) and RealityState.data.maintenance_jobs.is_empty() and RealityState.data.first_shift in [{},{"phase":FirstShiftDirector.PHASE_ARRIVED}]
					checks["full_title_route_has_no_failed_interactions"]=route.interaction_checks.all(func(row:Dictionary)->bool:return row.ok) and route.trace.size()>0
					route.queue_free();await get_tree().process_frame
				elif timed_bedroom:
					await measure_bedroom_control(shell, world, checks)
					checks["fresh_opening_preserves_intro_and_job_boundary"] = not bool(RealityState.data.intro_complete) \
						and RealityState.data.maintenance_jobs.is_empty()
				elif is_instance_valid(opening) and is_instance_valid(opening.waking):
					await get_tree().create_timer(6.0).timeout
					await _capture("dream")
					await get_tree().create_timer(11.0).timeout
					checks["uninterrupted_opening_restores_control_in_bedroom"] = opening.state.phase == "bedroom_exploration" \
							and world.player.camera.is_current() and world.player.text_input_owner == null \
							and opening.message_id == "wake_passed" and not bool(RealityState.data.intro_complete)
					checks["title_pointer_hands_off_to_captured_mouse_look"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
							and not world.player.mouse_released and not world.player.call_locked
					var before_look: float = world.player.rotation.y
					var motion := InputEventMouseMotion.new()
					motion.relative = Vector2(12, 0)
					Input.parse_input_event(motion)
					Input.flush_buffered_events()
					await get_tree().process_frame
					checks["first_mouse_motion_reaches_real_player_after_waking"] = absf(world.player.rotation.y - before_look) > 0.0001
			else:
				checks["normal_title_launch_starts_first_shift"] = bool(RealityState.data.intro_complete) \
						and world.get("first_shift_director").ritual_phase() == FirstShiftDirector.PHASE_ARRIVED
		elif world is OrisonV2RuntimeRoot and timed_bedroom:
			if not nook_export.is_empty():
				checks["fresh_nook_owner_restores_real_mutated_binding_before_input"] = observe_nook(shell, world)
			await measure_bedroom_control(shell, world, checks)
			if not nook_export.is_empty():
				checks["fresh_nook_binding_stays_restored_through_input"] = observe_nook(shell, world)
				checks["restored_nook_owner_and_binding_remain_same_instances"] = nook_observations.size() == 2 \
					and nook_observations[0].owner_instance == nook_observations[1].owner_instance \
					and nook_observations[0].book_instance == nook_observations[1].book_instance
				checks["nook_continue_preserves_campaign_authority_through_input"] = true
				for key: String in nook_export.authority:
					var actual_value: Variant = JSON.parse_string(JSON.stringify(RealityState.data.get(key)))
					if actual_value != expected[key]:
						checks["nook_continue_preserves_campaign_authority_through_input"] = false
			checks["saved_bedroom_resumes_without_dream_replay"] = timing.observed_prologue_phases == ["bedroom_exploration"] \
				and RealityState.data.prologue.phase == "bedroom_exploration" and world.opening_render_preparation.get("completed", false)
			timing["after_input_clock"] = JSON.parse_string(JSON.stringify(RealityState.data.campaign_clock))
			checks["saved_bedroom_clock_stays_exact_through_input"] = timing.after_input_clock == expected.campaign_clock
		elif world is OrisonV2RuntimeRoot:
			checks["legacy_completed_save_does_not_replay_replacement_opening"] = world.prologue_director == null \
					and not shell.uses_prologue_entry() and bool(RealityState.data.intro_complete)
		if packed_washer:
			checks["packed_paid_washer_restores_one_hidden_counter_body"] = _packed_washer_restored(world)
		var directory := OS.get_environment("SHOT_DIR")
		if not directory.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("title_" + action + "_arrival.png"))
		var nook_executed := false
		if not nook_export.is_empty():
			nook_executed = action_usec > 0 and get_tree().current_scene == shell and world is OrisonV2RuntimeRoot
			checks["nook_actual_continue_reaches_selected_waking_world"] = nook_executed
			checks["nook_consumer_sources_and_producer_inputs_stay_fixed"] = _nook_sources_match()
		# Real world initialization may commit additive facts. Primary bytes are
		# retained as evidence, but a byte-identity claim would overstate scope.
		var failures := 0
		for key in checks:
			print("[TITLE ACTUAL CONTINUE] %s %s" % ["PASS" if checks[key] else "FAIL", key])
			if not checks[key]:
				failures += 1
		var receipt := {"checks": checks, "expected_facts": expected, "actual_facts": actual,
				"onboarding": {"intro_complete": RealityState.data.intro_complete,
					"first_shift": RealityState.data.first_shift.duplicate(true),
					"prologue_phase": RealityState.data.get("prologue", {}).get("phase", "")},
				"selected_root": world.scene_file_path, "source_primary_bytes": expected_bytes.size(),
				"post_world_primary_bytes": FileAccess.get_file_as_bytes(RealityState.save_path).size(),
				"entry_render_preparation":world.opening_render_preparation.duplicate(true) if world is OrisonV2RuntimeRoot else {},
				"scope": "actual title button and scene transition with explicit campaign-time freeze; no human traversal"}
		if timed_bedroom:
			receipt["timing"] = timing
			receipt["engine_identity"] = {"pid": OS.get_process_id(), "executable": OS.get_executable_path(),
				"observer_anchor_utc": born_anchor_utc, "observer_anchor_usec": born_anchor_usec, "receipt_anchor_utc": Time.get_unix_time_from_system(), "receipt_anchor_usec": Time.get_ticks_usec()}
			receipt["startup_ms"] = world.get("startup_ms")
			receipt["scope"] = "Fresh native process and isolated profile. Actual title input through bedroom mouse look and movement. OS and driver caches are uncontrolled."
		if not nook_export.is_empty():
			receipt["nook_continue"] = {"evidence_class":"INERT", "fixture_sha256":nook_export.primary_sha256,
				"producer_manifest_sha256":nook_export.manifest_sha256, "producer_source":nook_export.source,
				"owner":NOOK_OWNER, "stock_id":NOOK_STOCK, "expected_row":nook_export.saved_row,
				"observations":nook_observations, "post_primary_sha256":FileAccess.get_sha256(RealityState.save_path),
				"timing_scope":"Source binding before title action and after controls. Birth-to-control is not comparable to the original timing run."}
		var path := OS.get_environment("TITLE_ACTUAL_RECEIPT")
		if not path.is_empty():
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(receipt, "\t"))
				file.close()
			else:
				failures += 1
		if not nook_export.is_empty():
			if not _write_nook_contract(checks, nook_executed, failures):
				failures += 1
		shell.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		print("[TITLE ACTUAL CONTINUE] checks=%d failures=%d" % [checks.size(), failures])
		get_tree().quit(0 if failures == 0 else 1)

	func _packed_washer_restored(world: Node) -> bool:
		if not world is OrisonV2RuntimeRoot or world.startup_failed:
			return false
		var item := CarriedCase.MAINTENANCE_WASHER
		var counter: Node = world.fire_maintenance_counter
		var body: RigidBody3D = counter.pickups.get(item) if is_instance_valid(counter) else null
		return is_instance_valid(body) and body.freeze and not body.visible \
			and body.collision_layer == 0 and body.collision_mask == 0 and not counter.can_take(body) \
			and world.maintenance_inventory.has_item(item) and not world.maintenance_inventory.is_consumed(item) \
			and world.player.held_stock_body() == null and CarriedCase.washer_is_packed(RealityState.data)

	func _capture(label: String) -> void:
		var directory := OS.get_environment("SHOT_DIR")
		if directory.is_empty() or DisplayServer.get_name() == "headless":return
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("title_" + action + "_" + label + ".png"))


func _ready() -> void:
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	var action := OS.get_environment("TITLE_ACTUAL_ACTION")
	if action.is_empty(): action = "continue"
	if OS.get_environment("PROLOGUE_TITLE_FULL_SEQUENCE")=="1":
		if action!="begin":get_tree().quit(2);return
		OS.set_environment("PROLOGUE_FULL_SEQUENCE","1")
	if action not in ["continue", "begin", "new"]:
		get_tree().quit(2)
		return
	var timed_bedroom := OS.get_environment("TITLE_ACTUAL_TIMED_BEDROOM") == "1"
	if OS.get_environment("TITLE_ACTUAL_NOOK_CONTINUE") == "1" and (not timed_bedroom or action != "continue"):
		push_error("Nook title witness requires the original timed bedroom Continue route")
		get_tree().quit(2)
		return
	if OS.get_environment("TITLE_ACTUAL_PACKED_WASHER") == "1":
		var profile := OS.get_environment("TITLE_ACTUAL_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
		var raw_sha := OS.get_environment("TITLE_ACTUAL_PACKED_PRIMARY_SHA")
		var clock := CampaignClock.new()
		if action != "continue" or timed_bedroom or not profile.begins_with("C:/ov/reports/develop_intake_20261104/") \
				or OS.get_user_data_dir().replace("\\", "/").simplify_path() != profile.path_join("PleaseRemainOnTheLine") \
				or raw_sha.length() != 64 or FileAccess.get_sha256(RealityState.SAVE_PATH) != raw_sha \
				or RealityState.load_status().status != "loaded" or not RealityState.can_continue() \
				or not CarriedCase.washer_is_packed(RealityState.data) or not clock.bind_state():
			push_error("Packed washer Continue requires its exact validated producer primary in an isolated profile")
			get_tree().quit(2)
			return
		GameBoot.settings.weather_network_enabled = false
		await _launch(action, clock, false, true)
		return
	if timed_bedroom:
		if action not in ["begin", "continue"] or not _verify_timing_profile(action):
			get_tree().quit(2)
			return
		GameBoot.settings.weather_network_enabled = false
		seed(1928)
	if timed_bedroom and action == "continue":
		var saved_clock := CampaignClock.new()
		if not saved_clock.bind_state():
			get_tree().quit(2)
			return
		_launch(action, saved_clock, true)
		return
	RealityState.save_path = "user://tests/title_actual_%s_%s/campaign.json" % [
			action, Crypto.new().generate_random_bytes(8).hex_encode()]
	RealityState.persistence_enabled = true
	if FileAccess.file_exists(RealityState.save_path):
		get_tree().quit(2)
		return
	RealityState.load_game()
	RealityState.new_campaign_time_provider = func(): return {"hour": 13, "minute": 27}
	if action != "begin" and not RealityState.start_new_campaign():
		get_tree().quit(2)
		return
	var clock := CampaignClock.new()
	if action != "begin" and (not clock.configure_date(1928, 11, 10, 1439) or not clock.advance_to(181.5)):
		get_tree().quit(2)
		return
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
			"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
	RealityState.data.core_loop = {"safe_return_anchor": "F04_B_BED", "boundary": "wake_complete",
			"active_job_id": "", "conversation_requested": false,
			"conversation_complete": false, "dream_pending": false}
	if action != "begin" and not RealityState.save_game():
		get_tree().quit(2)
		return
	RealityState.load_game()
	_launch(action, clock, timed_bedroom)

func _verify_timing_profile(action: String) -> bool:
	var expected := OS.get_environment("TITLE_ACTUAL_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var actual := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	if expected.is_empty() or actual != expected or not expected.begins_with("C:/ov/reports/develop_intake_20261104/") \
			or OS.get_user_data_dir().replace("\\", "/").simplify_path() != expected.path_join("PleaseRemainOnTheLine"):
		push_error("Title timing requires the explicit isolated APPDATA")
		return false
	if action == "begin":
		return not FileAccess.file_exists(RealityState.SAVE_PATH)
	var nook_requested := OS.get_environment("TITLE_ACTUAL_NOOK_CONTINUE") == "1"
	var expected_sha := BEDROOM_FIXTURE_SHA
	if nook_requested:
		_nook_export = _admit_nook_export()
		expected_sha = str(_nook_export.get("primary_sha256", ""))
	var valid: bool = not expected_sha.is_empty() and FileAccess.get_sha256(RealityState.SAVE_PATH) == expected_sha \
		and RealityState.load_status().status == "loaded" and RealityState.can_continue() \
		and not RealityState.save_write_blocked and RealityState.data.prologue.phase == "bedroom_exploration"
	if not valid:
		push_error("Current validation did not accept the nook export" if nook_requested else "Current validation did not accept the original bedroom fixture")
	return valid

func _admit_nook_export() -> Dictionary:
	var manifest_path := OS.get_environment("TITLE_ACTUAL_NOOK_EXPORT_MANIFEST")
	var manifest_sha := OS.get_environment("TITLE_ACTUAL_NOOK_EXPORT_MANIFEST_SHA")
	var receipt_path := OS.get_environment("TITLE_ACTUAL_RECEIPT")
	var shot_dir := OS.get_environment("SHOT_DIR")
	if manifest_path.is_empty() or manifest_sha.length() != 64 or receipt_path.is_empty() or shot_dir.is_empty() \
			or FileAccess.file_exists(receipt_path) or FileAccess.file_exists(shot_dir.path_join(NOOK_CONTRACT_NAME)) \
			or FileAccess.get_sha256(manifest_path) != manifest_sha:
		return {}
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var appdata := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	if manifest is not Dictionary or manifest.get("seed_sha256") != BEDROOM_FIXTURE_SHA \
			or not str(manifest.get("producer_appdata", "")).begins_with("C:/ov/reports/develop_intake_20261104/") \
			or str(manifest.get("producer_appdata", "")).nocasecmp_to(appdata) == 0 \
			or manifest.get("owner") != NOOK_OWNER or manifest.get("stock_id") != NOOK_STOCK \
			or not bool(manifest.get("storage_result", {}).get("ok", false)) \
			or str(manifest.get("source", {}).get("runtime_inputs_sha256", "")).length() != 64:
		return {}
	var bytes := FileAccess.get_file_as_bytes(RealityState.SAVE_PATH)
	var actual_sha := FileAccess.get_sha256(RealityState.SAVE_PATH)
	if actual_sha == BEDROOM_FIXTURE_SHA or actual_sha != manifest.get("primary_sha256") \
			or bytes.size() != int(manifest.get("primary_size", -1)):
		return {}
	var record: Dictionary = RealityState.data.get("v2_household_controls", {}).get("records", {}).get(NOOK_OWNER, {}).get("value", {})
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(record, "", true, true))
	var saved: Dictionary = loaded.get("books", {}).get(NOOK_STOCK, {})
	var original: Dictionary = manifest.get("original_row", {})
	if int(original.get("slot", -1)) != 0 or int(saved.get("slot", 0)) != -1 or not bool(saved.get("body", {}).get("sleeping", false)) \
			or saved == original or saved != manifest.get("saved_row") \
			or JSON.stringify(loaded, "", true, true).sha256_text() != manifest.get("library_sha256"):
		return {}
	var authority: Dictionary = manifest.get("authority", {})
	for key: String in ["version", "intro_complete", "campaign_clock", "prologue", "core_loop", "first_shift", "maintenance_items", "maintenance_jobs", "dream", "dream_seed"]:
		if not authority.has(key) or JSON.parse_string(JSON.stringify(RealityState.data.get(key))) != authority[key]:
			return {}
	var producer_root := str(manifest.producer_appdata).path_join("PleaseRemainOnTheLine")
	var primary_path := str(manifest.get("primary_path", "")).replace("\\", "/").simplify_path()
	if primary_path != producer_root.path_join("tests/nook_title_fixture.json") \
			or FileAccess.get_sha256(primary_path) != actual_sha:
		return {}
	var wrapper_path := OS.get_environment("TITLE_ACTUAL_NOOK_PRODUCER_WRAPPER")
	var wrapper_sha := OS.get_environment("TITLE_ACTUAL_NOOK_PRODUCER_WRAPPER_SHA")
	if wrapper_path.is_empty() or wrapper_sha.length() != 64 or FileAccess.get_sha256(wrapper_path) != wrapper_sha:
		return {}
	var wrapper: Variant = JSON.parse_string(FileAccess.get_file_as_string(wrapper_path))
	if wrapper is not Dictionary or wrapper.get("evidence_kind") != "suite_run" \
			or wrapper.get("scene") != "res://tests/V2BookInspectionReturnWorld.tscn":
		return {}
	var execution: Dictionary = wrapper.get("execution", {})
	var wrapper_shots := str(wrapper.get("shot_dir", "")).replace("\\", "/").simplify_path()
	if execution.get("completed") != true or execution.get("exit_code") != 0 or execution.get("timed_out") != false \
			or wrapper.get("source", {}).get("runtime_inputs_sha256") != manifest.source.runtime_inputs_sha256 \
			or wrapper_shots.path_join("nook_title_export.json") != manifest_path.replace("\\", "/").simplify_path():
		return {}
	manifest.primary_path = primary_path
	manifest.library_record = loaded
	manifest.manifest_path = manifest_path
	manifest.manifest_sha256 = manifest_sha
	manifest.wrapper_path = wrapper_path
	manifest.wrapper_sha256 = wrapper_sha
	return manifest

func _launch(action: String, clock: CampaignClock, timed_bedroom: bool, packed_washer := false) -> void:
	var observer := LaunchObserver.new()
	observer.action = action
	observer.timed_bedroom = timed_bedroom
	observer.nook_export = _nook_export
	observer.packed_washer = packed_washer
	if timed_bedroom and action == "continue":
		observer.timing["pre_title_save"] = {"sha256": FileAccess.get_sha256(RealityState.SAVE_PATH),
			"load_status": RealityState.load_status(), "clock": RealityState.data.campaign_clock.duplicate(true),
			"prologue": RealityState.data.prologue.duplicate(true)}
	observer.expected = JSON.parse_string(JSON.stringify({
			"campaign_clock": RealityState.data.campaign_clock,
			"first_shift": RealityState.data.first_shift, "core_loop": RealityState.data.core_loop})) if action == "continue" else {}
	if packed_washer:
		for key: String in ["carried_case", "maintenance_items", "caretaker_economy"]:
			observer.expected[key] = JSON.parse_string(JSON.stringify(RealityState.data[key]))
	if not _nook_export.is_empty():
		observer.expected.merge(_nook_export.authority, true)
		observer.timing.pre_title_save["authority"] = _nook_export.authority
		if observer.expected.dream == {}:
			# Admission already checked the original empty record. Both world
			# observations expect the exact JSON shape of the awake defaults.
			observer.expected.dream = {"phase":"awake", "active":false, "debug_preview":false,
				"case_id":"", "profile_id":"", "window":{}, "seed_hex":_nook_export.authority.dream_seed,
				"maze_revision":0.0, "night_index":-1.0, "spawn_anchor":-1.0, "outcome":""}
	observer.expected_absolute = clock.absolute_minutes() if action == "continue" else 13 * 60 + 27
	observer.expected_bytes = FileAccess.get_file_as_bytes(RealityState.save_path) if action != "begin" else PackedByteArray()
	if not _nook_export.is_empty():
		var scene: String = get_tree().current_scene.scene_file_path
		if not observer.bind_nook_source(get_script().resource_path, scene, str(get_path())) \
				or observer.nook_source_before.producer_raw_sha256 != {
					"manifest":_nook_export.manifest_sha256, "wrapper":_nook_export.wrapper_sha256, "primary":_nook_export.primary_sha256}:
			observer.free()
			push_error("Nook title Continue source or producer provenance cannot be bound")
			get_tree().quit(2)
			return
	get_tree().root.add_child.call_deferred(observer)
	var title := load("res://scenes/ui/title_screen.tscn").instantiate() as OrisonTitleScreen
	add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	if title._primary_button.text != ("BEGIN THE NIGHT" if action == "begin" else "CONTINUE"):
		get_tree().quit(1)
		return
	# No GameBoot scene-operation override is installed in this process.
	observer.mark("title_action")
	observer.action_usec = observer.timing.title_action
	if action == "new":
		title._new_campaign_button.pressed.emit()
		title._replacement_confirm.pressed.emit()
	else:
		title._primary_button.pressed.emit()
