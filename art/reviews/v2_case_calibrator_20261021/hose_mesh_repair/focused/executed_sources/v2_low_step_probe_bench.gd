extends Node3D
## Paired actual Input movement against identical original physical fixtures.
var failures: Array=[]
var observations: Array=[]
func _ready() -> void:_run.call_deferred()
func _box(size: Vector3,at: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var node:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;node.shape=box;body.add_child(node);body.position=at;add_child(body);return body
func check(ok: bool,label: String) -> void:
	print("LOWER CAP EQUIVALENCE: ",label," = ",ok)
	if not ok:failures.append(label)
func _run() -> void:
	_box(Vector3(20,.2,20),Vector3(0,-.1,0))
	for fixture: String in ["step_100","step_200","step_280","step_300","step_310","wall","headroom","thin_curb","ramp","crouched","small_radius","rotated_capsule"]:
		var traces: Array=[]
		for candidate: bool in [false,true]:
			var player: PlayerController=PlayerController.new();add_child(player);player.set_lamp_enabled(false)
			if candidate:player.enable_low_step_probe()
			player._set_crouched(fixture=="crouched")
			if fixture=="small_radius":player._capsule.radius=.20
			if fixture=="rotated_capsule":player._shape.rotation.x=.05
			var height: float=.2
			if fixture.begins_with("step_"):height=float(fixture.trim_prefix("step_"))/1000.
			if fixture=="wall":height=2.
			var obstacle:=_box(Vector3(2,height,.02 if fixture=="thin_curb" else .5),Vector3(0,height*.5,0))
			if fixture=="ramp":obstacle.scale=Vector3(1,.5,5);obstacle.rotation.x=.15;obstacle.position.y=.2
			var ceiling: StaticBody3D=null
			if fixture=="headroom":ceiling=_box(Vector3(2,.2,3),Vector3(0,1.72,0))
			player.position=Vector3(0,.02,1.8);player.rotation=Vector3.ZERO;player.velocity=Vector3.ZERO
			for frame in 12:await get_tree().physics_frame
			var rows: Array=[];Input.action_press("move_forward")
			for frame in 120:
				await get_tree().physics_frame
				rows.append({"x":player.position.x,"y":player.position.y,"z":player.position.z,"on_floor":player.is_on_floor()})
			Input.action_release("move_forward");traces.append(rows)
			obstacle.free();if ceiling!=null:ceiling.free()
			player.free()
		var error:=0.;var floor_mismatches:=0
		for index in 120:
			var a: Dictionary=traces[0][index];var b: Dictionary=traces[1][index]
			error=maxf(error,Vector3(a.x,a.y,a.z).distance_to(Vector3(b.x,b.y,b.z)))
			if a.on_floor!=b.on_floor:floor_mismatches+=1
		check(error<.001 and floor_mismatches==0,fixture+" per-tick paired trajectory within1mm and identical floor state")
		observations.append({"fixture":fixture,"max_position_error_m":error,"floor_state_mismatches":floor_mismatches,"original":traces[0],"candidate":traces[1]})
	await _query_is_inert()
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("equivalence.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Fresh controller per leg; twelve paired actual keyboard movement fixtures, original vs lower-cap eligibility; original collision masks/full-capsule lift/raised motion/slide retained. Not runtime qualification or absolute native1um claim.","observations":observations,"failures":failures},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _query_is_inert() -> void:
	var player:=PlayerController.new();player.position=Vector3(3,.02,3);add_child(player);player.set_lamp_enabled(false);player.enable_low_step_probe()
	var probe: CharacterBody3D=player._step_cap
	check(probe.collision_layer==0 and probe.collision_mask==0,"query has no physical layer or idle mask")
	var ball:=RigidBody3D.new();ball.mass=.1;ball.position=Vector3(0,.7,0)
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.05;shape.shape=sphere;ball.add_child(shape);add_child(ball)
	for frame in 120:await get_tree().physics_frame
	check(ball.position.y<.10,"ordinary rigid body reaches real floor through inert query volume")
	probe.collision_layer=1;probe.collision_mask=1;ball.position=Vector3(0,.7,0);ball.linear_velocity=Vector3.ZERO;ball.sleeping=false
	for frame in 120:await get_tree().physics_frame
	check(ball.position.y>.30,"negative control makes that same query volume physically detectable")
	probe.collision_layer=0;probe.collision_mask=0;ball.sleeping=false
	for frame in 120:await get_tree().physics_frame
	check(ball.position.y<.10 and probe.collision_mask==0,"restored inert query cannot leave a hidden obstacle")
	ball.free();player.free()
