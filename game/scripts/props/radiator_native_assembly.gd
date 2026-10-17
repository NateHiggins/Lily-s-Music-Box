class_name RadiatorNativeAssembly
extends Node3D
## The native mechanical rig. Heating, case and inventory facts stay with
## RadiatorProp; this node accepts physical positions and owns presentation.

var section_count := 10
var body: Node3D
var wheel: Node3D
var vent: Node3D
var packing: MeshInstance3D
var header_nut: Node3D
var header_socket: Node3D
var upstream: Node3D
var header_bearing: Node3D
var _shims := {}
var _shoe_points := PackedVector3Array()
var sole_points := PackedVector3Array()
var pitch_wedges: Node3D
var _half := 0.0
var _shift := 0.0
var _body_joint := Vector3.ZERO
var _fixed_joint := Vector3(-.455,.19,-.085)
var feed_angle := 0.0
var body_pose := Transform3D.IDENTITY
var header_joint := Vector3.ZERO
var supported_shim := true
var packing_external := false
var orifices_external := false
var _pose_pitch := INF

static func translation(point: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY,point)

func _group(identity: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = identity
	parent.add_child(node)
	return node

func build(count: int, sliding_wedges := false) -> void:
	assert(body == null and count in [7,8,9,10])
	section_count = count
	_half = float(count-1)*.092*.5
	_shift = maxf(0.0,_half-.322)
	_body_joint = Vector3(-_half+_shift-.071,.19,-.085)
	_shoe_points = RadiatorNativeParts.stock_points("mechanisms","CastShoeFoot")
	var distinct := {}
	for point in _shoe_points:
		if absf(point.y)<.0000001 and not distinct.has(point):
			distinct[point]=true
			sole_points.append(point)
	assert(sole_points.size()>=32,"Native shoe must retain its actual flat sole")
	for identity in ["ArticulatedValveHousing","SweptSupplyElbow"]:
		RadiatorNativeParts.part("mechanisms",identity,self)
	RadiatorNativeParts.part("mechanisms","FixedStemPacking",self,translation(Vector3(0,0,-.03)))
	wheel = _group("SupplyHandwheel",self)
	for identity in ["ThreadedMovingValveCore","SixSpokeHandwheel"]:
		RadiatorNativeParts.part("mechanisms",identity,wheel)
	body = _group("PitchedCastings",self)
	var source := RadiatorNativeParts.part("mechanisms","CastSectionThreeColumnCandidate",body)
	var sections := MultiMeshInstance3D.new()
	sections.name = "SharedCastSections"
	sections.material_override = source.get_active_material(0)
	sections.multimesh = MultiMesh.new()
	sections.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	sections.multimesh.mesh = source.mesh
	sections.multimesh.instance_count = count
	for index in count:
		var pose := translation(Vector3(-_half+_shift+index*.092,.105,-.03))*source.transform
		sections.multimesh.set_instance_transform(index,pose)
	sections.custom_aabb = AABB(Vector3(-_half+_shift-.06,.08,-.18),Vector3(2*_half+.12,.72,.3))
	body.add_child(sections)
	source.free()
	for x in [-_half,_half]:
		RadiatorNativeParts.part("mechanisms","CastShoeFoot",body,translation(Vector3(x+_shift,0,-.03)))
	var far_x := _half+_shift+.046
	for spec in [[Vector3(-_half+_shift-.046,.72,-.085),PI,"BlindHeaderPlug"],
		[Vector3(far_x,.19,-.085),0.0,"BlindHeaderPlug"],
		[Vector3(far_x,.72,-.085),0.0,"VentHeaderReducer"]]:
		var pose := Transform3D(Basis(Vector3.UP,float(spec[1])),spec[0])
		RadiatorNativeParts.part("mechanisms",str(spec[2]),body,pose)
		RadiatorNativeParts.part("mechanisms","HeaderSealWasher",body,pose)
	vent = _group("AutomaticAirVent",body)
	vent.position = Vector3(far_x,.72,-.085)
	for identity in ["VentBody","VentCap","FloatAndNeedle"]:
		RadiatorNativeParts.part("vent",identity,vent)
	for grade in 5:
		RadiatorNativeParts.part("vent","VentOrificeInsert_%d" % grade,vent)
	upstream = _group("ArticulatedFeed",self)
	for identity in ["SphericalNeck_%d" % count,"ValveSphericalRetainer"]:
		RadiatorNativeParts.part("mechanisms",identity,upstream)
	RadiatorNativeParts.part("mechanisms","FloatingMetalBearingRing",self,translation(_fixed_joint))
	header_bearing = _group("HeaderBearing",self)
	RadiatorNativeParts.part("mechanisms","FloatingMetalBearingRing",header_bearing)
	header_socket = _group("HeaderSocket",self)
	RadiatorNativeParts.part("mechanisms","PackedHeaderSocket",header_socket)
	header_nut = _group("CaptiveHeaderRetainer",self)
	RadiatorNativeParts.part("mechanisms","HeaderSphericalRetainer",header_nut)
	packing = RadiatorNativeParts.part("mechanisms","RemovableFibrousUnionPacking",self)
	if not sliding_wedges:
		for identity: String in RadiatorNativeParts.names("shims"):
			if identity.begins_with("Shim_%d_" % count):
				var shim := RadiatorNativeParts.part("shims",identity,self)
				shim.hide()
				_shims[identity] = shim
	set_positions(.35,1.0,0.0,2,0.0,0.0)

func set_positions(pitch: float, supply: float, service: float, grade: int,
		spread: float, packing_out: float) -> void:
	assert(body != null)
	var theta := deg_to_rad(clampf(pitch,-1.0,1.0)*1.15)
	var rotation := Basis(Vector3.BACK,theta)
	# Supply, packing and heat updates do not change the bearing solve. Avoid
	# rescanning the detailed shoe vertices on every mouse event in 23 actors.
	if pitch_wedges!=null:
		pitch_wedges.sync(pitch)
		body_pose=pitch_wedges.solution.pose
		feed_angle=pitch_wedges.solution.feed_angle
		header_joint=pitch_wedges.solution.joint
		rotation=pitch_wedges.solution.rotation
		_pose_pitch=pitch
	elif pitch!=_pose_pitch:
		var lowest := INF
		for x in [-_half,_half]:
			for point in _shoe_points:
				lowest = minf(lowest,(rotation*(point+Vector3(x+_shift,0,-.03)-_body_joint)).y)
		var length := _body_joint.x-_fixed_joint.x
		var sine := (-_fixed_joint.y-lowest)/length
		assert(absf(sine)<1.0,"Radiator feet cannot meet the floor with a rigid feed")
		feed_angle = asin(sine)
		header_joint = _fixed_joint+Vector3(length*cos(feed_angle),length*sin(feed_angle),0)
		body_pose = translation(header_joint)*Transform3D(rotation,Vector3.ZERO)*translation(-_body_joint)
		_pose_pitch=pitch
	var progress := clampf(service,0.0,1.0)
	var withdraw := translation(Vector3(.04*maxf((progress-.4)/.6,0.0),0,0))
	var down := Transform3D(rotation,header_joint)
	body.transform = withdraw*body_pose
	upstream.transform = Transform3D(Basis(Vector3.BACK,feed_angle),_fixed_joint)
	header_bearing.transform = Transform3D(Basis(Vector3.BACK,feed_angle),header_joint)
	header_socket.transform = withdraw*down
	header_nut.transform = withdraw*down*translation(Vector3(.001*minf(progress/.4,1.0),0,0))
	header_nut.transform *= Transform3D(Basis(Vector3.RIGHT,TAU*minf(progress/.4,1.0)),Vector3.ZERO)
	if not packing_external:
		packing.transform = translation(Vector3(0,0,-.12*clampf(packing_out,0.0,1.0)))*down*packing.get_meta("native_pose")
		RadiatorNativeParts.spread_packing(packing,spread)
	wheel.transform = Transform3D(Basis(Vector3.UP,TAU*3.5*clampf(supply,0.0,1.0)),
		Vector3(-.53,.378+.018*clampf(supply,0.0,1.0),-.03))
	if not orifices_external:
		for index in 5:
			(vent.get_node("VentOrificeInsert_%d" % index) as Node3D).visible = index==clampi(grade,0,4)
	if pitch_wedges!=null:
		pitch_wedges.apply_draws()
		supported_shim=true
		return
	# These native wedges fit the five authored pitches. Continuous player
	# pitch adjustment needs a physical sliding wedge before production cutover.
	supported_shim = is_zero_approx(pitch)
	var label := ""
	for option in [[-1.0,"minus1_supply"],[-.35,"minus0.35_supply"],[.35,"0.35_far"],[1.0,"1_far"]]:
		if is_equal_approx(pitch,float(option[0])): label = str(option[1])
	for identity: String in _shims:
		var expected := ("Shim_%d_%s" % [section_count,label]).validate_node_name()
		var shim: MeshInstance3D = _shims[identity]
		shim.visible = identity==expected
		if shim.visible: supported_shim = true
		shim.transform = withdraw*shim.get_meta("native_pose")

func pitch_pose(pitch: float) -> Transform3D:
	# Fast inverse-wedge solve uses the actual sole vertices. The installed
	# bearing solve above still checks every shoe vertex, independently.
	var rotation := Basis(Vector3.BACK,deg_to_rad(clampf(pitch,-1.0,1.0)*1.15))
	var lowest := INF
	for x in [-_half,_half]:
		for point in sole_points:
			lowest=minf(lowest,(rotation*(point+Vector3(x+_shift,0,-.03)-_body_joint)).y)
	var length := _body_joint.x-_fixed_joint.x
	var angle := asin((-_fixed_joint.y-lowest)/length)
	var at := _fixed_joint+Vector3(length*cos(angle),length*sin(angle),0)
	return translation(at)*Transform3D(rotation,Vector3.ZERO)*translation(-_body_joint)

func install_wall_supports(mounts: Array) -> void:
	assert(body != null and mounts.size()==2)
	for mount: Dictionary in mounts:
		var at := Vector3(mount.column[0],mount.column[1],mount.column[2])
		var wall := translation(Vector3(at.x,at.y,float(mount.bracket_z)))
		RadiatorNativeParts.part("supports","SlottedWallBracket",self,wall)
		RadiatorNativeParts.part("supports",str(mount.hardware),self,wall)
		RadiatorNativeParts.part("supports",str(mount.rod),body,translation(at))
