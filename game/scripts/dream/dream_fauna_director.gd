class_name DreamFaunaDirector
extends Node3D
## F1: one presentation-only density owner; no collision, light, shadow or save.

const MAX_INSTANCES := 96
const TICK_S := 1.0 / 3.0
const HUSH_RADIUS := 4.0
const FAUNA_SHADER := preload("res://shaders/dream_fauna.gdshader")

var rooms: DreamRoomBuilder
var player: Node3D
var pursuer: Node3D
var exposure: DreamExposureField
var frozen := false
var _clock := 0.0
var _buttons: MultiMeshInstance3D
var _tessellates: MultiMeshInstance3D
var _census := {"buttons": 0, "tessellates": 0, "rooms": 0,
		"hushed": 0, "submerged": 0}
var _signature := ""
var _room_signatures: Dictionary = {}
var _densities: Dictionary = {}
var _tick_index := 0

func setup(room_owner: DreamRoomBuilder, body: Node3D, tenant: Node3D,
		exposure_owner: DreamExposureField) -> void:
	name = "DreamFaunaDirector"
	rooms = room_owner; player = body; pursuer = tenant; exposure = exposure_owner
	var button := SphereMesh.new(); button.radial_segments = 12; button.rings = 6
	_buttons = _make_batch("GildersButtons", button, Color("5f1827"), 0.03)
	_tessellates = _make_batch("Tessellates", _tessellate_mesh(),
			Color("8a6425"), 0.10)
	refresh()

func _physics_process(delta: float) -> void:
	if frozen or rooms == null: return
	_clock += delta
	if _clock >= TICK_S:
		_clock -= TICK_S
		advance_fixed()
		refresh()

func advance_fixed() -> void:
	var live := rooms.live_rooms()
	_sync_densities(live)
	_tick_index += 1
	for room in live:
		var key := str(room.get("key", ""))
		var state: Dictionary = _densities[key]
		var r: Array = room.rect
		var centre := Vector3((r[0]+r[2])*0.5, 0.0, (r[1]+r[3])*0.5)
		var frame := _birth_frame(key, centre)
		var retained := exposure.room_exposure(key) if exposure != null else 0.0
		var lamp_pool := 1.0 if player != null and minf(
				player.global_position.distance_to(centre),
				player.global_position.distance_to(frame)) < 5.0 else 0.0
		var target := clampf(0.12 + retained*0.62 + lamp_pool*0.35, 0.0, 1.0)
		state.nutrient = move_toward(float(state.nutrient), target, 0.16)
		var previous := float(state.grazer)
		var births := maxf(0.0, float(state.nutrient)-0.28)*0.28
		var deaths := 0.025 + maxf(0.0, 0.32-float(state.nutrient))*0.22
		state.grazer = clampf(previous+births-deaths, 0.0, 1.0)
		state.detritus = clampf(float(state.detritus)*0.78
				+ maxf(0.0, previous-float(state.grazer)), 0.0, 1.0)
		state.predator = 0.0 # F1 is harmless and has no predator family.
		_densities[key] = state

func freeze_for_capture() -> void:
	frozen = true
	if _buttons: _buttons.visible = false
	if _tessellates: _tessellates.visible = false

func refresh() -> void:
	var button_xforms: Array[Transform3D] = []
	var tess_xforms: Array[Transform3D] = []
	var button_custom: Array[Color] = []
	var tess_custom: Array[Color] = []
	var hushed_count := 0
	var submerged_count := 0
	var live := rooms.live_rooms()
	_sync_densities(live)
	_room_signatures.clear()
	# RefCounted's dictionary does not promise an order. Slot order is visual
	# identity for a MultiMesh, so name the order explicitly before a cap can
	# make insertion history observable.
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", "")))
	for room in live:
		var button_start := button_xforms.size()
		var tess_start := tess_xforms.size()
		var r: Array = room.rect
		var centre := Vector3((r[0]+r[2])*0.5, 0.0, (r[1]+r[3])*0.5)
		var frame := _birth_frame(str(room.get("key", "")), centre)
		var hush := pursuer != null and minf(
				pursuer.global_position.distance_to(centre),
				pursuer.global_position.distance_to(frame)) < HUSH_RADIUS
		var lineage: Dictionary = room.get("lineage", {})
		var phase := fposmod(float(lineage.get("phase", 0.0)), TAU) / TAU
		var state: Dictionary = _densities[str(room.get("key", ""))]
		var feed := float(state.nutrient)
		var button_count := 1 + int(round(feed * 3.0))
		var tess_count := 1 + int(round(float(state.grazer) * 4.0))
		if hush:
			hushed_count += tess_count
		for i in button_count:
			if button_xforms.size() >= MAX_INSTANCES: break
			var a := phase * TAU + float(i) * 2.094
			var at := centre + Vector3(cos(a)*0.72, 0.025, sin(a)*0.72)
			button_xforms.append(Transform3D(Basis().scaled(
					Vector3(0.20, 0.035, 0.20)), at))
			button_custom.append(Color(phase, 0.2, 0.0, feed))
		for i in tess_count:
			if button_xforms.size()+tess_xforms.size() >= MAX_INSTANCES: break
			var a := phase*TAU + float(i)*1.37
			var radius := 0.20 if hush else 0.95 + float(i%2)*0.28
			# Grazers are born at a real landed birth-frame, then spread toward
			# the exposure crop. Hush reverses that path and submerges them into
			# the frame-foot rather than inventing a second escape owner.
			var graze_at := centre + Vector3(cos(a)*radius, 0.14, sin(a)*radius)
			var emergence := clampf(feed * 1.35 - float(i) * 0.08, 0.0, 1.0)
			var at := frame.lerp(graze_at, emergence)
			if hush:
				at = frame + Vector3(0.0, -0.18, 0.0)
				submerged_count += 1
			var size := 0.82 + 0.08 * float(i % 3)
			tess_xforms.append(Transform3D(Basis().scaled(
					Vector3(size, size * 0.72, size)), at))
			tess_custom.append(Color(phase+float(i)*0.11, feed, 0.0 if hush else 1.0, feed))
		var room_rows: Array[String] = []
		for i in range(button_start, button_xforms.size()):
			room_rows.append("b:%s:%s" % [button_xforms[i].origin, button_custom[i]])
		for i in range(tess_start, tess_xforms.size()):
			room_rows.append("t:%s:%s" % [tess_xforms[i].origin, tess_custom[i]])
		_room_signatures[str(room.get("key", ""))] = "|".join(room_rows)
	_apply(_buttons, button_xforms, button_custom)
	_apply(_tessellates, tess_xforms, tess_custom)
	_signature = _realization_signature(button_xforms, button_custom,
			tess_xforms, tess_custom)
	_census = {"buttons":button_xforms.size(), "tessellates":tess_xforms.size(),
			"rooms":live.size(), "hushed":hushed_count,
			"submerged":submerged_count}

