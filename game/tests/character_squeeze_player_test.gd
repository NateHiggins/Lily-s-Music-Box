extends Node3D
## Real player input and collision on diagnostic solids, not native Harukiya proof.
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	print("PLAYER SQUEEZE: ",label," = ",ok)
	if not ok: failures.append(label)
func block(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body); body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = size
	shape.shape = box; body.add_child(shape)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var preview := RealityState.begin_preview_campaign(self)
	if not preview: get_tree().quit(2); return
	block(Vector3(0,-.1,0),Vector3(10,.2,10))
	block(Vector3(0,1,-2),Vector3(10,2,.2))
	var player := PlayerController.new(); add_child(player)
	player.global_position = Vector3(0,.02,1.2)
	player.set_mouse_released(false)
	var peer := Node3D.new(); add_child(peer)
	peer.add_to_group("animated_residents")
	var prior_mouse := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	Input.action_press("move_forward")
	var minimum_z := 100.0
	var yielded := false
	var previous := player.position
	for i in Engine.physics_ticks_per_second*8:
		await get_tree().physics_frame
		minimum_z = minf(minimum_z,player.position.z)
		if player.position.z>.60 and player.position.z<.80 and player.position.distance_to(previous)<.001: yielded=true
		previous = player.position
	Input.action_release("move_forward")
	check(yielded,"directional input briefly yields to the actual nearby actor")
	check(player.position.z<-.7,"directional input squeezes past actor")
	check(minimum_z > -1.9,"solid wall remains impassable")
	check(player._squeeze.cue_count==1,"one courtesy cue for passage")
	check(player.get_collision_exceptions().is_empty(),"no native collision exceptions added")
	Input.mouse_mode = prior_mouse
	RealityState.end_preview_campaign(self)
	get_tree().quit(0 if failures.is_empty() else 1)
