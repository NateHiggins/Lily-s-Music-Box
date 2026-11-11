extends Node
## The face controller on a stand-in face: a small mesh carrying the same
## shape names the rebuilt heads carry. No character asset is needed. It
## checks that a face blinks on its own, that a feeling arrives and leaves
## instead of switching, that it is a little uneven, that the mouth follows a
## line's timing, shuts when a line is interrupted, moves with restraint when
## a line has no timing and not at all for a silent one, that the eyes turn,
## and that every shape has one write a frame. With FACE_GLB set to a rebuilt
## body and a window, it also saves close captures of that face.

const Face := preload("res://scripts/characters/face_controller.gd")
const STEP := 1.0 / 60.0
const SHAPES: Array[String] = [
	"eyeBlinkLeft", "eyeBlinkRight", "browInnerUp", "browDownLeft", "browDownRight", "browOuterUpLeft", "browOuterUpRight",
	"eyeWideLeft", "eyeWideRight", "eyeSquintLeft", "eyeSquintRight", "cheekSquintLeft", "cheekSquintRight",
	"mouthSmileLeft", "mouthSmileRight", "mouthFrownLeft", "mouthFrownRight", "mouthPressLeft", "mouthPressRight",
	"noseSneerLeft", "noseSneerRight", "jawOpen", "eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight",
	"eyeLookUpLeft", "eyeLookUpRight", "eyeLookDownLeft", "eyeLookDownRight",
	"viseme_PP", "viseme_kk", "viseme_SS", "viseme_E", "viseme_aa", "viseme_O", "viseme_U", "viseme_FF", "viseme_nn", "viseme_DD",
]

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _stand_in(shapes: Array[String]) -> Node3D:
	var model := Node3D.new()
	var mesh := ArrayMesh.new()
	var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	var blends: Array = []
	for shape: String in shapes:
		mesh.add_blend_shape(shape)
		var blend: Array = []
		blend.resize(Mesh.ARRAY_MAX)
		blend[Mesh.ARRAY_VERTEX] = points
		blend[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		blend[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		blends.append(blend)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.name = "Face_skin"
	model.add_child(instance)
	add_child(model)
	return model


func _shape(model: Node3D, shape: String) -> float:
	var instance := model.get_child(0) as MeshInstance3D
	return instance.get_blend_shape_value(instance.find_blend_shape_by_name(shape))


func _run(face: Node, seconds: float) -> void:
	for index in int(round(seconds / STEP)):
		face.step(STEP)


func _ready() -> void:
	var model := _stand_in(SHAPES)
	var face: Node = Face.new()
	face.set_process(false)
	add_child(face)
	_check(face.bind(model, "mina_vale"), "a face with the shapes is found")
	_check(face.can_speak_shapes(), "and it can form mouth shapes")

	print("NPC FACE: a body with no face")
	var blank := _stand_in([] as Array[String])
	var none: Node = Face.new()
	none.set_process(false)
	add_child(none)
	_check(not none.bind(blank, "nobody"), "a body with no face shapes binds to nothing")
	none.express("amusement", 1.0)
	none.speak([{"start": 0.0, "end": 1.0, "value": "D"}])
	none.step(STEP)
	_check(none.writes_last_frame == 0, "and asking it to feel or speak writes nothing and breaks nothing")

	print("NPC FACE: blinking")
	var closed := 0
	var blinks := 0
	var was_closed := false
	for index in 20 * 60:
		face.step(STEP)
		var lid := _shape(model, "eyeBlinkLeft")
		if lid > 0.9 and absf(lid - _shape(model, "eyeBlinkRight")) < 0.001:
			closed += 1
		if lid > 0.5 and not was_closed:
			blinks += 1
		was_closed = lid > 0.5
	_check(blinks >= 3 and blinks <= 12, "in twenty seconds a resting face blinks a few times (%d)" % blinks)
	_check(closed > 0 and closed < 140, "a blink shuts both lids and is over quickly (%d frames shut)" % closed)

	print("NPC FACE: a feeling arrives and leaves")
	_check(face.express("amusement", 0.8), "amusement is a known expression")
	_check(not face.express("smugness", 1.0), "an unknown expression is refused")
	face.step(STEP)
	var first := _shape(model, "mouthSmileLeft")
	_check(first > 0.0 and first < 0.1, "one frame in, the smile has only begun (%.3f)" % first)
	_run(face, 1.5)
	var left := _shape(model, "mouthSmileLeft")
	var right := _shape(model, "mouthSmileRight")
	_check(left > 0.3 and left <= 0.55 * 0.8 + 0.001, "it settles at its intensity (%.3f)" % left)
	_check(absf(left - right) > 0.02, "the two corners of the mouth are not a mirror (%.3f, %.3f)" % [left, right])
	var again: Node = Face.new()
	again.set_process(false)
	add_child(again)
	var twin := _stand_in(SHAPES)
	again.bind(twin, "mina_vale")
	again.express("amusement", 0.8)
	_run(again, 1.5 + STEP)
	_check(absf(_shape(twin, "mouthSmileLeft") - left) < 0.02, "the same resident's face is uneven the same way every time")
	face.express("concern", 1.0)
	_run(face, 0.1)
	_check(_shape(model, "mouthSmileLeft") > 0.05 and _shape(model, "browInnerUp") > 0.0, "one feeling gives way to the next; it does not cut")
	_run(face, 1.5)
	_check(_shape(model, "mouthSmileLeft") < 0.01 and _shape(model, "browInnerUp") > 0.4, "concern has replaced amusement")
	face.express("neutral")
	_run(face, 1.5)
	_check(_shape(model, "browInnerUp") < 0.01, "and the face comes back to rest")

	print("NPC FACE: speaking a timed line")
	var cues := [
		{"start": 0.0, "end": 0.2, "value": "X"}, {"start": 0.2, "end": 0.5, "value": "D"},
		{"start": 0.5, "end": 0.8, "value": "A"}, {"start": 0.8, "end": 1.1, "value": "E"}, {"start": 1.1, "end": 1.4, "value": "X"},
	]
	face.express("amusement", 1.0)
	_run(face, 1.5)
	var smiling := _shape(model, "mouthSmileLeft")
	face.speak(cues)
	_run(face, 0.42)
	_check(face.is_speaking() and _shape(model, "viseme_aa") > 0.6, "on an open vowel the mouth is open (%.2f)" % _shape(model, "viseme_aa"))
	_check(_shape(model, "mouthSmileLeft") < smiling * 0.6, "speaking quiets the smile under it (%.2f from %.2f)" % [_shape(model, "mouthSmileLeft"), smiling])
	_run(face, 0.3)
	_check(_shape(model, "viseme_PP") > 0.6 and _shape(model, "viseme_aa") < 0.2, "on a closed consonant the lips meet (%.2f)" % _shape(model, "viseme_PP"))
	_run(face, 0.3)
	_check(_shape(model, "viseme_O") > 0.5, "then a rounded vowel (%.2f)" % _shape(model, "viseme_O"))
	_run(face, 0.6)
	_check(not face.is_speaking() and _shape(model, "viseme_O") < 0.02, "when the line ends the mouth is at rest")
	_check(_shape(model, "mouthSmileLeft") > smiling * 0.85, "and the smile is back")
	face.express("neutral")
	_run(face, 1.0)

	print("NPC FACE: interrupted, untimed and silent lines")
	face.speak(cues)
	_run(face, 0.4)
	_check(_shape(model, "viseme_aa") > 0.5, "mid-line the mouth is open")
	face.stop_speaking()
	_run(face, 0.25)
	_check(_shape(model, "viseme_aa") < 0.05, "interrupted, it shuts within a quarter second (%.3f)" % _shape(model, "viseme_aa"))
	face.speak_untimed(2.0)
	var most := 0.0
	var least := 1.0
	var mouth_shapes := 0.0
	for index in 110:
		face.step(STEP)
		most = maxf(most, _shape(model, "jawOpen"))
		least = minf(least, _shape(model, "jawOpen"))
		mouth_shapes = maxf(mouth_shapes, _shape(model, "viseme_aa"))
	_check(most > 0.12 and most <= 0.33, "a line with no timing moves the jaw with restraint (%.2f at most)" % most)
	_check(least < 0.03 and mouth_shapes < 0.01, "the jaw closes between syllables and invents no mouth shapes")
	_run(face, 0.5)
	_check(not face.is_speaking() and _shape(model, "jawOpen") < 0.02, "and it stops when the line does")
	var before := _shape(model, "jawOpen")
	_run(face, 1.0)
	_check(is_equal_approx(before, _shape(model, "jawOpen")) and _shape(model, "viseme_aa") < 0.001, "a written or silent line moves no mouth: nothing speaks unless told to")
	_check(Face.load_cues("res://data/voice/no_such_line.json").is_empty(), "a line with no timing file has no cues")

	print("NPC FACE: eyes")
	face.look(Vector2(18, 0))
	_run(face, 0.4)
	_check(_shape(model, "eyeLookOutLeft") > 0.5 and _shape(model, "eyeLookInRight") > 0.5 and _shape(model, "eyeLookInLeft") < 0.001, "both eyes turn the same way (%.2f)" % _shape(model, "eyeLookOutLeft"))
	face.look(Vector2(-90, 40))
	_run(face, 0.4)
	_check(_shape(model, "eyeLookInLeft") <= 1.0 and _shape(model, "eyeLookInLeft") > 0.95 and _shape(model, "eyeLookUpLeft") > 0.95, "eyes stop at their limits")
	face.look(Vector2.ZERO)
	_run(face, 0.5)

	print("NPC FACE: one writer")
	face.express("surprise", 1.0)
	face.speak(cues)
	face.blink()
	var worst := 0
	for index in 40:
		face.step(STEP)
		worst = maxi(worst, int(face.writes_last_frame))
	_check(worst > 4 and worst <= SHAPES.size(), "feeling, blinking and speaking at once still write each shape once a frame (%d of %d shapes)" % [worst, SHAPES.size()])
	face.stop_speaking()
	face.express("neutral")
	_run(face, 2.0)

	await _captures()
	print("NPC FACE CONTROLLER TEST: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## Optional: a rebuilt body from outside the project, looked at close.
func _captures() -> void:
	var path := OS.get_environment("FACE_GLB")
	var directory := OS.get_environment("SHOT_DIR")
	if path.is_empty() or directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		print("  face capture: could not read ", path)
		return
	var body := document.generate_scene(state) as Node3D
	add_child(body)
	var face: Node = Face.new()
	face.set_process(false)
	add_child(face)
	print("  face capture: bound=%s shapes=%d" % [face.bind(body, path.get_file()), (face.targets as Dictionary).size()])
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3, 0.31, 0.33)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 22
	add_child(camera)
	var height := float(OS.get_environment("FACE_HEIGHT")) if not OS.get_environment("FACE_HEIGHT").is_empty() else 1.52
	camera.position = Vector3(0.25, height, 1.5)
	camera.look_at(Vector3(0, height, 0))
	camera.current = true
	DirAccess.make_dir_recursive_absolute(directory)
	var stem := path.get_file().get_basename()
	var beats := [
		["rest", "neutral", 0.0, []],
		["recognition", "recognition", 1.0, []],
		["concern", "concern", 1.0, []],
		["speaking", "amusement", 0.6, [{"start": 0.0, "end": 3.0, "value": "D"}]],
	]
	for beat: Array in beats:
		face.express(str(beat[1]), float(beat[2]))
		if (beat[3] as Array).is_empty():
			face.stop_speaking()
		else:
			face.speak(beat[3])
		for index in 70:
			face.step(STEP)
			await get_tree().process_frame
		for index in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("%s_%s.png" % [stem, beat[0]]))
		print("FACE SHOT: %s %s" % [stem, beat[0]])
	body.queue_free()
