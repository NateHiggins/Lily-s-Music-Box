extends Node3D
## Nearby prepared actor/hour/transaction-anchor diagnostic, not installed commerce/save proof.
const Assembly := preload("res://scripts/building/orison_v2_arcade_prepared_geometry.gd")
const ActorPatch := preload("res://scripts/building/orison_v2_arcade_actor_projection.gd")
const Hours := preload("res://scripts/building/passage_hours_director.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Carrier := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Host := preload("res://scripts/building/orison_v2_passage_region.gd")
const NATIVE_INPUT := "res://tests/fixtures/arcade_all_native_projection.json"
const RAW_INPUT := "res://tests/fixtures/arcade_all_raw_projection.json"
const SHELL_INPUT := "res://tests/fixtures/arcade_plaza_shells_contract.json"
const FRAME_INPUT := "res://tests/fixtures/arcade_door_frames.json"
var failures: Array[String] = []
var observations: Array = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()
var host: OrisonV2PassageRegion
var service: MaintenanceShopService
var hours: PassageHoursDirector
var projected: Dictionary
var output := ""
var original: Dictionary
var original_text := ""
var original_graph: Dictionary
var old_mouse: int
var camera: Camera3D
var started: int
var storefront_inputs: Dictionary

func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);print("ARCADE ACTOR FAIL: ",label)
	return ok
func _ready() -> void:run.call_deferred()

func _storefront_inputs() -> Dictionary:
	var result := {}
	for path: String in [ActorPatch.DATA, ActorPatch.SOURCE, Shell.DATA, Shell.STOREFRONT_DATA, Assembly.PENDANTS,
		NATIVE_INPUT, RAW_INPUT, SHELL_INPUT, FRAME_INPUT,
		"res://scripts/building/orison_v2_passage_residency.gd",
		"res://tests/arcade_actor_projection_test.gd", "res://tests/ArcadeActorProjectionTest.tscn",
		"res://scripts/building/orison_v2_arcade_actor_projection.gd", "res://scripts/building/orison_v2_arcade_plaza_shell.gd",
		"res://scripts/building/orison_v2_passage_region.gd", "res://scripts/building/passage_hours_director.gd",
		"res://scripts/building/passage_finish_pass.gd", "res://scripts/building/orison_v2_arcade_prepared_geometry.gd",
		"res://scripts/building/orison_v2_arcade_shop_door.gd", "res://scripts/props/door_prop.gd",
		"res://scripts/props/light_fixture_prop.gd", "res://scripts/props/passage_pushcart.gd",
		"res://scripts/game/v2_maintenance_shop_service.gd", "res://scripts/building/orison_v2_public_region_programmes.gd",
		"res://data/orison_v2/exterior/public_region_programmes.json", Assembly.PENDANT_ASSET + ".import",
		"res://scripts/props/shop_sign_prop.gd", "res://scripts/building/surface_pass.gd",
		"res://shaders/orison_surface.gdshader", "res://scripts/generated/material_sets.gd",
		"res://scripts/material_library.gd", "res://tests/orison_v2_roof_bulkhead_caps_test.gd",
		"res://tests/fixtures/arcade_actor_projection.json",
		"res://assets/props/arcade_storefront_identity.glb.import", "res://assets/props/arcade_plaza_shells.glb.import"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	for path: String in ["res://assets/props/arcade_storefront_identity.glb", "res://assets/props/arcade_plaza_shells.glb",
		Assembly.PENDANT_ASSET, "res://assets/props/arcade_door_leaves.glb", "res://assets/props/arcade_darkroom_curtain.glb"]:
		result[path] = FileAccess.get_sha256(path)
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Shell.STOREFRONT_DATA))
	for finish: Dictionary in declaration.materials:
		var key := str(finish.catalog_key)
		for name: String in MatLib.SETS[key].slice(0,3):
			var path := MatLib.TEX + name
			result[path] = FileAccess.get_sha256(path)
			result[path + ".import"] = FileAccess.get_file_as_string(path + ".import").replace("\r\n", "\n").sha256_text()
	for declaration_path: String in [NATIVE_INPUT,RAW_INPUT]:
		var intake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(declaration_path))
		for cell: Dictionary in intake.cells:
			for path: String in cell.source_bindings:
				if cell.source_bindings[path].kind == "raw":
					result[path] = FileAccess.get_sha256(path)
				else:
					result[path] = FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return result

