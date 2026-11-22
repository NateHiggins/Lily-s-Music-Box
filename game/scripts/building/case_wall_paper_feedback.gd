extends Node3D
## The board keeps its original paper and pointer at rest. This visual follows
## the grip during the peel and briefly follows the sheet after it lets go.

const COLUMNS := 4
const ROWS := 12

var _grip: Node
var _paper: MeshInstance3D
var _ink: Label3D
var _moving_ink: Array[Label3D] = []
var _skin: MeshInstance3D
var _size: Vector2
var _progress := 0.0
var _sound: AudioStreamPlayer3D


func setup(grip: Node, paper: MeshInstance3D, ink: Label3D, frame: Transform3D,
		size: Vector2, rip: AudioStreamWAV) -> void:
	_grip = grip
	_paper = paper
	_ink = ink
	_size = size
	global_transform = frame
	_skin = MeshInstance3D.new()
	_skin.material_override = paper.get_active_material(0)
	_skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_skin)
	for line: String in ink.text.split("\n"):
		var moving_line := ink.duplicate() as Label3D
		moving_line.text = line
		_moving_ink.append(moving_line)
		add_child(moving_line)
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = &"World"
	_sound.stream = rip
	_sound.unit_size = 0.55
	_sound.max_distance = 4.0
	_sound.volume_db = -11.0
	add_child(_sound)
	hide()


func _physics_process(_delta: float) -> void:
	var progress: float = _grip.travel / _grip.reach
	if is_equal_approx(progress, _progress):
		return
	if _progress < 0.55 and progress >= 0.55:
		_sound.volume_db = -22.0
		_sound.pitch_scale = 1.42
		_sound.play()
	_progress = progress
	if is_zero_approx(progress):
		hide()
		_skin.mesh = null
		_paper.show()
		_ink.show()
		return
	if not visible:
		_paper.hide()
		_ink.hide()
		show()
	_draw_peel(progress)


func _point(uv: Vector2, progress: float) -> Vector3:
	# Release starts at the lower right and spreads toward the attached edge.
	var front := 1.02 - 0.99 * smoothstep(0.04, 0.92, progress)
	var loose := smoothstep(front - 0.04, front + 0.24, uv.y + 0.14 * (uv.x - 0.5))
	var lift := clampf(progress / 0.22, 0.0, 1.0) * loose
	return Vector3(
		(uv.x - 0.5) * _size.x,
		(0.5 - uv.y) * _size.y + 0.023 * lift * lift - 0.075 * smoothstep(0.62, 1.0, progress) * loose,
		0.098 * lift + 0.017 * sin(loose * PI) * smoothstep(0.0, 0.2, progress))


func _draw_peel(progress: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for row in range(ROWS + 1):
		for column in range(COLUMNS + 1):
			var uv := Vector2(float(column) / COLUMNS, float(row) / ROWS)
			surface.set_uv(uv)
			surface.add_vertex(_point(uv, progress))
	for row in ROWS:
		for column in COLUMNS:
			var a := row * (COLUMNS + 1) + column
			var b := a + COLUMNS + 1
			for index: int in [a, a + 1, b, a + 1, b + 1, b]:
				surface.add_index(index)
	surface.generate_normals()
	surface.generate_tangents()
	_skin.mesh = surface.commit()
	for line_index in _moving_ink.size():
		var y := 0.5 + (float(line_index) - float(_moving_ink.size() - 1) * 0.5) * 0.19
		var centre := _point(Vector2(0.5, y), progress)
		var up := (_point(Vector2(0.5, y - 0.04), progress) - _point(Vector2(0.5, y + 0.04), progress)).normalized()
		var towards := Vector3.RIGHT.cross(up).normalized()
		_moving_ink[line_index].transform = Transform3D(Basis(up.cross(towards), up, towards), centre + towards * 0.006)


func snap_free() -> void:
	set_physics_process(false)
	_paper.hide()
	_ink.hide()
	show()
	_draw_peel(1.0)
	_sound.volume_db = -11.0
	_sound.pitch_scale = 1.0
	_sound.play()
	var fall := create_tween().set_parallel()
	fall.tween_property(self, "position", position - basis.y * 0.29 + basis.z * 0.15, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(self, "rotation", rotation + Vector3(-0.60, 0.0, -0.19), 0.25)
	await fall.finished
	hide()
	_skin.mesh = null


## A short string of irregular fibre breaks, with a final sharper release.
## Kept local to the board so no persistent sound or mixer state is introduced.
static func make_rip() -> AudioStreamWAV:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 47129
	var samples := PackedByteArray()
	samples.resize(int(RATE * 0.21) * 2)
	var last := 0.0
	var fibre := 0.0
	for i in samples.size() / 2:
		var time := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		fibre = fibre * 0.74 + noise * 0.26
		var envelope := smoothstep(0.0, 0.014, time) * (1.0 - smoothstep(0.09, 0.20, time))
		var cracks := pow(0.5 + 0.5 * sin(TAU * (31.0 * time + 83.0 * time * time)), 4.0)
		var snap := exp(-absf(time - 0.10) * 115.0)
		var sample := (0.55 * fibre + 0.22 * (noise - last)) * envelope * (0.25 + 0.66 * cracks + 0.72 * snap)
		samples.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 28000.0))
		last = noise
	var rip := AudioStreamWAV.new()
	rip.format = AudioStreamWAV.FORMAT_16_BITS
	rip.mix_rate = RATE
	rip.data = samples
	return rip
