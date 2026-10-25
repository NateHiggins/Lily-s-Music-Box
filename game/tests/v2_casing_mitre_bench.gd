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
	var linings: Variant=load("res://scripts/building/orison_v2_lining_mitre_stock.gd").new()
	if not check_result(linings.prepare(layout),"native deep linings cover all 111 source openings"):
		get_tree().quit(1);return
	check(linings.variants.size()==7,"all seven exact lining dimensions are present")
	var metrics: Node=preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var inspector: Node=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var finishes:=preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
	var meshes: Dictionary={};var materials: Dictionary={};var index:=0
	var lift_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_lift_frame_mitres.json"))
	var lift_scene:=load("res://assets/props/lift_frame_mitres.glb") as PackedScene
	if not check_result(lift_scene!=null,"native lift stock was imported before review"):
		get_tree().quit(1);return
	var lift_model: Node3D=lift_scene.instantiate()
	var lift_parts: Dictionary={}
	for row: Dictionary in lift_fixture.runtime.parts:
		var source_draw:=lift_model.find_child(str(row.name),true,false) as MeshInstance3D
		check(source_draw!=null and source_draw.mesh.get_faces().size()==int(row.triangles)*3,"native grooved landing member imports: "+str(row.member))
		if source_draw==null:continue
		lift_parts[str(row.member)]=source_draw.mesh
		metrics._check_cap_mapping(source_draw.mesh,true)
		meshes["lift/"+str(row.member)]=inspector._mesh(source_draw.mesh)
		var draw:=MeshInstance3D.new();draw.name="Lift_"+str(row.member);draw.mesh=source_draw.mesh
		var material:=MatLib.get_mat("brass",Color(.62,.52,.28)).duplicate() as StandardMaterial3D
		material.normal_enabled=true;material.normal_scale=.35;material.uv1_triplanar=false
		material.uv1_scale=Vector3.ONE/float(MatLib.SETS.brass[3])
		draw.material_override=material;draw.position.x=index*1.6;add_child(draw);index+=1
		materials[str(draw.name)]=material
	if not check_result(lift_parts.size()==3,"all three lift members are present before cap checks"):
		lift_model.free();get_tree().quit(1);return
	for side: String in ["west","east"]:
		for corner: Array in lift_fixture.interfaces_godot[side]:
			var point:=Vector3(corner[0],corner[1],corner[2])
			check(_has_vertex(lift_parts[side],point) and _has_vertex(lift_parts.head,point),"imported grooved lift cap matches both native members: "+side+str(point))
	lift_model.free()
	var facade_scene:=load("res://assets/props/front_facade.glb") as PackedScene
	if not check_result(facade_scene!=null,"native entrance facade was imported before review"):
		get_tree().quit(1);return
	var facade: Node3D=facade_scene.instantiate()
	var facade_count:=0
	for draw: MeshInstance3D in facade.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		meshes["facade/"+str(draw.name)]=inspector._mesh(draw.mesh)
		facade_count+=1
	check(facade_count==68,"all 68 rebuilt entrance facade partitions receive imported UV/tangent checks")
	facade.free()
	var shop_scene:=load("res://assets/props/shop_joinery.glb") as PackedScene
	if not check_result(shop_scene!=null,"native shop frame family was imported before review"):
		get_tree().quit(1);return
	var shop_model: Node3D=shop_scene.instantiate()
	var shop_count:=0
	for draw: MeshInstance3D in shop_model.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		meshes["shop/"+str(draw.name)]=inspector._mesh(draw.mesh)
		shop_count+=1
	check(shop_count==46,"all46 retained/expanded shop joinery partitions receive imported UV/tangent checks")
	var shop_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/shop_joinery.json"))
	var checked_finishes: Dictionary={}
	for cell: Dictionary in shop_data.cells:
		for part: Dictionary in cell.parts:
			if not str(part.name).begins_with("storm_sf_"):continue
			var key:=str(part.catalog_key)
			check(MatLib.SETS.has(key) and is_equal_approx(float(part.tile),float(MatLib.SETS[key][3])),"storefront finish retains its registered metric calibration: "+key)
			if checked_finishes.has(key):continue
			checked_finishes[key]=true
			var source_draw:=shop_model.find_child(str(part.name),true,false) as MeshInstance3D
			var draw:=MeshInstance3D.new();draw.name="ShopFinish_"+key;draw.mesh=source_draw.mesh
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/float(part.tile)
			draw.material_override=material;draw.position.x=index*1.6;add_child(draw);index+=1
			materials[str(draw.name)]=material
	check(checked_finishes.size()==5,"all five registered storefront finish families receive loaded PBR/mipmap checks")
	shop_model.free()
	for key: String in linings.variants:
		var variant: Dictionary=linings.variants[key]
		metrics._check_cap_mapping(variant.mesh,true);meshes[key]=inspector._mesh(variant.mesh)
		for part: String in variant.parts:
			metrics._check_cap_mapping(variant.parts[part],true);meshes[key+"/"+part]=inspector._mesh(variant.parts[part])
		_check_lining_joints(variant,key)
		var draw:=MeshInstance3D.new();draw.name=key;draw.mesh=variant.mesh
		draw.material_override=finishes.material_for("FrameHead","core")
		draw.position.x=index*1.6;add_child(draw);index+=1
		materials[key]=draw.material_override
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

func _check_lining_joints(variant: Dictionary,key: String) -> void:
	var half: float=variant.width*.5
	var height: float=variant.height
	var depth: float=variant.depth
	for side: float in [-1.0,1.0]:
		var member: Mesh=variant.parts.left if side<0 else variant.parts.right
		for xh: Vector2 in [Vector2(side*half,height),Vector2(side*(half+.09),height+.09)]:
			for z: float in [-depth*.5,depth*.5]:
				var point:=Vector3(xh.x,xh.y,z)
				check(_has_vertex(member,point) and _has_vertex(variant.parts.head,point),key+" exact shared 45 degree cap corner "+str(point))
		var bounds: AABB=member.get_aabb()
		check(bounds.end.x<=-half+.0001 if side<0 else bounds.position.x>=half-.0001,key+" jamb preserves clear aperture")
	check(variant.parts.head.get_aabb().position.y>=height-.0001,key+" head preserves clear height")
	check(variant.mesh.get_faces().size()==108,key+" full-depth frame retains 36 triangles")

func _has_vertex(mesh: Mesh,point: Vector3) -> bool:
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			if vertex.distance_to(point)<.0001:return true
	return false
