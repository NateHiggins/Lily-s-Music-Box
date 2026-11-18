extends "res://tests/arcade_all_native_carrier_test.gd"
## Nearby real clock transfer and fixed pavement receivers; no installed arcade.
const Public := preload("res://scripts/building/orison_v2_arcade_public_fittings.gd")
const ClockFactory := preload("res://scripts/building/orison_v2_arcade_clock.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const PROOF := "res://tests/fixtures/arcade_public_fittings_native.json"
var holder: Node3D
var donor: Node3D
var before_inputs: Dictionary
var started := 0

func _inputs() -> Dictionary:
	var result := {}
	for path: String in [Public.DATA, Public.CLOCK, Public.SOURCE, PROOF, Shell.DATA,
		"res://tests/fixtures/arcade_plaza_shells_contract.json", "res://data/runtime_material_sets.json",
		"res://tests/arcade_public_fittings_test.gd", "res://tests/ArcadePublicFittingsTest.tscn",
		"res://tests/arcade_all_native_carrier_test.gd", "res://tests/orison_v2_domestic_native_test.gd", "res://tests/arcade_clock_bench.gd",
		"res://scripts/building/orison_v2_arcade_public_fittings.gd", "res://scripts/building/orison_v2_arcade_clock.gd",
		"res://scripts/building/orison_v2_arcade_clock_movement.gd", "res://scripts/building/orison_v2_arcade_plaza_shell.gd",
		"res://scripts/building/orison_v2_arcade_native_carrier.gd", "res://scripts/building/orison_v2_shop_seating.gd",
		"res://scripts/building/orison_v2_architectural_materials.gd", "res://scripts/building/surface_pass.gd",
		"res://scripts/material_library.gd", "res://scripts/generated/material_sets.gd",
		"res://scripts/game/campaign_clock.gd", "res://scripts/game/campaign_clock_driver.gd",
		"res://scripts/game/reality_game_state.gd", "res://shaders/orison_surface.gdshader", "res://shaders/lamp_glass_surface.gdshader",
		"res://assets/building/orison_v2/passage/passage.gltf"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json"))
	var keys := {}
	var shell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Shell.DATA))
	for row: Dictionary in shell.materials: keys[str(row.catalog_key)] = true
	var clock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Public.CLOCK))
	for row: Dictionary in clock.cells[0].parts: keys[str(row.get("catalog_key", row.key))] = true
	for key: String in ["cast_iron", "brass_dull", "metal"]: keys[key] = true
	for key: String in keys:
		for name: String in catalog.materials[key].files:
			var path := "res://assets/building/textures/" + name
			result[path] = FileAccess.get_sha256(path)
	for path: String in ["res://assets/props/arcade_public_fittings.glb", "res://assets/props/arcade_plaza_shells.glb", "res://assets/props/arcade_clock.glb"]:
		result[path] = FileAccess.get_sha256(path)
		result[path + ".import"] = FileAccess.get_file_as_string(path + ".import").replace("\r\n", "\n").sha256_text()
	var passage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/building/orison_v2/passage/passage.gltf"))
	for buffer: Dictionary in passage.buffers:
		var path := "res://assets/building/orison_v2/passage/" + str(buffer.uri)
		result[path] = FileAccess.get_sha256(path)
	return result

