extends "res://scripts/props/landmark_entry_door.gd"
## The original landmark hardware and DoorProp motion own the fabricated leaf.
var native_leaf: Node3D

func _ready() -> void:
	leaf_state=DoorKeyring.initial_state(self,leaf_state)
	add_to_group("building_entry")
	_build_materials()
	_build_leaf()
	for draw: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if _body.is_ancestor_of(draw):continue
		draw.position.z=-draw.position.z;draw.rotation.x=-draw.rotation.x;draw.rotation.y=-draw.rotation.y
	StaticMeshBatcher.merge(self,[_body])
	_build_audio()
	apply_hinge_setback()

func _build_materials() -> void:
	super._build_materials()
	_brass=MatLib.get_mat("brass_dull",Color(.66,.52,.33))
	_iron=MatLib.get_mat("cast_iron",Color(.18,.18,.17))

func _build_leaf() -> void:
	_body=AnimatableBody3D.new();_body.name="CenturyOakLeaf";_body.sync_to_physics=true
	_hinge_offset=HINGE_SETBACK
	_body.position.z=-_hinge_offset;add_child(_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(width-.018,height-.018,.064);shape.shape=box
	shape.position=Vector3(width*.5,height*.5,_hinge_offset);_body.add_child(shape)
	_body.add_child(native_leaf);native_leaf.position.z=_hinge_offset
	_build_hardware()
	# V2's front is local -Z. Reflect the original symmetric hardware primitives
	# into that face without negative physics or mesh scale.
	for draw: MeshInstance3D in _body.find_children("*","MeshInstance3D",true,false):
		if native_leaf.is_ancestor_of(draw):continue
		draw.position.z=-draw.position.z;draw.rotation.x=-draw.rotation.x;draw.rotation.y=-draw.rotation.y
	StaticMeshBatcher.merge(_body,[native_leaf])
	if leaf_state=="open":open=true;_body.rotation.y=motion_target_angle(true)
