extends RefCounted
const Fan := preload("res://scripts/building/orison_v2_roof_fan.gd")
const DATA := "res://data/orison_v2/completion_interiors.json"
const VARIANTS := {"A":"west_weathered","B":"north_belt","C":"south_repainted","D":"east_oxidised"}
const DUCT_WIDTH := .18

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary: return false
	var graph: Dictionary = parsed.get("ventilation",{})
	var stacks := {}
	var registers := {}
	var actual := {}
	for record: Dictionary in layout.anchors:
		if str(record.id).ends_with("_VENT_REGISTER"): actual[str(record.id)] = true
	for record: Dictionary in graph.get("stacks",[]):
		var id := str(record.get("id",""))
		if not VARIANTS.has(id) or stacks.has(id) or record.get("riser",[]).size()!=2: return false
		if record.get("branch_axis","") not in ["xz","zx"]: return false
		stacks[id] = record
		registers[id] = []
	if stacks.size()!=4: return false
	for record: Dictionary in graph.get("registers",[]):
		var id := str(record.get("anchor",""))
		var stack := str(record.get("stack",""))
		if not actual.has(id) or not registers.has(stack): return false
		actual.erase(id)
		var anchor := adapter.resolve(id) as Node3D
		if anchor==null: return false
		registers[stack].append(anchor)
	if not actual.is_empty(): return false
	for stack: String in registers:
		if registers[stack].is_empty(): return false
		if adapter.resolve("ROOF_VENT_FAN_"+stack)==null: return false
	# Validate the entire assignment before attaching geometry or sound owners.
	var ducts := Node3D.new()
	ducts.name = "VentilationDucts"
	adapter.root.add_child(ducts)
	for stack: String in registers:
		var fan := Fan.new()
		fan.riser = "V-"+stack
		fan.fan_variant = VARIANTS[stack]
		fan.prop_type = "exhaust_fan"
		if not adapter.mount_consumer("ROOF_VENT_FAN_"+stack,fan):
			fan.free()
			return false
		var anchors: Array[Node3D] = []
		anchors.assign(registers[stack])
		fan.bind_registers(anchors)
		_build_stack(ducts,stack,stacks[stack],anchors,fan)
	return true

func _build_stack(root: Node3D, id: String, spec: Dictionary, anchors: Array[Node3D], fan: Node3D) -> void:
	var stack := StaticBody3D.new()
	stack.name = "Stack_"+id
	root.add_child(stack)
	var sections: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	var roof := root.to_local(fan.global_position)
	var top := Vector3(float(spec.riser[0]),roof.y-.22,float(spec.riser[1]))
	var lowest := top.y
	var roster: Array[String] = []
	for anchor: Node3D in anchors:
		roster.append(str(anchor.name))
		_build_register(anchor)
		var grille := root.to_local(anchor.global_position)
		var start := grille+Vector3.UP*.09
		lowest = minf(lowest,start.y)
		var end := Vector3(top.x,start.y,top.z)
		var corner := Vector3(end.x,start.y,start.z) if str(spec.branch_axis)=="xz" else Vector3(start.x,start.y,end.z)
		_piece(stack,sections,grille+Vector3.UP*.045,Vector3(.36,.09,.34))
		_segment(stack,sections,seams,start,corner)
		_segment(stack,sections,seams,corner,end)
	stack.set_meta("registers",roster)
	_segment(stack,sections,seams,Vector3(top.x,lowest,top.z),top)
	var roof_corner := Vector3(roof.x,top.y,top.z)
	var roof_end := Vector3(roof.x,top.y,roof.z)
	_segment(stack,sections,seams,top,roof_corner)
	_segment(stack,sections,seams,roof_corner,roof_end)
	_segment(stack,sections,seams,roof_end,roof+Vector3.UP*.08)
	_draw(stack,"SheetMetal",sections,"metal")
	_draw(stack,"SeamBands",seams,"cast_iron")

func _segment(body: StaticBody3D, sections: Array[Transform3D], seams: Array[Transform3D], a: Vector3, b: Vector3) -> void:
	var delta := (b-a).abs()
	if delta.length()<.001: return
	var axis := delta.max_axis_index()
	var size := Vector3.ONE*DUCT_WIDTH
	size[axis] = delta[axis]+DUCT_WIDTH
	_piece(body,sections,(a+b)*.5,size)
	var bands := maxi(1,int(ceil(delta[axis]/1.2)))
	for i in bands+1:
		var band_size := Vector3.ONE*(DUCT_WIDTH+.014)
		band_size[axis] = .025
		seams.append(Transform3D(Basis.from_scale(band_size),a.lerp(b,float(i)/float(bands))))

func _piece(body: StaticBody3D, sections: Array[Transform3D], at: Vector3, size: Vector3) -> void:
	sections.append(Transform3D(Basis.from_scale(size),at))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	body.add_child(collision)

func _draw(parent: Node3D, label: String, transforms: Array[Transform3D], material: String) -> void:
	var draw := MultiMeshInstance3D.new()
	draw.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = MatLib.get_mat(material)
	draw.multimesh = MultiMesh.new()
	draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	draw.multimesh.mesh = mesh
	draw.multimesh.instance_count = transforms.size()
	for i in transforms.size(): draw.multimesh.set_instance_transform(i,transforms[i])
	parent.add_child(draw)

func _build_register(anchor: Node3D) -> void:
	# Passive painted grille; the production roof motor owns its bearing tone.
	for index in 9:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.36,.018,.018)
		bar.mesh = mesh
		bar.position = Vector3(0,0,-.14+float(index)*.035)
		bar.material_override = MatLib.get_mat("trim")
		anchor.add_child(bar)
	for side in [-1.0,1.0]:
		var frame := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.022,.022,.34)
		frame.mesh = mesh
		frame.position.x = side*.18
		frame.material_override = MatLib.get_mat("trim")
		anchor.add_child(frame)
