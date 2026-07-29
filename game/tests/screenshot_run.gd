extends Node
## Screenshot driver (not shipped). Run under xvfb:
##   xvfb-run godot --path game res://tests/Screenshot.tscn
## Renders documentation framegrabs of key building views to $SHOT_DIR.

var root: Node3D
var cam: Camera3D
var _dir := ""

const SHOTS := [
	{"name": "b_01_exterior_street", "pos": Vector3(16, 12, 34),
	 "look": Vector3(0, 8, 0), "overlay": false},
	{"name": "b_02_lobby", "pos": Vector3(-2.5, 1.72, 8.6),
	 "look": Vector3(2.2, 1.2, 5.2), "overlay": false},
	{"name": "b_03_corridor_f04", "pos": Vector3(4.3, 11.25, 7.6),
	 "look": Vector3(4.3, 10.8, -6.0), "overlay": false},
	{"name": "b_04_apartment_4b", "pos": Vector3(-6.6, 11.25, -1.8),
	 "look": Vector3(-13.2, 10.3, -4.9), "overlay": false},
	{"name": "b_05_front_stair", "pos": Vector3(0.3, 1.8, 5.8),
	 "look": Vector3(-2.8, 3.1, 4.4), "overlay": false},
	{"name": "b_06_laundry_b1", "pos": Vector3(-7.8, -1.2, -2.2),
	 "look": Vector3(-11.5, -2.2, -5.4), "overlay": false},
	{"name": "b_07_roof", "pos": Vector3(-6, 21.4, 9.5),
	 "look": Vector3(2, 19.4, -4), "overlay": false},
	{"name": "b_08_acoustic_graph", "pos": Vector3(26, 14, 26),
	 "look": Vector3(0, 7, 0), "overlay": true},
]


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	Conductor.infection = 0.6       # lights react in stills too
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	cam.make_current()
	# stills need more ambient light than gameplay
	for c in root.get_children():
		if c is WorldEnvironment:
			c.environment.ambient_light_energy = 1.1
			c.environment.background_color = Color(0.05, 0.06, 0.10)
	for shot in SHOTS:
		AcousticGraphData.set_overlay_visible(shot.overlay, root)
		cam.global_position = shot.pos
		cam.look_at(shot.look)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_dir, shot.name]
		img.save_png(path)
		print("saved ", path)
	get_tree().quit(0)
