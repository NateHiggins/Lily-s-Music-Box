extends RefCounted
## Production fit, interaction and durable settings, batched with surface proof.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var actors := {}
	var units := {}
	var rows: Array = []
	for actor: Node3D in suite.get_tree().get_nodes_in_group("v2_window_treatments"):
		if not world.is_ancestor_of(actor): continue
		var id := str(actor.get_meta("semantic_window"))
		suite.check(not actors.has(id),"unique window treatment: "+id)
		actors[id]=actor
		var unit := str(actor.get_meta("unit"))
		if not unit.is_empty(): units[unit]=true
		suite.check(world.household_state._subjects.get(id)==actor,"existing save owner binds window: "+id)
		suite.check(actor.valid_settings(actor.settings_snapshot()),"initial settings are valid: "+id)
		var space := ""
		for opening: Dictionary in world.layout.windows:
			if str(opening.id)==id:space=str(opening.space);break
		actor.set_meta("review_space",space)
		if "BATH" in space:
			suite.check(actor.style=="cafe" and actor.raised==0 and actor.curtain_open==0,"bathroom privacy: "+id)
		if "KITCHEN" in space:
			suite.check(actor.style=="bare","kitchen fabric clearance: "+id)
		var lower: float = actor._bottom.multimesh.get_instance_transform(0).origin.y-.012
		suite.check(lower>=-actor.height+.15,"blind bottom remains above sill: "+id)
		rows.append({"window":id,"unit":unit,"style":actor.style,"material":actor.fabric,"character_note":actor.character_note,"initial":actor.settings_snapshot()})
	suite.check(actors.size()==world.layout.windows.size()-1 and actors.size()==71,"all 71 habitable windows fitted; boiler hopper retains its owner")
	suite.check(units.size()==18,"all 18 households receive authored treatment")
	var player: Node3D
	for actor: Node3D in actors.values():
		if actor.get_meta("unit")=="4B":player=actor;break
	if player==null:suite.check(false,"player blind exists");return
	var id := str(player.get_meta("semantic_window"))
	var original: Dictionary=player.settings_snapshot()
	player.set_settings(.6,-35,.4,.25)
	var stored: Dictionary=RealityState.data[world.household_state.KEY].records[id].value
	suite.check(is_equal_approx(stored.raise,.6) and is_equal_approx(stored.tilt_degrees,-35) and is_equal_approx(stored.curtain_open,.4),"save commits target at start of motion")
	RealityState.commit()
	await suite.get_tree().create_timer(.3).timeout
	suite.check(is_equal_approx(player.raised,.6) and is_equal_approx(player.tilt_degrees,-35),"unrelated state commit does not interrupt blind motion")
	player.raised=.1;player.tilt_degrees=0;player.curtain_open=1;player._apply()
	world.household_state._restore(RealityState.data[world.household_state.KEY])
	suite.check(player.settings_snapshot()==stored,"household reconstruction restores lift, tilt and curtain draw")
	await suite.get_tree().physics_frame
	for control in ["LiftControl","TiltControl","CurtainControl"]:
		var area: Area3D=player.get_node(control)
		var query := PhysicsRayQueryParameters3D.create(player.to_global(player.to_local(area.global_position)+Vector3(0,0,.45)),area.global_position,1)
		query.collide_with_areas=true
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		suite.check(not hit.is_empty() and hit.collider==area,"room-side ray reaches "+control)
	player.set_settings(original.raise,original.tilt_degrees,original.curtain_open,0)
	var directory := OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("window-settings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","windows":rows},"\t"))
	var camera := Camera3D.new();camera.fov=72;world.add_child(camera);camera.make_current()
	world.player.carried_device.set_capture_hidden(true)
	for unit in ["1D","2B","3A","4C","4B"]:
		var chosen: Node3D
		for actor: Node3D in actors.values():
			if actor.get_meta("unit")==unit and actor.style!="bare" and not str(actor.get_meta("review_space")).contains("BATH"):chosen=actor;break
		if chosen==null:continue
		camera.global_position=chosen.to_global(Vector3(.15,-chosen.height*.52,2.1))
		camera.look_at(chosen.to_global(Vector3(0,-chosen.height*.48,0)),Vector3.UP)
		var fill := OmniLight3D.new();fill.light_energy=.4;fill.omni_range=5;world.add_child(fill);fill.global_position=camera.global_position
		await suite.shot("window_"+unit)
		fill.free()
	camera.free();world.player.camera.make_current()
