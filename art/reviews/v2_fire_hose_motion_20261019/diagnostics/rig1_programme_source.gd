extends Node3D
## Candidate kinematics/skin and actual grab, not deployed-world acceptance.
class EndpointBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(_hit: Dictionary) -> Dictionary:return provider.call()
var rig:=preload("res://scripts/props/native_hose_rig.gd").new()
var endpoint: EndpointBody
var handle: MeshInstance3D
var player: PlayerController
var held:=false
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("FIRE RIG CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func prepare(model: Node3D) -> bool:
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/fire_capacity_rig.json"))
	check(rig.configure(model,projection),"native skin and original644centreline rings bind")
	if not failures.is_empty():return false
	var library:=preload("res://scripts/props/fire_nozzle_joint_stock.gd").new()
	if not library.load_stock():return false
	endpoint=EndpointBody.new();endpoint.name="CandidateHoseEnd";endpoint.sync_to_physics=false;add_child(endpoint)
	handle=library.make_part("HoseSeat");endpoint.add_child(handle)
	var shape:=CollisionShape3D.new();shape.shape=handle.mesh.create_trimesh_shape();endpoint.add_child(shape)
	endpoint.provider=_grip;_sync()
	return true
func _sync() -> void:
	endpoint.position=rig.strand.points[0]
	endpoint.basis=Basis(Vector3.BACK,1.5708+PI)
func _grip() -> Dictionary:
	return {"owner":self,"part":handle,"frame":self,"kind":"free",
		"read":func():return endpoint.position,
		"write":func(value: Vector3):
			if held and rig.move_endpoint(value):_sync(),
		"begin":func():
			if held:return false
			held=true;return true,
		"owns":func():return held,"end":func():held=false}
func _click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)
func _pose_matches() -> bool:
	for i in rig.indices.size():
		var at: Vector3=rig.model.to_local(rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(rig.indices[i]).origin))
		if at.distance_to(rig.strand.points[i])>.00002:return false
	return true
func run(holder: PlayerController) -> bool:
	player=holder
	check(rig.indices.size()==644 and absf(rig.strand.total_length-15.24)<.00002,"all native ring bones retain the full15.24m strand")
	await get_tree().process_frame
	check(_pose_matches(),"native bind points and rendered skeleton agree at rest")
	var saved: Dictionary=rig.snapshot()
	var before: PackedVector3Array=rig.strand.points.duplicate()
	check(not rig.move_endpoint(Vector3(INF,0,0)) and rig.strand.points==before,"nonfinite carrying is rejected atomically")
	check(not rig.move_endpoint(before[0]+Vector3(.02,0,0),func(_a: PackedVector3Array,_b: PackedVector3Array):return true) and rig.strand.points==before,"a contact-owner veto leaves every cloth point unchanged")
	var invalid: Dictionary=saved.duplicate(true);invalid.points[12][1]+=.01
	check(not rig.restore(invalid) and rig.strand.points==before,"stretched saved cloth is rejected without partial restore")
	invalid=saved.duplicate(true);invalid.version=true
	check(not rig.restore(invalid),"boolean schema version cannot masquerade as numeric version")
	player.position=Vector3(-.05,-1.43,.54);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var pick: Vector3=handle.to_global(Vector3(.026,.004,0))
	player.camera.look_at(pick)
	for frame in 3:await get_tree().process_frame
	check(player._grab.find_target().get("part")==handle,"cursor actually targets the native hose-end fitting")
	if not failures.is_empty():return false
	var camera_before: Transform3D=player.camera.global_transform
	_click()
	check(player._grab.active() and held and rig.strand.points==before,"actual primary click grabs without moving cloth or completing a duty")
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(45,0)
	var started: int=Time.get_ticks_usec();player._unhandled_input(motion)
	print("FIRE RIG MOVE: ms=",float(Time.get_ticks_usec()-started)/1000.," iterations=",rig.strand.last_iterations)
	await get_tree().process_frame
	check(rig.strand.points[0].distance_to(before[0])>.005,"actual mouse motion pays out the constrained native strand")
	check(rig.strand._valid_positions(rig.strand.points) and rig.strand.points[-1]==before[-1],"motion retains every segment length and the fixed upper port")
	check(_pose_matches(),"all644actual skeleton bones follow the moved cloth points")
	check(player.camera.global_transform.is_equal_approx(camera_before),"grabbing cloth leaves camera framing unchanged")
	var moved: PackedVector3Array=rig.strand.points.duplicate()
	_click()
	check(not player._grab.active() and not held and rig.strand.points==moved,"second click releases without snapping or refolding")
	var roundtrip: Variant=JSON.parse_string(JSON.stringify(rig.snapshot()))
	check(rig.restore(saved),"original physical strand restores")
	check(rig.restore(roundtrip) and rig.strand.points==moved,"JSON roundtrip restores exact moved cloth positions")
	_sync()
	return failures.is_empty()
