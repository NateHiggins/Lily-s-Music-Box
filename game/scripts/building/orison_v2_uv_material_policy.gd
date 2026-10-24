extends Node
## Use existing authored UV charts. Keep material identity so live controls
## retain their original references; restore shared defaults at world teardown.
var root: Node
var changed_materials: Dictionary = {}
var _record_ids: Array[int] = []
var _prune_cursor := 0
var inspected_draws := 0

func setup(world: Node) -> void:
	root = world
	get_tree().node_added.connect(_node_added)
	inspect_branch(root)
	print("V2 UV APPLICATION: initial corrected materials=",changed_materials.size())

func _node_added(node: Node) -> void:
	if node is GeometryInstance3D and is_instance_valid(root) and root.is_ancestor_of(node):
		# Factories commonly assign materials immediately after add_child().
		call_deferred("_inspect_added", weakref(node))

func _inspect_added(reference: WeakRef) -> void:
	var node := reference.get_ref() as Node
	if node != null and is_instance_valid(root) and root.is_ancestor_of(node):
		_inspect(node)

func inspect_branch(branch: Node) -> void:
	_inspect(branch)
	for node: Node in branch.find_children("*", "GeometryInstance3D", true, false):
		_inspect(node)

func _inspect(node: Node) -> void:
	var mesh: Mesh
	if node is MeshInstance3D:
		mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
	elif node is CPUParticles3D:
		mesh = node.mesh
	elif node is GPUParticles3D:
		for index in node.draw_passes:
			_inspect_mesh(node,node.get_draw_pass_mesh(index))
		return
	else:
		return
	_inspect_mesh(node,mesh)

func _inspect_mesh(node: GeometryInstance3D, mesh: Mesh) -> void:
	if mesh == null: return
	inspected_draws += 1
	_apply(node.material_overlay)
	for index in mesh.get_surface_count():
		var material: Material = node.material_override
		if material == null and node is MeshInstance3D:
			material = node.get_surface_override_material(index)
		if material == null: material = mesh.surface_get_material(index)
		_apply(material)

func _apply(material: Material) -> void:
	if material == null: return
	var identity := material.get_instance_id()
	if material is StandardMaterial3D and (material.uv1_triplanar or material.uv2_triplanar):
		if not changed_materials.has(identity):
			_remember(material,{"uv1":material.uv1_triplanar,"uv2":material.uv2_triplanar})
		material.uv1_triplanar = false
		material.uv2_triplanar = false
	elif material is ShaderMaterial and material.shader != null and material.shader.code.contains("orison_surface.gdshaderinc"):
		var mode: Variant = material.get_shader_parameter("uv_mode")
		if mode == null or int(mode) != 0:
			if not changed_materials.has(identity):
				_remember(material,{"mode":mode})
			material.set_shader_parameter("uv_mode",0)
	if material.next_pass != null: _apply(material.next_pass)

func _remember(material: Material, state: Dictionary) -> void:
	# Shared materials remain owned by their real consumers. A restoration
	# record must not keep retired local shaders and their textures alive.
	var identity:=material.get_instance_id()
	state["material"]=weakref(material)
	changed_materials[identity]=state
	_record_ids.append(identity)
	# Constant work per newly corrected material; avoid periodic full sweeps.
	for step in 4:
		if _record_ids.is_empty():break
		_prune_cursor%= _record_ids.size()
		var key:=_record_ids[_prune_cursor]
		var reference: WeakRef=changed_materials[key].material
		if reference.get_ref()==null:
			changed_materials.erase(key)
			_record_ids[_prune_cursor]=_record_ids[-1];_record_ids.pop_back()
		else:_prune_cursor+=1

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	for row: Dictionary in changed_materials.values():
		var material: Material = (row.material as WeakRef).get_ref() as Material
		if material==null:continue
		if row.has("mode"):
			(material as ShaderMaterial).set_shader_parameter("uv_mode",row.mode)
		else:
			(material as StandardMaterial3D).uv1_triplanar = row.uv1
			(material as StandardMaterial3D).uv2_triplanar = row.uv2
	changed_materials.clear()
	_record_ids.clear();_prune_cursor=0
