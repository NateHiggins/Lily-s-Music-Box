extends Node
## Production capture-presentation contract. The real DreamMazeRoot, player,
## hazard batch, lamp and Master bus are used; only the clock is manual.

const EXPECTED_CHECKS := 31
const SEED_HEX := "f123456789abcdef"
const EmbraceScript := preload("res://scripts/dream/dream_embrace.gd")

var checks := 0
var failures := 0
var root: DreamMazeRoot


func _ready() -> void:
	var master := AudioServer.get_bus_index("Master")
	var effects_before := AudioServer.get_bus_effect_count(master)
	await _spawn_root()
	var growth := root.get("_hazard_growth") as MeshInstance3D
	var growth_material := growth.material_override as ShaderMaterial
	_check("the production dream has one eye-bearing hazard surface",
			growth != null and growth.mesh.get_surface_count() == 1
			and growth_material != null)
	_check("capture begins exactly one presentation",
			bool(root.call("_begin_embrace"))
			and not bool(root.call("_begin_embrace")))
	var embrace := root.get("_embrace") as Node
	_check("the root latches pursuit before committing an outcome",
			embrace != null and bool(root.get("_embrace_active"))
			and not bool(root.get("_outcome_committed"))
			and not root.autonomous)
	_check("the body is still and ordinary input is frozen",
			root.player.call_locked and not root.player.is_processing()
			and root.player.velocity == Vector3.ZERO)
	var visible_hud_layers := 0
	for child in root.player.get_children():
		if child is CanvasLayer and child.visible:
			visible_hud_layers += 1
	_check("crosshair and interaction HUD do not print onto the interior",
			visible_hud_layers == 0
			and bool(embrace.get_meta("hud_hidden", false)))
	_check("capture preserves the service lamp's chosen ON state",
			root.player.lamp_is_enabled()
			and bool(embrace.get_meta("lamp_state_preserved", false))
			and float((embrace.call("shell_material") as ShaderMaterial)
			.get_shader_parameter("lamp_enabled")) == 1.0)
	_check("the close is the ruled monotonic 1.5 seconds plus a short hold",
			is_equal_approx(float(embrace.get_meta("duration_s", 0.0)), 1.5)
			and float(embrace.get_meta("hold_s", 0.0)) <= 0.181
			and str(embrace.get_meta("photosensitivity", ""))
			== "monotonic_no_strobe")
	_check("the embrace has no direction and creates no topology",
			str(embrace.get_meta("direction", ""))
			== "none_frame_becomes_interior"
			and str(embrace.get_meta("topology", "")) == "none")
	var shell := root.player.camera.get_node_or_null("EmbraceInterior") \
			as MeshInstance3D
	_check("one inward shell belongs to the existing camera",
			shell != null and shell.get_parent() == root.player.camera
			and shell.mesh is SphereMesh)
	_check("the shell is close, bounded and never casts a shadow",
			shell.mesh.get_aabb().size.x <= EmbraceScript.SHELL_RADIUS_M * 2.01
			and shell.cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_check("presentation adds no camera light collision area or hazard",
			embrace.find_children("*", "Camera3D", true, false).is_empty()
			and embrace.find_children("*", "Light3D", true, false).is_empty()
			and embrace.find_children("*", "CollisionObject3D", true,
			false).is_empty()
			and embrace.find_children("*", "Area3D", true, false).is_empty())
	var shell_material := embrace.call("shell_material") as ShaderMaterial
	_check("the close is one shader on one surface",
			shell_material != null and shell.mesh.get_surface_count() == 1)
	embrace.set_process(false)
	embrace.call("set_progress_for_proof", 0.0)
	_check("the initial frame has zero authored closure",
			float(shell_material.get_shader_parameter("close_amount")) == 0.0
			and float(growth_material.get_shader_parameter("embrace_amount"))
			== 0.0)
	embrace.call("set_progress_for_proof", 0.5)
	_check("the same shell advances to a bounded middle state",
			is_equal_approx(float(shell_material.get_shader_parameter(
			"close_amount")), 0.5)
			and float(embrace.get_meta("progress", 0.0)) == 0.5)
	_check("all batched eyes close before the central view disappears",
			float(growth_material.get_shader_parameter("embrace_amount"))
			> 0.45)
	embrace.call("set_progress_for_proof", 1.0)
	_check("the final frame is fully enclosed without another mesh",
			float(shell_material.get_shader_parameter("close_amount")) == 1.0
			and root.player.camera.find_children("EmbraceInterior",
			"MeshInstance3D", true, false).size() == 1)
	_check("every existing eye reaches its closed endpoint",
			float(growth_material.get_shader_parameter("embrace_amount")) == 1.0)
	var sound := embrace.call("case_sound_player") as AudioStreamPlayer
	var signature := PoltergeistLibrary.signature("mina_caption_crisis")
	_check("the case sound occupies a non-spatial fifth position",
			sound != null and sound.get_class() == "AudioStreamPlayer"
			and str(embrace.get_meta("case_sound_position", ""))
			== "nondirectional_fifth")
	_check("the fifth position keeps Mina's recorded domestic signature",
			str(embrace.get_meta("case_sound_key", ""))
			== str(signature.sound)
			and is_equal_approx(sound.pitch_scale, float(signature.pitch))
			and sound.stream == PropAudio.get_stream(str(signature.sound)))
	_check("the close adds exactly one short reverb and one low-pass",
			AudioServer.get_bus_effect_count(master) == effects_before + 2
			and embrace.call("close_reverb") != null
			and embrace.call("close_low_pass") != null)
	var reverb := embrace.call("close_reverb") as AudioEffectReverb
	var low_pass := embrace.call("close_low_pass") as AudioEffectLowPassFilter
	_check("the final acoustic room is physically small and warm",
			reverb.room_size <= EmbraceScript.FINAL_REVERB_ROOM_SIZE + 0.001
			and reverb.wet >= 0.359
			and low_pass.cutoff_hz <= EmbraceScript.FINAL_LOWPASS_HZ + 1.0)
	_check("the presentation does not rewrite capture's danger vocabulary",
			str(embrace.get_meta("danger", ""))
			== "none_existing_capture_outcome_only"
			and DreamDirector.OUTCOMES == ["capture", "fall", "contact"])
	_check("manual proof placement never emits a persistent outcome",
			not bool(root.get("_outcome_committed")))
	root.remove_child(embrace)
	embrace.free()
	await get_tree().process_frame
	_check("teardown removes only its two Master-bus effects",
			AudioServer.get_bus_effect_count(master) == effects_before)
	# The late chosen-embrace path begins with the player's lamp off. The same
	# production owner must not silently reverse that vulnerable choice.
	root.set("_embrace_active", false)
	root.player.call_locked = false
	root.player.set_process(true)
	# This is a premise for the second capture, not a lamp-switch test. Set the
	# settled authored state directly so the player's generated switch WAV does
	# not leave an unrelated decoder alive at immediate headless shutdown.
	root.player.set("_lamp_on", false)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = false
	root.player.flashlight.light_energy = 0.0
	_check("the OFF premise is physically settled before the second capture",
			not root.player.lamp_is_enabled()
			and not root.player.flashlight.visible)
	_check("the same presentation accepts an extinguished chosen state",
			bool(root.call("_begin_embrace")))
	var dark_embrace := root.get("_embrace") as Node
	dark_embrace.set_process(false)
	dark_embrace.call("set_progress_for_proof", 1.0)
	_check("capture never relights a lamp the player deliberately extinguished",
			not root.player.lamp_is_enabled()
			and not root.player.flashlight.visible
			and not bool(dark_embrace.get_meta("lamp_state_preserved", true))
			and float((dark_embrace.call("shell_material") as ShaderMaterial)
			.get_shader_parameter("lamp_enabled")) == 0.0)
	_check("lamp-off enclosure keeps the same warm material, not black video",
			float((dark_embrace.call("shell_material") as ShaderMaterial).get_shader_parameter(
			"biological_afterglow")) > 0.0)
	_check("both states use the same one-surface presentation owner",
			root.player.camera.find_children("EmbraceInterior", "MeshInstance3D",
			true, false).size() == 1)
	remove_child(root)
	root.free()
	root = null
	await get_tree().process_frame
	_check("world teardown leaves the shared Master bus exactly as found",
			AudioServer.get_bus_effect_count(master) == effects_before)
	_check("the focused contract count stays explicit",
			checks + 1 == EXPECTED_CHECKS)
	if checks != EXPECTED_CHECKS:
		_failures_for_count()
	PropAudio.clear_cache()
	print("DREAM EMBRACE TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _spawn_root() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print",
		"window": {},
		"seed_hex": SEED_HEX,
		"maze_revision": 1,
		"outcome": "",
		"night_index": 7,
		"spawn_anchor": 0,
	})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	_stage_target_pocket()
	await get_tree().process_frame


