extends Node3D
## Model presentation only. Caller owns place, attendance and conversations.
## StandPose supplies the base before the existing one-writer pose modifier;
## FaceController is the only morph writer. No clips, collision or interaction.
const Wardrobe := preload("res://scripts/characters/resident_wardrobe.gd")
const Face := preload("res://scripts/characters/face_controller.gd")
const Stand := preload("res://scripts/characters/stand_pose.gd")
const Attention := preload("res://scripts/characters/resident_attention.gd")
const Skirt := preload("res://scripts/characters/skirt_follow.gd")
const Recipes := preload("res://scripts/characters/cast_material_recipes.gd")
const Hair := preload("res://scripts/characters/cast_hair_presentation.gd")
const SKIN_AREAS: Array[String] = ["arms", "chest", "feet", "hands", "head", "hips", "legs", "trunk"]
const REQUIRED_FACE: Array[String] = ["eyeBlinkLeft", "eyeBlinkRight", "viseme_PP", "viseme_kk", "viseme_SS", "viseme_E", "viseme_aa", "viseme_O", "viseme_U", "viseme_FF", "viseme_nn", "viseme_DD", "jawOpen", "eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight", "eyeLookUpLeft", "eyeLookUpRight", "eyeLookDownLeft", "eyeLookDownRight"]

var ready_ok := false
var model: Node3D
var skeleton: Skeleton3D
var face: Node
var hair: Hair
var attention: Node
var wardrobe: RefCounted
var errors: Array[String] = []
## Diagnostics only: negative fixtures collect the same strict refusals quietly.
var report_errors := true
var person_id := ""
var _source_model := ""
var _parts: Array = []
var _pose_name := "at_ease"
var _stand: RefCounted
var _skirt: SkeletonModifier3D
var _configured := false
var _active := true
var _applied_active: Variant = null
var _clock := 0.0


func configure(id: String, source_model: String, parts: Array, pose_name: String = "at_ease") -> void:
	if is_inside_tree() or _configured:
		_fail("configure must be called exactly once before add_child")
		return
	person_id = id
	_source_model = source_model
	_parts = parts.duplicate()
	_pose_name = pose_name
	_configured = true


func _fail(message: String) -> void:
	errors.append(message)
	ready_ok = false
	visible = false
	set_process(false)
	if face != null:
		face.stop_speaking()
		face.set_process(false)
	if attention != null:
		attention.set_process(false)
		attention.pipeline.active = false
	if _skirt != null:
		_skirt.active = false
	if hair != null:
		hair.set_presentation_active(false)
	if report_errors:
		push_error("CAST PRESENTATION %s: %s" % [person_id, message])