func _legacy(layout: Dictionary) -> void:
	var legacy := Hours.new();add_child(legacy);legacy.set_process(false)
	var specs: Array = legacy._shopfront_specs(layout)
	var expected: Array[Transform3D] = []
	for spec: Dictionary in specs:legacy._append_closed_lattice(spec,expected)
	var batch := legacy._build_grille_batch("UnchangedSideBayControl",specs,false)
	var exact := batch.multimesh.instance_count == expected.size()
	for index: int in expected.size(): exact = exact and batch.multimesh.get_instance_transform(index).is_equal_approx(expected[index])
	check(exact,"all original side-bay grille placements unchanged")
	legacy.free()

func _bounds() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_actor_projection.json"))
	for row: Dictionary in fixture.anchors:
		var family := "hardware_stock" if row.cell == "shop_hardware_paint" else "news_fittings"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+family+".json"))
		check(str(data.asset) == "res://"+str(row.native_source.asset).trim_prefix("game/") and FileAccess.get_sha256(str(data.asset)) == str(row.native_source.asset_sha256),"exact admitted native transaction asset bytes")
		var native := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
		var identity := str(row.id).trim_suffix("_top")+"__countertop"
		var draw := native.find_child(identity,true,false) as MeshInstance3D
		if check(draw != null,"actual loaded transaction countertop " + identity):
			var helper := Carrier.new()
			var pose: Transform3D = helper._matrix(row.delta_transform)*helper._relative(draw,native)
			var bounds := pose*draw.mesh.get_aabb()
			var record: Dictionary = row.target_record
			var rect: Array = record.rect
			var expected := AABB(Vector3(rect[0],record.z0,-rect[3]),Vector3(float(rect[2])-float(rect[0]),record.h,float(rect[3])-float(rect[1])))
			check(bounds.position.distance_to(expected.position)<.00005 and bounds.end.distance_to(expected.end)<.00005,"projected transaction anchor matches actual native top bounds")
			observations.append({"kind":"native_transaction_bounds","id":row.id,"low":[bounds.position.x,bounds.position.y,bounds.position.z],"high":[bounds.end.x,bounds.end.y,bounds.end.z]})
		native.free()
	var counter := service.counter("hardware_paint")
	check(counter != null,"existing V2 maintenance service counter mounted")
	if counter != null:
		var record: Dictionary
		for floor: Dictionary in projected.floors:
			if floor.id != "F01":continue
			for item: Dictionary in floor.furniture:
				if item.id == "storm_shop_hardware_paint_counter_top":record=item
		var r: Array = record.rect
		var local := GameBoot.b2g([(float(r[0])+float(r[2]))*.5,(float(r[1])+float(r[3]))*.5,float(record.z0)+float(record.h)+MaintenanceShopService.REACH_H*.5])
		check(counter.global_position.distance_to(host.to_global(local))<.00001,"existing counter adapter applies final Vantry frame exactly once")
	var stand := host._actors.get_node_or_null("NewsStand") as NewsRackProp
	check(stand != null and stand.hours == hours,"real newspaper control uses existing hours authority")

