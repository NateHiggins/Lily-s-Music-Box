extends RefCounted
## What a cast member is wearing. A person's own file holds the body once: the
## skeleton, the skin in named parts, the face. Each outfit is a small file of
## garments made on the same skeleton, with a note of which parts of the skin
## it leaves bare. Changing clothes loads one small file and frees another; the
## body, face and hair are never reloaded. So the number of outfits a person
## owns costs disk, not memory or frame time: one outfit is in memory at a time.

const PERSON := "res://assets/characters/%s/%s.glb"
const OUTFIT := "res://assets/characters/%s/%s__%s.glb"
const NOTE := "res://assets/characters/%s/%s__%s.json"
const SKIN_PREFIX := "Skin_"

var person_id := ""
var skeleton: Skeleton3D
var wearing := ""
var _garments: Array[MeshInstance3D] = []
var _skin: Dictionary = {}


## Take charge of a person's model. False when it is not one of the rebuilt bodies.
func bind(model: Node, id: String) -> bool:
	person_id = id
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return false
	skeleton = skeletons[0] as Skeleton3D
	for mesh: MeshInstance3D in model.find_children(SKIN_PREFIX + "*", "MeshInstance3D", true, false):
		_skin[str(mesh.name).trim_prefix(SKIN_PREFIX)] = mesh
	return not _skin.is_empty()


## The outfits this person has files for.
func owned() -> Array[String]:
	var found: Array[String] = []
	var folder := (PERSON % [person_id, person_id]).get_base_dir()
	for file: String in DirAccess.get_files_at(folder):
		if file.begins_with(person_id + "__") and file.ends_with(".json"):
			found.append(file.trim_prefix(person_id + "__").trim_suffix(".json"))
	found.sort()
	return found


## Put an outfit on. Returns false, and changes nothing, when it cannot be found.
func wear(outfit: String) -> bool:
	if outfit == wearing:
		return true
	var path := OUTFIT % [person_id, person_id, outfit]
	var note_path := NOTE % [person_id, person_id, outfit]
	if skeleton == null or not ResourceLoader.exists(path) or not FileAccess.file_exists(note_path):
		return false
	var note: Variant = JSON.parse_string(FileAccess.get_file_as_string(note_path))
	var scene := load(path) as PackedScene
	if note is not Dictionary or scene == null:
		return false
	return dress(scene.instantiate(), note.get("show", []), outfit)


## Dress from an already loaded garment scene (a test, or a file outside the project).
func dress(source: Node, show: Array, outfit: String) -> bool:
	var incoming: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		incoming.append(mesh)
	if incoming.is_empty():
		source.free()
		return false
	for old: MeshInstance3D in _garments:
		old.queue_free()
	_garments.clear()
	for mesh: MeshInstance3D in incoming:
		# The garment was skinned to a skeleton with the same bones; hand it to this one.
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.owner = null
		mesh.skeleton = NodePath("..")
		mesh.name = "Garment_" + str(mesh.name)
		_garments.append(mesh)
	source.queue_free()
	for part: String in _skin:
		(_skin[part] as MeshInstance3D).visible = part in show
	wearing = outfit
	return true


func garment_count() -> int:
	return _garments.size()


func bare_parts() -> Array:
	var bare: Array = []
	for part: String in _skin:
		if (_skin[part] as MeshInstance3D).visible:
			bare.append(part)
	bare.sort()
	return bare
