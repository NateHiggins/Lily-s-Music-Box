extends Node3D
## The soda fountain at Otis & Son. An order comes up as an empty cup under the first
## nozzle. A click grabs the tap handle, pulling the mouse down opens it and the cup
## fills while it is held open; the handle springs back when let go. A click grabs the
## cup, motion lifts it to the mouth, and it goes down only at the top of the lift.
## Money stays with the sale point. What is in the cup and what is owed is saved.

const KEY := "otis_fountain"
const ORDERS := ["soda_at_the_fountain", "egg_cream"]
const STOCK := "4B_mug"
const CELL := "shop_otis_son"
const HANDLE_PART := "storm_shop_otis___son_fount__handle0"
## Where the handle's stem meets the valve, in the fitting's own metres.
const HANDLE_PIVOT := Vector3(19.645, 1.38, 45.055)
const PORTION := 5.0
const FILL_RATE := 1.4
const PULL := 0.6
const OPEN_AT := 0.6
const PULL_PIXELS := 130.0
const SPRING := 3.0
const LIFT_PIXELS := 220.0
const AT_MOUTH := 0.9
const TILT := 0.75
const MOUTH := Vector3(0.0, -0.1, -0.26)
const SETTLE_SPEED := 1.4

var world: Node3D
var cup: Node3D
var handle: MeshInstance3D
var held := ""
var pull := 0.0
var lift := 0.0
var _handle_rest := Transform3D.IDENTITY


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"drawn": 0.0, "owed": 0.0}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 2:
		return false
	for key: String in ["drawn", "owed"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])) or float(value[key]) < 0.0:
			return false
	return true


func configure(runtime: Node3D, point: Node3D) -> bool:
	world = runtime
	var stock := preload("res://scripts/building/orison_v2_surface_stock.gd").new()
	if not stock.prepare():
		return false
	cup = Node3D.new()
	cup.name = "Cup"
	add_child(cup)
	var mounted: bool = stock.mount_on(cup, STOCK)
	stock.finish()
	if not mounted:
		return false
	preload("res://scripts/props/manipulation_area.gd").install(cup, _cup_grip)
	point.sold.connect(serve)
	RealityState.state_changed.connect(refresh)
	refresh()
	return true


func serve(item_id: String) -> void:
	if item_id not in ORDERS:
		return
	var left := book()
	left.owed = float(left.owed) + PORTION
	RealityState.commit()
	refresh()


func refresh() -> void:
	var left := book()
	cup.visible = float(left.drawn) + float(left.owed) > 0.0 or held == "cup"


## The handle belongs to a fitting that may mount after this does.
func _find_handle() -> void:
	var cell: Node3D = world.passage_region.cell_nodes.get(CELL)
	var model: Node = cell.get_node_or_null("DruggistFountain") if cell != null else null
	if model == null:
		return
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta("druggist_fountain_part", "")) == HANDLE_PART:
			handle = draw
			_handle_rest = draw.transform
			preload("res://scripts/props/manipulation_area.gd").install(draw, _handle_grip)
			return


func _handle_grip() -> Dictionary:
	if handle == null:
		return {}
	return {"owner": self, "part": handle, "frame": self, "kind": "slide", "axis": Vector3.BACK,
		"minimum": 0.0, "maximum": PULL, "gesture_travel_px": PULL_PIXELS,
		"gesture_screen_axis": Vector2.DOWN, "unobstructed_hold": true,
		"read": func(): return pull,
		"write": func(value: float):
			if held == "handle":
				pull = value
				_pose_handle(),
		"owns": func(): return held == "handle",
		"begin": func():
			if held != "":
				return false
			held = "handle"
			return true,
		"end": func():
			held = ""
			RealityState.commit()}


func _cup_grip() -> Dictionary:
	if not cup.visible or float(book().drawn) + float(book().owed) <= 0.0:
		return {}
	return {"owner": self, "part": cup, "frame": self, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": 1.0, "gesture_travel_px": LIFT_PIXELS,
		"gesture_screen_axis": Vector2.UP,
		"read": func(): return lift,
		"write": func(value: float):
			if held == "cup":
				lift = value
				_pose_cup(),
		"owns": func(): return held == "cup",
		"begin": func():
			if held != "":
				return false
			held = "cup"
			return true,
		"end": func():
			held = ""
			RealityState.commit()}


func _pose_handle() -> void:
	var turn := Transform3D(Basis(Vector3.RIGHT, pull), HANDLE_PIVOT - Basis(Vector3.RIGHT, pull) * HANDLE_PIVOT)
	handle.transform = turn * _handle_rest


func _pose_cup() -> void:
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if lift <= 0.0 or player == null:
		cup.position = Vector3.ZERO
		cup.basis = Basis.IDENTITY
		return
	cup.position = Vector3.ZERO.lerp(to_local(player.camera.global_transform * MOUTH), lift)
	cup.global_basis = Basis(player.camera.global_basis.x, TILT * lift)


func _process(delta: float) -> void:
	if handle == null:
		_find_handle()
		return
	var left := book()
	if held != "handle" and pull > 0.0:
		pull = maxf(pull - SPRING * delta * PULL, 0.0)
		_pose_handle()
	if pull >= PULL * OPEN_AT and lift <= 0.0 and float(left.owed) > 0.0:
		var ran := minf(FILL_RATE * delta, float(left.owed))
		left.owed = float(left.owed) - ran
		left.drawn = float(left.drawn) + ran
	if held == "cup":
		_pose_cup()
		if lift >= AT_MOUTH and float(left.drawn) > 0.0:
			left.drawn = maxf(float(left.drawn) - delta, 0.0)
	elif lift > 0.0:
		lift = maxf(lift - SETTLE_SPEED * delta, 0.0)
		_pose_cup()
	elif cup.visible and float(left.drawn) + float(left.owed) <= 0.0:
		cup.visible = false
