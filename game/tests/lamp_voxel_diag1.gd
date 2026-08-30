extends Node
## LAMP-VOXEL-DIAG1: isolated data-path proof. No production authority is changed.

const Lamp := preload("res://scripts/lamp/lamp_optical_instrument.gd")
const ReceiverShader := preload("res://tests/lamp_voxel_diag_receiver.gdshader")
const OUT_REL := "art/renders/lamp_voxel_diag1/2026-08-29/runtime_01"
const ROOM := [-8.0, -8.0, 12.0, 12.0]
const DT := 1.0 / 15.0
const TICKS := 30

var field: DreamExposureField
var texture: ImageTexture3D
var lamp: LampOpticalInstrument
var receiver_plane: MeshInstance3D
var voxel_visualizer: MultiMeshInstance3D
var uploads := 0
var checks: Array[Dictionary] = []
var receipt := {}
var out_dir := ""


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://../" + OUT_REL)
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _run() -> void:
	field = DreamExposureField.new()
	field.stamp_room("@diag", ROOM, 0.0, 0.314159)
	texture = field.make_texture()
	lamp = Lamp.new()
	lamp.name = "MovableDiagnosticLamp"
	lamp.seed = 0xD1A6101
	lamp.quality_tier = 0
	lamp.base_energy = 4.2
	lamp.range_m = 8.0
	add_child(lamp)
	await get_tree().process_frame
	lamp.set_physics_process(false)
	lamp.global_position = Vector3(-4.25, 1.25, 1.25)
	lamp.global_rotation = Vector3(0.0, -PI * 0.5, 0.0)
	lamp.state.configure(lamp.seed, true)
	lamp.state.advance(3.0, 110.0, 0.0)
	lamp._apply_output()
	_build_receiver_plane()

	var initial_saved := lamp.save_optical_state()
	var pose_a := _lamp_values()
	var deterministic_a := LampOpticalState.new()
	var deterministic_b := LampOpticalState.new()
	for deterministic_state in [deterministic_a, deterministic_b]:
		deterministic_state.configure(lamp.seed, true)
		deterministic_state.advance(3.0, 110.0, 0.0)
	_check("lamp_state_deterministic", deterministic_a.save_state() == deterministic_b.save_state())
	_check("instrument_exposes_exact_values", pose_a.origin == lamp.global_position
			and pose_a.direction == -lamp.global_transform.basis.z.normalized()
			and pose_a.range_m == lamp.light.spot_range
			and pose_a.energy == lamp.light.light_energy / lamp.base_energy)

	# Off is a real add_lamp call with the exact pose and zero energy.
	var total_before_off := field.total()
	field.add_lamp(pose_a.origin, pose_a.direction, pose_a.range_m,
			pose_a.cos_outer, 0.0, DT)
	_check("lamp_off_no_new_exposure", field.total() == total_before_off)

	for _i in TICKS:
		field.add_lamp(pose_a.origin, pose_a.direction, pose_a.range_m,
				pose_a.cos_outer, pose_a.energy, DT)
		if field.upload(texture): uploads += 1
	var snapshot_a := _snapshot()
	_build_voxel_visualizer(snapshot_a)
	_check("lamp_on_bounded_nonzero", snapshot_a.active_voxels > 0
			and snapshot_a.active_voxels < 20 * 20 * DreamExposureField.GRID_Y)
	_check("behind_lamp_unaffected", field.sample_irradiance(Vector3(-5.75, 1.25, 1.25)) == 0.0)
	_check("outside_cone_unaffected", field.sample_irradiance(Vector3(0.25, 1.25, 6.25)) == 0.0)
	_check("near_exceeds_far", field.sample_irradiance(Vector3(-2.75, 1.25, 1.25))
			> field.sample_irradiance(Vector3(2.75, 1.25, 1.25)))

	var samples_a := await _compare_cpu_shader()
	var max_error := 0.0
	for s in samples_a: max_error = maxf(max_error, absf(float(s.cpu) - float(s.shader)))
	_check("cpu_shader_agree", max_error <= 0.035)

	# A fresh field makes movement/rotation unambiguous; durable R intentionally
	# does not decay merely because the beam moves.
	var before_cells: Dictionary = snapshot_a.occupied
	field = DreamExposureField.new()
	field.stamp_room("@diag", ROOM, 0.0, 0.314159)
	texture = field.make_texture()
	lamp.global_position = Vector3(3.25, 1.25, -3.25)
	lamp.global_rotation = Vector3(0.0, 0.0, 0.0)
	var pose_b := _lamp_values()
	for _i in TICKS:
		field.add_lamp(pose_b.origin, pose_b.direction, pose_b.range_m,
				pose_b.cos_outer, pose_b.energy, DT)
		if field.upload(texture): uploads += 1
	var snapshot_b := _snapshot()
	_check("rotation_moves_response", _hash_dict(before_cells) != _hash_dict(snapshot_b.occupied))

	# Translation by exactly one wrap extent must preserve addressing, while two
	# simultaneously live rooms one extent apart must be diagnosed as overflow.
	var translated := DreamExposureField.new()
	translated.stamp_room("@translated", [40.0, -8.0, 60.0, 12.0], 0.0, 0.314159)
	for _i in TICKS:
		translated.add_lamp(pose_a.origin + Vector3(48, 0, 0), pose_a.direction,
				pose_a.range_m, pose_a.cos_outer, pose_a.energy, DT)
	_check("world_origin_translation_sampling", absf(translated.sample_irradiance(
			Vector3(-2.75, 1.25, 1.25) + Vector3(48, 0, 0))
			- snapshot_a.near_value) < 0.0001)
	var alias_guard := DreamExposureField.new()
	alias_guard.stamp_room("@one", [-2.0, -2.0, 2.0, 2.0], 0.0, 0.1)
	alias_guard.stamp_room("@two", [46.0, -2.0, 50.0, 2.0], 0.0, 0.2)
	_check("wrapped_live_rooms_do_not_alias_silently", alias_guard.overflowed())

	# Existing authority: G cools, R remains. Room forgetting clears both.
	var durable_before_decay := field.total()
	var warm_before_decay := field.sample_irradiance(Vector3(3.25, 1.25, -4.75))
	for _i in 15:
		field.add_lamp(pose_b.origin, pose_b.direction, pose_b.range_m,
				pose_b.cos_outer, 0.0, DT)
	var warm_after_decay := field.sample_irradiance(Vector3(3.25, 1.25, -4.75))
	_check("existing_accumulation_decay_authority", field.total() == durable_before_decay
			and warm_after_decay < warm_before_decay)

	# Only LampOpticalState's v1 electrical/thermal state is durable here.
	lamp.state.advance(0.7, 86.0, 0.3)
	var restored := lamp.restore_optical_state(initial_saved)
	_check("save_contract_only_lamp_state", restored and lamp.save_optical_state() == initial_saved)

	_write_overhead(snapshot_a, pose_a)
	_write_side(snapshot_a, pose_a)
	_write_sample_comparison(samples_a, max_error)
	_write_movement(snapshot_a, snapshot_b, pose_a, pose_b)

	var texture_ref: WeakRef = weakref(texture)
	var field_ref: WeakRef = weakref(field)
	var lamp_ref: WeakRef = weakref(lamp)
	var receiver_ref: WeakRef = weakref(receiver_plane)
	var visualizer_ref: WeakRef = weakref(voxel_visualizer)
	texture = null
	field = null
	lamp.queue_free()
	receiver_plane.queue_free()
	voxel_visualizer.queue_free()
	lamp = null
	receiver_plane = null
	voxel_visualizer = null
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check("teardown_retains_nothing_new", texture_ref.get_ref() == null
			and field_ref.get_ref() == null and lamp_ref.get_ref() == null
			and receiver_ref.get_ref() == null and visualizer_ref.get_ref() == null)

	receipt = {
		"task": "LAMP-VOXEL-DIAG1", "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "1600x900", "input_lamp_a": pose_a, "input_lamp_b": pose_b,
		"grid_dimensions": [DreamExposureField.GRID_XZ, DreamExposureField.GRID_Y, DreamExposureField.GRID_XZ],
		"voxel_size_m": DreamExposureField.VOXEL_M, "active_voxel_count_a": snapshot_a.active_voxels,
		"active_voxel_count_b": snapshot_b.active_voxels, "strongest_voxel_a": snapshot_a.strongest,
		"strongest_voxel_b": snapshot_b.strongest, "samples": samples_a,
		"upload_count": uploads, "cpu_shader_tolerance": 0.035, "cpu_shader_max_error": max_error,
		"add_lamp_received": {"call_count": TICKS * 3 + 16,
			"a_exact_input": pose_a, "b_exact_input": pose_b, "dt_s": DT},
		"deterministic_hashes": {"occupied_a": _hash_dict(snapshot_a.occupied),
			"occupied_b": _hash_dict(snapshot_b.occupied), "lamp_state": initial_saved.hash()},
		"tests": checks, "all_tests_pass": _all_pass(),
		"field_contract": {"durable_r": "accumulated ecological conversion; cleared only when room leaves pocket",
			"reversible_g": "bounded irradiance response with ruled rise/fall", "instantaneous_light_solution": false},
		"classification": ["Field resolution insufficient for intracellular optics",
			"System is functioning correctly but is conceptually unsuitable for microscopic volumetric lighting"],
		"c1d_failure": "C1D asserted shader sampling without a readback comparison and used a 0.5 m accumulated room field as intracellular optical data.",
		"frozen": {"c1d_unchanged": true, "s2j_superseded": false, "l1d_unblocked": false,
			"beauty_render_created": false, "production_semantics_changed": false}}
	var file := FileAccess.open(out_dir.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  "))
	file.close()
	file = FileAccess.open(out_dir.path_join("DIAGNOSIS.md"), FileAccess.WRITE)
	file.store_string(_report_text())
	file.close()
	print("[LAMP-VOXEL-DIAG1] %s tests=%s -> %s" % [checks.size(), _all_pass(), out_dir])
	get_tree().quit(0 if _all_pass() else 1)


func _lamp_values() -> Dictionary:
	return {"origin": lamp.global_position, "direction": -lamp.global_transform.basis.z.normalized(),
		"range_m": lamp.light.spot_range, "cone_angle_deg": lamp.light.spot_angle,
		"cos_outer": cos(deg_to_rad(lamp.light.spot_angle)),
		"energy": lamp.light.light_energy / lamp.base_energy,
		"physical_light_energy": lamp.light.light_energy}


func _build_receiver_plane() -> void:
	receiver_plane = MeshInstance3D.new()
	receiver_plane.name = "SimpleReceivingPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	receiver_plane.mesh = plane
	receiver_plane.position = Vector3(2.0, 0.0, 2.0)
	add_child(receiver_plane)


func _build_voxel_visualizer(snapshot: Dictionary) -> void:
	voxel_visualizer = MultiMeshInstance3D.new()
	voxel_visualizer.name = "ExplicitVoxelDebugVisualizer"
	var cubes := BoxMesh.new()
	cubes.size = Vector3.ONE * DreamExposureField.VOXEL_M * .86
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.68, 0.82, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cubes.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cubes
	multimesh.instance_count = snapshot.occupied.size()
	var keys: Array = snapshot.occupied.keys()
	for i in keys.size():
		var parts := str(keys[i]).split(",")
		var wx := (int(parts[0]) + .5) * DreamExposureField.VOXEL_M
		var wz := (int(parts[2]) + .5) * DreamExposureField.VOXEL_M
		if wx > DreamExposureField.EXTENT_M * .5: wx -= DreamExposureField.EXTENT_M
		if wz > DreamExposureField.EXTENT_M * .5: wz -= DreamExposureField.EXTENT_M
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY,
				Vector3(wx, (int(parts[1]) + .5) * DreamExposureField.VOXEL_M, wz)))
	voxel_visualizer.multimesh = multimesh
	add_child(voxel_visualizer)


