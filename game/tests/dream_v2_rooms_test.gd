extends Node3D
## The dream is made of V2's rooms (order wc0265c4a2ba0, ruling dream_v2_direction_20261116: The Remembered Orison).
## The catalog names only real V2 blockout spaces and matches its generator; the fractal Orison builds from it with
## no defect; every module is reached in the endless building; every room keeps its hazards inside its walls.
## With SHOT_DIR, frames from the waking room and from rooms further in, by the player's own lamp.
const SEED_HEX := "f123456789abcdef"
const BLOCKOUT := "res://data/orison_v2_blockout.json"

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("DREAM V2 ROOMS: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _blockout_ids() -> Dictionary:
	var ids := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BLOCKOUT))
	for key: String in ["spaces", "platforms", "envelopes"]:
		for row: Dictionary in data.get(key, []):
			ids[str(row.id)] = true
	return ids


func run() -> void:
	RealityState.persistence_enabled = false
	var catalog := DreamMazeBuilder.load_catalog()
	check(str(catalog.meta.source_layout) == "game/data/orison_v2_blockout.json", "the catalog is cut from the V2 blockout")
	var ids := _blockout_ids()
	for module_id: String in catalog.modules:
		for record: Dictionary in catalog.modules[module_id].source.records:
			check(ids.has(str(record.id)), "%s is made of a real V2 space: %s" % [module_id, record.id])
	check(is_equal_approx(float(catalog.constants.clear_ceiling_m), 3.0), "the dream's ceiling is V2's clear height")

	var root: DreamMazeRoot = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis", "profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": ""})
	add_child(root)
	for frame in 3:
		await get_tree().process_frame
	check(root.maze_built, "the dream builds")
	check(not root.plan.has("defects") or (root.plan.defects as Array).is_empty(), "with no defect: %s" % [root.plan.get("defects", [])])
	check(root.rooms != null and not root.rooms.room_at_key(root._here_key).is_empty(), "the waking room is placed")
	if root.rooms == null:
		_finish()
		return

	# Walk the endless building on paper: every path to depth four.
	var reached := {}
	var frontier: Array = [root._here_path]
	var described := 0
	for depth in 4:
		var next: Array = []
		for path: PackedInt32Array in frontier:
			for door in 3:
				var step := path.duplicate()
				step.append(door)
				var room: Dictionary = root.rooms.describe(step)
				if room.is_empty():
					continue
				described += 1
				reached[str(room.source)] = int(reached.get(str(room.source), 0)) + 1
				var rect: Array = room.rect
				for hazard: Dictionary in room.hazards:
					var at: Array = hazard.position
					var r := float(hazard.clearance_radius_m)
					check(float(at[0]) - r >= float(rect[0]) - 0.001 and float(at[0]) + r <= float(rect[2]) + 0.001 							and float(at[1]) - r >= float(rect[1]) - 0.001 and float(at[1]) + r <= float(rect[3]) + 0.001,
							"%s keeps %s and its clearance inside its walls" % [room.source, hazard.id])
				next.append(step)
		frontier = next
	print("DREAM V2 ROOMS reached ", reached, " over ", described, " rooms")
	# Her Day, Folded: Mina's print lends the dream her own day, deeper is later, the day folds.
	var day_rooms := 0
	for module_id: String in reached:
		if module_id.begins_with("DAY_"):
			check(module_id.begins_with("DAY_mina_vale_"), "only the subject's own day is lent: %s" % module_id)
			day_rooms += int(reached[module_id])
	check(day_rooms > described / 4, "about half the rooms are her day: %d of %d" % [day_rooms, described])
	var atlas := DreamAtlas.new()
	atlas.setup(SEED_HEX, 0, "mina_caption_crisis", "mina_vale", "sat")
	var day: Array = []
	for row: Dictionary in catalog.days:
		if str(row.day_of) == "mina_vale" and str(row.weekday) == "sat":
			day.append(row)
	check(not day.is_empty() and day.any(func(row: Dictionary) -> bool: return str(row.source.records[0].id) == "B1_LAUNDRY"),
			"Mina's Saturday is her own Saturday: it takes in the laundry")
	day.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.day_order) < int(b.day_order))
	var ordered := true
	for path: PackedInt32Array in [PackedInt32Array([0]), PackedInt32Array([1, 2]), PackedInt32Array([2, 0, 1]), PackedInt32Array([0, 0, 0, 0, 1, 2, 0, 1, 2, 1])]:
		var room: Dictionary = atlas.room(path)
		if str(room.source).begins_with("DAY_"):
			ordered = ordered and str(room.source) == str(day[path.size() % day.size()].id)
	check(ordered, "deeper is later in her day, folding back to its morning")
	var plain := DreamAtlas.new()
	plain.setup(SEED_HEX, 0, "", "")
	var leaked := 0
	for i in 200:
		var path := PackedInt32Array([i % 3, (i / 3) % 3, (i / 9) % 3, (i / 27) % 3])
		if str(plain.room(path).source).begins_with("DAY_"):
			leaked += 1
	check(leaked == 0, "with no subject the dream lends no one's day (%d)" % leaked)
	check(described > 50, "the building goes on: %d rooms described to depth four" % described)
	for module_id: String in catalog.modules:
		if not module_id.begins_with("DAY_"):
			check(reached.has(module_id) or module_id == "D00_4B_THRESHOLD", "%s is reached in the building" % module_id)

	var shots := OS.get_environment("SHOT_DIR")
	if not shots.is_empty():
		await _shots(root, shots)
	_finish()


func _shots(root: DreamMazeRoot, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	root.player.set_physics_process(false)
	root.player.camera.make_current()
	root.player.set_lamp_enabled(true)
	var live: Dictionary = root.rooms._live
	var taken := 0
	for key: String in live:
		var room: Dictionary = live[key]
		var rect: Array = room.rect
		var centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0, (float(rect[1]) + float(rect[3])) * 0.5)
		var corner := Vector3(float(rect[0]) + 0.6, 0.0, float(rect[1]) + 0.6)
		root.player.global_position = corner
		root.player.look_at_from_position(corner, Vector3(centre.x, corner.y, centre.z))
		root.player.rotation.x = 0.0
		for frame in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("room_%02d_%s.png" % [taken, str(room.source)]))
		taken += 1
		if taken >= 6:
			break


func _finish() -> void:
	print("DREAM V2 ROOMS RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
