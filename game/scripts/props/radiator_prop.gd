class_name RadiatorProp
extends FunctionalProp
## A second-hand American three-column steam radiator, assembled from cast
## sections rather than drawn as a row of pipes. The Orison is one-pipe steam:
## the angle valve is either open or shut, while a replaceable air-vent orifice
## decides how quickly this radiator wins steam from the building's fixed cycle.

signal supply_changed(open: bool, position: float)
signal vent_changed(grade: int)
signal pitch_changed(toward_supply: float)
signal maintenance_completed(result: Dictionary)
signal physical_action(action_id: String, result: Dictionary)
signal manipulation_changed

## The Dream finds this object interesting (design/DREAM_TENTACLE_DIRECTION
## §13, §17): the tentacle's first contact is the top rim, which it traces
## along the sections; cast iron answers strongly and may be converted.
func dream_target_profile() -> DreamTargetProfile:
	var p := DreamTargetProfile.new()
	p.contact_local = Vector3(0.0, BODY_BOTTOM + 0.56, 0.0)
	p.contact_normal_local = Vector3.UP
	p.trace_axis_local = Vector3.RIGHT
	p.trace_half_length = 0.28
	p.response_strength = 1.2
	p.transformation_eligible = true
	p.material_word = "iron"
	if native_rig != null:
		var pose := native_rig.transform*native_rig.body.transform
		var half := float(section_count-1)*SECTION_PITCH*.5
		p.contact_local = pose*Vector3(maxf(0.0,half-.322),.775,-.085)
		p.contact_normal_local = pose.basis*Vector3.UP
		p.trace_axis_local = pose.basis*Vector3.RIGHT
	return p


const SECTION_PITCH := 0.092
const BODY_BOTTOM := 0.105
const BODY_TOP := 0.775
const BODY_DEPTH := 0.23
## The legacy marker's installed local -X is the building riser end. Keeping
## this explicit is cheaper than mirroring every 1912 riser in the baked floors.
const SUPPLY_X := -0.53
const RISER_X := -0.67

const IRON_DARK := Color(0.16, 0.16, 0.17)
const IRON_SILVER := Color(0.62, 0.63, 0.65)
const PIPE := Color(0.30, 0.28, 0.26)
const BRASS := Color(0.62, 0.55, 0.30)
const RUST := Color(0.31, 0.13, 0.065)
const SHIM := Color(0.24, 0.16, 0.09)

## Marker facts arrive before `_ready()`. Seven-to-nine sections vary the
## family without exceeding the old 810 mm body or moving the shared riser.
var unit := ""
var riser := "H-X"
var section_count := 10
## V2's compatibility marker is a chest-height interaction anchor. Runtime
## composition sets this to 0.75 so the permanent appliance still meets floor.
var installation_drop := 0.0
## V2 fits floating wall ties to the built shell before ready; an empty array
## retains the legacy 190 mm termination and all existing mechanism behavior.
var wall_standoff_depths := PackedFloat32Array()
var use_native_v2 := false
var native_wall_mounts: Array = []
var native_rig: RadiatorNativeAssembly
var native_service_progress := 0.0
var native_packing_spread := 0.0
var native_packing_out := 0.0
var native_packing: RigidBody3D
var native_vent_cap: RigidBody3D
var native_orifices: Node3D
var native_pitch_wedges: Node3D
var _native_held := ""

var supply_position := 1.0
var _supply_held := false
var _hand_writing_supply := false
var _supply_grab_start := 1.0
var _supply_case_start := ""

func supply_grip() -> Dictionary:
	return {"owner":self,"part":_wheel,"frame":_wheel.get_parent(),"kind":"hinge","axis":Vector3.UP,
		"minimum":0.0,"maximum":TAU*3.5,"read":func():return supply_position*TAU*3.5,
		"owns":func(): return _supply_held,
		"begin":func():
			if _supply_held or not _native_held.is_empty() or RealityState.save_write_blocked: return false
			if _wheel_tween != null and _wheel_tween.is_valid(): _wheel_tween.kill()
			_supply_held = true
			_supply_grab_start=supply_position
			_supply_case_start=open_shift_condition
			return true,
		"write":func(value: float):
			if not _supply_held: return
			_hand_writing_supply = true
			set_supply_position(value/(TAU*3.5),0.0)
			_hand_writing_supply = false,
		"end":func():
			_supply_held = false
			supply_changed.emit(supply_position>=.98,supply_position)
			if not is_equal_approx(_supply_grab_start,supply_position):
				var partial := supply_position>.02 and supply_position<.98
				# Preserve repair/open-union/porter and distinct fault authorities.
				# Only the original sounding case enters its wrong-valve branch.
				if unit=="2B" and open_shift_condition==_supply_case_start and _supply_case_start in ["sounding","wrong_valve_partial"]:
					if partial: open_shift_condition="wrong_valve_partial"
					elif supply_position>=.98: open_shift_condition="sounding"
				physical_action.emit("turn_valve",{"action":"turn_valve","condition":_supply_case_start,
					"observation":"valve_at_%.2f"%supply_position,"supply_partial":partial,"supply_position":supply_position})}
var vent_grade := 2
var pitch_toward_supply := 0.35

var _possessed_fit := false
var _body: Node3D
var _shell: Node3D
var _section_multimesh: MultiMeshInstance3D
var _section_bases: Array[Transform3D] = []
var _wheel: Node3D
var _stem: Node3D
var _vent: Node3D
var _shim: Node3D
var _union: Node3D
var _union_moving: Node3D
var _mineral_residue: Node3D
var _damp_patch: Node3D
var _vapor: Node3D
var _porter_tag: Node3D
var _connection_pipe: Node3D
var _knock: AudioStreamPlayer3D
var _tick: AudioStreamPlayer3D
var _whistle: AudioStreamPlayer3D
var _shake := 0.0
var _hammer_time := 0.0
var _wheel_tween: Tween
var _section_heat: Array[float] = []
var _balance
var _service_panel: MaintenanceActivityPanel
var open_shift_condition := "sounding"
## Historical acquisition/use authority. Native packing custody derives from
## its physical mechanism pose; legacy packing_location() retains inventory.
var inventory: MaintenanceInventory

## The 2B union packing's stable item identity.
const PACKING_ITEM := "radiator_packing_2b"
## An unrepaired air-bound fault worsens into riser hammer after this
## many neglected simulation minutes (mechanism-owned degradation).
const NEGLECT_WORSEN_MINUTES := 5.0


func _exit_tree() -> void:
	# A service completion can leave the handwheel's presentation tween active
	# while CampaignShell replaces the building. Kill and release that transient
	# owner here; the durable supply position is already held by the prop/save
	# authority and must not keep the retired scene (or its mesh resources) live.
	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	_wheel_tween = null
	super()


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "radiator / 7-section dark",
			"properties": {"unit": "1D", "riser": "H-D", "section_count": 7}},
		{"label": "radiator / 9-section silver",
			"properties": {"unit": "LOBBY", "riser": "H-A", "section_count": 9}},
	]


