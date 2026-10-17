extends Node
## Physical call-flag service. The board and ServiceRound retain their signals;
## no puzzle overlay, job-stage writer or automatic completion patch lives here.
const MODEL=preload("res://assets/props/annunciator_controls.glb")
const FLAG_LOW := -8.0*PI/180.0
const FLAG_HIGH := 34.0*PI/180.0
const RESET_HIGH := PI*.5
var board: OtisProp
var angles: Array[float]=[]
var reset_travel := 0.0
var held: Node3D
var _reset_pending := false
var _settling := false
var _contact_home := .63
var _completion: Dictionary

func configure(owner: OtisProp) -> bool:
	board=owner
	var library := MaintenanceActivityLibrary.load_default()
	if not library.is_valid() or not library.has_activity("annunciator_flag_service"):return false
	_completion=library.activity("annunciator_flag_service").get("completion",{})
	_contact_home=float(_completion.get("mechanism_patch",{}).get("contact_alignment",.63))
	var model := MODEL.instantiate()
	var parts := {}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):parts[str(draw.name)]=draw.mesh
	for name: String in ["ResetKnob","FlagArm","FlagSeat","FlagBearings"]:
		if not parts.has(name):model.free();return false
	for draw: MeshInstance3D in board.find_children("*","MeshInstance3D",true,false):
		var payload := str(draw.get_meta("native_service_instrument_part",""))
		if payload=="M01_P001":draw.material_override=_stock("radiator_service_brass")
		for i in board._flag_arms.size():
			if payload=="M01_P%03d"%(3+i*3):
				draw.mesh=parts.FlagSeat
				# Keep the original live ivory material reference.
				var original := draw.material_override as StandardMaterial3D
				if original==null:model.free();return false
				_copy_finish(original,"porcelain_fixture")
	for arm: MeshInstance3D in board._flag_arms:
		arm.mesh=parts.FlagArm
		var journals := MeshInstance3D.new()
		journals.name="FlagBearings";journals.mesh=parts.FlagBearings
		journals.material_override=_stock("radiator_service_brass")
		board.add_child(journals);journals.position=arm.position
	for spec: Array in [["FixedContactMetal","nickel_plated",board],["FixedContactInsulators","porcelain_fixture",board],
		["ResetBearing","radiator_service_brass",board],["MovingContactMetal","nickel_plated",board._contact_bridge]]:
		if not parts.has(spec[0]):model.free();return false
		var draw := MeshInstance3D.new()
		draw.name=spec[0];draw.mesh=parts[spec[0]]
		draw.material_override=_stock(spec[1])
		spec[2].add_child(draw)
	if not parts.has("ResetKnob"):model.free();return false
	board._reset_spindle.mesh=parts.ResetKnob
	# Preserve the original live material object while correcting its finish.
	# The old general-purpose brass has fixture-sized verdigris on this knob.
	var original := board._reset_spindle.material_override as StandardMaterial3D
	if original==null:model.free();return false
	_copy_finish(original,"radiator_service_brass")
	model.free()
	for arm: MeshInstance3D in board._flag_arms:angles.append(arm.rotation.x)
	for name in ["DispatchReach","CallHardwareReach"]:
		var area := board.get_node_or_null(name) as Area3D
		if area!=null:area.collision_layer=0
	for part: MeshInstance3D in board._flag_arms+[board._contact_bridge,board._reset_spindle]:
		preload("res://scripts/props/manipulation_area.gd").install(part,grip.bind(part))
	apply_pose()
	return true

func _stock(key: String) -> StandardMaterial3D:
	var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	_copy_finish(material,key)
	return material

func _copy_finish(original: StandardMaterial3D,key: String) -> void:
	var worked := MatLib.get_mat(key) as StandardMaterial3D
	for property: String in ["albedo_texture","roughness_texture","normal_texture","normal_enabled","metallic","roughness","uv1_scale","texture_filter"]:
		original.set(property,worked.get(property))
	original.albedo_color=Color.WHITE
	original.normal_scale=1.0 if key=="radiator_service_brass" else .35
	original.uv1_triplanar=false
	original.set_meta("v2_surface_stock",key)

