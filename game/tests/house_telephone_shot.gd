extends Node
## PHONE-A bounded mechanism sheet. Production placement belongs to the next
## proof; this makes the ordinary line states readable before story owns one.

const NetworkScript := preload("res://scripts/building/house_telephone_network.gd")
const BoardScript := preload("res://scripts/props/house_switchboard_prop.gd")
const NAMES := ["00_idle_control_a", "00_idle_control_b", "01_asking",
		"02_answered", "03_carrying", "04_released", "05_unanswered"]

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "": _dir = OS.get_user_data_dir().path_join("house_telephone_phone_a")
	DirAccess.make_dir_recursive_absolute(_dir)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	_box(stage, Vector3(2.8, 0.08, 1.8), Vector3(0, -0.04, 0), Color(0.10, 0.055, 0.03))
	_box(stage, Vector3(2.8, 2.0, 0.08), Vector3(0, 1.0, 0.55), Color(0.19, 0.13, 0.085))
	# The board is wall apparatus over a shallow porter shelf, not a console
	# that blocks the lobby floor.
	_box(stage, Vector3(1.12, 0.10, 0.42), Vector3(0, 0.70, -0.12), Color(0.20, 0.09, 0.04))
	var network: Node = NetworkScript.new(); stage.add_child(network)
	for endpoint in JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/house_telephones.json")).endpoints:
		network.call("register_endpoint", endpoint)
	var board: Node3D = BoardScript.new(); board.call("bind_line", network)
	# The prop's working face is local -Z, directly toward this camera.
	board.position = Vector3(0, 0.74, -0.28)
	stage.add_child(board)
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.22, -2.25)
	camera.fov = 37.0; stage.add_child(camera)
	camera.look_at(Vector3(0, 1.12, -0.22), Vector3.UP); camera.make_current()
	var key := SpotLight3D.new(); key.position = Vector3(-0.85, 1.85, -1.15)
	key.light_color = Color(1.0, 0.72, 0.45); key.light_energy = 2.7
	key.spot_range = 5.0; key.spot_angle = 44.0; stage.add_child(key)
	key.look_at(Vector3(0, 1.1, -0.2), Vector3.UP)
	var fill := OmniLight3D.new(); fill.position = Vector3(0.95, 1.25, -0.8)
	fill.light_color = Color(0.42, 0.54, 0.72); fill.light_energy = 0.55
	fill.omni_range = 4.0; stage.add_child(fill)
	for _frame in 4: await get_tree().process_frame
	await _snap(viewport, NAMES[0]); await _snap(viewport, NAMES[1])
	network.call("request", "apt_4b"); await _snap(viewport, NAMES[2])
	network.call("answer", "house_board"); await _snap(viewport, NAMES[3])
	network.call("carry", "outside_trunk"); await _snap(viewport, NAMES[4])
	network.call("release", "house_board"); await _snap(viewport, NAMES[5])
	network.call("request", "apt_3d")
	network.call("expire_unanswered", int((network.call("snapshot") as Dictionary).sequence))
	await _snap(viewport, NAMES[6])
	print("[HOUSE TELEPHONE SHOT] RESULT: PASS captures=%d dir=%s" % [NAMES.size(), _dir])
	get_tree().quit()


func _snap(viewport: SubViewport, label: String) -> void:
	for _frame in 2: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _dir.path_join(label + ".png")
	var error := viewport.get_texture().get_image().save_png(path)
	print("[HOUSE TELEPHONE SHOT] %s %s" % ["capture" if error == OK else "FAIL", path])
	if error != OK: get_tree().quit(1)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = size
	mesh.mesh = box; mesh.position = at
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.72
	mesh.material_override = mat; parent.add_child(mesh)
