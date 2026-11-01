extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
const PATH := "res://data/orison_v2/household_stoves.json"
const VisualMotion := preload("res://scripts/building/orison_v2_stove_visual_motion.gd")
var _fit: Dictionary
var _control_pivots: Dictionary = {}
var _flame_mount: Dictionary = {}
var _service_obstructions_by_variant: Dictionary = {}

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	_fit = data.native_service
	if data.has("flame_mount"):
		if data.flame_mount is not Dictionary or data.flame_mount.size()!=3:return false
		for key:String in ["port_y","radius","phase_radians"]:
			var value:Variant=data.flame_mount.get(key)
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):return false
		if float(data.flame_mount.port_y)<=0. or float(data.flame_mount.port_y)>StoveProp.HOB_Y or float(data.flame_mount.radius)<=0. or float(data.flame_mount.radius)>=StoveProp.W*.5:return false
		if absf(float(data.flame_mount.phase_radians))>PI:return false
		_flame_mount=data.flame_mount.duplicate(true)
	if data.has("control_pivots"):
		if data.control_pivots is not Dictionary or data.control_pivots.size()!=6: return false
		for name: String in ["BurnerValve1","BurnerValve2","BurnerValve3","BurnerValve4","OvenValve","Starter"]:
			var at: Variant=data.control_pivots.get(name)
			if at is not Array or at.size()!=3: return false
			for value: Variant in at:
				if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)): return false
		_control_pivots=data.control_pivots.duplicate(true)
	if _fit.grate_parking.size() != 4 or _fit.cap_end_blender_delta.size() != 4: return false
	for row: Dictionary in _fit.grate_parking:
		if row.blender_center.size() != 3 or not is_finite(float(row.angle_degrees)): return false
	for offset: Array in _fit.cap_end_blender_delta:
		if offset.size() != 3: return false
	for lift: float in [float(_fit.grate_lift_m),float(_fit.grate_forward_m),float(_fit.cap_lift_m)]:
		if not is_finite(lift) or lift < 0.: return false
	for row: Dictionary in data.assemblies:
		var occupied:Variant=row.get("service_obstructions",[])
		if occupied is not Array:return false
		var indices:Array[int]=[]
		for value:Variant in occupied:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floor(float(value)) or int(value)<0 or int(value)>3 or int(value) in indices:return false
			indices.append(int(value))
		_service_obstructions_by_variant[str(row.id)]=indices
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			_variants[str(row.id)][i]["component"] = str(row.parts[i].component)
	return true

func install_on(prop: StoveProp) -> bool:
	var identity := str(prop.name)
	if not _instances.has(identity): return false
	var variant: String = _instances[identity]
	prop._service_obstructions.assign(_service_obstructions_by_variant[variant])
	if prop.service_obstructed(prop.blocked_burner):return false
	var owners := {"Body":prop.get_node("StaticCarcass"),"OvenDoor":prop._door,"BroilerDrawer":prop._broiler,"OvenValve":prop.get_node("OvenValve"),"Starter":prop._starter}
	for i in 4:
		owners["BurnerValve"+str(i+1)] = prop._knobs[i]
		owners["Grate"+str(i+1)] = prop._grates[i]
		owners["BurnerCap"+str(i+1)] = prop._caps[i]
	for name: String in _control_pivots:
		var at: Array=_control_pivots[name]
		owners[name].position=Vector3(at[0],at[1],at[2])
	prop._starter_home=prop._starter.position
	if not _flame_mount.is_empty():
		for flame:Node3D in prop._flames:
			flame.position.y=float(_flame_mount.port_y)
			for draw:MeshInstance3D in flame.get_children():
				if draw.mesh is TorusMesh:
					var ring:=draw.mesh as TorusMesh
					var tube:float=(ring.outer_radius-ring.inner_radius)*.5
					ring.inner_radius=float(_flame_mount.radius)-tube
					ring.outer_radius=float(_flame_mount.radius)+tube
				else:
					var radial:=Vector2(draw.position.x,draw.position.z).normalized().rotated(float(_flame_mount.phase_radians))*float(_flame_mount.radius)
					draw.position.x=radial.x;draw.position.z=radial.y
				# The existing owner's Y scale now changes height about the port,
				# never the gap between the flame base and the metal outlet.
				draw.position.y=-draw.get_aabb().position.y
	for owner: Node3D in owners.values():
		for child: Node in owner.get_children():
			if child is MeshInstance3D and child not in prop._jet_plugs:
				owner.remove_child(child)
				child.free()
	var enamel: StandardMaterial3D
	for part: Dictionary in _variants[variant]:
		if not owners.has(part.component): return false
		var owner: Node3D = owners[part.component]
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		# Native stock is authored at rest. Preserve an already-open live valve
		# instead of cancelling its rotation in the replacement's local frame.
		var rest := Transform3D(Basis.IDENTITY,owner.position)
		draw.transform = rest.affine_inverse()*part.pose
		if part.key == "enamel":
			if enamel == null:
				enamel = part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
				enamel.albedo_color = prop._enamel_tint()
			draw.material_override = enamel
		draw.set_meta("native_stove_part",part.name)
		draw.set_meta("material_key",part.key)
		owner.add_child(draw)
	for i in 4:
		for grate: bool in [true,false]:
			var owner: Node3D = prop._grates[i] if grate else prop._caps[i]
			owner.set_script(VisualMotion)
			owner.call("configure",grate,i,_fit)
	# Refresh selection and solid sweeps against the installed native meshes.
	prop._build_primary_interaction()
	prop.set_meta("v2_native_stove_variant",variant)
	return true
