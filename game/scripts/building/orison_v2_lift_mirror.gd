extends Node3D
## Presentation contract shared with medicine cabinets; follows the moving car.
const WALL_EDGE_INSET_M := 0.02

var unit := "Passenger lift"
var _glass: MeshInstance3D
var _fallback: Material
var _shaft_walls: Array[MeshInstance3D] = []


func mount(lift: OrisonElevator, adapter: OrisonV2AnchorAdapter) -> void:
	for wall_id: String in ["PASSENGER_SHAFT_WEST", "PASSENGER_SHAFT_EAST", "PASSENGER_SHAFT_REAR"]:
		var wall := adapter.resolve(wall_id) as MeshInstance3D
		if wall != null:
			_shaft_walls.append(wall)
	lift._cabin.add_child(self)
	position=Vector3(0,1.52,-1.075)
	var model := (preload("res://assets/props/lift_mirror.glb") as PackedScene).instantiate()
	var frame := model.find_child("MirrorFrame",true,false) as MeshInstance3D
	frame.material_override=lift._cab_mirror_parts[0].material_override
	add_child(model)
	_fallback=lift._cab_mirror_parts[1].material_override.duplicate()
	(_fallback as StandardMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED
	for old: MeshInstance3D in lift._cab_mirror_parts: old.hide()
	_glass=MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size=Vector2(.96,.76)
	_glass.mesh=mesh
	_glass.position.z=.026
	# Same mirror-local -Z convention as the existing cabinet surface, so
	# the asymmetric frustum and shader UV orientation remain consistent.
	_glass.rotation.y=PI
	_glass.layers=PlanarMirrorRenderer.MIRROR_LAYER
	_glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass.material_override=_fallback
	_glass.set_meta("mirror_size",mesh.size)
	add_child(_glass)
	_glass.add_to_group("planar_mirror_surface")
	lift._cab_mirror=self

func mirror_surface() -> MeshInstance3D: return _glass
func mirror_center() -> Vector3: return _glass.global_position
func mirror_normal() -> Vector3: return -_glass.global_basis.z.normalized()
func set_live_mirror_material(material: Material) -> void:
	_glass.material_override=material if material else _fallback

func mirror_occluded_from(eye: Vector3, visible_layers: int) -> bool:
	var half_pane := (_glass.mesh as QuadMesh).size * 0.5
	for wall in _shaft_walls:
		if not is_instance_valid(wall) or not wall.is_visible_in_tree() or not (wall.layers & visible_layers):
			continue
		var box := wall.mesh as BoxMesh
		if box == null:
			continue
		# Each named masonry wall is a closed box. If all four pane rays
		# cross the same inset rectangle, its full convex projection is hidden.
		var half_wall := box.size * 0.5
		var axis := Vector3.AXIS_X if box.size.x < box.size.z else Vector3.AXIS_Z
		var world_to_wall := wall.global_transform.affine_inverse()
		var local_eye := world_to_wall * eye
		if absf(local_eye[axis]) <= half_wall[axis]:
			continue
		var pane_to_wall := world_to_wall * _glass.global_transform
		var fully_hidden := true
		for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			var point := pane_to_wall * Vector3(corner.x * half_pane.x, corner.y * half_pane.y, 0.0)
			if signf(point[axis]) == signf(local_eye[axis]) or absf(point[axis]) <= half_wall[axis]:
				fully_hidden = false
				break
			var hit := local_eye.lerp(point, local_eye[axis] / (local_eye[axis] - point[axis]))
			var horizontal := hit.z if axis == Vector3.AXIS_X else hit.x
			var half_width := half_wall.z if axis == Vector3.AXIS_X else half_wall.x
			if absf(horizontal) >= half_width - WALL_EDGE_INSET_M or absf(hit.y) >= half_wall.y - WALL_EDGE_INSET_M:
				fully_hidden = false
				break
		if fully_hidden:
			return true
	return false