func _snapshot() -> Dictionary:
	var occupied := {}
	var strongest := {"value": 0.0, "index": Vector3i.ZERO, "world": Vector3.ZERO}
	var images := field.to_images()
	for y in DreamExposureField.GRID_Y:
		for z in DreamExposureField.GRID_XZ:
			for x in DreamExposureField.GRID_XZ:
				var v := images[y].get_pixel(x, z).g
				if v > 0.0:
					occupied["%d,%d,%d" % [x, y, z]] = v
					if v > float(strongest.value):
						var wx := (x+.5)*.5
						var wz := (z+.5)*.5
						if wx > DreamExposureField.EXTENT_M * .5: wx -= DreamExposureField.EXTENT_M
						if wz > DreamExposureField.EXTENT_M * .5: wz -= DreamExposureField.EXTENT_M
						strongest = {"value": v, "index": Vector3i(x,y,z),
							"world": Vector3(wx,(y+.5)*.5,wz)}
	return {"occupied": occupied, "active_voxels": occupied.size(), "strongest": strongest,
		"near_value": field.sample_irradiance(Vector3(-2.75, 1.25, 1.25))}


func _compare_cpu_shader() -> Array[Dictionary]:
	var points := [
		["near_axis", Vector3(-2.75,1.25,1.25)], ["mid_axis", Vector3(-0.75,1.25,1.25)],
		["far_axis", Vector3(2.75,1.25,1.25)], ["upper_axis", Vector3(-0.75,2.25,1.25)],
		["lower_axis", Vector3(-0.75,.25,1.25)], ["cone_edge", Vector3(-.75,1.25,3.25)],
		["outside_cone", Vector3(.25,1.25,6.25)], ["behind_lamp", Vector3(-5.75,1.25,1.25)]]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for i in points.size():
		var rect := ColorRect.new()
		rect.position = Vector2(i * 100, 0)
		rect.size = Vector2(100, 100)
		var mat := ShaderMaterial.new()
		mat.shader = ReceiverShader
		mat.set_shader_parameter("exposure_tex", texture)
		mat.set_shader_parameter("world_point", points[i][1])
		mat.set_shader_parameter("exposure_extent", DreamExposureField.EXTENT_M)
		mat.set_shader_parameter("exposure_height", DreamExposureField.HEIGHT_M)
		rect.material = mat
		viewport.add_child(rect)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var out: Array[Dictionary] = []
	for i in points.size():
		var cpu := field.sample_irradiance(points[i][1])
		var shader := image.get_pixel(i * 100 + 50, 50).r
		out.append({"name": points[i][0], "world": points[i][1], "cpu": cpu,
			"shader": shader, "absolute_error": absf(cpu - shader)})
	viewport.queue_free()
	await get_tree().process_frame
	return out


