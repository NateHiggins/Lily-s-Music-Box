extends RefCounted
## Native visuals and exact collision attach to the existing furniture owner.
const PATH := "res://data/orison_v2/work_tables.json"
const IDS := ["2A_desk", "3B_workbench", "4B_terminal_desk", "5A_plantable", "6A_deskwall", "b1_repair_bench"]
const COPIES := {"b1_repair_bench":"3B_workbench"}

static func mount_on(body: StaticBody3D, identity: String, source_record: Dictionary = {}) -> bool:
	var source_id: String = COPIES.get(identity,identity)
	if source_id != identity:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_furniture.json"))
		var templates: Array = source.furniture.filter(func(record):return record.id==source_id)
		if templates.size()!=1:return false
		for key: String in ["kind","bounds","surfaces"]:
			if source_record.get(key)!=templates[0][key]:return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1 or data.get("assemblies") is not Array: return false
	if data.get("floor_y") != 0 or data.get("local_materials") != {}: return false
	var rows: Array = data.assemblies.filter(func(row): return row.id == source_id)
	if rows.size() != 1: return false
	var row: Dictionary = rows[0]
	var origin := Vector3(row.position[0],row.position[1],row.position[2])
	if not origin.is_zero_approx() or not is_zero_approx(float(row.yaw)): return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate()
	for part: Dictionary in row.parts:
		var draw := model.find_child(str(part.name), true, false) as MeshInstance3D
		if draw == null:
			push_error("native work table missing imported node: " + str(part.name))
			model.free(); return false
		draw.owner = null
		draw.get_parent().remove_child(draw)
		body.add_child(draw)
		draw.mesh = draw.mesh.duplicate() as Mesh
		var material := MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(part.tile)
		draw.mesh.surface_set_material(0, material)
		draw.set_meta("work_table_part", str(part.name))
		draw.set_meta("material_key", str(part.key))
		var collision := CollisionShape3D.new()
		collision.shape = draw.mesh.create_trimesh_shape()
		collision.transform = draw.transform
		body.add_child(collision)
	body.set_meta("v2_native_work_table", identity)
	model.free()
	return true
