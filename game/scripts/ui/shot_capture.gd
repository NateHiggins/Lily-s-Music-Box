class_name ShotCapture
extends Node
## F drops a screenshot, and beside it the pose that took it.
##
## Scripted camera stands only ever frame what someone already suspects is
## wrong. The problems that actually survive to the player — a hump at a
## threshold, a texture whose scale reads fine from the doorway and absurd
## from the couch — are found by standing where the player stands. So the
## capture lives here rather than in the debug panel: the panel is built
## only in DEBUG launch mode, and a review tool that works in one launch
## mode is a review tool you have to remember the state of.
##
## Every shot writes a stand string into shots.md next to it. Paste that
## into SHOT_ROOMS and FreeCam reproduces the same eye later, which is how
## a "look at this" becomes a before/after.

signal captured(stem: String, aim: String)

## Outside res:// on purpose: shots are review material, not game data, and
## they land where the rest of the renders already live.
const SHOT_DIR := "res://../art/renders/insitu"

## The debug panel's CanvasLayer, when there is one. Hidden for the one
## frame the shot is taken on, so review images are not half UI.
var chrome: CanvasLayer

var _busy := false


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("shot_capture"):
		capture()
		get_viewport().set_input_as_handled()


func capture() -> void:
	if _busy:
		return
	_busy = true
	var chrome_was := true
	if chrome:
		chrome_was = chrome.visible
		chrome.visible = false
	# Await twice: a visibility change made while handling input is not
	# honoured until the following frame, so a single await would bake the
	# debug panel into the first shot of every session.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if chrome:
		chrome.visible = chrome_was

	var dir_path: String = ProjectSettings.globalize_path(
			SHOT_DIR).simplify_path()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var index := 1
	for existing in DirAccess.get_files_at(dir_path):
		if existing.begins_with("shot_") and existing.ends_with(".png"):
			index = maxi(index, existing.substr(5, 3).to_int() + 1)
	var stem := "shot_%03d" % index
	image.save_png(dir_path.path_join(stem + ".png"))

	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye := Vector3.ZERO
	var facing := Vector3.ZERO
	var aim := "—"
	if camera:
		eye = camera.global_position
		facing = camera.global_rotation_degrees
		var space := camera.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
				eye, eye - camera.global_transform.basis.z * 40.0)
		var owner_root := get_parent()
		if owner_root and owner_root.get("player") != null:
			query.exclude = [owner_root.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.has("collider") and is_instance_valid(hit["collider"]):
			# The bare node name is almost always "StaticBody3D", which
			# identifies nothing. What is worth writing down is the path
			# back to a named ancestor, plus where in the world the ray
			# landed - a plan coordinate can be looked up in the layout.
			var node: Node = hit["collider"]
			var trail: Array[String] = []
			var walk: Node = node
			for _i in 4:
				if walk == null:
					break
				trail.push_front(String(walk.name))
				walk = walk.get_parent()
			var at: Vector3 = hit["position"]
			aim = "%s  @ world (%.2f, %.2f, %.2f)  %.2f m away" % [
					"/".join(trail), at.x, at.y, at.z,
					eye.distance_to(at)]

	var stand := "@%.2f_%.2f_%.2f:%.1f|%.1f" % [eye.x, eye.y, eye.z,
			facing.y, facing.x]
	var entry := "\n## %s.png\npos (%.2f, %.2f, %.2f)  yaw %.1f  pitch %.1f\n" \
			% [stem, eye.x, eye.y, eye.z, facing.y, facing.x] \
			+ "looking at: %s\nstand: %s\nnote:\n" % [aim, stand]
	var log_path := dir_path.path_join("shots.md")
	var handle: FileAccess
	if FileAccess.file_exists(log_path):
		handle = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if handle:
			handle.seek_end()
	else:
		handle = FileAccess.open(log_path, FileAccess.WRITE)
	if handle:
		handle.store_string(entry)
		handle.close()
	print("[shot] %s.png  %s  looking at %s" % [stem, stand, aim])
	captured.emit(stem, aim)
	_busy = false
