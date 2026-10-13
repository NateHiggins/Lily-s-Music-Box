extends RefCounted
## Hand motion belongs to the retained panel owner. Mesh nodes stay under that
## owner so the native binder and electrical/material references remain valid.
var panel: Node3D
var door_pivot: Node3D
var main_pivot: Node3D
var held := ""
var door_angle := -1.15
var main_angle := 0.0
var native := false
var door_closed := Transform3D.IDENTITY
var blade_closed := Transform3D.IDENTITY
var handle_closed := Transform3D.IDENTITY
var targets: Array[Area3D] = []
var door_collision: AnimatableBody3D
var plugs: RefCounted

func configure(owner: Node3D) -> void:
	panel = owner
	door_pivot = Node3D.new()
	door_pivot.name = "CabinetHinge"
	panel.add_child(door_pivot)
	main_pivot = Node3D.new()
	main_pivot.name = "KnifeSwitchHinge"
	panel.add_child(main_pivot)
	door_pivot.position = Vector3(-.32,.5,.14)
	main_pivot.position = Vector3(0,.70,.095)
	door_closed = Transform3D(Basis.IDENTITY,Vector3(0,.5,.14))
	blade_closed = Transform3D(Basis.IDENTITY,Vector3(0,.8,.095))
	handle_closed = Transform3D(Basis.IDENTITY,Vector3(.16,.8,.10))
	refresh()
	_rebuild_targets()

func native_ready() -> void:
	# Native door stock was authored in the old open leaf's local frame.
	# Undo that captured frame once; all subsequent motion is around its actual
	# hinge pin, without reparenting or editing the imported mesh payload.
	native = true
	door_pivot.position = Vector3(-.315,.5,.142)
	var captured := Transform3D(Basis(Vector3.UP,-1.15),Vector3(-.30,.50,.36))
	door_closed = _around(door_pivot.position,Vector3.UP,1.15) * captured
	refresh()
	_rebuild_targets()
	plugs=preload("res://scripts/props/fuse_panel_plugs.gd").new()
	plugs.configure(panel,self)

func _around(origin: Vector3,axis: Vector3,angle: float) -> Transform3D:
	var rotation := Basis(axis,angle)
	return Transform3D(rotation,origin-rotation*origin)

func _rebuild_targets() -> void:
	for area: Area3D in targets:
		area.get_parent().remove_child(area)
		area.queue_free()
	targets.clear()
	for entry: Array in [[panel._door,"door"],[panel._handle,"main"]]:
		var key: String = entry[1]
		targets.append(preload("res://scripts/props/manipulation_area.gd").install(entry[0],func(): return grip(key)))
	if door_collision!=null:
		door_collision.get_parent().remove_child(door_collision)
		door_collision.queue_free()
	door_collision=AnimatableBody3D.new()
	door_collision.name="CabinetLeafCollision"
	door_collision.sync_to_physics=false
	door_pivot.add_child(door_collision)
	var shape := CollisionShape3D.new()
	shape.shape=panel._door.mesh.create_convex_shape()
	door_collision.add_child(shape)
	shape.global_transform=panel._door.global_transform

func grip(key: String) -> Dictionary:
	return {"owner":panel,"part":door_pivot if key=="door" else main_pivot,
		"frame":panel,"kind":"hinge","axis":Vector3.UP if key=="door" else Vector3.RIGHT,
		"minimum":-2.15 if key=="door" else 0.0,"maximum":0.0 if key=="door" else 1.25,
		"read":func(): return door_angle if key=="door" else main_angle,
		"write":func(value: float): _move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=key
			return true,
		"owns":func(): return held==key,
		"end":func(): held="";panel.manipulation_changed.emit()}

func _move(key: String,value: float) -> void:
	if held!=key: return
	if key=="door":
		door_angle=preload("res://scripts/props/mechanism_sweep.gd").limited(panel,door_pivot,Vector3.UP,door_angle,clampf(value,-2.15,0),false)
	else:
		main_angle=clampf(value,0,1.25)
		var opened := main_angle>.09
		if opened!=panel.main_open and panel._clack!=null: panel._clack.play()
		panel.main_open=opened
		# This switch alone cannot certify a repair. The retained fuse and
		# guarded maintenance publication still decide conductor protection.
		panel.load_proved=not opened and panel.protects_conductor()
		if plugs!=null: plugs.update_facts()
	panel._refresh_mechanism()

func refresh() -> void:
	# Legacy restoration/NPC APIs still set electrical facts. They may move
	# the switch to an endpoint, but never erase a hand's partial travel.
	if panel.main_open!=(main_angle>.09): main_angle=1.25 if panel.main_open else 0.0
	door_pivot.basis=Basis(Vector3.UP,door_angle)
	main_pivot.basis=Basis(Vector3.RIGHT,main_angle)
	panel._door.transform=_around(door_pivot.position,Vector3.UP,door_angle)*door_closed
	var main_pose := _around(main_pivot.position,Vector3.RIGHT,main_angle)
	panel._blades.transform=main_pose*blade_closed
	panel._handle.transform=main_pose*handle_closed
	if plugs!=null: plugs.refresh()

func snapshot() -> Dictionary:
	var value := {"door":door_angle,"main":main_angle}
	if plugs!=null: value["plugs"]=plugs.snapshot()
	return value

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=(3 if plugs!=null else 2): return false
	if plugs!=null and not plugs.valid(value.get("plugs")): return false
	for key: String in ["door","main"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])): return false
	return value.door>=-2.15 and value.door<=0 and value.main>=0 and value.main<=1.25

func restore(value: Dictionary) -> void:
	if not valid(value): return
	held=""
	door_angle=float(value.door)
	main_angle=float(value.main)
	panel.main_open=main_angle>.09
	if plugs!=null: plugs.restore(value.plugs)
	panel._refresh_mechanism()
