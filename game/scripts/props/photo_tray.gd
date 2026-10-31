extends Node3D
## The working developing tray. With a print paid for, the hand rocks the tray: the image comes up
## while the bath moves, and slowly while it stands. The hand lifts the sheet out when it's
## ready. Too early is thin, too late is lost. The clock starts when the tray is first taken,
## and goes back to nothing if the player walks away and comes back another day.

const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const GESTURE_PIXELS := 180.0
const MAX_TILT := 0.09
const SECONDS_TO_READY := 18.0
const STANDING_RATE := 0.3
const THIN_BELOW := 0.6
const LOST_ABOVE := 1.15
const LIFT := 0.1

var tray: Node3D
var sheet: Node3D
var hours: Node
var progress := 0.0
var rock := 0.5
var lift := 0.0
var started := false
var _rocked_at := -10.0
var _tray_held := false
var _sheet_held := false
var _sheet_home := Vector3.ZERO
var _paper: StandardMaterial3D
var _image: StandardMaterial3D


func configure(pivot: Node3D, shop_hours: Node, picture: Texture2D) -> void:
	tray = pivot
	hours = shop_hours
	Manipulation.install(tray, tray_grip)
	sheet = Node3D.new()
	sheet.name = "Sheet"
	sheet.position = Vector3(0.0, _pan_height(pivot) - 0.012, 0.0)
	tray.add_child(sheet)
	_sheet_home = sheet.position
	var paper := MeshInstance3D.new()
	paper.name = "Paper"
	paper.mesh = _plate_mesh(Vector2(0.16, 0.2))
	_paper = MatLib.get_mat("paper").duplicate() as StandardMaterial3D
	_paper.resource_name="paper"
	_paper.uv1_triplanar=false;_paper.uv1_world_triplanar=false
	_paper.uv1_scale=Vector3.ONE/float(MatLib.SETS["paper"][3])
	_paper.normal_enabled=true
	_paper.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_paper.albedo_color = Color(.9, .87, .78)
	_paper.roughness = 0.45
	paper.material_override = _paper
	sheet.add_child(paper)
	var image := MeshInstance3D.new()
	image.name = "Image"
	image.mesh = _plate_mesh(Vector2(0.14, 0.18))
	image.position = Vector3(0.0, 0.0006, 0.0)
	_image = _paper.duplicate() as StandardMaterial3D
	# The paper's metric UV0 keeps grain/roughness at catalogue scale. The
	# photograph is a full-sheet UV2 detail, independent of that physical scale.
	_image.detail_enabled=true
	_image.detail_uv_layer=BaseMaterial3D.DETAIL_UV_2
	_image.detail_blend_mode=BaseMaterial3D.BLEND_MODE_MIX
	_image.detail_albedo=picture
	_image.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_image.roughness = 0.45
	image.material_override = _image
	sheet.add_child(image)
	# The pan's own target would take the ray first: the sheet's stands proud of the rim.
	var target := Manipulation.install(sheet, sheet_grip)
	for solid: Node in target.get_children():
		(solid as CollisionShape3D).shape.size.y = 0.06
		(solid as CollisionShape3D).position.y += 0.03
	refresh()


## How high the pan's rim stands above the pivot; the sheet lies just under it.
func _pan_height(pivot: Node3D) -> float:
	var top := 0.0
	for draw: Node in pivot.find_children("*", "MeshInstance3D", true, false):
		var box := (pivot.global_transform.affine_inverse() * (draw as Node3D).global_transform) * (draw as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)
	return top


func _plate_mesh(size: Vector2) -> ArrayMesh:
	var plane:=PlaneMesh.new();plane.size=size
	var arrays:=plane.get_mesh_arrays()
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	arrays[Mesh.ARRAY_TEX_UV2]=uv.duplicate()
	for index in uv.size():uv[index]*=size
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


func _closed() -> bool:
	return hours != null and is_instance_valid(hours) and hours.has_method("is_after_hours") and bool(hours.call("is_after_hours"))


func refresh() -> void:
	sheet.visible = bool(PhotoSales.book().waiting)
	_show()


func _show() -> void:
	# Comes up out of nothing to a full image, then on past it into black.
	_image.albedo_color = Color(1, 1, 1, clampf(progress / THIN_BELOW * 0.6, 0.0, 1.0)) if progress <= 1.0 \
			else Color.WHITE.darkened(clampf((progress - 1.0) / 0.4, 0.0, 0.95))


func tray_grip() -> Dictionary:
	if not bool(PhotoSales.book().waiting) or _closed():
		return {}
	return {"owner": self, "part": tray, "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
		"minimum": 0.0, "maximum": 1.0, "gesture_travel_px": GESTURE_PIXELS, "gesture_screen_axis": Vector2.RIGHT,
		"read": func(): return rock,
		"write": func(value: float):
			if _tray_held:
				_rock(value),
		"begin": func():
			if _tray_held or _sheet_held:
				return false
			_tray_held = true
			started = true
			return true,
		"owns": func(): return _tray_held,
		"end": func(): _tray_held = false}


func sheet_grip() -> Dictionary:
	if not bool(PhotoSales.book().waiting) or _closed():
		return {}
	return {"owner": self, "part": sheet, "frame": tray, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": LIFT, "gesture_travel_px": GESTURE_PIXELS, "gesture_screen_axis": Vector2.UP,
		"read": func(): return lift,
		"write": func(value: float):
			if _sheet_held:
				_lift(value),
		"begin": func():
			if _sheet_held or _tray_held:
				return false
			_sheet_held = true
			started = true
			return true,
		"owns": func(): return _sheet_held,
		"end": func(): _sheet_held = false}


func _rock(value: float) -> void:
	if not is_finite(value):
		return
	if absf(value - rock) > 0.0001:
		_rocked_at = Time.get_ticks_msec() / 1000.0
	rock = clampf(value, 0.0, 1.0)
	tray.rotation.z = (rock - 0.5) * 2.0 * MAX_TILT


func _lift(value: float) -> void:
	if not is_finite(value):
		return
	lift = clampf(value, 0.0, LIFT)
	sheet.position = _sheet_home + Vector3.UP * lift
	if lift >= LIFT - 0.000001:
		_finish()


func _finish() -> void:
	if not bool(PhotoSales.book().waiting):
		return
	PhotoSales.book().waiting = false
	var title := "Print" if progress >= THIN_BELOW else "Print, thin"
	var lost := progress > LOST_ABOVE
	if not lost:
		PersonInventory.carry_goods(PersonInventory.PLAYER, "own_print", title, "card")
	RealityState.commit()
	progress = 0.0
	lift = 0.0
	started = false
	_sheet_held = false
	sheet.position = _sheet_home
	refresh()
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player != null:
		player.present_service_note(self, {"title": "THE TRAY", "body": "GONE BLACK. NOTHING TO KEEP." if lost else title.to_upper() + ". IN THE CASE.",
			"condition": "LOST" if lost else "FIXED", "stamp": "SERVICE NOTE"})


func _physics_process(delta: float) -> void:
	if not started or not bool(PhotoSales.book().waiting):
		return
	var moving := Time.get_ticks_msec() / 1000.0 - _rocked_at < 0.5
	progress += delta / SECONDS_TO_READY * (1.0 if moving else STANDING_RATE)
	_show()
