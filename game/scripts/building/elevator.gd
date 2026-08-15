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
## Independent service: the car answers no hall calls while a keyholder
## (maintenance, or a test) has it. Residents shrug and take the stairs.
var service_mode := false

var _cabin: AnimatableBody3D
var _bell: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _doors: Dictionary = {}      # level -> {"w": body, "e": body, "t": float}
var _buttons: Dictionary = {}    # level -> landing call-plate material
var _cabin_lamps: Dictionary = {}  # level -> cab button material
## The collapsible gate inside the car, and the needle over its opening.
## Both are driven from the car rather than animated: the gate rides the
## landing door fraction, the needle rides the cabin's height.
var _gate: Node3D
var _needle: Node3D
var _dome: StandardMaterial3D
var _sleep_half_width := 0.0
var _sleep_rear_z := 0.0


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
	_sleep_half_width = cw * 0.5 + PlayerController.BODY_RADIUS
	_sleep_rear_z = -cd * 0.5 - PlayerController.BODY_RADIUS
	_add_cabin_box(Vector3(cw, 0.12, cd), Vector3(0, 0.06, 0))          # floor
	_add_cabin_box(Vector3(cw, 0.08, cd), Vector3(0, 2.28, 0))          # ceiling
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(-cw / 2, 1.16, 0))   # west
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(cw / 2, 1.16, 0))    # east
	_add_cabin_box(Vector3(cw, 2.2, 0.05), Vector3(0, 1.16, -cd / 2))   # rear
	_build_cab_interior(cw, cd)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.94, 0.80)
	light.light_energy = 0.9
	light.omni_range = 3.0
	# inside the dome, not floating below the ceiling slab
	light.position = Vector3(0, 2.12, 0)
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


## A finish from the shared catalog, or a flat stand-in if that texture
## has not been baked yet.
##
## MatLib caches and hands back the SAME material instance to everyone
## who asks, so the result must never be mutated. When the key is not in
## SETS the cache holds a flat material with no albedo_texture, and this
## builds its own rather than writing into the shared one.
func _finish(key: String, fallback: Color, rough: float,
		metal := 0.0) -> StandardMaterial3D:
	var m := MatLib.get_mat(key, Color.WHITE)
	if m and m.albedo_texture != null:
		return m
	var f := StandardMaterial3D.new()
	f.albedo_color = fallback
	f.roughness = rough
	f.metallic = metal
	return f


