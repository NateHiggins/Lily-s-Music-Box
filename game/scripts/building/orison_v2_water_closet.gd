extends BakedFurnitureInteraction
## V2 supplies the porcelain body separately; preserve the production flush owner.
const MODEL := "res://assets/props/bath_water_closet.glb"
var model_path := MODEL
var inlet_clear := true
var unit: String:
	get: return owner_unit

func _refill_duration() -> float:
	return 2.1 if inlet_clear else 5.0

func _finish_refill() -> void:
	super._finish_refill()
	_water.stop()

signal manipulation_changed
const PartTarget = preload("res://scripts/props/manipulation_area.gd")
const Sweep = preload("res://scripts/props/mechanism_sweep.gd")
var parts: Dictionary = {}
var _held := ""
var water_level := 1.0
var _draining := false
var _cover_velocity := 0.0

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.free()
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	add_child(model)
	_skin(model)
	remove_child(_lever)
	_lever.free()
	for key in ["SeatHinge", "RaisedLid", "CisternHandle", "CisternCover", "FloatArm", "FlushBall"]:
		var part := model.find_child(key, true, false) as Node3D
		part.reparent(self)
		parts[key] = part
		var area := PartTarget.install(part, func(): return _target(key))
		Sweep.install(part)
		# Mesh-shaped ray targets preserve the empty space around the bent linkage.
		var draws := part.find_children("*","MeshInstance3D",true,false)
		for index in draws.size():
			var draw: MeshInstance3D=draws[index]
			var target_shape: CollisionShape3D=area.get_child(index)
			target_shape.shape=draw.mesh.create_trimesh_shape()
			target_shape.global_transform=draw.global_transform
			if draw.name=="HandleInsideArm":
				# This enclosed linkage cannot contact the player. Its convex hull
				# would fill the bend and hide the independently selectable lift rod.
				var hull: Node=part.get_node("HandMovedCollision").get_child(index)
				hull.get_parent().remove_child(hull)
				hull.free()
	_lever = parts.CisternHandle
	# Concave fixed castings preserve the bowl and cistern openings.
	var casting := StaticBody3D.new()
	casting.name="FixedCastingCollision"
	add_child(casting)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if draw.name in ["WaterSeal", "StoredWater"]: continue
		var shape := CollisionShape3D.new()
		shape.shape = draw.mesh.create_trimesh_shape()
		casting.add_child(shape)
		shape.global_transform = draw.global_transform
	parts["Water"] = model.find_child("CisternWaterSurface", true, false)

func manipulation_target(hit: Dictionary) -> Dictionary:
	var collider: Node=hit.get("collider")
	for key in parts:
		if key!="Water" and collider!=null and parts[key].is_ancestor_of(collider): return _target(key)
	return {}

func interact(_actor: Node = null) -> Dictionary:
	# The legacy entry point may report condition, but cannot operate the handle.
	return service_wire_card()

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(.18,1.38,.04)), "at":to_global(Vector3(0,.63,.235))}

func _target(key: String) -> Dictionary:
	var free := key == "CisternCover"
	var slide := key == "FlushBall"
	var limits := _limits(key)
	return {"owner":self, "part":parts[key], "frame":self,
		"kind":"free" if free else "slide" if slide else "hinge",
		"axis":Vector3.UP if slide else Vector3.RIGHT if key in ["SeatHinge","RaisedLid"] else Vector3.BACK,
		"minimum":limits.x, "maximum":limits.y,
		"read":func(): return parts[key].position if free else _value(key),
		"write":func(value): _move_part(key,value),
		"begin":func():
			if not _held.is_empty() or RealityState.save_write_blocked: return false
			_held = key
			return true,
		"owns":func(): return _held == key,
		"end":func(): _held = ""; manipulation_changed.emit()}

func _limits(key: String) -> Vector2:
	match key:
		"SeatHinge", "RaisedLid": return Vector2(0,deg_to_rad(82))
		"CisternHandle": return Vector2(deg_to_rad(-36),0)
		"FloatArm": return Vector2(-.65,.12)
		"FlushBall": return Vector2(.558,.628)
	return Vector2.ZERO

func _value(key: String) -> float:
	if key == "FlushBall": return parts[key].position.y
	return parts[key].rotation.x if key in ["SeatHinge","RaisedLid"] else parts[key].rotation.z

func _move_part(key: String, value: Variant) -> void:
	if _held != key: return
	var part: Node3D = parts[key]
	if key == "CisternCover":
		var proposed: Vector3 = value.clamp(Vector3(-.65,.025,-.12),Vector3(.65,1.18,.42))
		# The rim must be cleared before the cover can leave its seat.
		if part.position.y < .85: proposed.x = clampf(proposed.x,-.025,.025); proposed.z = .235
		if absf(proposed.x)<.45 and absf(proposed.z-.235)<.21: proposed.y=maxf(proposed.y,.817)
		var pose := part.transform
		pose.origin=proposed
		if Sweep.clear(self,part,pose): part.position=proposed
		_cover_velocity=0
		return
	var limits := _limits(key)
	var proposed := clampf(float(value),limits.x,limits.y)
	if key == "SeatHinge": proposed=minf(proposed,_value("RaisedLid"))
	if key == "RaisedLid": proposed=maxf(proposed,_value("SeatHinge"))
	var axis := Vector3.RIGHT if key in ["SeatHinge","RaisedLid"] else Vector3.UP if key=="FlushBall" else Vector3.BACK
	proposed=Sweep.limited(self,part,axis,_value(key),proposed,key=="FlushBall")
	if key == "FlushBall": part.position.y=proposed
	elif key in ["SeatHinge","RaisedLid"]: part.rotation.x=proposed
	else: part.rotation.z=proposed
	if key == "CisternHandle" and proposed<=deg_to_rad(-33): _flush_stroke_completed=true
	if (key=="CisternHandle" and proposed<-.18) or (key=="FlushBall" and proposed>.57):
		_draining=true
		_refilling=true

