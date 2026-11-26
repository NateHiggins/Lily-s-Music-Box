extends "res://scripts/songbook/found_trace_source.gd"
## A receiver for completed originals on the existing phonautograph. The tray
## draws the authority's exposed sheet and delegates every handoff back to it.
const OfficeStock := preload("res://scripts/building/orison_v2_house_office_stock.gd")
const TRAY_PIVOT := Vector3(.550, .111, .150)
const SHEET_UNDERSIDE := Vector3(.550, .1152, .150)
const RUNNER_CENTRES_Z := [.085, .215]

var _read_top: Callable
var _selected_original: Callable
var _take_original: Callable
var _put_original_back: Callable
var _render_original: Callable
var _displayed := ""


## Call after the recorder's M13 native retrofit has succeeded. The prepared
## stock is the mounted house-office desk's stock. IDs are bare edition IDs.
## read_top()/selected_original() -> String, take(id)/put_back(id) -> bool.
## The optional render_original(id) -> Node3D uses the same underside origin
## as FoundTraceVisual and can provide edition-specific audio/inscription.
static func mount(recorder: Node3D, stock: OfficeStock, read_top: Callable,
		selected_original: Callable, take: Callable, put_back: Callable,
		render_original := Callable()) -> bool:
	if recorder == null or recorder.name != &"F01_BAR_SONGBOOK" or not recorder.get_meta("v2_native_service_instrument", false):
		return false
	var actors := recorder.get_parent() as Node3D
	if actors == null or actors.has_node("PlayerOriginalOutput") or stock == null:
		return false
	if not read_top.is_valid() or not selected_original.is_valid() or not take.is_valid() or not put_back.is_valid():
		return false
	# M13_P013 is the existing 300 x 20 x 20 mm iron carriage runner.
	var rail: MeshInstance3D
	for draw: MeshInstance3D in recorder.find_children("*", "MeshInstance3D", true, false):
		if draw.get_meta("native_service_instrument_part", "") == "M13_P013":
			rail = draw
			break
	if rail == null or rail.mesh == null or rail.get_active_material(0) == null:
		return false
	var bounds := rail.mesh.get_aabb()
	if bounds.size.distance_to(Vector3(.300, .020, .020)) > .0005:
		return false
	var mounting := Node3D.new()
	mounting.name = "PlayerOriginalOutput"
	mounting.transform = recorder.transform
	var tray := stock.part_node("sorting_desk", "Tray")
	if not tray.has_node("sorting_desk__Tray_ON_iron_blackened") or not tray.has_node("sorting_desk__Tray_ON_brass"):
		tray.free()
		mounting.free()
		return false
	# Native vertices are pivoted on the donor tray. Strip the donor desk pose.
	tray.transform = Transform3D(Basis.IDENTITY, TRAY_PIVOT)
	mounting.add_child(tray)
	var runner_mesh := rail.mesh
	for z: float in RUNNER_CENTRES_Z:
		var runner := MeshInstance3D.new()
		runner.name = "BackRunner" if z < TRAY_PIVOT.z else "FrontRunner"
		runner.mesh = runner_mesh
		runner.material_override = rail.get_active_material(0)
		runner.visibility_range_end = OfficeStock.RANGE
		# The native visual has already baked in the M13 dado standoff.
		runner.position = Vector3(.445, .101, z) - bounds.get_center()
		mounting.add_child(runner)

	var paper := new()
	paper.name = "TopOriginal"
	paper.position = SHEET_UNDERSIDE
	paper._read_top = read_top
	paper._selected_original = selected_original
	paper._take_original = take
	paper._put_original_back = put_back
	paper._render_original = render_original
	paper._visual = Node3D.new()
	paper._visual.name = "ExposedStock"
	mounting.add_child(paper)
	actors.add_child(mounting)
	return true


func _top_id() -> String:
	return _read_top.call()


func _return_id() -> String:
	return _selected_original.call()


func _transfer(id: String, returning: bool) -> bool:
	return _put_original_back.call(id) if returning else _take_original.call(id)


func _present_sheet(id: String) -> bool:
	if id == _displayed:
		return true
	var edition: Node3D
	if _render_original.is_valid():
		edition = _render_original.call(id) as Node3D
	else:
		edition = Visual.make_player_original(id)
	if edition == null:
		return false
	for previous in _visual.get_children():
		_visual.remove_child(previous)
		previous.queue_free()
	_visual.add_child(edition)
	_displayed = id
	return true
