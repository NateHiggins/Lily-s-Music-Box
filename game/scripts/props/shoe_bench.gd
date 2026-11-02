extends Node3D
## The bench at Shoe Rebuilding. Paying for half soles stands your boots at this end. A click
## grabs them, motion slides them along the bench to the finisher, and they stay there only if
## they go the whole way. They come back the next day at the far end, and the same stroke
## brings them home, resoled. ShoeSales owns the book; this owns the boots on the bench.

const MaterialSets := preload("res://scripts/generated/material_sets.gd")
const UPPER_KEY := "leather_worn"
const SOLE_KEY := "rubber_aged"
const BROWN := Color(0.42, 0.3, 0.22)
const TRAVEL := 1.1
const TAKEN_AT := 0.85
const DRAG_PIXELS := 260.0
const SETTLE_SPEED := 1.2

var world: Node3D
var boots: Node3D
var along := 0.0
var held := false
var _dragged_from := 0.0


func configure(runtime: Node3D, point: Node3D) -> bool:
	world = runtime
	boots = Node3D.new()
	boots.name = "CustomerBoots"
	add_child(boots)
	var scene := load("res://assets/props/customer_boots.glb") as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	boots.add_child(model)
	model.rotation_degrees.y = 90.0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var key := SOLE_KEY if "sole" in draw.name else UPPER_KEY
		if not MaterialSets.SETS.has(key):
			return false
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		if key == UPPER_KEY:
			material.albedo_color = BROWN
		material.uv1_scale = Vector3.ONE / float(MaterialSets.SETS[key][3])
		draw.set_surface_override_material(0, material)
	preload("res://scripts/props/manipulation_area.gd").install(boots, _grip)
	point.sold.connect(func(_item: String): refresh())
	RealityState.state_changed.connect(refresh)
	refresh()
	return true


## Boots come back the morning after they went, so a day's count is all the work needs.
func _today() -> int:
	var info: Dictionary = world.campaign_clock.day_info()
	return int(info.get("year", 0)) * 1000 + int(info.get("doy", 0))


func collectable() -> bool:
	var left := ShoeSales.book()
	return str(left.away) != "" and _today() >= int(left.ready)


func refresh() -> void:
	var left := ShoeSales.book()
	boots.visible = str(left.paid) != "" or collectable() or held
	if not held:
		along = TRAVEL if collectable() else 0.0
		_pose()


func _grip() -> Dictionary:
	if not boots.visible:
		return {}
	return {"owner": self, "part": boots, "frame": self, "kind": "slide", "axis": Vector3.LEFT,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_travel_px": DRAG_PIXELS,
		"gesture_screen_axis": Vector2.LEFT,
		"reach_point": func(): return to_global(Vector3.LEFT * TRAVEL * 0.5),
		"unobstructed_hold": true,
		"read": func(): return along,
		"write": func(value: float):
			if held:
				along = value
				_pose(),
		"owns": func(): return held,
		"begin": func():
			if held:
				return false
			held = true
			_dragged_from = along
			return true,
		"end": _release}


## Sent to the finisher, or brought home. Short of the end they slide back where they were.
func _release() -> void:
	held = false
	var left := ShoeSales.book()
	if str(left.paid) != "" and along >= TRAVEL * TAKEN_AT:
		left.away = left.paid
		left.paid = ""
		left.ready = _today() + 1
	elif collectable() and along <= TRAVEL * (1.0 - TAKEN_AT):
		left.sole = left.away
		left.away = ""
	RealityState.commit()
	refresh()


func _pose() -> void:
	boots.position = Vector3.LEFT * along


func _process(delta: float) -> void:
	if held or not boots.visible:
		return
	var rest := TRAVEL if collectable() else 0.0
	if not is_equal_approx(along, rest):
		along = move_toward(along, rest, SETTLE_SPEED * delta)
		_pose()