func _safelight_geometry() -> void:
	var identity := "SITE_SHOP_DARKROOM_PHOTO_SUPPLIES"
	var lamp := host._actors.get_node(NodePath(identity)) as LightFixtureProp
	var source: Dictionary
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ActorPatch.SOURCE))
	for floor: Dictionary in authored.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if marker.id == identity: source = marker
	var source_frame := Transform3D(Basis(Vector3.UP, deg_to_rad(-float(source.yaw_deg))), GameBoot.b2g(source.pos))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/photo_radio_fittings.json"))
	var native := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
	var legacy := preload("res://scripts/props/photo_darkroom_light.gd").new()
	legacy.name = "LegacySafelightSourceControl"
	legacy.prop_type = str(source.kind)
	legacy.transform = source_frame
	host.add_child(legacy)
	legacy.set_process(false)
	check(not legacy.has_native_source_frame and legacy.light.global_position.distance_to(host.to_global(helper_point(data.emitter))) < .00001, "ordinary unprojected safelight emitter remains exact")
	var delta := lamp.global_transform * source_frame.affine_inverse()
	var helper := Carrier.new()
	var matches := 0
	for row: Dictionary in data.actor_parts:
		var old := native.find_child(str(row.name), true, false) as MeshInstance3D
		var draw := lamp.get("native_parts")[str(row.name)] as MeshInstance3D
		check(draw != null and helper._same(draw.global_transform, delta * helper._relative(old, native)), "native safelight body follows source-to-target frame " + str(row.name))
		check(draw.mesh.get_faces().to_byte_array() == old.mesh.get_faces().to_byte_array(), "safelight original native triangles unchanged " + str(row.name))
		var legacy_draw := legacy.native_parts[str(row.name)] as MeshInstance3D
		check(helper._same(legacy_draw.global_transform, host.global_transform * helper._relative(old, native)), "ordinary unprojected native safelight frame unchanged " + str(row.name))
		var box := draw.global_transform * draw.mesh.get_aabb()
		check(box.position.x >= 23.30 - .00005 and box.end.x <= 26.70 + .00005 and box.position.z >= 38.72 + host.position.z - .00005, "safelight body inside actual stock wall/room " + str(row.name))
		matches += 1
	check(matches == 2, "both original native safelight partitions retained")
	var emitter := helper._point(data.emitter)
	check(lamp.light.global_position.distance_to(delta * emitter) < .00001, "real red emitter moves with native body exactly once")
	check(lamp.bounce.global_position.distance_to(delta * (emitter + Vector3.DOWN)) < .00001, "existing red bounce follows same source frame")
	check(lamp.light.global_position.distance_to(host.to_global(emitter)) > 10, "original cancelled-relocation control now separated from actual emitter")
	var back := delta * Vector3(22.94, 2.23, 59.725)
	check(absf(back.z - (38.72 + host.position.z)) < .00001, "native mounting bracket reaches actual north stock wall")
	var exclude: Array[RID] = []
	for body: CollisionObject3D in lamp.find_children("*", "CollisionObject3D", true, false): exclude.append(body.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(back + Vector3.BACK * .03, back - Vector3.BACK * .03, 1, exclude))
	check(not hit.is_empty() and shell_is_ancestor(hit.collider) and absf(hit.position.z - back.z) < .00005, "actual mounted shell supports native safelight bracket")
	observations.append({"kind":"safelight_native_frame","source_marker":source.pos,"target_marker":[lamp.position.x,lamp.position.y,lamp.position.z],"emitter_world":[lamp.light.global_position.x,lamp.light.global_position.y,lamp.light.global_position.z],"wall_contact":[back.x,back.y,back.z],"native_parts":matches})
	native.free()
	legacy.free()

func helper_point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func shell_is_ancestor(node: Node) -> bool:
	return host.is_ancestor_of(node) and node.get_parent() is MeshInstance3D and node.get_parent().has_meta("arcade_shell_part")

func _storefront_checks(frontage: Node3D) -> void:
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var draws := frontage.find_children("ArcadeStorefront_*", "MeshInstance3D", true, false)
	check(draws.size() == 49, "all native storefront draws loaded")
	var checked_materials := {}
	for draw: MeshInstance3D in draws:
		metrics._check_cap_mapping(draw.mesh, true)
		var material := draw.get_active_material(0) as ShaderMaterial
		if not check(material != null and int(material.get_shader_parameter("uv_mode")) == 0, "authored UVs for " + str(draw.name)):
			continue
		if checked_materials.has(material):
			continue
		checked_materials[material] = true
		for parameter: String in ["albedo_tex", "rough_tex", "normal_tex"]:
			var texture := material.get_shader_parameter(parameter) as Texture2D
			check(texture != null and texture.get_image().has_mipmaps(), "storefront loaded mip chain " + parameter + "/" + str(draw.get_meta("material_key")))
	check(metrics.failures.is_empty(), "storefront loaded metric UV and tangent derivatives " + str(metrics.failures))
	metrics.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blade_count := 0
	for sign_prop: ShopSignProp in host._signs:
		var area := sign_prop.get_node("ShopSignInspection") as Area3D
		for part: CollisionShape3D in area.get_children():
			var blade := part.name == "BladeShape"
			if blade: blade_count += 1
			# Test both blade faces. Rays include bodies so any trim that hides the
			# existing inspection target will win the query and fail this check.
			for outward: Vector3 in ([Vector3.LEFT, Vector3.RIGHT] if blade else [Vector3.BACK]):
				var at := sign_prop.to_global(part.position)
				var from := sign_prop.to_global(part.position + outward*.26)
				var ray := PhysicsRayQueryParameters3D.create(from, at, 1)
				ray.collide_with_areas = true
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				check(hit.get("collider") == area, "original sign inspection area in front of trim " + str(sign_prop.name) + "/" + str(part.name) + str(outward))
	check(blade_count == 5, "original five blade inspection shapes")

