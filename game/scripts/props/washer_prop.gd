class_name WasherProp
extends FunctionalProp
## Period galvanized powered wringer washer. Native stock provides visual
## form; this actor retains service, save and direct manipulation authorities.

const METAL := Color(0.55, 0.56, 0.58)
const ENAMEL := Color(0.85, 0.84, 0.78)
const BRASS := Color(0.62, 0.48, 0.22)
const RUBBER := Color(0.09, 0.08, 0.07)
const WOOD := Color(0.28, 0.20, 0.14)

var _lower_spin: Node3D
var _upper_spin: Node3D
var _pressure_bridge: Node3D
var _fixed: Node3D
var _lid: Node3D
var _gyrator: Node3D
var _yoke: Node3D
var _roller_lower: Node3D
var _roller_upper: Node3D
var _pressure_screw: Node3D
var _pressure_turn := 0.0
var _safety_released := false
const PRESSURE_TRAVEL := .012
const PRESSURE_TURNS := TAU * 4.0
var _release_bar: Node3D
var _water: MeshInstance3D
var _agitate: AudioStreamPlayer3D
var _thump: AudioStreamPlayer3D
var _control_click: AudioStreamPlayer3D
var _lid_tween: Tween
var _yoke_tween: Tween
var _lid_open := false
var _roller_gap := 0.0
var _wringer_running := false
var _release_warning := 0.0
var _fill_open := false
var _drain_open := false
var _hand_control := ""
var _fill_handles: Array[Node3D] = []
var _drain_handle: Node3D
var _agitator_drive: Node3D
var _wringer_drive: Node3D
var _reset_handle: Node3D
var _fill_openings := Vector2.ZERO
var _drain_opening := 0.0
var _agitator_angle := 0.0
var _wringer_angle := 0.0
var _water_quantity := 1.0
const COCK_TURNS := TAU * 2.0
const DRIVE_STOP := PI / 5.0
var _lid_limits: Array = []
signal manipulation_changed


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "washer / 1926 powered wringer"}]


func _build_visual() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/washer_native.json"))
	assert(int(data.schema)==1)
	var clearance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/washer_clearance.json"))
	assert(int(clearance.schema)==1)
	_lid_limits=clearance.lid_limits_degrees
	for role: String in ["zinc","enamel","frame","brass","rubber","iron","wood"]:
		assert(data.finishes.has(role),"Missing washer finish: "+role)
	var model := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
	var parts := {}
	var finishes := {}
	for part: Node3D in model.get_children():
		part.owner=null
		for child: Node in part.find_children("*","Node",true,false): child.owner=null
		parts[str(part.name)]=part
		model.remove_child(part)
		for draw: MeshInstance3D in part.find_children("*","MeshInstance3D",true,false):
			var role := str(draw.name).trim_prefix(str(part.name)+"_")
			if not finishes.has(role):
				var recipe: Dictionary=data.finishes[role]
				var finish:=MatLib.get_mat(str(recipe.catalog_key)).duplicate() as StandardMaterial3D
				finish.uv1_triplanar=false;finish.normal_scale=float(recipe.normal)
				finish.roughness=float(recipe.roughness)
				finish.albedo_color=Color(recipe.tint[0],recipe.tint[1],recipe.tint[2],recipe.tint[3])
				finishes[role]=SurfacePass.surface_for(finish,{"pigment_variation":float(recipe.pigment),"relief_mul":0.0})
			draw.material_override=finishes[role]
	_fixed=parts.FixedBody;_fixed.name="StaticFrameAndTub";add_child(_fixed)
	_lid=parts.TubLid;add_child(_lid)
	_gyrator=parts.Gyrator;add_child(_gyrator)
	_yoke=parts.SwingingWringer;add_child(_yoke)
	_roller_lower=Node3D.new();_roller_lower.name="LowerRoller";_yoke.add_child(_roller_lower)
	_roller_upper=Node3D.new();_roller_upper.name="UpperRoller";_yoke.add_child(_roller_upper)
	_lower_spin=parts.LowerRoll;_roller_lower.add_child(_lower_spin)
	_upper_spin=parts.UpperRoll;_roller_upper.add_child(_upper_spin)
	_roller_upper.add_child(parts.UpperCarriage)
	_pressure_bridge=parts.PressureBridge;_yoke.add_child(_pressure_bridge)
	_pressure_screw=parts.PressureScrew;_yoke.add_child(_pressure_screw)
	_release_bar=parts.SafetyRelease;_yoke.add_child(_release_bar)
	_reset_handle=parts.SafetyReset;_yoke.add_child(_reset_handle)
	_fill_handles=[parts.HotCock,parts.ColdCock]
	for part: Node3D in _fill_handles:add_child(part)
	_drain_handle=parts.DrainCock;add_child(_drain_handle)
	_agitator_drive=parts.AgitatorDrive;add_child(_agitator_drive)
	_wringer_drive=parts.WringerDrive;add_child(_wringer_drive)
	var water_root: Node3D=parts.WaterSurface
	_water=water_root.get_children()[0] as MeshInstance3D
	water_root.remove_child(_water);add_child(_water);_water.transform=water_root.transform*_water.transform;water_root.free()
	var water:=MatLib.get_mat("water_clear").duplicate() as StandardMaterial3D
	water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;water.albedo_color=Color(.78,.88,.92,.52)
	water.normal_scale=.08;water.uv1_triplanar=false
	_water.material_override=water
	model.free()
	# The tub stays hollow for visible water and later inspection. Original
	# semantic actor owns the actual native fixed-shell collision.
	var body:=StaticBody3D.new();body.name="WasherCollision";add_child(body)
	for draw: MeshInstance3D in _fixed.find_children("*","MeshInstance3D",true,false):
		var collision:=CollisionShape3D.new();collision.shape=draw.mesh.create_trimesh_shape();body.add_child(collision)
		collision.transform=draw.transform
	_agitate=make_emitter("agitate_loop",-23.0,true)
	_thump=make_emitter("thud",-17.0)
	_control_click=make_emitter("tick",-18.0)
	_set_pressure_turn(0.0)


