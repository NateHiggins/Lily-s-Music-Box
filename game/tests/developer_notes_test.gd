extends Node3D
## Developer notes: F7 files a picture, F6 pauses for a line and files both, under the room; the playtest context is
## kept current. Windowed (it reads frames). Writes only under DEV_NOTES_TEST_DIR (default user://dev_notes_test).
const Notes := preload("res://scripts/dev/developer_notes.gd")
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	print("DEV NOTES: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func _ready() -> void:
	run.call_deferred()


func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for _wait in 6:
		await get_tree().process_frame


func rows(folder: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(folder.path_join("notes.jsonl")).split("\n", false):
		out.append(JSON.parse_string(line))
	return out


func run() -> void:
	RealityState.persistence_enabled = false
	if DisplayServer.get_name() == "headless":
		print("DEV NOTES RESULT: needs a window")
		get_tree().quit(2)
		return
	for _wait in 3:
		await get_tree().process_frame
	check(get_node_or_null("/root/DeveloperNotes") == null, "off by default: the autoload removes itself")
	var folder := OS.get_environment("DEV_NOTES_TEST_DIR")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("user://dev_notes_test")
	folder = folder.replace("\\", "/").path_join(str(Time.get_ticks_usec()))
	OS.set_environment("ORISON_DEV_NOTES", folder)
	OS.set_environment("ORISON_DEV_CONTEXT", folder.path_join("context.json"))
	OS.set_environment("ORISON_DEV_BUILD", "test-build")
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var notes := Notes.new()
	add_child(notes)
	for _wait in 80:
		await get_tree().process_frame
	var context: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("context.json")))
	check(context is Dictionary and str(context.get("source_label", "")) == "game developer mode" and context.has("location"), "playtest context is published")
	await press(Notes.SHOT_KEY)
	var first := rows(folder)
	check(first.size() == 1 and str(first[0].note) == "" and FileAccess.file_exists(folder.path_join(str(first[0].picture))), "F7 files a picture under the room")
	check(str(first[0].build) == "test-build" and (first[0].position as Array).size() == 3, "the row names the build and where she stood")
	await press(Notes.NOTE_KEY)
	check(get_tree().paused and notes._panel.visible, "F6 pauses the game and asks for a line")
	notes._entry.text = "lamp floats off the wall"
	notes._entry.text_submitted.emit(notes._entry.text)
	for _wait in 4:
		await get_tree().process_frame
	var second := rows(folder)
	check(not get_tree().paused and not notes._panel.visible, "saving the note gives the game back")
	check(second.size() == 2 and str(second[1].note) == "lamp floats off the wall" and FileAccess.file_exists(folder.path_join(str(second[1].picture))), "the note and its picture are filed")
	await press(Notes.NOTE_KEY)
	await press(KEY_ESCAPE)
	check(not get_tree().paused and rows(folder).size() == 2, "Esc cancels without filing")
	OS.set_environment("ORISON_DEV_NOTES", "")
	print("DEV NOTES RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
