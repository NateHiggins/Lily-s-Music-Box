class_name OrisonElevator
extends Node3D
## The unreliable elevator, now with hardware: a kinematic cabin, real
## center-parting landing doors at every stop (closed doors are the shaft
## interlock — you cannot walk into an empty well), and brass call plates
## mounted on the hall wall beside the opening. Ride sequence: call ->
## doors close -> travel (cabin moved in _physics_process so a rider is
## carried) -> arrival bell -> doors open. Travels at 1.2 m/s.

const SPEED := 1.2
const DOOR_SPEED := 1.6          # door open fraction per second
const DOOR_TRAVEL := 0.52        # meters each panel slides
const PANEL_W := 0.50
const PANEL_H := 2.06
const FRONT_Z := 1.1             # shaft front plane, local (shaft is 2.2 deep)
const WALL_T := 0.18             # core wall the opening pierces
const SETTLE := 0.35             # decelerate over the last stretch

enum S { IDLE, CLOSING, MOVING, OPENING }

var stops: Dictionary = {}       # level name -> shaft-local y
var stop_order: Array = []
var current := "F01"
var moving := false              # true from request until doors reopen
var state: int = S.IDLE
var _pending := ""

var _cabin: AnimatableBody3D
var _bell: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _doors: Dictionary = {}      # level -> {"w": body, "e": body, "t": float}
var _buttons: Dictionary = {}    # level -> landing call-plate material
var _cabin_lamps: Dictionary = {}  # level -> cab button material


func setup(elevator_data: Dictionary) -> void:
	var shaft: Array = elevator_data["shaft"]
	var cx := (float(shaft[0]) + float(shaft[2])) / 2.0
	var cy := (float(shaft[1]) + float(shaft[3])) / 2.0
	position = GameBoot.b2g([cx, cy, 0.0])
	for level in elevator_data["stops"]:
		stops[level] = float(elevator_data["stops"][level])
		stop_order.append(level)
	stop_order.sort_custom(func(a, b): return stops[a] < stops[b])

	_cabin = AnimatableBody3D.new()
	_cabin.sync_to_physics = true
	add_child(_cabin)
	var cw: float = float(elevator_data["cabin"][0])
	var cd: float = float(elevator_data["cabin"][1])
	_add_cabin_box(Vector3(cw, 0.12, cd), Vector3(0, 0.06, 0))          # floor
	_add_cabin_box(Vector3(cw, 0.08, cd), Vector3(0, 2.28, 0))          # ceiling
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(-cw / 2, 1.16, 0))   # west
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(cw / 2, 1.16, 0))    # east
	_add_cabin_box(Vector3(cw, 2.2, 0.05), Vector3(0, 1.16, -cd / 2))   # rear
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position = Vector3(0, 2.1, 0)
	_cabin.add_child(light)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = PropAudio.get_stream("bell")
	_bell.volume_db = -10.0
	_cabin.add_child(_bell)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = PropAudio.get_stream("elevator_machine_loop")
	_hum.volume_db = -60.0
	_cabin.add_child(_hum)
	_hum.play()
	_cabin.position.y = stops[current]

	var door_w: float = float(elevator_data.get("door_w", 0.91))
	for level in stop_order:
		_build_landing(level, door_w)
	_set_door_t(current, 1.0)    # arrive with the home landing open
	_add_cabin_panel(cw, cd)


func _steel(dark := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.36, 0.33) if not dark \
			else Color(0.18, 0.20, 0.19)
	m.roughness = 0.45
	m.metallic = 0.55
	return m


func _brass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.52, 0.28)
	m.roughness = 0.35
	m.metallic = 0.8
	return m