func _storefront_views() -> void:
	if output.is_empty(): return
	for identity: String in ["SITE_SHOP_SIGN_KEYS_CUT", "SITE_SHOP_SIGN_MODEL_LAUNDRY", "SITE_SHOP_SIGN_PAWNBROKER"]:
		var sign_prop := host._actors.get_node(NodePath(identity)) as ShopSignProp
		var eye := Vector3(-.6,-.9,3.0)
		if identity == "SITE_SHOP_SIGN_MODEL_LAUNDRY":
			eye = Vector3(1.7,-.85,1.0)
		camera.look_at_from_position(sign_prop.to_global(eye), sign_prop.to_global(Vector3(0,-.15,0)))
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join(identity+".png")) == OK, "loaded storefront lettering view " + identity)

func _state(minute: float,closed: bool) -> void:
	hours.apply_for_minute(minute)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(hours.is_after_hours()==closed,"ordinary authored hours state " + str(minute))
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_door_frames.json"))
	for row: Dictionary in frames.frames:
		if not bool(row.paired):continue
		var matrix: Transform3D = Carrier.new()._matrix(row.frame_transform)
		var centre := matrix*Vector3(float(row.width)*.5,.95,-.16)
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.8
		query.shape=capsule;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,host.to_global(centre));query.margin=.001
		var hits := get_world_3d().direct_space_state.intersect_shape(query,16)
		var gate_hit := hits.any(func(hit: Dictionary)->bool:return hit.collider == hours._barrier)
		check(gate_hit == (closed and row.cell != "shop_hardware_paint"),"actual relocated grille collision/hour policy " + str(row.cell))
	for spec: Dictionary in hours.shop_specs:
		var suffix := str(spec.id).trim_prefix("SITE_SHOP_HOURS_")
		for prefix: String in Hours.SHOP_LIGHT_PREFIXES:
			var lamp := host._actors.get_node_or_null(NodePath(prefix+suffix)) as LightFixtureProp
			if lamp == null:continue
			var expected := 1.0
			if closed and str(spec.trade) != Hours.NIGHT_SERVICE_TRADE:
				expected=float(Hours.NIGHT_SECURITY_GAIN.get(str(spec.trade),0)) if prefix == Hours.NIGHT_SECURITY_FIXTURE else 0.0
			check(is_equal_approx(lamp._state_gain,expected) and lamp.powered == (expected>0),"existing per-trade light policy follows moved marker " + str(lamp.name))
	var stand := host._actors.get_node("NewsStand") as NewsRackProp
	check(stand.shuttered()==closed,"newspaper shutter state retained")
	for frame: int in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():check(get_viewport().get_texture().get_image().save_png(output.path_join("hours_"+str(int(minute))+".png"))==OK,"actual projected hours frame")

