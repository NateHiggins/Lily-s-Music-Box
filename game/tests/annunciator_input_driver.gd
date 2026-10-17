extends RefCounted
## Shared actual-input gestures in a bench or rotated installed board frame.
var context: Node3D
var board: OtisProp
var player: PlayerController
var motion: Node3D
var verify: Callable
func _init(owner: Node3D,mechanism: OtisProp,actor: PlayerController,driver: Node3D,assertion: Callable) -> void:
	context=owner;board=mechanism;player=actor;motion=driver;verify=assertion

func focus(part: Node3D) -> void:
	var at := part.to_global(Vector3(.010,.035,0)) if part==board._reset_spindle else part.global_position
	if player.inspecting():Input.warp_mouse(player.camera.unproject_position(at))
	else:
		player.camera.global_position=at+board.global_basis*Vector3(.012,.025,.32)
		player.camera.look_at(at)
	await context.get_tree().physics_frame
	await context.get_tree().physics_frame

func move(part: Node3D,goal: float) -> void:
	await focus(part)
	verify.call(player._grab.find_target().get("part")==part,"cursor finds actual control: "+str(part.name))
	var initial := part.transform
	motion._click(player)
	verify.call(player._grab.active(),"click grabs actual control")
	verify.call(initial.is_equal_approx(part.transform),"grab alone does not change control position")
	if not player._grab.active():return
	motion._drag_to(player,goal)
	var reached := part.transform
	motion._click(player)
	verify.call(not player._grab.active(),"second click releases control")
	verify.call(reached.is_equal_approx(part.transform),"release does not snap control before its physical return")
