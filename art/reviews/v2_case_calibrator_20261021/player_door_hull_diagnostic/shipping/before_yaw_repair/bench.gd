extends "res://tests/v2_fire_hand_bench.gd"
const Contacts=preload("res://scripts/building/v2_fire_player_contact.gd")
func _prepare_player_contacts(native: RefCounted) -> void:
	check(player._native_contact_agent==null and player.collision_mask==1,"standalone and V1 player retains original collision policy by default")
	var agent:=Contacts.new()
	if not check(agent.configure(player,native.stations),"shipping contact stock installs against all eight native stations"):return
	check(agent.ready and agent.active and agent.pairs.size()==8 and (player.collision_mask&1)==1,"all eight substitutions are active with original world collision retained")
	var exact:=true;var leaves:=0
	for reference: WeakRef in native.stations.values():
		var actor: Node3D=reference.get_ref();var original: PhysicsBody3D=actor._bodies.door
		var proxy: StaticBody3D=original.get_node("PlayerContactStock")
		exact=exact and (original.collision_layer&1)==1 and proxy.collision_layer==Contacts.LAYER and proxy.collision_mask==0 and proxy.get_child_count()==actor._stock.door.size()
		for i in proxy.get_child_count():
			var leaf: CollisionShape3D=proxy.get_child(i)
			exact=exact and leaf.shape==actor._stock.door[i].shape and leaf.transform==actor._stock.door[i].frame;leaves+=1
	check(exact and leaves==72,"72 shipping query shapes reuse the exact authoritative resources and part frames; original colliders remain")
	var original_pose: Transform3D=player.transform
	for i in 1000:
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion)
	agent.sync()
	print("CONTACT LOOK STRESS: supported=",agent._supported()," active=",agent.active," scale=",player.global_basis.get_scale()," up=",player.global_basis.y.normalized().dot(Vector3.UP)," radius=",player._capsule.radius)
	check(agent.active,"shipping contact survives extended ordinary looking")
	player.transform=original_pose;agent.sync()
	player._set_crouched(true);agent.sync()
	check(agent.active,"ordinary crouching retains supported player contact")
	player._set_crouched(false)
	var radius: float=player._capsule.radius;player._capsule.radius=.20;agent.sync()
	check(not agent.active and player.collision_mask==1 and _no_door_exceptions(agent),"unsupported smaller capsule falls back to all original door collision")
	player._capsule.radius=radius;agent.sync()
	var basis: Basis=player._shape.basis;player._shape.rotation.x=.05;agent.sync()
	check(not agent.active and player.collision_mask==1 and _no_door_exceptions(agent),"tilted capsule falls back to original contact without a mask gap")
	player._shape.basis=basis;agent.sync()
	player.noclip=true;agent.sync()
	check(not agent.active and player.collision_mask==0 and _no_door_exceptions(agent),"debug noclip policy removes all substitutions")
	player.noclip=false;agent.sync()
	check(agent.active and player.collision_mask==(1|Contacts.LAYER),"restoring ordinary play reinstates protected native contact")
	# Use the same physical shape and world mask as mechanism constraints.
	# Body-pair exceptions used for movement must not hide the actual player.
	var part: Dictionary=native.stations.values()[0].get_ref()._stock.door[0]
	var centroid:=Vector3.ZERO
	for point: Vector3 in part.shape.points:centroid+=point
	centroid/=part.shape.points.size()
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=part.shape;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,player._shape.global_position-centroid)
	check(get_world_3d().direct_space_state.intersect_shape(query,8).any(func(hit: Dictionary):return hit.collider==player),"mechanical shape queries still see the actual player")
	var original_bodies: Array=[]
	for pair: Dictionary in agent.pairs:original_bodies.append(pair.original)
	player.clear_native_contact_agent()
	check(player._native_contact_agent==null and player.collision_mask==1 and original_bodies.all(func(body: PhysicsBody3D):return not body.has_node("PlayerContactStock") and body not in player.get_collision_exceptions()),"explicit teardown removes only owned proxies and restores all original contact")
	agent=Contacts.new()
	check(agent.configure(player,native.stations) and agent.active,"fresh contact installation succeeds after complete teardown")

func _no_door_exceptions(agent: RefCounted) -> bool:
	for pair: Dictionary in agent.pairs:
		if pair.original in player.get_collision_exceptions():return false
	return true
