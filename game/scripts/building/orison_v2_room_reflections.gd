extends Node3D
## Bounded room-local specular context; no new lights or material overrides.
## Production owner; broader appearance qualification remains separate.
const TRANSIENT_LIGHT_LAYER := 1<<18
const CAPTURE_MASK := 0xFFFFF & ~((1<<1)|(1<<15)|(1<<17)|(1<<18)|(1<<19))
const CACHE_LIMIT := 3
const REFRESH_SECONDS := 30.0
var world: OrisonV2RuntimeRoot
var frame: Node3D
var rooms: Array[Dictionary]=[]
var probes: Dictionary={}
var active_id := ""
var errors: Array[String]=[]
var refresh_count := 0
var _last_used: Dictionary={}
var _refresh_due: Dictionary={}
var _base_positions: Dictionary={}
var _retry_after: Dictionary={}
var _scan_due := 0.0
var _enabled := true
var _available := false
var _lamp_layers_before := 1
var _switches: SwitchSystem
var _capture_frames: Dictionary={}

func setup(owner: OrisonV2RuntimeRoot) -> bool:
	if world!=null or owner==null or owner.player==null:return false
	world=owner;frame=world.adapter.root as Node3D
	if frame==null:return false
	# Compatibility keeps its current lighting. No hidden render-layer changes
	# in a renderer/device where this capture path has not been qualified.
	_available=RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_rendering_device()!=null
	if not _available:return true
	var heights := {}
	var exclusions: Variant=frame.get("space_geometry_exclusions")
	for level: Dictionary in world.layout.levels:heights[str(level.id)]=float(level.y)
	for space: Dictionary in world.layout.spaces:
		if bool(space.get("open_shell",false)) or bool(space.get("no_ceiling",false)) or bool(space.get("no_floor",false)):continue
		if exclusions is Array and str(space.id) in exclusions:continue
		var r: Array=space.rect
		var bounds := AABB(Vector3(float(r[0]),float(heights[str(space.level)]),float(r[1])),Vector3(float(r[2])-float(r[0]),float(world.layout.dimensions.clear_height),float(r[3])-float(r[1])))
		rooms.append({"id":str(space.id),"bounds":bounds})
	_lamp_layers_before=world.player.flashlight.layers
	world.player.flashlight.layers=TRANSIENT_LIGHT_LAYER
	_switches=world.get_node_or_null("V2RoomSwitches") as SwitchSystem
	if _switches!=null:_switches.room_toggled.connect(_on_room_toggled)
	# Let the actual fixture/daylight presentation settle after composition.
	_scan_due=1.0
	return not rooms.is_empty()

func room_at(global_eye: Vector3) -> String:
	var eye := frame.to_local(global_eye)
	var chosen := "";var area := INF
	for room: Dictionary in rooms:
		var b: AABB=room.bounds
		var size := b.size.x*b.size.z
		if b.has_point(eye) and size<area:area=size;chosen=room.id
	return chosen

func set_reflections_enabled(value: bool) -> void:
	_enabled=value
	for probe: ReflectionProbe in probes.values():probe.visible=value
	_scan_due=0.0

func _physics_process(delta: float) -> void:
	if not _available or not _enabled or not is_instance_valid(world) or not is_instance_valid(world.player):return
	_scan_due-=delta
	if _scan_due>0:return
	_scan_due=.25
	var identity := room_at(_view_position())
	active_id=identity
	if identity.is_empty():return
	_last_used[identity]=Time.get_ticks_msec()
	if not probes.has(identity) and Time.get_ticks_msec()>=int(_retry_after.get(identity,0)):_create(identity)
	if probes.has(identity) and Time.get_ticks_msec()>=int(_refresh_due.get(identity,0)):_refresh(identity)

