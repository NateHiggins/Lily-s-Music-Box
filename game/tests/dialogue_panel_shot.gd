extends Node
## Visual proof for the conversation lower-third: scrim weight, serif
## hierarchy, numbered plain replies, evidence and inference tints, silence
## set apart, and the centre of the view left clear.
##
## Deliberately not the whole building: a flat room-coloured backdrop with a
## crosshair mark at the exact centre, so the capture shows only what the
## panel adds and whether it crosses the aim.

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.26, 0.22, 0.17), Color(0.17, 0.15, 0.12),
			Color(0.09, 0.08, 0.07)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.6, 1.0)
	backdrop.texture = texture
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var crosshair := ColorRect.new()
	crosshair.color = Color(0.9, 0.86, 0.72, 0.9)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	add_child(crosshair)
	var panel := CaseDialoguePanel.new()
	add_child(panel)
	await get_tree().process_frame
	panel.present("PETER WREN",
			"Each station is a decision I have not made, kept where I would have made it. Kitchen: whether to write to my sister. Door: whether to renew. Desk: the other matter. None of them is thrown away because throwing away is also a decision, and I would need a form for that.",
			[
				{"text": "'The other matter.'", "action": Callable()},
				{"text": "You keep them where you'd act. So you'd see them.", "action": Callable(), "infer": true},
				{"text": "You've got one for every uncertainty. [the staging table]", "action": Callable(), "evidence": true},
				{"text": "Say nothing.", "action": Callable(), "silent": true},
			])
	for _frame in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	var centre := viewport.get_visible_rect().size * 0.5
	var column_top := panel._column.get_global_rect().position.y
	var scrim_top := panel._scrim.get_global_rect().position.y
	print("[DIALOGUE SHOT] viewport=%s column_top=%.0f scrim_top=%.0f centre_y=%.0f clear=%s" % [
			viewport.get_visible_rect().size, column_top, scrim_top, centre.y,
			column_top > centre.y and scrim_top > centre.y])
	var out_dir := OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("dialogue_panel.png")
	var error := viewport.get_texture().get_image().save_png(path)
	print("[DIALOGUE SHOT] %s %s" % ["saved" if error == OK else "FAIL", path])
	get_tree().quit(0 if error == OK and column_top > centre.y else 1)
