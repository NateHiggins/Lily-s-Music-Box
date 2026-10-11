extends "res://tests/orison_v2_floor_surface_test.gd"
## Exhaustive loaded geometry discovery. Findings remain failures, never exemptions.
var mesh_rows: Dictionary = {}
var material_rows: Dictionary = {}
var texture_rows: Dictionary = {}
var draws: Array = []
var unhandled_geometry: Array = []
var shader_filter_cache := {}

func _run() -> void:
	var started := Time.get_ticks_msec()
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK or DisplayServer.get_name() == "headless":
		push_error("Surface qualification requires writable SHOT_DIR and -Windowed")
		get_tree().quit(1)
		return
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var before := _input_snapshot(root)
	if before.is_empty(): get_tree().quit(1); return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	if world == null:
		push_error("Surface world failed to instantiate")
		get_tree().quit(1)
		return
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.player == null or world.startup_failed:
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	await preload("res://tests/v2_window_treatments_review.gd").new().run(world,self)
	await preload("res://tests/v2_millwork_weather_review.gd").new().run(world,self)
	world.player.global_position = world.adapter.root.to_global(Vector3(-4., .02, -5.))
	for frame in 600:
		if world.passage_region.residency.state == "RESIDENT": break
		await get_tree().process_frame
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if node is Label3D: continue # Separately authored lettering, RUL-008.
		if not node is MeshInstance3D and not node is MultiMeshInstance3D and not node is GPUParticles3D and not node is CPUParticles3D:
			unhandled_geometry.append({"path":str(world.get_path_to(node)),"type":node.get_class()})
			continue
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D: mesh = node.mesh
		elif node is CPUParticles3D:
			mesh = node.mesh
			instances = node.amount
		elif node is GPUParticles3D:
			if node.draw_passes != 1:
				unhandled_geometry.append({"path":str(world.get_path_to(node)),"type":"unscanned particle draw passes"})
				continue
			mesh = node.draw_pass_1
			instances = node.amount
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count
		if mesh == null: continue
		var mesh_id := str(mesh.get_instance_id())
		if not mesh_rows.has(mesh_id): mesh_rows[mesh_id] = _mesh(mesh)
		var slots: Array = []
		for surface in mesh.get_surface_count():
			var material: Material = node.material_override
			if material == null and node is MeshInstance3D: material = node.get_active_material(surface)
			if material == null: material = mesh.surface_get_material(surface)
			var material_id := "none" if material == null else str(material.get_instance_id())
			if material != null and not material_rows.has(material_id): material_rows[material_id] = _material(material)
			slots.append(material_id)
		var owner: Node = node
		while owner != world and owner.get_script() == null: owner = owner.get_parent()
		draws.append({"path":str(world.get_path_to(node)), "owner":str(world.get_path_to(owner)), "owner_script":owner.get_script().resource_path if owner.get_script() != null else "", "visible":node.is_visible_in_tree(), "mesh":mesh_id, "materials":slots, "instances":instances, "surface_role":str(node.get_meta("surface_role", "physical")), "retired_surface":str(node.get_meta("retired_surface", "")), "geometry_transparency":node.transparency})
		if node.material_overlay != null:
			var overlay_key := str(node.material_overlay.get_instance_id())
			if not material_rows.has(overlay_key): material_rows[overlay_key] = _material(node.material_overlay)
			var overlay_draw: Dictionary = draws.back().duplicate()
			overlay_draw.path += "/material_overlay"
			overlay_draw.materials = []
			for index in mesh.get_surface_count(): overlay_draw.materials.append(overlay_key)
			draws.append(overlay_draw)
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Surface inventory requires a writable SHOT_DIR")
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	var report := {"schema":"orison.v2-surface-inventory.v1", "evidence_class":"INERT", "acceptance":"Inventory; acceptance requires passing runtime contract and reviewed renders.", "coverage":{"production_world":true,"space_count":world.layout.spaces.size(),"resident_cells":world.passage_region.cell_nodes.size()}, "passage_state":world.passage_region.residency.state, "draws":draws, "meshes":mesh_rows, "materials":material_rows, "textures":texture_rows,"unhandled_geometry":unhandled_geometry}
	var file := FileAccess.open(directory.path_join("surface-inventory.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write surface inventory")
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var audit_output: Array = []
	check(OS.execute("python",[root.path_join("tools/audit_v2_surfaces.py"),"--inventory",directory.path_join("surface-inventory.json"),"--out",directory.path_join("technical_findings.json")],audit_output)==0,"all loaded surfaces satisfy UV/PBR/mip/filter requirements")
	for line in audit_output: print(str(line).strip_edges())
	_validate_native_controls(world)
	print("SURFACE INVENTORY: draws=", draws.size(), " meshes=",mesh_rows.size()," materials=",material_rows.size()," textures=",texture_rows.size())
	# Reuse this composed world for representative appearance checks.
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	for room_id in ["F02_A_MAIN", "F03_B_MAIN", "F04_C_MAIN"]:
		for record: Dictionary in world.layout.spaces:
			if str(record.id) != room_id: continue
			var r: Array = record.rect
			var y: float = world.adapter.root.level_y[record.level]
			world.player.global_position = world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,y+.05,r[1]+.65))
			world.player.camera.make_current()
			world.player.face_world_point(world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,y+1.0,(r[1]+r[3])*.5)))
			await shot(room_id)
	# A fixed review camera avoids controller, head-motion and lens framing.
	var review_camera := Camera3D.new()
	review_camera.fov = world.player.camera.fov
	review_camera.attributes = world.player.camera.attributes
	review_camera.cull_mask = world.player.camera.cull_mask
	world.add_child(review_camera)
	for station in [
		["B1_FUSE_PANEL",Vector3(.35,.7,1.25),Vector3(0,.6,.1),"fuse_panel"],
		["LobbyMailBank",Vector3(.35,1.,-1.5),Vector3(0,.9,-.1),"mail_bank"],
		["B1_WATCH_STATION",Vector3(.2,.25,.7),Vector3(0,.16,.09),"watch_station"],
		["F04_4A_BOOKSHELF_01",Vector3(.35,.85,1.6),Vector3(0,.8,.15),"bookcase"],
		["F02_B_RADIATOR_01",Vector3(.35,.65,-1.1),Vector3(0,.48,0),"radiator"],
		["B1_BOILER_01",Vector3(.6,1.45,-2.15),Vector3(0,1.,0),"boiler"],
		["Arcade_retail_bar_cab01",Vector3(.4,1.,-1.8),Vector3(0,1.,-.3),"signal_scope"],
		["F04_B_MONITOR_01",Vector3(.35,.8,-1.3),Vector3(0,.3,-.2),"signal_terminal"],
		["F02_2A_TOASTER_01",Vector3(.25,.35,-.65),Vector3(0,.1,0),"toaster_crumbs"],
		["LobbyServiceDumbwaiter",Vector3(.65,1.,1.7),Vector3(0,1.,0),"dumbwaiter"]]:
		var actor := world.find_child(str(station[0]),true,false) as Node3D
		check(actor != null,"capture station exists: "+str(station[0]))
		if actor == null: continue
		var saved_condition := ""
		if actor is RadiatorProp:
			saved_condition = actor.open_shift_condition
			actor.apply_open_shift_condition("porter_temporary_shutoff")
		if actor is ToasterProp:
			actor.get_parent().restore_open_state(true)
			actor.set_crumb_tray_open(true,0)
		world.player.global_position = actor.to_global(Vector3(station[1].x,0,station[1].z))
		world.player.face_world_point(actor.to_global(station[2]))
		review_camera.global_position = actor.to_global(station[1])
		review_camera.look_at(actor.to_global(station[2]),Vector3.UP)
		review_camera.make_current()
		await shot(str(station[3]))
		if actor is RadiatorProp: actor.apply_open_shift_condition(saved_condition)
	var after := _input_snapshot(root)
	check(before.get("sha256","") == after.get("sha256","changed"),"rendering inputs stayed fixed during qualification")
	var owner_ref: WeakRef = weakref(world)
	world.shutdown_for_tests()
	world.free()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(owner_ref.get_ref() == null,"production world retires after inspection")
	var head: Array=[]; var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record runtime input digest")
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var path: String = get_script().resource_path
	var contract := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"all loaded V2 physical surface UV/PBR/mip/filter checks; representative renders; no gameplay completion claim",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"surface_inputs_sha256":after.get("sha256",""),"inventory_sha256":FileAccess.get_sha256(directory.path_join("surface-inventory.json")),
		"contracts":{"production_composition":{"executed":true,"status":status},"surface_requirements":{"executed":true,"status":status},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned"}},
		"checks":batch_checks,"failures":failures}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(contract,"\t"))
	print("V2 SURFACE QUALIFICATION: ",status,"; ",batch_checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if passed else 1)

