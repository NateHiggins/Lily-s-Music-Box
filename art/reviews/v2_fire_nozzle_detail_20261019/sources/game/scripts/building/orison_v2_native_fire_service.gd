extends RefCounted
## Original maintenance owners, native visual payloads, and a dedicated gravity line.
const PATH := "res://data/orison_v2/fire_service.json"
var errors: Array[String] = []
var stations: Dictionary = {}
var meshes: Dictionary = {}
var pipe_parts: Array[MeshInstance3D] = []
var source_records: Dictionary = {}
var data: Dictionary
var _root: Node3D

func mount(adapter: RefCounted, layout: Dictionary) -> bool:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1: return false
	if FileAccess.get_file_as_string(data.source_script).replace("\r\n","\n").sha256_text() != data.source_sha256:
		errors.append("fire source drift"); return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("native fire stock missing"); return false
	var model := packed.instantiate()
	var finishes: Dictionary = {}
	for spec: Dictionary in data.materials:
		var mat := MatLib.get_mat(str(spec.catalog)).duplicate() as StandardMaterial3D
		if str(spec.key) == "Brass":
			mat.albedo_texture = load("res://assets/building/textures/mailbank/T_mailbank_brass_albedo.png")
			mat.roughness_texture = load("res://assets/building/textures/mailbank/T_mailbank_brass_rough.png")
		mat.uv1_triplanar = false; mat.uv1_scale = Vector3.ONE / float(spec.tile)
		mat.normal_scale = float(spec.normal); mat.roughness = float(spec.roughness); mat.metallic = float(spec.metallic)
		mat.albedo_color = Color(spec.tint[0],spec.tint[1],spec.tint[2],spec.tint[3])
		finishes[str(spec.key)] = mat
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for index in mesh.get_surface_count():
			var key := str(mesh.surface_get_material(index).resource_name)
			if not finishes.has(key): errors.append("fire finish " + key); continue
			mesh.surface_set_material(index,finishes[key])
		meshes[str(node.name)] = mesh
	model.free()
	# The right-facing successor retains the original inlet datum and source
	# fact selector, with a properly receiving socket and coaxial hose entry.
	var nozzle_packed:=load("res://assets/props/fire_nozzle_hose.glb") as PackedScene
	if nozzle_packed==null:errors.append("native nozzle hose missing");return false
	var nozzle_model:=nozzle_packed.instantiate()
	for draw: MeshInstance3D in nozzle_model.find_children("*","MeshInstance3D",true,false):
		var mesh: ArrayMesh=draw.mesh.duplicate() as ArrayMesh
		for index in mesh.get_surface_count():
			var key: String=mesh.surface_get_material(index).resource_name
			if not finishes.has(key):errors.append("nozzle hose finish "+key);continue
			mesh.surface_set_material(index,finishes[key])
		meshes[str(draw.name)]=mesh
	nozzle_model.free()
	if not errors.is_empty(): return false
	var nozzle_detail:=preload("res://scripts/props/fire_nozzle_detail_stock.gd").new()
	if not nozzle_detail.load_stock():errors.append("detailed nozzle stock missing");return false
	_root = Node3D.new(); _root.name = "NativeFireService"
	adapter.root.add_child(_root)
	for identity: String in data.stations:
		var actor := preload("res://scripts/props/v2_fire_line_cabinet.gd").new(); actor.station_id = identity
		if not adapter.mount_consumer(identity,actor): actor.free(); errors.append("fire anchor " + identity); return false
		var draws := actor.find_children("*","MeshInstance3D",true,false).filter(func(n): return n.mesh != null)
		if draws.size() != data.parts.size(): errors.append("fire source count " + identity); return false
		for part: Dictionary in data.parts:
			if draws[int(part.index)].mesh.get_class() != str(part.type): errors.append("fire source shape " + identity); return false
		var records: Array = []
		for part: Dictionary in data.parts:
			var draw: MeshInstance3D = draws[int(part.index)]
			records.append({"draw":weakref(draw),"parent":draw.get_parent().get_instance_id(),"transform":draw.transform})
			var key := "F%03d" % int(part.index)
			draw.mesh = null if int(part.index) == 58 else meshes.get(key); draw.material_override = null
			draw.set_meta("native_fire_part",key)
			if part.has("collision_size"):
				var body := StaticBody3D.new(); body.name = "NativeCaseCollision"; draw.add_child(body)
				var shape := BoxShape3D.new(); var size: Array = part.collision_size
				shape.size = Vector3(size[0],size[1],size[2])
				var collider := CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
			if str(part.name).begins_with("Fold_"):
				var crown := _draw("FoldCrown",draw,Vector3(0,.131,0)); crown.name = "NativeFoldCrown"
		var folds:=preload("res://scripts/props/fire_fold_stock.gd").new();folds.name="NativeContinuousFolds";actor.add_child(folds)
		if not folds.configure(actor):errors.append("continuous native folds "+identity);return false
		# Retire the two unaligned pins and bar, retaining every original node.
		for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if str(draw.get_meta("native_fire_part","")) in ["F034","F035","F036"]:
				draw.mesh=null;draw.set_meta("native_fire_successor","fire_hose_rack")
		var rack:=preload("res://scripts/props/fire_hose_rack.gd").new();rack.name="NativeHoseRack";actor.add_child(rack)
		if not rack.configure(actor):errors.append("fitted native fire rack "+identity);return false
		if not actor.install_joint_stock(meshes.NozzleSocket): errors.append("fire swivel stock " + identity); return false
		var hoses := preload("res://scripts/building/orison_v2_fire_hose_visual.gd").new()
		hoses.name = "NativeHoseRuns"; actor.add_child(hoses)
		if not hoses.configure(actor,meshes): errors.append("fire hose stock " + identity); return false
		if not nozzle_detail.fit(actor):errors.append("detailed nozzle fitting "+identity);return false
		if not actor.install_native_hand_controls(): errors.append("fire hand stock " + identity); return false
		if not actor.install_nozzle_joint():errors.append("physical nozzle joint "+identity);return false
		stations[identity] = weakref(actor); source_records[identity] = records
		var at: Vector3 = actor.position + actor.basis * Vector3(.540,.350,.140)
		_draw("StationTee",_root,at,actor.basis)
	var reserve := adapter.root.find_child("FIRE_SERVICE_RISER",true,false) as MeshInstance3D
	if reserve == null: errors.append("fire reservation missing"); return false
	reserve.mesh = null
	# Segments terminate at the actual open tees; no hidden solid branch blockers.
	var intervals: Array = [{"low":18.62,"high":18.82}]
	for identity: String in stations:
		var actor: Node3D = stations[identity].get_ref()
		intervals.append({"low":actor.position.y+.305,"high":actor.position.y+.395})
	intervals.sort_custom(func(a,b): return a.low < b.low)
	var low := -3.2
	for interval: Dictionary in intervals:
		_segment(Vector3(4.89,low,-3.64),Vector3(4.89,interval.low,-3.64))
		low = float(interval.high)
	_segment(Vector3(4.89,low,-3.64),Vector3(4.89,20.92,-3.64))
	_draw("FeedTee",_root,Vector3(4.89,18.72,-3.64))
	_draw("FootCap",_root,Vector3(4.89,-3.1875,-3.64))
	_draw("FootCap",_root,Vector3(4.89,20.9325,-3.64))
	for level: Dictionary in layout.levels:
		for offset: float in [.18,2.90]:
			var y := float(level.y)+offset
			if y > 20.8: continue
			var basis := Basis.IDENTITY
			_draw("WallSaddle",_root,Vector3(4.89,y,-3.64),basis)
			for x: float in [-.034,.034]:
				for h: float in [-.035,.035]:
					_draw("SaddleBolt",_root,Vector3(4.89,y,-3.64)+basis*Vector3(x,h,-.122),basis)
			_draw("UnionCollar",_root,Vector3(4.89,y+.12,-3.64))
	var points: Array[Vector3] = []
	for point: Array in data.feed_points: points.append(Vector3(point[0],point[1],point[2]))
	var start := points[0]
	for i in range(1,points.size()-1):
		var incoming := (points[i]-points[i-1]).normalized()
		var outgoing := (points[i+1]-points[i]).normalized()
		_segment(start,points[i]-incoming*.18)
		_draw("PipeElbow",_root,points[i]-incoming*.18,Basis(outgoing,incoming,outgoing.cross(incoming)))
		start = points[i]+outgoing*.18
	_segment(start,points.back())
	# Roof underside support, positive contact with the existing slab underside.
	for at: Vector3 in [Vector3(-8.6,18.775,-4.3),Vector3(-7.4,18.775,-3.64),Vector3(-4.,18.775,-3.64),Vector3(0.,18.775,-3.64),Vector3(4.,18.775,-3.64)]:
		_draw("UnionCollar",_root,at-Vector3(0,.055,0),Basis(Vector3.FORWARD,PI*.5))
		var rod := _draw("HangerRod",_root,at+Vector3(0,.1115,0))
		rod.mesh = _length_mesh(meshes.HangerRod,.223)
		_draw("CeilingSeat",_root,Vector3(at.x,18.998,at.z))
	return errors.is_empty()

