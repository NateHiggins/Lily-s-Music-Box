extends RefCounted
## The guard remains the only custody owner. This helper moves its native parts.
var guard: Node3D
var held := ""
var latch_angle := 0.0
var key_lift := 0.0
const TRAVEL := .065
const DIRECTION := Vector3(0,.8,.6)
var key_area: Area3D
var return_area: Area3D

func configure(owner: Node3D) -> void:
	guard=owner
	var area := preload("res://scripts/props/manipulation_area.gd")
	area.install(guard._latch,grip.bind("latch"))
	key_area=area.install(guard._key,grip.bind("key"))
	return_area=area.install(guard._check,grip.bind("return"))
	refresh()

func grip(key: String) -> Dictionary:
	if key=="key" and guard.key_carried(): return {}
	if key=="return" and not guard.key_carried(): return {}
	return {"owner":guard,"part":guard._latch if key=="latch" else guard._key,"frame":guard,
		"kind":"hinge" if key=="latch" else "slide",
		"axis":Vector3.FORWARD if key=="latch" else DIRECTION,
		"minimum":0.0,"maximum":1.4 if key=="latch" else TRAVEL,
		"read":func(): return latch_angle if key=="latch" else key_lift,
		"write":func(value: float): move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=key
			if key=="return": key_lift=TRAVEL
			refresh()
			return true,
		"owns":func(): return held==key,
		"end":func():
			held=""
			if guard.key_carried(): key_lift=0
			refresh()
			guard.manipulation_changed.emit()}

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	if key=="latch":
		# The bar cannot pass through a key partway over the hook lip.
		latch_angle=clampf(value,.9 if key_lift>.004 and key_lift<.05 else 0.0,1.4)
	else:
		if latch_angle<.9: return
		key_lift=clampf(value,0,TRAVEL)
		if key_lift>=TRAVEL-.001 and not guard.key_carried(): guard.take_key()
		elif key_lift<=.001 and guard.key_carried(): guard.return_key()
	refresh()

func refresh() -> void:
	guard._latch.rotation.z=-latch_angle
	guard._key.position=Vector3(0,.146,.038)+DIRECTION*key_lift
	guard._key.visible=guard.key_on_hook or held in ["key","return"]
	guard._check.visible=guard.key_carried()
	key_area.collision_layer=1 if guard.key_on_hook else 0
	return_area.collision_layer=1 if guard.key_carried() else 0

func snapshot() -> Dictionary:
	# Custody deliberately resets with the existing session owner. Only the
	# mechanical latch and the unfinished lift of a hanging key persist.
	return {"latch_angle":latch_angle,"key_lift":key_lift if guard.key_on_hook else 0.0}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2: return false
	for key: String in ["latch_angle","key_lift"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT]: return false
		if not is_finite(float(value[key])) or value[key]<0: return false
		if value[key]>(1.4 if key=="latch_angle" else TRAVEL): return false
	return value.key_lift<=.004 or value.key_lift>=.05 or value.latch_angle>=.9

func restore(value: Dictionary) -> void:
	held=""
	latch_angle=float(value.latch_angle) if valid(value) else 0.0
	key_lift=float(value.key_lift) if valid(value) and guard.key_on_hook else 0.0
	refresh()
