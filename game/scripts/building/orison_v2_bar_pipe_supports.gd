extends RefCounted
## Source-fitted native pipe supports; all four original pipes retain authority.
static func mount_cell(cell: Node3D) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bar_pipe_supports.json"))
	if data is not Dictionary or int(data.get("schema_version",0))!=1 or cell.has_node("BarPipeSupports"):return false
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate() as Node3D
	if model==null:return false
	model.name="BarPipeSupports"
	var expected: Dictionary={}
	for part: Dictionary in data.parts:
		var key:=str(part.key);var tile:=float(part.tile)
		if expected.has(str(part.name)) or not MatLib.SETS.has(key) or not is_finite(tile) or tile<=0. or absf(float(MatLib.SETS[key][3])-tile)>.000001:
			model.free();return false
		expected[str(part.name)]=part
	var mounted: Dictionary={};var materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var identity:=str(draw.name)
		if not expected.has(identity) or mounted.has(identity) or draw.mesh.get_surface_count()!=1:
			model.free();return false
		var part: Dictionary=expected[identity];var key:=str(part.key)
		if not materials.has(key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/float(part.tile)
			materials[key]=material
		draw.mesh.surface_set_material(0,materials[key])
		draw.set_meta("bar_pipe_support_part",identity);draw.set_meta("material_key",key)
		draw.name="F01_retail_bar_pipe_support_"+identity
		draw.create_trimesh_collision();mounted[identity]=true
	if mounted.size()!=expected.size():model.free();return false
	cell.add_child(model)
	return true
