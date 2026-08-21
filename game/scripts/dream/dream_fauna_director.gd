class_name DreamFaunaDirector
extends Node3D
## FA1/FA2: one presentation-only density owner; no collision, light, shadow or save.

const MAX_INSTANCES := 96
const TICK_S := 1.0 / 3.0
const HUSH_RADIUS := 4.0
const FAUNA_SHADER := preload("res://shaders/dream_fauna.gdshader")
const WINE := Color("55152f")
const GOLD := Color(0.72, 0.40, 0.09)
const EMERALD := Color(0.180, 0.404, 0.360)
const CARNELIAN := Color(0.451, 0.098, 0.106)
const LAPIS := Color(0.145, 0.216, 0.463)
const FAUNA_DARK_GLOW := 0.10

var rooms: DreamRoomBuilder
var player: Node3D
var pursuer: Node3D
var exposure: DreamExposureField
var frozen := false
var _clock := 0.0
var _buttons: MultiMeshInstance3D
var _tessellates: MultiMeshInstance3D
var _anemones: MultiMeshInstance3D
var _ribbonettes: MultiMeshInstance3D
var _loupe: MultiMeshInstance3D
var _material_bindings: Node3D
var _census := {"buttons": 0, "tessellates": 0, "rooms": 0,
		"anemones": 0, "ribbonettes": 0, "loupe": 0,
		"hushed": 0, "submerged": 0}
var _signature := ""
var _room_signatures: Dictionary = {}
var _densities: Dictionary = {}

func setup(room_owner: DreamRoomBuilder, body: Node3D, tenant: Node3D,
		exposure_owner: DreamExposureField) -> void:
	name = "DreamFaunaDirector"
	rooms = room_owner; player = body; pursuer = tenant; exposure = exposure_owner
	_material_bindings = Node3D.new()
	_material_bindings.name = "FaunaMaterialBindings"
	add_child(_material_bindings)
	_buttons = _make_batch("GildersButtons", DreamFaunaParts.buttons(), WINE,
			EMERALD, 0.03, 1.8, 0.0, true)
	_tessellates = _make_batch("Tessellates", DreamFaunaParts.tessellates(),
			WINE, EMERALD, 0.10, 1.8, 1.0, true)
	_anemones = _make_batch("WineAnemones", DreamFaunaParts.anemones(),
			WINE, LAPIS, 0.055, 0.55, 2.0, true)
	(_anemones.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.85)
	_ribbonettes = _make_batch("Ribbonettes", DreamFaunaParts.ribbonettes(),
			WINE, LAPIS, 0.085, 0.45, 3.0, true)
	(_ribbonettes.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.85)
	_loupe = _make_batch("TheLoupe", DreamFaunaParts.loupe(), WINE, CARNELIAN,
			0.035, 0.08, 4.0, true)
	(_loupe.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.75)
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
		var predator_target := maxf(0.0, previous-0.42)*0.82
		state.predator = move_toward(float(state.predator), predator_target, 0.075)
		var consumed := float(state.predator)*0.028
		state.grazer = clampf(previous+births-deaths-consumed, 0.0, 1.0)
		state.detritus = clampf(float(state.detritus)*0.78
				+ maxf(0.0, previous-float(state.grazer))+consumed*0.8, 0.0, 1.0)
		_densities[key] = state

func freeze_for_capture() -> void:
	frozen = true
	if _buttons: _buttons.visible = false
	if _tessellates: _tessellates.visible = false
	if _anemones: _anemones.visible = false
	if _ribbonettes: _ribbonettes.visible = false
	if _loupe: _loupe.visible = false

