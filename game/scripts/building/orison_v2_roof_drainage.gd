extends RefCounted
## Fit native falls and weather interfaces while retaining original actors,
## floor/wall bodies, fan registers, doors and household state authority.
var world: Node3D
var prototype: Node3D
var prototype_fixture: Dictionary
var port_fixture: Dictionary
var ports_model: Node3D
var leader_model: Node3D
var receiver_model: Node3D
var original_floor_shapes: Dictionary={}
var errors: Array[String]=[]

func mount(runtime: Node3D) -> bool:
	world=runtime
	var root: Node3D=world.adapter.root
	_mount_field(root)
	_mount_ports(root)
	_mount_leaders(root)
	_mount_plant(root)
	_mount_doors(root)
	_mount_receivers(root)
	return errors.is_empty()

func _require(condition: bool,description: String) -> bool:
	if not condition:errors.append(description);push_error("Roof drainage composition: "+description)
	return condition

func _mount_field(root: Node3D) -> void:
	prototype_fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_falls.json"))
	_require(FileAccess.get_sha256("res://assets/props/roof_drainage_falls.glb")==prototype_fixture.asset_sha256,"source route binds its actual native export")
	prototype=(load("res://assets/props/roof_drainage_falls.glb") as PackedScene).instantiate()
	prototype.name="RoofFalls";root.add_child(prototype)
	var draws: Array[Node]=prototype.find_children("*","MeshInstance3D",true,false)
	draws.sort_custom(func(a: Node,b: Node) -> bool:return str(a.name).ends_with("__PhysicalEnvelope") and not str(b.name).ends_with("__PhysicalEnvelope"))
	for draw: MeshInstance3D in draws:
		var identity: String=str(draw.name).split("__")[0]
		var kind: String=str(draw.name).split("__")[-1]
		if "PhysicalEnvelope" in kind:
			draw.hide()
			var owner: String=identity
			if kind!="PhysicalEnvelope":
				var spec: Dictionary=_door_spec(identity)
				owner=str(spec.exterior_floor_owner if kind=="ExteriorPhysicalEnvelope" else spec.interior_floor_owner)
			var floor: MeshInstance3D=_floor(owner)
			var body:=floor.get_node("Collision") as StaticBody3D
			if not original_floor_shapes.has(body.get_rid()):original_floor_shapes[body.get_rid()]=body.get_child_count()
			var shape:=CollisionShape3D.new();var native:=ConcavePolygonShape3D.new()
			native.set_faces((body.global_transform.affine_inverse()*draw.global_transform)*_actual_faces(draw.mesh));shape.shape=native;body.add_child(shape)
		elif kind=="FittedHead":
			var spec: Dictionary=_door_spec(identity)
			var head: MeshInstance3D=root.get_node(spec.head_owner)
			var retained: Material=head.material_override if head.material_override!=null else head.mesh.surface_get_material(0)
			head.mesh=draw.mesh;head.transform=root.global_transform.affine_inverse()*draw.global_transform;head.material_override=retained
			var body:=head.get_node("Collision") as StaticBody3D
			for child: CollisionShape3D in body.get_children():child.free()
			# This source-owned fitted head remains an axis-aligned solid box.
			# Keep its original convex collision representation, fitted to the
			# actual native box bounds.
			var shape:=CollisionShape3D.new();var bounds:=draw.mesh.get_aabb();var exact:=BoxShape3D.new();exact.size=bounds.size;shape.position=bounds.get_center();shape.shape=exact;body.add_child(shape);draw.hide()
		else:
			var key: String="roof_bitumen" if kind.begins_with("Field_") else "galvanized_roof" if kind=="CurbCap" else "concrete"
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;draw.material_override=material
			if kind.begins_with("Field_"):
				draw.hide()
				for surface in draw.mesh.get_surface_count():
					var normals: PackedVector3Array=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
					var valid_normals:=true
					for normal: Vector3 in normals:
						if (draw.global_basis*normal).y<.999:valid_normals=false
					_require(valid_normals,"native field faces look upward with normal material culling: "+str(draw.name))
	for spec: Dictionary in prototype_fixture.door_fittings:
		var leaf:=_leaf(spec.id)
		# An already synchronized AnimatableBody keeps its old world pose when
		# a parent is relocated during startup. Publish the fitted parent pose
		# before restoring the original door's physics synchronization.
		leaf._body.sync_to_physics=false
		var anchor: Node3D=root.get_node(spec.id);anchor.position.y+=float(spec.candidate_mount_offset)
		leaf.position.z+=float(spec.fitted_leaf_normal_offset_m)
		leaf._body.force_update_transform()
		leaf._body.sync_to_physics=true
		_require(leaf!=null and leaf.width==spec.source_record.width and leaf.height==spec.source_record.height,"retained moving leaf and clear opening: "+str(spec.id))
	# Import order must not let a later field envelope clear its curb shape.
	for spec: Dictionary in prototype_fixture.door_fittings:
		var body: StaticBody3D=root.get_node(str(spec.exterior_floor_owner)+"/Floor/Collision")
		_require(body.get_child_count()==int(original_floor_shapes[body.get_rid()])+2,"retained slab, field and outdoor curb share their original floor owner: "+str(spec.id))

