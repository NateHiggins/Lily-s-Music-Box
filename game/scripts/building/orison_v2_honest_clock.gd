extends "res://scripts/props/clock_prop.gd"
## The two honest clocks in V2: 4B's eight-day drop octagon and the lobby's
## Vantry reference clock. clock_prop.gd keeps the time, the spring, the
## winding order, the sealed cover and the service card; this mounts the
## Blender-authored cases and points V1's hands, pendulum and cover at them.
const Native := preload("res://scripts/building/orison_v2_native_witness_clocks.gd")

var native: RefCounted
var _spec: Dictionary = {}


func _build_visual() -> void:
	var face := Node3D.new()
	face.name = "FaceRig"
	add_child(face)
	if native == null:
		native = Native.new()
	var mounted: Dictionary = native.mount_on(self, clock_variant, Color("611310"), face) \
			if native.prepare() else {}
	if mounted.is_empty():
		push_error("V2 honest clock stock refused: " + clock_variant)
		return
	_spec = mounted.spec
	var pivots: Dictionary = mounted.pivots
	_hour = pivots.get("HourHand")
	_minute = pivots.get("MinuteHand")
	_second = pivots.get("SecondHand")
	_pendulum = pivots.get("Pendulum")
	var cover: Node3D = pivots.get("Cover")
	if cover != null:
		# V1 rattles the cover about its rest position; the mesh rests at its pivot.
		_master_cover = cover.get_child(0) as MeshInstance3D
		_cover_rest = _master_cover.position
	if _spec.has("winding_reach"):
		var reach := Marker3D.new()
		reach.name = "WindingReach"
		reach.position = Native.vec(_spec.winding_reach)
		add_child(reach)
	_build_collision()
	_tick = make_emitter("tick", -29.0 if clock_variant == "vantry_master" else -26.0)
	_tick.max_distance = 8.0
	_service_touch = make_emitter("tick", -18.0)
	_service_touch.max_distance = 3.4
	_show_time()


func _build_collision() -> void:
	var area := Area3D.new()
	area.name = "ClockReach"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var extent := Native.bounds(_spec).grow(0.03)
	shape.size = extent.size
	cs.shape = shape
	cs.position = extent.get_center()
	area.add_child(cs)
	add_child(area)


## V1 issues the winding order when the clock starts. A spine bound after the
## clock is in the tree gets the same order then.
func bind_order_spine(spine: WorkOrders) -> void:
	super.bind_order_spine(spine)
	if is_node_ready():
		_start_normal_function()
