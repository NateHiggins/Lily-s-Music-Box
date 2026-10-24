extends Node3D
var failures: Array[String]=[]
func _ready() -> void:_run.call_deferred()
func _box(size: Vector3,at: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);body.position=at;add_child(body);return body
func check(passed: bool,label: String) -> void:
	print("STEP CONTACT CHECK: ",label," = ",passed)
	if not passed:failures.append(label)
func _run() -> void:
	_box(Vector3(12,.2,12),Vector3(0,-.1,0))
	var player:=PlayerController.new();player.position=Vector3(0,.02,1.5);add_child(player);player.set_lamp_enabled(false);player.profile_physics=true
	for disabled: bool in [true,false]:
		player._profile_disable_step_guard=disabled
		for kind: String in ["low_step","high_wall","low_headroom"]:
			var height: float=.2 if kind!="high_wall" else 2.
			var obstacle:=_box(Vector3(2,height,.5),Vector3(0,height*.5,0))
			var ceiling: StaticBody3D=null
			if kind=="low_headroom":ceiling=_box(Vector3(2,.2,3),Vector3(0,1.72,0))
			player.position=Vector3(0,.02,1.5);player.rotation=Vector3.ZERO;player.velocity=Vector3.ZERO
			for frame in 12:await get_tree().physics_frame
			Input.action_press("move_forward")
			for frame in 120:await get_tree().physics_frame
			Input.action_release("move_forward")
			check(player.position.z<-.7 if kind=="low_step" else player.position.z>.45,("original " if disabled else "guard ")+kind+" retains physical traversal/blocking")
			if kind=="high_wall":
				obstacle.position.x=4.
				await RenderingServer.frame_post_draw
				for frame in 2:await get_tree().physics_frame
				Input.action_press("move_forward")
				for frame in 90:await get_tree().physics_frame
				Input.action_release("move_forward")
				check(player.position.z<-.7,("original " if disabled else "guard ")+" removed wall cannot retain a stale obstruction")
			obstacle.free()
			if ceiling!=null:ceiling.free()
	check(player.step_guard_rejections>0,"guard observes actual resolved high contacts")
	print("V2 STEP CONTACT: failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
