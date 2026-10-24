extends Node3D
## Imported stock/UV/PBR diagnostic before composing any occupied world.
var checks:=0
var failures: Array[String]=[]
func _ready() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
	print("MITER STOCK CHECK: ",label," = ",ok)

func _run() -> void:
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	var script: Script=load("res://scripts/building/orison_v2_casing_mitre_stock.gd")
	if script==null or not script.can_instantiate():get_tree().quit(1);return
	var stock: Variant=script.new()
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	if not check_result(stock.prepare(layout),"native frames and independent parts load for every source dimension"):
		get_tree().quit(1);return
	check(stock.variants.size()==10,"all ten domestic/service dimension variants are present")
	var metrics: Node=preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var inspector: Node=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var finishes:=preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
	var meshes: Dictionary={};var materials: Dictionary={};var index:=0
	for key: String in stock.variants:
		var variant: Dictionary=stock.variants[key]
		metrics._check_cap_mapping(variant.mesh,true);meshes[key]=inspector._mesh(variant.mesh)
		for part: String in variant.parts:
			metrics._check_cap_mapping(variant.parts[part],true);meshes[key+"/"+part]=inspector._mesh(variant.parts[part])
		var draw:=MeshInstance3D.new();draw.name=key;draw.mesh=variant.mesh
		draw.material_override=MatLib.get_mat("cast_iron",Color(.24,.25,.23)) if key.begins_with("S") else finishes.material_for("FrameHead","core")
		draw.position.x=index*1.6;add_child(draw);index+=1
		materials[key]=draw.material_override
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	var uv_policy:=preload("res://scripts/building/orison_v2_uv_material_policy.gd").new();add_child(uv_policy);uv_policy.setup(self)
	var rows: Dictionary={}
	for key: String in materials:
		var material: Material=(get_node(key) as MeshInstance3D).material_override;rows[key]=inspector._material(material)
		var row: Dictionary=rows[key]
		var required: Array=["albedo_texture","roughness_texture","normal_texture"] if material is StandardMaterial3D else ["albedo_tex","rough_tex","normal_tex"]
		for map: String in required:check(row.maps.has(map),"registered PBR map: "+key+"/"+map)
		if material is StandardMaterial3D:check(material.normal_enabled and not material.uv1_triplanar,"native service normals use authored UVs")
	for path: String in inspector.texture_rows:
		var texture: Dictionary=inspector.texture_rows[path]
		check(texture.mips and texture.mip_levels==int(log(float(maxi(texture.width,texture.height)))/log(2.0)+.000001),"complete loaded mip chain: "+path)
	FileAccess.open(output.path_join("stock.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Imported native casing stock only; no occupied-world/input/runtime qualification","meshes":meshes,"materials":rows,"textures":inspector.texture_rows,"checks":checks,"failures":failures},"\t"))
	inspector.free()
	var environment:=WorldEnvironment.new();var state:=Environment.new();state.background_mode=Environment.BG_COLOR;state.background_color=Color(.12,.13,.14);state.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;state.ambient_light_color=Color(.4,.4,.4);state.ambient_light_energy=.6;environment.environment=state;add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=.7;add_child(light)
	var camera:=Camera3D.new();add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.36
	var hero:=get_node("D0810_2130") as MeshInstance3D
	camera.position=hero.to_global(Vector3(-.62,2.30,.65));camera.look_at(hero.to_global(Vector3(-.45,2.17,0)));camera.make_current()
	for frame in 12:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("imported_mitre.png"))
	print("MITER STOCK: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func check_result(ok: bool,label: String) -> bool:
	check(ok,label);return ok
