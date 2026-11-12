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
		check(unresolved == 0, id + " walk tracks all land on its own skeleton")
		check(foreign == 0, id + " keeps its own joint spacing (no borrowed position or scale tracks)")
		for clip: String in STANDING:
			if not player.has_animation(clip):
				continue
			player.play(clip)
			var length := player.get_animation(clip).length
			var deepest := 0.0
			for step in 8:
				player.seek(length * step / 8.0, true)
				await get_tree().process_frame
				deepest = minf(deepest, _lowest(skeleton) - rest_low)
			check(deepest > -FLOOR_TOLERANCE, "%s stays on the floor in %s (%.3f m)" % [id, clip, deepest])
		body.queue_free()
		await get_tree().process_frame
	print("CAST MOVES RESULT: ", checks, " checks / ", failures.size(), " failures")
	print("CAST MOVES TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
