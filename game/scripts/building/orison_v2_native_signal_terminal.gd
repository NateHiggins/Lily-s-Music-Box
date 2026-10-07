extends "res://scripts/props/signal_terminal_prop.gd"
## The original actor owns all behavior and dynamic witnesses.
var native_ready := false

func _build_visual() -> void:
	super._build_visual()
	# make_box originally reparents with its world transform, leaving the
	# needles at the actor origin. Seat their existing meshes on their pivots.
	for pivot: Node3D in _meter_needles:
		for needle: MeshInstance3D in pivot.find_children("*","MeshInstance3D",false,false): needle.position = Vector3(0,.032,0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/signal_terminal.json"))
	if data.get("schema_version") != 1 or data.get("assemblies") is not Array or data.assemblies.size() != 1: return
	var row: Dictionary = data.assemblies[0]
	if data.floor_y != 0 or row.id != "VantryFixed" or not Vector3(row.position[0],row.position[1],row.position[2]).is_zero_approx() or not is_zero_approx(float(row.yaw)): return
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return
	var model := packed.instantiate()
	for part: Dictionary in row.parts:
		if model.find_child(str(part.name),true,false) == null: model.free(); return
	var old := get_node("FixedInstrument")
	remove_child(old); old.free()
	var fixed := Node3D.new()
	fixed.name = "FixedInstrument"
	add_child(fixed)
	var bank := get_node("ValveBank")
	for old_glass: MeshInstance3D in bank.find_children("*","MeshInstance3D",true,false):
		old_glass.get_parent().remove_child(old_glass); old_glass.free()
	for part: Dictionary in row.parts:
		var draw := model.find_child(str(part.name),true,false) as MeshInstance3D
		draw.owner = null
		draw.get_parent().remove_child(draw)
		if part.key == "glassish": bank.add_child(draw)
		else: fixed.add_child(draw)
		draw.mesh = draw.mesh.duplicate() as Mesh
		if part.key == "glassish":
			draw.mesh.surface_set_material(0,_valve_mat)
			draw.material_override = _valve_mat
			draw.set_meta("signal_terminal_part",str(part.name))
			continue
		var material := MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
		if part.has("tint"):
			var tint: Array = part.tint
			material.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
		if part.has("finish"):
			material.normal_scale = float(part.finish.normal_scale)
			material.roughness = float(part.finish.roughness)
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(part.tile)
		draw.mesh.surface_set_material(0,material)
		draw.set_meta("signal_terminal_part",str(part.name))
	model.free()
	native_ready = true