func _residency_actors() -> void:
	var old_door: DoorProp = host.doors["SITE_SHOP_DOOR_HARDWARE_PAINT"]
	old_door.restore_mechanism({"angle":PI/6})
	var old_lamp := host._actors.get_node("PASSAGE_AISLE_LT_07") as LightFixtureProp
	var old_cart: PassagePushcart = host.finish.pushcarts[0]
	var original_counter_position := service.counter("hardware_paint").global_position
	var retired := host.suspend_geometry()
	check(not host._actors.visible and not host.transaction_counter_available("hardware_paint"),
		"original suspension hides actors and unmounts the real counter")
	await get_tree().process_frame
	check(retired.get_ref() == null and host.doors[str(old_door.name)] == old_door,
		"original suspension releases fitted geometry independently of the stable door")
	var residency := Host.Residency.new()
	residency.region = host
	host.residency = residency
	host.add_child(residency)
	residency._gate(true)
	residency._begin_load()
	if not check(residency.state == "LOADING","existing controller starts the prepared builder"): return
	residency._stage_one()
	residency._wanted = false
	residency._stage_one()
	check(residency.state == "DORMANT" and residency._prepared_build == null and host.cell_nodes.size() == 1
		and residency._guard.visible and not host._actors.visible,"abandoned prepared fit retains only the gateway and loading guard")
	residency._wanted = true
	residency._begin_load()
	var hidden_cells := 0
	for frame: int in 300:
		if residency.state != "LOADING": break
		residency._stage_one()
		if residency._publication_root != null and not residency._publication_root.visible \
			and residency._guard.visible and not host._actors.visible:
			hidden_cells = residency._publication_root.get_child_count()
		await get_tree().process_frame
	if not check(residency.state == "RESIDENT" and residency.load_cycles == 1 and hidden_cells == 12
		and not residency._guard.visible,"all returning cells publish behind the original hidden gate"): return
	check(host.cell_nodes.passage.has_node("ArcadeAislePendants")
		and host.cell_nodes.passage.has_node("ArcadePublicClock")
		and host.cell_nodes.shop_hardware_paint.has_meta("arcade_retained_shop_admitted"),
		"returning geometry contains the prepared public fittings and retained hardware shop")
	check(host._actors.visible and host.transaction_counter_available("hardware_paint")
		and host._actors.get_node("PASSAGE_AISLE_LT_07") == old_lamp
		and host.finish.pushcarts[0] == old_cart and host.doors[str(old_door.name)] == old_door
		and is_equal_approx(old_door.mechanism_snapshot().angle,PI/6),
		"reactivation preserves the cart, lamp and door angle and remounts the original shop service")
	var counter := service.counter("hardware_paint")
	check(counter != null and counter.global_position.distance_to(original_counter_position) < .00001,
		"remounted maintenance counter keeps its new position")
	old_door.restore_mechanism({"angle":0.0})

