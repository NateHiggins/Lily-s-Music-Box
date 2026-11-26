extends Node3D
## A sheet stays on its own support until the player lifts it into the valise.
## With this specific sheet in the glove, the same spot accepts it back.
const Custody := preload("res://scripts/songbook/found_trace_custody.gd")
const Visual := preload("res://scripts/songbook/found_trace_visual.gd")
const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const TRAVEL := .12
const RELEASE_STROKE := .10
const DRAG_PIXELS := 120.0

var trace_id: String
var sheet: Node3D
var _visual: Node3D
var _area: Manipulation
var _height := 0.0
var _held := false
var _returning := false
var _holder: Node


static func mount_building(adapter: OrisonV2AnchorAdapter, desk: Node3D) -> bool:
	var boiler := adapter.resolve("B1_BOILER_01") as BoilerProp
	var first := adapter.resolve("B1_WASHER_01") as WasherProp
	var second := adapter.resolve("B1_WASHER_02") as WasherProp
	if boiler == null or first == null or second == null or desk == null:
		return false
	# The equalizer runs at x=-.76. Its 10 cm-high concrete hearth extends
	# to x=-.72; the sheet lies lengthwise on the ledge behind the pipe.
	if not _place(boiler, "trace_room0", Vector3(-.649, .10, .42), PI * .5):
		return false
	# The sleeve has fallen into the gap between the two immovable wringer
	# chassis. The front half of the gap is accessible from the laundry aisle.
	var gap := first.global_position.lerp(second.global_position, .5) - first.global_basis.z.normalized() * .18
	if not _place(first, "trace_1610", first.to_local(gap)):
		return false
	# Clear oak in front of the sorting rail, between the letter tray and tally.
	return _place(desk, "trace_two_voices", Vector3(.10, .76, .52))


static func mount_landing(bar: Node3D, furniture: Array) -> bool:
	var stack: Array = furniture.filter(func(row): return row.id == "retail_bar_acc_news1")
	var binding: Array = furniture.filter(func(row): return row.id == "retail_bar_acc_news_twine")
	if stack.size() != 1 or binding.size() != 1:
		return false
	# Centre the loose sheet on the free paper to the right of the twine.
	# Derive the top from the same local stock that was baked into the bar cell.
	var rect: Array = stack[0].rect
	var free_left := float(binding[0].rect[2])
	if float(rect[2]) - free_left < Visual.SIZE.x or float(rect[3]) - float(rect[1]) < Visual.SIZE.z:
		return false
	var support := GameBoot.b2g([(free_left + float(rect[2])) * .5, (float(rect[1]) + float(rect[3])) * .5,
		float(stack[0].z0) + float(stack[0].h)])
	return _place(bar, "trace_unlabelled", support)


static func _place(parent: Node3D, id: String, at: Vector3, yaw := 0.0) -> bool:
	if parent.has_node(NodePath(id)):
		return false
	var source := new()
	source.trace_id = id
	source.name = id
	source.position = at
	source.rotation.y = yaw
	source._visual = Visual.make(id)
	if source._visual == null:
		source.free()
		return false
	parent.add_child(source)
	return true


func _ready() -> void:
	sheet = Node3D.new()
	sheet.name = "Sheet"
	add_child(sheet)
	sheet.add_child(_visual)
	_area = Manipulation.new()
	_area.name = "Operable"
	_area.provider = _grip
	_area.collision_layer = 0
	_area.collision_mask = 0
	_area.monitoring = false
	_area.add_to_group("functional_interaction_areas")
	sheet.add_child(_area)
	var contact := CollisionShape3D.new()
	contact.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(Visual.SIZE.x, .012, Visual.SIZE.z)
	contact.shape = shape
	contact.position.y = shape.size.y * .5
	_area.add_child(contact)
	add_to_group("found_trace_sources")
	RealityState.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var packed := Custody.is_packed(trace_id)
	var selected := packed and CarriedCase.hand() == Custody.item_id(trace_id)
	if _held and (_returning != packed or (_returning and not selected)):
		_held = false
	if not _held:
		_height = 0.0
	sheet.position.y = _height
	# An empty patch of shelf can be targeted only with its own item in hand.
	# Until the return stroke begins, the selected sheet remains in the glove.
	_area.collision_layer = 1 if not packed or selected else 0
	_visual.visible = not packed or _held


func _grip() -> Dictionary:
	var packed := Custody.is_packed(trace_id)
	if packed and CarriedCase.hand() != Custody.item_id(trace_id):
		return {}
	return {"owner": self, "frame": self, "part": sheet, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_travel_px": DRAG_PIXELS,
		"gesture_screen_axis": Vector2.UP, "read": func(): return _height,
		"begin": _begin, "owns": func(): return _held, "write": _move_sheet,
		"bind_holder": func(holder): _holder = holder,
		"end": _finish.bind(false), "primary_end": _finish.bind(true)}


func _begin() -> bool:
	if _held:
		return false
	_returning = Custody.is_packed(trace_id)
	if _returning and CarriedCase.hand() != Custody.item_id(trace_id):
		return false
	_held = true
	_height = TRAVEL if _returning else 0.0
	_refresh()
	return true


func _move_sheet(value: float) -> void:
	if _held:
		_height = clampf(value, 0.0, TRAVEL)
		sheet.position.y = _height


func _finish(primary: bool) -> void:
	if not _held:
		return
	_held = false
	var refused := false
	if primary:
		if _returning and _height <= TRAVEL - RELEASE_STROKE and CarriedCase.hand() == Custody.item_id(trace_id):
			refused = not Custody.return_to_source(trace_id)
		elif not _returning and _height >= RELEASE_STROKE:
			refused = not Custody.take(trace_id)
	# A full case, a cancelled grip, or a rejected save leaves the real owner
	# intact. Always redraw from custody; never publish an optimistic transfer.
	_refresh()
	if refused and is_instance_valid(_holder) and _holder.has_method("present_service_note"):
		var message := "The packet is still in the valise." if _returning else "The valise would not take the paper. It is still here."
		_holder.present_service_note(self, {"title": "Found trace", "body": message})
	_holder = null
