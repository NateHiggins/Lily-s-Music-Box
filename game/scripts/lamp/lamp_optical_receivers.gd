extends RefCounted
## V2-local optical receiver binding. Reserved render layer 18 is illuminated
## only by the carried lamp. Native surfaces retain their own PBR materials.
## Layer 20 belongs to mirrors, Dream portals and the zoo's inspection lights.
const LAYER := 1 << 17
const RECEIVER_META := &"lamp_optical_receiver"
var root: Node
var lamp: Light3D
var field: RefCounted
var pending: Array[WeakRef] = []
var receivers: Dictionary = {}
var lights: Dictionary = {}
var surfaces: Dictionary = {}
var surface_materials: Dictionary = {}
const DREAM_SURFACES := ["res://shaders/dream_fauna.gdshader", "res://shaders/dream_lineage_gold.gdshader", "res://shaders/dream_klimt.gdshader", "res://shaders/dream_tessellate_translucent.gdshader"]
var disposed := false

func setup(owner_root: Node, owner_lamp: Light3D, owner_field: RefCounted) -> void:
	root = owner_root
	lamp = owner_lamp
	field = owner_field
	root.get_tree().node_added.connect(_node_added)
	_scan(root)

func select_lamp(active_lamp: Light3D) -> void:
	if lamp == active_lamp: return
	if is_instance_valid(lamp): lamp.light_cull_mask &= ~LAYER
	lamp = active_lamp
	if is_instance_valid(lamp): lamp.light_cull_mask |= LAYER

func _scan(node: Node) -> void:
	_consider(node)
	for child in node.get_children(): _scan(child)

func _node_added(node: Node) -> void:
	_consider_weak.call_deferred(weakref(node))

func _consider_weak(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node): _consider(node)

func _consider(node: Node) -> void:
	if disposed or not is_instance_valid(node) or not is_instance_valid(root): return
	if node != root and not root.is_ancestor_of(node): return
	if node is Light3D:
		var id := node.get_instance_id()
		if not lights.has(id):
			lights[id] = [weakref(node),node.light_cull_mask]
			node.tree_exiting.connect(_release_light.bind(id),CONNECT_ONE_SHOT)
			node.light_cull_mask = (node.light_cull_mask | LAYER) if node == lamp else (node.light_cull_mask & ~LAYER)
	if node is MeshInstance3D and node.has_meta(RECEIVER_META):
		if not receivers.has(node.get_instance_id()):
			node.visible = false
			pending.append(weakref(node))
			bind_pending()
	elif node is GeometryInstance3D:
		var material := node.material_override as ShaderMaterial
		if material != null and material.shader != null and material.shader.resource_path in DREAM_SURFACES:
			var id := node.get_instance_id()
			if not surfaces.has(id):
				surfaces[id] = [weakref(node),material]
				surface_materials[material] = int(surface_materials.get(material,0)) + 1
				field.bind_material(material)
				if not field.failed.is_empty(): material.set_shader_parameter("lamp_volume_shape",Vector4.ZERO)
				node.tree_exiting.connect(_release_surface.bind(id),CONNECT_ONE_SHOT)

func bind_pending() -> void:
	if disposed or not field.ready or not field.failed.is_empty(): return
	for reference in pending:
		var mesh: MeshInstance3D = reference.get_ref()
		if not is_instance_valid(mesh) or not mesh.is_inside_tree(): continue
		var material := mesh.material_override as ShaderMaterial
		if material == null: continue
		var id := mesh.get_instance_id()
		if receivers.has(id): continue
		field.bind_material(material)
		receivers[id] = [weakref(mesh),material]
		mesh.tree_exiting.connect(_release.bind(id),CONNECT_ONE_SHOT)
		mesh.visible = true
	pending.clear()

func hide_all() -> void:
	for material: ShaderMaterial in surface_materials:
		material.set_shader_parameter("lamp_volume_shape",Vector4.ZERO)
	for record: Array in receivers.values():
		var mesh: MeshInstance3D = record[0].get_ref()
		if is_instance_valid(mesh): mesh.visible = false

func _release_surface(id: int) -> void:
	if not surfaces.has(id): return
	var material: ShaderMaterial = surfaces[id][1]
	surfaces.erase(id)
	var remaining := int(surface_materials[material]) - 1
	if remaining > 0:
		surface_materials[material] = remaining
	else:
		surface_materials.erase(material)
		field.unbind_material(material)

func _release(id: int) -> void:
	if not receivers.has(id): return
	field.unbind_material(receivers[id][1])
	receivers.erase(id)

func _release_light(id: int) -> void:
	if not lights.has(id): return
	var light: Light3D = lights[id][0].get_ref()
	if is_instance_valid(light):
		# Restore only the bit we own, preserving other owners' mask changes.
		light.light_cull_mask = (light.light_cull_mask & ~LAYER) | (int(lights[id][1]) & LAYER)
	lights.erase(id)

func dispose() -> void:
	if disposed: return
	disposed = true
	if is_instance_valid(root) and root.is_inside_tree():
		root.get_tree().node_added.disconnect(_node_added)
	for id in surfaces.keys():
		var surface: GeometryInstance3D = surfaces[id][0].get_ref()
		if is_instance_valid(surface) and surface.tree_exiting.is_connected(_release_surface.bind(id)):
			surface.tree_exiting.disconnect(_release_surface.bind(id))
		_release_surface(id)
	for id in receivers.keys():
		var mesh: MeshInstance3D = receivers[id][0].get_ref()
		if is_instance_valid(mesh):
			mesh.visible = false
			if mesh.tree_exiting.is_connected(_release.bind(id)):
				mesh.tree_exiting.disconnect(_release.bind(id))
		_release(id)
	for id in lights.keys():
		var light: Light3D = lights[id][0].get_ref()
		if is_instance_valid(light) and light.tree_exiting.is_connected(_release_light.bind(id)):
			light.tree_exiting.disconnect(_release_light.bind(id))
		_release_light(id)
	lights.clear()
	pending.clear()
	field = null
	root = null
	lamp = null

static func add_glass_haze(surface: MeshInstance3D) -> MeshInstance3D:
	var receiver := MeshInstance3D.new()
	receiver.name = "LampGlassHaze"
	receiver.mesh = surface.mesh
	receiver.layers = LAYER
	receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	receiver.visible = false
	receiver.set_meta(RECEIVER_META,true)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/lamp_optical_glass_haze.gdshader")
	receiver.material_override = material
	surface.add_child(receiver)
	return receiver