func _mount_ports(root: Node3D) -> void:
	port_fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_ports.json"))
	_require(FileAccess.get_sha256("res://assets/props/roof_drainage_ports.glb")==port_fixture.asset_sha256,"composed inspection binds the actual ports")
	ports_model=(load("res://assets/props/roof_drainage_ports.glb") as PackedScene).instantiate();ports_model.name="RoofPorts";root.add_child(ports_model)
	for draw: MeshInstance3D in ports_model.find_children("*","MeshInstance3D",true,false):
		var identity: String=str(draw.name).split("__")[0]
		var kind: String=str(draw.name).split("__")[-1]
		if kind=="NotchedWall":
			var wall: MeshInstance3D=root.get_node(identity)
			var material: Material=(wall.material_override if wall.material_override!=null else wall.mesh.surface_get_material(0)).duplicate()
			var key: String=str(wall.get_meta("v2_material_key","brick"))
			if material is StandardMaterial3D:
				(material as StandardMaterial3D).uv1_triplanar=false
			elif material is ShaderMaterial:
				(material as ShaderMaterial).set_shader_parameter("uv_mode",0)
				(material as ShaderMaterial).set_shader_parameter("mesh_uv_scale",Vector2.ONE/float(MatLib.SETS[key][3]))
			print("SOURCE PARAPET MATERIAL ",identity," ",wall.get_meta("v2_material_key","unknown")," ",material.resource_name)
			wall.mesh=draw.mesh;wall.transform=root.global_transform.affine_inverse()*draw.global_transform;wall.material_override=material
			var body:=wall.get_node("Collision") as StaticBody3D
			for shape: CollisionShape3D in body.get_children():shape.free()
			var shape:=CollisionShape3D.new();var exact:=ConcavePolygonShape3D.new();exact.set_faces(_actual_faces(draw.mesh));shape.shape=exact;body.add_child(shape);draw.hide()
		else:
			var key: String="galvanized_roof" if kind=="Channel" else "concrete"
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;draw.material_override=material;_fixed_shape(ports_model,draw)
func _mount_leaders(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_leaders.json"))
	_require(FileAccess.get_sha256("res://assets/props/roof_drainage_leaders.glb")==fixture.asset_sha256,"source leader inspection binds the actual export")
	leader_model=(load("res://assets/props/roof_drainage_leaders.glb") as PackedScene).instantiate();leader_model.name="RoofLeaders";root.add_child(leader_model)
	var parts:=0
	var expected_keys: Dictionary={}
	for part: Dictionary in fixture.parts:expected_keys[str(part.name)]=str(part.material)
	for draw: MeshInstance3D in leader_model.find_children("*","MeshInstance3D",true,false):
		var key: String=str(expected_keys.get(str(draw.name),"missing"))
		_require(MatLib.SETS.has(key),"bound native leader part has its catalogue key: "+str(draw.name)+" -> "+key)
		var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D;material.uv1_triplanar=false;draw.material_override=material
		_fixed_shape(leader_model,draw);parts+=1
	_require(parts==fixture.parts.size(),"composed leader includes every bounded native part")

func _mount_plant(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_plant_weather.json"))
	var asset: String="res://assets/props/roof_drainage_plant_weather.glb"
	_require(FileAccess.get_sha256(asset)==fixture.asset_sha256,"plant weather binds actual native export")
	var models: Dictionary={};var source_audio: Dictionary={}
	for spec: Dictionary in fixture.fan_curbs:
		var fan:=world.adapter.resolve(spec.id) as ExhaustFanProp
		_require(fan!=null,"actual production fan resolved: "+str(spec.id))
		if fan==null:continue
		models[spec.id]=fan
		var old_root: Transform3D=fan.global_transform;var audio: Dictionary={}
		for emitter: AudioStreamPlayer3D in fan._duct_emitters:audio[str(emitter.name)]=emitter.global_position
		for child in fan.get_children():
			if child is Node3D and not str(child.name).begins_with("Duct_"):(child as Node3D).position.y+=float(spec.machine_offset_y)
		_require(fan.global_transform.is_equal_approx(old_root),"fan anchor and original duct endpoint retained: "+str(spec.id))
		for emitter: AudioStreamPlayer3D in fan._duct_emitters:_require(emitter.global_position.distance_to(audio[str(emitter.name)])<.000005,"room register audio stays at original anchor: "+str(emitter.name))
		source_audio[spec.id]=audio.size()
	var model: Node3D=(load(asset) as PackedScene).instantiate();model.name="RoofPlantWeather";root.add_child(model)
	var keys: Dictionary={}
	for part: Dictionary in fixture.parts:keys[str(part.name)]=str(part.material)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key: String=str(keys.get(str(draw.name),"missing"));_require(MatLib.SETS.has(key),"plant weather has bound catalogue key: "+key)
		var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D;material.uv1_triplanar=false;draw.material_override=material
		if key=="concrete":
			var identity: String=str(draw.name).split("__")[0];var body: StaticBody3D=models[identity].get_node("PlantCollision")
			var shape:=CollisionShape3D.new();var exact:=ConcavePolygonShape3D.new();exact.set_faces((body.global_transform.affine_inverse()*draw.global_transform)*_actual_faces(draw.mesh));shape.shape=exact;body.add_child(shape)

func _mount_doors(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_door_weather.json"))
	var asset: String="res://assets/props/roof_drainage_door_weather.glb";_require(FileAccess.get_sha256(asset)==fixture.asset_sha256,"door weather binds actual native export")
	var model: Node3D=(load(asset) as PackedScene).instantiate();model.name="RoofDoorWeather";root.add_child(model)
	var specs: Dictionary={};var keys: Dictionary={};var blades: Dictionary={}
	for spec: Dictionary in fixture.door_pans:specs[spec.id]=spec
	for part: Dictionary in fixture.parts:keys[str(part.name)]=part
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part: Dictionary=keys.get(str(draw.name),{});var identity: String=str(part.owner).split("__")[0];var key: String=part.material
		_require(MatLib.SETS.has(key),"door weather retains bound catalogue material: "+key);var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D;material.uv1_triplanar=false;draw.material_override=material
		if part.moving:
			var pose: Transform3D=model.global_transform.affine_inverse()*draw.global_transform;var leaf:=_leaf(identity)
			draw.reparent(leaf._body,false);draw.transform=pose;draw.position.z+=leaf._hinge_offset
			if key=="rubber_aged":blades[identity]=draw
		elif part.get("fixed_leaf_local",false):
			var pose: Transform3D=model.global_transform.affine_inverse()*draw.global_transform;draw.reparent(_leaf(identity)._fixed,false);draw.transform=pose
		else:
			prototype.get_node(str(specs[identity].original_cap_stock_replaced)).hide()

func _fixed_shape(parent: Node3D,draw: MeshInstance3D) -> void:
	var body:=StaticBody3D.new();body.name="Collision"
	var shape:=CollisionShape3D.new();var exact:=ConcavePolygonShape3D.new();exact.set_faces(_actual_faces(draw.mesh));shape.shape=exact;body.add_child(shape);draw.add_child(body)

func _v(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])

func _door_spec(identity: String) -> Dictionary:
	for row: Dictionary in prototype_fixture.door_fittings:
		if row.id==identity:return row
	return {}

func _floor(identity: String) -> MeshInstance3D:
	var root: Node3D=world.adapter.root
	return root.get_node(identity+"/Floor") as MeshInstance3D if root.has_node(identity+"/Floor") else root.get_node(identity) as MeshInstance3D

func _actual_faces(mesh: Mesh) -> PackedVector3Array:
	# Mesh.get_faces() uses its snapped triangle-mesh cache. Read the imported
	# position/index arrays to preserve actual thin sheet and joint coordinates.
	var result:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface);var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_INDEX]==null or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():result.append_array(positions)
		else:
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index: int in indices:result.append(positions[index])
	return result

func _leaf(identity: String) -> DoorProp:
	var opening:=world.adapter.resolve(identity) as Node3D
	return opening.get_node_or_null(identity+"_Leaf") as DoorProp if opening!=null else null

func _mount_receivers(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_receivers.json"))
	var asset: String="res://assets/props/roof_drainage_receivers.glb"
	_require(FileAccess.get_sha256(asset)==fixture.asset_sha256,"receiver export binding")
	receiver_model=(load(asset) as PackedScene).instantiate();receiver_model.name="RoofReceivers";root.add_child(receiver_model)
	var keys: Dictionary={}
	for part: Dictionary in fixture.parts:keys[str(part.name)]=str(part.material)
	for draw: MeshInstance3D in receiver_model.find_children("*","MeshInstance3D",true,false):
		var key: String=str(keys.get(str(draw.name),"missing"))
		if not _require(MatLib.SETS.has(key),"receiver catalogue key: "+key):continue
		var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D;material.uv1_triplanar=false;draw.material_override=material;draw.set_meta("material_key",key)
		_fixed_shape(receiver_model,draw)