func refresh() -> void:
	var button_xforms: Array[Transform3D] = []
	var tess_xforms: Array[Transform3D] = []
	var button_custom: Array[Color] = []
	var tess_custom: Array[Color] = []
	var anemone_xforms: Array[Transform3D] = []
	var ribbon_xforms: Array[Transform3D] = []
	var loupe_xforms: Array[Transform3D] = []
	var anemone_custom: Array[Color] = []
	var ribbon_custom: Array[Color] = []
	var loupe_custom: Array[Color] = []
	var hushed_count := 0
	var submerged_count := 0
	var loupe_room: Dictionary = {}
	var loupe_strength := 0.0
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
		var anemone_start := anemone_xforms.size()
		var ribbon_start := ribbon_xforms.size()
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
		var anemone_count := 1 + int(round((1.0-feed+float(state.detritus))*1.4))
		var ribbon_count := int(round(maxf(0.0,float(state.grazer)-0.28)*2.4))
		if hush:
			hushed_count += tess_count+ribbon_count+anemone_count
		for i in button_count:
			if button_xforms.size() >= MAX_INSTANCES: break
			var a := phase * TAU + float(i) * 2.094
			var at := centre + Vector3(cos(a)*0.72, 0.025, sin(a)*0.72)
			button_xforms.append(Transform3D(Basis().scaled(
					Vector3(0.20, 0.035, 0.20)), at))
			button_custom.append(DreamFaunaChannels.encode(phase, feed, feed,
					DreamFaunaChannels.FLAG_PEARL_COLONY, 0.0,
					_genome(phase, i, 0.37), _genome(phase, i, 0.71)))
		for i in tess_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
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
			var tess_flags := DreamFaunaChannels.FLAG_HUSH if hush else 0
			tess_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.11, feed,
					emergence, tess_flags, 0.0 if hush else 1.0,
					_genome(phase, i, 1.13), _genome(phase, i, 1.79)))
		for i in anemone_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var side := Vector3(-sin(phase*TAU),0.0,cos(phase*TAU))
			var at := frame.lerp(centre,0.18)+side*(float(i)-0.5)*0.32
			at.y = -0.12 if hush else 0.10
			if hush: submerged_count += 1
			anemone_xforms.append(Transform3D(Basis().scaled(Vector3.ONE*1.12),at))
			var anemone_flags := DreamFaunaChannels.FLAG_HUSH if hush else 0
			anemone_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.09,
					1.0-feed, float(state.detritus), anemone_flags,
					0.0 if hush else 1.0, _genome(phase, i, 2.11),
					_genome(phase, i, 2.73)))
		for i in ribbon_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var a := phase*TAU+float(i)*PI
			var at := centre+Vector3(cos(a)*0.54,0.12,sin(a)*0.54)
			if hush: at=frame+Vector3(0.0,-0.20,0.0); submerged_count+=1
			ribbon_xforms.append(Transform3D(Basis(Vector3.UP,a).scaled(
					Vector3.ONE*(1.18+float(i)*0.06)),at))
			var ribbon_flags := DreamFaunaChannels.FLAG_COURTSHIP
			if hush: ribbon_flags |= DreamFaunaChannels.FLAG_HUSH
			ribbon_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.17,
					float(state.grazer), feed, ribbon_flags,
					0.0 if hush else 1.0, _genome(phase, i, 3.17),
					_genome(phase, i, 3.91)))
		if float(state.predator)>loupe_strength:
			loupe_strength=float(state.predator)
			loupe_room={"centre":centre,"frame":frame,"phase":phase,"hush":hush}
		var room_rows: Array[String] = []
		for i in range(button_start, button_xforms.size()):
			room_rows.append("b:%s:%s" % [button_xforms[i].origin, button_custom[i]])
		for i in range(tess_start, tess_xforms.size()):
			room_rows.append("t:%s:%s" % [tess_xforms[i].origin, tess_custom[i]])
		for i in range(anemone_start,anemone_xforms.size()):
			room_rows.append("a:%s:%s"%[anemone_xforms[i].origin,anemone_custom[i]])
		for i in range(ribbon_start,ribbon_xforms.size()):
			room_rows.append("r:%s:%s"%[ribbon_xforms[i].origin,ribbon_custom[i]])
		_room_signatures[str(room.get("key", ""))] = "|".join(room_rows)
	if loupe_strength>=0.14 and not loupe_room.is_empty() and _total_instances(
			button_xforms,tess_xforms,anemone_xforms,ribbon_xforms,loupe_xforms)<MAX_INSTANCES:
		var at:Vector3=loupe_room.frame.lerp(loupe_room.centre,0.68)
		if bool(loupe_room.hush): at=loupe_room.frame+Vector3(0.0,-0.38,0.0); submerged_count+=1; hushed_count+=1
		loupe_xforms.append(Transform3D(Basis(Vector3.UP,float(loupe_room.phase)*TAU),at))
		var loupe_flags := DreamFaunaChannels.FLAG_CAMERA_TRACKER
		if bool(loupe_room.hush): loupe_flags |= DreamFaunaChannels.FLAG_HUSH
		loupe_custom.append(DreamFaunaChannels.encode(float(loupe_room.phase),loupe_strength,
				loupe_strength, loupe_flags,
				0.0 if bool(loupe_room.hush) else 1.0,
				_genome(float(loupe_room.phase), 0, 4.19),
				_genome(float(loupe_room.phase), 0, 4.83)))
	_apply(_buttons, button_xforms, button_custom)
	_apply(_tessellates, tess_xforms, tess_custom)
	_apply(_anemones,anemone_xforms,anemone_custom)
	_apply(_ribbonettes,ribbon_xforms,ribbon_custom)
	_apply(_loupe,loupe_xforms,loupe_custom)
	_signature = _realization_signature(button_xforms, button_custom,
			tess_xforms, tess_custom)+_realization_signature(anemone_xforms,
			anemone_custom,ribbon_xforms,ribbon_custom)+str(loupe_xforms)+str(loupe_custom)
	_census = {"buttons":button_xforms.size(), "tessellates":tess_xforms.size(),
			"anemones":anemone_xforms.size(),"ribbonettes":ribbon_xforms.size(),
			"loupe":loupe_xforms.size(),"rooms":live.size(),"hushed":hushed_count,
			"submerged":submerged_count}

