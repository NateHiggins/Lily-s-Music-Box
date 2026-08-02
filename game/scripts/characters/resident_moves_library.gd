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

static var _cache: Array = []


static func apply(model_root: Node) -> bool:
	var player := _find_player(model_root)
	var skeleton := _find_skeleton(model_root)
	if player == null or skeleton == null:
		return false
	# Only the generated family shares the skeleton; Evelyn's Meshy rig
	# (Hips/LeftArm/...) would accept the tracks and animate nothing.
	if skeleton.find_bone("hips") == -1:
		return false
	var moves := _animations()
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
		for t in anim.get_track_count():
			var bone := String(anim.track_get_path(t)).get_slice(":", 1)
			anim.track_set_path(t,
					NodePath("%s:%s" % [skeleton_path, bone]))
		anim.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(entry.name, anim)
		grafted += 1
	return grafted > 0


static func _animations() -> Array:
	if not _cache.is_empty():
		return _cache
	var scene := load(LIB_PATH) as PackedScene
	if scene == null:
		push_warning("shared resident moves missing: " + LIB_PATH)
		return []
	var root := scene.instantiate()
	var player := _find_player(root)
	if player:
		for animation_name in player.get_animation_list():
			_cache.append({"name": String(animation_name),
					"animation": player.get_animation(animation_name)})
	root.free()
	return _cache


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