func run() -> void:
	started = Time.get_ticks_msec()
	storefront_inputs = _storefront_inputs()
	OS.add_logger(logger);output=OS.get_environment("SHOT_DIR")
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	original=RealityState.data;original_text=JSON.stringify(original,"",true,true);original_graph=AcousticGraphData.nodes.duplicate(true);old_mouse=Input.mouse_mode
	if not check(RealityState.begin_preview_campaign(self),"isolated campaign"):get_tree().quit(1);return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ActorPatch.DATA))
	var source_text := FileAccess.get_file_as_string(ActorPatch.SOURCE)
	var layout: Dictionary = JSON.parse_string(source_text)
	_legacy(layout)
	for kind: String in ["missing","duplicate","nonspatial","nonfinite","source","anchor_authority"]:
		var bad := spec.duplicate(true)
		match kind:
			"missing":bad.markers.pop_back()
			"duplicate":bad.markers[1]=bad.markers[0]
			"nonspatial":bad.markers[0].patch.energy=0
			"nonfinite":bad.markers[0].patch.pos[0]=INF
			"source":bad.source_sha256_lf="changed"
			"anchor_authority":bad.anchors[0].patch.price_cents=0
		var refused := ActorPatch.new();check(refused.prepare(bad).is_empty() and not refused.errors.is_empty(),"reject authority/coverage mutation " + kind)
	var helper := ActorPatch.new();projected=helper.prepare(spec)
	if not check(not projected.is_empty(),"same-ID spatial projection admitted " + str(helper.errors)):get_tree().quit(1);return
	var input_text := JSON.stringify(spec,"",true,true)
	var scratch := helper.prepare(spec)
	for floor: Dictionary in scratch.floors:
		if floor.id != "F01":continue
		for marker: Dictionary in floor.markers:
			if marker.id == spec.markers[0].id:marker.pos[0]+=100
		for item: Dictionary in floor.furniture:
			if item.id == spec.anchors[0].id:item.rect[0]-=100
	check(JSON.stringify(spec,"",true,true)==input_text,"returned layout does not share mutable marker/anchor arrays with intake")
	check(helper.prepare(spec)==projected,"repeat preparation returns exact independent spatial state")
	service=preload("res://scripts/game/v2_maintenance_shop_service.gd").new();add_child(service);service.setup(null,null)
	check(service.is_valid(),"existing stock definitions valid")
	host=Host.new()
	host.name="PreparedActorHost"
	check(host.configure(service),"production region binds the registered Vantry frame and immutable fabrication")
	var shell_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHELL_INPUT))
	var native: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NATIVE_INPUT))
	var raws: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAW_INPUT))
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FRAME_INPUT))
	var bundle := {"shell":shell_spec,"frames":frames.frames,"native":native.cells,"raw":raws.cells,"placement":projected}
	if not check(host.configure_prepared(bundle),"explicit prepared source wired to the real region"):
		host.free(); get_tree().quit(1); return
	add_child(host)
	if not check(not host.startup_failed and host.cell_nodes.size() == 13
		and host.cell_nodes.shop_hardware_paint.has_meta("arcade_retained_shop_admitted"),
		"production region startup mounts the registered gateway and twelve prepared cells"):
		get_tree().quit(1); return
	check(host.source_layout == layout and host.source_layout != projected,"fabrication stays separate from actor placement")
	check(host._signs.size()==11 and host.doors.size()==11,"eleven original sign and storefront mechanism owners")
	var lamps := 0
	for actor: Node in host._actors.get_children():
		if actor is LightFixtureProp:lamps+=1
	check(lamps==49,"original shop, aisle and portal light actors retained")
	check(host.receiving_row.cabinets.is_empty() and host.finish.pushcarts.size()==3,
		"receiving retirement and original movable-cart policy retained")
	hours=host.finish.hours_director
	hours.set_process(false)
	_bounds()
	var storefront_loaded := host._geometry_root != null
	if check(storefront_loaded,"prepared storefront is part of the region geometry"):
		await _storefront_checks(host._geometry_root)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.05,.06,.08);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.18;add_child(env)
	camera=Camera3D.new();host.add_child(camera);camera.fov=75
	var target := Vector3.ZERO
	for record: Dictionary in hours.shop_specs:
		if record.trade == "hardware":target=record.position
	camera.look_at_from_position(host.to_global(Vector3(target.x,1.65,target.z-6)),host.to_global(Vector3(target.x,1.4,target.z)));camera.make_current()
	await _state(750,false)
	await _storefront_views()
	_safelight_geometry()
	camera.look_at_from_position(host.to_global(Vector3(25.42,2.2,40.5)),host.to_global(Vector3(25.42,2.25,38.9)))
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty(): check(get_viewport().get_texture().get_image().save_png(output.path_join("safelight_native.png")) == OK, "native relocated safelight view")
	var shop_door: DoorProp = host.doors["SITE_SHOP_DOOR_KEYS_CUT"]
	camera.look_at_from_position(shop_door.to_global(Vector3(1,1.65,3.3)),shop_door.to_global(Vector3(1,1.35,0)))
	await _state(180,true);await _state(750,false)
	await _residency_actors()
	check(FileAccess.get_file_as_string(ActorPatch.SOURCE)==source_text,"immutable fabrication bytes unchanged")
	host.free();host=null;service.free();service=null
	for frame: int in 4:await get_tree().process_frame
	check(AcousticGraphData.nodes==original_graph,"all original acoustic positions restored")
	check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,original) and JSON.stringify(original,"",true,true)==original_text,"exact campaign restored")
	Input.mouse_mode=old_mouse
	check(_storefront_inputs() == storefront_inputs, "declared storefront inputs remain frozen")
	check(logger.errors.is_empty(),"no engine/teardown errors")
	OS.remove_logger(logger)
	if not output.is_empty():FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Prepared same-ID marker factory/hour/light/transaction-anchor diagnostic only; no installed service purchase/save/residency/art acceptance","checks":checks,"failures":failures,"engine_errors":logger.errors,"observations":observations},"\t"))
	if not output.is_empty():
		var passed := failures.is_empty()
		var contract := {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":false,"selector":"v2",
			"scope":"Explicit prepared region startup, storefront/hour interactions and staged return under the existing residency controller.",
			"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
			"source":{"test_path":"game/tests/arcade_actor_projection_test.gd","inputs":storefront_inputs},
			"contracts":{"storefront":{"executed":storefront_loaded,"status":"PASS" if passed else "FAIL"}},
			"checks":checks,"failures":failures,"engine_errors":logger.errors}
		FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(contract,"\t"))
	print("ARCADE ACTOR RESULT: %d checks / %d failures" % [checks,failures.size()]);get_tree().quit(0 if failures.is_empty() else 1)
