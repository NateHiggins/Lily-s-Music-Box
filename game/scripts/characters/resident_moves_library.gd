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
## 38 gesture/idle/dance clips folded from the merged Meshy packs by
## art/blender/scripts/build_gesture_library.py — same 24-joint biped
## skeleton, so every hero-mesh resident and creature can play them.
const GESTURES_LIB_PATH := "res://assets/characters/shared/biped_gestures.glb"

static var _caches: Dictionary = {}
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
	#
	# UNLESS the model brought its own bake. Borrowing rotations verbatim
	# is only correct while the rigs share bone AXES, and Meshy's newer
	# generations do not (mina_vale/Grey_Elegance: 9-34° of rest delta per
	# bone — borrowed clips corseted, leaned and hunched her). For such a
	# model, bake_model_moves.py bakes the whole set onto its own rig
	# (a rest-relative analytic bake — see that script's docstring for
	# why constraints were wrong) and ships it as <model>_moves.glb
	# beside the mesh, the creature convention. A personal library is
	# complete, so it replaces the shared sources outright. As of the
	# 2026-08-14 cast repopulation EVERY resident ships one, with the
	# model's own raw gait riding along as <slug>_Walk; the shared
	# branches below are the fallback for future models, not the cast's
	# path.
	var sources: Array[String] = []
	var own_moves := ""
	if model_root.scene_file_path != "":
		own_moves = model_root.scene_file_path.get_basename() + "_moves.glb"
	if own_moves != "" and ResourceLoader.exists(own_moves):
		sources = [own_moves]
		print("[MOVES] personal library: ", own_moves)
	elif skeleton.find_bone("hips") != -1:
		sources = [LIB_PATH]
	elif skeleton.find_bone("Hips") != -1:
		sources = [BIPED_LIB_PATH, GESTURES_LIB_PATH]
	else:
		return false
	var moves: Array = []
	for source in sources:
		moves.append_array(_animations(source))
	if moves.is_empty():
		return false
	# No scaling of any kind (final ruling 2026-08-02): models render at
	# their exported size, and tracks are copied untouched.
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
		#
		# Position tracks get the same law, one level further (2026-08-13):
		# they encode the DONOR's joint spacing, not motion. That was
		# invisible while every hero rig was the same 2026-08-02 Meshy
		# generation as Evelyn — her positions equalled their rest — and it
		# corseted the first model from a newer generation (mina_vale /
		# Grey_Elegance, whose rig spaces its joints differently: the clips
		# dragged her joints to Evelyn's spacing every frame and gathered
		# the mesh at the waist). Rotations carry the animation; each body
		# keeps its own skeleton. Only the hips keep their position track,
		# because that one IS motion — the locomotion bob and root carry.
		# Position tracks are copied VERBATIM again (the 2026-08-13 drop
		# is reverted). The drop existed to cure the Grey Elegance corset
		# — donor joint spacing riding in on borrowed position tracks —
		# and that case no longer exists: a cross-generation rig ships a
		# personal <model>_moves.glb bake and never borrows these tracks
		# at all. For the same-generation family the tracks equal their
		# own rest, so verbatim is the longest-proven path with one less
		# special case. (An inflation regression was briefly attributed
		# to the drop and disproven by paired runs: the inflation was the
		# benchmark measuring day versus night, fixed by pinning the
		# clock in perf_probe.)
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