func _total_instances(a:Array,b:Array,c:Array,d:Array,e:Array)->int:
	return a.size()+b.size()+c.size()+d.size()+e.size()

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

func _make_batch(label: String, mesh: Mesh, color: Color, jewel: Color,
		gait: float, gait_hz: float, motif: float,
		vertex_channels_ready := false) -> MultiMeshInstance3D:
	var material := ShaderMaterial.new(); material.shader = FAUNA_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("gold_color", GOLD)
	material.set_shader_parameter("jewel_color", jewel)
	material.set_shader_parameter("gait_amount", gait)
	material.set_shader_parameter("gait_hz", gait_hz)
	material.set_shader_parameter("family_motif", motif)
	material.set_shader_parameter("fauna_dark_glow", FAUNA_DARK_GLOW)
	material.set_shader_parameter("vertex_channels_ready",
			1.0 if vertex_channels_ready else 0.0)
	var node := MultiMeshInstance3D.new(); node.name = label
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	else:
		mesh.surface_set_material(0, material)
	# Compatibility expands a MultiMesh material_override into per-instance
	# waking-view submissions. A zero-mesh, invisible binding lets the existing
	# root collector discover this exact material without entering any render
	# pass; the batch keeps the same material on its sole mesh surface.
	var binding := MeshInstance3D.new()
	binding.name = label+"MaterialBinding"
	binding.visible = false
	binding.material_override = material
	_material_bindings.add_child(binding)
	add_child(node)
	var batch := MultiMesh.new(); batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true; batch.mesh = mesh; node.multimesh = batch
	return node

func _genome(phase: float, index: int, salt: float) -> float:
	return fposmod(sin(phase * 91.7 + float(index) * 17.31 + salt) * 43758.5453,
			1.0)

func _apply(node: MultiMeshInstance3D, xforms: Array[Transform3D], custom: Array[Color]) -> void:
	node.multimesh.instance_count = xforms.size()
	for i in xforms.size():
		node.multimesh.set_instance_transform(i, xforms[i])
		node.multimesh.set_instance_custom_data(i, custom[i])