func bind_heat_balance(model) -> void:
	_balance = model


func _build_visual() -> void:
	if use_native_v2:
		_build_native_visual()
		return
	add_to_group("radiators")
	if section_count <= 0:
		section_count = 7 + posmod(hash(unit), 3)
	vent_grade = 2 + posmod(hash(unit), 2)

	_body = Node3D.new()
	_body.name = "WorkingAssembly"
	_body.position.y = -installation_drop
	add_child(_body)
	_shell = Node3D.new()
	_shell.name = "CastSections"
	_body.add_child(_shell)

	var iron := Color(0.20, 0.205, 0.20)
	_build_sections(iron)
	_build_supply()
	_build_air_vent()
	_build_pitch_shim()

	retexture(_body, [
		[iron, "iron_neutral", Color(0.55,0.56,0.55)],
		[Color(0.27,0.23,0.16), "brass_dull", Color(0.72,0.65,0.50)],
		[Color(0.12,0.105,0.09), "iron_blackened", Color.WHITE],
		[Color(0.08,0.065,0.045), "iron_blackened", Color(0.7,0.65,0.55)],
		[Color(0.62,0.59,0.47), "mineral_scale", Color(0.82,0.78,0.64)],
		[Color(0.09,0.075,0.06), "fx_grease", Color(0.40,0.32,0.24)],
		[IRON_DARK, "cast_iron", Color(0.32, 0.31, 0.30), 0.68],
		[IRON_SILVER, "cast_iron", Color(0.74, 0.75, 0.76), 0.72],
		[PIPE, "metal", Color(0.52, 0.48, 0.44), 0.50],
		[BRASS, "brass_dull", Color(0.82, 0.72, 0.48), 0.72],
		[RUST, "cast_iron", Color(0.48, 0.20, 0.10), 0.42],
		[SHIM, "wood_dark", Color(0.42, 0.29, 0.18), 0.32],
	])
	# The cast body and fixed valve housing collapse to one draw per finish.
	# A rigged assembly still gets merged internally: keeping the handwheel
	# movable does not require keeping its ring, hub and six spokes as eight
	# draw calls. Only transforms which move independently remain separate.
	# Ten body castings share one mesh/material/draw. Independently moving
	# mechanism owners remain outside this merge boundary.
	merge_static(_wheel)
	merge_static(_vent)
	merge_static(_shell, [_vent, _section_multimesh])
	merge_static(_connection_pipe)
	merge_static(_union, [_union_moving, _mineral_residue])
	merge_static(_union_moving)
	merge_static(_mineral_residue, [_vapor, _damp_patch])
	merge_static(_body, [_shell, _wheel, _shim, _union, _connection_pipe,
			_mineral_residue, _damp_patch, _vapor, _porter_tag,
			_section_multimesh])
	_build_service_areas()
	_apply_pitch()
	_update_balance()
	_apply_visual_state()

	_knock = make_emitter("knock", -12.0)
	_tick = make_emitter("tick", -23.0)
	_whistle = make_emitter("radiator_whistle", -29.0)


func _build_native_visual() -> void:
	add_to_group("radiators")
	vent_grade = 2+posmod(hash(unit),2)
	native_rig = RadiatorNativeAssembly.new()
	native_rig.name = "WorkingAssembly"
	native_rig.position.y = -installation_drop
	add_child(native_rig)
	native_rig.build(section_count,true)
	if not native_wall_mounts.is_empty(): native_rig.install_wall_supports(native_wall_mounts)
	_attach_native_collision()
	_body = native_rig
	_shell = native_rig.body
	_wheel = native_rig.wheel
	_vent = native_rig.vent
	_union_moving = native_rig.header_nut
	_section_multimesh = native_rig.body.get_node("SharedCastSections")
	_build_native_tag()
	_vapor = Node3D.new()
	_vapor.name = "LocalizedUnionVapor"
	_vapor.position = Vector3(-.39,.22,-.1)
	_body.add_child(_vapor)
	for index in 3:
		var puff := _ellipsoid(_vapor,Vector3(0,.035*index,0),Vector3(.012,.022,.012),Color(.7,.72,.7,.3))
		puff.transparency = .55
		puff.set_meta("surface_role","steam_volume")
	preload("res://scripts/props/manipulation_area.gd").install(_wheel,supply_grip)
	preload("res://scripts/props/manipulation_area.gd").install(native_rig.header_nut,native_union_grip.bind("retainer"))
	_install_native_body_grab()
	native_packing=preload("res://scripts/props/radiator_union_packing.gd").new()
	native_packing.name="PhysicalUnionPacking"
	add_child(native_packing)
	native_packing.configure(self)
	native_vent_cap=preload("res://scripts/props/radiator_vent_cap.gd").new()
	native_vent_cap.name="PhysicalVentCap"
	add_child(native_vent_cap)
	native_vent_cap.configure(self)
	preload("res://scripts/props/manipulation_area.gd").install(native_rig.vent.get_node("FloatAndNeedle"),native_vent_cap.float_grip)
	native_pitch_wedges=preload("res://scripts/props/radiator_pitch_wedges.gd").new()
	native_pitch_wedges.name="PhysicalPitchWedges"
	native_rig.add_child(native_pitch_wedges)
	native_pitch_wedges.configure(self)
	_update_balance()
	_apply_visual_state()
	_knock = make_emitter("knock",-12.0)
	_tick = make_emitter("tick",-23.0)
	_whistle = make_emitter("radiator_whistle",-29.0)

func _install_native_body_grab() -> void:
	var sections := native_rig.body.get_node("SharedCastSections") as MultiMeshInstance3D
	var area := preload("res://scripts/props/manipulation_area.gd").new()
	area.name = "CastingGrip"
	area.provider = native_union_grip.bind("withdraw")
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("functional_interaction_areas")
	sections.add_child(area)
	var bounds := sections.multimesh.mesh.get_aabb().grow(.008)
	for index in sections.multimesh.instance_count:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size
		shape.shape = box
		shape.transform = sections.multimesh.get_instance_transform(index)*Transform3D(Basis.IDENTITY,bounds.get_center())
		area.add_child(shape)

