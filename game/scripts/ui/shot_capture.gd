class_name ShotCapture
extends Node
## F drops a screenshot, and beside it the pose that took it.
## H hides or restores the carried device and paper; its lamp stays active.
## F8 borrows an independent inspection eye in Debug or the roof preview.
## The existing input lease parks gameplay controls; no player pose is moved.
##
## Scripted camera stands only ever frame what someone already suspects is
## wrong. The problems that actually survive to the player — a hump at a
## threshold, a texture whose scale reads fine from the doorway and absurd
## from the couch — are found by standing where the player stands. So the
## capture lives here rather than in the debug panel: the panel is built
## only in DEBUG launch mode, and a review tool that works in one launch
## mode is a review tool you have to remember the state of.
##
## Every shot writes a stand string into shots.md next to it. Paste that
## into SHOT_ROOMS and FreeCam reproduces the same eye later, which is how
## a "look at this" becomes a before/after.

signal captured(stem: String, aim: String)
signal device_visibility_changed(hidden: bool)

## Outside res:// on purpose: shots are review material, not game data, and
## they land where the rest of the renders already live.
const SHOT_DIR := "res://../art/renders/insitu"

## The debug panel's CanvasLayer, when there is one. Hidden for the one
## frame the shot is taken on, so review images are not half UI.
var chrome: CanvasLayer

var _busy := false
var inspection_camera: Camera3D
var inspection_speed := 6.0
var _inspection_saved: Dictionary = {}
var _inspection_hud: CanvasLayer
var _inspection_label: Label


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func toggle_inspection_camera() -> bool:
	if is_instance_valid(inspection_camera):
		end_inspection_camera()
		return true
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG and not GameBoot.developer_overlays_enabled() and not bool(get_meta("inspection_enabled",false)): return false
	var world := get_parent()
	var player := world.get("player") as PlayerController
	if player == null or get_tree().paused or player.call_locked or player.inspecting() \
			or is_instance_valid(player.seated_interaction) or (player._grab!=null and player._grab.active()) \
			or get_viewport().get_camera_3d() != player.camera: return false
	if is_instance_valid(world.get("building_debug")) and world.building_debug._body.visible: return false
	var released:=player.mouse_released
	player.mouse_released=false
	if not player.acquire_text_input(self):
		player.mouse_released=released
		return false
	var carrier := player.carried_device as ServiceSetCarrier
	_inspection_saved = {"player":player,"process":player.is_processing(),"physics":player.is_physics_processing(),
		"input":player.is_processing_input(),"unhandled":player.is_processing_unhandled_input(),
		"mouse":Input.mouse_mode,"released":released,"mode":process_mode,"view":world.get("view_override"),
		"hud":player._interaction_hud.visible,"carrier_hidden":carrier.is_capture_hidden() if carrier!=null else true}
	inspection_camera = Camera3D.new()
	inspection_camera.name = "InspectionCamera"
	inspection_camera.set_meta("inspection_camera",true)
	inspection_camera.fov=player.camera.fov
	inspection_camera.near=player.camera.near
	inspection_camera.far=maxf(2000.,player.camera.far)
	inspection_camera.keep_aspect=player.camera.keep_aspect
	inspection_camera.cull_mask=player.camera.cull_mask
	inspection_camera.environment=player.camera.environment
	inspection_camera.attributes=player.camera.attributes
	add_child(inspection_camera)
	inspection_camera.global_transform=player.camera.global_transform
	world.view_override=inspection_camera
	var passage: Node=world.get("passage_region")
	if passage!=null and passage.get("residency")!=null:
		_inspection_saved["residency"]=passage.residency
		_inspection_saved["observer"]=passage.residency.observer
		passage.residency.observer=inspection_camera
	var mirror: Node=world.get("mirror_renderer")
	if mirror!=null and mirror.has_method("set_observer"):
		_inspection_saved["mirror"]=mirror
		_inspection_saved["mirror_observer"]=mirror._main_camera
		mirror.set_observer(inspection_camera)
	player.set_process(false);player.set_physics_process(false)
	player.set_process_input(false);player.set_process_unhandled_input(false)
	player._interaction_hud.visible=false
	if carrier!=null:carrier.set_capture_hidden(true)
	inspection_camera.make_current()
	_inspection_hud=CanvasLayer.new();_inspection_hud.layer=96;add_child(_inspection_hud)
	_inspection_label=Label.new();_inspection_label.position=Vector2(16,16)
	_inspection_label.add_theme_font_size_override("font_size",18)
	_inspection_label.add_theme_color_override("font_outline_color",Color.BLACK)
	_inspection_label.add_theme_constant_override("outline_size",5)
	_inspection_hud.add_child(_inspection_label)
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(true);set_process_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	return true


