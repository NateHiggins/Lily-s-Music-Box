extends Node3D
## Imported stock diagnostic only; no whole-world acceptance.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
const GroundMetrics=preload("res://tests/orison_v2_ceiling_top_closures_test.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("FLUE STOCK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var stock: Node3D=preload("res://assets/props/flue_wall_thimble.glb").instantiate()
	add_child(stock)
	var metrics: Node=Metrics.new()
	var draws: Array[Node]=stock.find_children("*","MeshInstance3D",true,false)
	check(draws.size()==13,"thirteen actual imported fabricated parts")
	var material: StandardMaterial3D=MatLib.get_mat("iron_neutral").duplicate()
	material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE;material.normal_scale=.25
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for draw: MeshInstance3D in draws:
		# The shared derivative checker expects metres. Undo only the authored
		# catalogue tile divisor on a copy; retain imported positions/tangents.
		var metric_mesh:=ArrayMesh.new()
		for surface in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface)
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for index in uv.size():uv[index]*=.4
			arrays[Mesh.ARRAY_TEX_UV]=uv
			metric_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		metrics._check_cap_mapping(metric_mesh,true)
		draw.material_override=material
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	var ground: Node3D=preload("res://assets/props/alley_groundworks.glb").instantiate()
	add_child(ground)
	var ground_metrics: Node=GroundMetrics.new()
	var ground_draws: Array[Node]=ground.find_children("*","MeshInstance3D",true,false)
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_alley_groundworks_construction.json"))
	check(ground_draws.size()==construction.parts.size(),"all rebuilt groundwork partitions imported")
	check(FileAccess.get_sha256("res://assets/props/alley_groundworks.glb")==construction.asset_sha256,"exact rebuilt groundwork asset")
	for draw: MeshInstance3D in ground_draws:ground_metrics._check_planar_mapping(draw.mesh,true)
	for failure: String in ground_metrics.failures:check(false,failure)
	ground_metrics.free();ground.free()
	for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
		var image: Image=texture.get_image()
		check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"loaded full mip chain: "+texture.resource_path)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.08,.08,.08)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.5
	add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-40,0);add_child(light)
	var camera:=Camera3D.new();camera.position=Vector3(.45,.3,.8);add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("imported_stock.png"))
	print("V2 FLUE STOCK: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