func _attach_native_collision() -> void:
	var installed := get_node_or_null("InstalledRadiatorCollision") as StaticBody3D
	if installed == null: return
	# Replace the old centred body envelope. The new envelope follows the
	# actual castings' pitch and service withdrawal, leaving the feed fixed.
	# The remaining legacy feed box filled the real union approach and blocked
	# cloth returned at a different settled orientation. Bind the fixed native
	# feed surfaces, keeping their actual openings instead of that solid box.
	installed.free()
	for identity: String in ["ArticulatedValveHousing","SweptSupplyElbow","FixedStemPacking"]:
		var draw := native_rig.get_node(identity) as MeshInstance3D
		var fixed := StaticBody3D.new()
		fixed.name="NativeFixedFeedCollision"
		draw.add_child(fixed)
		var surface := CollisionShape3D.new()
		surface.shape=RadiatorNativeParts.collision_for(draw.mesh)
		fixed.add_child(surface)
	var body := StaticBody3D.new()
	body.name = "RigidCastingsCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var half := float(section_count-1)*SECTION_PITCH*.5
	var shift := maxf(0.0,half-.322)
	box.size = Vector3(2*half+.092,.72,.24)
	shape.shape = box
	shape.position = Vector3(shift,.43,-.03)
	body.add_child(shape)
	native_rig.body.add_child(body)

func inspection_view() -> Dictionary:
	var at := Vector3(-.35,.25-installation_drop,-.06)
	return {"from":to_global(Vector3(-.24,.60-installation_drop,-.65)),"at":to_global(at),"fov":76.0}

func inspection_view_for(part: Node3D) -> Dictionary:
	if native_pitch_wedges!=null and native_pitch_wedges.owns(part): return native_pitch_wedges.inspection_view(part)
	if native_vent_cap!=null and (part==native_vent_cap or part==native_rig.vent.get_node("FloatAndNeedle") or (native_orifices!=null and native_orifices.owns_part(part))):
		var at: Vector3=native_rig.vent.to_global(Vector3(.043,.045,0))
		return {"from":at+native_rig.global_basis*Vector3(.015,.18,-.025),"at":at,"fov":52.0}
	return inspection_view()

func inspection_started() -> void:
	if use_native_v2:
		physical_action.emit("inspect_vent",{"observation":"vent_grade_%d" % vent_grade,"condition":open_shift_condition})

func native_union_grip(key: String) -> Dictionary:
	if not use_native_v2 or native_rig==null or supply_position>.02: return {}
	if key=="retainer" and native_service_progress>.40001: return {}
	if key=="withdraw" and (native_service_progress<.39999 or (native_packing_spread>0.0 and (native_packing==null or native_packing.station==0))): return {}
	var part := native_rig.header_nut if key=="retainer" else native_rig.body
	return {"owner":self,"part":part,"frame":native_rig,
		"kind":"hinge" if key=="retainer" else "slide",
		"axis":func(): return native_rig.header_socket.basis.x if key=="retainer" else Vector3.RIGHT,
		"minimum":0.0,"maximum":TAU if key=="retainer" else .04,
		"read":func(): return native_service_progress/.4*TAU if key=="retainer" else maxf(0.0,(native_service_progress-.4)/.6)*.04,
		"begin":func():
			if not _native_held.is_empty() or _supply_held or RealityState.save_write_blocked: return false
			_native_held = key
			return true,
		"owns":func(): return _native_held==key,
		"write":func(value: float):
			if _native_held!=key: return
			native_service_progress = .4*clampf(value/TAU,0,1) if key=="retainer" else .4+.6*clampf(value/.04,0,1)
			if native_service_progress>.445: open_shift_condition="opened_uncommitted"
			elif open_shift_condition=="opened_uncommitted": open_shift_condition="sounding" if unit=="2B" else "steady"
			_update_balance()
			_apply_visual_state(),
		"end":func():
			_native_held = ""
			if native_service_progress>.445:
				physical_action.emit("open_service",{"condition":open_shift_condition,"observation":"union_backed_off"})
			manipulation_changed.emit()}

func mechanism_snapshot() -> Dictionary:
	var value := {"supply_position":supply_position,"vent_grade":vent_grade,"pitch":pitch_toward_supply,
		"service_progress":native_service_progress,"packing_spread":native_packing_spread,"packing_out":native_packing_out}
	if native_packing!=null: value.packing=native_packing.snapshot()
	if native_vent_cap!=null: value.vent_cap=native_vent_cap.snapshot()
	if native_pitch_wedges!=null:value.pitch_wedges=native_pitch_wedges.snapshot()
	return value

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size() not in [6,7,8,9]: return false
	for key: String in ["supply_position","vent_grade","pitch","service_progress","packing_spread","packing_out"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])): return false
		var minimum := -1.0 if key=="pitch" else 0.0
		var maximum := 4.0 if key=="vent_grade" else 1.0
		if value[key]<minimum or value[key]>maximum: return false
	if float(value.vent_grade)!=floor(float(value.vent_grade)): return false
	if value.size()>=7:
		if not preload("res://scripts/props/radiator_union_packing.gd").valid(value.get("packing"),value.packing_spread,value.packing_out,value.service_progress): return false
		if value.size()>=8 and not preload("res://scripts/props/radiator_vent_cap.gd").valid(value.get("vent_cap")):return false
		return value.size()<9 or (native_pitch_wedges!=null and native_pitch_wedges.valid(value.get("pitch_wedges"),float(value.pitch)))
	return (value.packing_out<=0.0 or value.packing_spread>=.999) and (value.packing_spread<=0.0 or value.service_progress>=.999)

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_supply_held = false
	_native_held = ""
	native_service_progress = value.service_progress
	native_packing_spread = value.packing_spread
	native_packing_out = value.packing_out
	set_supply_position(float(value.supply_position),0.0)
	set_vent_grade(int(value.vent_grade))
	if native_pitch_wedges!=null:native_pitch_wedges.restore(value.get("pitch_wedges"),float(value.pitch))
	set_pitch(float(value.pitch))
	if native_packing!=null:
		if value.has("packing"): native_packing.restore(value.packing)
		elif native_packing_out>0.0:
			var home_pose: Transform3D=native_packing.home()
			var at := home_pose.origin+Vector3.FORWARD*.12*native_packing_out
			var rot := home_pose.basis.get_rotation_quaternion()
			native_packing.restore({"station":1,"position":[at.x,at.y,at.z],"rotation":[rot.x,rot.y,rot.z,rot.w]})
		else: native_packing.restore({"station":0})
	if native_vent_cap!=null: native_vent_cap.restore(value.get("vent_cap",{"loose":false,"turn":0.0}))
	_update_balance()
	_apply_visual_state()