func _input_snapshot(root: String) -> Dictionary:
	var output: Array = []
	if OS.execute("python",[root.path_join("tools/v2_surface_evidence.py"),"--snapshot"],output) != 0 or output.is_empty(): return {}
	var result: Variant = JSON.parse_string(str(output[0]))
	return result if result is Dictionary else {}

func _validate_native_controls(world: Node) -> void:
	for actor: Node in world.find_children("*","Node3D",true,false):
		if actor is BookshelfProp and actor.case_style == "sectional":
			var saved: float = actor._door_open
			actor._door_open = 1.;actor._apply_doors()
			for door: MeshInstance3D in actor._doors:
				check(door.position.is_equal_approx(Vector3(0,.27,-.045)),"bookcase retains lift/pocket motion")
				check(door.mesh.get_surface_count()==2,"bookcase separates wood and glass stock")
			actor._door_open = saved;actor._apply_doors()
		if actor is RadiatorProp:
			for tag: MeshInstance3D in actor._porter_tag.find_children("*","MeshInstance3D",true,false):
				var bounds := tag.mesh.get_aabb()
				check(is_equal_approx(bounds.size.x,.1056) and is_equal_approx(bounds.size.y,.1584),"native paper tag retains physical size")

func _mesh(mesh: Mesh) -> Dictionary:
	var surfaces: Array = []
	for index in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = PackedVector2Array() if a[Mesh.ARRAY_TEX_UV] == null else a[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = PackedInt32Array() if a[Mesh.ARRAY_INDEX] == null else a[Mesh.ARRAY_INDEX]
		var missing := uv.size() != vertices.size()
		var invalid := 0
		var degenerate := 0
		var triangles := 0
		for point in uv:
			if not point.is_finite(): invalid += 1
		var primitive: int = (mesh as ArrayMesh).surface_get_primitive_type(index) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		if primitive == Mesh.PRIMITIVE_TRIANGLES and not missing:
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for start in range(0, count - 2, 3):
				var i: int = indices[start] if not indices.is_empty() else start
				var j: int = indices[start+1] if not indices.is_empty() else start+1
				var k: int = indices[start+2] if not indices.is_empty() else start+2
				if (vertices[j]-vertices[i]).cross(vertices[k]-vertices[i]).length_squared() <= 1e-18: continue
				triangles += 1
				if absf((uv[j]-uv[i]).cross(uv[k]-uv[i])) <= 1e-12: degenerate += 1
		surfaces.append({"vertices":vertices.size(),"missing_uv":missing,"nonfinite_uv":invalid,"degenerate_uv_triangles":degenerate,"triangles":triangles})
	return {"source":mesh.resource_path,"type":mesh.get_class(),"surfaces":surfaces}

func _texture(texture: Texture2D) -> String:
	var key := texture.resource_path
	if key.is_empty(): key = "generated:"+str(texture.get_instance_id())
	if not texture_rows.has(key):
		# A live render target is an image of a screen, not a sampled PBR map.
		# Dummy headless rendering cannot read it; keep it in the inventory.
		var pixels: Image = null if texture is ViewportTexture else texture.get_image()
		texture_rows[key] = {"type":texture.get_class(),"width":texture.get_width(),"height":texture.get_height(),"mips":pixels != null and pixels.has_mipmaps(),"mip_levels":pixels.get_mipmap_count() if pixels != null else 0,"compressed":pixels.is_compressed() if pixels != null else false,"format":pixels.get_format() if pixels != null else -1}
	return key

func _material(material: Material) -> Dictionary:
	var maps := {}
	var row := {"type":material.get_class(),"source":material.resource_path,"name":material.resource_name,"maps":maps}
	if material is StandardMaterial3D:
		row.triplanar = material.uv1_triplanar
		row.filter = material.texture_filter
		row.metallic = material.metallic
		row.roughness = material.roughness
		row.transparency = material.transparency
		row.unshaded = material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		row.additive = material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
		row.billboard = material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
		row.emissive = material.emission_enabled
		row.stock_recipe = str(material.get_meta("v2_surface_stock", ""))
		row.normal_enabled = material.normal_enabled
		row.color = [material.albedo_color.r,material.albedo_color.g,material.albedo_color.b,material.albedo_color.a]
		for property in material.get_property_list():
			var value: Variant = material.get(property.name)
			if value is Texture2D: maps[property.name] = _texture(value)
	elif material is ShaderMaterial and material.shader != null:
		row.shader = material.shader.resource_path
		row.shader_unshaded = material.shader.code.contains("unshaded")
		row.mip_filters = _shader_filters(material.shader)
		for uniform in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value is Texture2D: maps[uniform.name] = _texture(value)
			elif uniform.name in ["has_normal_tex", "has_rough_tex", "has_albedo_tex"]: row[uniform.name] = value
	if material.next_pass != null: row.next_pass = _material(material.next_pass)
	return row

func _shader_filters(shader: Shader) -> Dictionary:
	var identity := shader.get_instance_id()
	if shader_filter_cache.has(identity): return shader_filter_cache[identity]
	var code := shader.code
	var include := RegEx.new()
	include.compile('#include\\s+"(res://[^"]+)"')
	for match in include.search_all(code): code += "\n"+FileAccess.get_file_as_string(match.get_string(1))
	var sampler := RegEx.new()
	sampler.compile("uniform\\s+sampler2D\\s+(\\w+)\\s*([^;]*);")
	var filters := {}
	for match in sampler.search_all(code): filters[match.get_string(1)] = match.get_string(2).contains("mipmap")
	shader_filter_cache[identity] = filters
	return filters
