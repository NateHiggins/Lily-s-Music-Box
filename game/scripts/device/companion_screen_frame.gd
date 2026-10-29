extends Node
signal world_handoff_finished
## Foreground flight is a presentation cheat, never a second device or action owner.
## The same rig remains in the world for mirrors, its lamp and physical controls.
const DEVICE_MASK := 1 << (ServiceSetProp.DEVICE_LAYER - 1)
var carrier: Node3D
var camera: Camera3D
var view: SubViewport
var view_camera: Camera3D
var layer: CanvasLayer
var image: TextureRect
var stock_bounds := AABB()
var safe_rect := Rect2()
var reading_bounds := AABB()
var composite_enabled := true
var present_reading := false
var _world_handoff:=false
var _handoff_from:=Transform3D.IDENTITY
var _handoff_age:=0.0

func begin_world_handoff(pose:Transform3D) -> void:
	_handoff_from=pose;_handoff_age=0;_world_handoff=true

func cancel_world_handoff() -> void:
	_world_handoff=false
var _has_reading_bounds := false
var _main_mask := 0
var _last_basis := Basis.IDENTITY
var _lean := Vector3.ZERO
var _lean_velocity := Vector3.ZERO
var _drift := Vector2.ZERO
var _drift_velocity := Vector2.ZERO
var _flight_clock := 0.0
var _size := Vector2i.ZERO
var _environment: Environment

func setup(owner_carrier: Node3D, source_camera: Camera3D) -> void:
	carrier = owner_carrier; camera = source_camera
	_main_mask = camera.cull_mask
	camera.cull_mask &= ~DEVICE_MASK
	_last_basis = camera.global_basis
	# Bound every open/closed part once, rather than rescanning furniture or
	# changing the manufactured model's scale as the player turns.
	var rig: Node3D = carrier.rig
	var saved: float = rig.keyboard_open
	for opening: float in [0.0, 1.0]:
		rig.keyboard_open = opening; rig._apply_keyboard()
		for draw: GeometryInstance3D in rig.find_children("*", "GeometryInstance3D", true, false):
			if not draw.is_visible_in_tree() or draw is Label3D: continue
			var is_reading_stock: bool = opening > .99 and (draw == carrier.device.teletype._paper or str(draw.name) == "CompanionKeyboard__CompanionSteel")
			var box: AABB = draw.get_aabb()
			var into_rig: Transform3D = rig.global_transform.affine_inverse() * draw.global_transform
			for corner in 8:
				var point := into_rig * box.get_endpoint(corner)
				stock_bounds = stock_bounds.expand(point)
				if is_reading_stock:
					if not _has_reading_bounds:
						reading_bounds = AABB(point, Vector3.ZERO); _has_reading_bounds = true
					else: reading_bounds = reading_bounds.expand(point)
	rig.keyboard_open = saved; rig._apply_keyboard()
	view = SubViewport.new(); view.name = "CompanionForeground"
	view.transparent_bg = true
	view.handle_input_locally = false
	view.world_3d = carrier.get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	view_camera = Camera3D.new(); view_camera.name = "CompanionFrameCamera"
	view_camera.cull_mask = DEVICE_MASK
	view_camera.current = true
	view_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# No second world, rig, physical query, shadow light or sky render.
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_CLEAR_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(.55, .62, .58)
	_environment.ambient_light_energy = .8
	view_camera.environment = _environment
	view.add_child(view_camera)
	# One shadowless photographic fill makes manufactured metal readable even
	# when the room is dark. It illuminates only the instrument layer, owns no
	# gameplay lamp state and cannot light scenery or become a second sun.
	var fill := OmniLight3D.new()
	fill.name = "InstrumentFill"
	fill.light_cull_mask = DEVICE_MASK
	fill.layers = DEVICE_MASK
	fill.light_color = Color(.88, .94, .88)
	fill.light_energy = 3.0
	fill.omni_range = 1.8
	fill.shadow_enabled = false
	fill.light_indirect_energy = 0.0
	fill.light_volumetric_fog_energy = 0.0
	fill.position = Vector3(-.12, .25, .08)
	view_camera.add_child(fill)
	layer = CanvasLayer.new(); layer.name = "CompanionFraming"; layer.layer = 7
	add_child(layer)
	image = TextureRect.new(); image.name = "PhysicalCompanion"
	image.texture = view.get_texture()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(image)
	advance(0.0, false)
	RenderingServer.frame_pre_draw.connect(_before_draw)