func _build_native_tag() -> void:
	_porter_tag = Node3D.new()
	_porter_tag.name = "PorterShutoffTag"
	_porter_tag.position = Vector3(SUPPLY_X + 0.12, 0.23, -0.15)
	_body.add_child(_porter_tag)
	var tag := MeshInstance3D.new()
	var paper_model := preload("res://assets/props/radiator_paper_tag.glb").instantiate()
	tag.mesh = (paper_model.get_node("PaperTag") as MeshInstance3D).mesh
	paper_model.free()
	tag.name = "PhysicalPaperTag"
	var paper := MatLib.get_mat("paper", Color(.72,.58,.38)).duplicate() as StandardMaterial3D
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.uv1_triplanar = false
	tag.material_override = paper
	tag.position = Vector3(0.0, -0.06, 0.04)
	_porter_tag.add_child(tag)
	var tag_copy := Label3D.new()
	tag_copy.text = "PORTER\nHEAT OFF"
	tag_copy.font_size = 12
	tag_copy.pixel_size = 0.00125
	tag_copy.modulate = Color(0.16, 0.10, 0.055)
	tag_copy.position = Vector3(0.0, -0.06, 0.044)
	_porter_tag.add_child(tag_copy)


func _build_sections(iron: Color) -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	var shared_mesh := _cast_section_mesh()
	var section_material := MatLib.get_mat("cast_iron",
			Color(0.66, 0.65, 0.61), 0.72).duplicate() as StandardMaterial3D
	section_material.vertex_color_use_as_albedo = true
	shared_mesh.surface_set_material(0, section_material)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = shared_mesh
	instances.instance_count = section_count
	_section_multimesh = MultiMeshInstance3D.new()
	_section_multimesh.name = "SharedCastSections"
	_section_multimesh.multimesh = instances
	# Runtime-created MultiMeshes do not acquire a reliable aggregate AABB until
	# rendering has already considered them for culling. Declare the installed
	# section envelope explicitly so the castings are visible on their first
	# gameplay and evidence frame.
	_section_multimesh.custom_aabb = AABB(
			Vector3(-half_width - 0.05, BODY_BOTTOM, -BODY_DEPTH * 0.5),
			Vector3(half_width * 2.0 + 0.10, BODY_TOP - BODY_BOTTOM,
					BODY_DEPTH))
	_shell.add_child(_section_multimesh)
	for i in section_count:
		var sx := -half_width + float(i) * SECTION_PITCH
		var transform := Transform3D(Basis.IDENTITY,
				Vector3(sx, BODY_BOTTOM, 0.0))
		_section_bases.append(transform)
		instances.set_instance_transform(i, transform)
		# Subtle enamel/casting variation stays coherent by batch, not random
		# damage pasted over every section.
		var age := 0.82 + 0.025 * float((i * 3) % 4)
		instances.set_instance_color(i, Color(age, age * 0.98, age * 0.94))
	# Feet are continuations of the end castings, with broad toes that keep
	# the load out of a century-old floorboard rather than modern box legs.
	for x in [-half_width, half_width]:
		_cyl(_shell, 0.035, 0.047, 0.10, Vector3(x, 0.055, 0), iron)
		_box(_shell, Vector3(0.13, 0.024, 0.20),
				Vector3(x, 0.012, -0.006), iron)
		# Local rust belongs where cast feet meet damp floorboards.
		_box(_shell, Vector3(0.105, 0.006, 0.17),
				Vector3(x, 0.027, -0.006), RUST)
	# A restrained dust shelf appears only in the inaccessible inter-section
	# trough, plus two wall braces that make installation load legible.
	_box(_shell, Vector3(half_width * 1.75, 0.008, 0.055),
			Vector3(0.0, 0.135, 0.075), Color(0.12, 0.105, 0.09))
	for side in 2:
		var x := half_width * .55 * (-1.0 if side==0 else 1.0)
		var depth := wall_standoff_depths[side] if wall_standoff_depths.size()==2 else .19
		var brace := _tube_between(_shell, Vector3(x, 0.58, 0.10),
				Vector3(x, 0.58, depth), 0.009, PIPE)
		brace.name = "WallStandOff"


func _cast_section_mesh() -> ArrayMesh:
	# Shared native casting retains the original profile; every face now has
	# a noncollapsed metre chart, including both closed header caps.
	var model := preload("res://assets/props/radiator_section.glb").instantiate()
	var mesh := (model.get_node("CastSection") as MeshInstance3D).mesh as ArrayMesh
	model.free()
	return mesh