func _physics_process(delta: float) -> void:
	if parts.is_empty(): return
	if _held != "CisternHandle": _lever.rotation.z=move_toward(_lever.rotation.z,0,delta*2.0)
	var ball: Node3D=parts.FlushBall
	if _held != "FlushBall":
		var lift := maxf(-_lever.rotation.z*.10,.05 if _draining and water_level>.08 else 0.0)
		ball.position.y=.558+lift
	if _draining:
		water_level=maxf(0,water_level-delta*.55)
		if water_level<=.02 and _held!="FlushBall" and absf(_lever.rotation.z)<.02: _draining=false
	elif _value("FloatArm")<-.001 or (water_level<1.0 and _held!="FloatArm"):
		water_level=minf(1.06 if _held=="FloatArm" else 1.0,water_level+delta/_refill_duration())
	if _held != "FloatArm": parts.FloatArm.rotation.z=lerpf(-.65,0,clampf(water_level,0,1))
	parts.Water.position.y=lerpf(.535,.745,clampf(water_level,0,1.04))
	if _refilling and not _draining and water_level>=1: _finish_refill()
	if (_draining or water_level<.99) and not _water.playing: _water.play()
	elif not _draining and water_level>=.99: _water.stop()
	if _held != "CisternCover":
		var cover: Node3D=parts.CisternCover
		var floor_y := .817 if absf(cover.position.x)<.45 and absf(cover.position.z-.235)<.21 else .025
		if cover.position.y>floor_y:
			_cover_velocity+=delta*3.0
			var pose := cover.transform
			pose.origin.y=maxf(floor_y,pose.origin.y-_cover_velocity*delta)
			if Sweep.clear(self,cover,pose): cover.transform=pose
			else: _cover_velocity=0

func mechanism_snapshot() -> Dictionary:
	var state := {"water":water_level,"draining":_draining,"refilling":_refilling,"stroke":_flush_stroke_completed}
	for key in ["SeatHinge","RaisedLid","CisternHandle","FloatArm","FlushBall"]:
		var limits:=_limits(key)
		state[key]=clampf(_value(key),limits.x,limits.y)
	var pos: Vector3=parts.CisternCover.position
	state["cover"]=[pos.x,pos.y,pos.z]
	return state

func valid_mechanism(state: Dictionary) -> bool:
	for key in ["SeatHinge","RaisedLid","CisternHandle","FloatArm","FlushBall","water"]:
		if not state.get(key) is float and not state.get(key) is int: return false
		var limits:=Vector2(0,1.06) if key=="water" else _limits(key)
		if not is_finite(float(state[key])) or state[key]<limits.x-.000001 or state[key]>limits.y+.000001: return false
	var cover: Variant=state.get("cover")
	if not cover is Array or cover.size()!=3: return false
	for value in cover:
		if not (value is float or value is int) or not is_finite(float(value)): return false
	var pos:=Vector3(cover[0],cover[1],cover[2])
	return pos==pos.clamp(Vector3(-.65,.025,-.12),Vector3(.65,1.18,.42)) and state.SeatHinge<=state.RaisedLid+.000001 and state.get("draining") is bool and state.get("refilling") is bool and state.get("stroke") is bool

func restore_mechanism(state: Dictionary) -> void:
	if not valid_mechanism(state): return
	_held=""
	for key in ["SeatHinge","RaisedLid","CisternHandle","FloatArm","FlushBall"]:
		if key=="FlushBall": parts[key].position.y=state[key]
		elif key in ["SeatHinge","RaisedLid"]: parts[key].rotation.x=state[key]
		else: parts[key].rotation.z=state[key]
	parts.CisternCover.position=Vector3(state.cover[0],state.cover[1],state.cover[2])
	water_level=state.water
	_draining=state.draining
	_refilling=state.refilling
	_flush_stroke_completed=state.stroke
	_cover_velocity=0

func _skin(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(surface)
			if source.resource_name == "WaterSeal":
				var water := MatLib.get_mat("water_clear").duplicate() as StandardMaterial3D
				water.albedo_color = Color(.75,.84,.85,.055)
				water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				water.roughness = .08
				node.set_surface_override_material(surface, water)
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				node.set_surface_override_material(surface, MatLib.get_mat(source.resource_name))
	for child in node.get_children(): _skin(child)

func _exit_tree() -> void:
	for tween in [_flush_tween, _busy_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if _water != null:
		var stream := _water.stream
		_water.stop()
		_water.stream = null
		PropAudio.release_stream("sink_water", stream)
