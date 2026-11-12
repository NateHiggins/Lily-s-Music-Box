extends Node3D
## The rebuilt cast and the shared clip library: every installed body takes the clips the residents ask for
## from ResidentMovesLibrary, keeps its own joint spacing, and stays on the floor while it plays them.
## Real imported assets under res://assets/characters/cast; no building, dialogue or saves.
const BASE := "res://assets/characters/cast"
const FEET: Array[String] = ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]
const STANDING: Array[String] = ["clip_01", "walk", "mina_walk", "mina_idle_calm"]
## How far a foot joint may dip below where it rests. Bodies of another build than the one the clips were baked
## on stand a little low; more than this is a broken hip track.
const FLOOR_TOLERANCE := 0.035
## The same clip puts every body in the same pose: how far the trunk and head turn from each body's own rest
## must agree across the cast. With clips that carried the donor's rest pose the men's chests sat 20 degrees
## further over than the women's.
const TRUNK: Array[String] = ["Spine2", "Neck", "Head"]
const TRUNK_DEGREES_APART := 2.0

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CAST MOVES: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _lowest(skeleton: Skeleton3D) -> float:
	var low := 99.0
	for bone: String in FEET:
		low = minf(low, (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))).origin.y)
	return low


func run() -> void:
	var people: Array[String] = []
	for folder: String in DirAccess.get_directories_at(BASE):
		if ResourceLoader.exists("%s/%s/%s.gltf" % [BASE, folder, folder]):
			people.append(folder)
	people.sort()
	check(not people.is_empty(), "at least one cast body is installed")
	check(ResourceLoader.exists(ResidentMovesLibrary.CAST_LIB_PATH), "the shared cast clip library is installed")
	var wanted: Array[String] = ["walk", "run"]
	for number in range(1, 9):
		wanted.append("clip_%02d" % number)
	for clip: String in MinaAnimationBehavior.CLIPS:
		wanted.append(clip)
	var turned: Dictionary = {}
	for id: String in people:
		var body := (load("%s/%s/%s.gltf" % [BASE, id, id]) as PackedScene).instantiate() as Node3D
		add_child(body)
		var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var rest_low := _lowest(skeleton)
		check(ResidentMovesLibrary.apply(body), id + " takes the shared clips")
		var players := body.find_children("*", "AnimationPlayer", true, false)
		check(players.size() == 1, id + " has one clip player")
		if players.size() != 1:
			body.queue_free()
			continue
		var player := players[0] as AnimationPlayer
		var missing: Array[String] = []
		for clip: String in wanted:
			if not player.has_animation(clip):
				missing.append(clip)
		check(missing.is_empty(), "%s has every clip asked for (missing %s)" % [id, missing])
		var foreign := 0
		var unresolved := 0
		var walk := player.get_animation("walk")
		var root := player.get_node(player.root_node)
		for track in walk.get_track_count():
			var path := walk.track_get_path(track)
			var bone := String(path).get_slice(":", 1)
			if root.get_node_or_null(NodePath(String(path).get_slice(":", 0))) != skeleton or skeleton.find_bone(bone) == -1:
				unresolved += 1
			if walk.track_get_type(track) == Animation.TYPE_POSITION_3D and bone != "Hips":
				foreign += 1
			if walk.track_get_type(track) == Animation.TYPE_SCALE_3D:
				foreign += 1
			if bone.begins_with("Skirt"):
				foreign += 1
		check(unresolved == 0, id + " walk tracks all land on its own skeleton")
		check(foreign == 0, id + " keeps its own joint spacing (no borrowed position, scale or skirt tracks)")
		var trunk_rest: Dictionary = {}
		for bone: String in TRUNK:
			trunk_rest[bone] = skeleton.get_bone_global_rest(skeleton.find_bone(bone))
		for clip: String in STANDING:
			if not player.has_animation(clip):
				continue
			player.play(clip)
			var length := player.get_animation(clip).length
			var deepest := 99.0
			var bent := 0.0
			for step in 8:
				player.seek(length * step / 8.0, true)
				await get_tree().process_frame
				deepest = minf(deepest, _lowest(skeleton) - rest_low)
				if step == 0 and clip in ["clip_01", "mina_idle_calm"]:
					for bone: String in TRUNK:
						var now := skeleton.get_bone_global_pose(skeleton.find_bone(bone))
						var rest: Transform3D = trunk_rest[bone]
						bent = maxf(bent, rad_to_deg(now.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion())))
			# The lowest foot is on the floor at some moment of every standing clip: neither sunk nor floating.
			check(absf(deepest) < FLOOR_TOLERANCE, "%s stays on the floor in %s (%.3f m)" % [id, clip, deepest])
			if clip in ["clip_01", "mina_idle_calm"]:
				if not turned.has(clip):
					turned[clip] = {}
				turned[clip][id] = bent
		body.queue_free()
		await get_tree().process_frame
	for clip: String in turned:
		var least := 999.0
		var most := 0.0
		for id: String in turned[clip]:
			least = minf(least, float(turned[clip][id]))
			most = maxf(most, float(turned[clip][id]))
		check(most - least < TRUNK_DEGREES_APART, "every body holds the same pose in %s (trunk turned %.1f to %.1f degrees from rest)" % [clip, least, most])
	print("CAST MOVES RESULT: ", checks, " checks / ", failures.size(), " failures")
	print("CAST MOVES TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
