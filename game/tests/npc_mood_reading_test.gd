extends Node
## MoodReading (ruling npc_face_mood_source_20261124): how a resident feels about a
## line is read from the line, trust, temperament and the last exchange, by rules
## only. Checks the reading on chosen lines, that it is stable and exaggerated,
## that gestures are only for strong feelings and are clips the cast has, and
## the spread of feelings over every authored dialogue line.

const MoodReading := preload("res://scripts/characters/mood_reading.gd")
const Face := preload("res://scripts/characters/face_controller.gd")
const MOVES := "res://assets/characters/cast/shared/cast_moves.glb"

var _checks := 0
var _fails := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	var mood: RefCounted = MoodReading.new()
	_check(mood.load_data(), "the reading rules load")
	_check(not mood.traits_of("cal_dwyer").is_empty(), "temperament comes from the residents' own traits")

	print("NPC MOOD: chosen lines")
	var sad: Dictionary = mood.read("teresa_vale", "He died in the spring. I still set two cups. Nobody writes now.", 1)
	_check(sad.expression == "sadness", "a line about a death reads as sadness (%s)" % sad.expression)
	var cross: Dictionary = mood.read("omar_bell", "Enough. I said leave it. None of your business, and stop asking!", 1)
	_check(cross.expression == "frustration", "a refusal reads as frustration (%s)" % cross.expression)
	var plain: Dictionary = mood.read("cal_dwyer", "The set is on the table by the window.", 1)
	_check(plain.expression == "interest" and plain.emote == "", "a plain line rests on interest, with no gesture (%s)" % plain.expression)
	var that: Dictionary = mood.read("cal_dwyer", "That is the thing that has the hat.", 1)
	_check(that.expression != "amusement", "'ha' is not found inside other words (%s)" % that.expression)
	_check(float(sad.intensity) > 1.0, "a clear feeling is shown larger than written (%.2f)" % float(sad.intensity))
	var again: Dictionary = mood.read("teresa_vale", "He died in the spring. I still set two cups. Nobody writes now.", 1)
	_check(again == sad, "the same line, trust and person read the same every time")

	print("NPC MOOD: trust and the last exchange")
	var line := "Enough. You came back?"
	var warm: Dictionary = mood.read("lena_ortiz", line, 5)
	var cold: Dictionary = mood.read("lena_ortiz", line, -2)
	_check(warm.expression != cold.expression, "trust changes how the same line is felt (%s warm, %s cold)" % [warm.expression, cold.expression])
	var won: Dictionary = mood.read("lena_ortiz", "Oh. You noticed that.", 1, {"trust_delta": 1})
	_check(won.expression == "recognition", "a line after the player won trust reads as recognition (%s)" % won.expression)
	var lost: Dictionary = mood.read("lena_ortiz", "Fine.", 1, {"trust_delta": -1})
	_check(lost.expression in ["frustration", "sadness"], "a line after the player lost trust reads as hurt (%s)" % lost.expression)

	print("NPC MOOD: gestures")
	var clips: Dictionary = {}
	var moves := load(MOVES) as PackedScene
	if moves != null:
		var scene := moves.instantiate()
		for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
			for clip in player.get_animation_list():
				clips[str(clip)] = true
		scene.free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/mood_reading.json"))
	var missing: Array = []
	for feeling: String in data.emote.clips:
		for clip: String in data.emote.clips[feeling]:
			if not clips.has(clip):
				missing.append(clip)
	_check(not clips.is_empty() and missing.is_empty(), "every gesture is a clip the cast has (missing %s)" % str(missing))
	_check(cross.emote != "", "a strong feeling brings a gesture (%s)" % cross.emote)

	print("NPC MOOD: every authored line")
	var counts: Dictionary = {}
	var gestures := 0
	var lines := 0
	for file in DirAccess.get_files_at("res://data/dialogue"):
		if not file.ends_with(".json"):
			continue
		var tree: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + file))
		if tree is not Dictionary or tree.get("nodes") is not Dictionary:
			continue
		var who := file.get_basename()
		for id: String in tree.nodes:
			var node: Dictionary = tree.nodes[id]
			var text := str(node.get("line", "")).strip_edges()
			if text.replace(".", "").strip_edges().is_empty():
				continue
			var reading: Dictionary = mood.read(who, text, 1)
			counts[reading.expression] = int(counts.get(reading.expression, 0)) + 1
			if reading.emote != "":
				gestures += 1
			lines += 1
	print("  %d lines: %s; %d with a gesture" % [lines, JSON.stringify(counts), gestures])
	var largest := 0
	for feeling: String in counts:
		largest = maxi(largest, int(counts[feeling]))
	_check(lines > 300 and counts.size() >= 6, "the writing reads as at least six different feelings (%d)" % counts.size())
	_check(float(largest) / float(maxi(lines, 1)) < 0.6, "no single feeling takes most lines (%d of %d)" % [largest, lines])
	_check(gestures > 0 and float(gestures) / float(lines) < 0.45, "gestures are kept for the stronger lines (%d of %d)" % [gestures, lines])

	print("NPC MOOD: the face shows it larger")
	var written := _smile(1.0)
	var staged := _smile(1.7)
	_check(staged > written * 1.4 and staged <= 1.0, "an exaggerated feeling moves the face further, within each shape's reach (%.2f from %.2f)" % [staged, written])

	print("NPC MOOD READING TEST: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _smile(intensity: float) -> float:
	var model := Node3D.new()
	var mesh := ArrayMesh.new()
	var points := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var blends: Array = []
	for shape: String in ["mouthSmileLeft", "mouthSmileRight", "eyeBlinkLeft"]:
		mesh.add_blend_shape(shape)
		var blend: Array = []
		blend.resize(Mesh.ARRAY_MAX)
		blend[Mesh.ARRAY_VERTEX] = points
		blends.append(blend)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	model.add_child(instance)
	add_child(model)
	var face: Node = Face.new()
	face.set_process(false)
	add_child(face)
	face.bind(model, "staged_" + str(intensity))
	face.express("amusement", intensity)
	for index in 120:
		face.step(1.0 / 60.0)
	var value := instance.get_blend_shape_value(instance.find_blend_shape_by_name("mouthSmileLeft"))
	face.queue_free()
	model.queue_free()
	return value
