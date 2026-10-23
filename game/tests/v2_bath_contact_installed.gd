extends "res://tests/v2_bath_contact_lod_study.gd"
## Same route with ordinary production collision owners; no shape replacements.
func _ready() -> void:
	installed_only=true
	super._ready()

func installed_interactions() -> Dictionary:
	var tap:=world.find_child("F03_3B_SINK_01",true,false) as TapProp
	var saved:=tap.mechanism_snapshot()
	var driver:=preload("res://tests/orison_v2_4b_door_route_test.gd").new()
	driver.externally_managed=true;driver.world=world;driver.player=player;add_child(driver)
	var stance:=Vector3.INF
	for distance: float in [.8,1.,1.2]:
		for offset: float in [0.,-.2,.2]:
			var feet: Vector3=tap.to_global(Vector3(offset,0,-distance));feet.y=6.400265
			var capsule:=CapsuleShape3D.new();capsule.height=PlayerController.STANDING_HEIGHT;capsule.radius=PlayerController.BODY_RADIUS
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=player.collision_mask;query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
			if world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():stance=feet;break
		if stance.is_finite():break
	if not stance.is_finite():failures.append("no full-capsule sink service stance");driver.free();return {}
	player.global_position=stance
	await get_tree().physics_frame
	for operation: Array in [[0,PI*.5],[1,PI*.5],[0,0.],[1,0.]]:
		var control:=tap.get_node("HotValveControl" if operation[0]==0 else "ColdValveControl") as Area3D
		if not await driver._drag_part(tap,control.global_position,operation[1],"installed_sink_"+str(operation)):
			player.cancel_manipulation();break
	for failure: String in driver.failures:failures.append(failure)
	var checks: Array=driver.interaction_checks.duplicate(true)
	# Reaching the plug must still use the unobstructed real production ray.
	player.face_world_point(tap._bath_plug.global_position)
	await get_tree().physics_frame
	var target: Dictionary=player._grab.find_target()
	var plug_access: bool=target.get("part")==tap._bath_plug
	checks.append({"label":"open basin permits exact plug target","ok":plug_access})
	if not plug_access:failures.append("installed basin blocks plug target")
	if player._grab.active():player.cancel_manipulation()
	tap.restore_mechanism(saved);driver.free()
	return {"stance":str(stance),"checks":checks,"limits":"Direct placement at full-capsule service stance, actual valve click/motion/release and authoritative plug target. Not a walked approach or full save reconstruction."}
