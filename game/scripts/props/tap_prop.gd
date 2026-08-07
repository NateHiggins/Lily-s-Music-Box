class_name TapProp
extends FunctionalProp
## The handles on a sink or a shower, and the water they let out.
##
## The porcelain, the cross taps and the shower's valve plate are all
## modelled in Blender and always have been - twenty-three of each. What
## none of them had was a marker, so not one of them turned. This is the
## same division the range and the refrigerator use: the assembly is the
## fixture, and the prop is the part that moves.
##
## Turning a tap is a small thing to get right and an obvious thing to
## get wrong, so:
##   - the handle ROTATES rather than snapping, and keeps its angle
##   - water is a tapered column, not a blue box: it narrows as it falls
##     and breaks into a splash disc where it lands
##   - the sound starts with the handle, not with the water arriving
##   - a shower left running steams up, which is what makes an empty
##     bathroom with the water on unsettling rather than just wet
##
## Left running, it stays running. Nobody in this building is tidy.

## Which fixture this is; set from the marker's kind.
var fixture := "sink"

var _running := false
var _handles: Array[Node3D] = []
var _stream: Node3D
var _water: AudioStreamPlayer3D
var _turn := 0.0


func _build_visual() -> void:
	var chrome := Color(0.80, 0.82, 0.85)
	if fixture == "shower":
		_build_shower_valve(chrome)
	else:
		_build_sink_taps(chrome)
	_water = make_emitter(
			"shower_water" if fixture == "shower" else "sink_water",
			-16.0, true)
	if _water:
		_water.stream_paused = true


## Bakelite valve on its chrome plate, at the height the assembly left it.
func _build_shower_valve(chrome: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = "Valve"
	pivot.position = Vector3(0.0, 1.07, -0.36)
	add_child(pivot)
	_handles.append(pivot)
	var boss := make_cyl(0.026, 0.030, 0.030, Vector3.ZERO,
			Color(0.16, 0.14, 0.13), 0.42, 0.0, self)
	# four-spoke cross, the pattern every stall in the building has
	for i in 4:
		var arm := make_box(Vector3(0.104, 0.016, 0.013),
				Vector3.ZERO, Color(0.16, 0.14, 0.13))
		arm.rotation.z = TAU * i / 4.0
		_reparent(arm, pivot)
	_reparent(boss, pivot)
	boss.rotation_degrees.x = 90
	# the column of water, from the rose down to the tray
	_stream = _make_stream(Vector3(0.0, 1.90, -0.36), 1.78, 0.020)


## Two cross taps over a pedestal basin, hot and cold, turning opposite
## ways because they always did.
func _build_sink_taps(chrome: Color) -> void:
	for i in 2:
		var tx := -0.09 + i * 0.18
		var pivot := Node3D.new()
		pivot.name = "Tap%d" % i
		pivot.position = Vector3(tx, 0.855, -0.17)
		add_child(pivot)
		_handles.append(pivot)
		for k in 2:
			var arm := make_box(Vector3(0.058, 0.011, 0.011),
					Vector3.ZERO, chrome)
			arm.rotation.y = PI * 0.5 * k
			_reparent(arm, pivot)
		var cap := make_cyl(0.010, 0.010, 0.010, Vector3.ZERO,
				chrome, 0.12, 1.0, self)
		_reparent(cap, pivot)
	_stream = _make_stream(Vector3(0.0, 0.868, -0.045), 0.30, 0.008)


## A tapered column with a splash where it lands. Hidden until wanted.
func _make_stream(from: Vector3, drop: float, r: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Water"
	holder.position = from
	holder.visible = false
	add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.82, 0.86, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.10
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var col := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 0.55       # it narrows as it accelerates
	cyl.height = drop
	cyl.radial_segments = 7
	col.mesh = cyl
	col.material_override = mat
	col.position = Vector3(0, -drop * 0.5, 0)
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(col)
	var splash := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r * 4.5
	disc.bottom_radius = r * 4.5
	disc.height = 0.004
	disc.radial_segments = 10
	splash.mesh = disc
	splash.material_override = mat
	splash.position = Vector3(0, -drop, 0)
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(splash)
	return holder


func _reparent(node: Node3D, to: Node3D) -> void:
	var keep := node.position
	node.get_parent().remove_child(node)
	to.add_child(node)
	node.position = keep - to.position


func interact_prompt() -> String:
	var what := "shower" if fixture == "shower" else "tap"
	return "[E]  Turn %s the %s" % ["off" if _running else "on", what]


func interact(_player: Node) -> void:
	set_running(not _running)


func set_running(on: bool) -> void:
	if on == _running:
		return
	_running = on
	if _stream:
		_stream.visible = on
	if _water:
		_water.stream_paused = not on
		if on and not _water.playing:
			_water.play()
	state = PState.OPERATING if on else PState.IDLE


func _start_normal_function() -> void:
	state = PState.IDLE


## The handle turns rather than snapping. A quarter turn, eased, so the
## hand that did it reads as a hand.
func _process(delta: float) -> void:
	var want := 1.0 if _running else 0.0
	if is_equal_approx(_turn, want):
		return
	_turn = move_toward(_turn, want, delta * 3.2)
	for i in _handles.size():
		var sign := 1.0 if i % 2 == 0 else -1.0
		if fixture == "shower":
			_handles[i].rotation.z = -_turn * PI * 0.5
		else:
			_handles[i].rotation.y = sign * _turn * PI * 0.5