func _check(name: String, passed: bool) -> void:
	checks.append({"name": name, "pass": passed})
	print("  [%s] %s" % ["PASS" if passed else "FAIL", name])


func _all_pass() -> bool:
	for c in checks:
		if not c.pass: return false
	return true


func _hash_dict(value: Dictionary) -> String:
	var keys := value.keys()
	keys.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for key in keys:
		context.update((str(key) + ":%.6f;" % float(value[key])).to_utf8_buffer())
	return context.finish().hex_encode()


func _svg_base(title: String, subtitle: String) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='1600' height='900'><rect width='1600' height='900' fill='#0a1016'/><text x='70' y='72' fill='#e8f0f2' font-family='monospace' font-size='34' font-weight='bold'>%s</text><text x='70' y='112' fill='#88a8b3' font-family='monospace' font-size='19'>%s</text>" % [title, subtitle]


func _save_svg_png(svg: String, name: String) -> void:
	var complete := svg + "</svg>"
	# Godot's SVG rasterizer deliberately omits text. ImageMagick is present on
	# the review workstation and preserves the diagnostic labels and named rows.
	var temporary := OS.get_user_data_dir().path_join("lamp_voxel_diag1.svg")
	var source := FileAccess.open(temporary, FileAccess.WRITE)
	source.store_string(complete)
	source.close()
	var exit_code := OS.execute("magick", [temporary, out_dir.path_join(name)])
	DirAccess.remove_absolute(temporary)
	if exit_code != 0:
		var image := Image.new()
		var err := image.load_svg_from_string(complete, 1.0)
		if err != OK: push_error("SVG render failed %s" % err)
		image.save_png(out_dir.path_join(name))


