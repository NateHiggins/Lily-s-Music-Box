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
var contact: RefCounted
func check(ok: bool,label: String) -> void:
	print("FIRE RIG CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func prepare(model: Node3D) -> bool:
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fire_capacity_rig.json"))
	check(rig.configure(model,projection),"native skin and authored centreline rings bind")
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
			if held and contact!=null and contact.ready and rig.move_endpoint(value,contact.veto):_sync(),
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
func _render_high_rings() -> void:
	# Exercise skin indices above the old2048 boundary in the rendered result,
	# rather than relying only on CPU skeleton positions at the long pose.
	var saved_player: Transform3D=player.global_transform
	var saved_camera: Transform3D=player.camera.transform
	var target: Vector3=rig.model.to_global(rig.strand.points[rig.strand.points.size()-100])
	var eye: Vector3=target+rig.model.global_basis*Vector3(.02,.22,.40)
	player.global_position+=eye-player.camera.global_position;player.camera.look_at(target)
	rig.model.visible=false
	for frame in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image=get_viewport().get_texture().get_image()
	rig.model.visible=true
	for frame in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var visible: Image=get_viewport().get_texture().get_image()
	var center:=Vector2i(visible.get_width()/2,visible.get_height()/2)
	var lit_pixels:=0;var difference:=0.0;var samples:=0
	for dx in range(-22,23):
		for dy in range(-22,23):
			if abs(dx)<6 and abs(dy)<6:continue
			var a: Color=hidden.get_pixel(center.x+dx,center.y+dy);var b: Color=visible.get_pixel(center.x+dx,center.y+dy)
			var delta: float=absf(b.r-a.r)+absf(b.g-a.g)+absf(b.b-a.b)
			if delta>.08:lit_pixels+=1
			difference+=delta;samples+=1
	check(lit_pixels>100 and difference/samples>.03,"rendered high-index cloth occupies its expected fully extended position")
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		hidden.save_png(directory.path_join("high_ring_hidden.png"));visible.save_png(directory.path_join("high_ring_visible.png"))
	print("HIGH RING RENDER: pixels=",lit_pixels," mean_rgb_difference=",difference/samples)
	player.global_transform=saved_player;player.camera.transform=saved_camera
func run(holder: PlayerController) -> bool:
	player=holder
	check(rig.indices.size()>3000 and rig.indices.size()==rig.rest.size() and absf(rig.strand.total_length-15.24)<.00002,"all dense native ring bones retain the full15.24m strand")
	var widest:=0.0
	for distance: float in rig.strand.lengths:widest=maxf(widest,distance)
	check(widest<=.005001,"every actual centreline interval is at most5mm within float precision")
	print("FIRE RIG RESOLUTION: rings=",rig.indices.size()," maximum_interval_m=",widest)
	await get_tree().process_frame
	check(_pose_matches(),"native bind points and rendered skeleton agree at rest")
	var saved: Dictionary=rig.snapshot()
	var before: PackedVector3Array=rig.strand.points.duplicate()
	var mutable:=before.duplicate();var cached: Array[Transform3D]=rig.model_frames(mutable)
	mutable[0]+=Vector3(.001,0,0)
	var changed: Array[Transform3D]=rig.model_frames(mutable)
	check(changed[0].origin==mutable[0] and cached[0].origin==before[0],"in-place edits cannot reuse stale native frames")
	cached[0]=Transform3D.IDENTITY
	check(rig.model_frames(before)[0].origin==before[0],"returned frame arrays cannot corrupt cached native geometry")
	check(not rig.move_endpoint(Vector3(INF,0,0)) and rig.strand.points==before,"nonfinite carrying is rejected atomically")
	check(not rig.move_endpoint(before[0]+Vector3(.02,0,0),func(_a: PackedVector3Array,_b: PackedVector3Array):return true) and rig.strand.points==before,"a contact-owner veto leaves every cloth point unchanged")
	var invalid: Dictionary=saved.duplicate(true);invalid.points[12][1]+=.01
	check(not rig.restore(invalid) and rig.strand.points==before,"stretched saved cloth is rejected without partial restore")
	invalid=saved.duplicate(true);invalid.version=true
	check(not rig.restore(invalid),"boolean schema version cannot masquerade as numeric version")
	var inflated:=PackedVector3Array();inflated.resize(before.size());inflated[-1]=rig.strand.anchor
	for i in range(inflated.size()-2,-1,-1):inflated[i]=inflated[i+1]+Vector3.RIGHT*(rig.strand.lengths[i]+.00001)
	check(not rig.strand._valid_positions(inflated),"many individually small errors cannot accumulate into extra hose length")
	check(rig.move_endpoint(rig.strand.anchor+Vector3.RIGHT*(rig.strand.total_length+1.)),"overreach stops at actual stock length")
	check(absf(rig.strand.points[0].distance_to(rig.strand.anchor)-rig.strand.total_length)<.00002 and rig.strand._valid_positions(rig.strand.points),"fully extended strand retains total and per-segment lengths")
	await get_tree().process_frame
	check(_pose_matches(),"all native bones follow the fully extended constraint result")
	await _render_high_rings()
	check(rig.restore(saved),"resting cloth restores after maximum-reach test")
	var world_checks:=preload("res://tests/v2_fire_hose_world_contact_programme.gd").new()
	var excluded: Array[RID]=[endpoint.get_rid(),player.get_rid()]
	contact=await world_checks.run(self,rig,excluded)
	for failure: String in world_checks.failures:check(false,failure)
	player.position=Vector3(-.05,-1.43,.54);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var pick: Vector3=handle.to_global(Vector3(.022,.004,0))
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
	check(rig.strand.points[0].distance_to(before[0])>.005,"actual mouse motion moves the constrained native strand")
	check(rig.strand._valid_positions(rig.strand.points) and rig.strand.points[-1]==before[-1],"motion retains every segment length and the fixed upper port")
	check(_pose_matches(),"all actual skeleton bones follow the moved cloth points")
	check(player.camera.global_transform.is_equal_approx(camera_before),"grabbing cloth leaves camera framing unchanged")
	var moved: PackedVector3Array=rig.strand.points.duplicate()
	_click()
	check(not player._grab.active() and not held and rig.strand.points==moved,"second click releases without snapping or refolding")
	var roundtrip: Variant=JSON.parse_string(JSON.stringify(rig.snapshot()))
	check(rig.restore(saved),"original physical strand restores")
	check(rig.restore(roundtrip) and rig.strand.points==moved,"JSON roundtrip restores exact moved cloth positions")
	_sync()
	return failures.is_empty()
