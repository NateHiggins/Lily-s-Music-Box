extends Node3D
## Native import, kinematic parity and loaded PBR review. Does not certify
## production world integration, player controls, persistence or navigation.
var failures: Array[String] = []
var checks := 0
var _camera: Camera3D

func _ready() -> void:
	_run.call_deferred()

func check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native import review requires -Windowed and SHOT_DIR")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.18,.21)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.8,.85,.95)
	env.environment.ambient_light_energy = .75
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_energy = 1.7
	add_child(sun)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 42
	add_child(_camera)
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/radiator_native_poses.json"))
	check(fixture is Array and fixture.size()==20,"twenty native reference poses are available")
	var rigs := {}
	for count in [7,8,9,10]:
		var rig := RadiatorNativeAssembly.new()
		add_child(rig)
		rig.build(count)
		rigs[count] = rig
		for draw: GeometryInstance3D in rig.find_children("*","GeometryInstance3D",true,false):
			var mesh: Mesh = draw.multimesh.mesh if draw is MultiMeshInstance3D else draw.mesh
			for index in mesh.get_surface_count():
				var stock: Material = draw.material_override if draw is MultiMeshInstance3D else draw.get_active_material(index)
				_check_surface(mesh,index,stock)
	for row: Dictionary in fixture:
		var rig: RadiatorNativeAssembly = rigs[int(row.sections)]
		rig.set_positions(float(row.pitch),1.0,0.0,2,0.0,0.0)
		var expected := _blender_matrix(row.body_matrix)
		check(_matrix_distance(rig.body_pose,expected)<.000001,"runtime body matches native floor-contact pose %s / %s" % [row.sections,row.pitch])
		check(absf(rig.feed_angle-float(row.feed_angle_radians))<.000001,"rigid feed angle matches native solve")
		check(rig.supported_shim,"native wedge fits authored pitch")
		var base := rig.body.transform
		rig.set_positions(float(row.pitch),.42,1.0,2,1.0,1.0)
		check((rig.body.position-base.origin).distance_to(Vector3(.04,0,0))<.000001,"service withdraws actual body forty millimetres")
		check(is_equal_approx(rig.wheel.position.y,.378+.018*.42),"valve core and wheel rise along the actual screw")
		check(rig.packing.get_blend_shape_count()==20,"packing retains twenty shading anchors")
		check(is_equal_approx(rig.packing.get_blend_shape_value(19),1.0),"removed packing reaches its native open shape")
	for count in rigs:
		(rigs[count] as Node3D).hide()
	var shown: RadiatorNativeAssembly = rigs[10]
	shown.show()
	shown.set_positions(.35,1.0,0.0,2,0.0,0.0)
	await _capture(directory,"assembled",Vector3(1.2,1.25,1.9),Vector3(0,.4,0))
	shown.set_positions(-.35,.0,1.0,2,1.0,1.0)
	await _capture(directory,"packing_removed",Vector3(-.31,.53,.65),Vector3(-.38,.24,-.06))
	await _review_cast_finish(shown,env.environment,sun,directory)
	var supports := Node3D.new()
	add_child(supports)
	for name: String in RadiatorNativeParts.names("supports"):
		var sample := RadiatorNativeParts.part("supports",name,supports)
		for index in sample.mesh.get_surface_count(): _check_surface(sample.mesh,index,sample.get_active_material(index))
	supports.free()
	var result := {"evidence_class":"INERT","scope":"Imported candidate stocks, PBR mipmaps and native/runtime kinematic parity; no game integration or player acceptance", "checks":checks,"failures":failures}
	var file := FileAccess.open(directory.path_join("native_review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("RADIATOR NATIVE REVIEW: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_surface(mesh: Mesh, index: int, stock: Material) -> void:
	var arrays := mesh.surface_get_arrays(index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bad := uv.size()!=vertices.size()
	for point in uv: bad = bad or not point.is_finite()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for start in range(0,count-2,3):
		var a := indices[start] if not indices.is_empty() else start
		var b := indices[start+1] if not indices.is_empty() else start+1
		var c := indices[start+2] if not indices.is_empty() else start+2
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<=1e-18: continue
		if absf((uv[b]-uv[a]).cross(uv[c]-uv[a]))<=1e-12: bad = true
	check(not bad,"imported stock retains every finite noncollapsed metre chart")
	check(stock is StandardMaterial3D,"stock uses catalogue PBR")
	if not stock is StandardMaterial3D: return
	check(not stock.uv1_triplanar and not stock.uv2_triplanar,"stock samples authored charts")
	check(not str(stock.get_meta("v2_surface_stock","")).is_empty(),"stock has a registered physical recipe")
	if stock.get_meta("v2_surface_stock","")=="graphited_packing":
		check(stock.normal_enabled and is_equal_approx(stock.normal_scale,1.0),"fabric loads its measured relief without generic attenuation")
		check(is_zero_approx(stock.metallic),"graphited fabric remains dielectric")
	if stock.get_meta("v2_surface_stock","")=="radiator_cast_iron":
		check(stock.normal_enabled and is_equal_approx(stock.normal_scale,1.0),"casting uses physical normal relief without the old worked-iron attenuation")
		check(is_zero_approx(stock.metallic),"continuous oxide coating remains dielectric")
		check(stock.normal_texture.resource_path.ends_with("T_ai_materials_radiator_cast_iron_normal.png"),"casting actually loads its distinct normal map")
	if stock.get_meta("v2_surface_stock","")=="radiator_service_brass":
		check(stock.normal_enabled and is_equal_approx(stock.normal_scale,1.0),"service brass loads its physical microrelief at authored strength")
		check(is_equal_approx(stock.metallic,.92) and is_equal_approx(stock.roughness,1.0),"service brass retains its alloy response and authored roughness map")
		check(stock.normal_texture.resource_path.ends_with("T_ai_materials_radiator_service_brass_normal.png"),"service fittings load their own finish rather than door hardware maps")
		check(is_equal_approx(stock.uv1_scale.x,25.0) and is_equal_approx(stock.uv1_scale.y,25.0),"service brass samples its 40 millimetre physical tile")
	for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
		check(texture!=null,"stock loads all three PBR maps")
		if texture==null: continue
		var image := texture.get_image()
		check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.0))),"actual loaded PBR image has its complete mip chain")
	check(stock.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC],"PBR filtering samples mipmaps")

