class_name DreamViewPortal
extends SubViewport
## ONE IMPOSSIBLE VIEW, ZERO NEW SPACE.
##
## R6 is deliberately smaller than the recursive-portal proposal. This camera
## shares the production dream's World3D and looks only at the already-live
## room named by DreamRoomBuilder. It owns no room, collision, graph edge,
## hazard or destination choice. The source wall remains physically intact.
##
## The hazard surface is placed on one presentation-only render layer and this
## camera excludes that layer. That prevents the feed from seeing the wound
## which samples it, so depth is provably zero rather than accidental recursion.

const WIDTH := 384
const HEIGHT := 672
const MAX_VIEW_DISTANCE_M := 14.0
const HAZARD_PRESENTATION_LAYER := 1 << 19
const PHASE_THRESHOLD_LOW := 0.88
const PHASE_THRESHOLD_HIGH := 0.98
const EXPOSURE_MULTIPLIER := 3.2

var portal_camera: Camera3D
var fault: Dictionary = {}
var breach: Dictionary = {}
var portal_material: ShaderMaterial
var exposure: DreamExposureField

var _texture_bound := false


func configure(shared_world: World3D, authored_fault: Dictionary,
		authored_breach: Dictionary, material: ShaderMaterial,
		exposure_field: DreamExposureField) -> void:
	name = "DreamViewPortal"
	size = Vector2i(WIDTH, HEIGHT)
	transparent_bg = false
	handle_input_locally = false
	physics_object_picking = false
	own_world_3d = false
	world_3d = shared_world
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	fault = authored_fault.duplicate(true)
	breach = authored_breach.duplicate(true)
	portal_material = material
	exposure = exposure_field

	portal_camera = Camera3D.new()
	portal_camera.name = "ViewOnlyCamera"
	portal_camera.fov = 56.0
	portal_camera.near = 0.08
	portal_camera.far = 48.0
	portal_camera.cull_mask = 0xFFFFF & ~HAZARD_PRESENTATION_LAYER
	# This is a camera exposure, not a helper light: it cannot illuminate the
	# shared world or alter the destination. The second view otherwise inherits
	# the dream's very low carried black level without carrying the player's
	# lamp and collapses to a black rectangle.
	var camera_attributes := CameraAttributesPractical.new()
	camera_attributes.auto_exposure_enabled = false
	camera_attributes.exposure_multiplier = EXPOSURE_MULTIPLIER
	portal_camera.attributes = camera_attributes
	portal_camera.current = true
	add_child(portal_camera)

	set_meta("owner", "DreamAtlas/DreamRoomBuilder")
	set_meta("view_only", true)
	set_meta("shared_world", true)
	set_meta("destination_key", str(fault.get("destination_key", "")))
	set_meta("recursion_depth", 0)
	set_meta("max_recursion_depth", 0)
	set_meta("resolution", Vector2i(WIDTH, HEIGHT))
	set_meta("exposure_multiplier", EXPOSURE_MULTIPLIER)
	set_meta("phase_thresholds", Vector2(PHASE_THRESHOLD_LOW,
			PHASE_THRESHOLD_HIGH))
	set_meta("excluded_layer", HAZARD_PRESENTATION_LAYER)
	set_meta("last_exposure", 0.0)
	set_meta("last_visible", false)
	add_to_group("dream_view_portal")
	if portal_material != null:
		portal_material.set_shader_parameter("portal_active", 0.0)
	call_deferred("_bind_texture")


func _bind_texture() -> void:
	if portal_material == null or not is_inside_tree():
		return
	var feed := get_texture()
	if feed == null:
		return
	portal_material.set_shader_parameter("portal_view", feed)
	portal_material.set_shader_parameter("portal_active", 1.0)
	_texture_bound = true


## Root calls this beside its other exposure consumers. No independent process
## can keep a forgotten portal alive. The renderer sleeps below the high-state
## threshold and whenever the aperture is not in the player's useful view.
func update_view(main_camera: Camera3D) -> void:
	if main_camera == null or exposure == null or portal_camera == null:
		render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var center: Vector3 = breach.get("center", Vector3.ZERO)
	var retained := exposure.sample(center)
	var phase := smoothstep(PHASE_THRESHOLD_LOW, PHASE_THRESHOLD_HIGH,
			retained)
	var to_aperture := center - main_camera.global_position
	var distance_m := to_aperture.length()
	var camera_forward := -main_camera.global_basis.z
	var facing := distance_m > 0.001 \
			and camera_forward.dot(to_aperture / distance_m) > 0.10
	# The breach record's normal points into its Atlas room. A viewer must be
	# on that interior half-space; the authoritative wall answers from behind.
	var on_room_side := (main_camera.global_position - center).dot(
			breach.get("normal", Vector3.FORWARD)) > -0.30
	var useful_view := phase > 0.001 and distance_m <= MAX_VIEW_DISTANCE_M \
			and facing and on_room_side \
			and main_camera.is_position_in_frustum(center)
	if useful_view:
		_pose_camera(main_camera)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if useful_view and _texture_bound else SubViewport.UPDATE_DISABLED
	set_meta("last_exposure", retained)
	set_meta("last_visible", useful_view)
	if OS.get_environment("DREAM_PORTAL_TRACE") == "1" \
			and phase > 0.99 and not has_meta("trace_printed"):
		set_meta("trace_printed", true)
		print(("[DREAM VIEW PORTAL] fault=%s destination=%s origin=%s "
				+ "forward=%s camera=%s phase=%.3f visible=%s world_shared=%s") % [
				str(fault.get("id", "")), str(fault.get("destination_source", "")),
				str(fault.get("destination_origin", Vector3.ZERO)),
				str(fault.get("destination_forward", Vector3.ZERO)),
				str(portal_camera.global_position), phase, str(useful_view),
				str(world_3d == main_camera.get_world_3d())])


func _pose_camera(main_camera: Camera3D) -> void:
	var source_center: Vector3 = breach.get("center", Vector3.ZERO)
	var source_side: Vector3 = (breach.get("side", Vector3.RIGHT) as Vector3) \
			.normalized()
	var source_normal: Vector3 = (breach.get("normal",
			Vector3.FORWARD) as Vector3).normalized()
	var relative := main_camera.global_position - source_center
	var lateral := clampf(relative.dot(source_side), -0.90, 0.90)
	var vertical := clampf(relative.dot(Vector3.UP), -0.70, 0.70)
	var depth := clampf(relative.dot(source_normal), 0.35, 5.0)

	var origin: Vector3 = fault.get("destination_origin", Vector3.ZERO)
	var forward: Vector3 = (fault.get("destination_forward",
			Vector3.FORWARD) as Vector3).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var quarter_turns := int(fault.get("orientation_quarters", 1)) % 4
	var rolled_up := Vector3.UP
	if quarter_turns == 1:
		rolled_up = right
	elif quarter_turns == 2:
		rolled_up = -Vector3.UP
	elif quarter_turns == 3:
		rolled_up = -right
	var position := origin + right * lateral * 0.24 \
			+ Vector3.UP * vertical * 0.16 \
			+ forward * clampf((depth - 1.6) * 0.07, -0.10, 0.18)
	portal_camera.global_transform = Transform3D(
			Basis.looking_at(forward, rolled_up), position)


func texture_is_bound() -> bool:
	return _texture_bound
