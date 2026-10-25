extends DoorProp
## Fitted presentation and easy bounded motion, retaining DoorProp's hand/lock/save owners.
const NATIVE := preload("res://assets/props/passage_shop_leaves.glb")
const Glass := preload("res://scripts/building/orison_v2_expressive_glass.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

func _build_storefront() -> void:
	assert(is_equal_approx(width,.95) and is_equal_approx(height,2.10))
	if _meshes.is_empty():
		var source := NATIVE.instantiate()
		for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			_meshes[str(draw.name)]=draw.mesh
		source.free()
	if _materials.is_empty():
		_materials.wood=MatLib.get_mat("door_oak").duplicate()
		_materials.brass=MatLib.get_mat("door_brass").duplicate()
		_materials.glass=Glass.make("glass_drawn_expressive")
		for key: String in ["wood","brass"]: _materials[key].uv1_triplanar=false
	var shell := _body.get_child(0) as CollisionShape3D
	# Keep the original upper bearing; give the lower edge 6 mm over the terrazzo.
	shell.shape.size=Vector3(width-.02,height-.026,.044)
	shell.position.y+=.003
	for identity: String in _meshes:
		var part:=MeshInstance3D.new();part.name=identity;part.mesh=_meshes[identity]
		var pull := identity.begins_with("Pull") or identity.begins_with("Stand")
		part.material_override=_materials.brass if pull else _materials.glass if identity=="Glazing" else _materials.wood
		_body.add_child(part)
		if pull:
			var bounds: AABB=part.mesh.get_aabb()
			var shape:=CollisionShape3D.new();shape.name=identity+"Collision"
			var box:=BoxShape3D.new();box.size=bounds.size
			shape.shape=box;shape.position=bounds.get_center()+Vector3(0,0,_hinge_offset)
			_body.add_child(shape)

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-90.0 if swing_out else 90.0) if want_open else 0.0

func valid_mechanism(value: Variant) -> bool:
	# Accept historical 100-degree saves. The inherited restore clamps them to
	# this leaf's current physical stop, rather than rejecting the complete save.
	return value is Dictionary and value.size()==1 and typeof(value.get("angle")) in [TYPE_FLOAT,TYPE_INT] \
		and is_finite(float(value.angle)) and float(value.angle)>=minf(0,deg_to_rad(-100.0 if swing_out else 100.0))-.000001 \
		and float(value.angle)<=maxf(0,deg_to_rad(-100.0 if swing_out else 100.0))+.000001
