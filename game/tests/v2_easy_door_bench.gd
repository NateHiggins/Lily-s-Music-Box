extends Node3D
## Actual input and passage-first control; no environment impact qualification.
var checks:=0
var failures: Array[String]=[]
var player: PlayerController
func check(ok: bool,label: String) -> void:
	checks+=1;print('EASY DOOR CHECK: ',label,' = ',ok)
	if not ok:failures.append(label)
func click() -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;player._unhandled_input(e)
func drag(x: float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(x,0);player._unhandled_input(e)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	var floor_body:=StaticBody3D.new();floor_body.position.y=-.1;add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);shape.shape=box;floor_body.add_child(shape)
	player=PlayerController.new();add_child(player);player.camera.make_current();player.set_lamp_enabled(false);player.set_beam_mask_enabled(false)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);add_child(sun)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for swing: bool in [false,true]:
		var door:=preload('res://scripts/building/orison_v2_fitted_door.gd').new();door.swing_out=swing;door.position.x=4.0 if swing else 0.0;add_child(door)
		player.position=door.position+Vector3(.40,0,.55 if swing else -.55);player.velocity=Vector3.ZERO;player.rotation.y=0.0 if swing else PI
		for frame in 3:await get_tree().physics_frame
		player.camera.look_at(door.to_global(Vector3(door.width-.085,1.0,0)))
		var before:=player.position
		click();check(player._grab.active(),'actual part acquires')
		check(is_zero_approx(door._body.rotation.y),'grab leaves angle unchanged')
		for step in 24:drag(10.0);await get_tree().physics_frame
		check(absf(door._body.rotation.y-door.motion_target_angle(true))<.001,'240-pixel horizontal gesture reaches full stop')
		check(player.position.distance_to(before)>.20,'opening toward player backs the physical character away')
		check(player._grab.active(),'fixed gesture retains grip across the full swing')
		click();check(not player._grab.active(),'next primary releases')
		check(player.get_collision_exceptions().has(door._body),'open leaf gives the player passage priority')
		var saved:=door.mechanism_snapshot();check(door.valid_mechanism(saved),'angle retains existing save schema')
		door.restore_mechanism(saved);check(door.mechanism_snapshot()==saved,'restoration preserves the exact saved angle')
		Input.action_press('move_forward')
		for frame in 90:
			await get_tree().physics_frame
			var crossed: float=door.to_local(player.global_position).z
			if (crossed<-.7 if swing else crossed>.7):break
		Input.action_release('move_forward')
		check((door.to_local(player.global_position).z<-.7 if swing else door.to_local(player.global_position).z>.7),'ordinary walking passes the opened leaf')
		Input.action_press('move_back')
		for frame in 90:
			await get_tree().physics_frame
			var returned: float=door.to_local(player.global_position).z
			if (returned>.8 if swing else returned<-.8):break
		Input.action_release('move_back')

		await get_tree().create_timer(4.2).timeout
		check(door.open and absf(door._body.rotation.y)<absf(door.motion_target_angle(true)),'released leaf starts closing slowly')
		player.camera.look_at(door._body.to_global(Vector3(.4,1,0)));click()
		check(player._grab.active() and not door._easy.closing,'player can interrupt slow closing')
		if player._grab.active():click()
		await get_tree().create_timer(12).timeout
		print("CLOSER DIAGNOSTIC: angle=",door._body.rotation.y," moving=",door._moving," held=",door._hand_gripped," remaining=",door._easy.remaining," closing=",door._easy.closing," processing=",door.is_physics_processing()," player=",door.to_local(player.global_position))
		check(not door.open and is_zero_approx(door._body.rotation.y),'slow closer reaches closed stop')
		check(not player.get_collision_exceptions().has(door._body),'closed leaf restores its ordinary barrier')
		door.leaf_state='locked';player.camera.look_at(door.to_global(Vector3(.4,1,0)));click()
		check(player._grab.active() and player._grab.target.owner==door,'actual input acquires the locked leaf')
		for step in 24:drag(10.0);await get_tree().physics_frame
		check(is_zero_approx(door._body.rotation.y) and door.leaf_state=='locked','fixed gesture retains lock authority')
		check(not player.get_collision_exceptions().has(door._body),'locked leaf retains its barrier')
		if player._grab.active():click()
		door.queue_free();await get_tree().physics_frame
	print('EASY DOOR BENCH: ', 'PASS' if failures.is_empty() else 'FAIL','; ',checks,' checks; ',failures.size(),' failures')
	get_tree().quit(failures.size())
