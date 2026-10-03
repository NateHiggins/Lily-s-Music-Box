extends Node3D
## Presentation contract shared with medicine cabinets; follows the moving car.
var unit := "Passenger lift"
var _glass: MeshInstance3D
var _fallback: Material

func mount(lift: OrisonElevator) -> void:
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
