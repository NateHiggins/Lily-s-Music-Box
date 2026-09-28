extends "res://tests/orison_v2_lift_joinery_test.gd"
## Semantic envelope, real collision and reachable existing service mechanism.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false); world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var root: Node3D=world.adapter.root
	var model: Node3D=root.get_node("FittedHouseTank")
	var parts := model.find_children("*","MeshInstance3D",true,false)
	check(parts.size()==3,"tank wood, iron and fasteners use three Blender batches")
	for part: MeshInstance3D in parts: check(part.mesh is ArrayMesh,"tank uses imported geometry")
	var owners := 0
	var body: MeshInstance3D
	var bands: Array[MeshInstance3D]=[]
	var supports: Array[MeshInstance3D]=[]
	var lid: MeshInstance3D
	var collector_floor: MeshInstance3D
	var collector_walls: Array[MeshInstance3D]=[]
	for record: Dictionary in root.layout.fixtures:
		var identity := str(record.id)
		if record.get("fabrication","")!="house_tank": continue
		var owner := root.get_node(identity) as MeshInstance3D
		if record.get("fabrication_part","")=="body": body=owner
		if record.get("fabrication_part","")=="binding": bands.append(owner)
		if record.get("fabrication_part","")=="support": supports.append(owner)
		if record.get("fabrication_part","")=="lid": lid=owner
		if record.get("fabrication_part","")=="collector_floor": collector_floor=owner
		if record.get("fabrication_part","")=="collector_wall": collector_walls.append(owner)
		check(not owner.visible,"primitive tank visual is retired "+identity)
		var shape := owner.get_node("Collision").find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D
		check(not shape.disabled and shape.shape is BoxShape3D,"original fixture collision remains enabled "+identity)
		check((shape.shape as BoxShape3D).size.is_equal_approx(Vector3(record.size[0],record.size[1],record.size[2])),"semantic collision envelope retained")
		owners+=1
	check(owners-collector_walls.size()-1==18 and collector_walls.size()==4 and collector_floor!=null,"eighteen tank owners plus five collector owners retained")
	var timber := model.get_node("Timber") as MeshInstance3D
	var size := (body.mesh as BoxMesh).size
	var center := model.to_local(body.global_position)+Vector3.UP*.25
	var contacts := 0
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		# Probe board faces rather than the recessed seam between two staves.
		var at := center+Vector3(direction.z,0,-direction.x)*.06
		var origin: Vector3=at+direction*((size.x if direction.x!=0 else size.z)*.5+.20)
		var ray := PhysicsRayQueryParameters3D.create(model.to_global(origin),model.to_global(at),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==body.get_node("Collision"),"actual tank body collision behind timber")
		var distance := _mesh_distance(timber.mesh.get_faces(),origin,-direction)
		check(is_finite(distance),"tank side has real timber triangles")
		if not hit.is_empty(): check(absf(distance-origin.distance_to(model.to_local(hit.position)))<.012,"fabricated timber follows the existing envelope")
		contacts+=1
	var collector_center := model.to_local(collector_floor.global_position)
	var collector_size := (collector_floor.mesh as BoxMesh).size
	var wall_size := (collector_walls[0].mesh as BoxMesh).size
	var wall_center := model.to_local(collector_walls[0].global_position)
	var inside := collector_center
	inside.y=wall_center.y
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var at := inside+Vector3(direction.z,0,-direction.x)*.031
		var outside: Vector3=at+direction*maxf(collector_size.x,collector_size.z)
		var ray := PhysicsRayQueryParameters3D.create(model.to_global(at),model.to_global(outside),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider.get_parent() in collector_walls,"collector retains its actual inner wall")
		var distance := _mesh_distance(timber.mesh.get_faces(),at,direction)
		check(is_finite(distance),"collector wall has real timber geometry")
		if not hit.is_empty(): check(absf(distance-at.distance_to(model.to_local(hit.position)))<.003,"collector boards fit the inner collision faces")
		contacts+=1
	var floor_top := collector_center.y+collector_size.y*.5
	var over_mouth := collector_center
	over_mouth.y=wall_center.y+wall_size.y*.5+.2
	var above_floor := Vector3(collector_center.x,floor_top+.01,collector_center.z)
	var cavity_ray := PhysicsRayQueryParameters3D.create(model.to_global(over_mouth),model.to_global(above_floor),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(cavity_ray).is_empty(),"collector cavity remains physically open")
	for part: MeshInstance3D in parts:
		var distance := _mesh_distance(part.mesh.get_faces(),over_mouth,Vector3.DOWN)
		check(not is_finite(distance) or distance>=over_mouth.y-floor_top-.001,"no imported lid closes the collector mouth")
	var bottom_ray := PhysicsRayQueryParameters3D.create(model.to_global(above_floor),model.to_global(collector_center),1,[world.player.get_rid()])
	var bottom_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(bottom_ray)
	check(not bottom_hit.is_empty() and bottom_hit.collider==collector_floor.get_node("Collision"),"collector floor remains solid")
	contacts+=1
	var iron := model.get_node("Iron") as MeshInstance3D
	for owner: MeshInstance3D in supports+[lid]:
		var direction := Vector3.DOWN if owner==lid else Vector3.RIGHT
		var at := model.to_local(owner.global_position)
		if owner==lid: at.x+=.4 # between the standing seams
		var origin := at-direction*.3
		var ray := PhysicsRayQueryParameters3D.create(model.to_global(origin),model.to_global(at),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==owner.get_node("Collision"),"original support/lid collider remains seated")
		var distance := _mesh_distance(iron.mesh.get_faces(),origin,direction)
		check(is_finite(distance),"support/lid has an imported surface")
		if not hit.is_empty(): check(absf(distance-origin.distance_to(model.to_local(hit.position)))<.003,"ironwork fits its actual collision envelope")
		contacts+=1
	var cock: RoofTankBallcockProp
	for child in root.find_children("*","Node3D",true,false):
		if child is RoofTankBallcockProp: cock=child; break
	check(cock!=null and cock.has_node("BallcockReach") and cock.overflow_running(),"existing overflowing maintenance mechanism remains composed")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=70
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.light_energy=.7; fill.omni_range=8
	var target := body.global_position
	camera.global_position=target+model.global_basis*Vector3(size.x*.8,-size.y*.15,size.z*1.7)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("fabricated_house_tank")
	var band: MeshInstance3D
	for candidate: MeshInstance3D in bands:
		if candidate.position.z>body.position.z and absf(candidate.position.y-body.position.y)<.001:
			band=candidate; break
	target=band.global_position
	camera.global_position=target+model.global_basis*Vector3(size.x*.1,size.y*.02,size.z*.32)
	camera.look_at(target); fill.global_position=camera.global_position; fill.light_energy=.2
	await shot("binding_clamp_detail")
	target=model.to_global(inside)
	camera.global_position=target+model.global_basis*Vector3(-collector_size.x*.8,wall_size.y,collector_size.z*1.2)
	camera.look_at(target); fill.global_position=camera.global_position; fill.light_energy=.3
	await shot("open_overflow_collector")
	print("HOUSE TANK: original_owners=%d fitted_contacts=%d failures=%d" % [owners,contacts,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
