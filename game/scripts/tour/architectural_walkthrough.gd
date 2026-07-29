class_name ArchitecturalWalkthrough
extends Node
## Guided architectural walkthrough (T, or the debug-panel button): a
## fly-camera tour of the whole building — street, lobby, the grand dog-leg
## stair, every hero apartment, the roof and the basement — with captions.
## The path is computed from building_layout.json (stair flights included),
## so it stays true to the geometry it presents. Esc ends the tour.

const SPEED := 2.1
const EYE := 1.62
const LOOK_LERP := 3.0
const FADE_TIME := 0.45

var root: Node3D
var _wps: Array = []
var _i := 0
var _active := false
var _dwell := 0.0
var _fading := 0.0     # >0: fading out toward a teleport
var _cam: Camera3D
var _fade: ColorRect
var _caption: Label
var _header: Label
var _look_point := Vector3.ZERO


func setup(building_root: Node3D) -> void:
	root = building_root


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = 68.0
	add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -86.0
	_caption.offset_bottom = -46.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 21)
	_caption.add_theme_color_override("font_color", Color(0.92, 0.93, 0.9))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override("outline_size", 7)
	layer.add_child(_caption)
	_header = Label.new()
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_top = 10.0
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.text = "ARCHITECTURAL WALKTHROUGH  ·  Esc to exit"
	_header.add_theme_font_size_override("font_size", 12)
	_header.modulate = Color(0.75, 0.78, 0.8, 0.9)
	layer.add_child(_header)
	_header.visible = false
	_caption.visible = false


func toggle() -> void:
	if _active:
		stop()
	else:
		start()


func start() -> void:
	if _active or root == null or root.player == null:
		return
	if root.player.call_locked:
		return  # not while seated at the desk
	_build_path()
	if _wps.is_empty():
		return
	_i = 0
	_active = true
	_dwell = 0.0
	_fading = 0.0
	root.show_all_floors = true
	root.player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam.global_position = _wps[0]["p"]
	_look_point = _wps[0].get("look", _wps[0]["p"] + Vector3(0, 0, -2))
	_cam.look_at(_look_point)
	_cam.make_current()
	_header.visible = true
	_arrive()


func stop() -> void:
	if not _active:
		return
	_active = false
	root.show_all_floors = false
	root.player.call_locked = false
	root.player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_header.visible = false
	_caption.visible = false
	_fade.color.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("walkthrough"):
		toggle()
	elif _active and event.is_action_pressed("ui_cancel"):
		stop()


func _process(delta: float) -> void:
	if not _active:
		return
	var wp: Dictionary = _wps[_i]
	# look target eases toward the waypoint's interest point (or the path)
	var desired: Vector3 = wp.get("look",
			_wps[mini(_i + 1, _wps.size() - 1)]["p"])
	if desired.distance_to(_cam.global_position) < 0.4:
		desired = _look_point
	_look_point = _look_point.lerp(desired, minf(1.0, LOOK_LERP * delta))
	if _look_point.distance_to(_cam.global_position) > 0.05:
		_cam.look_at(_look_point)
	if _fading > 0.0:  # teleport transition
		_fading -= delta
		_fade.color.a = clampf(1.0 - absf(_fading) / FADE_TIME, 0.0, 1.0) \
				if _fading > 0.0 else _fade.color.a
		if _fading <= 0.0:
			_cam.global_position = wp["p"]
			_look_point = wp.get("look", wp["p"] + Vector3(0, 0, -2))
			_arrive()
		return
	if _fade.color.a > 0.0:
		_fade.color.a = maxf(0.0, _fade.color.a - delta / FADE_TIME)
	if _dwell > 0.0:
		_dwell -= delta
		return
	var target: Vector3 = wp["p"]
	var to_go := target - _cam.global_position
	if to_go.length() < 0.06:
		if _i >= _wps.size() - 1:
			stop()
			return
		_i += 1
		if _wps[_i].get("tp", false):
			_fading = FADE_TIME
		else:
			_arrive()
		return
	_cam.global_position += to_go.limit_length(SPEED * delta)


## On reaching (or being teleported to) waypoint _i: caption, dwell, doors.
func _arrive() -> void:
	var wp: Dictionary = _wps[_i]
	var cap: String = wp.get("cap", "")
	if cap != "":
		_caption.text = cap
		_caption.visible = true
	_dwell = wp.get("dwell", 0.0)
	# swing nearby doors open ahead of the camera
	var probe: Vector3 = _wps[mini(_i + 1, _wps.size() - 1)]["p"]
	for c in root.get_children():
		if c is DoorProp and not c.open and c.leaf_state == "closed":
			if c.global_position.distance_to(probe) < 3.0 \
					or c.global_position.distance_to(wp["p"]) < 3.0:
				c.interact(null)


# ---------------------------------------------------------------- the path

