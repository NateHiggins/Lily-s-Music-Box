extends Node
class WakeDriver extends "res://tests/orison_v2_connected_exterior_route_test.gd":
	func _ready() -> void:
		pass # The boundary owns the existing world and its earned player spawn.
## Boundary reconstruction from the preceding physically earned save. This
## drives the public dream transaction; it does not claim a played dream route.
var failures: Array[String] = []
var checks := 0
var output: String
var shell: CampaignShell
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("EARNED BOUNDARY: ",label," = ",ok)
	if not ok: failures.append(label)
	return ok
func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var source := OS.get_environment("V2_EARNED_SAVE")
	if not check(FileAccess.file_exists(source),"physically earned input save exists"):
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	RealityState.save_path = source
	RealityState.load_game()
	RealityState.save_path = output.path_join("boundary_save.json")
	if not check(RealityState.case_state(MinaCaseGameplay.CASE_ID).get("resolved",false),"loaded earned case remains resolved"):
		get_tree().quit(1)
		return
	shell = CampaignShell.new()
	shell.waking_scene_path = "res://scenes/building/orison_v2_runtime.tscn"
	shell.sleep_manual_clock = manual_onset_clock()
	add_child(shell)
	await get_tree().create_timer(.5).timeout
	check(shell.world_kind()=="waking" and shell.world_child_count()==1,"actual V2 reconstructs exclusively")
	if not check(shell.dream_director.phase()=="armed","earned request arms on reconstruction"):
		await finish()
		return
	var retired: WeakRef = weakref(shell.active_world)
	var retired_subjects: Array[WeakRef] = []
	for identity in ["2A_sofa",MinaCaptionManifestation.RESIDUE_ANCHOR_ID,MinaCaptionManifestation.RESIDUE_SOCKET_ID]:
		var subject := shell.active_world.find_child(identity,true,false)
		if subject!=null: retired_subjects.append(weakref(subject))
	for caption in shell.active_world.find_children("MinaCaseCaption","Label3D",true,false):
		retired_subjects.append(weakref(caption))
	check(retired_subjects.size()==7,"all new 2A furniture and caption subjects are tracked")
	var remote_display := shell.active_world.get_node_or_null("MinaRemoteCaptions")
	check(remote_display != null,"V2 remote caption owner exists")
	if remote_display != null: retired_subjects.append(weakref(remote_display))
	for identity in ["4B_wake_bed", "4B_wake_nightstand", "F04_B_ALCOVE_SWITCH", "F04_B_ALCOVE_LT_FLUSH_DOME", "4B_couch", "4B_shelf", "4B_wc", "F04_4B_SINK_01", "F04_4B_SHOWER_01"]:
		var furnishing := shell.active_world.find_child(identity,true,false)
		check(furnishing is Node3D,"wake furnishing mounted: " + identity)
		if furnishing != null: retired_subjects.append(weakref(furnishing))

	if not await enter_earned_dream():
		await finish()
		return
	await get_tree().create_timer(1).timeout
	check(shell.world_kind()=="dream" and shell.active_world is DreamMazeRoot and shell.world_child_count()==1,"real Dream root replaces V2 exclusively")
	check(retired.get_ref()==null,"retired V2 root is released")
	var subjects_released := true
	for reference in retired_subjects:
		subjects_released = subjects_released and reference.get_ref()==null
	check(subjects_released,"new 2A furniture and caption subjects retire with V2")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("earned_dream.png"))
	var dream: WeakRef = weakref(shell.active_world)
	if not check(await complete_dream(),"dream outcome commits return transaction"):
		await finish()
		return
	await get_tree().create_timer(1).timeout
	check(shell.world_kind()=="waking" and shell.active_world is OrisonV2RuntimeRoot and shell.world_child_count()==1,"actual V2 reconstructs after dream")
	check(dream.get_ref()==null,"retired Dream root is released")
	check(shell.core_loop.boundary()=="wake_complete" and shell.dream_director.phase()=="awake","wake transaction completes")
	var world := shell.active_world as OrisonV2RuntimeRoot
	var anchor := shell.core_loop.resolve_return_anchor()
	check(world.player.global_position.distance_to(anchor.position)<.5,"wake lands at V2 authored bedside")
	var facing: Vector3 = anchor.facing_position
	check((-world.player.camera.global_basis.z).dot(
			(facing-world.player.camera.global_position).normalized())>.99,
			"actual wake view faces the authored bed without review staging")
	check(world.work_orders.job_stage(ChirpHunt.JOB_ID)=="closed" and RealityState.case_state(MinaCaseGameplay.CASE_ID).resolved,"wake preserves earned work and resolution")
	check(RealityState.has_waking_residue(MinaCaptionManifestation.RESIDUE_ID),"wake records the factual Mina residue")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("earned_wake.png"))
	await verify_wake_room(world)
	var residue := RealityState.waking_residue(MinaCaptionManifestation.RESIDUE_ID).duplicate(true)
	world.mina_gameplay.bind_wake(shell.core_loop)
	check(RealityState.waking_residue(MinaCaptionManifestation.RESIDUE_ID)==residue,"repeated wake binding is idempotent")
	check(RealityState.save_game(),"completed wake saves through the real owner")
	shell.free()
	shell = null
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	shell = CampaignShell.new()
	shell.waking_scene_path = "res://scenes/building/orison_v2_runtime.tscn"
	shell.sleep_manual_clock = true
	add_child(shell)
	await get_tree().create_timer(.5).timeout
	check(shell.world_kind()=="waking" and shell.core_loop.boundary()=="wake_complete"
			and RealityState.waking_residue(MinaCaptionManifestation.RESIDUE_ID)==residue,
			"disk reload preserves completed wake and the exact factual residue")
	await finish()

