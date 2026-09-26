extends Node3D
## Focused A/A render proof. Production cabinet construction and budgets remain
## covered by WalkTest; this fixture isolates the expensive second-view path.

var cabinet: MedicineCabinetProp
var renderer: Node
var camera: Camera3D
var output_dir := ""


func _ready() -> void:
	output_dir = OS.get_environment("SHOT_DIR")
	if output_dir == "":
		output_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_proof_room()
	await get_tree().process_frame
	renderer.set_process(false)
	renderer.call("_sleep")
	await _settle(3)
	var control := await _capture("mirror__aged_control.png")
	renderer.set_process(true)
	await _settle(8)
	var live := await _capture("mirror__live.png")
	var delta := _mean_delta(control, live)
	var active_ok: bool = renderer.call("active_mirror") == cabinet
	var one_view: bool = renderer.get_child_count() == 1 \
			and renderer.get_child(0) is SubViewport
	var passed := active_ok and one_view and delta > 0.015
	for offset in [-.22, .22]:
		camera.position.x = offset
		camera.look_at(cabinet.mirror_center())
		await _settle(8)
		var shifted := await _capture("mirror_side_%s.png" % str(offset))
		passed = passed and _check_reflected_markers(shifted)
	print("[MIRROR SHOT] %s active=%s one_view=%s mean_delta=%.5f" % [
			"PASS" if passed else "FAIL", str(active_ok), str(one_view), delta])
	get_tree().quit(0 if passed else 2)


func _build_proof_room() -> void:
	cabinet = MedicineCabinetProp.new()
	cabinet.unit = "4B"
	add_child(cabinet)
	_add_box(Vector3(3.2, 2.5, 0.08), Vector3(0, 1.25, -2.35),
			Color(0.30, 0.22, 0.10))
	_add_box(Vector3(0.42, 0.82, 0.32), Vector3(-0.62, 1.38, -1.92),
			Color(0.72, 0.08, 0.055))
	_add_box(Vector3(0.34, 0.56, 0.28), Vector3(0.05, 1.31, -2.02),
			Color(0.04, 0.27, 0.75))
	_add_box(Vector3(0.50, 0.36, 0.30), Vector3(0.62, 1.18, -1.88),
			Color(0.08, 0.62, 0.22))
	camera = Camera3D.new()
	camera.name = "ProofCamera"
	camera.position = Vector3(0.04, 1.505, -0.92)
	camera.fov = 58.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.505, 0))
	camera.make_current()
	var light := OmniLight3D.new()
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.position = Vector3(0, 1.8, -1.0)
	add_child(light)
	renderer = load("res://scripts/building/planar_mirror_renderer.gd").new()
	add_child(renderer)
	renderer.call("setup", camera)


func _add_box(size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	node.material_override = material
	node.position = at
	add_child(node)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _capture(file_name: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	var path := output_dir.path_join(file_name)
	image.save_png(path)
	print("[CAPTURE] ", path)
	return image


func _mean_delta(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var sum := 0.0
	var count := a.get_width() * a.get_height()
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sum += (absf(ca.r - cb.r) + absf(ca.g - cb.g)
					+ absf(ca.b - cb.b)) / 3.0
	return sum / maxf(1.0, float(count))


func _check_reflected_markers(frame: Image) -> bool:
	# Analytical reflection locations must contain the matching coloured prop,
	# not merely differ from the fallback. This catches stretching and reversal.
	var all_ok := true
	var tested := 0
	for record in [[Vector3(-.62,1.38,-1.92),0], [Vector3(.05,1.31,-2.02),2], [Vector3(.62,1.18,-1.88),1]]:
		var center := cabinet.mirror_center()
		var normal := cabinet.mirror_normal()
		var virtual_point: Vector3 = record[0] - normal * (2.0 * (record[0]-center).dot(normal))
		var ray := virtual_point-camera.global_position
		var t := (center-camera.global_position).dot(normal)/ray.dot(normal)
		var glass_point := camera.global_position+ray*t
		var local := cabinet.mirror_surface().to_local(glass_point)
		if absf(local.x) > .19 or absf(local.y) > .265: continue
		tested += 1
		var pixel := camera.unproject_position(glass_point)
		var colour := frame.get_pixelv(Vector2i(pixel))
		var channels := [colour.r,colour.g,colour.b]
		var channel: int = record[1]
		var ok: bool = channels[channel] > channels[(channel+1)%3]*1.35 and channels[channel] > channels[(channel+2)%3]*1.35
		all_ok = all_ok and ok
		print("[MIRROR MARKER] %s channel=%s colour=%s pixel=%s" % ["PASS" if ok else "FAIL",channel,colour,pixel])
	return all_ok and tested > 0
