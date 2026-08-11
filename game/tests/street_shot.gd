extends Node
## The street from the kerb, four moments apart, to see the stream move.
##     SHOT_DIR=<abs> godot --path game res://tests/StreetShot.tscn
var root: Node3D
var cam: Camera3D
var _n := 0

func _ready() -> void:
	set_process(false)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	for c in get_tree().root.get_children():
		_sweep(c)
	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	# Standing on the north walk, looking across the carriageway.
	# Looking ALONG the carriageway, not across it. Five vehicles spread over a
	# hundred metres are almost never in a narrow across-the-road cone; down
	# the street they are a queue.
	# ON THE PAVEMENT. y -15.6 put the lens inside the westbound lane, so every
	# vehicle passed within a metre and filled the frame with a black wall.
	# The walks end at -14.6; a person stands at about -13.6.
	cam.global_position = GameBoot.b2g([-16.0, -13.5, 1.68])
	cam.look_at(GameBoot.b2g([26.0, -19.6, 1.30]))
	await get_tree().create_timer(3.0).timeout
	set_process(true)

func _sweep(n: Node) -> void:
	if n is CanvasLayer:
		n.visible = false
	if n is Label3D:
		n.visible = false
	for c in n.get_children():
		_sweep(c)

func _process(_d: float) -> void:
	_n += 1
	if _n % 45 != 0:
		return
	await RenderingServer.frame_post_draw
	var i := _n / 45
	get_viewport().get_texture().get_image().save_png(
			"%s/street_%d.png" % [OS.get_environment("SHOT_DIR"), i])
	if i >= 4:
		print("[STREET] shots saved")
		get_tree().quit(0)
