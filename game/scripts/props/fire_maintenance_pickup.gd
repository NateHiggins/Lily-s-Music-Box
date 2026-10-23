extends "res://scripts/props/v2_library_movable.gd"
## A service bottle or replacement washer follows the common held-stock path.
var item_id := ""
var cap: Node3D
const CAP_TRAVEL := 1.9
var cap_turn := 0.0
var _cap_held := false
var _floating := false
var _floating_camera := Transform3D.IDENTITY
var _floating_frames := 0
var _quiet_contact_time := 0.
var _quiet_contact_pose := Transform3D.IDENTITY
var _rest_diagnostics := OS.get_environment("V2_STOCK_PHYSICS_DIAGNOSTICS")=="1"
var _rest_support: WeakRef
var _rest_support_pose := Transform3D.IDENTITY

func pickup_centre() -> Vector3:
	return Vector3(0,.08,0) if item_id=="fire_hose_rubber_protectant" else Vector3.ZERO

func requires_shelf_withdrawal() -> bool:
	return freeze and not shelf.is_inspecting(self)

func grip() -> Dictionary:
	if shelf==null or not shelf.can_take(self):return {"blocked":true}
	return super.grip()

func _claim(tag: String) -> bool:
	if not super._claim(tag):return false
	if tag=="body":_floating=false
	return true

func hold_pose(camera_pose: Transform3D, centered := false) -> void:
	# A small bottle needs a closer supported inspection than a full book page.
	var view:=camera_pose.translated_local(Vector3(0,0,.35)) if centered else camera_pose
	super.hold_pose(view,centered)

func _ready() -> void:
	super._ready()
	contact_monitor=true;max_contacts_reported=8
	freeze=true
	set_physics_process(false)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if _rest_diagnostics and Engine.get_physics_frames()%60==0:
		var colliders: Array[String]=[]
		for index in state.get_contact_count():colliders.append(str(state.get_contact_collider_object(index)))
		print("STOCK REST STATE ",JSON.stringify({"contacts":colliders,"quiet_time":_quiet_contact_time,"linear":str(state.linear_velocity),"frozen":freeze,"held":_held,"floating":_floating,"sleeping":state.sleeping,"displacement":state.transform.origin.distance_to(_quiet_contact_pose.origin),"turn_x":state.transform.basis.x.distance_to(_quiet_contact_pose.basis.x),"turn_y":state.transform.basis.y.distance_to(_quiet_contact_pose.basis.y)}))
	if freeze or _held or _floating or state.sleeping or state.linear_velocity.length()>.06:
		_quiet_contact_time=0.;return
	var supported:=false
	var support: StaticBody3D
	var recovery:=Vector3.ZERO
	for index in state.get_contact_count():
		if state.get_contact_collider_object(index) is not StaticBody3D:continue
		if state.get_contact_collider_velocity_at_position(index).length()>.01:continue
		supported=true
		support=state.get_contact_collider_object(index)
		var separation:=state.get_contact_collider_position(index)-state.get_contact_local_position(index)
		if separation.length_squared()>recovery.length_squared():recovery=separation
	if not supported:
		_quiet_contact_time=0.;return
	if _quiet_contact_time==0.:
		_quiet_contact_pose=state.transform
	var rotated: bool=state.transform.basis.x.distance_to(_quiet_contact_pose.basis.x)>.10 or state.transform.basis.y.distance_to(_quiet_contact_pose.basis.y)>.10
	if state.transform.origin.distance_to(_quiet_contact_pose.origin)>.0015 or rotated:
		_quiet_contact_time=0.;return
	_quiet_contact_time+=state.step
	if _quiet_contact_time<.75:return
	_quiet_contact_time=0.
	# Recover the engine's tiny resting penetration using its own contact
	# points. The existing native-shape query must clear every obstruction.
	# This runs once on physical settling, never while held or unsupported.
	var pose:=state.transform
	if recovery.length()>.025:return
	if not recovery.is_zero_approx():pose.origin+=recovery+recovery.normalized()*.00005
	if not _clear_pose(pose):return
	state.transform=pose;state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO
	_watch_support(support);state.sleeping=true

func _watch_support(support: StaticBody3D) -> void:
	_forget_support()
	if support==null:return
	_rest_support=weakref(support);_rest_support_pose=support.global_transform
	support.tree_exiting.connect(_support_removed,CONNECT_ONE_SHOT)
	set_physics_process(true)

func _forget_support() -> void:
	var support: Node=_rest_support.get_ref() if _rest_support!=null else null
	if support!=null and support.tree_exiting.is_connected(_support_removed):support.tree_exiting.disconnect(_support_removed)
	_rest_support=null

func _support_removed() -> void:
	_forget_support();_quiet_contact_time=0.
	if not freeze and not _held:sleeping=false
	set_physics_process(_floating or _held)

func restore_stock(value: Dictionary) -> void:
	_forget_support();_quiet_contact_time=0.
	super.restore_stock(value)
	if bool(value.sleeping):_track_saved_support.call_deferred()

func _track_saved_support() -> void:
	await get_tree().physics_frame;await get_tree().physics_frame
	if not is_inside_tree() or freeze or _held or not sleeping:return
	# Reconnect a saved resting body to its actual support once. No world scan
	# is performed while it sleeps; only that support's transform is watched.
	for solid: CollisionShape3D in _solids:
		var query:=_shape_query(solid,global_transform.translated(Vector3.DOWN*.003))
		var hit:=get_world_3d().direct_space_state.get_rest_info(query)
		if hit.is_empty() or hit.normal.y<.5:continue
		var support:=instance_from_id(int(hit.collider_id)) as StaticBody3D
		if support!=null:_watch_support(support);return

func cap_grip() -> Dictionary:
	if item_id!="fire_hose_rubber_protectant":return {}
	if not shelf.is_inspecting(self):return grip()
	return {"owner":shelf,"part":cap,"frame":self,"kind":"hinge","axis":Vector3.RIGHT,
		"minimum":0.,"maximum":CAP_TRAVEL,"gesture_travel_px":240.,"gesture_screen_axis":Vector2.UP,
		"read":func():return cap_turn,
		"write":func(value: float):
			if _cap_held:set_cap(value),
		"begin":func():
			if not shelf.claim_library_hand(self,"cap"):return false
			_cap_held=true;return true,
		"owns":func():return _cap_held,
		"end":func():
			_cap_held=false;shelf.release_library_hand(self,true)}

func set_cap(value: float) -> void:
	cap_turn=clampf(value,0.,CAP_TRAVEL)
	cap.rotation.x=cap_turn

func _physics_process(_delta: float) -> void:
	if _rest_support!=null:
		var support: Node3D=_rest_support.get_ref()
		if freeze or _held or _floating:_forget_support()
		elif support==null or not support.global_transform.is_equal_approx(_rest_support_pose):_support_removed()
		elif not sleeping:_forget_support();set_physics_process(false)
	if _floating and not _held and not _cap_held:
		var before:=global_transform
		hold_pose(_floating_camera,true);_floating_frames+=1
		if global_transform.is_equal_approx(before) or _floating_frames>=120:
			_floating=false;set_physics_process(false)
	if not _held or cap_turn<CAP_TRAVEL-.0001:return
	shelf.apply_dressing(self,to_global(Vector3(0,.166,0)))

func begin_static_inspection(camera_pose: Transform3D) -> void:
	freeze=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	_floating=true;_floating_camera=camera_pose;_floating_frames=0;set_physics_process(true)

func end_static_inspection() -> void:
	_floating=false;set_physics_process(false)
