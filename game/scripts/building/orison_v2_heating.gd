extends RefCounted
## Full authored demand roster and installed emitters share retained authorities.
const PATH := "res://data/orison_v2/heating.json"
const STOCK_PATH := "res://data/orison_v2/heating_service_stock.json"
const Household := preload("res://scripts/building/orison_v2_household_radiator.gd")
const UNITS := ["LOBBY", "1A", "1D", "2C", "3D", "4C", "4D", "2A", "2B", "3A", "3B", "4A", "4B", "5A", "5B", "5C", "6A", "6B", "6C", "2D", "3C", "5D", "6D"]
var errors: Array[String] = []
var balance: HeatBalance

func mount(adapter: Variant, inventory: MaintenanceInventory) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source,adapter): return false
	var acoustic_ids: Array[String] = []
	var installed: Array=[]
	var mounts := preload("res://scripts/building/orison_v2_radiator_mounts.gd").new()
	mounts.configure(adapter.root)
	for record: Dictionary in source.installed: acoustic_ids.append(str(record.id))
	if not adapter.install_acoustic_overrides(acoustic_ids):
		errors.append("installed radiator acoustic anchors could not be rebound")
		return false
	balance = HeatBalance.new()
	balance.configure({"floors":[{"markers":source.network}]})
	for record: Dictionary in source.installed:
		var radiator: RadiatorProp = RadiatorProp.new() if record.unit == "2B" else Household.new()
		radiator.unit = record.unit
		radiator.riser = record.riser
		radiator.section_count = int(record.sections)
		radiator.installation_drop = .75
		radiator.use_native_v2 = true
		radiator.graph_node_id = record.id
		if not mounts.fit(radiator,adapter.resolve(str(record.id)),str(record.id).left(3)):
			radiator.free()
			errors.append_array(mounts.errors)
			return false
		if record.unit == "2B": radiator.bind_inventory(inventory)
		radiator.bind_heat_balance(balance)
		_add_collision(radiator)
		if not adapter.mount_consumer(record.id,radiator):
			radiator.free()
			errors.append("radiator mount refused: "+str(record.id))
			return false
		if str(record.get("drying","")) == "rag": _hang_rag(radiator)
		installed.append(radiator)
	mounts.draw()
	return _mount_orifice_stock(adapter,installed)

func _mount_orifice_stock(adapter: Variant,installed: Array) -> bool:
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(STOCK_PATH))
	if source is not Dictionary or source.get("schema_version")!=1 or source.get("id")!="B1_VENT_SERVICE_STOCK" or source.get("level")!="B1" or source.get("asset")!="res://assets/props/radiator_service_stock.glb" or source.get("position") is not Array or source.position.size()!=3 or source.get("spares") is not Array or source.spares.size()!=5:
		errors.append("invalid workshop vent stock source")
		return false
	var ids := {};var grades := {};var pockets := {}
	for record: Variant in source.spares:
		if record is not Dictionary or record.get("id") is not String or str(record.id).is_empty() or ids.has(record.id) or typeof(record.get("grade"))!=TYPE_FLOAT and typeof(record.get("grade"))!=TYPE_INT:
			errors.append("invalid workshop spare identity")
			return false
		if record.grade!=floor(record.grade) or record.grade<0 or record.grade>4 or grades.has(record.grade) or record.get("pocket")!=record.grade:
			errors.append("invalid workshop spare grade/pocket")
			return false
		ids[record.id]=true;grades[record.grade]=true;pockets[record.pocket]=true
	for number: Variant in source.position:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):
			errors.append("nonfinite workshop stock location")
			return false
	if typeof(source.get("yaw")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(source.yaw)):
		errors.append("invalid workshop stock orientation")
		return false
	var stock := preload("res://scripts/props/radiator_vent_stock.gd").new()
	stock.name=source.id
	stock.position=Vector3(source.position[0],float(adapter.root.level_y[source.level])+source.position[1],source.position[2])
	stock.rotation.y=float(source.yaw)
	adapter.root.add_child(stock)
	stock.install_rack(str(source.asset))
	stock.configure(installed,source)
	return true

