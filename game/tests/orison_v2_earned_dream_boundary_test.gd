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
	shell.sleep_manual_clock = true
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
	for identity in ["4B_wake_bed", "4B_wake_nightstand", "F04_B_ALCOVE_SWITCH", "F04_B_ALCOVE_LT_FLUSH_DOME", "4B_couch", "4B_shelf", "4B_wc", "F04_4B_SINK_01"]:
		var furnishing := shell.active_world.find_child(identity,true,false)
		check(furnishing is Node3D,"wake furnishing mounted: " + identity)
		if furnishing != null: retired_subjects.append(weakref(furnishing))

	check(shell.dream_director.enter_armed_dream(),"public dream entry accepts earned transaction")
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

func verify_wake_room(world: OrisonV2RuntimeRoot) -> void:
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
