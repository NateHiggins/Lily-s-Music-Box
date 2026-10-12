extends "res://scripts/props/landmark_entry_door.gd"
## Native fitted locksets; original DoorProp motion, key, save and sound owners.
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
	_brass=MatLib.get_mat("door_brass")
	_iron=MatLib.get_mat("cast_iron",Color(.18,.18,.17))

func _build_hardware() -> void:
	# Locksets and offset pulls are native parts of the actual leaf. Retain
	# the landmark's later repairs without rebuilding its old floating proxy.
	for y in [.26,height*.36,height*.66,height-.26]:
		butt_hinge(_body,y,_brass)
	_box(_body,Vector3(.25,.07,.008),Vector3(width-.20,height-.12,-.036),_iron)
	_box(_body,Vector3(.25,.07,.06),Vector3(width-.20,height-.12,-.07),_iron)
	var arm := _box(_body,Vector3(.36,.018,.018),Vector3(width-.35,height-.065,-.095),_iron)
	arm.rotation.z=-.14
	for x in [.12,width-.12]:
		_box(_body,Vector3(.055,.075,.04),Vector3(x,.94,-.052),_iron)
	_box(_body,Vector3(width-.18,.055,.045),Vector3(width*.5,.94,-.085),_iron)
	# The sealed mail slot remains a repair, not another through-opening.
	_box(_body,Vector3(.34,.105,.012),Vector3(width*.43,.68,.030),_brass)
	_box(_body,Vector3(.27,.035,.006),Vector3(width*.43,.68,.039),_iron)
	# Wall-bearing bell rosette; _ready reflects these local Z coordinates.
	_cylinder(self,.034,.012,Vector3(width+.105,1.16,-.029),_brass,90)
	_cylinder(self,.014,.010,Vector3(width+.105,1.16,-.018),MatLib.get_mat("bakelite_black"),90)

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
