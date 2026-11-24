extends Node3D
## The paper sack the bodega counter fills from a resident's list. It stands on the
## counter beside the terminal while ResidentErrands says a sack is waiting. The hand
## takes hold of it and lifts it; lifted clear, it goes into the carried case for the
## walk to the resident's door. Released short, it sets back down where it stood.
## Lily's ruling bodega_list_and_bag_20261124 (2026-11-24). It owns no stock, money
## or goods: ResidentErrands does. No physics body and no per-frame work.

const LIFT := 0.12
const TAKEN_AT := 0.9
const DRAG_PIXELS := 140.0
const SIZE := Vector3(0.22, 0.28, 0.14)
const FOLD := Vector3(0.22, 0.03, 0.15)
const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var errands: ResidentErrands
var part: Node3D
var target_area: Area3D
var lift := 0.0
var _held := false


func configure(owner_errands: ResidentErrands) -> bool:
	if owner_errands == null:
		return false
	errands = owner_errands
	part = Node3D.new()
	part.name = "Sack"
	add_child(part)
	var paper := MatLib.get_mat("paper").duplicate() as StandardMaterial3D
	paper.uv1_triplanar = false
	paper.uv1_scale = Vector3.ONE / float(MatLib.SETS["paper"][3])
	# Unbleached kraft: the catalogue paper, warmed and darkened.
	paper.albedo_color = Color(0.78, 0.62, 0.42)
	_draw("Body", SIZE, Vector3(0, SIZE.y * 0.5, 0), Vector3.ZERO, paper)
	# The top rolled over once, standing a little proud of the body.
	_draw("Fold", FOLD, Vector3(0, SIZE.y + FOLD.y * 0.5 - 0.004, 0.0),
			Vector3(deg_to_rad(4.0), 0, 0), paper)
	target_area = Manipulation.install(part, _grip)
	errands.sack_changed.connect(refresh)
	refresh()
	return target_area.get_child_count() > 0


func _draw(identity: String, size: Vector3, at: Vector3, turn: Vector3,
		material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var draw := MeshInstance3D.new()
	draw.name = identity
	draw.mesh = MetreUV.chart(box)
	draw.material_override = material
	draw.position = at
	draw.rotation = turn
	part.add_child(draw)
	return draw


func waiting() -> String:
	return errands.sack_waiting() if errands != null else ""


## Shown, and offered to the hand, only while a sack stands on the counter.
func refresh() -> void:
	var there := waiting() != ""
	visible = there
	if is_instance_valid(target_area):
		target_area.collision_layer = 1 if there else 0
	if not _held:
		_set_lift(0.0)


func _set_lift(value: float) -> void:
	lift = clampf(value, 0.0, LIFT)
	if part != null:
		part.position = Vector3.UP * lift


func _grip() -> Dictionary:
	if waiting() == "":
		return {}
	return {"owner": self, "part": part, "frame": self, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": LIFT, "gesture_travel_px": DRAG_PIXELS,
		"gesture_screen_axis": Vector2.UP,
		"read": func(): return lift,
		"write": func(value: float):
			if _held:
				_set_lift(value),
		"owns": func(): return _held,
		"begin": func():
			if _held:
				return false
			_held = true
			return true,
		"end": _release}


func _release() -> void:
	if not _held:
		return
	_held = false
	var resident := waiting()
	if lift >= LIFT * TAKEN_AT and resident != "" and errands.take_sack(resident):
		return # take_sack emits sack_changed, which hides and resets it.
	_set_lift(0.0)
