extends Node3D
## NPC repair pilot (order w3473eaaf58a9): Mina's rebuilt body moved the way the V2 resident route moves her
## (horizontal speed `route_speed`, height snapped to the tread under her) on the flat and on a stair of the house's
## own dimensions (rise 0.16, tread 0.285). Every frame a dot marks her lower toe: clean steps leave tight clusters,
## a sliding foot leaves a smear. Side view, orthographic, 0.1 m grid. Windowed capture only.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")
const RISE := 0.16
const TREAD := 0.285
const RISERS := 10
const STAIR_X := 3.0

var directory := ""
var route_speed := 1.05
var mina: Presentation
var dots: MultiMeshInstance3D
var dot_count := 0
var camera: Camera3D
## BEFORE=1 reproduces main before the pilot: no distance matching, level pace on the stairs.
var before := false
## RESIDENT=<id> stages another resident (the second pilot, a male-base body on the generic path).
var resident := "mina_vale"
var report := {}


func _ready() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Mina pilot shot requires windowed capture and SHOT_DIR")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	before = OS.get_environment("BEFORE") == "1"
	var speed := OS.get_environment("ROUTE_SPEED")
	if not speed.is_empty():
		route_speed = float(speed)
	var who := OS.get_environment("RESIDENT")
	if not who.is_empty():
		resident = who
	run.call_deferred()


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	box.material = mat
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _floor_at(x: float) -> float:
	# The flat, then RISERS risers going up from STAIR_X, then a landing.
	if x < STAIR_X:
		return 0.0
	return minf(floor((x - STAIR_X) / TREAD) + 1.0, RISERS) * RISE


func _set_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.93, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	add_child(sun)
	_box(Vector3(STAIR_X + 10.0, 0.02, 1.4), Vector3(STAIR_X * 0.5 - 5.0, -0.01, -0.3), Color(0.55, 0.55, 0.52))
	for i in RISERS:
		var top := (i + 1) * RISE
		_box(Vector3(TREAD, top, 1.4), Vector3(STAIR_X + (i + 0.5) * TREAD, top * 0.5, -0.3), Color(0.6, 0.56, 0.5))
	_box(Vector3(2.0, RISERS * RISE, 1.4), Vector3(STAIR_X + RISERS * TREAD + 1.0, RISERS * RISE * 0.5, -0.3), Color(0.6, 0.56, 0.5))
	# 0.1 m grid behind her.
	for i in range(-90, 120):
		var x := i * 0.1
		_box(Vector3(0.004 if i % 5 else 0.01, 3.4, 0.002), Vector3(x, 1.5, -1.05), Color(0.6, 0.6, 0.6))
	for j in range(0, 34):
		_box(Vector3(22.0, 0.004 if j % 5 else 0.01, 0.002), Vector3(1.0, j * 0.1, -1.05), Color(0.6, 0.6, 0.6))
	dots = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 6000
	mm.visible_instance_count = 0
	var sphere := SphereMesh.new()
	sphere.radius = 0.008
	sphere.height = 0.016
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.vertex_color_use_as_albedo = true
	dmat.no_depth_test = true
	sphere.material = dmat
	mm.mesh = sphere
	dots.multimesh = mm
	add_child(dots)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	add_child(camera)
	camera.make_current()


func _dot(at: Vector3, colour: Color) -> void:
	if dot_count >= dots.multimesh.instance_count:
		return
	dots.multimesh.set_instance_transform(dot_count, Transform3D(Basis(), at + Vector3(0, 0, 0.6)))
	dots.multimesh.set_instance_color(dot_count, colour)
	dot_count += 1
	dots.multimesh.visible_instance_count = dot_count


func _clear_dots() -> void:
	dot_count = 0
	dots.multimesh.visible_instance_count = 0