func _before_draw() -> void:
	advance(get_process_delta_time(), present_reading)

func advance(delta: float, reading: bool) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(carrier): return
	if _world_handoff and get_tree().paused:return
	var visible_now: bool = not carrier.is_capture_hidden() and camera.is_current()
	layer.visible = visible_now and composite_enabled
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_now and composite_enabled else SubViewport.UPDATE_DISABLED
	# The authored arrival briefly uses ordinary world depth, retaining the
	# exact native layers. Normal accompaniment has one foreground owner.
	if carrier.story_world_active():
		camera.cull_mask|=DEVICE_MASK
		layer.visible=false;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if not _world_handoff:return
	else:camera.cull_mask &= ~DEVICE_MASK
	if not visible_now: return
	var size := camera.get_viewport().get_visible_rect().size
	if size.x < 2.0 or size.y < 2.0: return
	# Reserve the centre/reticle and leftward view even while reading. The
	# transition never sweeps the bot across that protected view corridor.
	safe_rect = Rect2(Vector2(.67, .03), Vector2(.32, .94)) if reading else Rect2(Vector2(.70, .12), Vector2(.29, .83))
	var pixels := Rect2(safe_rect.position * size, safe_rect.size * size)
	image.position = pixels.position; image.size = pixels.size
	var wanted_size := Vector2i(pixels.size.round()).max(Vector2i(2, 2))
	if wanted_size != _size:
		_size = wanted_size; view.size = _size
	# A cropped off-axis camera has exactly the main camera's rays. Render
	# only the contextual right-third rectangle, with no extra render pass.
	var half_height := tan(deg_to_rad(camera.fov) * .5) * camera.near
	var aspect := size.x / size.y
	if camera.keep_aspect == Camera3D.KEEP_WIDTH: half_height /= aspect
	var center := safe_rect.get_center()
	view_camera.set_frustum(2.0 * half_height * safe_rect.size.y,
		Vector2((center.x * 2.0 - 1.0) * half_height * aspect,
		(1.0 - center.y * 2.0) * half_height), camera.near, camera.far)
	view_camera.global_transform = camera.global_transform
	# Flight path is expression: a small machine hunts for a station, then
	# banks against its own drift to recover upright. This remains bounded in
	# screen space; no scenery scan or expensive simulated rotor physics.
	var dt := clampf(delta, 0.0, .1)
	var intensity: float = carrier.motion.motion_intensity
	if bool(GameBoot.settings.get("reduce_camera_roll", false)): intensity *= .15
	var held: bool = carrier.motion.stationary_for_hand or (carrier.session != null and (carrier.session.typing or carrier.session.opening))
	_flight_clock += dt
	var station := floorf(_flight_clock / 1.9)
	var wander := Vector2(sin(station * 2.39996), sin(station * 1.618 + .7))
	var target_drift := wander * Vector2(.017, .030) * intensity
	if reading: target_drift *= .12
	if held: target_drift = Vector2.ZERO
	# Exact critically damped station correction, stable across render rates.
	var omega := 5.0 if reading else 2.8
	var error := _drift - target_drift
	var impulse := _drift_velocity + error * omega
	var decay := exp(-omega * dt)
	_drift = target_drift + (error + impulse * dt) * decay
	_drift_velocity = (_drift_velocity - impulse * omega * dt) * decay
	var turn := _last_basis.inverse() * camera.global_basis
	var turning := turn.get_euler() / maxf(delta, .001)
	_last_basis = camera.global_basis
	var desired := Vector3(clampf(-carrier._player.velocity.length() * .018 - _drift_velocity.y * 3.0, -.13, .10),
		clampf(turning.y * .035, -.13, .13), clampf(-turning.y * .055 - _drift_velocity.x * 7.0, -.22, .22)) * intensity
	if reading: desired *= .12
	if held: desired = Vector3.ZERO
	# Slightly underdamped attitude correction sells effort without jitter.
	var steps := maxi(1, int(ceil(dt * 120.0)))
	var step := dt / steps
	for index in steps:
		_lean_velocity += ((desired - _lean) * 80.0 - _lean_velocity * 11.0) * step
		_lean += _lean_velocity * step
	if held:
		_drift = Vector2.ZERO; _drift_velocity = Vector2.ZERO
		_lean = Vector3.ZERO; _lean_velocity = Vector3.ZERO
	var slope := half_height / camera.near
	var toward_reader := Vector3(-(center.x * 2.0 - 1.0) * slope * aspect,
		-(1.0 - center.y * 2.0) * slope, 1.0)
	var relative_basis := Basis.looking_at(toward_reader, Vector3.UP, true) * Basis.from_euler(_lean)
	# Pad the fitted manufactured hull to contain the bounded flight lean.
	# Reading frames the useful paper and tray; projecting every rotor and
	# corner protector would shrink the copy to an unreadable postage stamp.
	# Peripheral machinery may leave the cropped frame, never enter the view.
	var source := reading_bounds if reading and _has_reading_bounds else stock_bounds
	var fitted := AABB(source.position * carrier.PRESENTATION_SCALE, source.size * carrier.PRESENTATION_SCALE)
	var rotated := AABB(relative_basis * fitted.get_endpoint(0), Vector3.ZERO)
	for corner in range(1, 8): rotated = rotated.expand(relative_basis * fitted.get_endpoint(corner))
	var extents := rotated.size * (1.04 if reading else 1.4)
	var depth := maxf(extents.y / (2.0 * slope * safe_rect.size.y),
		extents.x / (2.0 * slope * aspect * safe_rect.size.x)) + extents.z * .5
	depth = maxf(depth, .18)
	if reading: depth *= clampf(carrier.reading_distance / .22, .82, 1.45)
	center += _drift
	var origin := Vector3((center.x * 2.0 - 1.0) * depth * slope * aspect,
		(1.0 - center.y * 2.0) * depth * slope, -depth)
	carrier.motion.global_transform = Transform3D(camera.global_basis,
		camera.global_position + camera.global_basis * (origin - relative_basis * fitted.get_center()))
	if _world_handoff:carrier.rig.position=Vector3.ZERO
	carrier.rig.basis = relative_basis.scaled(Vector3.ONE * carrier.PRESENTATION_SCALE)
	carrier.motion.velocity = Vector3.ZERO
	carrier.motion.screen_settled = true
	if _world_handoff:
		_handoff_age+=dt
		var fraction:=smoothstep(0.0,1.2,_handoff_age)
		carrier.rig.global_transform=_handoff_from.interpolate_with(carrier.rig.global_transform,fraction)
		layer.visible=false;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if fraction>=1:
			_world_handoff=false
			world_handoff_finished.emit()
			layer.visible=visible_now and composite_enabled
			view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if layer.visible else SubViewport.UPDATE_DISABLED
	carrier.rig.propulsion = clampf(.5 + carrier._player.velocity.length() * .13 + turning.length() * .04 + _drift_velocity.length() * 14.0 + _lean_velocity.length() * .12, .5, 1.6)
	# The real optical aperture follows the visible manufactured pose.
	carrier.beam_valid = true

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw): RenderingServer.frame_pre_draw.disconnect(_before_draw)
	if is_instance_valid(camera): camera.cull_mask = (camera.cull_mask & ~DEVICE_MASK) | (_main_mask & DEVICE_MASK)
