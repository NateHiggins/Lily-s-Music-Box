extends BakedFurnitureInteraction
## V2 supplies the porcelain body separately; preserve the production flush owner.
const MODEL := "res://assets/props/bath_water_closet.glb"
var model_path := MODEL
var inlet_clear := true
var unit: String:
	get: return owner_unit

func _refill_duration() -> float:
	return 2.1 if inlet_clear else 5.0

func _finish_refill() -> void:
	super._finish_refill()
	_water.stop()

func _ready() -> void:
	super._ready()
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	add_child(model)
	_skin(model)
	var handle := model.find_child("CisternHandle", true, false) as Node3D
	# Replace only the old primitive lever, retaining the same pivot and owner.
	remove_child(_lever)
	_lever.free()
	handle.reparent(self)
	_lever = handle

func _skin(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(surface)
			if source.resource_name == "WaterSeal":
				var water := StandardMaterial3D.new()
				water.albedo_color = Color(.59,.73,.78,.18)
				water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				water.roughness = .08
				node.set_surface_override_material(surface, water)
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				node.set_surface_override_material(surface, MatLib.get_mat(source.resource_name))
	for child in node.get_children(): _skin(child)

func _exit_tree() -> void:
	for tween in [_flush_tween, _busy_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if _water != null:
		var stream := _water.stream
		_water.stop()
		_water.stream = null
		PropAudio.release_stream("sink_water", stream)
