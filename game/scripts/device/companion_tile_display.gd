extends Node3D
## Physical, bistable two-color squares. Two native mesh batches; no viewport,
## glow, texture animation, resting solver or per-pixel Node3D hierarchy.
const WIDTH := 32
const HEIGHT := 12
const DATA := "res://data/device/service_companion_v2.json"
var failures: Array[String] = []
var dark: MultiMeshInstance3D
var light: MultiMeshInstance3D
var target := PackedByteArray()
var angles := PackedFloat32Array()
var _homes: Array[Vector3] = []
var _waiting: Array[int] = []
var _active: Array[int] = []
var _enqueued: Dictionary = {}
var _credit := 0.0
var _last_expression := ""
var _last_mouth := -1
var transform_writes := 0
var illustration_active := false
var _click: AudioStreamPlayer3D

func build(model: Node3D) -> bool:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var data: Dictionary = document.flip_display
	if int(data.columns) != WIDTH or int(data.rows) != HEIGHT:
		failures.append("Flip display resolution differs from native source")
		return false
	var center: Array = data.center
	var pitch := float(data.pitch)
	if pitch <= 0.0: return false
	var source_dark := model.find_child(str(data.dark_mesh), true, false) as MeshInstance3D
	var source_light := model.find_child(str(data.light_mesh), true, false) as MeshInstance3D
	if source_dark == null or source_light == null: return false
	dark = _batch(source_dark)
	light = _batch(source_light)
	source_dark.hide()
	source_light.hide()
	target.resize(WIDTH * HEIGHT)
	angles.resize(WIDTH * HEIGHT)
	angles.fill(PI)
	for row in HEIGHT:
		for column in WIDTH:
			var point := Vector3(float(center[0]) + (column - (WIDTH - 1) * .5) * pitch,
				float(center[1]) + ((HEIGHT - 1) * .5 - row) * pitch, float(center[2]))
			_homes.append(to_local(model.to_global(point)))
			_pose(row * WIDTH + column)
	_click = AudioStreamPlayer3D.new()
	_click.stream = PropAudio.get_stream("tick")
	_click.volume_db = -37.0
	_click.max_distance = 2.0
	add_child(_click)
	set_process(false)
	return true

func _batch(source: MeshInstance3D) -> MultiMeshInstance3D:
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = MultiMesh.new()
	draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	draw.multimesh.mesh = source.mesh
	draw.multimesh.instance_count = WIDTH * HEIGHT
	draw.material_override = source.get_active_material(0)
	draw.layers = source.layers
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	return draw

func set_pixels(pixels: PackedByteArray, instant := false) -> bool:
	if pixels.size() != WIDTH * HEIGHT: return false
	for value in pixels:
		if value > 1: return false
	_last_expression = ""
	illustration_active = true
	for index in pixels.size():
		if pixels[index] == target[index] and not instant: continue
		target[index] = pixels[index]
		if instant:
			angles[index] = 0.0 if pixels[index] != 0 else PI
			_pose(index)
		elif not _enqueued.has(index):
			_waiting.append(index)
			_enqueued[index] = true
	if instant:
		_waiting.clear()
		_active.clear()
		_enqueued.clear()
	set_process(not _waiting.is_empty() or not _active.is_empty())
	return true

func set_expression(expression: String, openness := 0.0, instant := false) -> void:
	var mouth := clampi(int(round(openness * 4.0)), 0, 4)
	if expression == _last_expression and mouth == _last_mouth and not instant: return
	var pixels := expression_pixels(expression, mouth / 4.0)
	set_pixels(pixels, instant)
	illustration_active = false
	_last_expression = expression
	_last_mouth = mouth

static func expression_pixels(expression: String, openness := 0.0) -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(WIDTH * HEIGHT)
	for row in HEIGHT:
		for column in WIDTH:
			var eye := column in [10, 11, 20, 21] and row in [3, 4]
			var mouth := false
			if expression == "sleeping":
				eye = row == 4 and (column in [9, 10, 11, 20, 21, 22])
				mouth = row == 9 and column in [14, 15, 16, 17]
			elif expression == "speaking" and openness > .2:
				var ellipse := pow((column - 15.5) / 5.5, 2.0) + pow((row - 8.5) / (1.0 + openness), 2.0)
				mouth = ellipse >= .45 and ellipse <= 1.3
			elif expression == "worried":
				mouth = (row == 8 and column >= 12 and column <= 19) or (row == 9 and column in [10, 11, 20, 21]) or (row == 10 and column in [9, 22])
			elif expression in ["listening", "speaking"]:
				mouth = row == 8 and column >= 12 and column <= 19
			else:
				mouth = (row == 8 and column in [9, 22]) or (row == 9 and column in [10, 11, 20, 21]) or (row == 10 and column >= 12 and column <= 19)
			pixels[row * WIDTH + column] = 1 if eye or mouth else 0
	return pixels

func show_illustration(rows: Array[String], instant := false) -> bool:
	if rows.size() != HEIGHT: return false
	var pixels := PackedByteArray()
	for row: String in rows:
		if row.length() != WIDTH: return false
		for column in WIDTH:
			if row[column] not in [".", "#"]: return false
			pixels.append(1 if row[column] == "#" else 0)
	return set_pixels(pixels, instant)

func _process(delta: float) -> void:
	_credit = minf(24.0, _credit + maxf(0.0, delta) * 240.0)
	var start_count := mini(maxi(0, 32 - _active.size()), mini(16, mini(int(_credit), _waiting.size())))
	if start_count > 0 and _click != null and not _click.playing: _click.play()
	for count in start_count:
		_active.append(_waiting.pop_front())
		_credit -= 1.0
	for offset in range(_active.size() - 1, -1, -1):
		var index := _active[offset]
		var wanted := 0.0 if target[index] != 0 else PI
		angles[index] = move_toward(angles[index], wanted, delta * PI / .09)
		_pose(index)
		if is_equal_approx(angles[index], wanted):
			_active.remove_at(offset)
			_enqueued.erase(index)
	set_process(not _waiting.is_empty() or not _active.is_empty())

func settled() -> bool:
	return _waiting.is_empty() and _active.is_empty()

func _pose(index: int) -> void:
	var pose := Transform3D(Basis(Vector3.UP, angles[index]), _homes[index])
	dark.multimesh.set_instance_transform(index, pose)
	light.multimesh.set_instance_transform(index, pose)
	transform_writes += 2