func _start_normal_function() -> void:
	set_agitating(true)


func set_lid_open(open: bool, duration := 0.35) -> void:
	if _hand_control == "lid": return
	_lid_open = open
	if _lid_tween and _lid_tween.is_valid():
		_lid_tween.kill()
	var target := deg_to_rad(82.0 if open else 0.0)
	if duration <= 0.0:
		_move_lid(target)
		return
	_lid_tween = create_tween()
	_lid_tween.tween_method(_move_lid, _lid.rotation.x, target, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func set_wringer_swing(angle_degrees: float, duration := 0.45) -> void:
	if _hand_control == "swing": return
	if _yoke_tween and _yoke_tween.is_valid():
		_yoke_tween.kill()
	var target := deg_to_rad(clampf(angle_degrees, -75.0, 90.0))
	if duration <= 0.0:
		_move_wringer(target)
		return
	_yoke_tween = create_tween()
	_yoke_tween.tween_method(_move_wringer, _yoke.rotation.y, target, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _lid_limit(swing: float) -> float:
	var degrees:=rad_to_deg(swing)
	for i in range(_lid_limits.size()-1):
		if degrees>=float(_lid_limits[i][0]) and degrees<=float(_lid_limits[i+1][0]):
			return deg_to_rad(minf(float(_lid_limits[i][1]),float(_lid_limits[i+1][1])))
	return 0.0

func _move_lid(value: float) -> void:
	_lid.rotation.x=clampf(value,0.0,_lid_limit(_yoke.rotation.y))
	_lid_open=_lid.rotation.x>.01

func _move_wringer(value: float) -> void:
	var before:=_yoke.rotation.y
	var steps:=maxi(1,ceili(absf(value-before)/.025))
	for step in range(1,steps+1):
		var proposal:=lerpf(before,value,float(step)/steps)
		if _lid.rotation.x>_lid_limit(proposal)+.00001: break
		_yoke.rotation.y=proposal


func set_wringer_gap(gap: float) -> void:
	if not is_finite(gap): return
	_safety_released = gap >= .035
	if _safety_released and _wringer_drive != null: _apply_wringer_drive(0.0)
	_roller_gap = maxf(clampf(gap, 0.0, 0.045), _pressure_turn / PRESSURE_TURNS * PRESSURE_TRAVEL)
	_update_pressure_pose()


func _set_pressure_turn(value: float) -> void:
	if not is_finite(value): return
	_pressure_turn = clampf(value, 0.0, PRESSURE_TURNS)
	var lift := _pressure_turn / PRESSURE_TURNS * PRESSURE_TRAVEL
	_pressure_screw.rotation.y = _pressure_turn
	# A tripped safety remains released even if someone tightens the screw.
	_roller_gap = maxf(.040 if _safety_released else 0.0, lift)
	_update_pressure_pose()

func _update_pressure_pose() -> void:
	var lift:=_pressure_turn/PRESSURE_TURNS*PRESSURE_TRAVEL
	_roller_upper.position.y=_roller_gap
	_pressure_screw.position.y=.41+_roller_gap
	_pressure_bridge.position.y=.405+maxf(0.0,_roller_gap-lift)

func pressure_grip() -> Dictionary:
	return {"owner":self,"part":_pressure_screw,"frame":_yoke,"kind":"hinge",
		"axis":Vector3.UP,"minimum":0.0,"maximum":PRESSURE_TURNS,
		"read":func(): return _pressure_turn,
		"write":func(value: float):
			if _hand_control == "pressure": _set_pressure_turn(value),
		"owns":func(): return _hand_control == "pressure",
		"begin":func():
			if not _hand_control.is_empty(): return false
			_hand_control = "pressure"
			return true,
		"end":func(): _hand_control = "";manipulation_changed.emit()}


func set_wringer_running(running: bool) -> void:
	if _hand_control == "wringer_drive": return
	_apply_wringer_drive(DRIVE_STOP if running else 0.0)


func set_agitating(running: bool) -> void:
	if _hand_control == "agitator_drive": return
	_agitator_angle = DRIVE_STOP if running else 0.0
	if _agitator_drive != null: _agitator_drive.rotation.x = _agitator_angle
	_apply_agitation(running)

func _apply_agitation(running: bool) -> void:
	state = PState.OPERATING if running else PState.IDLE
	if _agitate:
		if running and not _agitate.playing:
			_agitate.play()
		elif not running:
			_agitate.stop()


func set_draining(draining: bool) -> void:
	if _hand_control == "drain": return
	_set_drain_opening(1.0 if draining else 0.0)
	# Retained service API is an immediate drained/filled pose.
	_water_quantity = 0.0 if draining else 1.0
	_update_water_pose()


func trigger_safety_release() -> void:
	_release_warning = 1.0
	set_wringer_gap(0.040)
	_apply_wringer_drive(0.0)


func set_service_pose() -> void:
	set_wringer_swing(90.0, 0.0)
	set_lid_open(true, 0.0)
	set_wringer_gap(0.028)


func get_service_state() -> Dictionary:
	return {
		"lid_open": _lid_open,
		"wringer_angle": rad_to_deg(_yoke.rotation.y),
		"roller_gap": _roller_gap,
		"running": _wringer_running,
		"water_visible": _water.visible,
	}


func control_prompt(_control_id: String) -> String:
	return ""


func interact_control(_control_id: String, _player: Node = null) -> Dictionary:
	# Service callers may read the wire card; clicking never moves a mechanism.
	return service_wire_card()


func service_wire_card() -> Dictionary:
	var tub_state := "EMPTY" if not _water.visible else (
			"AGITATING" if state == PState.OPERATING else "FILLED")
	var wringer_state := "RUNNING" if _wringer_running else (
			"RELEASED" if _roller_gap >= 0.035 else "STOPPED")
	return PropServiceWire.card("washer", {
		"lid_state": "OPEN" if _lid_open else "CLOSED",
		"tub_state": tub_state,
		"wringer_state": wringer_state,
		"drain_state": "OPEN" if _drain_open else "CLOSED",
	})
func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	# The release gives before the impossible empty wring. It is small enough
	# to leave the player unsure until the rollers answer on the beat.
	_release_warning = maxf(_release_warning, accent)
	if _hand_control.is_empty() and not _safety_released:
		set_wringer_running(true)
	_thump.volume_db = -19.0 + linear_to_db(clampf(accent, 0.25, 1.0))
	_thump.pitch_scale = rng.randf_range(0.82, 0.96)
	_thump.play()
	if Conductor.infection > 0.6 and _agitate.playing:
		_agitate.pitch_scale = clampf(Conductor.bpm / 72.0, 0.72, 1.32)


func _process(delta: float) -> void:
	_water_quantity = clampf(_water_quantity + delta * ((_fill_openings.x + _fill_openings.y) / 24.0 - _drain_opening / 12.0), 0.0, 1.0)
	_update_water_pose()
	if state == PState.OPERATING:
		_gyrator.rotation.y += delta * 1.35
	if _wringer_running:
		_lower_spin.rotation.x += delta * 2.8
		_upper_spin.rotation.x -= delta * 2.8
	if _hand_control == "release": return
	if _release_warning > 0.001:
		_release_bar.rotation.x = deg_to_rad(-8.0 * _release_warning)
		_release_warning = maxf(0.0, _release_warning - delta * 1.8)
	else:
		_release_bar.rotation.x = lerpf(_release_bar.rotation.x, 0.0,
				clampf(delta * 8.0, 0.0, 1.0))


func _build_primary_interaction() -> void:
	var targets := preload("res://scripts/props/manipulation_area.gd")
	targets.install(_lid,func(): return _washer_grip("lid"))
	# The frame can be swung; the safety bar is a separate spring-loaded part.
	var swing_area := targets.install(_yoke,func(): return _washer_grip("swing"))
	# Exclude the independently moving rollers/screw/bar from frame targeting.
	for child in swing_area.get_children(): child.free()
	for draw in _yoke.get_children():
		if draw is not MeshInstance3D: continue
		# Merged frame bounds fill its open centre and hide the rear fill cocks.
		# A ray-only surface target preserves those real openings.
		var collision := CollisionShape3D.new()
		collision.shape=draw.mesh.create_trimesh_shape();swing_area.add_child(collision)
		collision.transform=draw.transform
	targets.install(_release_bar,func(): return _washer_grip("release"))
	targets.install(_pressure_screw,func(): return pressure_grip())
	for i in _fill_handles.size():
		targets.install(_fill_handles[i],_cock_grip.bind(i))
	targets.install(_drain_handle,func(): return _drive_grip("drain"))
	targets.install(_agitator_drive,func(): return _drive_grip("agitator_drive"))
	targets.install(_wringer_drive,func(): return _drive_grip("wringer_drive"))
	targets.install(_reset_handle,func(): return _drive_grip("reset"))

func _washer_grip(control: String) -> Dictionary:
	var part: Node3D = _lid if control=="lid" else _yoke if control=="swing" else _release_bar
	return {"owner":self,"part":part,"frame":_yoke if control=="release" else self,"kind":"hinge",
		"axis":Vector3.UP if control=="swing" else Vector3.RIGHT if control=="lid" else Vector3.LEFT,
		"minimum":deg_to_rad(-75) if control=="swing" else 0.0,
		"maximum":deg_to_rad(82 if control=="lid" else 90 if control=="swing" else 8),
		"read":func(): return part.rotation.y if control=="swing" else part.rotation.x if control=="lid" else -part.rotation.x,
		"write":func(value: float):
			if _hand_control != control: return
			if control=="swing": _move_wringer(value)
			else:
				if control=="lid": _move_lid(value)
				else: part.rotation.x=-value
				if control=="lid": _lid_open=part.rotation.x>.01
				elif value>=deg_to_rad(7): trigger_safety_release(),
		"owns":func(): return _hand_control == control,
		"begin":func():
			if not _hand_control.is_empty(): return false
			if control=="lid" and _lid_tween != null and _lid_tween.is_valid(): _lid_tween.kill()
			if control=="swing" and _yoke_tween != null and _yoke_tween.is_valid(): _yoke_tween.kill()
			_hand_control=control
			return true,
		"end":func(): _hand_control="";manipulation_changed.emit()}

func mechanism_snapshot() -> Dictionary:
	return {"lid":_lid.rotation.x,"swing":_yoke.rotation.y,"gap":_roller_gap,"pressure":_pressure_turn,
		"fill":[_fill_openings.x,_fill_openings.y],"drain":_drain_opening,
		"agitator":_agitator_angle,"drive":_wringer_angle,"water":_water_quantity}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size() not in [3,4,9]: return false
	if value.size()>=4:
		if not _finite_range(value.get("pressure"),0.0,PRESSURE_TURNS): return false
		if float(value.get("gap",-1)) + .00001 < float(value.pressure)/PRESSURE_TURNS*PRESSURE_TRAVEL: return false
	if value.size()==9:
		if value.get("fill") is not Array or value.fill.size()!=2: return false
		for opening in value.fill:
			if not _finite_range(opening,0.0,1.0): return false
		for key: String in ["drain","water"]:
			if not _finite_range(value.get(key),0.0,1.0): return false
		for key: String in ["agitator","drive"]:
			if not _finite_range(value.get(key),0.0,DRIVE_STOP): return false
		if float(value.gap)>=.035 and float(value.drive)>.25: return false
	return _finite_range(value.get("lid"),0.0,deg_to_rad(82)) and _finite_range(value.get("swing"),deg_to_rad(-75),deg_to_rad(90)) and _finite_range(value.get("gap"),0.0,.045)

func _finite_range(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and float(value)>=low-.00001 and float(value)<=high+.00001

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_hand_control=""
	for motion: Tween in [_lid_tween,_yoke_tween]:
		if motion != null and motion.is_valid(): motion.kill()
	_lid.rotation.x=0
	_yoke.rotation.y=clampf(float(value.swing),deg_to_rad(-75),deg_to_rad(90))
	_move_lid(float(value.lid))
	_set_pressure_turn(float(value.get("pressure",0.0)))
	set_wringer_gap(float(value.gap))
	if value.size()==9:
		_set_fill_opening(0,float(value.fill[0]));_set_fill_opening(1,float(value.fill[1]))
		_set_drain_opening(float(value.drain))
		_agitator_angle=clampf(float(value.agitator),0,DRIVE_STOP)
		_agitator_drive.rotation.x=_agitator_angle
		_apply_agitation(_agitator_angle>.25)
		_apply_wringer_drive(float(value.drive))
		_water_quantity=clampf(float(value.water),0,1)
		_update_water_pose()

func _set_fill_opening(index: int, opening: float) -> void:
	_fill_openings[index]=clampf(opening,0,1)
	_fill_handles[index].rotation.y=_fill_openings[index]*COCK_TURNS
	_fill_open=_fill_openings.x>0 or _fill_openings.y>0

func _set_drain_opening(opening: float) -> void:
	_drain_opening=clampf(opening,0,1)
	_drain_open=_drain_opening>0
	_drain_handle.rotation.x=_drain_opening*PI*.5

func _apply_wringer_drive(angle: float) -> void:
	_wringer_angle=clampf(angle,0,DRIVE_STOP) if not _safety_released else 0.0
	_wringer_drive.rotation.x=_wringer_angle
	_wringer_running=_wringer_angle>.25

func _update_water_pose() -> void:
	_water.visible=_water_quantity>.002
	_water.position.y=lerpf(.405,.79,_water_quantity)
	_water.scale=Vector3(lerpf(.955,1.0,_water_quantity),1.0,lerpf(.955,1.0,_water_quantity))

func _cock_grip(index: int) -> Dictionary:
	var control := "hot" if index==0 else "cold"
	return {"owner":self,"part":_fill_handles[index],"frame":self,"kind":"hinge",
		"axis":Vector3.UP,"minimum":0.0,"maximum":COCK_TURNS,
		"read":func(): return _fill_openings[index]*COCK_TURNS,
		"write":func(value: float):
			if _hand_control==control: _set_fill_opening(index,value/COCK_TURNS),
		"owns":func(): return _hand_control==control,
		"begin":func(): return _claim_control(control),
		"end":func(): _hand_control="";manipulation_changed.emit()}

func _claim_control(control: String) -> bool:
	if not _hand_control.is_empty(): return false
	_hand_control=control
	return true

func _drive_grip(control: String) -> Dictionary:
	var part: Node3D = _drain_handle if control=="drain" else _agitator_drive if control=="agitator_drive" else _wringer_drive if control=="wringer_drive" else _reset_handle
	return {"owner":self,"part":part,"frame":_yoke if control=="reset" else self,"kind":"hinge",
		"axis":Vector3.LEFT if control=="reset" else Vector3.RIGHT,
		"minimum":0.0,"maximum":PI*.5 if control=="drain" else deg_to_rad(30) if control=="reset" else DRIVE_STOP,
		"read":func(): return _drain_opening*PI*.5 if control=="drain" else -part.rotation.x if control=="reset" else _agitator_angle if control=="agitator_drive" else _wringer_angle,
		"write":func(value: float): _write_drive(control,part,value),
		"owns":func(): return _hand_control==control,
		"begin":func(): return _claim_control(control),
		"end":func():
			if control=="reset": part.rotation.x=0
			_hand_control="";manipulation_changed.emit()}

func _write_drive(control: String, part: Node3D, value: float) -> void:
	if _hand_control!=control: return
	match control:
		"drain": _set_drain_opening(value/(PI*.5))
		"agitator_drive":
			_agitator_angle=value;part.rotation.x=value;_apply_agitation(value>.25)
		"wringer_drive": _apply_wringer_drive(value)
		"reset":
			part.rotation.x=-value
			if value>=deg_to_rad(27) and _release_bar.rotation.x>deg_to_rad(-2) and not _wringer_running:
				_safety_released=false;_set_pressure_turn(_pressure_turn)
