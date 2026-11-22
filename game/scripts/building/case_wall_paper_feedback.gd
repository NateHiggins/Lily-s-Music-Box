extends Node3D
## The board keeps its original paper and pointer at rest. This visual follows
## the grip during the peel and briefly follows the sheet after it lets go.

const COLUMNS := 4
const ROWS := 18
const FIRST_RELEASE := 0.27
const LAST_TACK := 0.88

var _grip: Node
var _paper: MeshInstance3D
var _ink: Label3D
var _moving_ink: Array[Label3D] = []
var _skin: MeshInstance3D
var _size: Vector2
var _progress := 0.0
var _furthest_pull := 0.0
var _sound: AudioStreamPlayer3D
var _tears: Array[AudioStreamWAV]


func setup(grip: Node, paper: MeshInstance3D, ink: Label3D, frame: Transform3D,
		size: Vector2, tears: Array[AudioStreamWAV]) -> void:
	_grip = grip
	_paper = paper
	_ink = ink
	_size = size
	_tears = tears
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
	_sound.unit_size = 0.55
	_sound.max_distance = 4.0
	add_child(_sound)
	hide()


func _physics_process(_delta: float) -> void:
	var progress: float = _grip.travel / _grip.reach
	if is_equal_approx(progress, _progress):
		return
	_progress = progress
	if is_zero_approx(progress):
		_furthest_pull = 0.0
		_sound.stop()
		hide()
		_skin.mesh = null
		_paper.show()
		_ink.show()
		return
	if progress > _furthest_pull:
		if _furthest_pull < LAST_TACK and progress >= LAST_TACK:
			_play_tear(2, -19.0)
		elif _furthest_pull < FIRST_RELEASE and progress >= FIRST_RELEASE:
			_play_tear(1, -17.0)
		elif _furthest_pull < 0.09 and progress >= 0.09:
			_play_tear(0, -23.0)
		_furthest_pull = progress
	if not visible:
		_paper.hide()
		_ink.hide()
		show()
	_draw_peel(progress)


func _point(uv: Vector2, progress: float) -> Vector3:
	# The corner loads the sheet before the first tack gives. The peel front
	# then zips up the sheet and holds briefly against the last attached edge.
	var skew := uv.x - 0.5
	var front := 1.08 - 0.15 * smoothstep(0.0, FIRST_RELEASE, progress)
	front -= 0.71 * smoothstep(FIRST_RELEASE - 0.03, 0.73, progress)
	front -= 0.16 * smoothstep(LAST_TACK - 0.03, 1.0, progress)
	front += skew * (0.12 - 0.08 * progress)
	var lift := maxf(uv.y - front, 0.0) * _size.y
	var bend_length := 0.037
	var bend := minf(lift, bend_length)
	var straight := lift - bend
	var angle := 0.65 + 0.49 * smoothstep(0.08, 0.76, progress) + skew * 0.24
	var radius := bend_length / angle
	var turn := bend / radius
	# Integrate the circular bend and its tangent so the loose sheet keeps
	# its length and meets the still-flat paper without a crease or a gap.
	var down := radius * sin(turn) + straight * cos(turn)
	var out := radius * (1.0 - cos(turn)) + straight * sin(turn)
	return Vector3(skew * _size.x, (0.5 - minf(uv.y, front)) * _size.y - down, out)


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
		var right := _point(Vector2(0.55, y), progress) - _point(Vector2(0.45, y), progress)
		var towards := right.cross(up).normalized()
		_moving_ink[line_index].transform = Transform3D(Basis(up.cross(towards), up, towards), centre + towards * 0.006)


func snap_free() -> void:
	set_physics_process(false)
	_paper.hide()
	_ink.hide()
	show()
	_draw_peel(1.0)
	_play_tear(3, -9.0)
	var rest := position
	var facing := rotation
	var outward := basis.z
	var down := -basis.y
	var fall := create_tween()
	fall.tween_property(self, "position", rest + outward * 0.09 + down * 0.025, 0.065).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fall.parallel().tween_property(self, "rotation", facing + Vector3(0.20, 0.07, -0.10), 0.065)
	fall.tween_property(self, "position", rest + outward * 0.18 + down * 0.36, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(self, "rotation", facing + Vector3(-0.72, -0.19, 0.23), 0.30)
	await fall.finished
	hide()
	_skin.mesh = null


func _play_tear(index: int, level_db: float) -> void:
	_sound.stream = _tears[index]
	_sound.volume_db = level_db
	_sound.play()


## The corner rasps, the body zips, the last tack crackles and the sheet snaps.
## Shared by the board's sheets, with no persistent sound or mixer state.
static func make_tears() -> Array[AudioStreamWAV]:
	return [_make_tear(0.045, 27.0, 0.16), _make_tear(0.13, 38.0, 0.42),
			_make_tear(0.058, 54.0, 0.48), _make_tear(0.15, 31.0, 0.96)]


static func _make_tear(length: float, rate: float, bite: float) -> AudioStreamWAV:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 47129
	var samples := PackedByteArray()
	samples.resize(int(RATE * length) * 2)
	var last := 0.0
	var fibre := 0.0
	for i in samples.size() / 2:
		var time := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		fibre = fibre * 0.74 + noise * 0.26
		var envelope := smoothstep(0.0, 0.002, time) * (1.0 - smoothstep(length * 0.26, length, time))
		var cracks := pow(0.5 + 0.5 * sin(TAU * (rate * time + 145.0 * time * time)), 4.0)
		var snap := exp(-absf(time - 0.007) * 156.0)
		var sample := (0.59 * fibre + 0.23 * (noise - last)) * envelope * (0.19 + 0.68 * cracks + bite * snap)
		samples.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 28000.0))
		last = noise
	var rip := AudioStreamWAV.new()
	rip.format = AudioStreamWAV.FORMAT_16_BITS
	rip.mix_rate = RATE
	rip.data = samples
	return rip
