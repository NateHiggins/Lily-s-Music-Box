class_name DreamCritterVoxelBinding
extends Node
## A world owner's transient presentation binding. The owner creates, stamps,
## advances and uploads its one DreamExposureField; this node only shares that
## existing RG8 sampler with live critter batches. It never allocates a field,
## texture, material or animal and never serializes a GPU resource.

const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const OWNER_META := &"dream_critter_voxel_binding_owner"

var _texture: ImageTexture3D = null
var _controllers: Dictionary = {}


## Reject a different optical volume instead of interpreting RGBA lamp radiance
## or a multi-storey LivingField as the accepted R-history/G-irradiance channels.
## The world remains responsible for the field's world-space Y0..4 domain.
func set_texture(texture: ImageTexture3D) -> bool:
	if texture == null or texture.get_format() != Image.FORMAT_RG8 \
			or texture.get_width() != ExposureScript.GRID_XZ \
			or texture.get_height() != ExposureScript.GRID_XZ \
			or texture.get_depth() != ExposureScript.GRID_Y:
		return false
	_prune_departed()
	if _texture == texture:
		return true
	_texture = texture
	for reference: WeakRef in _controllers.values():
		var controller := reference.get_ref() as DreamCritterController
		controller.bind_voxel_optics(_texture, ExposureScript.EXTENT_M,
				ExposureScript.HEIGHT_M)
	return true


func bind_controller(controller: DreamCritterController) -> bool:
	if _texture == null or not is_instance_valid(controller) \
			or not controller.is_inside_tree():
		return false
	_prune_departed()
	var id := controller.get_instance_id()
	if _controllers.has(id):
		return true
	# Do not take a controller already registered with another world owner.
	if controller._voxel_texture != null:
		return false
	_controllers[id] = weakref(controller)
	controller.set_meta(OWNER_META, weakref(self))
	controller.bind_voxel_optics(_texture, ExposureScript.EXTENT_M,
			ExposureScript.HEIGHT_M)
	return true


func unbind_controller(controller: DreamCritterController) -> void:
	if not is_instance_valid(controller):
		return
	var id := controller.get_instance_id()
	if not _controllers.has(id):
		return
	_release_owned(controller)
	_controllers.erase(id)


func clear() -> void:
	for reference: WeakRef in _controllers.values():
		var controller := reference.get_ref() as DreamCritterController
		if is_instance_valid(controller):
			_release_owned(controller)
	_controllers.clear()
	_texture = null


func controller_count() -> int:
	_prune_departed()
	return _controllers.size()


func _prune_departed() -> void:
	for id in _controllers.keys():
		var controller := (_controllers[id] as WeakRef).get_ref() as DreamCritterController
		if not is_instance_valid(controller):
			_controllers.erase(id)
		elif not controller.is_inside_tree() or not _owns(controller) 				or controller._voxel_texture != _texture:
			# Texture identity cannot identify an owner: a released controller
			# may attach to another owner that uses the exact same texture.
			_release_owned(controller)
			_controllers.erase(id)


func _owns(controller: DreamCritterController) -> bool:
	var reference := controller.get_meta(OWNER_META, null) as WeakRef
	return reference != null and reference.get_ref() == self


func _release_owned(controller: DreamCritterController) -> void:
	if not _owns(controller):
		return
	if controller._voxel_texture == _texture:
		controller.unbind_voxel_optics()
	controller.remove_meta(OWNER_META)


func _exit_tree() -> void:
	clear()
