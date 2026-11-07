extends Node
## Prints the composed frames the distant districts mount into. Diagnostic only.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	for path: String in ["CityShells", "CityShells/QueensboroBridge", "CityShells/FarShoreSkyline"]:
		var node := world.get_node_or_null(path) as Node3D
		print("FRAME ", path, " ", node.global_transform if node else "missing")
	var ground := world.find_child("Ground", true, false) as Node3D
	print("FRAME Ground ", ground.global_transform if ground else "missing")
	print("FRAME adapter.root ", (world.adapter.root as Node3D).global_transform)
	print("FRAME world ", world.global_transform)
	world.shutdown_for_tests()
	world.free()
	get_tree().quit(0)