func end_inspection_camera() -> void:
	if not is_instance_valid(inspection_camera): return
	var world := get_parent()
	var player: PlayerController=_inspection_saved.get("player")
	if world!=null and world.get("view_override")==inspection_camera:world.view_override=_inspection_saved.view
	var residency: Node=_inspection_saved.get("residency")
	if is_instance_valid(residency) and residency.observer==inspection_camera:residency.observer=_inspection_saved.observer
	var mirror: Node=_inspection_saved.get("mirror")
	if is_instance_valid(mirror) and mirror._main_camera==inspection_camera:mirror.set_observer(_inspection_saved.mirror_observer)
	if is_instance_valid(player):
		player.release_text_input(self)
		if not player.call_locked:
			player.mouse_released=_inspection_saved.released
			Input.mouse_mode=_inspection_saved.mouse
		player.set_process(_inspection_saved.process);player.set_physics_process(_inspection_saved.physics)
		player.set_process_input(_inspection_saved.input);player.set_process_unhandled_input(_inspection_saved.unhandled)
		player._interaction_hud.visible=_inspection_saved.hud and not player.call_locked
		var carrier:=player.carried_device as ServiceSetCarrier
		if carrier!=null:carrier.set_capture_hidden(_inspection_saved.carrier_hidden)
		if player.camera.is_inside_tree():player.camera.make_current()
	process_mode=_inspection_saved.mode
	inspection_camera.queue_free();inspection_camera=null
	if is_instance_valid(_inspection_hud):_inspection_hud.queue_free()
	_inspection_saved.clear();set_process(false);set_process_input(false)


func _exit_tree() -> void:
	end_inspection_camera()


func _process(delta: float) -> void:
	if not is_instance_valid(inspection_camera):return
	var player: PlayerController=_inspection_saved.player
	if not is_instance_valid(player) or player.protected_input_active() or player.text_input_owner!=self or player.inspecting():
		end_inspection_camera();return
	if get_tree().paused:return
	var speed:=inspection_speed*(4. if Input.is_physical_key_pressed(KEY_SHIFT) else .2 if Input.is_physical_key_pressed(KEY_CTRL) else 1.)
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var direction:=Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W):direction-=inspection_camera.global_basis.z
		if Input.is_physical_key_pressed(KEY_S):direction+=inspection_camera.global_basis.z
		if Input.is_physical_key_pressed(KEY_A):direction-=inspection_camera.global_basis.x
		if Input.is_physical_key_pressed(KEY_D):direction+=inspection_camera.global_basis.x
		if Input.is_physical_key_pressed(KEY_E):direction+=Vector3.UP
		if Input.is_physical_key_pressed(KEY_Q):direction-=Vector3.UP
		inspection_camera.global_position+=direction.limit_length()*speed*delta
	_inspection_label.text="INSPECTION  %.2f m/s\nWASD / QE fly · Shift fast · Ctrl precise · wheel speed · F shot · ` pointer · F8 / Esc return"%inspection_speed


