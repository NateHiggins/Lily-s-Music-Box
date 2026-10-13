extends "res://tests/orison_v2_roof_route_test.gd"
## Production roof approach and native collision, no substitute plant owner.
func _init() -> void:
	route_label="TOWER REDESIGN"

func _route() -> void:
	player.set_lamp_enabled(false)
	for point in [Vector3(1.925,17.6,1.3),Vector3(3.975,17.6,1.3),
			Vector3(3.975,19.2,-3.4),Vector3(5,19.2,-3.4),Vector3(5,19.2,2.5),
			Vector3(-1.35,19.2,2.5),Vector3(-1.35,19.2,0)]:
		if not await _walk(point):return
	if not await _open_door("ROOF_PUBLIC_DOOR"):return
	for point in [Vector3(-3.6,19.2,0),Vector3(-9.4,19.2,0),Vector3(-9.4,19.2,-3.05)]:
		if not await _walk(point):return
	var root: Node3D=world.adapter.root
	var model:=root.get_node("FittedHouseTank") as Node3D
	var inventory:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface: Dictionary in inventory._mesh(draw.mesh).surfaces:
			_require(not surface.missing_uv and int(surface.nonfinite_uv)==0 and int(surface.degenerate_uv_triangles)==0,"loaded tower UVs remain finite and noncollapsed: "+str(draw.name))
	inventory.free()
	var tank:=root.get_node("ROOF_TANK_BODY") as Node3D
	var physics:=world.get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(model.to_global(Vector3(-2,3.55,0)),model.to_global(Vector3(2,3.55,0)),1)
	var hit:=physics.intersect_ray(ray)
	_require(hit.get("collider")==tank.get_node("Collision"),"native round tank keeps the original collision owner")
	if not hit.is_empty():_require(absf(model.to_local(hit.position).x+1.10)<.02,"collision follows the 1.10 metre tank radius")
	for radius in [.60,1.12]:
		ray.from=model.to_global(Vector3(radius,3.85,0));ray.to=model.to_global(Vector3(radius,4.60,0))
		var underside:=physics.intersect_ray(ray)
		_require(underside.get("collider")==tank.get_node("Collision"),"lid underside has actual solid faces at radius "+str(radius))
		if not underside.is_empty():_require(underside.normal.dot(model.global_basis.y)<-.3,"lid underside normals face down at radius "+str(radius))
	ray.from=model.to_global(Vector3(1.30,3.80,.90));ray.to=model.to_global(Vector3(1.30,3.60,.90))
	_require(physics.intersect_ray(ray).is_empty(),"retired rectangular tank corners are actually empty")
	for i in 4:
		var leg:=root.get_node("ROOF_TANK_LEG_"+str(i)) as Node3D
		ray.from=leg.to_global(Vector3(-.4,0,0));ray.to=leg.to_global(Vector3(.4,0,0))
		_require(physics.intersect_ray(ray).get("collider")==leg.get_node("Collision"),"original roof bearing remains solid "+str(i))
	var cock:=world.adapter.resolve("ROOF_TANK_BALLCOCK") as RoofTankBallcockProp
	_require(cock!=null and cock.overflow_running(),"original overflowing ballcock is still composed")
	if cock!=null:
		var reach:=cock.get_node("BallcockReach") as Area3D
		var target:=reach.to_global(Vector3(.02,-.02,.14))
		ray.from=player.camera.global_position;ray.to=target;ray.exclude=[player.get_rid()]
		_require(physics.intersect_ray(ray).is_empty(),"new trestle leaves the original service approach unobstructed")
	world.campaign_clock.configure_date(1928,10,15,750)
	var atmosphere: Node=world.get_node("WakingAtmosphere")
	atmosphere.weather_manager.set_process(false)
	atmosphere.weather_manager._publish()
	atmosphere.director._apply(750)
	await get_tree().create_timer(.5).timeout
	await _roof_capture("tower_service",root.to_local(model.to_global(Vector3(0,2.7,0))))
	for point in [Vector3(-9.4,19.2,0),Vector3(-12,19.2,0)]:
		if not await _walk(point):return
	await _roof_capture("tower_roof",Vector3(-8.6,21.75,-5.7))
