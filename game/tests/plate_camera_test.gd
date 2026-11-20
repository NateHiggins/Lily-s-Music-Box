extends Node3D
## The plate camera and the photo bench's own pictures: a blank plate takes what the frame shows; the exposure rides
## with the plate; printing it keeps the picture with the print, and a print lost in the tray loses it. Windowed (it
## reads a frame). Real inventory and bench state, no building.
const Camera := preload("res://scripts/props/plate_camera.gd")
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	print("PLATE CAMERA: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PLATE CAMERA RESULT: needs a window")
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var eye := Camera3D.new()
	add_child(eye)
	eye.make_current()
	var lamp := DirectionalLight3D.new()
	add_child(lamp)
	var thing := MeshInstance3D.new()
	thing.mesh = BoxMesh.new()
	thing.position = Vector3(0, 0, -3)
	add_child(thing)
	var camera := Camera.new()
	add_child(camera)
	for _wait in 4:
		await get_tree().process_frame
	check(PhotoSales.valid(PhotoSales.book()) and PhotoSales.blank_plates() == 0 and PhotoSales.pictured_prints().is_empty(), "the bench starts with no plates and no pictures")
	check(not camera.raise_camera() and not camera.raised, "with no blank plate the camera stays down")
	check(PersonInventory.carry_goods(PersonInventory.PLAYER, PhotoSales.PLATE, "Dry plate") and PersonInventory.carry_goods(PersonInventory.PLAYER, PhotoSales.PLATE, "Dry plate")
			and PhotoSales.blank_plates() == 2, "two plates bought are two blank plates")
	check(camera.raise_camera() and camera.raised and camera.frame_rect().size.x > 100.0
			and absf(camera.frame_rect().size.x / camera.frame_rect().size.y - Camera.PLATE_SHAPE) < 0.01, "raised, the view is masked to the plate's shape")
	camera.lower_camera()
	check(not camera.raised and await camera.take_picture() == 0 and PhotoSales.exposed().is_empty(), "lowered, nothing is taken")
	# A test's pictures stay out of the player's folder; a new campaign's first picture clears an earlier roll.
	check(PhotoSales.pictures_dir() == PhotoSales.TEST_PICTURES and PhotoSales.picture_path(3).begins_with(PhotoSales.TEST_PICTURES),
		"with the player's save not in use, pictures go to the test folder")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PhotoSales.pictures_dir()))
	var stale := Image.create(8, 8, false, Image.FORMAT_RGB8)
	stale.save_webp(PhotoSales.picture_path(7), true, 0.8)
	camera.raise_camera()
	var first: int = await camera.take_picture()
	check(not FileAccess.file_exists(PhotoSales.picture_path(7)), "the first picture of a campaign clears the last campaign's roll")
	var path := PhotoSales.picture_path(first)
	var kept := Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
	check(first == 1 and not camera.raised and kept != null and kept.get_size() == Camera.PICTURE, "the picture is taken, numbered, and written at the plate's size")
	check(PhotoSales.exposed().size() == 1 and int(PhotoSales.exposed()[0].n) == 1 and PhotoSales.blank_plates() == 1
			and PersonInventory.goods_count(PersonInventory.PLAYER, PhotoSales.PLATE) == 2, "the exposure rides with its plate; one plate is still blank")
	# Printed at the counter or lifted from the tray, the print keeps the picture.
	PhotoSales.book()["tray"] = PhotoSales._plate_goes_to_print()
	PersonInventory.spend_goods(PersonInventory.PLAYER, PhotoSales.PLATE)
	PhotoSales.tray_print_done(true)
	check(PhotoSales.pictured_prints() == [1] and PhotoSales.exposed().is_empty() and PhotoSales.blank_plates() == 1, "printed, the print carries picture one")
	camera.raise_camera()
	var second: int = await camera.take_picture()
	PhotoSales.book()["tray"] = PhotoSales._plate_goes_to_print()
	PersonInventory.spend_goods(PersonInventory.PLAYER, PhotoSales.PLATE)
	PhotoSales.tray_print_done(false)
	check(second == 2 and PhotoSales.pictured_prints() == [1] and not PhotoSales.book().has("tray"), "a print lost in the tray loses its picture")
	check(PhotoSales.blank_plates() == 0 and not camera.raise_camera() and PhotoSales.valid(PhotoSales.book()), "and with the plates gone the camera stays down again")
	check(PhotoSales._plate_goes_to_print() == 0, "a blank plate printed carries no picture")
	print("PLATE CAMERA RESULT: %d checks / %d failures" % [checks, failures.size()])
	for text: String in failures:
		print("PLATE CAMERA FAIL: ", text)
	get_tree().quit(0 if failures.is_empty() else 1)
