extends "res://tests/annunciator_world_review.gd"
## INERT diagnostic controls: actual room fixtures; temporary neutral ceiling
## material is a diagnostic only, never production surface acceptance.
var observations: Array[Dictionary]=[]

func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := await _world()
	if world.startup_failed or world.player==null:world.free();_finish_ceiling();return
	world.get_node("V2RoomReflections").set_reflections_enabled(false)
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	var deadline := Time.get_ticks_msec()+5000
	while world.player.flashlight.visible and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
	var camera := Camera3D.new();camera.fov=65.;world.add_child(camera);camera.make_current()
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	for identity in ["F02_B_MAIN","F03_B_MAIN","F04_B_MAIN"]:
		var room: Dictionary={}
		for record: Dictionary in world.layout.spaces:
			if record.id==identity:room=record;break
		check(not room.is_empty(),"authored ceiling room exists: "+identity)
		if room.is_empty():continue
		var r: Array=room.rect
		var floor_y: float=world.adapter.root.level_y[room.level]
		var center := Vector3((float(r[0])+float(r[2]))*.5,floor_y+.02,(float(r[1])+float(r[3]))*.5)
		world.player.global_position=world.adapter.root.to_global(center)
		camera.global_position=world.adapter.root.to_global(center+Vector3(0,1.5,0))
		camera.look_at(world.adapter.root.to_global(center+Vector3(.25,float(world.layout.dimensions.clear_height)-.06,-1.)))
		var circuit := switches.room_snapshot(identity)
		for key: String in circuit:circuit[key]=true
		check(switches.restore_room(identity,circuit),"actual room circuit powers the control: "+identity)
		await get_tree().create_timer(1.2).timeout
		var ceiling := world.adapter.root.get_node_or_null(identity+"/Ceiling") as MeshInstance3D
		check(ceiling!=null,"actual ceiling mesh resolves: "+identity)
		if ceiling==null:continue
		var fixtures: Array[Light3D]=[]
		for fixture in get_tree().get_nodes_in_group("light_fixtures"):
			if str(fixture.name) in circuit:fixtures.append(fixture.light)
		check(not fixtures.is_empty(),"room-circuit lights resolve: "+identity)
		var lights: Array[Dictionary]=[]
		for light: Light3D in world.find_children("*","Light3D",true,false):
			lights.append({"node":light,"shadow":light.shadow_enabled,"reverse":light.shadow_reverse_cull_face,"energy":light.light_energy,"color":light.light_color,"pose":light.global_transform})
		get_tree().paused=true
		var original: Material=ceiling.material_override
		await _ceiling_capture(identity+"_baseline")
		var original_reverse: Array=[]
		for light in fixtures:
			original_reverse.append(light.shadow_reverse_cull_face)
			light.shadow_reverse_cull_face=true
		await _ceiling_capture(identity+"_reverse_room_cull")
		_restore_lights(lights)
		for entry in lights:entry.node.shadow_enabled=false
		await _ceiling_capture(identity+"_no_shadow_control")
		_restore_lights(lights)
		var neutral := StandardMaterial3D.new();neutral.albedo_color=Color(.8,.8,.8);neutral.roughness=1.
		ceiling.material_override=neutral
		await _ceiling_capture(identity+"_neutral_material_control")
		ceiling.material_override=original
		await _ceiling_capture(identity+"_restored")
		check(ceiling.material_override==original,"original ceiling material identity restores: "+identity)
		for entry in lights:
			var light: Light3D=entry.node
			check(light.shadow_enabled==entry.shadow and light.shadow_reverse_cull_face==entry.reverse and light.light_energy==entry.energy and light.light_color==entry.color and light.global_transform==entry.pose,"real light fields restore after controls")
		observations.append({"room":identity,"fixture_count":fixtures.size(),"original_reverse_cull":original_reverse,"scope":"Baseline, reverse room culling, no shadows, neutral material, restored. Visual diagnostics, no acceptance."})
		get_tree().paused=false
	world.player.camera.make_current();world.free();_finish_ceiling()

func _restore_lights(lights: Array[Dictionary]) -> void:
	for entry in lights:
		entry.node.shadow_enabled=entry.shadow;entry.node.shadow_reverse_cull_face=entry.reverse

func _ceiling_capture(label: String) -> void:
	for frame in range(30):await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"diagnostic ceiling captured: "+label)

func _finish_ceiling() -> void:
	get_tree().paused=false
	FileAccess.open(out.path_join("ceiling_shadows.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"observations":observations,"scope":"Three-room shadow/material diagnosis; neutral material is a temporary test fixture, not production art or qualification."},"\t"))
	print("CEILING SHADOW REVIEW: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