func _ready() -> void:
	visible = false
	process_priority = -100
	set_process(false)
	if not _configured or not errors.is_empty() or person_id.is_empty():
		_fail("missing valid pre-tree configuration")
		return
	if not _source_model.begins_with("res://") or not ResourceLoader.exists(_source_model):
		_fail("base model must be an imported resource: " + _source_model)
		return
	var packed := load(_source_model) as PackedScene
	if packed == null:
		_fail("base is not a PackedScene")
		return
	var instance := packed.instantiate()
	model = instance as Node3D
	if model == null:
		instance.free()
		_fail("base scene is not Node3D")
		return
	add_child(model)
	var bodies := model.find_children("*", "Skeleton3D", true, false)
	if bodies.size() != 1 or not model.find_children("*", "AnimationPlayer", true, false).is_empty():
		_fail("expected one motion-free shared skeleton")
		return
	skeleton = bodies[0] as Skeleton3D
	if skeleton.get_bone_count() != 76:
		_fail("base does not carry the 76-bone shared contract")
		return
	var areas: Array[String] = []
	for draw: MeshInstance3D in model.find_children("Skin_*", "MeshInstance3D", true, false):
		areas.append(str(draw.name).trim_prefix("Skin_"))
	areas.sort()
	if areas != SKIN_AREAS:
		_fail("base must contain all eight named skin partitions exactly once")
		return
	wardrobe = Wardrobe.new()
	if not wardrobe.bind(model, person_id) or wardrobe.skeleton != skeleton:
		_fail("shared wardrobe cannot bind base")
		return
	wardrobe.read_wardrobe(_source_model.get_base_dir())
	if not _dress(_parts):
		return
	_stand = Stand.new()
	if not _stand.load_table() or not _stand.poses.has(_pose_name) or not _stand.apply(skeleton, _pose_name, false, 0.0, 0.0):
		_fail("authored stand pose missing; A-pose fallback refused")
		return
	attention = Attention.install(self, model, person_id)
	if attention == null or str(attention.pipeline.profile.family) != "mpfb_mixamo_76":
		_fail("shared measured profile/attention pipeline did not bind")
		return
	# Added after PosePipeline; only skirt-chain bones are written by this layer.
	_skirt = Skirt.new()
	skeleton.add_child(_skirt)
	if not _skirt.bind():
		_fail("skirt-chain contract incomplete")
		return
	face = Face.new()
	add_child(face)
	if not face.bind(model, person_id) or not face.can_speak_shapes():
		_fail("shared face controller cannot bind speech shapes")
		return
	for shape: String in REQUIRED_FACE:
		if not face.targets.has(shape):
			_fail("required facial channel missing: " + shape)
			return
	hair = Hair.new()
	add_child(hair)
	if not hair.bind(model, person_id):
		_fail("shared hair presentation refused: " + "; ".join(PackedStringArray(hair.errors)))
		return
	ready_ok = true
	set_active(_active)


## What a list of parts comes to, slot by slot, or an empty table (with the refusal recorded) when it is not a
## whole outfit. One part to a slot. An outer layer and headwear are optional. A whole outfit (a suit, a dress,
## a robe) stands for the slots its note says it replaces. Top, bottom and feet must each be worn or stood for:
## nobody is shown half dressed.
func _outfit(parts: Array) -> Dictionary:
	var slots: Dictionary = {}
	for part: Variant in parts:
		var key := str(part)
		if not wardrobe.notes.has(key):
			_fail("missing wardrobe note: " + key)
			return {}
		var note: Dictionary = wardrobe.notes[key]
		var slot := str(note.get("slot", ""))
		if int(note.get("schema_version", 0)) != 1 or str(note.get("person", "")) != person_id or str(note.get("part", "")) != key or slot not in Wardrobe.SLOTS or slots.has(slot):
			_fail("invalid or duplicate current wardrobe slot: " + key)
			return {}
		slots[slot] = key
	var stood_for: Dictionary = {}
	for slot: String in slots:
		for taken: Variant in (wardrobe.notes[slots[slot]] as Dictionary).get("replaces", []):
			if str(taken) != slot:
				stood_for[str(taken)] = true
	for taken: String in stood_for:
		slots.erase(taken)
	for needed: String in ["top", "bottom", "feet"]:
		if not slots.has(needed) and not stood_for.has(needed):
			_fail("current intake requires top, bottom and feet; partial dress refused")
			return {}
	return slots


func _dress(parts: Array) -> bool:
	var slots := _outfit(parts)
	if slots.is_empty():
		return false
	wardrobe.wear(slots.values(), _load_part)
	if not errors.is_empty():
		return false
	for slot: String in slots:
		if str(wardrobe.worn.get(slot, "")) != str(slots[slot]):
			_fail("requested garment did not mount: " + str(slots[slot]))
			return false
	if wardrobe.worn.size() != slots.size() or wardrobe.mesh_count() < slots.size():
		_fail("wardrobe produced an incomplete visible set")
		return false
	# On a change of clothes the hair already wears its shader; the check is of the imported materials.
	var hair_bound := hair != null and hair.ready_ok
	if hair_bound:
		hair.lift_materials()
	var material_errors := Recipes.validate(model, person_id)
	if hair_bound:
		hair.restore_materials()
	if not material_errors.is_empty():
		_fail("cast material contract: " + "; ".join(PackedStringArray(material_errors)))
		return false
	_parts = slots.values()
	return true