## Visual-only box inside the car. The five structural boxes already
## carry the collision; panelling a wall should not thicken it.
func _cab_box(size: Vector3, at: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = mat
	_cabin.add_child(mi)
	return mi


## Tube between two points: handrails, gate bars, the dome ring.
func _cab_tube(a: Vector3, b: Vector3, r: float,
		mat: StandardMaterial3D, parent: Node3D = null) -> MeshInstance3D:
	var span := b - a
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = span.length()
	cm.radial_segments = 8
	mi.mesh = cm
	mi.position = (a + b) * 0.5
	mi.material_override = mat
	var dir := span.normalized()
	var dot := clampf(Vector3.UP.dot(dir), -1.0, 1.0)
	if absf(dot) < 0.9999:
		mi.rotation = Basis(Vector3.UP.cross(dir).normalized(),
				acos(dot)).get_euler()
	elif dot < 0.0:
		mi.rotation = Vector3(PI, 0, 0)
	(parent if parent else _cabin).add_child(mi)
	return mi


## What the inside of a 1926 car actually was.
##
## The cab was five untextured boxes the colour of wet cardboard, which
## is the one room in the building every player is guaranteed to stand
## inside and stare at, with nothing else to look at, for the length of a
## ride. Period cars of this class are consistent about what they carry,
## so this carries it: quartered oak in raised panels to a chair rail,
## plain field above, a mirror on the back wall, a brass handrail on
## three sides, a coved ceiling with an opal dome, terrazzo underfoot, a
## collapsible brass gate across the opening, and a needle dial over it.
##
## The mirror is the reason the back wall is worth having. There is no
## planar reflection on gl_compatibility, so like the bathrooms it is
## aged silvering rather than a real reflection - but a mirror facing you
## in a lift does its work by being there.
func _build_cab_interior(cw: float, cd: float) -> void:
	var oak := _finish("oak_quartered", Color(0.42, 0.28, 0.16), 0.45)
	var brass := _finish("brass_bright", Color(0.62, 0.50, 0.26), 0.34, 0.85)
	var terrazzo := _finish("terrazzo_dark", Color(0.29, 0.27, 0.24), 0.40)
	# NOT car_paint. That cell is olive-drab enamel gone alligatored,
	# which is right for a service car's structure and completely
	# wrong beside polished oak - it read as a rusted-out plant room
	# with a nice dado in it. A passenger car of this class has a
	# painted field above the rail.
	var field := _finish("enamel", Color(0.88, 0.84, 0.74), 0.42)

	# Inner faces of the five boxes: the panelling sits proud of these.
	var wx := cw / 2.0 - 0.025          # west/east inner face
	var rz := -cd / 2.0 + 0.025         # rear inner face
	var fz := cd / 2.0                  # the open front
	var pr := 0.018                     # panel thickness

	# floor: terrazzo laid over the structural pan
	_cab_box(Vector3(cw - 0.10, 0.012, cd - 0.06),
			Vector3(0, 0.126, 0.03), terrazzo)

	# --- panelling, three walls ------------------------------------
	# skirting / raised panels / chair rail / field / cornice
	for sx in [-1.0, 1.0]:
		# sx comes out of an untyped array literal, so it is a Variant and
		# nothing derived from it can be inferred. Say float.
		var x: float = sx * (wx - pr * 0.5)
		_cab_box(Vector3(pr + 0.012, 0.14, cd - 0.06),
				Vector3(x, 0.19, 0.03), oak)
		# two raised panels per side, with a stile between them
		for pi in 2:
			var cz := -0.36 + pi * 0.72 + 0.03
			_cab_box(Vector3(pr, 0.60, 0.60), Vector3(x, 0.60, cz), oak)
			_cab_box(Vector3(pr + 0.018, 0.52, 0.52),
					Vector3(x, 0.60, cz), oak)
		_cab_box(Vector3(pr + 0.020, 0.06, cd - 0.06),
				Vector3(x, 0.97, 0.03), oak)          # chair rail
		_cab_box(Vector3(pr, 1.05, cd - 0.06),
				Vector3(x, 1.525, 0.03), field)        # field above
		_cab_box(Vector3(pr + 0.024, 0.09, cd - 0.06),
				Vector3(x, 2.10, 0.03), oak)           # cornice
	# rear wall, same courses
	_cab_box(Vector3(cw - 0.06, 0.14, pr + 0.012),
			Vector3(0, 0.19, rz + pr * 0.5), oak)
	for pi in 2:
		var px := -0.34 + pi * 0.68
		_cab_box(Vector3(0.58, 0.60, pr), Vector3(px, 0.60, rz + pr * 0.5), oak)
		_cab_box(Vector3(0.50, 0.52, pr + 0.018),
				Vector3(px, 0.60, rz + pr * 0.5), oak)
	_cab_box(Vector3(cw - 0.06, 0.06, pr + 0.020),
			Vector3(0, 0.97, rz + pr * 0.5), oak)
	_cab_box(Vector3(cw - 0.06, 0.09, pr + 0.024),
			Vector3(0, 2.10, rz + pr * 0.5), oak)

	# --- the mirror, in an oak surround ----------------------------
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.74, 0.75, 0.72)
	silver.metallic = 0.86
	silver.roughness = 0.18
	silver.rim_enabled = true
	silver.rim = 0.35
	_cab_box(Vector3(1.06, 0.86, pr), Vector3(0, 1.52, rz + pr * 0.5), oak)
	_cab_box(Vector3(0.96, 0.76, pr + 0.008),
			Vector3(0, 1.52, rz + pr * 0.6), silver)

	# --- handrail on three sides -----------------------------------
	var hy := 0.92
	var off := pr + 0.055
	for sx in [-1.0, 1.0]:
		var hx: float = sx * (wx - off)
		_cab_tube(Vector3(hx, hy, rz + 0.10), Vector3(hx, hy, fz - 0.16),
				0.021, brass)
		for bz in [rz + 0.14, fz - 0.20]:
			_cab_tube(Vector3(sx * wx, hy, bz), Vector3(hx, hy, bz),
					0.011, brass)
	_cab_tube(Vector3(-wx + 0.10, hy, rz + off),
			Vector3(wx - 0.10, hy, rz + off), 0.021, brass)

	# --- coved ceiling and the opal dome ---------------------------
	for sx in [-1.0, 1.0]:
		_cab_box(Vector3(0.10, 0.10, cd - 0.06),
				Vector3(sx * (wx - 0.05), 2.19, 0.03), field)
	_cab_box(Vector3(cw - 0.06, 0.10, 0.10),
			Vector3(0, 2.19, rz + 0.05), field)
	_dome = StandardMaterial3D.new()
	_dome.albedo_color = Color(0.92, 0.90, 0.84)
	_dome.roughness = 0.22
	_dome.emission_enabled = true
	_dome.emission = Color(1.0, 0.94, 0.80)
	_dome.emission_energy_multiplier = 0.45
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.23
	dm.height = 0.46
	dm.radial_segments = 18
	dm.rings = 8
	dome.mesh = dm
	dome.scale = Vector3(1.0, 0.34, 1.0)
	dome.position = Vector3(0, 2.21, 0.02)
	dome.material_override = _dome
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin.add_child(dome)
	for i in 16:                       # brass retaining ring
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		_cab_tube(Vector3(cos(a0) * 0.24, 2.225, 0.02 + sin(a0) * 0.24),
				Vector3(cos(a1) * 0.24, 2.225, 0.02 + sin(a1) * 0.24),
				0.012, brass)

	# --- the collapsible gate --------------------------------------
	# A scissor gate compresses toward its jamb, so the whole lattice
	# lives under one node pivoted at the west jamb and is squeezed in x.
	# That is what the real hardware does, and it costs one transform.
	_gate = Node3D.new()
	_gate.name = "CarGate"
	_gate.position = Vector3(-0.455, 0.0, fz - 0.06)
	_cabin.add_child(_gate)
	var gw := 0.91
	_cab_tube(Vector3(0, 0.18, 0), Vector3(gw, 0.18, 0), 0.016, brass, _gate)
	_cab_tube(Vector3(0, 2.08, 0), Vector3(gw, 2.08, 0), 0.016, brass, _gate)
	for i in 7:
		var x0 := gw * i / 7.0
		var x1 := gw * (i + 1) / 7.0
		_cab_tube(Vector3(x0, 0.20, 0), Vector3(x1, 2.06, 0),
				0.009, brass, _gate)
		_cab_tube(Vector3(x1, 0.20, 0), Vector3(x0, 2.06, 0),
				0.009, brass, _gate)
	for i in 3:
		var xv := gw * (i + 1) / 4.0
		_cab_tube(Vector3(xv, 0.20, 0), Vector3(xv, 2.06, 0),
				0.011, brass, _gate)

	# --- floor indicator over the opening --------------------------
	# A half-round brass dial with a needle. It reads the car's actual
	# height rather than the destination, so it sweeps during the ride
	# and is the only thing in the cab that tells you where you are.
	var dial := MeshInstance3D.new()
	var dcm := CylinderMesh.new()
	dcm.top_radius = 0.17
	dcm.bottom_radius = 0.17
	dcm.height = 0.016
	dcm.radial_segments = 20
	dial.mesh = dcm
	dial.material_override = _finish("indicator_enamel",
			Color(0.88, 0.84, 0.75), 0.24)
	dial.rotation_degrees = Vector3(90, 0, 0)
	dial.position = Vector3(0, 2.16, fz - 0.10)
	_cabin.add_child(dial)
	var bez := MeshInstance3D.new()
	var bzm := TorusMesh.new()
	bzm.inner_radius = 0.170
	bzm.outer_radius = 0.192
	bzm.rings = 20
	bez.mesh = bzm
	bez.material_override = brass
	bez.rotation_degrees = Vector3(90, 0, 0)
	bez.position = Vector3(0, 2.16, fz - 0.10)
	_cabin.add_child(bez)
	_needle = Node3D.new()
	_needle.position = Vector3(0, 2.16, fz - 0.118)
	_cabin.add_child(_needle)
	var nd := MeshInstance3D.new()
	var ndm := BoxMesh.new()
	ndm.size = Vector3(0.012, 0.15, 0.008)
	nd.mesh = ndm
	nd.material_override = _finish("bakelite_black",
			Color(0.14, 0.12, 0.11), 0.28)
	nd.position = Vector3(0, 0.068, 0)
	_needle.add_child(nd)
	# The stops, engraved around the arc the needle sweeps, at exactly
	# the angles _drive_cab_hardware will put the needle at. A dial with
	# no numerals on it is a clock with no face: you can see that
	# something is moving and learn nothing from it.
	var marks := stop_order.size()
	for i in marks:
		var th := deg_to_rad(lerpf(72.0, -72.0, float(i) / (marks - 1))) \
				if marks > 1 else 0.0
		_plate_quad(PLATE_LEGEND.get(stop_order[i], stop_order[i]),
				Vector3(-sin(th) * 0.133, 2.16 + cos(th) * 0.133,
						fz - 0.112),
				Vector2(0.040, 0.040), Vector3(0, 180, 0))

	# --- certificate of inspection, because every car carries one ---
	_cab_box(Vector3(pr + 0.010, 0.30, 0.22),
			Vector3(-(wx - pr), 1.52, -0.24), brass)
	_cab_box(Vector3(pr + 0.016, 0.26, 0.18),
			Vector3(-(wx - pr - 0.004), 1.52, -0.24),
			_finish("indicator_enamel", Color(0.86, 0.83, 0.74), 0.30))


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
	elif area.has_meta("cabin_alarm"):
		# It rings the car's own bell and nothing else. In a building
		# where nobody answers the telephone, an alarm that summoned help
		# would be the least believable thing in it.
		if _bell and not _bell.playing:
			_bell.play()


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
	if service_mode or not stops.has(level):
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