func _source_cast_section_mesh() -> ArrayMesh:
	# One low-cost lathed three-column casting shared by every section. The
	# pronounced header shoulders and narrow waist avoid tube-and-ball anatomy.
	var rings := [
		[0.00, 0.032, 0.082], [0.055, 0.043, 0.108],
		[0.105, 0.046, 0.114], [0.155, 0.034, 0.096],
		[0.30, 0.030, 0.085], [0.50, 0.030, 0.085],
		[0.575, 0.034, 0.096], [0.625, 0.046, 0.114],
		[0.67, 0.043, 0.108], [BODY_TOP - BODY_BOTTOM, 0.032, 0.082],
	]
	var sides := 12
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring_index in rings.size():
		var ring: Array = rings[ring_index]
		for side in sides:
			var theta := TAU * float(side) / float(sides)
			vertices.append(Vector3(cos(theta) * float(ring[1]),
					float(ring[0]), sin(theta) * float(ring[2])))
			normals.append(Vector3(cos(theta) / float(ring[1]), 0.0,
					sin(theta) / float(ring[2])).normalized())
			uvs.append(Vector2(float(side) / float(sides),
					float(ring[0]) / (BODY_TOP - BODY_BOTTOM)))
	var bottom_center := vertices.size()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.DOWN)
	uvs.append(Vector2(0.5, 0.0))
	var top_center := vertices.size()
	vertices.append(Vector3(0.0, BODY_TOP - BODY_BOTTOM, 0.0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 1.0))
	for ring_index in range(rings.size() - 1):
		for side in sides:
			var next_side := (side + 1) % sides
			var a := ring_index * sides + side
			var b := (ring_index + 1) * sides + side
			var c := (ring_index + 1) * sides + next_side
			var d := ring_index * sides + next_side
			# Clockwise from the casting exterior; the opposite winding culls the
			# entire section from the room side and leaves only the wall visible.
			for index in [a, c, b, a, d, c]:
				indices.append(index)
	for side in sides:
		var next_side := (side + 1) % sides
		for index in [bottom_center, next_side, side]:
			indices.append(index)
		var top_side := (rings.size() - 1) * sides + side
		var top_next := (rings.size() - 1) * sides + next_side
		for index in [top_center, top_side, top_next]:
			indices.append(index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_supply() -> void:
	# The riser emerges from the floor, turns through a real angle valve and
	# reaches the first section through a serviceable union. Condensate returns
	# along this same pipe, as a one-pipe steam installation requires.
	_connection_pipe = Node3D.new()
	_connection_pipe.name = "HeatingBranchConnection"
	_body.add_child(_connection_pipe)
	_cyl(_connection_pipe, 0.029, 0.029, 0.18,
			Vector3(RISER_X, 0.09, 0), PIPE)
	var elbow := _cyl(_connection_pipe, 0.041, 0.041, 0.075,
			Vector3(RISER_X, 0.17, 0), PIPE)
	elbow.scale = Vector3(1.0, 0.8, 1.0)
	var branch := _cyl(_connection_pipe, 0.028, 0.028,
			absf(RISER_X + 0.38), Vector3((RISER_X - 0.38) * 0.5,
			0.19, 0), PIPE)
	branch.rotation_degrees.z = 90.0

	# Valve body, bonnet and packing nut are distinct from the union. Six-sided
	# collars read as wrench flats instead of decorative gold cylinders.
	_cyl(_connection_pipe, 0.052, 0.047, 0.105,
			Vector3(SUPPLY_X, 0.205, 0), PIPE)
	var bonnet := _cyl(_connection_pipe, 0.037, 0.047, 0.038,
			Vector3(SUPPLY_X, 0.275, 0), BRASS)
	bonnet.name = "ValveBonnet"
	var packing := _cyl(_connection_pipe, 0.032, 0.032, 0.024,
			Vector3(SUPPLY_X, 0.307, 0), BRASS)
	packing.name = "PackingNut"

	_union = Node3D.new()
	_union.name = "ServiceUnionAndPacking"
	_union.position = Vector3(-0.42, 0.19, -0.055)
	_body.add_child(_union)
	var fixed_union := _cyl(_union, 0.049, 0.049, 0.070,
			Vector3.ZERO, PIPE)
	fixed_union.rotation_degrees.z = 90.0
	_union_moving = Node3D.new()
	_union_moving.name = "UnionMovingHalf"
	_union.add_child(_union_moving)
	var union_nut := _cyl(_union_moving, 0.052, 0.052, 0.050,
			Vector3(0.015, 0, 0), BRASS)
	union_nut.rotation_degrees.z = 90.0
	union_nut.name = "UnionNut"

	_mineral_residue = Node3D.new()
	_mineral_residue.name = "MineralLeakResidue"
	_mineral_residue.position.z = -0.075
	_union.add_child(_mineral_residue)
	var crust := _cyl(_mineral_residue, 0.032, 0.014, 0.045,
			Vector3(0.0, -0.045, 0.018), Color(0.62, 0.59, 0.47))
	crust.rotation_degrees.z = 7.0
	_damp_patch = Node3D.new()
	_damp_patch.name = "LocalizedDampness"
	_mineral_residue.add_child(_damp_patch)
	_box(_damp_patch, Vector3(0.18, 0.004, 0.12),
			Vector3(0.0, -0.186, 0.02), Color(0.09, 0.075, 0.06))
	_vapor = Node3D.new()
	_vapor.name = "LocalizedUnionVapor"
	_mineral_residue.add_child(_vapor)
	for i in 3:
		var puff := _ellipsoid(_vapor,
				Vector3(0.02 + i * 0.018, 0.02 + i * 0.035, -0.01),
				Vector3(0.018 + i * 0.007, 0.026 + i * 0.01,
				0.012 + i * 0.005), Color(0.70, 0.72, 0.70, 0.30))
		puff.transparency = 0.55
		puff.set_meta("surface_role", "steam_volume")

	_porter_tag = Node3D.new()
	_porter_tag.name = "PorterShutoffTag"
	_porter_tag.position = Vector3(SUPPLY_X + 0.12, 0.23, -0.15)
	_body.add_child(_porter_tag)
	var tag := MeshInstance3D.new()
	var paper_model := preload("res://assets/props/radiator_paper_tag.glb").instantiate()
	tag.mesh = (paper_model.get_node("PaperTag") as MeshInstance3D).mesh
	paper_model.free()
	tag.name = "PhysicalPaperTag"
	var paper := MatLib.get_mat("paper", Color(.72,.58,.38)).duplicate() as StandardMaterial3D
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.uv1_triplanar = false
	tag.material_override = paper
	tag.position = Vector3(0.0, -0.06, 0.04)
	_porter_tag.add_child(tag)
	var tag_copy := Label3D.new()
	tag_copy.text = "PORTER\nHEAT OFF"
	tag_copy.font_size = 12
	tag_copy.pixel_size = 0.00125
	tag_copy.modulate = Color(0.16, 0.10, 0.055)
	tag_copy.position = Vector3(0.0, -0.06, 0.044)
	_porter_tag.add_child(tag_copy)

	_wheel = Node3D.new()
	_wheel.name = "SupplyHandwheel"
	_wheel.position = Vector3(SUPPLY_X, 0.385, 0)
	_body.add_child(_wheel)
	_stem = Node3D.new()
	_stem.name = "RisingValveStem"
	_wheel.add_child(_stem)
	_cyl(_stem, 0.010, 0.010, 0.095, Vector3(0, -0.058, 0), PIPE)
	make_ring(0.062, 0.009, Vector3.ZERO,
			Color(0.27, 0.23, 0.16), 0.68, 0.16, _wheel)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var end := Vector3(cos(angle) * 0.056, 0, sin(angle) * 0.056)
		_tube_between(_wheel, Vector3.ZERO, end, 0.0055,
				Color(0.27, 0.23, 0.16))
	_cyl(_wheel, 0.015, 0.015, 0.018, Vector3.ZERO,
			Color(0.27, 0.23, 0.16))
	# Oil and wrench contact are confined to the mechanism actually handled.
	_cyl(_connection_pipe, 0.036, 0.036, 0.005,
			Vector3(SUPPLY_X, 0.319, 0), Color(0.08, 0.065, 0.045))


func _build_air_vent() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_vent = Node3D.new()
	_vent.name = "ReplaceableAirVent"
	_vent.position = Vector3(half_width + 0.045, 0.615, -0.085)
	_shell.add_child(_vent)
	var neck := _cyl(_vent, 0.010, 0.010, 0.045,
			Vector3(0.020, 0, 0), BRASS)
	neck.rotation_degrees.z = 90.0
	var body := _cyl(_vent, 0.017, 0.023, 0.070,
			Vector3(-0.012, 0.015, 0), BRASS)
	body.rotation_degrees.z = -12.0
	_ellipsoid(_vent, Vector3(-0.018, 0.050, 0),
			Vector3(0.018, 0.026, 0.018), BRASS)
	# A wet vent stains downward and toward the wall; no generic rust wash.
	_box(_vent, Vector3(0.018, 0.075, 0.004),
			Vector3(-0.010, -0.050, 0.016), RUST)


func _build_pitch_shim() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_shim = Node3D.new()
	_shim.name = "FarEndPitchShim"
	_shim.position = Vector3(-half_width, 0.006, 0.035)
	_body.add_child(_shim)


func _build_service_areas() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_service_area("listen", "Listen at radiator", Vector3(0.0, 0.46, -0.12),
			Vector3(0.38, 0.38, 0.16))
	_service_area("feel_temperature", "Feel section temperature",
			Vector3(0.08, 0.48, -0.12), Vector3(0.42, 0.36, 0.14))
	_service_area("inspect_vent", "Inspect air vent",
			Vector3(half_width + 0.04, 0.62, -0.06),
			Vector3(0.17, 0.20, 0.20))
	_service_area("inspect_union", "Inspect union and packing",
			Vector3(-0.42, 0.20, -0.04), Vector3(0.18, 0.18, 0.20))
	_service_area("turn_valve", "Turn supply valve",
			Vector3(SUPPLY_X, 0.39, -0.02), Vector3(0.18, 0.18, 0.20))
	_service_area("open_service", "Open union for service",
			Vector3(-0.38, 0.24, -0.03), Vector3(0.16, 0.14, 0.18))
	_service_area("commit_repair", "Seat union and test radiator",
			Vector3(-0.30, 0.28, -0.02), Vector3(0.18, 0.16, 0.18))


func _service_area(action_id: String, prompt: String, at: Vector3,
		size: Vector3) -> void:
	var script := preload("res://scripts/props/radiator_interaction_surface.gd")
	var area := script.new()
	area.setup(self, action_id, prompt, size, at + Vector3.DOWN * installation_drop)
	add_child(area)


func _start_normal_function() -> void:
	state = PState.OPERATING


func interact_prompt() -> String:
	return "Listen at radiator"


func interact(player: Node) -> void:
	if use_native_v2: return
	_begin_vent_service(player)


func interact_area(area: Area3D) -> void:
	if area != null and area.get_script() == preload(
			"res://scripts/props/radiator_interaction_surface.gd"):
		perform_physical_action(str(area.get("action_id")))


func perform_physical_action(action_id: String) -> Dictionary:
	var result := {"action": action_id, "condition": open_shift_condition}
	match action_id:
		"listen":
			result.observation = "quiet_tick" if open_shift_condition in [
					"repaired", "porter_temporary_shutoff", "cooling"] \
					else "riser_hammer_and_local_hiss"
		"feel_temperature":
			result.observation = _temperature_observation()
		"inspect_vent":
			result.observation = "vent_grade_%d" % vent_grade
		"inspect_union":
			if open_shift_condition == "opened_uncommitted" and \
					packing_location() == "radiator" and inventory != null:
				# The open union exposes the packing; inspecting it with
				# the union backed off removes it. Custody transfers
				# through the inventory authority - the world's packing
				# and the player's packing are one record.
				inventory.grant(PACKING_ITEM, "radiator_2b_union")
				result.observation = "packing_removed_from_union"
			elif open_shift_condition == "opened_uncommitted":
				result.observation = "open_and_damp" \
						if packing_location() == "radiator" \
						else "union_open_missing_packing"
			else:
				result.observation = "tool_marked_union"
		"turn_valve":
			set_supply_position(0.42 if supply_position >= 0.98 else 1.0)
			open_shift_condition = "wrong_valve_partial" \
					if supply_position < 0.98 else "sounding"
			_apply_visual_state()
			result.observation = "valve_at_%.2f" % supply_position
		"open_service":
			apply_open_shift_condition("opened_uncommitted")
			result.observation = "union_backed_off"
		"commit_repair":
			if _repair_prerequisites_satisfied():
				_begin_vent_service(get_tree().get_first_node_in_group(
						"player_controller"))
				result.observation = "service_sequence_opened"
			else:
				result.observation = "mechanism_not_prepared_for_commit"
		_:
			result.observation = "no_change"
	physical_action.emit(action_id, result.duplicate(true))
	return result


func prompt_for_action(action_id: String, authored_prompt: String) -> String:
	if action_id == "commit_repair" and not _repair_prerequisites_satisfied():
		return ""
	if action_id == "inspect_union" and \
			open_shift_condition == "opened_uncommitted" and \
			packing_location() == "radiator" and inventory != null:
		return "Remove radiator packing"
	return authored_prompt


func _repair_prerequisites_satisfied() -> bool:
	# A radiator whose packing is gone for good cannot be seated and
	# tested; packing at the union or in the player's custody can.
	if packing_location() == "consumed" and \
			open_shift_condition != "repaired":
		return false
	if not is_inside_tree():
		return true
	var orders := get_tree().root.find_child("WorkOrders", true, false) as WorkOrders
	return orders == null or orders.job_stage(ServiceRoundDirector.JOB_ID) \
			== "repairable"


func bind_inventory(custody_authority: MaintenanceInventory) -> void:
	inventory = custody_authority


## Exactly one custodian, derived from the inventory authority alone:
## "radiator" (never taken), "player" (granted, unconsumed), or
## "consumed" (used up in a repair).
func packing_location() -> String:
	if native_packing!=null:
		if native_packing.station==0: return "radiator"
		return "player" if _native_held=="packing" else "world"
	if inventory == null:
		return "radiator"
	if inventory.has_item(PACKING_ITEM):
		return "player"
	if inventory.is_consumed(PACKING_ITEM):
		return "consumed"
	return "radiator"


## The mechanism owns its own degradation: an unrepaired air-bound fault
## worsens into riser hammer after enough neglected minutes. Returns true
## the moment the condition actually changes.
func apply_neglect(elapsed_minutes: float) -> bool:
	if open_shift_condition != "sounding":
		return false
	if elapsed_minutes < NEGLECT_WORSEN_MINUTES:
		return false
	return apply_open_shift_condition("worsening_hammer")


func _temperature_observation() -> String:
	match open_shift_condition:
		"porter_temporary_shutoff", "cooling": return "cooling_from_supply_end"
		"wrong_valve_partial": return "first_sections_warm_far_sections_cold"
		"opened_uncommitted": return "union_warm_sections_cooling"
		"repaired": return "evenly_warming"
		_: return "supply_end_hot_far_end_cool"


func _begin_vent_service(player: Node) -> bool:
	if use_native_v2: return false
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "radiator_vent_service"):
		_service_panel = null
		return false
	return true