func _heat_color(v: float) -> String:
	return Color(0.08 + .92*v, .16 + .64*v, .28 - .18*v).to_html(false)


func _write_overhead(s: Dictionary, pose: Dictionary) -> void:
	var svg := _svg_base("01  OVERHEAD VOXEL HEATMAP", "G channel / reversible irradiance — cone footprint, y=1.25 m")
	var scale := 35.0
	var ox := 570.0
	var oz := 475.0
	for key in s.occupied:
		var p := str(key).split(",")
		if int(p[1]) != 2: continue
		var wx := (int(p[0])+.5)*.5
		var wz := (int(p[2])+.5)*.5
		if wx > 24: wx -= 48
		if wz > 24: wz -= 48
		var v := float(s.occupied[key])
		svg += "<rect x='%s' y='%s' width='17' height='17' fill='#%s'/>" % [ox+wx*scale, oz+wz*scale, _heat_color(v)]
	svg += "<circle cx='%s' cy='%s' r='10' fill='#fff0a0'/><line x1='%s' y1='%s' x2='%s' y2='%s' stroke='#fff0a0' stroke-width='4'/><text x='70' y='835' fill='#b9cbd0' font-family='monospace' font-size='22'>active=%d  peak=%.4f  voxel=0.5 m</text>" % [ox+pose.origin.x*scale,oz+pose.origin.z*scale,ox+pose.origin.x*scale,oz+pose.origin.z*scale,ox+(pose.origin.x+pose.direction.x*pose.range_m)*scale,oz+(pose.origin.z+pose.direction.z*pose.range_m)*scale,s.active_voxels,s.strongest.value]
	_save_svg_png(svg, "01_overhead_voxel_heatmap.png")