func grip(part: Node3D) -> Dictionary:
	var flag := board._flag_arms.find(part)
	var contact: bool=part==board._contact_bridge
	var reset: bool=part==board._reset_spindle
	if flag<0 and not contact and not reset:return {}
	return {"owner":board,"part":part,"frame":board,"kind":"hinge",
		"axis":Vector3.RIGHT if flag>=0 else Vector3.BACK,
		"minimum":deg_to_rad(26) if flag==0 and board.stuck_flag else FLAG_LOW if flag>=0 else -_contact_home*deg_to_rad(36) if contact else 0.0,
		"maximum":FLAG_HIGH if flag>=0 else (1.0-_contact_home)*deg_to_rad(36) if contact else RESET_HIGH,
		"read":func():return angles[flag] if flag>=0 else (board.contact_alignment-_contact_home)*deg_to_rad(36) if contact else reset_travel,
		"begin":func():
			if held!=null or RealityState.save_write_blocked:return false
			held=part;return true,
		"owns":func():return held==part,
		"write":func(value: float):
			if held!=part:return
			if flag>=0:
				angles[flag]=clampf(value,deg_to_rad(26) if flag==0 and board.stuck_flag else FLAG_LOW,FLAG_HIGH)
				if flag==0 and angles[flag]>=FLAG_HIGH-.0001:board.stuck_flag=false
			elif contact:board.contact_alignment=clampf(_contact_home+value/deg_to_rad(36),0,1)
			else:
				reset_travel=clampf(value,0,RESET_HIGH)
				if reset_travel>=RESET_HIGH-.001:
					board.bank_reset=1.0;_reset_pending=true
			apply_pose(),
		"end":func():
			held=null;_settling=true;board.manipulation_changed.emit()}

func apply_pose() -> void:
	for i in angles.size():board._flag_arms[i].rotation.x=angles[i]
	board._contact_bridge.rotation.z=(board.contact_alignment-_contact_home)*deg_to_rad(36)
	board._reset_spindle.basis=Basis(Vector3.BACK,reset_travel)*Basis(Vector3.RIGHT,PI*.5)

func _process(delta: float) -> void:
	if board==null:return
	var moving := false
	for i in angles.size():
		if held==board._flag_arms[i]:continue
		var target := deg_to_rad(26) if i==0 and board.stuck_flag else FLAG_LOW*board.bank_reset
		angles[i]=move_toward(angles[i],target,delta*1.5)
		moving=moving or absf(angles[i]-target)>.00001
	if held!=board._reset_spindle:
		reset_travel=move_toward(reset_travel,0.0,delta*2.5)
		moving=moving or reset_travel>.00001
	apply_pose()
	if _reset_pending and held==null and not moving and not board.stuck_flag and absf(board.contact_alignment-_contact_home)<=.07:
		_reset_pending=false
		board.maintenance_completed.emit(_completion.duplicate(true))
		_settling=true
	if _settling and not moving and held==null:
		_settling=false;board.manipulation_changed.emit()

func snapshot() -> Dictionary:
	return {"version":1,"flags":angles.duplicate(),"stuck":board.stuck_flag,"contact":board.contact_alignment,
		"reset":reset_travel,"bank_reset":board.bank_reset,"armed":_reset_pending}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() not in [6,7] or typeof(value.get("version")) not in [TYPE_INT,TYPE_FLOAT] or value.version!=1 or value.get("stuck") is not bool:return false
	if value.has("armed") and (value.armed is not bool or (value.armed and value.get("bank_reset")!=1.0)):return false
	if value.size()==7 and not value.has("armed"):return false
	if value.get("flags") is not Array or value.flags.size()!=8:return false
	for number: Variant in value.flags:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or number<FLAG_LOW-.00001 or number>FLAG_HIGH+.00001:return false
	for key: String in ["contact","reset","bank_reset"]:
		var maximum := RESET_HIGH if key=="reset" else 1.0
		# JSON's ordinary float formatting may round pi/2 a few ulps upward.
		# Accept that representation and restore to the actual physical stop.
		var epsilon := .00000001 if key=="reset" else 0.0
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])) or value[key]<0 or value[key]>maximum+epsilon:return false
	return not value.stuck or value.flags[0]>=deg_to_rad(26)-.00001

func restore(value: Dictionary) -> void:
	held=null;_reset_pending=bool(value.get("armed",false));_settling=true
	angles.assign(value.flags);board.stuck_flag=value.stuck;board.contact_alignment=value.contact
	board.bank_reset=value.bank_reset;reset_travel=clampf(float(value.reset),0.0,RESET_HIGH)
	apply_pose()

func adopt_legacy_pose() -> void:
	held=null;_reset_pending=false;reset_travel=0.0
	for i in angles.size():angles[i]=deg_to_rad(26) if i==0 and board.stuck_flag else FLAG_LOW*board.bank_reset
	apply_pose()
