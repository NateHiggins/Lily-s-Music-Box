class_name PhoneCamera
extends Node
## The handset's lens, its roll of film, and the roll's cap.
##
## A second Camera3D renders the world into its own small SubViewport;
## that texture is the viewfinder, and the shutter is a copy of it to
## disk. Sharing `world_3d` with the main viewport is the whole trick —
## without it the lens renders an empty scene and the viewfinder is a
## black rectangle with correct fog in it.
##
## THIRTY-NINE PLUS ONE. The roll holds forty. Past that the oldest
## frame is deleted to make room, which is a deliberate design choice
## rather than a storage one: a gallery that grows forever turns into a
## folder nobody opens, and a roll that forgets makes the decision to
## photograph something cost you an earlier photograph. It also means
## the pairs game's deck is always drawn from what you have been
## looking at lately.
##
## Resolution is 320x240 on purpose. It is a 2011 handset; the photos
## should look like a 2011 handset took them, they only ever get seen
## on a 52 mm screen or as a memory-match tile, and forty full-frame
## grabs would be 100 MB of somebody's save directory.

const DIR := "user://photos"
const MANIFEST := "user://photos/manifest.json"
const CAP := 40
const SHOT_W := 320
const SHOT_H := 240

signal captured(path: String, index: int)

var lens: SubViewport
var lens_camera: Camera3D
var roll: Array = []          # newest last; paths into DIR
var active := false

var _host: Node3D
var _flash := 0.0


func setup(host: Node3D) -> void:
	_host = host
	DirAccess.make_dir_recursive_absolute(DIR)
	lens = SubViewport.new()
	lens.size = Vector2i(SHOT_W, SHOT_H)
	lens.transparent_bg = false
	# Idle by default: a second 3D render every frame is the single most
	# expensive thing this phone could do, and the viewfinder is only
	# ever looked at while the camera app is open.
	lens.render_target_update_mode = SubViewport.UPDATE_DISABLED
	lens.handle_input_locally = false
	host.add_child(lens)
	lens_camera = Camera3D.new()
	lens_camera.fov = 58.0        # a little tighter than the player's eye
	lens_camera.current = true
	lens.add_child(lens_camera)
	_load_manifest()


## The lens has to see the same world the player is standing in. A
## SubViewport makes its own World3D unless told otherwise, and the
## symptom of forgetting is a viewfinder showing a correctly-lit void.
func bind_world(from: Viewport) -> void:
	if from:
		lens.world_3d = from.world_3d


func set_active(on: bool) -> void:
	active = on
	lens.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
			else SubViewport.UPDATE_DISABLED


## Keep the lens where the phone is, aimed where the phone is aimed, so
## the viewfinder answers to how the player is holding it rather than
## to where they are looking.
func track(basis_source: Node3D) -> void:
	if lens_camera == null or basis_source == null:
		return
	lens_camera.global_transform = basis_source.global_transform


func viewfinder_texture() -> Texture2D:
	return lens.get_texture()


func flash_amount() -> float:
	return _flash


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)


## Take the picture. Returns the path, or "" if the lens had nothing.
func capture() -> String:
	if lens == null:
		return ""
	var tex := lens.get_texture()
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "")
	var path := "%s/%s_%03d.png" % [DIR, stamp.replace("-", ""),
			randi() % 1000]
	if img.save_png(path) != OK:
		push_warning("phone camera: could not write " + path)
		return ""
	roll.append(path)
	_enforce_cap()
	_save_manifest()
	_flash = 1.0
	captured.emit(path, roll.size())
	return path


## Oldest out. Deleting the file as well as the entry matters: the roll
## is also the pairs game's deck, and a manifest pointing at a file that
## is not there is a blank tile nobody can match.
func _enforce_cap() -> void:
	while roll.size() > CAP:
		var gone: String = roll.pop_front()
		DirAccess.remove_absolute(gone)


func _save_manifest() -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"cap": CAP,
		"count": roll.size(),
		"note": "Photographs taken in the Orison on the handset's own "
				+ "camera. Written for the phone's gallery and read by "
				+ "the pairs game, which deals its deck from whatever "
				+ "is in here. Newest last.",
		"photos": roll,
	}, "  "))


func _load_manifest() -> void:
	roll.clear()
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for p in data.get("photos", []):
		# Survive a save directory somebody has been tidying by hand.
		if FileAccess.file_exists(str(p)):
			roll.append(str(p))


## What the pairs game needs: an even number of distinct images, at
## least `pairs` of them. Returns [] when the roll is too thin, so the
## caller can say so rather than dealing a broken board.
func deck_for_pairs(pairs := 8) -> Array:
	if roll.size() < pairs:
		return []
	var pool := roll.duplicate()
	pool.shuffle()
	return pool.slice(0, pairs)


func load_photo(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)
