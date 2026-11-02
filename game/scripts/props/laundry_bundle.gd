extends Node3D
## The bundle on the Model Laundry counter. Paying stands it on the customer's edge. A click grabs
## it, motion pushes it across to the back, and it stays there only if it goes the whole way. It
## comes back the next day, tied up, and the same stroke brings it home clean. LaundrySales owns
## the book; this owns the bundle on the counter.

const MaterialSets := preload("res://scripts/generated/material_sets.gd")
const TRAVEL := 0.4
const TAKEN_AT := 0.85
const DRAG_PIXELS := 200.0
const SETTLE_SPEED := 0.8

var job := LaundrySales.KEY
var model_path := "res://assets/props/laundry_bundle.glb"
var part_keys := {"wrap": "paper", "string": "linen"}
var axis := Vector3.RIGHT
var gesture := Vector2.UP
var bundle: Node3D
var along := 0.0
var held := false


func configure(point: Node3D) -> bool:
	bundle = Node3D.new()
	bundle.name = "LaundryBundle"
	add_child(bundle)
	var scene := load(model_path) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	bundle.add_child(model)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var key := str(part_keys.get(str(draw.name).get_slice("__", 1), ""))
		if not MaterialSets.SETS.has(key):
			return false
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(MaterialSets.SETS[key][3])
		draw.set_surface_override_material(0, material)
	preload("res://scripts/props/manipulation_area.gd").install(bundle, _grip)
	point.sold.connect(func(_item: String): refresh())
	RealityState.state_changed.connect(refresh)
	refresh()
	return true


func refresh() -> void:
	var left := LaundrySales.book(job)
	bundle.visible = bool(left.paid) or LaundrySales.collectable(job) or held
	if not held:
		along = TRAVEL if LaundrySales.collectable(job) else 0.0
		_pose()


func _grip() -> Dictionary:
	if not bundle.visible:
		return {}
	return {"owner": self, "part": bundle, "frame": self, "kind": "slide", "axis": axis,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_travel_px": DRAG_PIXELS,
		"gesture_screen_axis": gesture,
		"reach_point": func(): return to_global(axis * TRAVEL * 0.5),
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
			return true,
		"end": _release}


## Taken in, or brought home. Short of the end it slides back where it was.
func _release() -> void:
	held = false
	var left := LaundrySales.book(job)
	if bool(left.paid) and along >= TRAVEL * TAKEN_AT:
		left.paid = false
		left.away = true
		left.ready = LaundrySales.day() + 1
	elif LaundrySales.collectable(job) and along <= TRAVEL * (1.0 - TAKEN_AT):
		left.away = false
		left.washed = LaundrySales.day()
	RealityState.commit()
	refresh()


func _pose() -> void:
	bundle.position = axis * along


func _process(delta: float) -> void:
	if held or not bundle.visible:
		return
	var rest := TRAVEL if LaundrySales.collectable(job) else 0.0
	if not is_equal_approx(along, rest):
		along = move_toward(along, rest, SETTLE_SPEED * delta)
		_pose()
