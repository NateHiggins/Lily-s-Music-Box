extends Node
## K0-RADIO representative inspection sheet. Production-live proves the 18
## placements; this bounded stage makes the distinct mechanisms readable.

const RadioScript := preload("res://scripts/props/domestic_radio_prop.gd")
const UNITS := ["1D", "2A", "2C", "3A", "4B", "5B", "4B", "4B"]
const NAMES := ["01_night_nurse_headphones", "02_signal_workers_1928_ac_set",
	"03_homebuilt_regenerative", "04_quiet_crystal_set",
	"05_players_furnished_wireless", "06_collectors_principal_set",
	"Z_control_a", "Z_control_b"]

var _dir := ""


func _ready() -> void:
	print("[DOMESTIC RADIO SHOT] stage ready")
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "": _dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	_box(stage, Vector3(2.4, 0.08, 1.7), Vector3(0, -0.04, 0), Color(0.12, 0.07, 0.04))
	_box(stage, Vector3(2.4, 1.8, 0.08), Vector3(0, 0.9, 0.65), Color(0.18, 0.13, 0.09))
	_box(stage, Vector3(1.45, 0.72, 0.58), Vector3(0, 0.36, 0.05), Color(0.24, 0.11, 0.045))
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, -2.15)
	camera.fov = 42.0
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.88, 0), Vector3.UP)
	camera.make_current()
	var key := SpotLight3D.new()
	key.position = Vector3(-0.8, 1.65, -1.1)
	key.light_color = Color(1.0, 0.75, 0.52)
	key.light_energy = 2.3
	key.spot_range = 5.0
	key.spot_angle = 42.0
	stage.add_child(key)
	key.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.9, 1.25, -0.6)
	fill.light_color = Color(0.48, 0.60, 0.82)
	fill.light_energy = 0.65
	fill.omni_range = 4.0
	stage.add_child(fill)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/domestic_radios.json"))
	var profiles := {}
	for profile in catalog.profiles: profiles[str(profile.unit)] = profile
	var current: Node = null
	for i in UNITS.size():
		if current != null:
			current.queue_free()
			await get_tree().process_frame
		current = RadioScript.new()
		current.call("configure", profiles[UNITS[i]])
		current.position = Vector3(0, 0.72, 0)
		stage.add_child(current)
		for _frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [_dir, NAMES[i]]
		var error := viewport.get_texture().get_image().save_png(path)
		print("[DOMESTIC RADIO SHOT] %s %s" % ["saved" if error == OK else "FAIL", path])
		if error != OK:
			get_tree().quit(1)
			return
	print("[DOMESTIC RADIO SHOT] RESULT: PASS")
	get_tree().quit()


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mesh.material_override = mat
	parent.add_child(mesh)
