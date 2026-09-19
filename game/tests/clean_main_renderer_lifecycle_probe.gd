extends Node3D

func _ready() -> void:
	var root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for _i in 180: await get_tree().process_frame
	var light := SpotLight3D.new(); light.shadow_enabled=true; light.spot_range=9.0; light.light_energy=4.0; add_child(light)
	for _i in 30: await get_tree().process_frame
	light.visible=false; light.light_energy=0.0; light.queue_free()
	for _i in 8: await get_tree().process_frame
	root.queue_free()
	for _i in 20: await get_tree().process_frame
	print("[CLEAN MAIN LIFECYCLE] render_objects=%d resources=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	get_tree().quit(0)