## One stop's hardware: header/jamb trim, two sliding panels with
## collision, and the call plate on the hall face of the core wall.
func _build_landing(level: String, door_w: float) -> void:
	var y: float = stops[level]
	var jamb := door_w / 2.0
	# frame: brass jambs and header lining the wall reveal, a hair proud
	# of both faces so the opening reads as cased rather than cut
	for sx in [-1.0, 1.0]:
		var j := MeshInstance3D.new()
		var jm := BoxMesh.new()
		jm.size = Vector3(0.06, PANEL_H + 0.10, WALL_T + 0.02)
		j.mesh = jm
		j.material_override = _brass()
		j.position = Vector3(sx * (jamb + 0.03), y + (PANEL_H + 0.10) / 2,
				FRONT_Z)
		add_child(j)
	var hdr := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(door_w + 0.18, 0.10, WALL_T + 0.02)
	hdr.mesh = hm
	hdr.material_override = _brass()
	hdr.position = Vector3(0, y + PANEL_H + 0.13, FRONT_Z)
	add_child(hdr)
	# the two panels ride just inside the shaft face
	var pair := {"t": 0.0}
	for side in ["w", "e"]:
		var sx := -1.0 if side == "w" else 1.0
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(PANEL_W, PANEL_H, 0.045)
		shape.shape = box
		body.add_child(shape)
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(PANEL_W, PANEL_H, 0.045)
		vis.mesh = bm
		vis.material_override = _steel()
		body.add_child(vis)
		# narrow vision window, meeting-edge side, eye height
		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.11, 0.32, 0.055)
		win.mesh = wm
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.55, 0.62, 0.65, 0.5)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.05
		glass.metallic = 0.2
		win.material_override = glass
		win.position = Vector3(-sx * (PANEL_W / 2 - 0.11), 0.32, 0)
		body.add_child(win)
		var kick := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(PANEL_W, 0.16, 0.05)
		kick.mesh = km
		kick.material_override = _steel(true)
		kick.position = Vector3(0, -PANEL_H / 2 + 0.08, 0)
		body.add_child(kick)
		body.position = _panel_pos(sx, y, 0.0)
		pair[side] = body
	_doors[level] = pair
	# call plate: mounted flush on the hall face of the core wall,
	# east of the opening
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.10, 0.17, 0.015)
	plate.mesh = pm
	plate.material_override = _brass()
	# flush on the hall face of the core wall (wall spans +-WALL_T/2)
	plate.position = Vector3(jamb + 0.28, y + 1.15,
			FRONT_Z + WALL_T / 2.0 + 0.008)
	add_child(plate)
	var btn := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.017
	cyl.bottom_radius = 0.019
	cyl.height = 0.018
	btn.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.92, 0.88, 0.78)
	bmat.emission_enabled = true
	bmat.emission = Color(0.9, 0.7, 0.3)
	bmat.emission_energy_multiplier = 0.35
	btn.material_override = bmat
	btn.rotation_degrees = Vector3(90, 0, 0)
	btn.position = Vector3(jamb + 0.28, y + 1.15,
			FRONT_Z + WALL_T / 2.0 + 0.024)
	add_child(btn)
	_buttons[level] = bmat
	var area := Area3D.new()
	var ashape := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(0.14, 0.20, 0.10)
	ashape.shape = abox
	area.add_child(ashape)
	area.position = Vector3(jamb + 0.28, y + 1.15,
			FRONT_Z + WALL_T / 2.0 + 0.03)
	area.set_meta("call_level", level)
	add_child(area)


func _panel_pos(sx: float, y: float, open_t: float) -> Vector3:
	var closed_x := sx * (PANEL_W / 2 - 0.01)
	return Vector3(closed_x + sx * DOOR_TRAVEL * open_t,
			y + PANEL_H / 2 + 0.02, FRONT_Z - 0.075)


func _set_door_t(level: String, t: float) -> void:
	var pair: Dictionary = _doors[level]
	pair["t"] = t
	var y: float = stops[level]
	pair["w"].position = _panel_pos(-1.0, y, t)
	pair["e"].position = _panel_pos(1.0, y, t)


