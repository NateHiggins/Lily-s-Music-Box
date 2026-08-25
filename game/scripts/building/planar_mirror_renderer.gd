class_name PlanarMirrorRenderer
extends Node
## One honest reflected view, lent to the mirror the player can actually see.
##
## Twenty-three permanent SubViewports would render the building twenty-three
## extra times. This owner instead selects one close, front-facing cabinet,
## reflects the production camera through its live door plane, and sleeps when
## no mirror is useful. Mirror glass is presentation layer 20, excluded from
## the borrowed camera, so reflection depth is exactly zero.

const MIRROR_LAYER := 1 << 19
const WIDTH := 384
const HEIGHT := 512
const MAX_DISTANCE_M := 4.5
const SHADER := preload("res://shaders/planar_mirror.gdshader")

var _main_camera: Camera3D
var _view: SubViewport
var _camera: Camera3D
var _active: MedicineCabinetProp
var _material: ShaderMaterial
var _texture_bound := false


func setup(main_camera: Camera3D) -> void:
	name = "PlanarMirrorRenderer"
	_main_camera = main_camera
	process_priority = 100
	_view = SubViewport.new()
	_view.name = "ReflectedView"
	_view.size = Vector2i(WIDTH, HEIGHT)
	_view.transparent_bg = false
	_view.handle_input_locally = false
	_view.physics_object_picking = false
	_view.own_world_3d = false
	_view.world_3d = main_camera.get_world_3d()
	_view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)

	_camera = Camera3D.new()
	_camera.name = "ReflectedCamera"
	_camera.fov = main_camera.fov
	_camera.far = main_camera.far
	_camera.cull_mask = main_camera.cull_mask & ~MIRROR_LAYER
	_camera.current = true
	_view.add_child(_camera)
	call_deferred("_bind_texture")
	set_meta("shared_world", true)
	set_meta("single_borrowed_view", true)
	set_meta("excluded_layer", MIRROR_LAYER)


func _bind_texture() -> void:
	if _view == null or not is_inside_tree():
		return
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("mirror_view", _view.get_texture())
	_texture_bound = true
	# A cabinet can win selection on the first process tick, before this deferred
	# texture exists. Complete that same binding instead of waiting for a switch
	# to some other mirror that may never happen.
	if _active != null:
		_active.set_live_mirror_material(_material)


func _process(_delta: float) -> void:
	if _main_camera == null or _camera == null:
		_sleep()
		return
	var candidate := _choose_mirror()
	if candidate != _active:
		if _active != null:
			_active.set_live_mirror_material(null)
		_active = candidate
		if _active != null and _texture_bound:
			_active.set_live_mirror_material(_material)
	if _active == null or not _texture_bound:
		_sleep()
		return
	_pose_reflection(_active)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_meta("active_unit", _active.unit)


func _choose_mirror() -> MedicineCabinetProp:
	var best: MedicineCabinetProp
	var best_score := -INF
	for node in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var cabinet := node.get_parent().get_parent() as MedicineCabinetProp
		if cabinet == null:
			continue
		var center := cabinet.mirror_center()
		var offset := center - _main_camera.global_position
		var distance_m := offset.length()
		if distance_m < 0.10 or distance_m > MAX_DISTANCE_M:
			continue
		var toward := offset / distance_m
		var camera_facing := (-_main_camera.global_basis.z).dot(toward)
		var glass_facing := cabinet.mirror_normal().dot(-toward)
		if camera_facing < 0.18 or glass_facing < 0.12 \
				or not _main_camera.is_position_in_frustum(center):
			continue
		var score := camera_facing * 2.0 + glass_facing - distance_m * 0.16
		if score > best_score:
			best_score = score
			best = cabinet
	return best


func _pose_reflection(cabinet: MedicineCabinetProp) -> void:
	var center := cabinet.mirror_center()
	var normal := cabinet.mirror_normal()
	var source := _main_camera.global_transform
	var reflected_position := _reflect_point(source.origin, center, normal)
	var reflected_forward := _reflect_vector(-source.basis.z, normal).normalized()
	var reflected_up := _reflect_vector(source.basis.y, normal).normalized()
	_camera.global_transform = Transform3D(
			Basis.looking_at(reflected_forward, reflected_up), reflected_position)
	_camera.fov = _main_camera.fov
	_camera.far = _main_camera.far
	# Everything between the borrowed eye and the glass is behind the mirror.
	# Clipping it prevents the fitted wall from becoming an opaque photograph.
	var plane_distance := absf((reflected_position - center).dot(normal))
	_camera.near = maxf(0.05, plane_distance + 0.035)


func _reflect_point(point: Vector3, origin: Vector3, normal: Vector3) -> Vector3:
	return point - normal * (2.0 * (point - origin).dot(normal))


func _reflect_vector(vector: Vector3, normal: Vector3) -> Vector3:
	return vector - normal * (2.0 * vector.dot(normal))


func _sleep() -> void:
	if _view:
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _active != null:
		_active.set_live_mirror_material(null)
		_active = null
	set_meta("active_unit", "")


func active_mirror() -> MedicineCabinetProp:
	return _active