func _walk(label: String, from_x: float, to_x: float, direction: float) -> void:
	_clear_dots()
	var skeleton: Skeleton3D = mina.cast_body.skeleton
	var toes := [skeleton.find_bone("LeftToeBase"), skeleton.find_bone("RightToeBase")]
	var heels := [skeleton.find_bone("LeftFoot"), skeleton.find_bone("RightFoot")]
	var last_points: Array[Vector3] = []
	var steady: Array[float] = []
	mina.global_position = Vector3(from_x, _floor_at(from_x), 0)
	mina.global_rotation.y = PI * 0.5 * direction
	var shots := 0
	var next_shot := 1.2
	var elapsed := 0.0
	var x := from_x
	var slips: Array[float] = []
	var last_left := Vector3.INF
	var last_right := Vector3.INF
	while (to_x - x) * direction > 0.0 and shots < 6:
		var delta := get_process_delta_time()
		elapsed += delta
		var on_stair := x > STAIR_X and x < STAIR_X + RISERS * TREAD
		var pace := route_speed if before or not on_stair else minf(route_speed, Route.STAIR_PACE)
		x += direction * pace * delta
		# The game's stairs walk on a ramp collider: height follows the pitch line, not the treads.
		var y := clampf((x - STAIR_X) / TREAD * RISE, 0.0, RISERS * RISE)
		mina.global_position = Vector3(x, y, 0)
		# The route passes the authored edge slope, not the tread sample.
		var edge := RISE / TREAD if on_stair else 0.0
		mina.set_route_motion(true, edge * direction, pace)
		var attention: Node = mina.cast_body.get("attention")
		if attention != null:
			attention.staged_target = Vector3(x + direction * 3.0, y + 1.5, 0)
		await get_tree().process_frame
		var world: Transform3D = skeleton.global_transform
		var left := world * skeleton.get_bone_global_pose(toes[0]).origin
		var right := world * skeleton.get_bone_global_pose(toes[1]).origin
		# The planted foot is the one moving least along the way she travels; its world speed is the slip.
		if last_left.is_finite() and delta > 0.0:
			var vl := (left - last_left) / delta
			var vr := (right - last_right) / delta
			var planted := vl if vl.x * direction < vr.x * direction else vr
			slips.append(Vector2(planted.x, planted.z).length())
			var foot := left if vl.x * direction < vr.x * direction else right
			_dot(foot, Color(0.9, 0.1, 0.1) if foot == left else Color(0.1, 0.2, 0.9))
		last_left = left
		last_right = right
		# Contact slip: the stillest of the four foot points (heels and toes) is the one on the floor; heel-to-toe
		# roll moves the others. After the first 3.8 s (the walk start) the walk is steady.
		var points: Array[Vector3] = [left, right, world * skeleton.get_bone_global_pose(heels[0]).origin,
				world * skeleton.get_bone_global_pose(heels[1]).origin]
		if last_points.size() == 4 and delta > 0.0:
			var still := INF
			for k in 4:
				var v := (points[k] - last_points[k]) / delta
				still = minf(still, Vector2(v.x, v.z).length())
			if elapsed > 3.8:
				steady.append(still)
		last_points = points
		camera.global_position = Vector3(x, y + 0.9, 4.0)
		if elapsed >= next_shot:
			next_shot += 0.9
			get_viewport().get_texture().get_image().save_png(directory.path_join("%s_%d.png" % [label, shots]))
			shots += 1
	slips.sort()
	report[label] = {"frames": slips.size(), "slip_median": snappedf(slips[slips.size() / 2], .001),
			"slip_p90": snappedf(slips[slips.size() * 9 / 10], .001), "before": before}
	steady.sort()
	if steady.size() > 10:
		report[label]["contact_slip_median"] = snappedf(steady[steady.size() / 2], .001)
		report[label]["contact_slip_p90"] = snappedf(steady[steady.size() * 9 / 10], .001)
	print("MINA PILOT SHOT ", label, " ", report[label], " frames ", dot_count, " clip ", mina._animation_player.current_animation,
			" speed_scale ", mina._animation_player.speed_scale)


func run() -> void:
	RealityState.persistence_enabled = false
	_set_stage()
	CastBodies.set_for_test([resident])
	mina = Presentation.new()
	mina.setup(resident.capitalize(), resident, "2A", CastBodies.model_for(resident))
	mina.externally_driven = true
	add_child(mina)
	await frames(10)
	if before and mina.mina_animation != null:
		mina.mina_animation.gaits.clear()
	if before:
		mina.walk_gait = null
	report["resident"] = resident
	report["walk_gait"] = mina.walk_gait != null
	if mina.cast_body == null or (resident == "mina_vale" and mina.mina_animation == null):
		push_error("Pilot shot: no cast body or behaviour")
		get_tree().quit(1)
		return
	# From a standstill, as the route starts her: the walk start plays first.
	mina.set_route_motion(false, 0.0, 0.0)
	await frames(40)
	await _walk("flat", -6.5, STAIR_X - 0.3, 1.0)
	mina.global_position = Vector3(STAIR_X - 0.3, 0, 0)
	await _walk("up", STAIR_X - 0.4, STAIR_X + RISERS * TREAD + 0.6, 1.0)
	await _walk("down", STAIR_X + RISERS * TREAD + 0.6, STAIR_X - 0.4, -1.0)
	var f := FileAccess.open(directory.path_join("slip.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("MINA PILOT SHOT DONE")
	get_tree().quit(0)
