class_name VantryPointProp
extends FunctionalProp
## A 1912 Vantry listening head: fire detector, flood witness, house ear.
##
## The broad saucer is 230 mm across because it has to read as installed
## apparatus from a five-foot worker's eye, not as the white modern cube this
## replaces.  The grille is the service part.  Turn it and the object answers
## the battery joke with a carbon capsule, two terminals and no battery bay.

signal inspected(point_id: String)

const BAKELITE := Color(0.141, 0.125, 0.114)
const BRASS := Color(0.416, 0.322, 0.157)
const COPPER := Color(0.55, 0.33, 0.21)
const CLOTH := Color(0.86, 0.85, 0.81)
const RED := Color(0.878, 0.18, 0.12)

var point_id := ""
var room_id := ""
var work_orders: WorkOrders
var chirp_hunt: ChirpHunt
var _repaired := false
var _body: Node3D
var _grille: Node3D
var _telltale: MeshInstance3D
var _grille_open := 0.0
var _grille_tween: Tween
var _haunt_tween: Tween


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "Vantry point / 1912 listening head"}]


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "FixedBackplateAndCapsule"
	add_child(_body)
	# Two shallow steps make moulded phenolic read as a screwed ceiling saucer,
	# while the dark diaphragm behind the openings gives the brass a real job.
	_cyl(_body, 0.115, 0.115, 0.026, Vector3(0, -0.013, 0), BAKELITE)
	_cyl(_body, 0.103, 0.109, 0.028, Vector3(0, -0.036, 0), BAKELITE)
	_cyl(_body, 0.072, 0.072, 0.010, Vector3(0, -0.052, 0), BAKELITE)
	# Three service screws and two terminals survive when the face comes down.
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		_cyl(_body, 0.007, 0.007, 0.006,
				Vector3(sin(angle) * 0.092, -0.052,
						cos(angle) * 0.092), BRASS)
	for x in [-0.027, 0.027]:
		_cyl(_body, 0.010, 0.010, 0.015,
				Vector3(x, -0.063, 0.010), BRASS)
	# The plaster has let go around enough heads to expose a few inches of the
	# woven pair. It carries signal, so the 1912 installation is allowed to be
	# unnervingly competent; its insulation is still only cloth and copper.
	var flex := _cyl(_body, 0.006, 0.006, 0.11,
			Vector3(0.145, -0.006, 0), CLOTH)
	flex.rotation_degrees.z = 90.0
	var conductor := _cyl(_body, 0.003, 0.003, 0.045,
			Vector3(0.087, -0.023, 0.010), COPPER)
	conductor.rotation_degrees.z = 42.0

	_grille = Node3D.new()
	_grille.name = "CaptiveGrille"
	add_child(_grille)
	_ring(_grille, 0.078, 0.009, Vector3(0, -0.066, 0), BRASS)
	# Twelve spokes make twelve actual openings. A normal-map dot pattern on a
	# solid disc looked perforated in source and opaque in the room.
	for i in 12:
		var spoke := _box(_grille, Vector3(0.010, 0.007, 0.062),
				Vector3(0, -0.066, 0), BRASS)
		spoke.rotation.y = i * TAU / 12.0
	_cyl(_grille, 0.018, 0.018, 0.010, Vector3(0, -0.067, 0), BRASS)

	# A mechanical enamel flag behind a pinhole. Teresa's point closes it
	# before she stops speaking; no semiconductor LED is smuggled into 1912.
	_telltale = _cyl(self, 0.009, 0.009, 0.006,
			Vector3(0.065, -0.070, 0.010), RED)

	retexture(self, [
		[BAKELITE, "bakelite_black", Color(0.72, 0.65, 0.58), 0.42],
		[BRASS, "brass_mesh", Color(0.78, 0.70, 0.52), 0.50],
		[COPPER, "copper_aged", Color(0.72, 0.64, 0.52), 0.38],
		# ``linen`` intentionally stays on the older library path. It is in
		# MatLib.SETS and must not acquire a dead GODOT_STAGE twin.
		[CLOTH, "linen", Color(0.38, 0.30, 0.23), 0.20],
		[RED, "indicator_enamel", Color(0.72, 0.28, 0.20), 0.35],
	])
	merge_static(_body)
	merge_static(_grille)
	_build_service_area()


