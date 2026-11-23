extends Node3D

const Cel := preload("res://scripts/visuals/cel_style_presentation.gd")


func _ready() -> void:
	_run.call_deferred()


func _box(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	mesh.material = material
	var draw := MeshInstance3D.new()
	draw.mesh = mesh
	draw.position = at
	add_child(draw)
	return draw


func _frame() -> Image:
	for i in range(8):
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _difference(plain: Image, styled: Image, pixel: Vector2) -> float:
	var pos := Vector2i(pixel)
	var baseline := plain.get_pixelv(pos)
	var change := styled.get_pixelv(pos)
	return absf(baseline.r - change.r) + absf(baseline.g - change.g) + absf(baseline.b - change.b)


func _run() -> void:
	var camera := Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("332d45")
	camera.environment = env
	var native := _box(Vector3(-0.65, 0.0, -3.0), Vector3(1.15, 1.3, 0.30), Color("764e9d"))
	Cel.preserve(native)
	var ordinary := _box(Vector3(0.82, 0.0, -3.0), Vector3(1.15, 1.3, 0.30), Color("764e9d"))
	var blocker := _box(Vector3(-0.3, 0.0, -2.35), Vector3(0.44, 1.1, 0.15), Color("746882"))
	var filter := Cel.new()
	add_child(filter)
	GameBoot.settings["cel_shading"] = false
	var baseline := await _frame()
	GameBoot.settings["cel_shading"] = true
	var styled := await _frame()
	var directory := OS.get_environment("SHOT_DIR")
	baseline.save_png(directory.path_join("filter_off.png"))
	styled.save_png(directory.path_join("filter_on.png"))
	var native_pixel := camera.unproject_position(native.position + Vector3.LEFT * 0.35)
	var native_delta := _difference(baseline, styled, native_pixel)
	var room_delta := _difference(baseline, styled, camera.unproject_position(ordinary.position))
	var occluder_delta := _difference(baseline, styled, camera.unproject_position(blocker.position))
	GameBoot.settings["cel_shading"] = false
	var restored := await _frame()
	var roundtrip := _difference(baseline, restored, camera.unproject_position(ordinary.position))
	var pass_count: int = filter._effect.passes if filter._effect != null else 0
	print("CEL BENCH: passes=%d native=%f room=%f foreground=%f roundtrip=%f" % [
		pass_count, native_delta, room_delta, occluder_delta, roundtrip])
	var ok := pass_count > 0 and native_delta < 0.025 and room_delta > 0.025 and occluder_delta > 0.02 and roundtrip < 0.007
	print("CEL BENCH: " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