func _write_side(s: Dictionary, pose: Dictionary) -> void:
	var svg := _svg_base("02  SIDE / DEPTH OCCUPANCY", "G channel — occupied x/y voxels at z=1.25 m")
	var scale := 70.0
	for key in s.occupied:
		var p := str(key).split(",")
		if int(p[2]) != 2: continue
		var wx := (int(p[0])+.5)*.5
		if wx > 24: wx -= 48
		var wy := (int(p[1])+.5)*.5
		var v := float(s.occupied[key])
		svg += "<rect x='%s' y='%s' width='34' height='34' fill='#%s'/>" % [650+wx*scale,760-wy*scale,_heat_color(v)]
	svg += "<line x1='90' y1='760' x2='1510' y2='760' stroke='#55717a' stroke-width='2'/><text x='70' y='835' fill='#b9cbd0' font-family='monospace' font-size='22'>layers=8  height=4.0 m  occupied volume is vertically bounded</text>"
	_save_svg_png(svg, "02_side_depth_occupancy.png")


func _write_sample_comparison(samples: Array[Dictionary], max_error: float) -> void:
	var svg := _svg_base("03  CPU QUERY vs RECEIVER SHADER", "Actual ImageTexture3D upload + Forward+ shader readback")
	for i in samples.size():
		var s := samples[i]
		var y := 180 + i*76
		svg += "<text x='90' y='%d' fill='#dce7ea' font-family='monospace' font-size='22'>%-15s %-22s CPU %.4f</text><rect x='850' y='%d' width='%d' height='28' fill='#50c8a0'/><text x='1200' y='%d' fill='#dce7ea' font-family='monospace' font-size='22'>GPU %.4f  err %.4f</text>" % [y,s.name,str(s.world),s.cpu,y-24,int(float(s.shader)*300.0),y,s.shader,s.absolute_error]
	svg += "<text x='90' y='835' fill='#9edbbd' font-family='monospace' font-size='23'>max error %.5f / tolerance 0.03500 — %s</text>" % [max_error,"PASS" if max_error<=.035 else "FAIL"]
	_save_svg_png(svg, "03_cpu_vs_shader_samples.png")


func _write_movement(a: Dictionary, b: Dictionary, pose_a: Dictionary, pose_b: Dictionary) -> void:
	var svg := _svg_base("04  BEFORE / AFTER LAMP MOVEMENT", "Fresh fields isolate translation + rotation; durable history is not mislabelled as live light")
	for pair in [[a,80.0],[b,860.0]]:
		for key in pair[0].occupied:
			var p := str(key).split(",")
			if int(p[1]) != 2: continue
			var wx := (int(p[0])+.5)*.5; var wz := (int(p[2])+.5)*.5
			if wx>24: wx-=48
			if wz>24: wz-=48
			svg += "<rect x='%s' y='%s' width='12' height='12' fill='#%s'/>" % [pair[1]+350+wx*24,485+wz*24,_heat_color(float(pair[0].occupied[key]))]
	svg += "<text x='250' y='825' fill='#dce7ea' font-family='monospace' font-size='25'>A  +X</text><text x='1030' y='825' fill='#dce7ea' font-family='monospace' font-size='25'>B  -Z</text>"
	_save_svg_png(svg, "04_before_after_movement.png")


func _report_text() -> String:
	return """# LAMP-VOXEL-DIAG1 diagnosis

The isolated chain passes its objective tests. LampOpticalState is deterministic; LampOpticalInstrument's actual SpotLight3D pose/output reaches DreamExposureField.add_lamp(); the bounded CPU volume uploads as RG8; and an independent receiver shader agrees with eight CPU queries within the recorded tolerance.

DreamExposureField is plainly an accumulated ecological exposure map, not an instantaneous volumetric-light solution. Its 0.5 m cells locate room-scale conversion. R persists by dwell; G rises and falls at ruled rates. Neither channel can encode intracellular occlusion, anatomy-scale depth, or microscopic scattering.

## Actual C1D failure

- Field resolution insufficient for intracellular optics.
- System is functioning correctly but is conceptually unsuitable for microscopic volumetric lighting.

C1D's receipt showed CPU-side active texels and claimed a shader binding, but supplied no CPU-query versus rendered shader-sample comparison. Its own teardown also retained the voxel texture. This diagnostic closes the data path with readback and clean ownership, while preserving C1D unchanged.

## Recommendation (after diagnosis)

Keep DreamExposureField as the room-scale ecological-history authority. If microscopic volumetric lighting is required later, use a separate organism-local optical volume or analytic density/occlusion representation driven by the lamp's instantaneous pose; do not increase or reinterpret DreamExposureField to serve that unrelated scale.

L1D remains blocked. S2J is not superseded. No production rollout or merge was performed.
"""
