class_name PassagePushcart
extends RigidBody3D
## A low 1920s market handcart: movable circulation furniture, not a fixed
## corridor obstacle.  The player can shoulder it through ordinary rigid-body
## contact or give it a deliberate shove with the shared interact verb.

const FOOTPRINT := Vector2(0.92, 1.34)
const SHOVE_IMPULSE := 46.0

var cart_id := ""
var cargo := "empty"
var _active := true


func setup(id_: String, cargo_: String) -> void:
	cart_id = id_
	cargo = cargo_
	name = "PassagePushcart_%s" % cart_id
	mass = 46.0
	linear_damp = 4.2
	angular_damp = 8.0
	lock_rotation = true
	can_sleep = true
	add_to_group("passage_pushcarts")
	add_to_group("passage_runtime")
	set_meta("cart_id", cart_id)
	set_meta("cargo", cargo)
	_build_collision()
	_build_visual()


func _build_collision() -> void:
	var shape_node := CollisionShape3D.new()
	shape_node.name = "ShoveableCartHull"
	var shape := BoxShape3D.new()
	shape.size = Vector3(FOOTPRINT.x, 0.88, FOOTPRINT.y)
	shape_node.shape = shape
	shape_node.position.y = 0.46
	add_child(shape_node)
	var physics := PhysicsMaterial.new()
	physics.friction = 0.46
	physics_material_override = physics


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "WeatheredHandcart"
	add_child(visual)
	var timber := MatLib.get_mat("oak_quartered",
			Color(0.52, 0.34, 0.18), 0.72)
	var iron := MatLib.get_mat("cast_iron", Color(0.28, 0.29, 0.28), 0.72)
	var rubber := MatLib.get_mat("rubber_aged", Color(0.30, 0.29, 0.27), 0.82)
	var canvas := MatLib.get_mat("linen", Color(0.58, 0.48, 0.33), 0.84)
	var paper := MatLib.get_mat("paper", Color(0.66, 0.58, 0.43), 0.72)

	_box(visual, Vector3(0.88, 0.10, 1.28), Vector3(0, 0.48, 0), timber)
	# Raised slats make the load bed a repairable handcart rather than a modern
	# supermarket basket.  The rear rail carries the shove handle.
	for x in [-0.42, 0.42]:
		# Open side frames. A solid 340 mm iron plate became a near-black box
		# under the canonical hall lamps even though its material was correct.
		for y in [0.60, 0.82]:
			_box(visual, Vector3(0.055, 0.055, 1.28),
					Vector3(x, y, 0), iron)
		for z in [-0.60, 0.60]:
			_box(visual, Vector3(0.055, 0.28, 0.055),
					Vector3(x, 0.70, z), iron)
	for z in [-0.60, 0.60]:
		_box(visual, Vector3(0.88, 0.055, 0.055),
				Vector3(0, 0.82, z), iron)
	for x in [-0.35, 0.35]:
		_box(visual, Vector3(0.045, 0.52, 0.045),
				Vector3(x, 0.82, 0.70), iron)
	_box(visual, Vector3(0.78, 0.045, 0.045),
			Vector3(0, 1.06, 0.70), timber)
	for x in [-0.46, 0.46]:
		for z in [-0.43, 0.43]:
			var wheel := _cylinder(visual, 0.18, 0.065,
					Vector3(x, 0.22, z), rubber)
			wheel.rotation_degrees.z = 90.0
			_cylinder(visual, 0.055, 0.075,
					Vector3(x, 0.22, z), iron).rotation_degrees.z = 90.0

	match cargo:
		"laundry":
			_sack(visual, Vector3(-0.20, 0.72, -0.18),
					Vector3(0.28, 0.22, 0.38), canvas)
			_sack(visual, Vector3(0.18, 0.73, 0.20),
					Vector3(0.30, 0.24, 0.34), canvas)
		"papers":
			for i in range(3):
				_box(visual, Vector3(0.70, 0.075, 0.42),
						Vector3(0, 0.58 + float(i) * 0.078,
						-0.22 + float(i % 2) * 0.04), paper)
		"crates":
			_box(visual, Vector3(0.66, 0.42, 0.52),
					Vector3(-0.06, 0.74, -0.22), timber)
			_box(visual, Vector3(0.48, 0.32, 0.44),
					Vector3(0.10, 0.67, 0.30), timber)
		_:
			pass
	# Three or four textured surfaces per cart, rather than one draw per slat.
	StaticMeshBatcher.merge(visual)


func interact_prompt() -> String:
	return "[E]  Shove handcart"


func interact(player: Node) -> void:
	if not player is Node3D:
		return
	shove_from((player as Node3D).global_position)


func shove_from(source: Vector3) -> void:
	if not _active:
		return
	var direction := global_position - source
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -global_transform.basis.z
	# The visibility owner may have frozen the body one physics tick earlier;
	# an interaction inside PASSAGE must always wake it before applying force.
	freeze = false
	sleeping = false
	apply_central_impulse(direction.normalized() * SHOVE_IMPULSE)


func set_passage_active(active: bool) -> void:
	_active = active
	visible = active
	freeze = not active
	collision_layer = 1 if active else 0
	collision_mask = 1 if active else 0


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _sack(parent: Node3D, at: Vector3, size: Vector3,
		material: StandardMaterial3D) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 7
	node.mesh = mesh
	node.position = at
	node.scale = size
	node.material_override = material
	parent.add_child(node)
