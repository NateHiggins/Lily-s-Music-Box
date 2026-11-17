extends Node3D
## Nearby receiving-geometry diagnostic, not installed services/actor/save proof.
const Carrier := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Assembly := preload("res://scripts/building/orison_v2_arcade_prepared_geometry.gd")
const Fabric := preload("res://scripts/building/orison_v2_arcade_fabric.gd")
const Door := preload("res://scripts/building/orison_v2_arcade_shop_door.gd")
const NATIVE_INPUT := "res://tests/fixtures/arcade_all_native_projection.json"
const RAW_INPUT := "res://tests/fixtures/arcade_all_raw_projection.json"
const FRAMES_INPUT := "res://tests/fixtures/arcade_door_frames.json"
const SHELL_INPUT := "res://tests/fixtures/arcade_plaza_shells_contract.json"
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var donors: Array[Node3D] = []
var doors: Array[DoorProp] = []
var prepared: Node3D
var logger = preload("res://tests/guide_bell_error_capture.gd").new()

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok: failures.append(message);print("ARCADE DOOR FIT FAIL: ",message)
	return ok

func _ready() -> void: run.call_deferred()

func _inputs() -> Dictionary:
	var data := {}
	for path: String in [NATIVE_INPUT, RAW_INPUT, FRAMES_INPUT, SHELL_INPUT,
		Shell.DATA, Shell.STOREFRONT_DATA, Assembly.Public.DATA, Assembly.Public.CLOCK,
		Assembly.Threshold.DATA, Assembly.Cobbler.DATA, "res://data/building_layout.json",
		get_script().resource_path, "res://tests/ArcadeDoorFitTest.tscn",
		"res://scripts/building/orison_v2_arcade_prepared_geometry.gd", "res://scripts/building/orison_v2_arcade_fabric.gd",
		"res://scripts/building/orison_v2_arcade_native_carrier.gd", "res://scripts/building/orison_v2_arcade_plaza_shell.gd",
		"res://scripts/building/orison_v2_arcade_shop_door.gd", "res://scripts/building/orison_v2_arcade_public_fittings.gd",
		"res://scripts/building/orison_v2_arcade_entry_threshold.gd", "res://scripts/building/orison_v2_arcade_cobbler_field.gd",
		"res://scripts/building/orison_v2_shop_millwork.gd", "res://scripts/building/orison_v2_owner_finishes.gd",
		"res://scripts/props/door_prop.gd", "res://data/orison_v2/arcade_door_leaves.json",
		"res://assets/building/orison_v2/passage/passage.gltf"]:
		data[path] = FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	for asset: String in [Assembly.Threshold.ASSET, "res://assets/props/arcade_plaza_shells.glb",
		"res://assets/props/arcade_storefront_identity.glb", "res://assets/props/arcade_public_fittings.glb",
		"res://assets/props/arcade_clock.glb", "res://assets/props/arcade_cobbler_field.glb",
		"res://assets/props/arcade_door_leaves.glb", "res://assets/props/arcade_darkroom_curtain.glb"]:
		data[asset] = FileAccess.get_sha256(asset)
		data[asset+".import"] = FileAccess.get_file_as_string(asset+".import").replace("\r\n","\n").sha256_text()
	for path: String in [NATIVE_INPUT, RAW_INPUT]:
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for cell: Dictionary in contract.cells:
			for resource: String in cell.source_bindings:
				var binding: Dictionary = cell.source_bindings[resource]
				data[resource] = FileAccess.get_sha256(resource) if binding.kind == "raw" else FileAccess.get_file_as_string(resource).replace("\r\n","\n").sha256_text()
	return data

func _cell(spec: Dictionary, raw: Dictionary, layout: Dictionary, atlas: RefCounted) -> bool:
	var cell := (load(str(spec.cell_source)) as PackedScene).instantiate() as Node3D
	cell.name=str(spec.cell);donors.append(cell)
	for mount: Dictionary in spec.mounts:
		var arguments: Array = []
		for name: String in mount.arguments:
			match name:
				"cell":arguments.append(cell)
				"original_layout":arguments.append(layout)
				"portrait_atlas_cache":arguments.append(atlas)
		if not check(bool((load(str(mount.wrapper)) as GDScript).callv(str(mount.method),arguments)),"actual fitting owner "+str(spec.cell)+"/"+str(mount.family)):return false
	var helper := Assembly.new()
	if not check(helper.admit_shop(prepared,cell,spec,raw),"actual fitted shop admission " + str(spec.cell) + str(helper.errors)):
		return false
	check(not helper.admit_shop(prepared,cell,spec,raw), "duplicate shop admission refused " + str(spec.cell))
	return true

