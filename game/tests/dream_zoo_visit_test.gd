extends Node3D
## The installed DEBUG launcher and inspection controls. Historical empty bays
## describe design work, while sixteen actual animals occupy other benches.
const Visit := preload("res://scenes/debug/ZooVisit.tscn")
const Catalogue := preload("res://scripts/debug/dream_zoo_catalog.gd")
var zoo: DreamEcologyWarehouse
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var views: Array[Dictionary] = []
var shots := OS.get_environment("SHOT_DIR")
var started := Time.get_ticks_msec()


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _run() -> void:
	if not _check(DisplayServer.get_name() != "headless" and not shots.is_empty() and not FileAccess.file_exists(shots.path_join("runtime_contract.json")), "fresh windowed capture destination"):
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var visit := Visit.instantiate()
	add_child(visit)
	var building: Node
	var player: Node3D
	while Time.get_ticks_msec() - started < 100000:
		await get_tree().process_frame
		building = visit.get("_building")
		if building == null or building.get("warehouse") == null:
			continue
		zoo = building.get("warehouse").get("_ecology")
		player = building.get("player")
		if zoo != null and player != null and zoo.initialized and zoo.hall_aabb().has_point(player.global_position):
			break
	if not _check(zoo != null and player != null and zoo.hall_aabb().has_point(player.global_position) and not zoo.active,
			"ZooVisit puts the player on foot inside the installed V2 zoo"):
		_finish()
		return
	var before := get_viewport().get_camera_3d()
	var counts := zoo.stats()
	_check(counts.species == 16 and counts.placeholder_bays == 15 and counts.voxel_fields == 1 and counts.voxel_textures == 1,
			"sixteen live species and fifteen reserved bays share one warehouse field and texture")
	var panel := visit.call("_find_debug", building) as BuildingDebug
	if not _check(panel != null, "the installed building exposes the inspection controls"):
		_finish()
		return
	panel._open_dream_ecology()
	await _draw()
	if not _check(zoo.active and zoo.camera == get_viewport().get_camera_3d() and zoo._canvas.visible,
			"the Dream ecology control acquires its visible specimen camera"):
		_finish()
		return
	var designed := Catalogue.placeholders()
	var deferred := Catalogue.deferred_groups()
	_check(designed.size() == 6 and deferred.size() == 9, "the catalogue distinguishes six proposed forms from nine deferred exhibits")
	var expected := designed.duplicate()
	expected.append_array(deferred)
	var seen := {}
	for entry: Dictionary in expected:
		var id := str(entry.id)
		_check(not seen.has(id), "unique reserved identity " + id)
		seen[id] = true
		await _bay(entry)
	await _occlusion_control()
	if _press("Hero close-up"):
		await _draw()
		_check(zoo.selected_exhibit == "hero" and zoo._title.text.contains("HERO") and zoo.hero != null
				and zoo.hero.skeleton != null and _framed(zoo.hero.tip_world()), "the installed close-up frames the actual hero tip")
		_capture("hero")
	if _press("Leave camera"):
		await _draw()
		_check(not zoo.active and not zoo._canvas.visible and get_viewport().get_camera_3d() == before,
				"leaving the specimen camera restores the original walking camera")
	_finish()


func _draw() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _button(caption: String) -> Button:
	for node in zoo._canvas.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == caption:
			return button
	return null


func _press(caption: String) -> bool:
	var button := _button(caption)
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled, "available inspection control " + caption):
		return false
	button.pressed.emit()
	return true


func _framed(point: Vector3) -> bool:
	var camera := zoo.camera
	var pixel := camera.unproject_position(point)
	var control_panel := zoo._canvas.get_child(0) as Control
	return not camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(pixel) \
			and not control_panel.get_global_rect().has_point(pixel)


func _ray(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(zoo.camera.global_position, point, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _bay(entry: Dictionary) -> void:
	var id := str(entry.id)
	if not _press(entry.label):
		return
	await _draw()
	var marker := zoo.stations.get(id) as Marker3D
	var sign := zoo._bay_labels.get(id) as Label3D
	if not _check(marker != null and sign != null, "installed bay and physical sign " + id):
		return
	_check(zoo.selected_exhibit == id and zoo._title.text == str(entry.label).to_upper()
			and not str(entry.description).strip_edges().is_empty() and zoo._status.text == entry.description
			and _button(entry.label).tooltip_text == entry.description, "exact selected label and description " + id)
	_check(sign.is_visible_in_tree() and sign.text == str(entry.label) + "\nPLACEHOLDER"
			and _framed(marker.global_position) and _framed(sign.global_position), "selected physical sign and bay frame clear the controls " + id)
	_check(zoo.hall_aabb().has_point(marker.global_position) and zoo.hall_aabb().has_point(zoo.camera.global_position),
			"camera and bay stay inside the hall " + id)
	var hit := _ray(marker.global_position)
	_check(hit.is_empty() and _ray(sign.global_position).is_empty(), "both centre sightlines clear solid hall geometry " + id)
	views.append({"id": id, "title": zoo._title.text, "description": zoo._status.text, "camera": str(zoo.camera.global_position),
			"target": str(marker.global_position), "pixel": str(zoo.camera.unproject_position(marker.global_position)),
			"collider": "" if hit.is_empty() else str(hit.collider.get_path()), "image_sha256": _capture(id)})


func _occlusion_control() -> void:
	var station := zoo.stations.get(zoo.selected_exhibit) as Marker3D
	if not _check(station != null, "negative control uses the last inspected bay"):
		return
	var point := station.global_position
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.45
	shape.shape = box
	blocker.add_child(shape)
	add_child(blocker)
	blocker.global_position = zoo.camera.global_position.lerp(point, 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_ray(point).get("collider") == blocker, "the same sightline detects a deliberately interposed solid")
	blocker.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_ray(point).is_empty(), "removing the control restores an open sightline")


func _capture(id: String) -> String:
	var image := get_viewport().get_texture().get_image()
	var path := shots.path_join(id + ".jpg")
	if not _check(image != null and not image.is_empty() and image.save_jpg(path, 0.9) == OK, "capture drawn frame " + id):
		return ""
	return FileAccess.get_sha256(path)


func _finish() -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	var digest: Array = []
	var script: String = get_script().resource_path
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty()
			and OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest) == 0
			and not digest.is_empty(), "contract binds its runtime source")
	var output := FileAccess.open(shots.path_join("runtime_contract.json"), FileAccess.WRITE)
	if _check(output != null, "contract file opens"):
		output.store_string(JSON.stringify({"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2",
			"production_runtime": false, "scope": "Installed debug ZooVisit, walking entry, reserved inspection and isolated centreline control.",
			"source": {"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
				"runtime_inputs_sha256": str(digest[0]).strip_edges() if not digest.is_empty() else "",
				"test_path": "game/" + script.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(script),
				"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene_file_path)},
			"execution": {"completed": true, "timed_out": false, "exit_code": 0 if failures.is_empty() else 1,
				"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"contracts": {"debug_zoo_inspection": {"executed": not views.is_empty(), "status": "PASS" if failures.is_empty() else "FAIL"}},
			"checks": checks, "views": views, "failures": failures}, "\t"))
		output.flush()
		_check(output.get_error() == OK, "contract file flushes")
	print("[DREAM ZOO VISIT] checks=%d failures=%d reserved_views=%d" % [checks.size(), failures.size(), views.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