func maintenance_snapshot() -> Dictionary:
	return {"supply_position": supply_position, "vent_grade": vent_grade}


## Preview animates the actual fittings but does not publish heat state. The
## committed result below is the only route to the physical setters.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	match str(step.get("id", "")):
		"shut_supply", "open_supply":
			if _wheel:
				_wheel.rotation.y = clampf(value, 0.0, 1.0) * TAU * 3.5
				_wheel.position.y = 0.378 + clampf(value, 0.0, 1.0) * 0.018
		"free_vent":
			if _vent:
				_vent.position.y = sin(value * PI) * 0.006
		"seat_orifice":
			if _vent:
				_vent.rotation.x = deg_to_rad(clampf(value, 0.0, 1.0) * 44.0)


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	if _vent and not use_native_v2:
		_vent.position.y = 0.0
	set_supply_position(float(snapshot.get("supply_position", supply_position)), 0.2)
	set_vent_grade(int(snapshot.get("vent_grade", vent_grade)))


func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if use_native_v2 and native_packing!=null and (native_packing.station!=0 or native_packing_spread>.001 or native_packing_out>.001): return
	if use_native_v2 and (native_service_progress>.001 or (native_vent_cap!=null and native_vent_cap.leak()>.001)): return
	if use_native_v2:
		native_service_progress = 0.0
		native_packing_spread = 0.0
		native_packing_out = 0.0
	if inventory != null and inventory.has_item(PACKING_ITEM):
		# Packing carried back by the player is seated during the repair:
		# custody transfers from player into the mechanism, once.
		inventory.consume(PACKING_ITEM)
	if _vent and not use_native_v2:
		_vent.position.y = 0.0
	set_vent_grade(int(patch.get("vent_grade", vent_grade)))
	set_supply_position(float(patch.get("supply_position", supply_position)))
	open_shift_condition = "repaired"
	_apply_visual_state()
	maintenance_completed.emit(result.duplicate(true))