## The lift owns the geometry of its car and threshold. Even an idle car is a
## scene seam: replacing the world while the capsule overlaps its kinematic
## floor or landing gate is never a valid sleep entry.
func blocks_sleep_entry(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return absf(local.x) <= _sleep_half_width \
			and local.z >= _sleep_rear_z \
			and local.z <= FRONT_Z + PlayerController.BODY_RADIUS + 0.20


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
	_drive_cab_hardware()


## The gate follows the doors and the needle follows the car.
##
## Neither is animated on a timeline: a scissor gate is mechanically
## linked to the landing doors, and a needle dial is driven off the
## hoist, so both are derived every frame from the state that already
## exists. That also means they stay correct when a ride is interrupted,
## which a keyframed animation would not.
func _drive_cab_hardware() -> void:
	if _gate:
		var open_t: float = float(_doors[current]["t"]) \
				if _doors.has(current) else 0.0
		# A collapsed gate is not zero-width - the leaves stack against
		# the jamb - so it bottoms out at a tenth of its span.
		_gate.scale.x = lerpf(1.0, 0.10, open_t)
	if _needle and stop_order.size() > 1:
		var lo: float = stops[stop_order[0]]
		var hi: float = stops[stop_order[stop_order.size() - 1]]
		var f: float = clampf((_cabin.position.y - lo) / maxf(0.001, hi - lo),
				0.0, 1.0)
		# bottom of the building at the left horn of the dial, top at the
		# right, so the needle sweeps the way the car climbs
		_needle.rotation.z = deg_to_rad(lerpf(72.0, -72.0, f))


## Cabin control panel: a brass plate carrying one pressable button per
## stop, in the order they are stacked, so you can go where you want.
##
## Depths here are measured from the FINISHED wall, not the structural
## box. Panelling the car moved its east face 18 mm inboard and swallowed
## this entire panel - plate, buttons and numerals - because they were
## dimensioned off cw/2. The buttons were half buried even before that:
## they sat at a LARGER x than the plate they are supposed to stand proud
## of, so they went into the wall rather than out of it.
func _add_cabin_panel(cw: float, cd: float) -> void:
	var n := stop_order.size()
	var pitch := 0.085
	var run := pitch * n
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.016, run + 0.14, 0.20)
	plate.mesh = pm
	plate.material_override = _brass()
	plate.position = Vector3(cw / 2 - 0.051, 1.22, cd / 2 - 0.22)
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
		b.position = Vector3(cw / 2 - 0.067, y, cd / 2 - 0.22)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.9, 0.87, 0.8)
		bm.emission_enabled = true
		bm.emission = Color(0.9, 0.7, 0.3)
		bm.emission_energy_multiplier = 0.3
		b.material_override = bm
		_cabin.add_child(b)
		_cabin_lamps[level] = bm
		# The floor's number, engraved, off the same brass atlas the
		# door plaques and storey signs use. It was a featureless dark
		# box - one for every stop, distinguishable only by being
		# shorter at B1 - so the panel told you there were seven of
		# something and nothing else.
		_plate_quad(PLATE_LEGEND.get(level, level),
				Vector3(cw / 2 - 0.060, y, cd / 2 - 0.145),
				Vector2(0.055, 0.055))
		var hit := Area3D.new()
		var hs := CollisionShape3D.new()
		var hb := BoxShape3D.new()
		hb.size = Vector3(0.12, pitch * 0.92, 0.13)
		hs.shape = hb
		hit.add_child(hs)
		hit.position = Vector3(cw / 2 - 0.090, y, cd / 2 - 0.20)
		hit.set_meta("cabin_floor", level)
		_cabin.add_child(hit)
	# Below the floor buttons, the two controls every car of this class
	# carries and no self-service car is legal without: a red stop and an
	# alarm. Neither is wired to a destination - the stop halts nothing
	# because the ride is not interruptible - but a panel with only floor
	# numbers on it reads as a prop, and these are the two the eye looks
	# for. The alarm rings the car bell, which is the honest behaviour.
	var base := 1.22 - run * 0.5 - 0.09
	var stop_mat := StandardMaterial3D.new()
	stop_mat.albedo_color = Color(0.52, 0.09, 0.07)
	stop_mat.roughness = 0.34
	var stop_btn := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.026
	sc.bottom_radius = 0.022
	sc.height = 0.020
	stop_btn.mesh = sc
	stop_btn.rotation_degrees = Vector3(0, 0, 90)
	stop_btn.position = Vector3(cw / 2 - 0.069, base, cd / 2 - 0.22)
	stop_btn.material_override = stop_mat
	_cabin.add_child(stop_btn)
	var alarm := MeshInstance3D.new()
	var ac := CylinderMesh.new()
	ac.top_radius = 0.017
	ac.bottom_radius = 0.019
	ac.height = 0.016
	alarm.mesh = ac
	alarm.rotation_degrees = Vector3(0, 0, 90)
	alarm.position = Vector3(cw / 2 - 0.067, base - 0.075, cd / 2 - 0.22)
	alarm.material_override = _finish("bakelite_black",
			Color(0.14, 0.12, 0.11), 0.28)
	_cabin.add_child(alarm)
	var ahit := Area3D.new()
	var ahs := CollisionShape3D.new()
	var ahb := BoxShape3D.new()
	ahb.size = Vector3(0.12, 0.07, 0.13)
	ahs.shape = ahb
	ahit.add_child(ahs)
	ahit.position = Vector3(cw / 2 - 0.090, base - 0.075, cd / 2 - 0.20)
	ahit.set_meta("cabin_alarm", true)
	_cabin.add_child(ahit)


