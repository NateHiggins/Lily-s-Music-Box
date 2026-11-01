extends Node
## Short-lived work owned by an existing loading boundary. It allocates no
## render target/camera and never writes the player/camera Node transform.
## Deferred headings are restored before yielding or returning to normal draw.

var active := false
var render_calls := 0
var _player: WeakRef
var _camera: WeakRef
var _overridden: WeakRef
var _started := 0
var _steps: Array[float] = []
var _result: Dictionary = {}
var _poses_unchanged := true

func _ready() -> void:
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if active and (event.is_action_pressed("pause_services") or event.is_action_pressed("release_mouse")):
		# Release only our lease BEFORE the normal controller/UI handles this
		# event. A loading lease must not swallow Pause or reclaim the pointer.
		cancel("player_interrupted")

func run(player: Node3D, camera: Camera3D, origin: Variant = null) -> Dictionary:
	if active:return {"completed":false,"reason":"already_running"}
	_result = {};render_calls = 0;_steps.clear();_poses_unchanged = true
	_started = Time.get_ticks_usec()
	if not is_inside_tree() or not is_instance_valid(player) or not is_instance_valid(camera):
		return _finish(false,"missing_owner")
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()=="gl_compatibility":
		return _finish(false,"no_supported_renderer")
	if get_tree().paused or camera.get_viewport().get_camera_3d()!=camera:
		return _finish(false,"presentation_busy")
	var eye: Vector3 = camera.get_camera_transform().origin if origin==null else origin
	if not eye.is_finite():return _finish(false,"invalid_eye")
	if not player.acquire_text_input(self):return _finish(false,"input_busy")
	_player = weakref(player);_camera = weakref(camera);active = true
	set_process_input(true)
	var tree := get_tree()
	# Never force a draw from inside frame_post_draw's signal stack. Between
	# headings the normal scene still owns its RID and Pause remains available.
	for angle in [0.0,90.0,180.0,270.0]:
		await tree.process_frame
		while active and tree.paused:await tree.process_frame
		if not _owns_view():return _finish(false,"ownership_changed") if active else _result
		var drawn := _draw_pair(Transform3D(Basis(Vector3.UP,deg_to_rad(angle)),eye))
		if not active:return _result
		if not drawn or not _owns_view():return _finish(false,"interrupted_draw")
	await tree.process_frame
	while active and tree.paused:await tree.process_frame
	if not _owns_view():return _finish(false,"ownership_changed") if active else _result
	var drawn := _draw_pair(camera.get_camera_transform())
	if not active:return _result
	if not drawn or not _owns_view():return _finish(false,"interrupted_draw")
	RenderingServer.force_sync()
	if not _owns_view() or tree.paused:return _finish(false,"ownership_changed")
	return _finish(true,"completed")

func _owns_view() -> bool:
	if not active or not is_inside_tree():return false
	var player: Node3D = _player.get_ref() if _player!=null else null
	var camera: Camera3D = _camera.get_ref() if _camera!=null else null
	return is_instance_valid(player) and is_instance_valid(camera) \
		and player.text_input_owner==self and not player.protected_input_active() \
		and not player.mouse_released and not player.inspecting() \
		and camera.is_inside_tree() and camera.get_viewport().get_camera_3d()==camera

func _draw_pair(pose: Transform3D) -> bool:
	var camera: Camera3D = _camera.get_ref()
	var before := camera.global_transform
	var started := Time.get_ticks_usec()
	_overridden = weakref(camera)
	RenderingServer.camera_set_transform(camera.get_camera_rid(),pose)
	var count := 0
	for frame in 2:
		if not _owns_view() or get_tree().paused:break
		RenderingServer.force_draw(false)
		render_calls += 1;count += 1
	_restore_current_camera()
	if is_instance_valid(camera):_poses_unchanged = _poses_unchanged and camera.global_transform.is_equal_approx(before)
	_steps.append((Time.get_ticks_usec()-started)/1000.0)
	return count==2 and _poses_unchanged

func _restore_current_camera() -> void:
	var camera: Camera3D = _overridden.get_ref() if _overridden!=null else null
	if is_instance_valid(camera):
		# Use the current Node pose, not a saved pose that could overwrite a
		# successor's animation/inspection during a renderer callback.
		RenderingServer.camera_set_transform(camera.get_camera_rid(),camera.get_camera_transform())
	_overridden = null

func _finish(completed: bool, reason: String) -> Dictionary:
	_restore_current_camera()
	var player: Node3D = _player.get_ref() if _player!=null else null
	if is_instance_valid(player):player.release_text_input(self)
	active = false
	set_process_input(false)
	_result = {"completed":completed,"reason":reason,"render_calls":render_calls,
		"elapsed_ms":(Time.get_ticks_usec()-_started)/1000.0,
		"steps_ms":_steps.duplicate(),"node_poses_unchanged":_poses_unchanged}
	_player = null;_camera = null
	return _result

func cancel(reason := "cancelled") -> void:
	if active:_finish(false,reason)

func _exit_tree() -> void:
	cancel("owner_removed")
