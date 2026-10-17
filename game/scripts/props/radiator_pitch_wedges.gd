extends Node3D
## Two fixed timber stocks. Actual shoe contact maps insertion to pitch;
## radiator/heat/save/case authorities continue to own the resulting setting.
const SOURCE := "res://data/orison_v2/radiator_sliding_wedge.json"
static var _spec: Dictionary={}
var radiator: Node3D
var rig: RadiatorNativeAssembly
var rows := {}
var _authority_pitch := INF
var _tip_z := 0.0
var depths := {"supply":0.0,"far":0.0}
var solution := {}

static func spec() -> Dictionary:
	if _spec.is_empty():
		_spec=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		assert(_spec.schema_version==1)
		assert(_spec.width_m>.12 and _spec.length_m>.1 and _spec.rise_per_m>0 and _spec.rise_per_m<.25)
		assert(_spec.corner_clip_m>0 and _spec.corner_clip_m<_spec.width_m*.25)
	return _spec

func configure(owner: Node3D) -> void:
	radiator=owner
	rig=owner.native_rig
	_tip_z=INF
	for point in rig.sole_points: _tip_z=minf(_tip_z,point.z-.03)
	for old: Node3D in rig._shims.values(): old.free()
	rig._shims.clear()
	var half := float(rig.section_count-1)*.092*.5
	var shift := maxf(0.0,half-.322)
	for side: String in ["supply","far"]:
		var sign := -1.0 if side=="supply" else 1.0
		var anchor := Node3D.new()
		anchor.name=side.capitalize()+"WedgeTrack"
		anchor.position=Vector3(shift+sign*half,0,_tip_z)
		add_child(anchor)
		var draw := RadiatorNativeParts.part("wedges","SlidingPitchWedge_timber",anchor)
		var shape := draw.mesh.create_convex_shape(true,false)
		shape.margin=.00005
		var body := StaticBody3D.new()
		draw.add_child(body)
		var contact := CollisionShape3D.new()
		contact.shape=shape
		body.add_child(contact)
		var area := preload("res://scripts/props/manipulation_area.gd").new()
		area.provider=grip.bind(side)
		area.collision_layer=1;area.collision_mask=0;area.monitoring=false
		area.add_to_group("functional_interaction_areas")
		draw.add_child(area)
		var cursor := CollisionShape3D.new()
		cursor.shape=shape
		area.add_child(cursor)
		rows[side]={"sign":sign,"anchor":anchor,"draw":draw}
	rig.pitch_wedges=self
	sync(radiator.pitch_toward_supply)

func depth_for_pose(side: String,pose: Transform3D) -> float:
	var row: Dictionary=rows[side]
	var minimum := INF
	for point in rig.sole_points:
		var at := pose*(point+Vector3(row.anchor.position.x,0,-.03))
		minimum=minf(minimum,at.y+float(spec().rise_per_m)*at.z)
	return maxf(0.0,minimum/float(spec().rise_per_m)-_tip_z)

func depth_for_pitch(side: String,pitch: float) -> float:
	return depth_for_pose(side,rig.pitch_pose(pitch))

func _terms(theta: float) -> Vector2:
	var floor_support := INF;var wedge_support := INF
	var sine := sin(theta);var cosine := cos(theta)
	var slope: float=spec().rise_per_m
	for point in rig.sole_points:
		var vertical := sine*point.x+cosine*point.y
		floor_support=minf(floor_support,vertical)
		wedge_support=minf(wedge_support,vertical+slope*(point.z-.03-_tip_z))
	return Vector2(floor_support,wedge_support)

func _difference(theta: float,value: Dictionary) -> float:
	var terms := _terms(theta)
	var slope: float=spec().rise_per_m
	return 2*rig._half*sin(theta)+minf(terms.x,terms.y-slope*float(value.far))-minf(terms.x,terms.y-slope*float(value.supply))

