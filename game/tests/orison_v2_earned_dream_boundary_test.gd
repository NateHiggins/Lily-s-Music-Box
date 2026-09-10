extends Node
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
	check(shell.dream_director.enter_armed_dream(),"public dream entry accepts earned transaction")
	await get_tree().create_timer(1).timeout
	check(shell.world_kind()=="dream" and shell.active_world is DreamMazeRoot and shell.world_child_count()==1,"real Dream root replaces V2 exclusively")
	check(retired.get_ref()==null,"retired V2 root is released")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("earned_dream.png"))
	var dream: WeakRef = weakref(shell.active_world)
	check(shell.dream_director.end_dream("contact"),"public outcome commits return transaction")
	await get_tree().create_timer(1).timeout
	check(shell.world_kind()=="waking" and shell.active_world is OrisonV2RuntimeRoot and shell.world_child_count()==1,"actual V2 reconstructs after dream")
	check(dream.get_ref()==null,"retired Dream root is released")
	check(shell.core_loop.boundary()=="wake_complete" and shell.dream_director.phase()=="awake","wake transaction completes")
	var world := shell.active_world as OrisonV2RuntimeRoot
	var anchor := shell.core_loop.resolve_return_anchor()
	check(world.player.global_position.distance_to(anchor.position)<.5,"wake lands at V2 authored bedside")
	check(world.work_orders.job_stage(ChirpHunt.JOB_ID)=="closed" and RealityState.case_state(MinaCaseGameplay.CASE_ID).resolved,"wake preserves earned work and resolution")
	check(RealityState.has_waking_residue(MinaCaptionManifestation.RESIDUE_ID),"wake records the factual Mina residue")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("earned_wake.png"))
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
func finish() -> void:
	if shell != null: shell.free()
	await get_tree().create_timer(.3).timeout
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"	"))
	print("V2 EARNED DREAM BOUNDARY: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
