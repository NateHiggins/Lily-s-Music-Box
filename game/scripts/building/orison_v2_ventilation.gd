extends RefCounted
const Fan:=preload("res://scripts/building/orison_v2_roof_fan.gd")
const VARIANTS:={"A":"west_weathered","B":"north_belt","C":"south_repainted","D":"east_oxidised"}

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var registers:={"A":[],"B":[],"C":[],"D":[]}
	for record: Dictionary in layout.anchors:
		var identity:=str(record.id)
		if not identity.ends_with("_VENT_REGISTER"): continue
		var anchor:=adapter.resolve(identity) as Node3D
		if anchor==null: return false
		var stack:= "A" if identity=="F01_RESTROOM_VENT_REGISTER" else identity.split("_")[1]
		if not registers.has(stack): return false
		registers[stack].append(anchor)
		_build_register(anchor)
	for stack: String in registers:
		var fan:=Fan.new()
		fan.riser="V-"+stack
		fan.fan_variant=VARIANTS[stack]
		fan.prop_type="exhaust_fan"
		if not adapter.mount_consumer("ROOF_VENT_FAN_"+stack,fan):
			fan.free()
			return false
		var anchors: Array[Node3D]=[]
		anchors.assign(registers[stack])
		fan.bind_registers(anchors)
	return true

func _build_register(anchor: Node3D) -> void:
	# Passive painted sheet-metal grille; the shared roof motor owns its sound.
	for index in 9:
		var bar:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(.36,.018,.018)
		bar.mesh=mesh
		bar.position=Vector3(0,0,-.14+float(index)*.035)
		bar.material_override=MatLib.get_mat("trim")
		anchor.add_child(bar)
	for side in [-1.0,1.0]:
		var frame:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(.022,.022,.34)
		frame.mesh=mesh
		frame.position.x=side*.18
		frame.material_override=MatLib.get_mat("trim")
		anchor.add_child(frame)
