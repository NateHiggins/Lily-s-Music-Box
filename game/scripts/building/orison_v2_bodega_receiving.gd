extends Node3D
## A fitted room in the bodega's registered frame. ExteriorCell keeps the
## moving leaf, shop simulation, existing practical and public counter.
const ASSET := preload("res://assets/props/bodega_receiving.glb")
var startup_failed := false
var _mount := Transform3D.IDENTITY
var _practical: Dictionary = {}

func configure(exterior: OrisonV2ExteriorCell) -> bool:
	if exterior == null or exterior.instance_node("SHOP_BODEGA") == null:
		return false
	_mount = exterior.spatial_resolver.instance_world_transform("SHOP_BODEGA")
	if not _mount.is_finite(): return false
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		OrisonV2ExteriorCell.GEOMETRY_PATH))
	if source is not Dictionary: return false
	for template: Dictionary in source.get("templates", []):
		if template.id != "TEMPLATE_BODEGA_CELL_V1": continue
		for light: Dictionary in template.lights:
			if light.id == "delivery_alcove": _practical = light.duplicate(true)
	return not _practical.is_empty()

func _ready() -> void:
	transform = _mount
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var key := str(mesh.name).get_slice("__", 1)
		if not MatLib.SETS.has(key):
			startup_failed = true
			push_error("Bodega receiving material has no runtime mapping: " + key)
			return
		mesh.material_override = MatLib.get_mat(key)
		if key == "porcelain":
			var bulb := (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			var tint: Array = _practical.color_rgb
			bulb.emission_enabled = true
			bulb.emission = Color(tint[0], tint[1], tint[2])
			bulb.emission_energy_multiplier = .45
			mesh.material_override = bulb
		var body := StaticBody3D.new()
		body.name = str(mesh.name) + "Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
