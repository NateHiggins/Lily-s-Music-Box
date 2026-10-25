extends Node3D
## INERT rendered physical-tile reactions, budget and interruption diagnostic.
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
var rig: Mechanism
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var directory := ""
var finished := false
var last_writes := 0
var peak_active := 0
var peak_writes := 0
var old_cap := 0

func check(ok: bool, label: String) -> void:
	checks.append({"name":label, "passed":ok})
	if not ok: failures.append(label); push_error(label)

func _ready() -> void:
	set_process(false)
	process_priority = 200
	get_tree().create_timer(130.0).timeout.connect(func():
		if not finished: check(false, "face diagnostic deadline"); finish())
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	old_cap = Engine.max_fps
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, .66); camera.fov = 38.0; camera.near = .02
	add_child(camera); camera.make_current()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24252a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d6cbb6")
	environment.environment.ambient_light_energy = .8
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -25, 0); key.light_energy = 1.3
	add_child(key)
	rig = Mechanism.new(); add_child(rig)
	if not rig.build(): check(false, "native companion builds reaction library"); finish(); return
	var player: Node = rig.reaction_player
	var face: Node = rig.display
	check(player.clips.size() == 6, "six authored reaction strips are loaded")
	check(not player.is_processing(), "reaction player sleeps before a request")
	check(not rig.play_reaction("not_a_reaction") and player.current.is_empty(), "unknown reaction refuses without changing state")
	var draw_count := rig.find_children("*", "MultiMeshInstance3D", true, false).size()
	last_writes = face.transform_writes
	set_process(true)
	for cap in [30, 60, 144]:
		Engine.max_fps = cap
		for id: String in player.clips:
			if not check_request(id, cap): continue
			check(not rig.play_reaction("wireless_call"), "busy reaction cannot be overwritten: " + id + "/" + str(cap))
			var seen: Dictionary = {}
			var captured := false
			var started := Time.get_ticks_msec()
			while not player.current.is_empty() and Time.get_ticks_msec() - started < 10000:
				await get_tree().process_frame
				if not player.current.is_empty() and face.settled():
					seen[int(player.frame)] = true
					var expected: PackedByteArray = player.clips[id].frames[player.frame].pixels
					check(face.target == expected, "settled physical target matches authored frame: " + id + "/" + str(cap) + "/" + str(player.frame))
					var pose_ok := true
					for index in 384:
						if absf(float(face.angles[index]) - (0.0 if expected[index] else PI)) > .000001: pose_ok = false; break
					check(pose_ok, "all actual tile rotations reach the selected two-colour image")
					var capture_frame := 3 if id == "vaudeville_wink" else 2
					if cap == 60 and player.frame == capture_frame and not captured:
						await RenderingServer.frame_post_draw
						check(get_viewport().get_texture().get_image().save_png(directory.path_join(id + ".png")) == OK, "rendered physical reaction " + id)
						captured = true
			check(player.current.is_empty(), "reaction completes without tile backlog: " + id + "/" + str(cap))
			check(seen.size() == player.clips[id].frames.size(), "every authored frame reaches its stable physical pose: " + id + "/" + str(cap))
			check(not player.is_processing(), "reaction player sleeps after completion")
			check(not rig.play_reaction(id), "same reaction is rate-limited without restarting: " + id)
			observations.append({"id":id, "render_cap":cap, "stable_frames":seen.size(), "elapsed_ms":Time.get_ticks_msec()-started})
	check(peak_active <= 32 and peak_writes <= 64, "all reactions retain32 active flips and64 transform writes per rendered step")
	check(rig.find_children("*", "MultiMeshInstance3D", true, false).size() == draw_count, "all six shorts reuse the existing mesh batches")
	check(rig.play_reaction("clockwork_thought"), "new eligible reaction starts for keyboard interruption")
	rig.request_keyboard(true)
	await get_tree().process_frame; await get_tree().process_frame
	check(player.current.is_empty() and not player.is_processing(), "keyboard opening interrupts the hidden face")
	rig.request_keyboard(false)
	for index in 30: await get_tree().physics_frame
	rig.device.set_radio_powered(false)
	check(not rig.play_reaction("vaudeville_wink"), "unpowered radio refuses new face movement")
	for index in 20: await get_tree().physics_frame
	rig.device.set_radio_powered(true)
	for index in 20: await get_tree().physics_frame
	check(not face.illustration_active and player.current.is_empty(), "power restoration returns ownership to normal mouth animation")
	finish()

func check_request(id: String, cap: int) -> bool:
	var ok := rig.play_reaction(id)
	check(ok, "native reaction starts: " + id + "/" + str(cap))
	return ok

func _process(_delta: float) -> void:
	peak_active = maxi(peak_active, rig.display._active.size())
	peak_writes = maxi(peak_writes, rig.display.transform_writes - last_writes)
	last_writes = rig.display.transform_writes

func finish() -> void:
	if finished: return
	finished = true; set_process(false); Engine.max_fps = old_cap
	FileAccess.open(directory.path_join("face_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Rendered native tile animations at30/60/144 caps; no world dialogue, current full runtime, navigation, saves or performance qualification", "checks":checks, "failures":failures, "observations":observations, "peak_active":peak_active, "peak_transform_writes":peak_writes}, "\t"))
	print("COMPANION FACE: ", checks.size(), " checks; ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
