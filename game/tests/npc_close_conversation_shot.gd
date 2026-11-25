extends Node3D
## A close conversation for review (order w8c788aec4db6, plan section 8): a rebuilt resident in their own authored
## ResidentConversations exchange, filmed from where the player stands, at conversation distance and close up.
## Everything the face does comes from the runtime owners: attention, the face controller's gaze and blinks, the
## mood reading and its gestures, and the speech hook's untimed jaw. When CUES_DIR names a folder of
## `<tree>__<node>.cues.json` files from tools/voice/intake.py, a line with a file there is mouthed from its
## timing instead (no audio plays). Windowed only; saves PNGs to SHOT_DIR. Review evidence, not runtime proof.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const FaceController := preload("res://scripts/characters/face_controller.gd")
## Where the camera stands: metres in front of the face, and the lens.
const FRAMINGS := [["conversation", 1.1, 32.0], ["close", 0.55, 24.0]]
const SECONDS_PER_LINE := 2.4
const FRAME_EVERY := 0.2

var conversations: ResidentConversations
var panel: CaseDialoguePanel
var camera: Camera3D
var directory := ""
var cues_dir := ""
var shots := 0
var cued_lines := 0
var current_node := ""


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		print("NPC CLOSE CONVERSATION: needs a window and SHOT_DIR; nothing written")
		get_tree().quit(0)
		return
	cues_dir = OS.get_environment("CUES_DIR")
	var resident_id := OS.get_environment("RESIDENT")
	if resident_id.is_empty():
		resident_id = "cal_dwyer"
	var lines := maxi(int(OS.get_environment("LINES")), 1) if not OS.get_environment("LINES").is_empty() else 4
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	get_window().size = Vector2i(960, 720)
	_stage()
	panel = CaseDialoguePanel.new()
	add_child(panel)
	conversations = ResidentConversations.new()
	add_child(conversations)
	conversations.setup(panel, func() -> String: return "", func(_resident: String) -> bool: return true)
	panel.node_shown.connect(func(node_id: String) -> void: current_node = node_id)
	CastBodies.set_for_test([resident_id])
	var failures := 0
	for framing: Array in FRAMINGS:
		var actor := Presentation.new()
		actor.setup(resident_id.capitalize(), resident_id, "", CastBodies.model_for(resident_id))
		actor.externally_driven = true
		add_child(actor)
		for _frame in 8:
			await get_tree().process_frame
		if actor.cast_body == null or actor.cast_body.face == null:
			print("NPC CLOSE CONVERSATION: %s has no rebuilt body or face" % resident_id)
			failures += 1
			actor.queue_free()
			break
		actor.call("_play_named", "idle")
		_aim(actor, float(framing[1]), float(framing[2]))
		for _frame in 20:
			await get_tree().process_frame
		if not conversations.start(resident_id):
			print("NPC CLOSE CONVERSATION: %s's conversation did not open" % resident_id)
			failures += 1
			actor.queue_free()
			break
		for line in lines:
			await get_tree().process_frame
			var said: String = str(panel.displayed_line().get("text", ""))
			var cued := _mouth_from_cues(actor, resident_id)
			var speech: Node = actor.get_node_or_null("CastSpeech")
			var reading: Dictionary = speech.get("last_reading") if speech != null else {}
			print("NPC CLOSE CONVERSATION LINE: %s %s node=%s cued=%s reading=%s text=%s" % [framing[0], line, current_node,
					cued, JSON.stringify(reading), said.left(90)])
			var waited := 0.0
			var frame := 0
			while waited < SECONDS_PER_LINE:
				await get_tree().create_timer(FRAME_EVERY).timeout
				waited += FRAME_EVERY
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(directory.path_join("%s__%s__l%d_%02d.png" % [resident_id, framing[0], line, frame]))
				frame += 1
				shots += 1
			var labels: Array = panel.offered_labels()
			if labels.is_empty() or not panel.attention_active():
				break
			panel.choose(0)
		panel.close()
		conversations.conversation_ended.emit(resident_id)
		actor.queue_free()
		for _frame in 4:
			await get_tree().process_frame
	CastBodies.set_for_test()
	print("NPC CLOSE CONVERSATION: %d shots; %d lines from cue files; %d failures" % [shots, cued_lines, failures])
	get_tree().quit(1 if failures > 0 or shots == 0 else 0)


## A recorded line's timing, when one is supplied for the line on the panel: the face mouths it in place of the jaw.
func _mouth_from_cues(actor: Node, resident_id: String) -> bool:
	if cues_dir.is_empty() or current_node.is_empty():
		return false
	var cues: Array = FaceController.load_cues(cues_dir.path_join("%s__%s.cues.json" % [resident_id, current_node]))
	if cues.is_empty():
		return false
	actor.cast_body.face.speak(cues)
	cued_lines += 1
	return true


## The camera at the player's eye in front of the resident's face, looking at it; attention looks back at it.
func _aim(actor: Node3D, metres: float, fov: float) -> void:
	var skeleton: Skeleton3D = actor.get("cast_body").skeleton
	var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	var face: Vector3 = head + Vector3(0, 0.07, 0)
	var forward: Vector3 = actor.global_basis.z.normalized()
	camera.fov = fov
	camera.global_position = face + forward * metres + Vector3(0, 0.03, 0)
	camera.look_at(face - Vector3(0, 0.12 if metres > 1.0 else 0.0, 0))
	camera.make_current()


func _stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.29, 0.3, 0.32)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
	environment.environment.ambient_light_energy = 0.5
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-22, 28, 0)
	key.light_energy = 1.1
	add_child(key)
	camera = Camera3D.new()
	add_child(camera)