func _create(identity: String) -> void:
	var selected: Dictionary={}
	for room: Dictionary in rooms:
		if room.id==identity:selected=room;break
	if selected.is_empty():return
	var bounds: AABB=selected.bounds
	var origin := _clear_origin(bounds)
	if not origin.is_finite():
		var message := "no clear reflection origin: "+identity
		if message not in errors:errors.append(message)
		_retry_after[identity]=Time.get_ticks_msec()+10000
		return
	if probes.size()>=CACHE_LIMIT:
		var oldest := "";var timestamp := 9223372036854775807
		for key: String in probes:
			if int(_last_used.get(key,0))<timestamp:timestamp=int(_last_used.get(key,0));oldest=key
		(probes[oldest] as ReflectionProbe).free();probes.erase(oldest)
		_last_used.erase(oldest);_refresh_due.erase(oldest);_base_positions.erase(oldest)
		_capture_frames.erase(oldest)
	var probe := ReflectionProbe.new()
	probe.name="RoomReflection_"+identity
	probe.size=bounds.size;probe.max_distance=bounds.size.length()
	# Keep outdoor sky available through real openings, including daylight.
	probe.box_projection=true;probe.interior=false
	# Six secondary cube faces otherwise repeat the room's shadow work in one
	# engine step. Paired occupied-world captures retain the main scene's
	# shadows/dark circuits; accept slightly brighter secondary brass in return
	# for lower capture stalls. See V2_REFLECTION_CAPTURE_COST_2026-10-23.md.
	probe.enable_shadows=false
	# The world environment, actual fixtures and SSIL own diffuse light.
	# Reusing captured room radiance as diffuse ambient bleached compact rooms
	# even after their lights were off. Keep only the probe's specular context.
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	probe.blend_distance=.10;probe.reflection_mask=CAPTURE_MASK
	probe.mesh_lod_threshold=4.;probe.cull_mask=CAPTURE_MASK
	probe.update_mode=ReflectionProbe.UPDATE_ONCE
	var local_pose := Transform3D(Basis.IDENTITY,bounds.get_center())
	probe.transform=global_transform.affine_inverse()*frame.global_transform*local_pose
	probe.origin_offset=origin-bounds.get_center()
	add_child(probe)
	probes[identity]=probe;_base_positions[identity]=probe.position
	_refresh_due[identity]=Time.get_ticks_msec()+int(REFRESH_SECONDS*1000);refresh_count+=1
	_capture_frames[identity]=Engine.get_frames_drawn()

func _clear_origin(bounds: AABB) -> Vector3:
	var eye := frame.to_local(_view_position())
	var candidates: Array[Vector3]=[eye,bounds.get_center()]
	for x in [.25,.5,.75]:
		for z in [.25,.5,.75]:candidates.append(bounds.position+Vector3(bounds.size.x*x,1.4,bounds.size.z*z))
	var shape := SphereShape3D.new();shape.radius=.10
	var query := PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.exclude=[world.player.get_rid()]
	for candidate: Vector3 in candidates:
		if not bounds.grow(-.11).has_point(candidate):continue
		query.transform=Transform3D(Basis.IDENTITY,frame.to_global(candidate))
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return candidate
	return Vector3(INF,INF,INF)

func _refresh(identity: String) -> void:
	var probe: ReflectionProbe=probes[identity]
	# UPDATE_ONCE explicitly refreshes after a transform change. Toggle a tiny
	# bounded displacement rather than accumulating positional drift.
	var base: Vector3=_base_positions[identity]
	# Alternate this probe's own displacement. Global refresh-count parity
	# can repeat its previous position after another room refreshes, leaving
	# UPDATE_ONCE stale even though the counter and deadline advance.
	probe.position=base+Vector3(-.00001 if probe.position.x>base.x else .00001,0,0)
	_refresh_due[identity]=Time.get_ticks_msec()+int(REFRESH_SECONDS*1000);refresh_count+=1
	_capture_frames[identity]=Engine.get_frames_drawn()

func capture_positions() -> Array[Vector3]:
	# Capture illumination stays available through cube faces and filtering.
	# These probes have shadows disabled, so they need no shadow-camera vote.
	var result: Array[Vector3]=[]
	if not _enabled:return result
	for identity: String in _capture_frames:
		if probes.has(identity) and Engine.get_frames_drawn()-int(_capture_frames[identity])<=32:
			var probe: ReflectionProbe=probes[identity]
			result.append(probe.to_global(probe.origin_offset))
	return result

func _view_position() -> Vector3:
	# Inspection/free cameras can leave the controller parked on another floor.
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera!=null else world.player.camera.global_position

func _on_room_toggled(_identity: String,_on: bool) -> void:
	# A switch can be reached from a neighbouring hall; invalidate cached
	# rooms too so returning through that doorway cannot keep old lighting.
	for identity: String in probes:_refresh_due[identity]=0

func _exit_tree() -> void:
	if is_instance_valid(_switches) and _switches.room_toggled.is_connected(_on_room_toggled):_switches.room_toggled.disconnect(_on_room_toggled)
	if _available and is_instance_valid(world) and is_instance_valid(world.player) and is_instance_valid(world.player.flashlight) and world.player.flashlight.layers==TRANSIENT_LIGHT_LAYER:
		world.player.flashlight.layers=_lamp_layers_before
