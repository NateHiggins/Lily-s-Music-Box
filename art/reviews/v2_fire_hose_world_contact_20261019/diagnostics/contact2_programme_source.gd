extends RefCounted
## Real physics queries against extracted native cloth, not centreline proxies.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("HOSE WORLD CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func run(root: Node3D,rig: RefCounted,exclusions: Array[RID]) -> RefCounted:
	var contact:=preload("res://scripts/props/native_hose_world_contact.gd").new()
	var started: int=Time.get_ticks_usec()
	check(contact.configure(rig,root.get_world_3d().direct_space_state,exclusions),"full inner/outer native ring profile binds from imported skin")
	print("HOSE WORLD SETUP: ms=",float(Time.get_ticks_usec()-started)/1000.," error=",contact.error)
	if not failures.is_empty():return contact
	check(contact.sections.size()==644,"all644native sections retain32outer and32inner points")
	var rest: PackedVector3Array=rig.strand.points.duplicate()
	check(not contact.intersects_pose(rest),"unobstructed native cloth is clear")
	var body:=StaticBody3D.new();body.name="ClothContactProbe";root.add_child(body)
	var collider:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.004;collider.shape=sphere;body.add_child(collider)
	var frame: Transform3D=rig.model.global_transform*rig.original_frames[0]
	body.global_position=frame*Vector3(0,.004,0)
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(rest),"real4mmprobe fits the native hose bore without a false solid-capsule collision")
	var cloth: Vector3=contact.sections[0].outer[0]+Vector3(0,.004,0)
	body.global_position=frame*cloth
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(contact.intersects_pose(rest) and contact.last_collider==body,"same real probe intersects the actual canvas wall")
	var flat_index: int=-1
	for i in range(contact.sections.size()-1):
		var r:=Vector2.ZERO
		for p: Vector3 in contact.sections[i].outer:r=r.max(Vector2(absf(p.x),absf(p.z)))
		if r.x<.005 and r.y>.030 and rest[i].distance_to(rest[i+1])>.02:flat_index=i;break
	check(flat_index>=0,"actual flattened native strand selected")
	if flat_index>=0:
		var flat_frame: Transform3D=rig.model.global_transform*rig.original_frames[flat_index]
		sphere.radius=.0005;body.global_position=flat_frame*Vector3(0,.030,0)
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		check(not contact.intersects_pose(rest),"small real probe fits the narrow flattened bore")
		body.global_position=flat_frame*Vector3(0,.030,.031)
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		check(contact.intersects_pose(rest) and contact.last_collider==body,"native31mmwide cloth edge blocks a probe that a thin centreline proxy would miss")
	sphere.radius=.004
	var shifted:=rest.duplicate()
	for i in shifted.size():shifted[i]+=Vector3(0,0,.10)
	body.global_position=frame*cloth+rig.model.global_basis*Vector3(0,0,.05)
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(rest) and not contact.intersects_pose(shifted),"probe between two cloth poses is clear at both endpoints")
	started=Time.get_ticks_usec()
	check(contact.veto(rest,shifted) and contact.last_collider==body,"swept native shell blocks tunnelling between otherwise clear poses")
	print("HOSE WORLD SWEEP: ms=",float(Time.get_ticks_usec()-started)/1000.," broad=",contact.broad_queries," cells=",contact.shell_queries)
	var saved: Transform3D=rig.model.global_transform
	rig.model.global_transform=Transform3D(Basis(Vector3.UP,PI),Vector3(-4.35,-3.2,-7.87))
	frame=rig.model.global_transform*rig.original_frames[0]
	body.global_position=frame*cloth
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(contact.intersects_pose(rest) and contact.last_collider==body,"native wall contact survives composed-world rotation and translation")
	body.global_position=frame*Vector3(0,.004,0)
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(rest),"native bore remains open at the transformed world pose")
	rig.model.global_transform=saved
	var old_record: Dictionary=rig.snapshot()
	var goal: Vector3=rest[0]+Vector3(0,0,.10)
	var solved: bool=rig.strand.move_endpoint(goal)
	var proposed: PackedVector3Array=rig.strand.points.duplicate()
	rig.strand.points=rest.duplicate()
	check(solved,"world-veto test starts from a valid constrained proposal")
	if solved:
		var old_frame: Transform3D=rig.model.global_transform*rig.model_frames(rest)[0]
		var new_frame: Transform3D=rig.model.global_transform*rig.model_frames(proposed)[0]
		var edge: Vector3=contact.sections[0].outer[0]
		sphere.radius=.0005;body.global_position=(old_frame*edge+new_frame*edge)*.5
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		check(contact.veto(rest,proposed) and contact.last_collider==body,"real world contact vetoes the solved full-cloth proposal")
		check(not rig.move_endpoint(goal,contact.veto) and rig.snapshot()==old_record,"world-blocked carrying leaves every cloth point and saved pose unchanged")
	body.free()
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.veto(rest,shifted),"removing real obstruction clears the same sweep")
	return contact