func _input(event: InputEvent) -> void:
	if not is_instance_valid(inspection_camera):return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F8,KEY_ESCAPE:end_inspection_camera()
			KEY_QUOTELEFT:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_F:capture()
	elif event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		inspection_camera.rotation.y-=event.relative.x*.0025
		inspection_camera.rotation.x=clampf(inspection_camera.rotation.x-event.relative.y*.0025,-1.5,1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			inspection_speed=clampf(inspection_speed*(1.5 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1./1.5),.25,120.)
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F8:
		if toggle_inspection_camera():get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("capture_device_toggle"):
		toggle_device_visibility()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("shot_capture"):
		capture()
		get_viewport().set_input_as_handled()


func toggle_device_visibility() -> void:
	var owner_root := get_parent()
	if owner_root == null or owner_root.get("player") == null:
		return
	var carrier := owner_root.player.carried_device as ServiceSetCarrier
	if not is_instance_valid(carrier):
		return
	var hidden := not carrier.is_capture_hidden()
	carrier.set_capture_hidden(hidden)
	device_visibility_changed.emit(hidden)
	print("[shot] Carried device %s; lamp and radio unchanged" %
			("hidden" if hidden else "visible"))


func capture() -> void:
	if _busy:
		return
	_busy = true
	var fly_chrome:=_inspection_hud
	var fly_visible:=is_instance_valid(fly_chrome) and fly_chrome.visible
	if is_instance_valid(fly_chrome):fly_chrome.visible=false
	var chrome_was := true
	if chrome:
		chrome_was = chrome.visible
		chrome.visible = false
	# Await twice: a visibility change made while handling input is not
	# honoured until the following frame, so a single await would bake the
	# debug panel into the first shot of every session.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if chrome:
		chrome.visible = chrome_was
	if is_instance_valid(fly_chrome):fly_chrome.visible=fly_visible

	var dir_path: String = ProjectSettings.globalize_path(
			SHOT_DIR).simplify_path()
	if not OS.get_environment("SHOT_DIR").is_empty():dir_path=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var index := 1
	for existing in DirAccess.get_files_at(dir_path):
		if existing.begins_with("shot_") and existing.ends_with(".png"):
			index = maxi(index, existing.substr(5, 3).to_int() + 1)
	var stem := "shot_%03d" % index
	image.save_png(dir_path.path_join(stem + ".png"))

	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye := Vector3.ZERO
	var facing := Vector3.ZERO
	var aim := "—"
	if camera:
		eye = camera.global_position
		facing = camera.global_rotation_degrees
		var space := camera.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
				eye, eye - camera.global_transform.basis.z * 40.0)
		var owner_root := get_parent()
		if owner_root and owner_root.get("player") != null:
			query.exclude = [owner_root.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.has("collider") and is_instance_valid(hit["collider"]):
			# The bare node name is almost always "StaticBody3D", which
			# identifies nothing. What is worth writing down is the path
			# back to a named ancestor, plus where in the world the ray
			# landed - a plan coordinate can be looked up in the layout.
			var node: Node = hit["collider"]
			var trail: Array[String] = []
			var walk: Node = node
			for _i in 4:
				if walk == null:
					break
				trail.push_front(String(walk.name))
				walk = walk.get_parent()
			var at: Vector3 = hit["position"]
			aim = "%s  @ world (%.2f, %.2f, %.2f)  %.2f m away" % [
					"/".join(trail), at.x, at.y, at.z,
					eye.distance_to(at)]

	var stand := "@%.2f_%.2f_%.2f:%.1f|%.1f" % [eye.x, eye.y, eye.z,
			facing.y, facing.x]
	var entry := "\n## %s.png\npos (%.2f, %.2f, %.2f)  yaw %.1f  pitch %.1f\n" \
			% [stem, eye.x, eye.y, eye.z, facing.y, facing.x] \
			+ "looking at: %s\nstand: %s\nnote:\n" % [aim, stand]
	var log_path := dir_path.path_join("shots.md")
	var handle: FileAccess
	if FileAccess.file_exists(log_path):
		handle = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if handle:
			handle.seek_end()
	else:
		handle = FileAccess.open(log_path, FileAccess.WRITE)
	if handle:
		handle.store_string(entry)
		handle.close()
	print("[shot] %s.png  %s  looking at %s" % [stem, stand, aim])
	captured.emit(stem, aim)
	_busy = false
