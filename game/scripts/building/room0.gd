class_name Room0
extends Node3D
## The hidden room. A pocket space that exists only while the building's
## infection sustains it — entered through the manifested door anomaly in
## 4B. Inside, the motif is not transmitted through any body: the walls
## themselves keep time. If the hum falters (infection drops below 0.7)
## the room ejects its occupant back into a very slightly incorrect
## apartment — the conductor's tempo comes back a hair off.

const ORIGIN := Vector3(-7.2, 90.0, -4.4)  # far above the shell: impossible
const W := 5.0
const D := 7.0
const H := 3.4

var occupant: Node = null

var _return_pos := Vector3.ZERO
var _seam_mat: StandardMaterial3D
var _hum: AudioStreamPlayer3D
var _flash: ColorRect


func _ready() -> void:
	position = ORIGIN
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.055, 0.06)
	dark.roughness = 0.9
	_slab(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), dark)      # floor
	_slab(Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), dark)   # ceiling
	_slab(Vector3(0.2, H, D), Vector3(-W / 2 - 0.1, H / 2, 0), dark)
	_slab(Vector3(0.2, H, D), Vector3(W / 2 + 0.1, H / 2, 0), dark)
	_slab(Vector3(W, H, 0.2), Vector3(0, H / 2, -D / 2 - 0.1), dark)
	_slab(Vector3(W, H, 0.2), Vector3(0, H / 2, D / 2 + 0.1), dark)

	# seams of light where the surfaces meet: the room's pulse
	_seam_mat = StandardMaterial3D.new()
	_seam_mat.emission_enabled = true
	_seam_mat.emission = Color(0.34, 0.9, 0.83)
	_seam_mat.emission_energy_multiplier = 0.6
	_seam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for y in [0.02, H - 0.02]:
		_seam(Vector3(W, 0.02, 0.02), Vector3(0, y, -D / 2))
		_seam(Vector3(W, 0.02, 0.02), Vector3(0, y, D / 2))
		_seam(Vector3(0.02, 0.02, D), Vector3(-W / 2, y, 0))
		_seam(Vector3(0.02, 0.02, D), Vector3(W / 2, y, 0))

	var label := Label3D.new()
	label.text = "0 — SHARED MECHANICAL / DEVOTIONAL / UNRESOLVED"
	label.font_size = 40
	label.modulate = Color(0.5, 0.7, 0.68)
	label.position = Vector3(0, 1.9, -D / 2 + 0.12)
	add_child(label)

	# the way back: a door-shaped seam at the south end
	var exit_door := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.2, 0.4)
	shape.shape = box
	exit_door.add_child(shape)
	exit_door.position = Vector3(0, 1.1, D / 2 - 0.15)
	add_child(exit_door)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.95, 2.15, 0.04)
	frame.mesh = fm
	frame.material_override = _seam_mat
	frame.position = Vector3(0, 1.07, 0.12)
	exit_door.add_child(frame)

	_hum = AudioStreamPlayer3D.new()
	_hum.stream = PropAudio.get_stream("hum_loop")
	_hum.pitch_scale = 0.5
	_hum.volume_db = -14.0
	_hum.unit_size = 6.0
	_hum.position = Vector3(0, 1.6, 0)
	add_child(_hum)

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_flash = ColorRect.new()
	_flash.size = Vector2(1280, 720)
	_flash.color = Color(0, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	Conductor.motif_tick.connect(_on_tick)


func _slab(size: Vector3, offset: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = offset
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _seam(size: Vector3, offset: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _seam_mat
	mi.position = offset
	add_child(mi)


func enter(player: Node) -> void:
	if occupant != null:
		return
	occupant = player
	_return_pos = player.global_position
	_blink(0.9)
	player.global_position = ORIGIN + Vector3(0, 0.2, D / 2 - 1.2)
	player.velocity = Vector3.ZERO
	if not _hum.playing:
		_hum.play()
	print("[ROOM0] entered")


func interact_prompt() -> String:
	return "[E]  Leave" if occupant != null else ""


## Exit door (interact) and forced ejection both come through here.
func interact(player: Node) -> void:
	if player == occupant:
		_leave(false)


func _leave(ejected: bool) -> void:
	if occupant == null:
		return
	_blink(1.0 if ejected else 0.6)
	occupant.global_position = _return_pos
	occupant.velocity = Vector3.ZERO
	occupant = null
	_hum.stop()
	if ejected:
		# the slightly incorrect apartment: the building's time returns
		# fractionally off, and it never quite settles back
		Conductor.bpm += 0.8
		print("[ROOM0] collapsed — occupant returned, tempo now %.1f" % Conductor.bpm)
	else:
		print("[ROOM0] exited")


func _blink(strength: float) -> void:
	_flash.color.a = clampf(strength, 0.0, 1.0)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.7)


func _on_tick(_index: int, accent: float, _pitch: float) -> void:
	# no translation profile in here — the room IS the motif
	_seam_mat.emission_energy_multiplier = 0.6 + accent * 2.4


func _process(delta: float) -> void:
	_seam_mat.emission_energy_multiplier = maxf(
			_seam_mat.emission_energy_multiplier - delta * 3.0, 0.6)
	if occupant and Conductor.infection < 0.7:
		_leave(true)
