extends Node3D
## A resident on a rebuilt body speaks with its face while its own line is on the panel, and stops on another
## speaker's line, an empty line, a closed panel or the end of the conversation (order w9189b10b24ac).
## A stand-in conversation owner supplies the same signals and displayed line as ResidentConversations.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")


class FakeDialogue extends RefCounted:
	signal node_shown(node_id: String)
	var line := {"speaker": "", "text": ""}
	var open := true
	func displayed_line() -> Dictionary: return line
	func attention_active() -> bool: return open


class FakeConversations extends RefCounted:
	signal conversation_started(resident_id: String, entry_id: String)
	signal conversation_ended(resident_id: String)
	var trees := {"cal_dwyer": {"meta": {"speaker_default": "CAL DWYER"}}}
	var dialogue := FakeDialogue.new()


var conversations := FakeConversations.new()
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CAST SPEECH: [FAIL] ", text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	RealityState.persistence_enabled = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.5, 3.0)
	camera.make_current()
	CastBodies.set_for_test(["cal_dwyer"])
	var cal := Presentation.new()
	cal.setup("Cal Dwyer", "cal_dwyer", "4C", CastBodies.model_for("cal_dwyer"))
	cal.externally_driven = true
	add_child(cal)
	await frames(8)
	var body: Node = cal.cast_body
	check(body != null and cal.get_node_or_null("CastSpeech") != null, "Cal's rebuilt body has its speech hook")
	if body == null:
		_finish()
		return
	var face: Node = body.face
	var talk := func(speaker: String, words: String) -> void:
		conversations.dialogue.line = {"speaker": speaker, "text": words}
		conversations.dialogue.node_shown.emit("n")
	check(not face.is_speaking(), "silent before anyone talks")
	talk.call("CAL DWYER", "Shut the door, you're letting the room in.")
	await frames(2)
	check(not face.is_speaking(), "no mouth before his conversation starts")
	conversations.conversation_started.emit("cal_dwyer", "first")
	talk.call("CAL DWYER", "Shut the door, you're letting the room in.")
	await frames(2)
	check(face.is_speaking(), "his own line moves his mouth")
	conversations.dialogue.line = {"speaker": "CAL DWYER", "text": "He lowers the glass.", "delivery": "silent"}
	conversations.dialogue.node_shown.emit("silent_beat")
	check(not face.is_speaking(), "the visible action immediately stops the walking resident's active jaw")
	talk.call("CAL DWYER", "(He sets it down.) Good evening.")
	check(face.is_speaking(), "mixed speech and direction resume his jaw without explicit silent delivery")
	talk.call("MINA VALE", "Good evening.")
	await frames(2)
	check(not face.is_speaking(), "another speaker's line stops it")
	talk.call("CAL DWYER", "...")
	await frames(2)
	check(not face.is_speaking(), "an empty line stays silent")
	talk.call("CAL DWYER", "Listen. That's last Tuesday.")
	await frames(2)
	check(face.is_speaking(), "he speaks again on his next line")
	conversations.dialogue.open = false
	await get_tree().create_timer(0.4).timeout
	check(not face.is_speaking(), "a closed panel stops the mouth")
	conversations.dialogue.open = true
	talk.call("CAL DWYER", "Clear as glass.")
	await frames(2)
	conversations.conversation_ended.emit("cal_dwyer")
	await frames(2)
	check(not face.is_speaking(), "the end of the conversation stops the mouth")
	cal.queue_free()
	await frames(2)
	CastBodies.set_for_test()
	_finish()


func _finish() -> void:
	print("CAST SPEECH RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
