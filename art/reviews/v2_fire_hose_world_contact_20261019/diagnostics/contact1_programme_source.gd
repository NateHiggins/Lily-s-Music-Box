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
	body.free()
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.veto(rest,shifted),"removing real obstruction clears the same sweep")
	return contact
