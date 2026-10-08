extends RefCounted
## Visual payloads only. Original mesh nodes retain animation, material state,
## child lettering, sounds, reach areas and every gameplay reference.
const PATH := "res://data/orison_v2/service_instruments.json"
const BAR_PATH := "res://data/orison_v2/bar_instruments.json"
var installed: Dictionary = {}
var errors: Array[String] = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var work_light_parts: Dictionary = {}

func mount(world: Node, data_path: String = PATH) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if data is not Dictionary or data.get("schema_version")!=1: return false
	var scene := load(str(data.asset)) as PackedScene
	if scene==null: return false
	var model := scene.instantiate()
	for spec: Dictionary in data.materials:
		var key := str(spec.key)
		var material := MatLib.get_mat(str(spec.catalog)).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE/float(spec.tile)
		material.normal_scale = float(spec.normal)
		material.roughness = float(spec.roughness)
		material.metallic = float(spec.metallic)
		material.albedo_color = Color(spec.tint[0],spec.tint[1],spec.tint[2],spec.tint[3])
		_materials[key] = material
	for spec: Dictionary in data.source_materials:
		var owner:=world.find_child(str(spec.actor),true,false)
		var draws:=owner.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.mesh!=null)
		_materials[str(spec.key)]=draws[int(spec.index)].get_active_material(0)
	var prepared: Array[Dictionary] = []
	for part: Dictionary in data.dumbwaiter_ropes: _prepare_mesh(model,part,true)
	for part: Dictionary in data.work_lights:
		_prepare_mesh(model,part,false)
		work_light_parts[str(part.variant)]={"mesh":_meshes[str(part.mesh)],"seat":Vector3(part.seat[0],part.seat[1],part.seat[2]),"normal":Vector3(part.normal[0],part.normal[1],part.normal[2])}
	for row: Dictionary in data.actors:
		var actor := world.find_child(str(row.id),true,false) as Node3D
		if actor==null or actor.get_script().resource_path!=str(row.script):
			errors.append("source owner: "+str(row.id)); continue
		var draws := actor.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.mesh!=null)
		if draws.size()!=int(row.source_mesh_count):
			errors.append("source mesh count: "+str(row.id)); continue
		for part: Dictionary in row.replacements:
			var index := int(part.index)
			if index<0 or index>=draws.size(): errors.append("source index"); continue
			var draw: MeshInstance3D = draws[index]
			if draw.mesh.get_class()!=str(part.source_type): errors.append("source shape: "+str(row.id)); continue
			if not part.size.is_empty() and not (draw.mesh as BoxMesh).size.is_equal_approx(Vector3(part.size[0],part.size[1],part.size[2])):
				errors.append("source size: "+str(row.id)); continue
			if not str(part.mesh).is_empty(): _prepare_mesh(model,part,bool(part.preserve_material))
		for part: Dictionary in row.additions: _prepare_mesh(model,part,false)
		prepared.append({"actor":actor,"row":row,"draws":draws,"areas":actor.find_children("*","Area3D",true,false).map(func(n):return n.get_instance_id())})
	model.free()
	if not errors.is_empty(): return false
	# Preflight the whole batch before replacing any payload.
	for entry in prepared:
		var actor: Node3D = entry.actor
		var snapshots: Array[Dictionary] = []
		for part: Dictionary in entry.row.replacements:
			var draw: MeshInstance3D = entry.draws[int(part.index)]
			var original := draw.get_active_material(0)
			snapshots.append({"draw":weakref(draw),"transform":draw.transform,"parent":draw.get_parent().get_instance_id(),"material":original,"preserve_material":part.preserve_material,"replacement":part.mesh})
			draw.mesh = null if str(part.mesh).is_empty() else _meshes[str(part.mesh)]
			draw.material_override = original if part.preserve_material else null
			draw.set_meta("native_service_instrument_part",str(part.mesh))
		for part: Dictionary in entry.row.additions:
			var draw := MeshInstance3D.new()
			draw.name = str(part.mesh)
			draw.mesh = _meshes[str(part.mesh)]
			actor.add_child(draw)
		installed[str(entry.row.id)] = {"actor":weakref(actor),"source":snapshots,"script":entry.row.script,"areas":entry.areas}
		actor.set_meta("v2_native_service_instrument",true)
		if actor is DumbwaiterProp:
			var ropes:=preload("res://scripts/building/orison_v2_dumbwaiter_rope_visual.gd").new()
			ropes.name="NativeSuspensionRopes"
			actor.add_child(ropes)
			ropes.configure(actor,_meshes["DumbwaiterRopeUnit"],_meshes["DumbwaiterHandReturn"])
	return true

func _prepare_mesh(model: Node, part: Dictionary, preserve_material: bool) -> void:
	var name := str(part.mesh)
	var draw := model.find_child(name,true,false) as MeshInstance3D
	if draw==null:
		errors.append("native partition: "+name); return
	var mesh := draw.mesh.duplicate() as ArrayMesh
	if not preserve_material and mesh.get_surface_count()!=part.materials.size():
		errors.append("native materials: "+name); return
	for i in mesh.get_surface_count():
		if preserve_material:
			mesh.surface_set_material(i,null)
			continue
		var key := str(part.materials[i])
		if not preserve_material and not _materials.has(key): errors.append("catalog material: "+key); return
		mesh.surface_set_material(i,null if preserve_material else _materials[key])
	_meshes[name] = mesh