func complete_dream() -> bool:
	return shell.dream_director.end_dream("contact")

func manual_onset_clock() -> bool:
	return true

func enter_earned_dream() -> bool:
	return check(shell.dream_director.enter_armed_dream(), "public dream entry accepts earned transaction")

func verify_wake_room(world: OrisonV2RuntimeRoot) -> void:
	var shower := world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	check(shower != null and shower.fixture == "shower" and shower.unit == "4B"
			and shower.get_node_or_null("FixtureBody") is StaticBody3D
			and shower.get_node_or_null("HotValveControl") is Area3D
			and shower.get_node_or_null("ColdValveControl") is Area3D
			and world.boiler_tend != null and world.boiler_tend.taps.count(shower) == 1,
			"4B shower reconstructs with receptor collision, valve targets and boiler supply")
	var entry_opening := world.adapter.resolve("F04_DOOR_03") as Node3D
	var entry := entry_opening.get_node_or_null("F04_DOOR_03_Leaf") as DoorProp if entry_opening != null else null
	check(entry != null and entry.door_kind == "apartment_entry" and entry.unit == "4B"
			and entry.is_in_group("apartment_doors") and not entry.open
			and entry_opening.get_node_or_null("Hinge") == null,
			"4B entry reconstructs as a closed production apartment door")
	for identity in ["F04_B_HALL_DOOR", "F04_B_BATH_DOOR"]:
		var opening := world.adapter.resolve(identity) as Node3D
		var leaf := opening.get_node_or_null(identity + "_Leaf") as DoorProp if opening != null else null
		if check(leaf != null and opening.get_node_or_null("Hinge") == null,
				"4B right-hung production door reconstructs: " + identity):
			var hinge := opening.to_local(leaf.to_global(Vector3.ZERO))
			var latch := opening.to_local(leaf.to_global(Vector3(leaf.width, 0, 0)))
			check(hinge.distance_to(Vector3(leaf.width * .5, 0, 0)) < .001
					and latch.distance_to(Vector3(-leaf.width * .5, 0, 0)) < .001,
					"closed right leaf spans authored hinge and latch")
	check(world.adapter.resolve("4B_equipment_shelf") is StaticBody3D,
			"4B closet equipment shelf reconstructs")
	var closet := world.adapter.resolve("F04_B_CLOSET_DOOR") as Node3D
	check(closet != null and closet.get_node_or_null("F04_B_CLOSET_DOOR_Leaf") is DoorProp
			and closet.get_node_or_null("Hinge") == null,
			"4B closet uses one production leaf instead of its placeholder")
	check(world.adapter.resolve("4B_terminal_desk") is StaticBody3D
			and world.find_child("TerminalHomeContext", true, false) == null,
			"physical terminal desk replaces schematic workspace blocks")
	var below_desk := PhysicsRayQueryParameters3D.create(
			world.adapter.root.to_global(Vector3(-9.6, 10.0, 1.25)),
			world.adapter.root.to_global(Vector3(-8.5, 10.0, 1.25)), 1)
	below_desk.exclude = [world.player.get_rid()]
	check(world.get_world_3d().direct_space_state.intersect_ray(below_desk).is_empty(),
			"desk collision leaves its open centre clear")
	var desk_top := PhysicsRayQueryParameters3D.create(
			world.adapter.root.to_global(Vector3(-9.05, 10.0, 1.25)),
			world.adapter.root.to_global(Vector3(-9.05, 10.34, 1.25)), 1)
	desk_top.exclude = [world.player.get_rid()]
	var top_hit := world.get_world_3d().direct_space_state.intersect_ray(desk_top)
	check(top_hit.get("collider") == world.adapter.resolve("4B_terminal_desk"),
			"desk top remains physically solid above its open centre")
	var kitchen_tap := world.adapter.resolve("F04_4B_KITCHEN_SINK_01") as TapProp
	check(kitchen_tap != null and kitchen_tap.compact_kitchen
			and not kitchen_tap.has_drainboard and kitchen_tap.unit == "4B"
			and world.boiler_tend.taps.has(kitchen_tap),
			"4B compact kitchen sink reconstructs on the boiler supply")
	check(world.adapter.resolve("4B_sink_counter") is StaticBody3D,
			"4B supporting counter reconstructs")
	var range_prop := world.adapter.resolve("F04_B_STOVE_01") as StoveProp
	var icebox := world.adapter.resolve("F04_B_FRIDGE_01") as FridgeProp
	check(range_prop != null and range_prop.unit == "4B"
			and range_prop.get_node_or_null("FixtureBody") is StaticBody3D,
			"4B gas range reconstructs with solid body")
	check(icebox != null and icebox.unit == "4B" and not icebox.monitor_top
			and icebox.get_node_or_null("FixtureBody") is StaticBody3D,
			"4B retains its authored icebox with solid body")
	var radiator := world.adapter.resolve("F02_B_RADIATOR_01") as RadiatorProp
	check(radiator != null and radiator.inventory == world.maintenance_inventory
			and radiator.graph_node_id == "F02_B_RADIATOR_01",
			"2B radiator binds the campaign inventory and stable graph identity")
	var alcove := world.adapter.resolve("F04_B_ALCOVE_LT_FLUSH_DOME") as LightFixtureProp
	for pair in [["F04_B_MAIN_SWITCH", "F04_B_MAIN_LT_PENDANT_SHADE"],
			["F04_B_BATH_SWITCH", "F04_B_BATH_LT_FLUSH_DOME"],
			["F04_B_KITCHEN_SWITCH", "F04_B_KITCHEN_LT_FLUSH_DOME"],
			["F04_B_PRIVATE_HALL_SWITCH", "F04_B_PRIVATE_HALL_LT_FLUSH_DOME"],
			["F04_B_CLOSET_SWITCH", "F04_B_CLOSET_LT_FLUSH_DOME"]]:
		var plate := world.adapter.resolve(pair[0]) as StaticBody3D
		var fixture := world.adapter.resolve(pair[1]) as LightFixtureProp
		if check(plate != null and fixture != null and alcove != null,
				"4B room circuit reconstructs: " + str(pair[0])):
			var previous := fixture.powered
			var bedside := alcove.powered
			plate.call("interact", world.player)
			check(fixture.powered != previous and alcove.powered == bedside,
					"room switch changes its circuit without changing alcove")
			plate.call("interact", world.player)
			check(fixture.powered == previous, "room switch restores its circuit")
	var tap := world.adapter.resolve("F04_4B_SINK_01") as TapProp
	check(tap != null and tap.fixture == "bath_sink" and tap.unit == "4B"
			and tap.get_node_or_null("FixtureBody") is StaticBody3D,
			"4B lavatory reconstructs with its functional owner and solid body")
	check(world.adapter.resolve("4B_wc") is BakedFurnitureInteraction,
			"4B toilet reconstructs with the shared flush owner")
	for identity in ["4B_couch", "4B_shelf"]:
		var furnishing := world.adapter.resolve(identity) as StaticBody3D
		check(furnishing != null and furnishing.get_meta("v2_furniture_id", "") == identity,
				"main-room furniture reconstructs after wake: " + identity)
	var finishes: Dictionary = {}
	var mapped := 0
	var maps_valid := true
	for visual: MeshInstance3D in world.adapter.root.find_children("*","MeshInstance3D",true,false):
		if not visual.has_meta("v2_material_key"): continue
		var key := str(visual.get_meta("v2_material_key"))
		finishes[key] = true
		mapped += 1
		var material := visual.material_override as ShaderMaterial
		if key != "glass":
			maps_valid = maps_valid and material != null
			if material != null:
				maps_valid = maps_valid and material.get_shader_parameter("albedo_tex") is Texture2D \
						and material.get_shader_parameter("normal_tex") is Texture2D \
						and material.get_shader_parameter("rough_tex") is Texture2D
	check(mapped>100 and maps_valid,"V2 architecture consumes actual albedo normal and roughness maps")
	for key in ["floor_oak","plaster_stained","trim","ceramic","subway_tile","stair","glass"]:
		check(finishes.has(key),"architectural material family mounted: "+key)
	check(world.adapter.root.find_child("BedHomeContext",true,false)==null,
			"playable V2 omits the overlapping schematic bed")
	FileAccess.open(output.path_join("architectural_materials.json"),FileAccess.WRITE).store_string(
			JSON.stringify({"mapped_meshes":mapped,"families":finishes.keys(),"maps_valid":maps_valid},"\t"))
	# Probe the previously missing wall at normal player height, including the
	# edge just beyond the approach room. The walking route proves the opening.
	for z in [8.3, 8.9, 10.8]:
		var ray := PhysicsRayQueryParameters3D.create(
				world.adapter.root.to_global(Vector3(-11.4,11.01,z)),
				world.adapter.root.to_global(Vector3(-10.1,11.01,z)))
		ray.exclude = [world.player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var collider := hit.get("collider") as Node
		var room: Node = world.adapter.resolve("F04_B_ALCOVE")
		check(collider != null and room != null and room.is_ancestor_of(collider),
				"alcove owns a solid east boundary at z=" + str(z))
	var bed := world.adapter.resolve("4B_wake_bed") as Node3D
	check(bed != null and absf(world.adapter.root.to_local(bed.global_position).y-9.6)<.01,
			"physical bed stands on the F04 floor")
	var driver := WakeDriver.new()
	add_child(driver)
	driver.world = world
	driver.player = world.player
	driver.route_label = "EARNED WAKE EGRESS"
	# These are actual controller inputs after the real wake transaction, with
	# no replacement spawn or teleport. Cross both authored alcove/hall openings.
	for point in [Vector3(-11.95,9.6,7.25),Vector3(-9.8,9.6,7.25),
			Vector3(-9.8,9.6,5.5),Vector3(-9.8,9.6,7.25),
			Vector3(-11.95,9.6,7.25),Vector3(-11.95,9.6,8.9)]:
		if not await driver._walk(point): break
	check(driver.failures.is_empty() and driver.trace.size()==6,"wake capsule walks out through the hall and back to bedside")
	var fixture := world.adapter.resolve("F04_B_ALCOVE_LT_FLUSH_DOME") as LightFixtureProp
	var plate := world.adapter.resolve("F04_B_ALCOVE_SWITCH") as Node3D
	if check(fixture != null and plate != null,"bedroom fixture and switch reconstruct"):
		var rig := world.find_child("LightRig",true,false)
		print("WAKE_FIXTURE ",JSON.stringify({"powered":fixture.powered,
				"energy":fixture.light.light_energy,"scale":fixture.get("_target_scale"),
				"position":str(fixture.light.global_position),"visible":fixture.light.visible,
				"active_floor":rig.get("active_floor") if rig else "missing"}))
		var original_power := fixture.powered
		if await driver._walk(Vector3(-11.5,9.6,9.1)):
			check(await driver._use(plate,plate.global_position,"bedroom_switch_off"),"physical bedroom switch is reachable")
			check(fixture.powered != original_power,"bedroom switch changes fixture power")
			check(await driver._use(plate,plate.global_position,"bedroom_switch_on"),"physical bedroom switch can be used again")
			check(fixture.powered == original_power,"bedroom switch restores fixture power")
			check(await driver._walk(Vector3(-11.95,9.6,8.9)),"player returns beside bed after switching")
	check(driver.failures.is_empty(),"all wake movement and interactions pass")
	FileAccess.open(output.path_join("wake_route.json"),FileAccess.WRITE).store_string(
			JSON.stringify({"trace":driver.trace,"failures":driver.failures},"\t"))
	driver.free()
	var view_target := bed.global_position + Vector3.UP * .5
	var view_delta := view_target - world.player.global_position
	world.player.rotation.y = atan2(-view_delta.x,-view_delta.z)
	world.player.camera.look_at(view_target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("bedside_review.png"))

func finish() -> void:
	if shell != null: shell.free()
	await get_tree().create_timer(.3).timeout
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"	"))
	print("V2 EARNED DREAM BOUNDARY: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
