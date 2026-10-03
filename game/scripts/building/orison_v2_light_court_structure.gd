extends RefCounted
## Installed court structure; physical guards match the native rail envelope.
static func mount(root: Node3D) -> void:
	var model: Node3D = preload("res://assets/props/light_court_structure.glb").instantiate()
	model.name = "LightCourtStructure"
	root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var key := str(draw.mesh.surface_get_material(0).resource_name)
		draw.material_override = MatLib.get_mat(key)
		if str(draw.name).begins_with("LightCourtTransfer_"):
			draw.create_trimesh_collision()
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/light_court_guards.json"))
	for guard: Dictionary in construction.guards:
		var a := Vector3(guard.bounds[0],guard.bounds[1],guard.bounds[2])
		var b := Vector3(guard.bounds[3],guard.bounds[4],guard.bounds[5])
		_box(model, guard.id + "Collision", (a+b)*.5, b-a)

static func _box(parent: Node3D, label: String, centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = centre
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