func _start_normal_function() -> void:
	# ChirpHunt, through WorkOrders, is the sole normal-function owner. Starting
	# a timer here made every distributed point claim to have a dead battery.
	state = PState.IDLE


func bind_order_spine(spine: WorkOrders) -> void:
	work_orders = spine


func bind_chirp_hunt(hunt: ChirpHunt) -> void:
	chirp_hunt = hunt


func play_chirp(strength := 1.0) -> void:
	# ChirpHunt decides when a chirp is due; the prop only refuses to voice
	# a fault its own mechanism has already repaired. AudioPolicy owns only
	# presentation competition; this physical point remains the source owner.
	if not _repaired:
		AudioPolicy.present_3d(&"nav.vantry_fault", global_position,
				clampf(strength, 0.0, 1.0), StringName(point_id))


func set_chirping(enabled: bool) -> void:
	state = PState.OPERATING if enabled else PState.IDLE
	if not enabled:
		AudioPolicy.stop_source(StringName(point_id), &"nav.vantry_fault")


func set_grille_open(amount: float, seconds := 0.45) -> void:
	_grille_open = clampf(amount, 0.0, 1.0)
	if _grille_tween and _grille_tween.is_valid():
		_grille_tween.kill()
	var target_y := -0.050 * _grille_open
	var target_turn := deg_to_rad(20.0) * _grille_open
	if seconds <= 0.0:
		_grille.position.y = target_y
		_grille.rotation.y = target_turn
		return
	_grille_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_grille_tween.tween_property(_grille, "position:y", target_y, seconds)
	_grille_tween.parallel().tween_property(_grille, "rotation:y",
			target_turn, seconds)


func set_telltale_closed(closed: bool) -> void:
	if _telltale:
		_telltale.position.x = 0.045 if closed else 0.065
		_telltale.visible = not closed


func set_service_pose() -> void:
	set_grille_open(1.0, 0.0)


## The physical outcome of the capsule replacement: line quiet, grille
## secured, telltale at rest. The lifecycle fact lives in WorkOrders; this
## is only the body of the repair.
func set_repaired() -> void:
	_repaired = true
	set_chirping(false)
	set_grille_open(0.0)
	set_telltale_closed(true)


func is_repaired() -> bool:
	return _repaired


func get_service_state() -> Dictionary:
	return {"grille_open": _grille_open, "telltale_visible":
			_telltale.visible if _telltale else false,
			"repaired": _repaired, "mesh_count": _mesh_count(self)}


func interact_prompt() -> String:
	if chirp_hunt:
		return chirp_hunt.prompt_for(point_id)
	return "[E]  Inspect Vantry point"


func interact(_player: Node) -> void:
	set_grille_open(1.0)
	inspected.emit(point_id)


func interact_area(_area: Area3D) -> void:
	interact(null)


func stage_haunt(case_id: String, tier: int, _player: Node3D) -> bool:
	if case_id != "teresa_call_bells":
		return false
	set_telltale_closed(true)
	if _haunt_tween and _haunt_tween.is_valid():
		_haunt_tween.kill()
	_haunt_tween = create_tween()
	_haunt_tween.tween_interval(5.0 + tier)
	_haunt_tween.tween_callback(func(): set_telltale_closed(false))
	return true


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if accent > 0.9 and state == PState.OPERATING:
		play_chirp(accent)


func _build_service_area() -> void:
	var area := Area3D.new()
	area.name = "GrilleReach"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.14
	cyl.height = 0.12
	shape.shape = cyl
	shape.position.y = -0.055
	area.add_child(shape)
	add_child(area)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := make_box(size, at, color)
	remove_child(node)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(top, bottom, height, at, color, 0.48, 0.0, parent)


func _ring(parent: Node3D, radius: float, tube: float, at: Vector3,
		color: Color) -> MeshInstance3D:
	return make_ring(radius, tube, at, color, 0.48, 0.0, parent)


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count