func _birth_frame(room_key: String, fallback: Vector3) -> Vector3:
	if rooms == null:
		return fallback
	# The body is geometry already owned by the live room. Reading its published
	# metadata cannot keep the room alive and creates no fauna-specific maze seam.
	for body in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		if str(body.get_meta("room_key", "")) != room_key:
			continue
		var frames: Array = body.get_meta("birth_frames", [])
		if not frames.is_empty():
			return frames[0]
	return fallback

func census() -> Dictionary: return _census.duplicate(true)

func density_snapshot() -> Dictionary: return _densities.duplicate(true)

func realization_signature() -> String: return _signature

func room_signature(room_key: String) -> String:
	return str(_room_signatures.get(room_key, ""))

func _sync_densities(live: Array) -> void:
	var keep := {}
	for room in live:
		var key := str(room.get("key", "")); keep[key] = true
		if _densities.has(key): continue
		var lineage: Dictionary = room.get("lineage", {})
		var phase := fposmod(float(lineage.get("phase", 0.0)), TAU)/TAU
		var decay := clampf(float(room.get("decay", 0.0)), 0.0, 1.0)
		_densities[key] = {"nutrient":clampf(0.20+phase*0.18-decay*0.08,0.0,1.0),
				"grazer":clampf(0.34+phase*0.16,0.0,1.0),
				"predator":0.0,"detritus":decay*0.10}
	for key in _densities.keys():
		if not keep.has(key): _densities.erase(key)

func _realization_signature(button_xforms: Array[Transform3D],
		button_custom: Array[Color], tess_xforms: Array[Transform3D],
		tess_custom: Array[Color]) -> String:
	var rows: Array[String] = []
	for i in button_xforms.size():
		rows.append("b:%s:%s" % [button_xforms[i].origin, button_custom[i]])
	for i in tess_xforms.size():
		rows.append("t:%s:%s" % [tess_xforms[i].origin, tess_custom[i]])
	return "|".join(rows)

func _make_batch(label: String, mesh: Mesh, color: Color, gait: float) -> MultiMeshInstance3D:
	var material := ShaderMaterial.new(); material.shader = FAUNA_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("gold_color", color.lightened(0.22))
	material.set_shader_parameter("gait_amount", gait)
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	else:
		mesh.surface_set_material(0, material)
	var node := MultiMeshInstance3D.new(); node.name = label
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var batch := MultiMesh.new(); batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true; batch.mesh = mesh; node.multimesh = batch
	return node

func _tessellate_mesh() -> ArrayMesh:
	# One faceted grazer mesh, still submitted as one family MultiMesh. A low
	# body, four mineral feet and a smaller leading facet make "walking life"
	# legible without rigs, per-creature nodes or a second draw.
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new(); body.radius = 0.15; body.height = 0.20
	body.radial_segments = 8; body.rings = 4
	tool.append_from(body, 0, Transform3D.IDENTITY)
	var head := SphereMesh.new(); head.radius = 0.085; head.height = 0.12
	head.radial_segments = 8; head.rings = 3
	tool.append_from(head, 0, Transform3D(Basis(), Vector3(0.0, 0.01, -0.16)))
	var foot := BoxMesh.new(); foot.size = Vector3(0.045, 0.11, 0.045)
	for x in [-0.085, 0.085]:
		for z in [-0.065, 0.075]:
			tool.append_from(foot, 0, Transform3D(Basis(), Vector3(x, -0.105, z)))
	tool.generate_normals()
	return tool.commit()

func _apply(node: MultiMeshInstance3D, xforms: Array[Transform3D], custom: Array[Color]) -> void:
	node.multimesh.instance_count = xforms.size()
	for i in xforms.size():
		node.multimesh.set_instance_transform(i, xforms[i])
		node.multimesh.set_instance_custom_data(i, custom[i])