## Dossier slice 66 (F05_C_MAIN-003): a paint rag folded over the radiator's top to dry, mid-length so
## the supply valve and the air vent stay in reach. Visual only: no collision and no owner.
func _hang_rag(radiator: RadiatorProp) -> void:
	var top := RadiatorProp.BODY_TOP if radiator.use_native_v2 else RadiatorProp.BODY_TOP-radiator.installation_drop
	var half_depth := RadiatorProp.BODY_DEPTH * .5
	for part: Array in [
			["DryingRag", MatLib.get_mat("linen", Color(.74, .70, .62)), [
				[Vector3(.21, .012, half_depth * 2.0 + .02), Vector3(-.07, top + .006, 0)],
				[Vector3(.21, .19, .008), Vector3(-.07, top - .083, -half_depth - .014)],
				[Vector3(.17, .07, .008), Vector3(-.09, top - .023, half_depth + .014)]]],
			["DryingRagPaint", MatLib.get_mat("enamel", Color(.46, .12, .09)), [
				[Vector3(.05, .035, .002), Vector3(-.03, top - .06, -half_depth - .0185)],
				[Vector3(.03, .02, .002), Vector3(-.12, top - .13, -half_depth - .0185)],
				[Vector3(.06, .004, .03), Vector3(-.1, top + .0125, -.04)]]]]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece: Array in part[2]:
			var box := BoxMesh.new()
			box.size = piece[0]
			surface.append_from(box, 0, Transform3D(Basis.IDENTITY, piece[1]))
		var mesh := MeshInstance3D.new()
		mesh.name = part[0]
		mesh.mesh = surface.commit()
		mesh.material_override = part[1]
		if radiator.use_native_v2:
			mesh.position = Vector3(maxf(0.0,float(radiator.section_count-1)*.092*.5-.322),0,-.03)
			radiator.native_rig.body.add_child(mesh)
		else: radiator.add_child(mesh)

func _add_collision(radiator: RadiatorProp) -> void:
	var body := StaticBody3D.new()
	body.name = "InstalledRadiatorCollision"
	var half_width := float(radiator.section_count-1)*RadiatorProp.SECTION_PITCH*.5
	# The case blocks walking; the narrower supply hull leaves the physical
	# handwheel target exposed in front of the pipe instead of burying it.
	for bounds: Array in [
		[Vector3(-half_width-.06,.07,-.10),Vector3(half_width+.06,.81,.12)],
		[Vector3(-.715,0,-.055),Vector3(-.38,.33,.055)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds[1]-bounds[0]
		shape.shape = box
		shape.position = (bounds[1]+bounds[0])*.5-Vector3.UP*.75
		body.add_child(shape)
	radiator.add_child(body)

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("network") is not Array or source.get("installed") is not Array or adapter == null:
		errors.append("invalid heating source")
		return false
	var network := {}
	for record: Variant in source.network:
		if record is not Dictionary or record.get("kind") != "radiator" or record.get("id") is not String or record.get("unit") is not String or record.get("riser") not in ["H-A","H-B","H-C","H-D"]:
			errors.append("invalid heating demand record")
			continue
		if network.has(record.id): errors.append("duplicate heating demand")
		network[record.id] = record
		if record.get("pos") is not Array or record.pos.size() != 3:
			errors.append("invalid heating demand position")
		else:
			for value: Variant in record.pos:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): errors.append("nonfinite heating demand position")
	if network.size() != 23: errors.append("incomplete full-building heat budget")
	var units := {}
	for record: Variant in source.installed:
		if record is not Dictionary or record.get("unit") not in UNITS or record.get("id") not in network:
			errors.append("unknown installed radiator")
			continue
		if units.has(record.unit): errors.append("duplicate installed household")
		units[record.unit] = true
		if network[record.id].unit != record.unit or network[record.id].riser != record.get("riser"):
			errors.append("installed radiator disagrees with authored demand")
		var sections: Variant = record.get("sections")
		if typeof(sections) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(sections)) or float(sections) != floorf(float(sections)) or float(sections) < 7 or float(sections) > 10:
			errors.append("invalid radiator section count")
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if anchor == null or anchor is RadiatorProp: errors.append("missing or occupied radiator anchor")
	if units.size() != UNITS.size(): errors.append("incomplete installed radiator category")
	return errors.is_empty()
