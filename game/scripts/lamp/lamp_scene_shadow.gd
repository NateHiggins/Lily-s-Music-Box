extends Node3D
## A lamp-space depth view uses actual opaque scene geometry, including native
## vertex deformation. It is a shadow map sampled into voxels, not solid voxelization.
var viewport: SubViewport
var camera: Camera3D
var effect: CompositorEffect
var field: RefCounted
var lamp: SpotLight3D
func setup(owner_field: RefCounted, owner_lamp: SpotLight3D) -> void:
	field = owner_field
	lamp = owner_lamp
	viewport = SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.world_3d = get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = field.NEAR
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	viewport.add_child(camera)
	effect = preload("res://scripts/lamp/lamp_scene_shadow_effect.gd").new()
	effect.field_ref = weakref(field)
	camera.compositor = Compositor.new()
	camera.compositor.compositor_effects = [effect]
	process_priority = 110
	_process(0)
func _process(_delta: float) -> void:
	if not is_instance_valid(lamp) or field == null: return
	if not effect.failed.is_empty():
		field.failed = "Scene shadow: " + effect.failed
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	camera.global_transform = lamp.global_transform
	camera.far = lamp.spot_range
	camera.fov = lamp.spot_angle*2.0
	camera.cull_mask = lamp.shadow_caster_mask
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if field.enabled else SubViewport.UPDATE_DISABLED
func _exit_tree() -> void:
	if effect != null: effect.dispose()
	field = null
	lamp = null