func maintenance_panel_closed() -> void:
	_service_panel = null


func set_supply_open(open: bool, seconds := 0.65) -> void:
	set_supply_position(1.0 if open else 0.0, seconds)


## The maintenance rig can stop the wheel part-way so the player can learn
## why that is not a valid setting. Endpoints are the only healthy states.
func set_supply_position(value: float, seconds := 0.65) -> void:
	if _supply_held and not _hand_writing_supply: return
	supply_position = clampf(value, 0.0, 1.0)
	if _wheel == null:
		_update_balance()
		return
	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	var turns := supply_position * TAU * 3.5
	var target_y := 0.378 + supply_position * 0.018
	if seconds <= 0.0:
		_wheel.rotation.y = turns
		_wheel.position.y = target_y
	else:
		_wheel_tween = create_tween()
		_wheel_tween.set_trans(Tween.TRANS_CUBIC)
		_wheel_tween.set_ease(Tween.EASE_IN_OUT)
		_wheel_tween.tween_property(_wheel, "rotation:y", turns, seconds)
		_wheel_tween.parallel().tween_property(_wheel, "position:y", target_y,
				seconds)
	_update_balance()
	_apply_visual_state()
	if not _supply_held: supply_changed.emit(supply_position >= 0.98, supply_position)


func set_vent_grade(grade: int) -> void:
	# Once physical inserts are bound, changing a grade requires exchanging
	# the actual part. Legacy saves migrate once through the stock owner.
	if native_orifices!=null and not native_orifices._restoring: return
	vent_grade = clampi(grade, 0, 4)
	if _vent and not use_native_v2:
		# The small clocking difference lets inspection renders prove that the
		# insert was changed without turning a fixed orifice into a thermostat.
		_vent.rotation.x = deg_to_rad(float(vent_grade) * 11.0)
	_update_balance()
	_apply_visual_state()
	vent_changed.emit(vent_grade)


## Positive values pitch the far end upward so condensate returns toward the
## supply. Negative values are the service fault; zero is visually level.
func set_pitch(value: float) -> void:
	pitch_toward_supply = clampf(value, -1.0, 1.0)
	_apply_pitch()
	_update_balance()
	_apply_visual_state()
	pitch_changed.emit(pitch_toward_supply)


func _apply_pitch() -> void:
	if use_native_v2:
		_apply_visual_state()
		return
	if _shell == null:
		return
	_shell.rotation.z = deg_to_rad(-pitch_toward_supply * 1.15)
	if _shim:
		_shim.visible = pitch_toward_supply > 0.05


func get_heat_state() -> Dictionary:
	var local := {
		"supply_position": supply_position,
		"supply_open": supply_position >= 0.98,
		"supply_partial": supply_position > 0.02 and supply_position < 0.98,
		"vent_grade": vent_grade,
		"pitch": pitch_toward_supply,
		"riser": riser,
		"open_shift_condition": open_shift_condition,
	}
	if _balance and graph_node_id != "":
		local.merge(_balance.result_for(graph_node_id), true)
	return local


## Domain-owned physical consequences for the open-shift slice. The situation
## observer requests one of these authored conditions; this mechanism remains
## the only writer of valve/vent state and sound response.
func apply_open_shift_condition(condition: String) -> bool:
	match condition:
		"worsening_hammer":
			open_shift_condition = condition
			set_pitch(-0.35)
			_play_open_shift_cycle("knock")
		"porter_temporary_shutoff":
			open_shift_condition = condition
			set_supply_open(false)
		"wrong_valve_partial":
			open_shift_condition = condition
			set_supply_position(0.42)
			_play_open_shift_cycle("knock")
		"vent_removed":
			open_shift_condition = condition
			set_vent_grade(0)
			_play_open_shift_cycle("whistle")
		"opened_uncommitted":
			open_shift_condition = condition
			set_vent_grade(1)
			set_supply_position(0.18)
			_play_open_shift_cycle("hiss")
		"sounding":
			open_shift_condition = condition
			set_supply_open(true)
		"cooling":
			open_shift_condition = condition
			set_supply_open(false)
		"repaired":
			open_shift_condition = condition
			set_vent_grade(2)
			set_supply_open(true)
		_:
			return false
	if use_native_v2:
		if condition=="opened_uncommitted": native_service_progress = 1.0
		elif condition=="repaired": native_service_progress = 0.0
	_apply_visual_state()
	return true


func _apply_visual_state() -> void:
	if use_native_v2:
		if native_rig == null: return
		native_rig.set_positions(pitch_toward_supply,supply_position,native_service_progress,
			vent_grade,native_packing_spread,native_packing_out)
		if native_packing!=null: native_packing.refresh()
		if native_vent_cap!=null: native_vent_cap.refresh()
		_update_native_vapor()
		if _porter_tag: _porter_tag.visible = open_shift_condition=="porter_temporary_shutoff"
		return
	if _section_multimesh == null:
		return
	var mm := _section_multimesh.multimesh
	_section_heat.clear()
	for i in section_count:
		var normalized := float(i) / maxf(1.0, float(section_count - 1))
		var heat := 0.0
		match open_shift_condition:
			"repaired": heat = 0.72 - normalized * 0.08
			"sounding", "worsening_hammer": heat = 0.82 - normalized * 0.58
			"wrong_valve_partial": heat = maxf(0.0, 0.78 - normalized * 1.45)
			"opened_uncommitted": heat = maxf(0.0, 0.50 - normalized * 0.92)
			"cooling": heat = maxf(0.0, 0.26 - normalized * 0.20)
			"porter_temporary_shutoff": heat = 0.06
			_: heat = 0.25
		_section_heat.append(heat)
		# This is restrained heat tint in old enamel and oxide, not emission.
		# The range is wide enough to read at gameplay distance and makes a
		# partial fill visibly stop before the far sections.
		var cold := Color(0.30, 0.32, 0.34)
		var hot := Color(0.93, 0.48, 0.23)
		var casting_age := 0.91 + 0.025 * float((i * 3) % 4)
		mm.set_instance_color(i, cold.lerp(hot, heat) * casting_age)
	if _union_moving:
		_union_moving.position.x = 0.028 if open_shift_condition \
				== "opened_uncommitted" else 0.0
	if _vapor:
		_vapor.visible = open_shift_condition == "opened_uncommitted"
	if _damp_patch:
		_damp_patch.visible = open_shift_condition in ["opened_uncommitted",
				"worsening_hammer"]
	if _mineral_residue:
		# Dampness, residue, and vapor share one bounded evidence mesh after the
		# static merge. Expose it only when the union is mechanically open.
		_mineral_residue.visible = open_shift_condition == "opened_uncommitted"
	if _porter_tag:
		_porter_tag.visible = open_shift_condition == "porter_temporary_shutoff"