func _wp(x: float, y: float, z: float, look = null, cap := "",
		dwell := 0.0, tp := false) -> void:
	var d := {"p": GameBoot.b2g([x, y, z]), "cap": cap, "dwell": dwell,
			"tp": tp}
	if look != null:
		d["look"] = GameBoot.b2g(look)
	_wps.append(d)


## Stair climb waypoints straight from the shared layout model.
func _climb(stair_id: String, from_level: String, land_cap := "") -> void:
	for st in root.layout["stairs"]:
		if st["id"] != stair_id:
			continue
		var idx := -1
		for k in range(st["levels"].size()):
			if st["levels"][k][0] == from_level:
				idx = k
		if idx < 0 or idx * 3 + 2 >= st["parts"].size():
			return
		var f1: Dictionary = st["parts"][idx * 3]
		var land: Dictionary = st["parts"][idx * 3 + 1]
		var f2: Dictionary = st["parts"][idx * 3 + 2]
		var bx1: float = (f1["b0"] + f1["b1"]) / 2.0
		var bx2: float = (f2["b0"] + f2["b1"]) / 2.0
		var ly: float = (land["rect"][1] + land["rect"][3]) / 2.0
		var z0: float = f1["z0"]
		var zl: float = land["z"]
		var z1: float = f2["z0"] + f2["n"] * f2["rise"]
		_wp(bx1, f1["start"], z0 + EYE)
		_wp(bx1, ly, zl + EYE, null, land_cap, 1.5 if land_cap != "" else 0.0)
		_wp(bx2, ly, zl + EYE)
		_wp(bx2, f1["start"], z1 + EYE)
		return