func run() -> void:
	started = Time.get_ticks_msec()
	OS.add_logger(logger)
	old_mouse = Input.mouse_mode
	original = RealityState.data
	original_text = JSON.stringify(original, "", true, true)
	before_inputs = _inputs()
	preview = RealityState.begin_preview_campaign(self)
	if not check(preview, "exclusive preview campaign"):
		await done()
		return
	var clock := CampaignClock.new()
	check(clock.configure_date(1928,10,15,610), "known shared-clock fixture")
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Public.DATA))
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
	var frame := Carrier.new()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Public.SOURCE))
	donor = (load("res://assets/building/orison_v2/passage/passage.gltf") as PackedScene).instantiate() as Node3D
	donor.name = "passage"
	if not check(ClockFactory.mount_cell(donor,layout), "existing strict original clock owner mounts on detached source"):
		await done()
		return
	var model := donor.get_node("ArcadeClock") as Node3D
	var movement := model.get_node("ClockMovement")
	var hands: Dictionary = movement.get("_hands")
	var rest: Dictionary = (movement.get("_rest") as Dictionary).duplicate()
	var snapshot := _snapshot(model,frame)
	var labels := {}
	for label: Label3D in model.find_children("*","Label3D",true,false): labels[label] = {"text":label.text,"pose":label.transform}
	var child_count := donor.get_child_count()
	for kind: String in ["schema","source","native","duplicate","frame","tint","response"]:
		var bad := spec.duplicate(true)
		match kind:
			"schema": bad.schema = "wrong"
			"source": bad.fabrication_sha256_lf = "wrong"
			"native": bad.asset_sha256 = "wrong"
			"duplicate": bad.parts[1] = bad.parts[0].duplicate(true)
			"frame": bad.parts[0].transform[0][3] += .1
			"tint": bad.materials[0].tint[0] = NAN
			"response": bad.materials[0].normal = INF
		var refused := Public.new()
		var result := refused.extract_clock(donor,bad)
		check(result == null and not refused.errors.is_empty(), "clock admission refuses " + kind)
		if result != null: result.free()
		check(donor.get_child_count() == child_count and donor.get_node_or_null("ArcadeClock") == model, "refusal leaves actual donor intact " + kind)
	var helper := Public.new()
	var projected := helper.extract_clock(donor,spec)
	if not check(projected != null, "whole scripted clock transfer: " + str(helper.errors)):
		await done()
		return
	check(projected.get_node("ArcadeClock") == model and model.get_node("ClockMovement") == movement, "same clock and same presentation owner transferred")
	check(movement.get("_hands") == hands and movement.get("_rest") == rest, "eight direct hand references and local rest frames unchanged")
	for identity: int in snapshot:
		var old: Dictionary = snapshot[identity]
		check(old.node.mesh == old.mesh and _signature(old.node) == old.signature and old.node.material_override == old.material_override and frame._same(frame._relative(old.node,model),old.pose), "original clock geometry/material/local pose unchanged " + str(old.node.name))
	for label: Label3D in labels:
		check(label.text == labels[label].text and label.transform == labels[label].pose and model.is_ancestor_of(label), "original dial numeral remains in whole assembly " + str(label.name))
	var duplicate := Public.new()
	var again := duplicate.extract_clock(donor,spec)
	check(again == null and not duplicate.errors.is_empty(), "same donor cannot yield a duplicate clock")
	if again != null: again.free()
	var hatches := Public.new().prepare_hatches(spec)
	var shell_helper := Shell.new()
	var shell := shell_helper.prepare(JSON.parse_string(FileAccess.get_file_as_string(Shell.DATA)))
	if not check(hatches != null and shell != null, "new fitted hatch/floor assemblies admit together " + str(shell_helper.errors)):
		projected.free()
		if hatches != null: hatches.free()
		if shell != null: shell.free()
		await done()
		return
	holder = Node3D.new()
	holder.position.z = -9.795
	add_child(holder)
	holder.add_child(shell)
	holder.add_child(projected)
	holder.add_child(hatches)
	check(projected.position.is_equal_approx(frame._point(proof.clock.proof.delta)), "single rigid source projection, external Vantry applied once")
	var bench := preload("res://tests/arcade_clock_bench.gd").new()
	bench.review_suite = self
	for minute: float in [610.,822.]:
		check(clock.configure_date(1928,10,15,minute) and movement.refresh_from_campaign(), "original clock reads shared time " + str(minute))
		bench._check_hands(model,minute)
		check(clock.minute_of_day() == minute, "presentation never writes shared clock " + str(minute))
	bench.free()
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for part: MeshInstance3D in projected.get_node("ClockSuspension").get_children() + hatches.get_children():
		metrics._check_cap_mapping(part.mesh,true)
		var material := part.material_override as ShaderMaterial
		check(material != null and int(material.get_shader_parameter("uv_mode")) == 0, "authored UV finish " + str(part.name))
		for parameter: String in ["albedo_tex","rough_tex","normal_tex"]:
			var texture := material.get_shader_parameter(parameter) as Texture2D
			check(texture != null and texture.get_image().has_mipmaps(), "loaded custom map mips " + str(part.name) + "/" + parameter)
	check(metrics.failures.is_empty(), "strict loaded seven-stock UV/normal/tangent metrics " + str(metrics.failures))
	metrics.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bearing(projected,shell,proof,frame)
	var excluded: Array[RID] = []
	for body: CollisionObject3D in hatches.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	for row: Dictionary in proof.hatches.stocks:
		var rect: Array = row.plan_rect_m
		var draw := hatches.get_node(NodePath(str(row.name))) as MeshInstance3D
		check(not draw.get_meta("source_disposal_authorized",false), "original hatch donor disposal remains unauthorized")
		for sample: Vector2 in [Vector2(.05,.05),Vector2(.95,.05),Vector2(.05,.95),Vector2(.95,.95),Vector2(.5,.5)]:
			var point := holder.to_global(Vector3(1.18+lerpf(rect[0],rect[2],sample.x),0.,38.6+lerpf(rect[1],rect[3],sample.y)))
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.02,point-Vector3.UP*.05)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and draw.is_ancestor_of(hit.collider) and absf(hit.position.y)<.000001, "actual flush hatch top " + str(row.name) + str(sample))
			ray.exclude = excluded
			var floor_hit := get_world_3d().direct_space_state.intersect_ray(ray)
			check(not floor_hit.is_empty() and shell.is_ancestor_of(floor_hit.collider) and absf(floor_hit.position.y+.004)<.000001, "actual closed receiving floor at -4mm " + str(row.name) + str(sample))
	await render_review(shell,projected,hatches)
	await done()