func _millwork_collision() -> void:
	# Include the rendered millwork in the nearby leaf sweep. Its original
	# visuals stay passive in the detachable production geometry.
	var faces := PackedVector3Array()
	var helper := Carrier.new()
	for batch: MultiMeshInstance3D in prepared.find_children("*","MultiMeshInstance3D",true,false):
		var local: Transform3D = helper._relative(batch,prepared)
		var native_faces := batch.multimesh.mesh.get_faces()
		for index in batch.multimesh.instance_count:
			var pose := local*batch.multimesh.get_instance_transform(index)
			for vertex: Vector3 in native_faces:
				faces.append(pose*vertex)
	var body := StaticBody3D.new()
	body.name = "TEST_ONLY_MillworkTriangles"
	var shape := CollisionShape3D.new()
	var mesh := ConcavePolygonShape3D.new()
	mesh.backface_collision = true
	mesh.set_faces(faces)
	shape.shape = mesh
	body.add_child(shape)
	prepared.add_child(body)
	check(not faces.is_empty(),"all rendered millwork triangles included in fit query")
	observations.append({"kind":"test_only_millwork_collision","triangles":faces.size()/3})

func _sweep(door: DoorProp) -> void:
	var excluded: Array[RID] = []
	for leaf: Dictionary in door.motion_leaves():excluded.append(leaf.body.get_rid())
	for leaf: Dictionary in door.motion_leaves():
		var body: AnimatableBody3D=leaf.body
		var target:=door.motion_target_angle(true)*float(leaf.ratio)
		var steps:=ceili(absf(target)/deg_to_rad(.1))
		observations.append({"kind":"sweep_sampling","door":str(door.name),"leaf_ratio":leaf.ratio,"angular_steps":steps,"maximum_step_degrees":.1})
		# This encloses each half-step rotational chord at the actual outer
		# collider radius; a plain set of samples would miss thin obstacles.
		var margin:=.001+2.0*(float(leaf.width)+.15)*sin(absf(target)/steps*.25)
		for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",false,false):
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=shape.shape;query.collision_mask=1;query.exclude=excluded;query.margin=margin
			var blocked:=false
			for step in range(steps+1):
				var pose:=body.transform
				pose.basis=Basis(Vector3.UP,target*float(step)/steps)
				query.transform=door.global_transform*pose*shape.transform
				var hits:=get_world_3d().direct_space_state.intersect_shape(query,16)
				if not hits.is_empty():
					var witnesses: Array = []
					for hit: Dictionary in hits:
						var collider:=hit.collider as Node
						var draw:=collider.get_parent() if collider!=null else null
						witnesses.append({"path":str(collider.get_path()) if collider!=null else "", "part":str(draw.get_meta("arcade_native_identity",draw.name)) if draw!=null else ""})
					observations.append({"door":str(door.name),"shape":str(shape.name),"angle_degrees":rad_to_deg(target*float(step)/steps),"margin_m":margin,"hits":witnesses})
					blocked=true;break
			check(not blocked,"full real-frame/apparatus sweep "+str(door.name)+"/"+str(shape.name))

func _views() -> void:
	var output:=OS.get_environment("SHOT_DIR")
	if output.is_empty():return
	DirAccess.make_dir_recursive_absolute(output)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.18,.22)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-40,0);add_child(light)
	var camera:=Camera3D.new();camera.fov=60;add_child(camera)
	var door:DoorProp=doors[0]
	for opened: bool in [false,true]:
		for item:DoorProp in doors:item.restore_mechanism({"angle":item.motion_target_angle(opened)})
		await get_tree().physics_frame;await get_tree().physics_frame
		camera.look_at_from_position(door.to_global(Vector3(1,1.7,3.5)),door.to_global(Vector3(1,1.15,0)));camera.make_current()
		for frame in 6:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join("fitted_open.png" if opened else "fitted_closed.png"))==OK,"actual fitted pair capture "+str(opened))
	camera.look_at_from_position(prepared.to_global(Vector3(20,2.2,61.2)),prepared.to_global(Vector3(22.5,.65,63.2)))
	for frame in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("diner_stools.png"))==OK,"three whole stools fitted to new paired-leaf sweep")