func _build_path() -> void:
	_wps.clear()
	var e := {"F01": 1.62, "F02": 4.82, "F03": 8.02, "F04": 11.22,
			"F05": 14.42, "F06": 17.62, "ROOF": 20.82, "B1": -1.18}
	# street + lobby
	_wp(0, -17.5, 1.85, [0, -9.65, 6.0],
			"ORISON APARTMENTS — street elevation", 2.6)
	_wp(0, -12.0, 1.72, [0, -9.65, 2.1], "the street entry", 1.0)
	_wp(0, -9.1, e.F01)
	_wp(0.3, -8.6, e.F01, null, "the draft vestibule", 0.9)
	_wp(0.9, -7.9, e.F01, [-2.0, -7.4, 1.3],
			"LOBBY — mail wall, bench, the atrium beyond", 1.8)
	_wp(2.6, -8.5, e.F01, [4.4, -9.5, 1.1], "22 mailboxes, six floors", 1.4)
	_wp(-1.2, -8.5, e.F01, [-1.2, -5.0, 2.6], "", 0.6)
	_wp(-1.2, -5.2, e.F01, [0, -3.2, 2.4],
			"the elevator hall — every floor meets the atrium here", 1.4)
	_wp(-0.5, -2.7, e.F01, [0, 0, 8.0],
			"THE ATRIUM STAIR — one open switchback, lobby to skylight",
			2.6)
	_climb("atrium", "F01",
			"the half landing — between floors, over the eye")
	_wp(0.4, -2.7, e.F02)
	_wp(0, -5.2, e.F02)
	_wp(-4.38, -6.0, e.F02, null, "FLOOR 2 — the corridor ring", 1.0)
	_wp(-4.38, -1.65, e.F02)
	_wp(-6.2, -1.9, e.F02)
	_wp(-8.2, -2.8, e.F02, [-12.0, -4.2, 4.5],
			"2A — MINA VALE · the caption station", 2.0)
	_wp(-9.6, -4.6, e.F02, [-13.2, -5.0, 4.2], "", 1.0)
	_wp(-6.2, -1.9, e.F02)
	_wp(-4.38, -1.65, e.F02)
	_wp(-4.38, 8.55, e.F02)
	_wp(4.38, 8.55, e.F02)
	_wp(4.38, 0.32, e.F02)
	_wp(5.9, 0.4, e.F02)
	_wp(9.0, 2.0, e.F02, [12.9, 4.0, 3.9],
			"2C — JUNO KELLS · speakers everywhere", 2.0)
	_wp(5.9, 0.4, e.F02)
	_wp(4.38, -6.0, e.F02)
	_wp(0, -5.2, e.F02)
	_wp(-0.5, -2.7, e.F02)
	_climb("atrium", "F02")
	_wp(0.4, -2.7, e.F03)
	_wp(0, -5.2, e.F03)
	_wp(-4.38, 3.87, e.F03)
	_wp(-6.2, 3.87, e.F03)
	_wp(-11.0, 4.4, e.F03, [-13.0, 6.2, 7.5],
			"3B — OMAR BELL · repairs, by category", 2.0)
	_wp(-6.2, 3.87, e.F03)
	_wp(-4.38, -3.31, e.F03)
	_wp(6.0, -3.31, e.F03)
	_wp(10.0, -4.2, e.F03, [8.7, -5.3, 7.6],
			"3D — RHEA SATO · the vocal booth", 2.0)
	_wp(6.0, -3.31, e.F03)
	_wp(4.38, -6.0, e.F03)
	_wp(0, -5.2, e.F03)
	_wp(-0.5, -2.7, e.F03)
	_climb("atrium", "F03")
	_wp(0.4, -2.7, e.F04)
	_wp(0, -5.2, e.F04)
	_wp(-4.38, 3.87, e.F04, null, "FLOOR 4", 0.8)
	_wp(-6.1, 3.87, e.F04)
	_wp(-6.6, 3.95, e.F04, [-6.6, 6.2, 11.0],
			"4B — the player's studio, to the Section 4 plan", 2.0)
	_wp(-7.3, 4.35, e.F04)
	_wp(-10.2, 4.4, e.F04, [-12.8, 3.9, 10.5], "", 1.0)
	_wp(-9.2, 5.6, e.F04, [-8.05, 5.5, 10.4],
			"the workstation — Mara Chen's call arrives here", 2.4)
	_wp(-9.6, 8.5, e.F04, [-9.7, 9.35, 10.55],
			"the hero toaster — latch, coil, relay, pop", 2.0)
	_wp(-12.3, 8.0, e.F04, [-13.3, 8.2, 10.2], "the sleeping alcove", 1.2)
	_wp(-8.9, 6.5, e.F04, [-7.2, 7.05, 10.9],
			"the door anomaly wall — a seam only infection reveals", 2.4)
	_wp(-7.3, 4.2, e.F04)
	_wp(-6.1, 3.87, e.F04)
	_wp(-4.38, -6.0, e.F04)
	_wp(0, -5.2, e.F04)
	_wp(-0.5, -2.7, e.F04)
	_climb("atrium", "F04")
	_wp(0.4, -2.7, e.F05)
	_wp(0, -5.2, e.F05)
	_wp(-4.38, -1.65, e.F05)
	_wp(-6.2, -1.9, e.F05)
	_wp(-9.0, -3.4, e.F05, [-9.6, -5.0, 13.7],
			"5A — NADIA QUELL · plans over contradictory plans", 2.0)
	_wp(-6.2, -1.9, e.F05)
	_wp(-4.38, -3.31, e.F05)
	_wp(6.0, -3.31, e.F05)
	_wp(10.2, -4.6, e.F05, [9.6, -5.3, 13.4],
			"5D — fire-damaged · vacant", 1.8)
	_wp(6.0, -3.31, e.F05)
	_wp(4.38, -6.0, e.F05)
	_wp(0, -5.2, e.F05)
	_wp(-0.5, -2.7, e.F05)
	_climb("atrium", "F05")
	_wp(0.4, -2.7, e.F06)
	_wp(0, -5.2, e.F06)
	_wp(-4.38, -1.65, e.F06)
	_wp(-6.2, -1.9, e.F06)
	_wp(-9.0, -3.6, e.F06, [-13.2, -5.0, 16.9],
			"6A — SACHA REED · the three-monitor capture wall", 2.2)
	_wp(-6.2, -1.9, e.F06)
	_wp(4.6, -3.31, e.F06, [5.8, -3.31, 17.0],
			"6D — landlord storage · locked", 1.6)
	_wp(0, -5.2, e.F06)
	_wp(-0.5, -2.7, e.F06, [0, 0, 21.7],
			"six storeys of open eye, straight to the skylight", 2.0)
	_climb("atrium", "F06")
	_wp(-0.85, -2.9, e.ROOF, null,
			"the roof door — the atrium monitor", 1.2)
	_wp(-0.85, -4.6, e.ROOF)
	_wp(-4.5, 5.2, e.ROOF, [-8.0, 6.0, 20.6],
			"ROOF — the water tank, the parapet", 2.2)
	_wp(-8.0, -8.3, e.ROOF, [-8.0, -18.0, 19.5], "the street below", 1.8)
	# basement, by fade
	_wp(4.38, -5.0, e.B1, null, "BASEMENT", 1.2, true)
	_wp(4.38, 4.385, e.B1)
	_wp(6.2, 4.385, e.B1)
	_wp(9.0, 3.4, e.B1, [10.4, 5.2, -1.9],
			"the boiler — the conductor's default origin", 2.4)
	_wp(6.2, 4.385, e.B1)
	_wp(-4.38, 6.16, e.B1, null, "", 0.0, true)
	_wp(-6.2, 6.16, e.B1)
	_wp(-10.4, 5.2, e.B1, [-11.6, 5.0, -1.9],
			"LAUNDRY — washers on the water network", 2.0)
	_wp(-8.0, 5.2, e.B1, [-5.0, 0.5, -0.4],
			"heating headers run the spine of the building", 2.0)
	# home: back to the lobby, tour ends
	_wp(0, -8.4, e.F01, [0, -5.0, 2.4],
			"WALKTHROUGH COMPLETE", 2.2, true)
