extends RefCounted
## Placements derive from named V2 owner reservations, never legacy coordinates.
const PATH := "res://data/orison_v2/case_one_placement.json"

func mount(adapter: Variant, owner: MinaCaseGameplay) -> bool:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var placements := {}
	for record: Dictionary in source.objects:
		var anchor := adapter.resolve(record.anchor) as Node3D
		if anchor == null or placements.has(record.id): return false
		var offset := Vector3(record.offset[0],record.offset[1],record.offset[2])
		placements[record.id] = Transform3D(adapter.root.global_basis * Basis(Vector3.UP,deg_to_rad(float(record.yaw_degrees))),
				anchor.global_position + adapter.root.global_basis * offset)
	if not owner.place_case_objects(placements): return false
	for record: Dictionary in source.tables:
		var anchor := adapter.resolve(record.anchor) as Node3D
		if anchor == null: return false
		var body := StaticBody3D.new()
		body.name = record.id
		adapter.root.add_child(body)
		body.global_position = anchor.global_position + adapter.root.global_basis * Vector3(
				record.offset[0],record.offset[1],record.offset[2])
		var width := float(record.width)
		var depth := float(record.depth)
		var height := float(record.height)
		_piece(body,Vector3(0,height-.04,0),Vector3(width,.08,depth))
		for x in [-width*.5+.07,width*.5-.07]:
			for z in [-depth*.5+.07,depth*.5-.07]:
				_piece(body,Vector3(x,(height-.08)*.5,z),Vector3(.09,height-.08,.09))
	for i in 3: _evidence_body(owner.evidence_nodes[i],str(owner.EVIDENCE[i].id))
	return true

func _evidence_body(item: CaseInteractable, identity: String) -> void:
	var visual: MeshInstance3D = item.get_node("CaseOwnedObject")
	visual.mesh = null
	visual.position = Vector3.ZERO
	item._visual_home = Vector3.ZERO
	var size := Vector3.ZERO
	if identity == "caption_cards":
		size = Vector3(.18,.018,.11)
		for i in 6:
			_small_box(visual,Vector3(float(i%2)*.002,.002+float(i)*.002,0),Vector3(.176,.002,.108),"paper")
	elif identity == "style_guide":
		size = Vector3(.18,.04,.24)
		_small_box(visual,Vector3(0,.02,0),Vector3(.168,.028,.224),"paper")
		for y in [.003,.037]: _small_box(visual,Vector3(0,y,0),Vector3(.18,.006,.24),"linen")
		_small_box(visual,Vector3(-.087,.02,0),Vector3(.006,.04,.24),"linen")
	else:
		size = Vector3(.20,.015,.018)
		var shaft := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .006
		cylinder.bottom_radius = .006
		cylinder.height = .18
		cylinder.radial_segments = 6
		shaft.mesh = cylinder
		shaft.position.y = .008
		shaft.rotation.z = PI*.5
		shaft.material_override = MatLib.get_mat("wood_dark",Color(.65,.12,.08))
		visual.add_child(shaft)
		_small_box(visual,Vector3(.093,.008,0),Vector3(.012,.003,.003),"metal")
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			(child.shape as BoxShape3D).size = size
			child.position.y = size.y*.5

func _small_box(parent: Node3D, at: Vector3, size: Vector3, material: String) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = MatLib.get_mat(material)
	parent.add_child(visual)

func _piece(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = MatLib.get_mat("wood_dark")
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	body.add_child(collision)
