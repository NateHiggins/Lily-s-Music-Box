class_name ServiceSetProp
extends Node3D
## The carried Vantry Model No. 4 service radiophone.  This is a physical
## instrument, not a phone with its screen removed: speaker, carbon mouthpiece,
## aerial, PTT, lamp and three single-purpose incandescent jewels are the whole
## grammar.

const DEVICE_LAYER := 2
const BODY := Vector3(0.085, 0.225, 0.058)
## The inspection beam leaves the attached lamp down local -Z.
const LAMP_AT := Vector3(-0.026, 0.116, -0.078)

const PHENOLIC := Color("211711")
const PHENOLIC_EDGE := Color("35251a")
const BLACKENED := Color("24211d")
const BRASS := Color("79623a")
const BRASS_WORN := Color("a58b58")
const CERAMIC := Color("d3c7a7")
const GLASS_DARK := Color("160f0a")
const AMBER := Color("ff9d24")
const GREEN := Color("65d07d")
const RED := Color("e35a42")
const LAMP_WARM := Color("ffd08a")

var radio_powered := true
var lamp_enabled := true
var order_open := false
var incoming_call := false

var _work_orders: WorkOrders
var _aerial: Node3D
var _lamp_lever: Node3D
var _order_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _lamp_indicator_material: StandardMaterial3D
var _lamp_glass_material: StandardMaterial3D
var _receipt_root: Node3D
var _receipt_label: Label3D
var _receipt_tween: Tween
var _printer_tick: AudioStreamPlayer
var _printer_feed: AudioStreamPlayer
var printed_count := 0


func _ready() -> void:
	_build_model()
	_isolate_meshes(self)
	_apply_state(false)


func bind_work_orders(orders: WorkOrders) -> void:
	_work_orders = orders
	if _work_orders == null:
		return
	if not _work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		_work_orders.job_stage_changed.connect(_on_job_stage_changed)
	if not _work_orders.order_issued.is_connected(_on_simple_order_changed):
		_work_orders.order_issued.connect(_on_simple_order_changed)
	if not _work_orders.order_activated.is_connected(_on_simple_order_changed):
		_work_orders.order_activated.connect(_on_simple_order_changed)
	if not _work_orders.order_closed.is_connected(_on_simple_order_changed):
		_work_orders.order_closed.connect(_on_simple_order_changed)
	if not RealityState.state_changed.is_connected(_refresh_order):
		RealityState.state_changed.connect(_refresh_order)
	_refresh_order()


func set_radio_powered(on: bool, animate := true) -> void:
	if radio_powered == on and _aerial != null:
		_apply_state(animate)
		return
	radio_powered = on
	_apply_state(animate)


func toggle_radio_power() -> void:
	set_radio_powered(not radio_powered)


func set_incoming_call(waiting: bool) -> void:
	incoming_call = waiting
	if _receipt_root and _receipt_label:
		if waiting:
			if _receipt_tween:
				_receipt_tween.kill()
			_receipt_label.text = "LINE REQUEST\nL. ORTIZ · 2B\nPRESS R"
			_receipt_root.scale.y = 1.0
			_receipt_root.visible = true
		else:
			_receipt_root.visible = false
	_apply_state(false)