func _stage_target_pocket() -> void:
	var atlas: DreamAtlas = root.rooms.atlas
	var queue: Array[PackedInt32Array] = [PackedInt32Array()]
	var chosen := PackedInt32Array()
	var examined := 0
	while not queue.is_empty() and examined < 2400:
		var path: PackedInt32Array = queue.pop_front()
		var room: Dictionary = atlas.room(path)
		var dark_sources := 1 if _source_is_dark_hazard(str(room.source)) else 0
		for door_index in int(room.doors):
			var child := DreamAtlas.step(path, door_index)
			if _source_is_dark_hazard(str(atlas.room(child).source)):
				dark_sources += 1
			if path.size() < 8:
				queue.append(child)
		if dark_sources >= 2:
			chosen = path
			break
		examined += 1
	if chosen.is_empty():
		return
	var key := DreamRoomBuilder.key_of(chosen)
	root.rooms.advance(root.get("_architecture") as Node3D, chosen)
	root.rooms.write_plan(root.plan, key)
	root.set("_here_path", chosen)
	root.set("_here_key", key)
	root.hazards.rearm(root.plan, root.profile_hazards)
	root.call("_rebuild_hazard_growth")


func _source_is_dark_hazard(source: String) -> bool:
	return source in ["D01_F04_LONG_HALL", "D03_LIFT_VOID"]


func _check(label: String, condition: bool) -> void:
	checks += 1
	print("  %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		failures += 1


func _failures_for_count() -> void:
	printerr("  FAIL expected %d checks, ran %d" % [EXPECTED_CHECKS, checks])
	failures += 1
