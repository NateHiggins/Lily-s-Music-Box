extends Node3D
## The presentation with clips: an owner that asks for them gets the shared cast clips as the base pose in the
## stand pose's place, with attention, skirt and face going on over it; an owner that does not ask is as before.
## Real imported assets under res://assets/characters/cast; no building, dialogue or saves.
const Presentation := preload("res://scripts/characters/cast_model_presentation.gd")
const BASE := "res://assets/characters/cast"
const PEOPLE: Array[String] = ["cal_dwyer", "mina_vale", "adela_voss"]

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CAST CLIPS: [FAIL] ", text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func _set_of(notes: Dictionary, letter: String) -> Array:
	var parts: Array = []
	for part: String in notes:
		if str(notes[part].get("set", "")) == letter:
			parts.append(part)
	return parts


func _thigh(actor: Presentation) -> Quaternion:
	return actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("LeftUpLeg"))


func run() -> void:
	RealityState.persistence_enabled = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.5, 3.0)
	camera.make_current()
	var installed := 0
	for id: String in PEOPLE:
		var source := "%s/%s/%s.gltf" % [BASE, id, id]
		if not ResourceLoader.exists(source):
			continue
		installed += 1
		var probe := Presentation.Wardrobe.new()
		probe.person_id = id
		probe.read_wardrobe(source.get_base_dir())
		# An owner that does not ask: no player, and the stand pose holds.
		var still := Presentation.new()
		still.configure(id, source, _set_of(probe.notes, "a"))
		add_child(still)
		await frames(6)
		check(still.ready_ok and not still.clip_driven and still.find_children("*", "AnimationPlayer", true, false).is_empty(), id + " without clips is as before: no player")
		var held := _thigh(still)
		await frames(10)
		check(held.is_equal_approx(_thigh(still)), id + " without clips holds the stand pose")
		still.queue_free()
		# An owner that asks.
		var actor := Presentation.new()
		actor.configure(id, source, _set_of(probe.notes, "a"))
		add_child(actor)
		await frames(6)
		check(actor.ready_ok, id + " ready: " + "; ".join(PackedStringArray(actor.errors)))
		if not actor.ready_ok:
			actor.queue_free()
			continue
		var stood := _thigh(actor)
		var player := actor.drive_with_clips()
		check(player != null and actor.clip_driven, id + " takes the clips when asked")
		if player == null:
			actor.queue_free()
			continue
		check(actor.drive_with_clips() == player and actor.find_children("*", "AnimationPlayer", true, false).size() == 1, id + " asking twice gives the same one player")
		check(actor.ready_ok and actor.visible and actor.errors.is_empty(), id + " is still ready and seen with a player on board")
		player.play("walk")
		await frames(8)
		var first := _thigh(actor)
		await frames(12)
		var later := _thigh(actor)
		check(not first.is_equal_approx(stood) and not first.is_equal_approx(later), id + " the clip moves the body and the stand pose is silent")
		check(actor.is_processing() and actor.attention.is_processing() and actor.attention.pipeline.active, id + " attention goes on over the clip")
		check(int(actor.attention.pipeline.refused_writes) == 0, id + " no bone is written twice by the pose layers")
		actor.attention.staged_target = actor.global_position + Vector3(2.0, 1.5, 1.0)
		actor.attention.conversing = true
		# Looking comes and goes as it does in a conversation; within a few seconds there is a look.
		var looked := false
		for _wait in 360:
			await get_tree().process_frame
			if actor.attention.pipeline.attending() and actor.attention.pipeline.gaze_weight() > 0.2:
				looked = true
				break
		check(looked, id + " turns to look while walking")
		check(int(actor.attention.pipeline.refused_writes) == 0, id + " still no bone written twice while looking")
		# A change of clothes under way.
		check(actor.wear(_set_of(probe.notes, "b")) and player.is_playing(), id + " changes clothes without stopping: " + actor.last_refusal)
		# Off shift the clip stops with everything else; back on, it goes on.
		actor.set_active(false)
		var parked := _thigh(actor)
		await frames(8)
		check(not actor.visible and not player.active and parked.is_equal_approx(_thigh(actor)), id + " off shift hides and holds still")
		actor.set_active(true)
		await frames(8)
		check(actor.visible and player.active and not parked.is_equal_approx(_thigh(actor)), id + " back on shift moves again")
		actor.queue_free()
		await frames(2)
	check(installed > 0, "at least one cast body is installed")
	print("CAST CLIPS RESULT: ", checks, " checks / ", failures.size(), " failures")
	print("CAST CLIPS TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
