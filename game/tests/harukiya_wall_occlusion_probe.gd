extends Node3D
const Pilot := preload("res://scripts/building/orison_v2_bar_occlusion.gd")
var failures: Array[String] = []
var checks := 0
var logger := preload("res://tests/guide_bell_error_capture.gd").new()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _ready() -> void: run.call_deferred()
func check_pilot(pilot: Node3D) -> bool:
	check(is_instance_valid(pilot),"installed production wall owner")
	if not is_instance_valid(pilot): return false
	check(pilot.enabled and pilot.errors.is_empty(),"production wall owner enabled without admission errors")
	return pilot.enabled and pilot.errors.is_empty()
func run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	OS.add_logger(logger)
	var bar := OrisonV2BarRegion.new(); add_child(bar)
	check(not bar.startup_failed,"actual final mounted bar")
	var pilot: Node3D = bar.wall_occlusion
	if not check_pilot(pilot):
		bar.shutdown();bar.free();RealityState.end_preview_campaign(self);OS.remove_logger(logger);get_tree().quit(1);return
	pilot.set_enabled(false)
	for row: Dictionary in pilot.sources:
		var draw: MeshInstance3D = row.draw
		var proxy: OccluderInstance3D = row.proxy
		var array := proxy.occluder as ArrayOccluder3D
		var expected_indices := PackedInt32Array()
		for index in draw.mesh.get_faces().size(): expected_indices.append(index)
		check(array.get_indices() == expected_indices,"exact triangle index stream "+str(draw.name))
		check(array.get_vertices() == draw.mesh.get_faces(),"exact rendered triangles preserve openings "+str(draw.name))
		check(proxy.global_transform == draw.global_transform,"exact mounted frame "+str(draw.name))
		check(not proxy.visible and draw.ignore_occlusion_culling == row.previous_ignore,"baseline unchanged "+str(draw.name))
	pilot.set_enabled(true)
	for row: Dictionary in pilot.sources:
		check(row.proxy.visible and row.draw.ignore_occlusion_culling,"only source walls exempt self-occlusion")
	var glass := MeshInstance3D.new()
	if not pilot.sources.is_empty(): glass.mesh = pilot.sources[0].draw.mesh
	var opaque := StandardMaterial3D.new(); glass.material_override = opaque
	check(Pilot._admit(glass),"valid actual ArrayMesh opaque material control")
	var transparent := StandardMaterial3D.new(); transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = transparent
	check(not Pilot._admit(glass),"transparent source negative")
	var cutout := ShaderMaterial.new(); cutout.shader = load("res://shaders/orison_surface_cutout.gdshader")
	glass.material_override = cutout
	check(not Pilot._admit(glass),"actual cutout shader negative")
	glass.material_override = opaque; opaque.proximity_fade_enabled = true
	check(not Pilot._admit(glass),"proximity fade cannot be structural occluder")
	opaque.proximity_fade_enabled = false; opaque.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER
	check(not Pilot._admit(glass),"distance dither cannot be structural occluder")
	glass.free()
	for frame in 3: await get_tree().physics_frame
	var ray_hits: Array = []
	var eye := Vector3(0.199391,1.41083,24.63183)
	for direction: Vector3 in [Vector3(-.008327,0,-.999965),Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(eye,eye+direction*20.0,1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var owner: Node = hit.collider
			var paths: Array = []
			for depth in 4:
				if owner == null: break
				paths.append(str(owner.get_path())); owner = owner.get_parent()
			ray_hits.append({"eye":eye,"direction":direction,"position":hit.position,"owners":paths})
	var records: Array = pilot.records.duplicate(true)
	if not pilot.sources.is_empty():
		var source: MeshInstance3D = pilot.sources[0].draw
		source.hide()
		check(not pilot.enabled,"source visibility change disables stale occluders immediately")
		source.show(); pilot.set_enabled(true)
		check(not pilot.enabled,"invalidated occluders require rebuild, never unsafe automatic reuse")
	check(pilot.shutdown(),"source flags restored and owned proxies removed")
	check(pilot.shutdown(),"repeated production shutdown idempotent")
	bar.shutdown(); bar.free()
	check(RealityState.end_preview_campaign(self),"preview campaign restored")
	check(logger.errors.is_empty(),"no captured engine/script errors")
	OS.remove_logger(logger)
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify({"evidence_class":"INERT loaded exact-triangle diagnostic; not appearance or gameplay qualification","checks":checks,"failures":failures,"records":records,"nearby_gallery_ray_hits":ray_hits,"engine_errors":logger.errors},"\t"));file.flush()
	print("HARUKIYA WALL OCCLUSION PROBE: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() and file.get_error()==OK else 1)
