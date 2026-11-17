extends "res://tests/door_passage_policy_test.gd"
## Existing real key/settlement/restore policy programme, using both native leaves.
func make_door() -> DoorProp:
	var door := preload("res://scripts/building/orison_v2_arcade_shop_door.gd").new()
	door.unit = DoorKeyring.player_unit()
	return door

func additional_checks(door: DoorProp, carrier: Carrier) -> void:
	var leaves := door.motion_leaves()
	_check(leaves.size()==2 and door.width==2.0 and door.passage_swing_radius()==1.0,"two full-size leaves share one2m aperture")
	_check(door.mechanism_snapshot().keys()==["angle"],"one existing durable mechanism angle")
	_check(door.manipulation_target({"collider":leaves[1].body}).get("legacy",false),"secondary leaf click reaches same door owner")
	door.restore_mechanism({"angle":.45})
	_check(is_equal_approx(leaves[0].body.rotation.y,.45) and is_equal_approx(leaves[1].body.rotation.y,-.45),"partial restore drives mirrored physical bodies")
	await get_tree().physics_frame; await get_tree().physics_frame
	for leaf: Dictionary in leaves:
		var server: Transform3D = PhysicsServer3D.body_get_state(leaf.body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
		_check(server.is_equal_approx(leaf.body.global_transform),"restored leaf published to physics " + str(leaf.ratio))
	door.restore_mechanism({"angle":door.motion_target_angle(true)})
	leaves[1].body.rotation.y = -.4
	_check(not door.is_ready_for_passage(),"secondary drift refuses passage readiness")
	door.restore_mechanism({"angle":0.0})
	carrier.global_position = door.to_global(Vector3(1.55,0,-.5))
	_check(not door.opening_clear() and not door.standing_position_clear(carrier.global_position,.33,1.524),"secondary-only occupant blocks actual mirrored sweep")
	var route := preload("res://scripts/characters/orison_v2_resident_route.gd").new()
	_check(not route._door_motion_clear(door,true),"NPC owner shares secondary sweep refusal")
	route.free()
	carrier.global_position = door.to_global(Vector3(1,0,3))
	var stock := StaticBody3D.new();var collision := CollisionShape3D.new();var shape := BoxShape3D.new()
	shape.size = Vector3(.3,.4,.3);collision.shape=shape;stock.add_child(collision);add_child(stock)
	carrier.held=stock;stock.global_position=door.to_global(Vector3(1.55,1,-.5))
	_check(not door.opening_clear(),"held stock in secondary-only sweep refuses opening")
	carrier.held=null;stock.free()
	# Use the actual hose crossing owner with a bounded two-point strand.
	var hose := preload("res://scripts/props/fire_unracked_hose.gd").new()
	hose.model=Node3D.new();hose.add_child(hose.model);add_child(hose)
	hose.deployed=true;hose.add_to_group("deployed_fire_hoses")
	for x: float in [.5,1.5]:
		hose.rig.strand.points=PackedVector3Array([door.to_global(Vector3(x,.04,-.3)),door.to_global(Vector3(x,.04,.3))])
		_check(door.hose_blocks_close(),"real hose crossing protected on half " + str(x))
	hose.rig.strand.points=PackedVector3Array([door.to_global(Vector3(3,.04,-.3)),door.to_global(Vector3(3,.04,.3))])
	_check(not door.hose_blocks_close(),"off-aperture hose negative control")
	hose.free()
	var opened := make_door();opened.name="ArcadePairInitiallyOpen";opened.position.x=5;opened.leaf_state="open";add_child(opened)
	print("PAIR STARTUP BEFORE PHYSICS: ",opened.leaf_state," ",opened.open," ",opened._body.rotation.y," ",opened.motion_leaves()[1].body.rotation.y)
	await get_tree().physics_frame; await get_tree().physics_frame
	print("PAIR STARTUP AFTER PHYSICS: ",opened.leaf_state," ",opened.open," ",opened._body.rotation.y," ",opened.motion_leaves()[1].body.rotation.y)
	_check(opened.is_ready_for_passage(),"open startup synchronizes both physical leaves")
	opened.free()
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for draw: MeshInstance3D in door.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		var mat := draw.get_active_material(0) as ShaderMaterial
		_check(mat!=null,"native primary-UV material owner " + str(draw.name))
		if mat!=null:
			var optical := mat.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader"
			for key: String in (["rough_tex","normal_tex"] if optical else ["albedo_tex","rough_tex","normal_tex"]):
				var texture := mat.get_shader_parameter(key) as Texture2D
				_check(texture!=null and texture.get_image().has_mipmaps(),"native loaded custom map mips " + str(draw.name)+"/"+key)
	_check(metrics.failures.is_empty(),"native strict UV/normal/tangent derivatives " + str(metrics.failures))
	metrics.free()

func _inputs() -> Dictionary:
	var result: Dictionary = super._inputs()
	for path: String in ["res://tests/arcade_paired_door_policy_test.gd","res://tests/ArcadePairedDoorPolicyTest.tscn","res://scripts/building/orison_v2_arcade_shop_door.gd","res://scripts/characters/orison_v2_resident_route.gd","res://scripts/props/fire_unracked_hose.gd","res://data/orison_v2/arcade_door_leaves.json"]:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	result["res://assets/props/arcade_door_leaves.glb"]=FileAccess.get_sha256("res://assets/props/arcade_door_leaves.glb")
	return result