## Change clothes. The same rules as at first dressing; a refused change leaves the actor hidden and failed,
## as any other refusal does, so a caller should only offer whole outfits (WardrobeRules does).
func wear(parts: Array) -> bool:
	if not ready_ok:
		return false
	return _dress(parts)


## The parts now worn, one to a slot.
func worn_parts() -> Array:
	return _parts.duplicate()


func _load_part(part: String) -> Node:
	var extension := _source_model.get_extension().to_lower()
	var path := _source_model.get_base_dir().path_join("%s__%s.%s" % [person_id, part, extension])
	if not ResourceLoader.exists(path):
		_fail("garment resource missing: " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("garment is not a PackedScene: " + path)
		return null
	var source := packed.instantiate()
	var bodies := source.find_children("*", "Skeleton3D", true, false)
	if bodies.size() != 1:
		source.free()
		_fail("garment has no unique shared skeleton: " + part)
		return null
	var other := bodies[0] as Skeleton3D
	if other.get_bone_count() != skeleton.get_bone_count():
		source.free()
		_fail("garment bone count mismatch: " + part)
		return null
	for index in skeleton.get_bone_count():
		var name_in_base := skeleton.get_bone_name(index)
		var match_index := other.find_bone(name_in_base)
		if match_index < 0 or not skeleton.get_bone_global_rest(index).is_equal_approx(other.get_bone_global_rest(match_index)):
			source.free()
			_fail("garment rest skeleton mismatch: " + part + "/" + name_in_base)
			return null
	if source.find_children("*", "MeshInstance3D", true, false).is_empty():
		source.free()
		_fail("garment has no meshes: " + part)
		return null
	return source


func set_active(enabled: bool) -> void:
	_active = enabled
	if not ready_ok:
		visible = false
		return
	if _applied_active == enabled:
		return
	_applied_active = enabled
	visible = enabled
	if not enabled:
		face.stop_speaking()
		face.look(Vector2.ZERO)
		# Clear any residual speech before suspending the facial writer.
		face.step(0.25)
		attention.conversing = false
		attention.pipeline.rest()
	face.set_process(enabled)
	attention.set_process(enabled)
	attention.pipeline.active = enabled
	_skirt.active = enabled
	hair.set_presentation_active(enabled)
	set_process(enabled)


func _process(delta: float) -> void:
	if not ready_ok or not _active:
		return
	_clock += delta
	# Exact imported signature: (skeleton, name, mirror, time, life).
	# life=0 prevents a second breathing/sway owner beneath PosePipeline.
	if not _stand.apply(skeleton, _pose_name, false, _clock, 0.0):
		_fail("base stand pose failed after readiness")
		return
	_look_with_eyes()


func _look_with_eyes() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not attention.is_looking() or attention.pipeline.frames == 0:
		face.look(Vector2.ZERO)
		return
	var pipeline: Node = attention.pipeline
	var forward: Vector3 = pipeline.facing_world()
	var up: Vector3 = skeleton.global_basis.orthonormalized() * pipeline.profile.up
	up = (up - forward * up.dot(forward)).normalized()
	var left := up.cross(forward).normalized()
	var toward: Vector3 = camera.global_position - pipeline.eye_world()
	if toward.length_squared() < 0.000001:
		face.look(Vector2.ZERO)
		return
	toward = toward.normalized()
	face.look(Vector2(rad_to_deg(atan2(toward.dot(left), toward.dot(forward))), rad_to_deg(asin(clampf(toward.dot(up), -1.0, 1.0)))))


func speak_cues(cues: Array) -> void:
	if ready_ok and _active:
		face.speak(cues)


func speak_untimed(seconds: float) -> void:
	if ready_ok and _active:
		face.speak_untimed(seconds)


func stop_speaking() -> void:
	if face != null:
		face.stop_speaking()


func express(expression: String, intensity: float = 1.0) -> void:
	if ready_ok and _active:
		face.express(expression, intensity)