## A powered set advances one physical field slip. The HUD enlarges the same
## copy for legibility; this modeled paper is the fiction, not a hidden screen.
func print_telegram_card(title: String) -> bool:
	if not radio_powered or _receipt_root == null:
		return false
	printed_count += 1
	# TelegramStyle.fit_slip stops at a word boundary instead of wherever
	# sixteen characters happen to land; a slip that ends on a dangling
	# em-dash reads as a bug rather than as a short strip of paper.
	_receipt_label.text = "WIRE %04d\n%s" % [printed_count,
			TelegramStyle.fit_slip(title.to_upper())]
	if _receipt_tween:
		_receipt_tween.kill()
	_receipt_root.visible = true
	_receipt_root.scale.y = 0.025
	if _printer_tick and _printer_tick.stream:
		_printer_tick.play()
	_receipt_tween = create_tween()
	_receipt_tween.tween_property(_receipt_root, "scale:y", 1.0,
			0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_receipt_tween.tween_callback(_play_feed)
	_receipt_tween.tween_interval(2.35)
	_receipt_tween.tween_property(_receipt_root, "scale:y", 0.025,
			0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_receipt_tween.tween_callback(func(): _receipt_root.visible = false)
	return true


func _play_feed() -> void:
	if _printer_feed and _printer_feed.stream:
		_printer_feed.play()


func set_lamp_enabled(on: bool, animate := true) -> void:
	if lamp_enabled == on and _lamp_lever != null:
		_apply_state(animate)
		return
	lamp_enabled = on
	_apply_state(animate)


func _on_job_stage_changed(_job_id: String, _from_stage: String,
		_to_stage: String, _state: Dictionary) -> void:
	_refresh_order()


func _on_simple_order_changed(_order_id: String, _order: Dictionary) -> void:
	_refresh_order()


func _refresh_order() -> void:
	order_open = _work_orders != null and _work_orders.has_open_work()
	_apply_state(false)


func _apply_state(animate: bool) -> void:
	_set_jewel(_order_material, AMBER,
			(order_open or incoming_call) and radio_powered,
			1.65 if incoming_call else 1.25)
	_set_jewel(_net_material, GREEN, radio_powered, 0.82)
	_set_jewel(_lamp_indicator_material, RED, lamp_enabled, 0.82)
	_set_jewel(_lamp_glass_material, LAMP_WARM, lamp_enabled, 2.1)
	if _aerial:
		var aerial_y := 1.0 if radio_powered else 0.14
		if animate and is_inside_tree():
			create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(
					Tween.EASE_OUT).tween_property(_aerial, "scale:y",
					aerial_y, 0.28)
		else:
			_aerial.scale.y = aerial_y
	if _lamp_lever:
		var angle := deg_to_rad(-24.0 if lamp_enabled else 24.0)
		if animate and is_inside_tree():
			create_tween().set_trans(Tween.TRANS_BACK).tween_property(
					_lamp_lever, "rotation:z", angle, 0.16)
		else:
			_lamp_lever.rotation.z = angle


func _set_jewel(material: StandardMaterial3D, color: Color, on: bool,
		energy: float) -> void:
	if material == null:
		return
	material.albedo_color = color if on else GLASS_DARK
	material.emission_enabled = on
	material.emission = color
	material.emission_energy_multiplier = energy if on else 0.0


func _build_model() -> void:
	# TYPE 28-R, phase 1: the five silhouette landmarks and the construction
	# that makes them credible before any supernatural system is added. The
	# long chassis is still oriented along local Y so the established carried
	# pose and the real beam owner remain unchanged.
	var japan := _mat(Color("302a22"), 0.34, 0.38)
	var japan_edge := _mat(Color("44382c"), 0.42, 0.34)
	var phenolic := _mat(Color("5a3527"), 0.56)
	var phenolic_worn := _mat(Color("744a37"), 0.43)
	var nickel := _mat(Color("a7a29a"), 0.26, 0.88)
	var brass := _mat(Color("765c31"), 0.39, 0.82)
	var brass_worn := _mat(Color("b29255"), 0.29, 0.86)
	var steel := _mat(Color("4e4d49"), 0.31, 0.91)
	var ceramic := _mat(Color("d8ccb0"), 0.70)
	var paper := _mat(Color("d7c99f"), 0.84)
	var ink := _mat(Color("17130e"), 0.78)
	var leather := _mat(Color("6b4228"), 0.76)
	var copper := _mat(Color("8d4e2e"), 0.31, 0.86)
	var glass := _mat(Color(0.58, 0.62, 0.60, 0.32), 0.09)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := _mat(Color("18140f"), 0.82)

	# Genuine frame, three separate shell plates and exposed dark seams.
	var chassis := Node3D.new()
	chassis.name = "HistoricalChassis"
	add_child(chassis)
	_box(Vector3(0.098, 0.316, 0.070), Vector3(0, -0.006, 0), dark, chassis)
	_box(Vector3(0.104, 0.091, 0.076), Vector3(0, 0.086, 0), japan,
			chassis).name = "InstrumentPlate"
	_box(Vector3(0.104, 0.080, 0.076), Vector3(0, -0.012, 0), japan_edge,
			chassis).name = "ControlPlate"
	_box(Vector3(0.104, 0.104, 0.080), Vector3(0, -0.108, 0), japan,
			chassis).name = "BatteryServicePlate"
	for y in [-0.058, 0.036]:
		_box(Vector3(0.108, 0.003, 0.082), Vector3(0, y, 0), dark, chassis)
	for x in [-0.054, 0.054]:
		_box(Vector3(0.007, 0.304, 0.071), Vector3(x, -0.006, 0), brass,
				chassis)

	# Coherent 1928 hardware: slotted screws, washers and two captive thumbs.
	var fasteners := Node3D.new()
	fasteners.name = "PeriodFasteners"
	add_child(fasteners)
	for x in [-0.043, 0.043]:
		for y in [-0.145, -0.096, -0.049, 0.044, 0.104, 0.141]:
			var washer := _cyl(0.0041, 0.0014, Vector3(x, y, -0.041), brass,
					Vector3.UP, fasteners)
			washer.rotation.x = PI * 0.5
			var screw := _cyl(0.0028, 0.0018, Vector3(x, y, -0.042), steel,
					Vector3.UP, fasteners)
			screw.rotation.x = PI * 0.5
			_box(Vector3(0.0040, 0.00065, 0.0007),
					Vector3(x, y, -0.0431), dark, fasteners).rotation.z = \
					deg_to_rad(18.0 if y > 0.0 else -11.0)

	# Landmark 1: faceted focusing lamp, with actual lens, retaining ring,
	# reflector, filament support and a bracket into the chassis.
	var lamp := Node3D.new()
	lamp.name = "LampBezelLandmark"
	add_child(lamp)
	_box(Vector3(0.060, 0.050, 0.020), Vector3(-0.026, 0.116, -0.043),
			brass, lamp)
	for spec in [[0.049, 0.021, nickel], [0.042, 0.025, brass_worn],
			[0.035, 0.029, dark]]:
		var ring := _cyl(float(spec[0]), float(spec[1]),
				Vector3(-0.026, 0.116, -0.058), spec[2], Vector3.UP, lamp)
		ring.rotation.x = PI * 0.5
		(ring.mesh as CylinderMesh).radial_segments = 8
	var reflector := _cyl(0.030, 0.010, Vector3(-0.026, 0.116, -0.070),
			nickel, Vector3.UP, lamp)
	reflector.rotation.x = PI * 0.5
	_lamp_glass_material = _jewel_material()
	var lens := _cyl(0.033, 0.0035, LAMP_AT, _lamp_glass_material,
			Vector3.UP, lamp)
	lens.rotation.x = PI * 0.5
	var bulb := _sphere(0.006, Vector3(-0.026, 0.116, -0.069), glass, lamp)
	_box(Vector3(0.0011, 0.007, 0.0011), Vector3(-0.026, 0.116, -0.075),
			copper, lamp)
	_label("FOCUS  <-  ->", Vector3(-0.026, 0.159, -0.061), 0.00019,
			Color("21170d"), true, Vector3.ZERO, lamp)

	# Landmark 2: a Weston-like arched instrument, mechanically layered from
	# housing to paper scale to pointer and calibration jewel.
	var meter := Node3D.new()
	meter.name = "ArchedMeterLandmark"
	add_child(meter)
	_box(Vector3(0.086, 0.071, 0.020), Vector3(0.007, 0.047, -0.046),
			phenolic, meter)
	var meter_crown := _cyl(0.043, 0.020, Vector3(0.007, 0.081, -0.046),
			phenolic, Vector3.UP, meter)
	meter_crown.rotation.x = PI * 0.5
	_box(Vector3(0.074, 0.052, 0.002), Vector3(0.007, 0.054, -0.058),
			paper, meter)
	for tick in range(13):
		var a := lerpf(-1.05, 1.05, float(tick) / 12.0)
		var p := Vector3(0.007 + sin(a) * 0.029,
				0.047 + cos(a) * 0.023, -0.0595)
		var mark := _box(Vector3(0.0010, 0.006 if tick % 3 == 0 else 0.0035,
				0.0008), p, ink, meter)
		mark.rotation.z = -a
	var needle := _box(Vector3(0.0012, 0.030, 0.001),
			Vector3(0.007, 0.052, -0.061), ink, meter)
	needle.rotation.z = deg_to_rad(-14.0)
	_sphere(0.0042, Vector3(0.007, 0.038, -0.062), brass_worn, meter)
	_label("ORISON  28-R\nLINE  CONT.  BATT.  FIELD", Vector3(0.007, 0.061,
			-0.061), 0.00013, Color("17130e"), true, Vector3.ZERO, meter)

	# Landmark 3: detector glass and ordinary galena. Its impossible third
	# position belongs to TL-6; this first phase stays museum-plausible.
	var detector := Node3D.new()
	detector.name = "DetectorDomeLandmark"
	add_child(detector)
	_cyl(0.019, 0.008, Vector3(0.035, 0.119, -0.042), brass,
			Vector3.UP, detector).rotation.x = PI * 0.5
	_sphere(0.015, Vector3(0.035, 0.119, -0.057), glass, detector)
	var galena := _sphere(0.007, Vector3(0.035, 0.119, -0.058), steel, detector)
	galena.scale = Vector3(1.0, 0.72, 0.82)
	var whisker := _cyl(0.0007, 0.022, Vector3(0.029, 0.123, -0.066),
			brass_worn, Vector3.UP, detector)
	whisker.rotation.z = deg_to_rad(32.0)
	_label("DETECTOR", Vector3(0.035, 0.095, -0.043), 0.00014,
			Color("c8ad70"), true, Vector3.ZERO, detector)

	# Landmark 4: rear dry-cell/service mass with a separate cap, spring clips
	# and a hand-crank boss. It reads heavier than the instrument face.
	var battery := Node3D.new()
	battery.name = "BatteryMassLandmark"
	add_child(battery)
	_box(Vector3(0.116, 0.091, 0.090), Vector3(0, -0.121, 0), japan_edge,
			battery)
	_box(Vector3(0.108, 0.012, 0.096), Vector3(0, -0.168, 0), brass,
			battery)
	for x in [-0.047, 0.047]:
		_box(Vector3(0.008, 0.035, 0.006), Vector3(x, -0.124, -0.049),
				steel, battery)
	var crank_boss := _cyl(0.013, 0.010, Vector3(0.061, -0.118, 0), brass,
			Vector3.UP, battery)
	crank_boss.rotation.z = PI * 0.5
	_label("DRY CELL No. 6\nSERVICE CAP", Vector3(0, -0.126, -0.047),
			0.00017, Color("c8ad70"), true, Vector3.ZERO, battery)

	# Landmark 5: physical telegram throat, platen, paper and tear edge.
	var printer := Node3D.new()
	printer.name = "TelegramSlotLandmark"
	add_child(printer)
	_box(Vector3(0.078, 0.023, 0.013), Vector3(-0.005, -0.060, -0.047),
			brass_worn, printer)
	_box(Vector3(0.061, 0.004, 0.007), Vector3(-0.005, -0.052, -0.055),
			dark, printer)
	for tooth in range(10):
		_box(Vector3(0.002, 0.004, 0.003),
				Vector3(-0.032 + tooth * 0.006, -0.040, -0.054), steel,
				printer).rotation.z = deg_to_rad(18.0)
	_label("TELEGRAM", Vector3(-0.005, -0.076, -0.055), 0.00018,
			Color("21170d"), true, Vector3.ZERO, printer)

	# Instrument/service asymmetry: selector and tuning controls on one side;
	# lead terminals and a screwed access panel on the other.
	var controls := Node3D.new()
	controls.name = "InstrumentSideControls"
	add_child(controls)
	for spec in [[-0.031, 0.019], [0.009, 0.015]]:
		var knob := _cyl(float(spec[1]), 0.012,
				Vector3(0.059, float(spec[0]), -0.010), phenolic_worn,
				Vector3.UP, controls)
		knob.rotation.z = PI * 0.5
	for y in [-0.030, 0.010]:
		_cyl(0.008, 0.014, Vector3(-0.059, y, 0.010), ceramic,
				Vector3.UP, controls).rotation.z = PI * 0.5
		_cyl(0.004, 0.018, Vector3(-0.066, y, 0.010), brass_worn,
				Vector3.UP, controls).rotation.z = PI * 0.5

	# The opposite face is a service side, not the blank back of a prop. A
	# removable plate exposes period point-to-point construction through two
	# mica windows, with line posts and a serialized maker plate around it.
	var service := Node3D.new()
	service.name = "ServiceSideAssembly"
	add_child(service)
	_box(Vector3(0.086, 0.174, 0.006), Vector3(0, -0.005, 0.049),
			japan_edge, service).name = "ServiceAccessPlate"
	for x in [-0.035, 0.035]:
		for y in [-0.076, 0.066]:
			var service_screw := _cyl(0.0032, 0.002, Vector3(x, y, 0.053),
					brass_worn, Vector3.UP, service)
			service_screw.rotation.x = PI * 0.5
			_box(Vector3(0.004, 0.0006, 0.0006), Vector3(x, y, 0.0542),
					dark, service).rotation.z = deg_to_rad(24.0)
	for x in [-0.022, 0.022]:
		_box(Vector3(0.032, 0.054, 0.002), Vector3(x, 0.022, 0.053),
				dark, service)
		for turn in range(5):
			var coil := _torus(0.009 + float(turn) * 0.0012, 0.0010,
					Vector3(x, 0.013 + float(turn) * 0.007, 0.055), copper,
					Vector3.RIGHT)
			coil.name = "LacqueredCoil"
	for x in [-0.026, 0.026]:
		_cyl(0.008, 0.006, Vector3(x, -0.058, 0.055), ceramic,
				Vector3.UP, service).rotation.x = PI * 0.5
		_cyl(0.004, 0.009, Vector3(x, -0.058, 0.060), brass_worn,
				Vector3.UP, service).rotation.x = PI * 0.5
	_label("ORISON ELECTRICAL & SIGNAL WORKS\nLONG ISLAND CITY, N.Y.\nTYPE 28-R  SERIAL 1847",
			Vector3(0, -0.101, 0.056), 0.00012, Color("c8ad70"), false,
			Vector3.ZERO, service)

	# The established production states remain physically represented.
	_order_material = _jewel_material()
	_net_material = _jewel_material()
	_lamp_indicator_material = _jewel_material()
	for spec in [["ORDER", -0.030, AMBER, _order_material],
			["NET", 0.0, GREEN, _net_material],
			["LAMP", 0.030, RED, _lamp_indicator_material]]:
		_sphere(0.0048, Vector3(float(spec[1]), -0.091, -0.048), spec[3])
		_label(str(spec[0]), Vector3(float(spec[1]), -0.102, -0.049),
				0.00012, Color("c8ad70"), true)

	_receipt_root = Node3D.new()
	_receipt_root.name = "FieldSlip"
	_receipt_root.position = Vector3(-0.005, -0.050, -0.057)
	_receipt_root.visible = false
	add_child(_receipt_root)
	_box(Vector3(0.058, 0.068, 0.0007), Vector3(0, 0.034, 0), paper,
			_receipt_root)
	_receipt_label = _label("WIRE 0000", Vector3(0, 0.031, -0.0012),
			0.00019, Color("261f19"), true, Vector3.ZERO, _receipt_root)

	_printer_tick = AudioStreamPlayer.new()
	_printer_tick.stream = PropAudio.get_stream("tick")
	_printer_tick.volume_db = -13.0
	add_child(_printer_tick)
	_printer_feed = AudioStreamPlayer.new()
	_printer_feed.stream = PropAudio.get_stream("pop")
	_printer_feed.volume_db = -18.0
	_printer_feed.pitch_scale = 1.7
	add_child(_printer_feed)

	# Existing radio switch contract, now expressed as a period pull aerial.
	_cyl(0.009, 0.010, Vector3(-0.040, 0.157, 0.010), ceramic, Vector3.UP)
	_aerial = Node3D.new()
	_aerial.name = "PowerAerial"
	_aerial.position = Vector3(-0.040, 0.159, 0.010)
	add_child(_aerial)
	for i in 4:
		var length := 0.072
		var radius := 0.0032 - float(i) * 0.00052
		_cyl(radius, length, Vector3(0, length * (float(i) + 0.5), 0),
				nickel, Vector3.UP, _aerial)
	_sphere(0.005, Vector3(0, 0.270, 0), phenolic, _aerial)

	_lamp_lever = Node3D.new()
	_lamp_lever.name = "LampLever"
	_lamp_lever.position = Vector3(0.061, 0.102, 0.010)
	add_child(_lamp_lever)
	_box(Vector3(0.004, 0.026, 0.006), Vector3(0, 0.011, 0), brass_worn,
			_lamp_lever)
	_cyl(0.005, 0.008, Vector3.ZERO, phenolic, Vector3.UP, _lamp_lever)

	# Underside hand cradle and two folded lead runs establish weight and use.
	_box(Vector3(0.074, 0.155, 0.012), Vector3(0, -0.028, 0.041), leather)
	for x in [-0.031, 0.031]:
		_box(Vector3(0.009, 0.124, 0.010), Vector3(x, -0.030, 0.058),
				_mat(Color("3b3027"), 0.88))


func _build_legacy_model() -> void:
	# The isolated pass already supplies wear through light and silhouette. The
	# building material atlas is calibrated for metre-scale appliances and
	# crushed this 85 mm case to featureless black, so the carried prop uses
	# honest small-object colors here instead of sampling a wall-sized texel.
	var phenolic := _mat(Color("613b28"), 0.54)
	var edge := _mat(Color("7a5035"), 0.48)
	var black := _mat(Color("39332d"), 0.50, 0.18)
	var brass := _mat(Color("927440"), 0.44, 0.54)
	var worn_brass := _mat(Color("c3a66a"), 0.38, 0.62)
	var ceramic := _mat(CERAMIC, 0.76)
	var grille := _mat(Color("100d0b"), 0.84)
	var paper := _mat(Color("b8a77f"), 0.88)
	var telegram_paper := _mat(Color.WHITE, 0.96)
	telegram_paper.albedo_texture = load(
			"res://assets/ui/telegram/telegram_paper_stock_v1.png")
	telegram_paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	# Compression-moulded case, raised end caps and the screwed rear hatch.
	_box(BODY, Vector3.ZERO, phenolic)
	_box(Vector3(0.090, 0.014, 0.063), Vector3(0, 0.105, 0), edge)
	_box(Vector3(0.090, 0.014, 0.063), Vector3(0, -0.105, 0), edge)
	_box(Vector3(0.070, 0.137, 0.003), Vector3(0, -0.012, 0.0305), black)
	for x in [-0.031, 0.031]:
		for y in [-0.073, 0.049]:
			_cyl(0.0031, 0.0025, Vector3(x, y, 0.033), worn_brass,
					Vector3.RIGHT)

	# FRONT, away from the hand: receiver, carbon mouthpiece and ORDER.
	var front_z := -BODY.z * 0.5 - 0.002
	_cyl(0.031, 0.004, Vector3(0, 0.058, front_z), grille,
			Vector3.RIGHT)
	for radius in [0.030, 0.022, 0.014]:
		_torus(radius, 0.0015, Vector3(0, 0.058, front_z - 0.003), brass,
				Vector3.RIGHT)
	for row in range(-2, 3):
		for col in range(-2, 3):
			if Vector2(row, col).length() <= 2.35:
				_cyl(0.0015, 0.003, Vector3(col * 0.009, 0.058 + row * 0.009,
						front_z - 0.004), black, Vector3.RIGHT)
	_cyl(0.014, 0.004, Vector3(0, -0.058, front_z), grille,
			Vector3.RIGHT)
	for a in range(8):
		var theta := TAU * float(a) / 8.0
		_cyl(0.0012, 0.003, Vector3(cos(theta) * 0.008,
				-0.058 + sin(theta) * 0.008, front_z - 0.003), black,
				Vector3.RIGHT)
	_order_material = _jewel_material()
	_sphere(0.0062, Vector3(0, -0.010, front_z - 0.002), _order_material)
	_label("ORDER", Vector3(0, -0.024, front_z - 0.003), 0.00042,
			Color("cfb77a"), true)

	# Rebuild and maker plates; large enough to read only in a proof close-up.
	_box(Vector3(0.060, 0.027, 0.002), Vector3(0, -0.091,
			front_z - 0.001), brass)
	_label("VANTRY & CO.\nMODEL No. 4", Vector3(0, -0.089,
			front_z - 0.003), 0.00027, Color("21170d"), true)

	# The 1940s service-wire modification: a narrow platen slot in the crown.
	# It emits paper, never pixels. A slip rises into the carrier's view after
	# an object has already answered the hand.
	_box(Vector3(0.069, 0.008, 0.006), Vector3(0, 0.111,
			front_z - 0.003), worn_brass)
	_box(Vector3(0.054, 0.002, 0.007), Vector3(0, 0.113,
			front_z - 0.006), grille)
	_label("WIRE", Vector3(0.015, 0.103, front_z - 0.007), 0.00025,
			Color("21170d"), true)
	_receipt_root = Node3D.new()
	_receipt_root.name = "FieldSlip"
	_receipt_root.position = Vector3(0, 0.114, front_z - 0.009)
	_receipt_root.visible = false
	add_child(_receipt_root)
	_box(Vector3(0.058, 0.068, 0.0007), Vector3(0, 0.034, 0),
			telegram_paper, _receipt_root)
	_receipt_label = _label("WIRE 0000", Vector3(0, 0.031, -0.0012),
			0.00019, Color("261f19"), true, Vector3.ZERO, _receipt_root)
	_printer_tick = AudioStreamPlayer.new()
	_printer_tick.stream = PropAudio.get_stream("tick")
	_printer_tick.volume_db = -13.0
	add_child(_printer_tick)
	_printer_feed = AudioStreamPlayer.new()
	_printer_feed.stream = PropAudio.get_stream("pop")
	_printer_feed.volume_db = -18.0
	_printer_feed.pitch_scale = 1.7
	add_child(_printer_feed)

	# BACK, facing the carrier: a later linesman's modification. NET tells the
	# worker that the aerial really closed the radio circuit; LAMP confirms the
	# forward-facing bulb they cannot see from behind.
	var back_z := BODY.z * 0.5 + 0.003
	_net_material = _jewel_material()
	_lamp_indicator_material = _jewel_material()
	for spec in [
		["NET", -0.019, GREEN, _net_material],
		["LAMP", 0.019, RED, _lamp_indicator_material],
	]:
		_sphere(0.0053, Vector3(float(spec[1]), 0.051, back_z), spec[3])
		_label(str(spec[0]), Vector3(float(spec[1]), 0.036, back_z + 0.002),
				0.00034, Color("c7b47f"), false)
	_label("1924 REBUILD", Vector3(0, -0.071, back_z + 0.002), 0.00028,
			Color("c7b47f"), false)
	# Pasted circuit card beneath the service cover's lower window.
	_box(Vector3(0.050, 0.034, 0.0015), Vector3(0, -0.039, back_z), paper)
	for y in [-0.048, -0.040, -0.032]:
		_box(Vector3(0.039, 0.0008, 0.001), Vector3(0, y, back_z + 0.002),
				brass)

	# Attached tungsten work lamp. The broad barrel, glass and bracket make
	# LAMP_AT visually true rather than a spotlight emitted by empty air.
	_box(Vector3(0.018, 0.035, 0.016), Vector3(0.036, 0.076, -0.023), brass)
	var barrel := _cyl(0.022, 0.082, Vector3(0.054, 0.070, -0.073), black,
			Vector3.RIGHT)
	barrel.rotation.x = PI * 0.5
	var reflector := _cyl(0.025, 0.018, Vector3(0.054, 0.070, -0.109),
			worn_brass, Vector3.RIGHT)
	reflector.rotation.x = PI * 0.5
	_lamp_glass_material = _jewel_material()
	var lens := _cyl(0.021, 0.004, LAMP_AT, _lamp_glass_material,
			Vector3.RIGHT)
	lens.rotation.x = PI * 0.5

	# Pull aerial, ceramic feed-through and nested brass tubes. The pivot is at
	# the case shoulder so collapsing scale visibly pushes it home.
	_cyl(0.010, 0.012, Vector3(-0.026, 0.116, 0.010), ceramic, Vector3.UP)
	_aerial = Node3D.new()
	_aerial.name = "PowerAerial"
	_aerial.position = Vector3(-0.026, 0.118, 0.010)
	add_child(_aerial)
	for i in 4:
		var length := 0.096
		var radius := 0.0034 - float(i) * 0.00055
		_cyl(radius, length, Vector3(0, length * (float(i) + 0.5), 0),
				worn_brass, Vector3.UP, _aerial)
	_sphere(0.006, Vector3(0, 0.402, 0), black, _aerial)

	# Tactile controls. PTT is broad and protected; the lamp switch has only
	# the owner-ruled OFF/ON detent. A fluted volume wheel sits on the crown.
	_box(Vector3(0.006, 0.064, 0.026), Vector3(-0.046, 0.008, 0.002), black)
	_label("PTT", Vector3(-0.050, 0.008, 0.017), 0.00030,
			Color("b29b6d"), false, Vector3(0, -90, 0))
	_lamp_lever = Node3D.new()
	_lamp_lever.name = "LampLever"
	_lamp_lever.position = Vector3(0.048, -0.055, 0.003)
	add_child(_lamp_lever)
	_box(Vector3(0.004, 0.030, 0.005), Vector3(0, 0.012, 0), worn_brass,
			_lamp_lever)
	_cyl(0.005, 0.008, Vector3.ZERO, black, Vector3.UP, _lamp_lever)
	_cyl(0.014, 0.010, Vector3(0.022, 0.112, 0.005), black, Vector3.UP)
	for notch in range(10):
		var a := TAU * float(notch) / 10.0
		_box(Vector3(0.002, 0.011, 0.003), Vector3(0.022 + cos(a) * 0.013,
				0.112, 0.005 + sin(a) * 0.013), worn_brass)

	# A repaired cotton-and-leather carrying strap: two short visible runs are
	# enough in first person; it never pretends to be tactical webbing.
	_box(Vector3(0.010, 0.170, 0.009), Vector3(-0.054, -0.010, 0.017),
			MatLib.get_mat("rubber_aged", Color("6d5845"), 0.32))
	_box(Vector3(0.020, 0.052, 0.012), Vector3(-0.055, 0.006, 0.017),
			_mat(Color("4a2f1d"), 0.88))


func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _jewel_material() -> StandardMaterial3D:
	var material := _mat(GLASS_DARK, 0.20)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.96
	return material


func _box(size: Vector3, at: Vector3, material: Material,
		parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cyl(radius: float, height: float, at: Vector3, material: Material,
		_axis: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _sphere(radius: float, at: Vector3, material: Material,
		parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _torus(radius: float, tube: float, at: Vector3, material: Material,
		_axis: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 20
	mesh.ring_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation.x = PI * 0.5
	node.material_override = material
	add_child(node)
	return node


func _label(value: String, at: Vector3, pixel: float, color: Color,
		front_face: bool, rotation_degrees := Vector3.ZERO,
		parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = value
	TelegramStyle.apply_world(label, true)
	label.font_size = 32
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = at
	label.rotation_degrees = rotation_degrees + (Vector3(0, 180, 0)
			if front_face else Vector3.ZERO)
	parent.add_child(label)
	return label


func _isolate_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).layers = 1 << (DEVICE_LAYER - 1)
	for child in node.get_children():
		_isolate_meshes(child)
