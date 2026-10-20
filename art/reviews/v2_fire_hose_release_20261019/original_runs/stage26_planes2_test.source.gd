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
	check(contact.sections.size()==rig.indices.size() and contact.sections.size()>3000,"all dense native sections retain32outer and32inner points")
	var rest: PackedVector3Array=rig.strand.points.duplicate()
	var invalid:=rest.duplicate();invalid[0]=Vector3(INF,0,0)
	check(contact.veto(rest,invalid),"invalid contact coordinates are rejected before broad-phase queries")
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
		if r.x>=.005 or r.y<=.030 or i+8>=rest.size():continue
		var axis: Vector3=(rest[i+1]-rest[i]).normalized();var straight:=true
		for step in range(1,8):
			if axis.dot((rest[i+step+1]-rest[i+step]).normalized())<.999999:straight=false;break
		if straight:flat_index=i;break
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
	contact.chunked=false
	check(contact.veto(rest,shifted) and contact.last_collider==body,"per-segment reference query agrees with chunked swept contact")
	contact.chunked=true
	var saved: Transform3D=rig.model.global_transform
	rig.model.global_transform=Transform3D(Basis(Vector3.UP,PI),Vector3(-4.35,-3.2,-7.87))
	frame=rig.model.global_transform*rig.original_frames[0]
	body.global_position=frame*cloth
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(contact.intersects_pose(rest) and contact.last_collider==body,"native wall contact survives composed-world rotation and translation")
	body.global_position=frame*Vector3(0,.004,0)
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(rest),"native bore remains open at the transformed world pose")
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fire_capacity_rig.json"))
	for height: float in [-3.2,9.6,19.2]:
		for angle: float in [PI,-PI]:
			var clone:=rig.model.duplicate() as Node3D;root.add_child(clone)
			clone.global_transform=Transform3D(Basis(Vector3.UP,angle),Vector3(-4.35,height,-7.87))
			var second_rig:=preload("res://scripts/props/native_hose_rig.gd").new()
			var second_contact:=preload("res://scripts/props/native_hose_world_contact.gd").new()
			var bound: bool=second_rig.configure(clone,projection) and second_contact.configure(second_rig,root.get_world_3d().direct_space_state,exclusions)
			check(bound,"fresh native contact binding at floorheight/orientation "+str([height,angle]))
			if not bound:print("HOSE WORLD BIND ERROR: ",second_contact.error)
			clone.free()
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
	await _response_planes(root,rig,contact,rest)
	return contact
func _response_planes(root: Node3D,rig: RefCounted,contact: RefCounted,rest: PackedVector3Array) -> void:
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(.045,.04,.07);shape.shape=box;wall.add_child(shape);root.add_child(wall)
	var lowest:=INF
	var frame: Transform3D=rig.model_frames(rest)[0]
	for p: Vector3 in contact.sections[0].outer:lowest=minf(lowest,(frame*p).y)
	var local:=Transform3D(Basis.IDENTITY,Vector3(rest[0].x-.01,lowest-.02+.0005,rest[0].z))
	var original: Transform3D=rig.model.global_transform
	for world: Transform3D in [original,Transform3D(Basis(Vector3.UP,PI),Vector3(-4.35,9.6,-7.87))]:
		rig.model.global_transform=world;wall.global_transform=world*local
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		var result: Dictionary=contact.contact_constraints(rest)
		check(result.valid and not result.truncated and not result.planes.is_empty(),"native cloth yields bounded contact response planes "+str(world.origin))
		var correct: bool=not result.planes.is_empty();var shift:=0.
		for plane: Dictionary in result.planes:
			correct=correct and plane.normal.dot(Vector3.UP)>.999 and plane.rid==wall.get_rid()
			shift=maxf(shift,plane.offset-plane.normal.dot(rest[plane.ring]))
		check(correct and shift>.0004 and shift<.001,"response direction and depth derive from actual500micrometre cloth intrusion")
		var lifted:=rest.duplicate()
		for i in lifted.size():lifted[i]+=Vector3.UP*shift
		check(not contact.intersects_pose(lifted),"native shell clears real wall after measured response translation")
		result=contact.contact_constraints(rest,2)
		check(result.valid and result.truncated and result.planes.size()==2,"bounded contact collection reports truncation explicitly")
	rig.model.global_transform=original;wall.free()
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	var clear: Dictionary=contact.contact_constraints(rest)
	check(clear.valid and not clear.truncated and clear.planes.is_empty(),"removed wall leaves no cached contact planes")

