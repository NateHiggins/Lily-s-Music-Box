class_name ResidentMovesLibrary
extends RefCounted
## The shared animation set. All eighteen generated residents carry one
## identical 22-joint skeleton, so Evelyn's Meshy clips — retargeted once
## by art/blender/scripts/retarget_resident_moves.py — can be grafted onto
## any of them at load time. The only per-model work is repointing each
## track at that model's own Skeleton3D, because glTF track paths embed
## the exporting armature's node name.
##
## Animations keep their bare names (clip_01..clip_08, walk, run) inside
## the target's default library, so ROLES lookups and has_animation()
## keep working unchanged.

const LIB_PATH := "res://assets/characters/shared/resident_moves.glb"
const BIPED_LIB_PATH := "res://assets/characters/evelyn_marsh/evelyn_marsh.gltf"
const PROFILE_PATH := "res://data/resident_animation_profiles.json"

static var _caches: Dictionary = {}
static var _profiles: Dictionary = {}


## The cast's canon proportions live in resident_animation_profiles.json
## (body.height/width/head, authored per resident) but the generated rigs
## all ship at the same 1.80 m. Realize the canon with scale transforms:
## (w, h, w) on the whole figure, the head factor as a bone pose scale —
## which survives animation because grafted clips carry no scale tracks.
## Returns the height factor so callers can move nameplates and the like.
static func apply_body(figure: Node3D, slug: String) -> float:
	if _profiles.is_empty():
		var parsed = JSON.parse_string(
				FileAccess.get_file_as_string(PROFILE_PATH))
		for profile in (parsed if parsed is Array else []):
			_profiles[str(profile.slug)] = profile
	var body: Dictionary = _profiles.get(slug, {}).get("body", {})
	if body.is_empty():
		return 1.0
	var h := float(body.get("height", 1.0))
	var w := float(body.get("width", 1.0))
	figure.scale = Vector3(w, h, w)
	var skeleton := _find_skeleton(figure)
	if skeleton:
		var head := skeleton.find_bone("head")
		if head != -1:
			var head_factor := float(body.get("head", 1.0))
			skeleton.set_bone_pose_scale(head,
					Vector3(head_factor, head_factor, head_factor))
	return h


static func apply(model_root: Node) -> bool:
	var player := _find_player(model_root)
	var skeleton := _find_skeleton(model_root)
	if skeleton == null:
		return false
	if player == null:
		# Animation-stripped models (the hero dump ships motion-free by
		# contract) import without an AnimationPlayer; the graft brings
		# its own.
		player = AnimationPlayer.new()
		player.name = "GraftedMoves"
		model_root.add_child(player)
	# Two skeleton families share the building: the generated 22-joint
	# rigs (hips/spine/...) take the retargeted bake, and the Meshy biped
	# family (Hips/Spine02/... — the hero dump AND the creatures, which
	# turn out to carry the same 24 joints) borrows Evelyn's set directly.
	var source := ""
	if skeleton.find_bone("hips") != -1:
		source = LIB_PATH
	elif skeleton.find_bone("Hips") != -1:
		source = BIPED_LIB_PATH
	else:
		return false
	var moves := _animations(source)
	if moves.is_empty():
		return false
	var player_root: Node = player.get_node(player.root_node)
	var skeleton_path := player_root.get_path_to(skeleton)
	var library: AnimationLibrary
	if player.has_animation_library(""):
		library = player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	var grafted := 0
	for entry in moves:
		if library.has_animation(entry.name):
			continue  # a bespoke clip always beats the shared one
		var anim: Animation = entry.animation.duplicate(true)
		# Walk backwards so removals don't shift the indices. Scale tracks
		# are all 1.0 from the bake and would stomp the canon head-size
		# pose scale every frame; the bones keep their own proportions.
		for t in range(anim.get_track_count() - 1, -1, -1):
			if anim.track_get_type(t) == Animation.TYPE_SCALE_3D:
				anim.remove_track(t)
				continue
			var bone := String(anim.track_get_path(t)).get_slice(":", 1)
			anim.track_set_path(t,
					NodePath("%s:%s" % [skeleton_path, bone]))
		anim.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(entry.name, anim)
		grafted += 1
	return grafted > 0


static func _animations(source: String) -> Array:
	if _caches.has(source):
		return _caches[source]
	var collected: Array = []
	var scene := load(source) as PackedScene
	if scene == null:
		push_warning("shared move library missing: " + source)
		return []
	var root := scene.instantiate()
	var player := _find_player(root)
	if player:
		for animation_name in player.get_animation_list():
			collected.append({"name": String(animation_name),
					"animation": player.get_animation(animation_name)})
	root.free()
	_caches[source] = collected
	return collected


static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
