extends RefCounted
## Native fitted plumbing; retained TapProp owns water and basin behavior.
const PATH="res://data/orison_v2/kitchen_plumbing.json"
const Owner=preload("res://scripts/building/orison_v2_kitchen_plumbing_owner.gd")
var errors: Array[String]=[]
var source: Dictionary
var meshes: Dictionary={}

func load_source() -> bool:
	source=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if source.get("schema_version")!=1 or FileAccess.get_sha256(str(source.asset))!=source.get("asset_sha256"):
		errors.append("Kitchen plumbing source/export mismatch");return false
	var model: Node3D=load(str(source.asset)).instantiate()
	for part: Dictionary in source.parts:
		var draw:=model.find_child(str(part.name),true,false) as MeshInstance3D
		if draw==null:model.free();errors.append("Missing plumbing stock: "+str(part.name));return false
		meshes[part.name]=draw.mesh
	model.free();return true

func mount(world: Node3D) -> bool:
	if not load_source():return false
	var sinks: Dictionary={}
	for node: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if node is TapProp and node.fixture=="kitchen_sink":
			if sinks.has(node.unit):errors.append("Duplicate kitchen sink owner");return false
			sinks[node.unit]=node
	if sinks.size()!=source.installations.size():errors.append("Kitchen sink census changed");return false
	for row: Dictionary in source.installations:
		var sink: TapProp=sinks.get(str(row.unit))
		if sink==null or not sink.has_method("kitchen_rim_height"):errors.append("Missing source sink: "+str(row.unit));return false
		var template:=template_for(str(row.template))
		if template.is_empty() or sink.compact_kitchen!=bool(template.compact) or absf(sink.kitchen_rim_height()-float(template.rim_y))>.00004:
			errors.append("Sink variant changed: "+str(row.unit));return false
		var excluded: Array[RID]=[]
		for body: CollisionObject3D in sink.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
		for x: float in [-.095,0.,.095]:
			for y: float in [.22,.64,1.01]:
				var ray:=PhysicsRayQueryParameters3D.create(sink.to_global(Vector3(x,y,.24)),sink.to_global(Vector3(x,y,1.24)),1,excluded)
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or not "/Wall" in str(hit.collider.get_path()) or absf(sink.to_local(hit.position).z-float(template.wall_z))>.00004:
					errors.append("Actual kitchen wall port changed: "+str(row.unit));return false
		install(sink,template)
	return true

func template_for(identity: String) -> Dictionary:
	for row: Dictionary in source.templates:
		if row.id==identity:return row
	return {}

func install(sink: TapProp,template: Dictionary) -> Node3D:
	var owner:=Owner.new();owner.name="KitchenPlumbing_"+sink.unit;owner.tap=sink;owner.record=template
	sink.add_child(owner)
	# Fixed pipes consume collision-only clicks like the retained basin body;
	# they must not fall through to an ancestor's legacy faucet toggle.
	var body:=preload("res://scripts/building/orison_v2_water_controls.gd").FixtureBody.new();body.name="FixedServices";owner.add_child(body)
	_visuals(body,str(template.id),true)
	for index in 2:
		var pivot:=Node3D.new();pivot.name="HotStop" if index==0 else "ColdStop"
		pivot.position=Vector3(-.095 if index==0 else .095,.345,float(template.riser_z)-.065)
		owner.add_child(pivot);_visuals(pivot,"StopWheel",false);owner.wheels.append(pivot)
		preload("res://scripts/props/manipulation_area.gd").install(pivot,func():return owner.grip(index))
	sink.supply_stops=owner;owner.apply_pose();return owner

func _visuals(parent: Node3D,assembly: String,collision: bool) -> void:
	for part: Dictionary in source.parts:
		if part.assembly!=assembly:continue
		var draw:=MeshInstance3D.new();draw.name=part.name;draw.mesh=meshes[part.name]
		var material:=MatLib.get_mat(str(part.key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/float(MatLib.SETS[str(part.key)][3])
		material.normal_enabled=true;material.normal_scale=.18
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		draw.material_override=material;parent.add_child(draw)
		if collision:
			var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();parent.add_child(shape)