func _bearing(projected: Node3D, shell: Node3D, proof: Dictionary, frame: RefCounted) -> void:
	var stem := projected.get_node("ClockSuspension/site_crossing_clock_stem") as MeshInstance3D
	var roof := shell.get_node("passage/ArcadePlaza_public_roof_steel") as MeshInstance3D
	var stem_pose: Transform3D = frame._relative(stem,holder)
	var roof_pose: Transform3D = frame._relative(roof,holder)
	var vertices: PackedVector3Array = stem.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var faces := roof.mesh.get_faces()
	var maximum_native_gap := 0.
	var maximum_collision_snap := 0.
	for contact: Dictionary in proof.clock.proof.cap_contacts:
		var target: Vector3 = frame._point(contact.target_point)
		var nearest := INF
		for point: Vector3 in vertices: nearest = minf(nearest,(stem_pose*point).distance_to(target))
		check(nearest < .00001, "actual native coped cap vertex " + str(contact.index))
		var from := target-Vector3.UP*.01
		var closest := Vector3.INF
		for at in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(from,Vector3.UP,roof_pose*faces[at],roof_pose*faces[at+1],roof_pose*faces[at+2])
			if hit is Vector3 and (not closest.is_finite() or from.distance_squared_to(hit) < from.distance_squared_to(closest)): closest = hit
		var native_gap := closest.distance_to(target) if closest.is_finite() else INF
		maximum_native_gap = maxf(maximum_native_gap,native_gap)
		check(native_gap < .00001,"actual unsnapped native rib receives coped cap " + str(contact.index))
		var ray := PhysicsRayQueryParameters3D.create(holder.to_global(from),holder.to_global(target+Vector3.UP*.01))
		var physical := get_world_3d().direct_space_state.intersect_ray(ray)
		var snap := holder.to_local(physical.position).distance_to(closest) if not physical.is_empty() and closest.is_finite() else INF
		maximum_collision_snap = maxf(maximum_collision_snap,snap)
		# Separate engine0.1mm collision quantization from native bearing error.
		# The native fit keeps its10micron bound above; no gap is waived for snapping.
		check(not physical.is_empty() and roof.is_ancestor_of(physical.collider) and snap < .0001,"real rib collider and independently measured collision snap " + str(contact.index))
	observations.append({"kind":"actual_clock_bearing","native_gap_m":maximum_native_gap,"collision_snap_m":maximum_collision_snap,"contacts":proof.clock.proof.cap_contacts.size(),"external_vantry_z":holder.position.z})

func render_review(shell: Node3D, projected: Node3D, hatches: Node3D) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.1,.11,.13)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	for shot: Dictionary in [
		{"name":"clock.png","eye":Vector3(15.7,5.8,50),"at":Vector3(14,4.97,52.2733333),"size":2.7},
		{"name":"clock_bearing.png","eye":Vector3(14.3,9.44,52.6),"at":Vector3(14,9.65,52.2733333),"size":.5},
		{"name":"photo_hatch.png","eye":Vector3(18.3,3.,38.7),"at":Vector3(16.57,0.,39.9),"size":3.5}]:
		for draw: MeshInstance3D in shell.find_children("*","MeshInstance3D",true,false):
			draw.visible = str(draw.name) in (["ArcadePlaza_public_public_floor"] if shot.name == "photo_hatch.png" else ["ArcadePlaza_public_roof_steel"])
		projected.visible = shot.name != "photo_hatch.png"
		hatches.visible = shot.name == "photo_hatch.png"
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(shot.size)
		camera.look_at_from_position(holder.to_global(shot.eye),holder.to_global(shot.at))
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join(str(shot.name))) == OK,"loaded public view " + str(shot.name))

func done() -> void:
	if is_instance_valid(holder): holder.free()
	if is_instance_valid(donor): donor.free()
	if preview:
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,original) and JSON.stringify(original,"",true,true) == original_text,"exact original campaign object/content restored")
	Input.mouse_mode = old_mouse
	for frame in 3: await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine/teardown errors")
	check(_inputs() == before_inputs,"executed source inputs remain frozen")
	OS.remove_logger(logger)
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): output = "user://tests/arcade_public_fittings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var passed := failures.is_empty()
	var result := {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":false,"selector":"v2",
		"scope":"Nearby actual original-clock transfer and shared time, fixed hatch/floor receivers, native UV/mips and refusal controls. No installed arcade, occupied passage/service/save/cost/human or artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/tests/arcade_public_fittings_test.gd","inputs":before_inputs},
		"contracts":{"public_fittings":{"executed":true,"status":"PASS" if passed else "FAIL"}},
		"checks":checks,"failures":failures,"engine_errors":logger.errors,"observations":observations}
	FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ARCADE PUBLIC FITTINGS RESULT: %d checks / %d failures" % [checks,failures.size()])
	get_tree().quit(0 if passed else 1)
