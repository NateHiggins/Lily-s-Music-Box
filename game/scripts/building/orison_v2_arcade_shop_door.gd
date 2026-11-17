extends DoorProp
## Prepared 2m arcade pair (or 1m stock leaf), never a second lock/save owner.
## Installation chooses this fitted family; the historical arcade stays intact.
const DATA := "res://data/orison_v2/arcade_door_leaves.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
var paired := true
var _right_body: AnimatableBody3D

func _init() -> void:
	width = 2.0
	height = 2.30
	door_kind = "storefront"

func motion_leaves() -> Array[Dictionary]:
	var leaves: Array[Dictionary] = [{"body":_body,"width":1.0,"ratio":1.0}]
	if paired: leaves.append({"body":_right_body,"width":1.0,"ratio":-1.0})
	return leaves

func passage_swing_radius() -> float:
	return 1.0

func lock_x() -> float:
	return 1.0-.085

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-90.0 if swing_out else 90.0) if want_open else 0.0

func valid_mechanism(value: Variant) -> bool:
	# Keep the same one-angle authority and historical 100-degree save intake.
	return value is Dictionary and value.size()==1 and typeof(value.get("angle")) in [TYPE_FLOAT,TYPE_INT] \
		and is_finite(float(value.angle)) and float(value.angle)>=minf(0,deg_to_rad(-100.0 if swing_out else 100.0))-.000001 \
		and float(value.angle)<=maxf(0,deg_to_rad(-100.0 if swing_out else 100.0))+.000001

func _material(key: String) -> Material:
	if key == "glass_drawn_expressive":
		return preload("res://scripts/building/orison_v2_architectural_materials.gd").new().material_for("Glazing","public")
	assert(key in ["door_oak","door_brass"])
	var source := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	source.uv1_triplanar = false
	source.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
	return Surface.surface_for(source,{"uv_mode":0})

func _collision(body: AnimatableBody3D, row: Dictionary) -> void:
	var low := Vector3(row.low[0],row.low[1],row.low[2])
	var high := Vector3(row.high[0],row.high[1],row.high[2])
	assert(low.is_finite() and high.is_finite() and high.x>low.x and high.y>low.y and high.z>low.z)
	var shape := CollisionShape3D.new()
	shape.name = str(row.name)
	var box := BoxShape3D.new()
	box.size = high-low
	shape.shape = box
	shape.position = (low+high)*.5+Vector3.BACK*_hinge_offset
	body.add_child(shape)

func _build_leaf() -> void:
	assert(not swing_out) # Native barrel axes are authored for these inward shop leaves.
	assert(is_equal_approx(width,2.0 if paired else 1.0) and is_equal_approx(height,2.30))
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(spec.schema == "orison.v2.arcade-door-leaves.v1" and float(spec.leaf_width_m)==1.0 and float(spec.height_m)==height)
	assert(FileAccess.get_sha256(str(spec.asset))==str(spec.asset_sha256))
	_hinge_offset = HINGE_SETBACK*(-1.0 if swing_out else 1.0)
	_body = AnimatableBody3D.new()
	_body.name = "HingedLeaf"
	_body.position.z = -_hinge_offset
	_body.sync_to_physics = true
	add_child(_body)
	if paired:
		_right_body = AnimatableBody3D.new()
		_right_body.name = "HingedLeafRight"
		_right_body.position = Vector3(width,0,-_hinge_offset)
		_right_body.sync_to_physics = true
		add_child(_right_body)
	_fixed = Node3D.new()
	_fixed.name = "FixedIronmongery"
	add_child(_fixed)
	var expected := {}
	for row: Dictionary in spec.parts:
		assert(not expected.has(str(row.name)))
		expected[str(row.name)] = row
	var source := (load(str(spec.asset)) as PackedScene).instantiate() as Node3D
	var seen := {}
	var materials := {}
	for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var identity := str(draw.name)
		assert(expected.has(identity) and not seen.has(identity))
		var row: Dictionary = expected[identity]
		assert(draw.transform.is_equal_approx(Transform3D.IDENTITY) and draw.mesh.get_faces().size()==int(row.triangles)*3)
		seen[identity] = true
		if identity.begins_with("Right") and not paired: continue
		var key := str(row.key)
		if not materials.has(key): materials[key] = _material(key)
		var part := MeshInstance3D.new()
		part.name = identity
		part.mesh = draw.mesh
		part.material_override = materials[key]
		part.set_meta("material_key","glassish" if key=="glass_drawn_expressive" else key)
		if key=="glass_drawn_expressive": part.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		if identity.ends_with("FixedBrass"):
			_fixed.add_child(part)
			if identity.begins_with("Right"): part.position.x=width
		else:
			var body := _right_body if identity.begins_with("Right") else _body
			body.add_child(part)
	assert(seen.size()==expected.size())
	source.free()
	for row: Dictionary in spec.collider_boxes:
		if str(row.side)=="Right":
			if paired: _collision(_right_body,row)
		else:
			assert(str(row.side)=="Left")
			_collision(_body,row)
	StaticMeshBatcher.merge(_fixed)

func apply_hinge_setback() -> void:
	for leaf: Dictionary in motion_leaves():
		for child: Node in leaf.body.get_children():
			if child is MeshInstance3D: child.position.z+=_hinge_offset