## Level names as the brass atlas spells them: the plates were cut for
## the storey signs, which say "1", not "F01".
const PLATE_LEGEND := {
	"B1": "B1", "F01": "1", "F02": "2", "F03": "3",
	"F04": "4", "F05": "5", "F06": "6", "ROOF": "ROOF",
}
const PLATE_ATLAS := "res://assets/building/textures/signage/engraved_plates.png"
const PLATE_COLS := 6
const PLATE_ROWS := 6
var _plate_index: Dictionary = {}


## One engraved legend off the shared brass atlas, as a quad facing into
## the car. Sampled with a UV window rather than AtlasTexture, which does
## not crop on a 3D material.
func _plate_quad(legend: String, at: Vector3, size: Vector2,
		rot_deg := Vector3(0, -90, 0)) -> MeshInstance3D:
	if _plate_index.is_empty():
		var f := FileAccess.open("res://data/signage_plates.json",
				FileAccess.READ)
		if f:
			var doc: Dictionary = JSON.parse_string(f.get_as_text())
			_plate_index = doc.get("index", {})
	if not _plate_index.has(legend):
		return null
	var cell: Array = _plate_index[legend]
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(PLATE_ATLAS)
	mat.uv1_scale = Vector3(1.0 / PLATE_COLS, 1.0 / PLATE_ROWS, 1.0)
	mat.uv1_offset = Vector3(float(cell[0]) / PLATE_COLS,
			float(cell[1]) / PLATE_ROWS, 0.0)
	mat.roughness = 0.38
	mat.metallic = 0.65
	mi.material_override = mat
	mi.position = at
	# default faces west, off the east-wall panel; the dial passes its own
	mi.rotation_degrees = rot_deg
	_cabin.add_child(mi)
	return mi
