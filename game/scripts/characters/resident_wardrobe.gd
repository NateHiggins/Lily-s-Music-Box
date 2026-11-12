extends RefCounted
## What a cast member is wearing. A person's own file holds the body once: the
## skeleton, the skin in named parts, the face. Their wardrobe is a set of
## small files, one per part: a top, a bottom, an outer layer, headwear,
## footwear, three of each, made on the same skeleton. Any part goes with any
## other. Each part has a note saying which slot it fills, what it is for
## (tags such as warm, night, work) and which parts of the skin it covers.
##
## Changing clothes loads the parts that are new and frees the ones taken off;
## the body, face and hair are never reloaded. A wardrobe's size costs disk,
## not memory: only what is worn is loaded.

const FOLDER := "res://assets/characters/%s"
const SKIN_PREFIX := "Skin_"
const SLOTS: Array[String] = ["bottom", "top", "over", "feet", "head"]

var person_id := ""
var keep_body := false
## Modelled hair, and the same hair pressed to the skull for wearing under a hat.
var _hair: MeshInstance3D
var _hat_hair: MeshInstance3D
var skeleton: Skeleton3D
## Slot to the name of the part worn in it.
var worn: Dictionary = {}
## Part name to its note.
var notes: Dictionary = {}
var _meshes: Dictionary = {}
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
	for mesh: MeshInstance3D in model.find_children("*Hair*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("HatHair"):
			_hat_hair = mesh
		elif str(mesh.name).begins_with("Hair") and not str(mesh.name).begins_with("HairCap"):
			_hair = mesh
	if _hat_hair != null:
		_hat_hair.visible = false
	return not _skin.is_empty()


## Read the notes of every part this person owns from their folder.
func read_wardrobe(folder: String = "") -> int:
	if folder.is_empty():
		folder = FOLDER % person_id
	notes.clear()
	for file: String in DirAccess.get_files_at(folder):
		if not (file.begins_with(person_id + "__") and file.ends_with(".json")):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
		# A note is filed under the part its file is named for; a copied note that names another part is not read.
		var named := file.trim_prefix(person_id + "__").trim_suffix(".json")
		if parsed is Dictionary and parsed.has("slot") and str(parsed.get("part", "")) == named:
			notes[named] = parsed
	return notes.size()


## Wear exactly these parts (one per slot; a later part in the list wins a
## slot). `loader` turns a part's name into its loaded scene; left out, the
## part's file is loaded from the person's folder.
func wear(parts: Array, loader: Callable = Callable()) -> bool:
	var wanted: Dictionary = {}
	for part: Variant in parts:
		if notes.has(str(part)):
			wanted[str(notes[str(part)].slot)] = str(part)
	# A whole outfit (a suit, a dress) takes the slots it replaces.
	for slot: String in wanted.keys():
		if not wanted.has(slot):
			continue
		for taken: Variant in (notes[wanted[slot]] as Dictionary).get("replaces", []):
			if str(taken) != slot:
				wanted.erase(str(taken))
	var changed := false
	for slot: String in SLOTS:
		var now := str(worn.get(slot, ""))
		var next := str(wanted.get(slot, ""))
		if now == next:
			continue
		if not now.is_empty():
			for mesh: MeshInstance3D in _meshes.get(now, []):
				mesh.queue_free()
			_meshes.erase(now)
			worn.erase(slot)
		if not next.is_empty() and _put_on(next, loader):
			worn[slot] = next
		changed = true
	_show_skin()
	return changed


func _put_on(part: String, loader: Callable) -> bool:
	var source: Node = null
	if loader.is_valid():
		source = loader.call(part)
	else:
		var scene := load((FOLDER % person_id).path_join("%s__%s.glb" % [person_id, part])) as PackedScene
		source = scene.instantiate() if scene != null else null
	if source == null:
		return false
	var mine: Array = []
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		# The part was skinned to a skeleton with the same bones; hand it to this one.
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		mesh.name = "%s_%s" % [part, mesh.name]
		mine.append(mesh)
	source.queue_free()
	_meshes[part] = mine
	return not mine.is_empty()


## The body is whole and in parts. A part is hidden only under a garment that
## fits closely over it (its note lists what it covers), so a lifted skirt or
## an open coat shows a person and not a hole. keep_body shows every part.
func _show_skin() -> void:
	if _hair != null and _hat_hair != null:
		_hair.visible = not worn.has("head")
		_hat_hair.visible = worn.has("head")
	var covered: Dictionary = {}
	if keep_body:
		for area: String in _skin:
			(_skin[area] as MeshInstance3D).visible = true
		return
	for slot: String in worn:
		for area: Variant in (notes[worn[slot]] as Dictionary).get("covers", []):
			covered[str(area)] = true
	for area: String in _skin:
		(_skin[area] as MeshInstance3D).visible = area in ["head", "hands"] or not covered.has(area)


func bare_parts() -> Array:
	var bare: Array = []
	for area: String in _skin:
		if (_skin[area] as MeshInstance3D).visible:
			bare.append(area)
	bare.sort()
	return bare


func mesh_count() -> int:
	var count := 0
	for part: String in _meshes:
		count += (_meshes[part] as Array).size()
	return count