func _draw(key: String, parent: Node3D, at: Vector3, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var draw := MeshInstance3D.new(); draw.name = key; draw.mesh = meshes[key]
	parent.add_child(draw); draw.transform = Transform3D(basis,at)
	draw.set_meta("native_fire_part",key); pipe_parts.append(draw)
	return draw

func _segment(a: Vector3,b: Vector3) -> void:
	var length := a.distance_to(b)
	if length <= .001: errors.append("empty pipe span"); return
	var direction := (b-a)/length
	var axis := Vector3.UP.cross(direction)
	var basis := Basis.IDENTITY
	if axis.length_squared() > .000001: basis = Basis(axis.normalized(),acos(Vector3.UP.dot(direction)))
	elif direction.y < 0: basis = Basis(Vector3.RIGHT,PI)
	var draw := _draw("PipeUnit",_root,(a+b)*.5,basis)
	draw.mesh = _length_mesh(meshes.PipeUnit,length)
	var body := StaticBody3D.new(); body.name = "PipeCollision"; draw.add_child(body)
	var collider := CollisionShape3D.new(); var shape := CylinderShape3D.new()
	shape.radius = .055; shape.height = length; collider.shape = shape; body.add_child(collider)

func _length_mesh(source: ArrayMesh,length: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for index in vertices.size():
			var side_chart: bool = absf(normals[index].y) < maxf(absf(normals[index].x),absf(normals[index].z))
			vertices[index].y *= length
			normals[index] = Vector3(normals[index].x,normals[index].y/length,normals[index].z).normalized()
			if side_chart: uv[index].y *= length
			if tangents.size() == vertices.size()*4:
				var tangent := Vector3(tangents[index*4],tangents[index*4+1]*length,tangents[index*4+2]).normalized()
				tangents[index*4] = tangent.x; tangents[index*4+1] = tangent.y; tangents[index*4+2] = tangent.z
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,source.surface_get_material(surface))
	return result