func _add_cabin_box(size: Vector3, offset: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	_cabin.add_child(shape)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	vis.mesh = bm
	vis.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	mat.roughness = 0.5
	mat.metallic = 0.3
	vis.material_override = mat
	_cabin.add_child(vis)


## Call buttons and the cabin panel resolve here via the player's ray.
func interact_area(area: Area3D) -> void:
	if area.has_meta("call_level"):
		var level: String = area.get_meta("call_level")
		if state == S.IDLE and level == current:
			# car is here: reopen if someone closed on you
			if _doors[current]["t"] < 1.0:
				state = S.OPENING
			return
		travel_to(level)
	elif area.has_meta("cabin_floor"):
		# One button per stop. The panel used to be a single plate that
		# advanced to the next floor, so reaching B1 from F06 meant riding
		# every landing in between — a lift you cannot direct is furniture.
		if state != S.IDLE:
			return
		travel_to(String(area.get_meta("cabin_floor")))


func travel_to(level: String) -> void:
	if state != S.IDLE or level == current or not stops.has(level):
		return
	moving = true
	_pending = level
	state = S.CLOSING
	if _buttons.has(level):
		_buttons[level].emission_energy_multiplier = 1.6
	if _cabin_lamps.has(level):
		_cabin_lamps[level].emission_energy_multiplier = 1.7
	print("[ELEVATOR] %s -> %s (%.1fs)" % [current, level,
			absf(stops[level] - _cabin.position.y) / SPEED])
	create_tween().tween_property(_hum, "volume_db", -16.0, 0.5)


## Small public surface for autonomous residents. They queue by waiting at
## the landing; only an idle car accepts a new destination.
func npc_request(level: String) -> bool:
	if not stops.has(level):
		return false
	if current == level and state == S.IDLE:
		if _doors[current]["t"] < 1.0:
			state = S.OPENING
		return true
	if state != S.IDLE:
		return false
	travel_to(level)
	return true


func is_ready_at(level: String) -> bool:
	return current == level and state == S.IDLE \
			and float(_doors[level]["t"]) >= 0.98


func _physics_process(delta: float) -> void:
	match state:
		S.CLOSING:
			var t: float = maxf(0.0, _doors[current]["t"] - DOOR_SPEED * delta)
			_set_door_t(current, t)
			if t <= 0.0:
				state = S.MOVING
		S.MOVING:
			var target: float = stops[_pending]
			var dy := target - _cabin.position.y
			var dist := absf(dy)
			var v := SPEED * clampf(dist / SETTLE, 0.25, 1.0)
			var step := minf(dist, v * delta)
			_cabin.position.y += signf(dy) * step
			if dist <= 0.005:
				_cabin.position.y = target
				current = _pending
				state = S.OPENING
				_bell.play()
				if _buttons.has(current):
					_buttons[current].emission_energy_multiplier = 0.35
				if _cabin_lamps.has(current):
					_cabin_lamps[current].emission_energy_multiplier = 0.3
				create_tween().tween_property(_hum, "volume_db", -60.0, 1.0)
		S.OPENING:
			var t2: float = minf(1.0, _doors[current]["t"] + DOOR_SPEED * delta)
			_set_door_t(current, t2)
			if t2 >= 1.0:
				state = S.IDLE
				moving = false


## Cabin control panel: a brass plate carrying one pressable button per
## stop, in the order they are stacked, so you can go where you want.
func _add_cabin_panel(cw: float, cd: float) -> void:
	var n := stop_order.size()
	var pitch := 0.085
	var run := pitch * n
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.016, run + 0.14, 0.20)
	plate.mesh = pm
	plate.material_override = _brass()
	plate.position = Vector3(cw / 2 - 0.04, 1.22, cd / 2 - 0.22)
	_cabin.add_child(plate)
	# top of the plate is the top of the building: B1 sits at the bottom
	for i in range(n):
		var level: String = stop_order[i]
		var y := 1.22 - run * 0.5 + (i + 0.5) * pitch
		var b := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.017
		c.bottom_radius = 0.019
		c.height = 0.016
		b.mesh = c
		b.rotation_degrees = Vector3(0, 0, 90)
		b.position = Vector3(cw / 2 - 0.030, y, cd / 2 - 0.22)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.9, 0.87, 0.8)
		bm.emission_enabled = true
		bm.emission = Color(0.9, 0.7, 0.3)
		bm.emission_energy_multiplier = 0.3
		b.material_override = bm
		_cabin.add_child(b)
		_cabin_lamps[level] = bm
		# engraved level mark beside each button
		var tag := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.004, 0.026, 0.014 if level == "B1" else 0.026)
		tag.mesh = tm
		tag.material_override = _steel(true)
		tag.position = Vector3(cw / 2 - 0.048, y, cd / 2 - 0.145)
		_cabin.add_child(tag)
		var hit := Area3D.new()
		var hs := CollisionShape3D.new()
		var hb := BoxShape3D.new()
		hb.size = Vector3(0.12, pitch * 0.92, 0.13)
		hs.shape = hb
		hit.add_child(hs)
		hit.position = Vector3(cw / 2 - 0.075, y, cd / 2 - 0.20)
		hit.set_meta("cabin_floor", level)
		_cabin.add_child(hit)
