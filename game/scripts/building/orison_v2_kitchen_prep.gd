extends RefCounted
## Period-informed native tables, removable sink boards and loose prep tools.
const Station=preload("res://scripts/building/orison_v2_kitchen_prep_station.gd")
const PATH="res://data/orison_v2/kitchen_prep_stations.json"
var errors: Array[String]=[]
var meshes: Dictionary={}
var source: Dictionary

func mount(world: Node3D) -> bool:
	source=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if source.get("schema_version")!=1 or FileAccess.get_sha256(str(source.asset))!=source.get("asset_sha256"):
		errors.append("Kitchen preparation source version/export mismatch");return false
	var model: Node3D=load(source.asset).instantiate()
	for part: Dictionary in source.parts:
		var draw:=model.find_child(part.name,true,false) as MeshInstance3D
		if draw==null:errors.append("Missing prep mesh: "+str(part.name));model.free();return false
		meshes[part.name]=draw.mesh
	model.free()
	for row: Dictionary in source.stations:
		var station:=Station.new();station.name=row.id;station.record=row
		world.adapter.root.add_child(station)
		if row.template=="SinkBridge":
			var sink: TapProp
			for node: Node in world.adapter.root.find_children("*","Node3D",true,false):
				if node is TapProp and node.fixture=="kitchen_sink" and node.unit==row.unit:sink=node;break
			if sink==null or sink.compact_kitchen:errors.append("Missing standard sink for bridge: "+str(row.unit));return false
			station.global_transform=sink.global_transform
			_loose(station,"SinkBridge",Vector3(0,sink.kitchen_rim_height()+.0125,-.035),0.)
		else:
			station.position=Vector3(row.position[0],row.position[1],row.position[2]);station.rotation.y=row.yaw
			# Fit to the actual finished support plane before adding table collision.
			var template: Dictionary={}
			for candidate: Dictionary in source.templates:
				if candidate.id==row.template:template=candidate;break
			var heights: Array[float]=[]
			for x: float in [-float(template.width)/2.+.055,float(template.width)/2.-.055]:
				for z: float in [-float(template.depth)/2.+.055,float(template.depth)/2.-.055]:
					var foot: Vector3=station.to_global(Vector3(x,0,z))
					var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.045,foot-Vector3.UP*.045))
					if hit.is_empty():errors.append("Unsupported prep leg: "+str(row.id));return false
					heights.append(hit.position.y)
			if heights.max()-heights.min()>.00004:errors.append("Uneven prep bearings: "+str(row.id));return false
			station.global_position.y=heights[0]
			var table:=StaticBody3D.new();table.name="Worktable";station.add_child(table)
			_visuals(table,str(row.template),row.tint,true)
			_loose(station,"Breadboard",Vector3(-.12,.9,0),float(row.tool_yaw))
			if row.rolling_pin:_loose(station,"RollingPin",Vector3(-.12,.95,0),float(row.tool_yaw))
			if row.bowl:_loose(station,"MixingBowl",Vector3(float(template.width)*.30,.9,float(template.depth)*.20),0.)
	return true

func _visuals(parent: Node3D,assembly: String,tint: Array,collision: bool) -> void:
	for part: Dictionary in source.parts:
		if part.assembly!=assembly:continue
		var draw:=MeshInstance3D.new();draw.name=part.name;draw.mesh=meshes[part.name]
		var material:=MatLib.get_mat(str(part.key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/float(MatLib.SETS[str(part.key)][3])
		material.normal_enabled=true;material.normal_scale=.35
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if part.key in ["oak_work_surface","door_paint"]:material.albedo_color=Color(tint[0],tint[1],tint[2])
		draw.material_override=material;parent.add_child(draw)
		if collision:
			var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();parent.add_child(shape)

func _loose(station: Node3D,assembly: String,at: Vector3,yaw: float) -> void:
	var body:=RigidBody3D.new();body.name=assembly;body.position=at;body.rotation.y=yaw
	# Authored, bearing-fitted rests start stationary. Waking all touching
	# convex stocks simultaneously otherwise injects a Jolt startup impulse.
	body.freeze=true
	body.mass=1.6 if assembly=="SinkBridge" else (.65 if assembly=="Breadboard" else .35)
	body.continuous_cd=true;body.contact_monitor=true;body.max_contacts_reported=8
	var friction:=PhysicsMaterial.new();friction.friction=.85;body.physics_material_override=friction
	station.add_child(body);station.tools[assembly]=body
	station.hulls[assembly]=source.tool_hulls[assembly]
	_visuals(body,assembly,station.record.tint,false)
	for points: Array in source.tool_hulls[assembly]:
		var hull:=ConvexPolygonShape3D.new();var vertices:=PackedVector3Array()
		for point: Array in points:vertices.append(Vector3(point[0],point[1],point[2]))
		hull.points=vertices;hull.margin=.0001
		var shape:=CollisionShape3D.new();shape.shape=hull;body.add_child(shape)
