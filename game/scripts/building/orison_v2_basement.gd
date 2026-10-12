extends RefCounted
## Service apparatus uses existing production owners. Storage is architecture,
## not a second inventory or a new set of resident quests.
const UNITS := ["1A","1D","2A","2B","2C","3A","3B","3D","4A","4B","4C","4D","5A","5B","5C","6A","6B","6C"]

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var delivery := preload("res://scripts/building/orison_v2_coal_delivery.gd").new()
	if not adapter.mount_consumer("B1_COAL_BUNKER", delivery):
		delivery.free()
		return false
	var panel := FusePanelProp.new()
	panel.prop_type = "fuse_panel"
	_box(panel,Vector3(0,.5,-.06),Vector3(.66,.90,.12),MatLib.get_mat("cast_iron"),true)
	if not adapter.mount_consumer("B1_FUSE_PANEL",panel):
		panel.free()
		return false
	var storage := preload("res://scripts/building/orison_v2_native_resident_storage.gd").new()
	return storage.mount(adapter)

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)
		parent.add_child(body)
