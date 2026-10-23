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

func pickup_centre() -> Vector3:
	return Vector3(0,.08,0) if item_id=="fire_hose_rubber_protectant" else Vector3.ZERO

func requires_shelf_withdrawal() -> bool:
	return freeze and not shelf.is_inspecting(self)

func grip() -> Dictionary:
	if shelf==null or not shelf.can_take(self):return {"blocked":true}
	return super.grip()

func hold_pose(camera_pose: Transform3D, centered := false) -> void:
	# A small bottle needs a closer supported inspection than a full book page.
	var view:=camera_pose.translated_local(Vector3(0,0,.35)) if centered else camera_pose
	super.hold_pose(view,centered)

func _ready() -> void:
	super._ready()
	freeze=true
	set_physics_process(false)

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