func visual_state_receipt() -> Dictionary:
	var warm_sections := 0
	for heat: float in _section_heat:
		if heat >= 0.30:
			warm_sections += 1
	return {
		"condition": open_shift_condition,
		"sections": section_count,
		"supply_position": supply_position,
		"vent_grade": vent_grade,
		"warm_sections": warm_sections,
		"union_open": native_service_progress>.4 if use_native_v2 else (_union_moving != null and _union_moving.position.x > 0.01),
		"vapor_visible": (_vapor != null and _vapor.visible) if use_native_v2 else (_mineral_residue != null and _mineral_residue.visible),
		"damp_visible": false if use_native_v2 else (_mineral_residue != null and _mineral_residue.visible),
		"porter_tag_visible": _porter_tag != null and _porter_tag.visible,
		"installation_drop": installation_drop,
	}


func _play_open_shift_cycle(kind: String) -> void:
	# Headless acceptance runs prove state and teardown, not an audio device.
	# Gameplay still publishes the authored sound through the real prop owner.
	if DisplayServer.get_name() != "headless":
		play_ambient_cycle(kind, 1.0)


func _update_balance() -> void:
	if _balance and graph_node_id != "":
		_balance.update_radiator(graph_node_id, supply_position, vent_grade,
				pitch_toward_supply,native_pressure_leak() if use_native_v2 else 0.0)

func native_pressure_leak() -> float:
	return maxf(maxf(native_union_leak(),native_vent_cap.leak() if native_vent_cap!=null else 0.0),native_orifices.leak(self) if native_orifices!=null else 0.0)

func native_union_leak() -> float:
	if native_packing!=null and native_packing.station==1: return 1.0
	return maxf(clampf((native_service_progress-.4)/.6,0.0,1.0),native_packing_spread)

func _update_native_vapor() -> void:
	if _vapor:
		var heat := get_heat_state()
		_vapor.visible = native_union_leak()>.01 and supply_position>.02 and float(heat.get("boiler_output",1.0))>.02


## Called by AmbientSoundscape. Central scheduling makes a riser answer as a
## pipe system instead of letting every radiator improvise alone.
func play_ambient_cycle(kind: String, intensity := 0.5) -> void:
	if state != PState.OPERATING:
		return
	var heat := get_heat_state()
	match kind:
		"whistle":
			if not bool(heat.get("supply_open", false)):
				return
			_whistle.volume_db = lerpf(-34.0, -23.0, intensity)
			_whistle.pitch_scale = lerpf(0.90, 1.10,
					float(vent_grade) / 4.0)
			_whistle.play()
		"knock":
			var faulted := bool(heat.get("hammer", false))
			_knock.volume_db = lerpf(-22.0, -11.0, intensity) + \
					(4.0 if faulted else 0.0)
			_knock.pitch_scale = rng.randf_range(0.88, 1.08)
			_knock.play()
			_shake = maxf(_shake, intensity * (0.005 if faulted else 0.002))
		_:
			_tick.volume_db = lerpf(-29.0, -18.0, intensity)
			_tick.pitch_scale = rng.randf_range(0.82, 1.18)
			_tick.play()


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -11.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(pow(2.0, pitch * 0.15 / 12.0), 0.9, 1.1)
	_knock.play()
	_shake = maxf(_shake, accent * 0.006)


func _process(delta: float) -> void:
	if use_native_v2:
		_shake = maxf(_shake-delta*.04,0.0)
		if native_packing!=null: native_packing.tick()
		if native_vent_cap!=null: native_vent_cap.tick()
		_update_native_vapor()
		return
	if _section_multimesh == null:
		return
	_hammer_time += delta
	var active := _shake > 0.0002 or open_shift_condition in [
			"worsening_hammer", "wrong_valve_partial"]
	var amplitude := maxf(_shake, 0.0016 if active else 0.0)
	for i in section_count:
		var transform := _section_bases[i]
		if active:
			var phase := _hammer_time * 22.0 - float(i) * 0.62
			transform.origin += Vector3(sin(phase) * amplitude,
					cos(phase * 0.73) * amplitude * 0.22,
					sin(phase * 0.81) * amplitude * 0.35)
		_section_multimesh.multimesh.set_instance_transform(i, transform)
	if _connection_pipe:
		_connection_pipe.rotation.z = sin(_hammer_time * 20.0) \
				* amplitude * 0.7 if active else 0.0
	_shake = maxf(_shake - delta * 0.04, 0.0)


## Possession does not invent a new power. It drives a real water-hammer
## symptom in the motif already carried by this radiator's authored riser.
func possess_fit(beats := 4) -> void:
	if _possessed_fit:
		return
	_possessed_fit = true
	for i in range(beats):
		play_ambient_cycle("knock", 0.85 + 0.1 * float(i % 2))
		await get_tree().create_timer(0.24 if i % 2 else 0.38, false).timeout
		if not is_inside_tree():
			return
	_possessed_fit = false


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _pmat(color, 0.55, 0.0)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.52, 0.28, parent)


func _ellipsoid(parent: Node3D, at: Vector3, scale_: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.position = at
	node.scale = scale_
	node.material_override = _pmat(color, 0.52, 0.28)
	parent.add_child(node)
	return node


func _tube_between(parent: Node3D, a: Vector3, b: Vector3, radius: float,
		color: Color) -> MeshInstance3D:
	var delta := b - a
	var tube := _cyl(parent, radius, radius, delta.length(),
			(a + b) * 0.5, color)
	var direction := delta.normalized()
	var dot := Vector3.UP.dot(direction)
	if dot < -0.9999:
		tube.rotation_degrees.x = 180.0
	elif dot < 0.9999:
		tube.quaternion = Quaternion(Vector3.UP, direction)
	return tube