func _blender_matrix(rows: Array) -> Transform3D:
	var basis := Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2]))
	var mapping := Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3.ZERO)
	return mapping*Transform3D(basis,Vector3(rows[0][3],rows[1][3],rows[2][3]))*mapping.affine_inverse()

func _matrix_distance(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func _capture(directory: String, identity: String, at: Vector3, target: Vector3) -> void:
	_camera.position = at
	_camera.look_at(target)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(identity+".png"))

func _review_cast_finish(rig: RadiatorNativeAssembly, environment: Environment,
		sun: DirectionalLight3D, directory: String) -> void:
	rig.set_positions(.35,1.0,0.0,2,0.0,0.0)
	var castings: Array[GeometryInstance3D] = []
	var originals: Array[Material] = []
	for draw: GeometryInstance3D in rig.find_children("*","GeometryInstance3D",true,false):
		var stock: Material = draw.material_override if draw is MultiMeshInstance3D else draw.get_active_material(0)
		if stock!=null and stock.get_meta("v2_surface_stock","")=="radiator_cast_iron":
			castings.append(draw)
			originals.append(stock)
	check(castings.size()==3,"cast finish covers the shared sections and both shoes only")
	var worked := MatLib.get_mat("iron_neutral").duplicate() as StandardMaterial3D
	worked.uv1_triplanar=false
	worked.uv2_triplanar=false
	environment.ambient_light_energy=.20
	environment.ambient_light_color=Color.WHITE
	var flashlight := SpotLight3D.new()
	flashlight.light_energy=3.0
	flashlight.spot_range=3.0
	flashlight.spot_angle=30.0
	flashlight.shadow_enabled=true
	add_child(flashlight)
	for mode: String in ["diffuse","grazing","flashlight"]:
		sun.visible=mode!="flashlight"
		flashlight.visible=mode=="flashlight"
		sun.light_energy=1.4
		sun.look_at(Vector3(0,-.6,1) if mode=="diffuse" else Vector3(.95,-.25,.1))
		var at := Vector3(.65,.85,-1.65) if mode=="diffuse" else Vector3(.18,.54,-.48)
		var target := Vector3(0,.4,-.06) if mode=="diffuse" else Vector3(.04,.43,-.07)
		flashlight.position=at
		flashlight.look_at(target)
		for finish: String in ["worked_before","cast_after"]:
			for index in castings.size():
				var draw := castings[index]
				var stock := worked if finish=="worked_before" else originals[index]
				if draw is MultiMeshInstance3D: draw.material_override=stock
				else: (draw as MeshInstance3D).set_surface_override_material(0,stock)
			await _capture(directory,mode+"_"+finish,at,target)
	flashlight.queue_free()