func solve(value: Dictionary) -> Dictionary:
	var limit := deg_to_rad(1.15)
	if _difference(-limit,value)>.00000002 or _difference(limit,value)<-.00000002:return {}
	var low := -limit;var high := limit
	for index in 25:
		var middle := (low+high)*.5
		if _difference(middle,value)<0:low=middle
		else:high=middle
	var theta := (low+high)*.5
	var terms := _terms(theta)
	var clearance := sin(theta)*(float(rows.supply.anchor.position.x)-rig._body_joint.x)-cos(theta)*rig._body_joint.y+minf(terms.x,terms.y-float(spec().rise_per_m)*float(value.supply))
	var length := rig._body_joint.x-rig._fixed_joint.x
	var sine := (-clearance-rig._fixed_joint.y)/length
	if absf(sine)>=1.0:return {}
	var beta := asin(sine)
	if absf(beta)>deg_to_rad(22) or absf(beta-theta)>deg_to_rad(22):return {}
	var at := rig._fixed_joint+Vector3(length*cos(beta),length*sin(beta),0)
	var rotation := Basis(Vector3.BACK,theta)
	return {"pitch":clampf(rad_to_deg(theta)/1.15,-1,1),"feed_angle":beta,"joint":at,"rotation":rotation,
		"pose":Transform3D(Basis.IDENTITY,at)*Transform3D(rotation,Vector3.ZERO)*Transform3D(Basis.IDENTITY,-rig._body_joint)}

func sync(pitch: float) -> void:
	if pitch==_authority_pitch:return
	var pose := rig.pitch_pose(pitch)
	for side: String in rows:
		var row: Dictionary=rows[side]
		depths[side]=depth_for_pose(side,pose) if pitch*float(row.sign)>0 else 0.0
	solution=solve(depths)
	assert(not solution.is_empty(),"Legacy pitch must have a real supported wedge pose")
	_authority_pitch=pitch
	apply_draws()

func apply_draws() -> void:
	for side: String in rows:rows[side].draw.position.z=float(depths[side])

func set_depth(side: String,value: float) -> void:
	var candidate := depths.duplicate()
	candidate[side]=clampf(value,0,float(spec().length_m)-.004)
	var result := solve(candidate)
	if result.is_empty():
		# The rigid feed and actual spherical joints provide physical stops.
		# Both wedges may lift the body; neither one silently resets the other.
		var old: float=depths[side];var wanted: float=candidate[side]
		var low := 0.0;var high := 1.0
		for index in 22:
			var fraction := (low+high)*.5
			candidate[side]=lerpf(old,wanted,fraction)
			if solve(candidate).is_empty():high=fraction
			else:low=fraction
		candidate[side]=lerpf(old,wanted,low)
		result=solve(candidate)
	if result.is_empty():return
	depths=candidate;solution=result
	_authority_pitch=float(result.pitch)
	apply_draws()
	radiator.set_pitch(_authority_pitch)

func snapshot() -> Dictionary:
	return depths.duplicate()

func valid(value: Variant,pitch: float) -> bool:
	if value is not Dictionary or value.size()!=2:return false
	for side: String in ["supply","far"]:
		if typeof(value.get(side)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[side])):return false
		if value[side]<0 or value[side]>float(spec().length_m)-.004:return false
	var result := solve(value)
	return not result.is_empty() and absf(float(result.pitch)-pitch)<.00001

func restore(value: Variant,pitch: float) -> void:
	_authority_pitch=INF
	if value==null:sync(pitch);return
	depths=value.duplicate();solution=solve(depths)
	_authority_pitch=pitch
	apply_draws()

func manipulation_target(hit: Dictionary) -> Dictionary:
	for side: String in rows:
		if rows[side].draw.is_ancestor_of(hit.collider):return grip(side)
	return {}

func owns(part: Node3D) -> bool:
	return rows.values().any(func(row):return row.draw==part)

func inspection_view(part: Node3D) -> Dictionary:
	var at := part.to_global(Vector3(0,.009,-.11))
	return {"from":at+rig.global_basis*Vector3(.14,.22,-.30),"at":at,"fov":62.0}

func grip(side: String) -> Dictionary:
	var row: Dictionary=rows[side]
	if radiator.supply_position>.02 or radiator.native_service_progress>.40001:return {}
	var key := "pitch_"+side
	return {"owner":radiator,"part":row.draw,"frame":row.anchor,"kind":"slide","axis":Vector3.BACK,
		"minimum":0.0,"maximum":float(spec().length_m)-.004,
		"read":func():return row.draw.position.z,
		"begin":func():
			if not radiator._native_held.is_empty() or radiator._supply_held or RealityState.save_write_blocked:return false
			radiator._native_held=key
			return true,
		"owns":func():return radiator._native_held==key,
		"write":func(value: float):
			if radiator._native_held!=key:return
			set_depth(side,value),
		"end":func():
			radiator._native_held=""
			radiator.manipulation_changed.emit()}