func run() -> void:
	var started := Time.get_ticks_msec()
	var inputs := _inputs()
	OS.add_logger(logger)
	var original: Dictionary=RealityState.data;var original_text:=JSON.stringify(original,"",true,true);var mouse:=Input.mouse_mode
	var preview:=RealityState.begin_preview_campaign(self)
	if not check(preview,"isolated campaign"):get_tree().quit(1);return
	var frames:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FRAMES_INPUT))
	var native:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_INPUT))
	var raws:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RAW_INPUT))
	var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var atlas:=preload("res://scripts/building/orison_v2_photo_portraits.gd").AtlasCache.new()
	var assembly := Assembly.new()
	var shell_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHELL_INPUT))
	prepared = assembly.prepare(shell_contract,frames.frames)
	var ready := check(prepared != null,"detached shell, trim, threshold and hatches admit " + str(assembly.errors))
	if ready:
		check(prepared.get_parent() == null and prepared.get_child_count() == 12,"one detached owner per shop and passage")
		for cell: Dictionary in native.cells:
			var candidates: Array = raws.cells.filter(func(row: Dictionary) -> bool: return row.cell == cell.cell)
			if not _cell(cell,candidates[0],layout,atlas):
				ready = false
				break
	if ready:
		var donor := (load("res://assets/building/orison_v2/passage/passage.gltf") as PackedScene).instantiate() as Node3D
		donor.name = "passage"
		donors.append(donor)
		ready = check(Fabric.mount_clock(donor,layout),"original clock mounted under its original fitting owner")
		if ready:
			var movement := donor.get_node("ArcadeClock/ClockMovement")
			ready = check(assembly.admit_clock(prepared,donor),"whole clock transferred to prepared passage " + str(assembly.errors))
			if ready:
				check(prepared.get_node("passage/ArcadePublicClock/ArcadeClock/ClockMovement") == movement,"same clock movement remains")
				check(not assembly.admit_clock(prepared,donor),"duplicate clock admission refused")
		_millwork_collision()
	if ready:
		for row:Dictionary in frames.frames:
			var door:=Door.from_frame(row)
			door.leaf_state="closed";prepared.add_child(door);doors.append(door)
		prepared.position.z=float(frames.external_vantry_root_z);add_child(prepared)
		await get_tree().physics_frame;await get_tree().physics_frame
		for cell: Node3D in prepared.get_children(): preload("res://scripts/building/orison_v2_owner_finishes.gd").apply_shop_wear(cell)
		check(doors.size()==22,"eleven actual front pairs and eleven stock singles")
		for door:DoorProp in doors:_sweep(door)
		# A real added obstruction must be found by the same physical query.
		var control:=StaticBody3D.new();control.name="DeliberateLeafObstruction";add_child(control)
		control.global_position=doors[0].to_global(Vector3(.4,1,-.4))
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.15,.4,.15);shape.shape=box;control.add_child(shape)
		await get_tree().physics_frame;await get_tree().physics_frame
		var body:AnimatableBody3D=doors[0]._body
		var collision:=body.find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D
		var pose:=body.transform;pose.basis=Basis(Vector3.UP,PI*.25)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=collision.shape;query.transform=doors[0].global_transform*pose*collision.transform;query.collision_mask=1
		var hits:=get_world_3d().direct_space_state.intersect_shape(query,32)
		check(hits.any(func(hit:Dictionary)->bool:return hit.collider==control),"real static obstruction positive control")
		control.free()
		await _views()
	if prepared != null:
		if prepared.get_parent()==null:prepared.free()
		else:prepared.queue_free();await get_tree().process_frame
	for donor:Node3D in donors:donor.free()
	check(RealityState.end_preview_campaign(self) and is_same(original,RealityState.data) and JSON.stringify(original,"",true,true)==original_text,"exact campaign restored")
	Input.mouse_mode=mouse
	for frame in 3:await get_tree().process_frame
	check(_inputs() == inputs,"composed door fit inputs remained frozen")
	check(logger.errors.is_empty(),"no engine/teardown errors "+str(logger.errors));OS.remove_logger(logger)
	var output:=OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual retained native/raw apparatus and new shell22door static swept-box fit only; no installed actor/route/service/save/human/art qualification","checks":checks,"failures":failures,"engine_errors":logger.errors,"observations":observations},"\t"))
		var contract := {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":false,"selector":"v2",
			"scope":"Nearby detached prepared arcade assembly and static sweeps of all 22 operating door frames.",
			"execution":{"completed":true,"exit_code":int(not failures.is_empty()),"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
			"source":{"test_path":"game/tests/arcade_door_fit_test.gd","inputs":inputs},
			"contracts":{"prepared_geometry_fit":{"executed":ready,"status":"PASS" if failures.is_empty() else "FAIL"}},
			"checks":checks,"failures":failures,"engine_errors":logger.errors}
		FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(contract,"\t"))
	print("ARCADE DOOR FIT RESULT: %d checks / %d failures"%[checks,failures.size()]);get_tree().quit(0 if failures.is_empty() else 1)
