extends "res://scripts/cases/reality_affected_prop.gd"
## A reality-affected case prop in V2. The catalogue identity, the rule hookup
## and the whole affected-state language (drift, orbit, point, stutter, grow,
## stretch, the glow, the wrong colour, the impossible duplicate) stay V1's:
## this script only replaces the placeholder silhouette with the Blender
## library object and lets V1's own driver values reach its real finishes
## and its separately pivoted parts.
const Stock := preload("res://scripts/building/orison_v2_case_prop_stock.gd")
## V1's glow lit a flat tint; on a textured PBR surface the same energy reads
## hotter, so the worn finish takes this share of it.
const GLOW_SHARE := 0.3
const WRONG_COLOR_SHARE := 0.65
const OVERLAY := -2
const OVERLAY_SHARE := 0.5

var asset := ""
var stock: Stock
## Placement turn. V1's driver owns this node's own rotation (it settles to
## zero at rest), so the library object is turned on an inner holder.
var yaw := 0.0
## A fitting fixed to the building glows and doubles but is never carried.
var fixed := false

var _pose: Node3D
var _draws: Array[MeshInstance3D] = []
var _parts: Array = []
var _worn: Array = []
var _echo_filled := false
var _clock := 0.0


func _build_visual() -> void:
	if stock == null or not stock.has(asset):
		push_error("V2 case prop has no library object: %s (%s)" % [prop_id, asset])
		return
	_pose = Node3D.new()
	_pose.name = "Pose"
	_pose.rotation.y = yaw
	add_child(_pose)
	set_meta("v2_native_case_prop", asset)
	for part: Dictionary in stock.mount_on(_pose, asset):
		var draw: MeshInstance3D = part.draw
		_draws.append(draw)
		if str(part.motion) != "":
			part["rest"] = draw.transform
			_parts.append(part)


## V1 copied its placeholder meshes at once; here the duplicate is drawn only
## when a rule first calls for it, from the meshes the prop really wears.
func _build_echo() -> void:
	_echo_root = Node3D.new()
	_echo_root.name = "ImpossibleDuplicate"
	_echo_root.visible = false
	add_child(_echo_root)


func _apply_rule(effect: Dictionary) -> void:
	super._apply_rule(effect)
	if _echo_root != null and _echo_root.visible and not _echo_filled:
		_fill_echo()


func affected() -> bool:
	return _intensity > 0.0


## The strongest glow any of its finishes is wearing now.
func glow_level() -> float:
	var level := 0.0
	for record: Dictionary in _worn:
		var finish: StandardMaterial3D = record.worn
		level = maxf(level, finish.albedo_color.g if int(record.surface) == OVERLAY else finish.emission_energy_multiplier)
	return level


func affected_state() -> Dictionary:
	return {"prop_id": prop_id, "case_id": case_id, "intensity": _intensity, "recurrence": _recurrence,
		"verbs": _verbs.duplicate(), "glowing": not _worn.is_empty(),
		"duplicate": _echo_root != null and _echo_root.visible, "fixed": fixed}


func _process(delta: float) -> void:
	super._process(delta)
	if _material == null:
		return
	if fixed:
		position = _home
		rotation.y = 0.0
		scale = Vector3.ONE
	_wear()
	_drive_parts(delta)


func _echo_frame() -> Transform3D:
	return _pose.transform if _pose != null else Transform3D.IDENTITY


func _echo_origin() -> Transform3D:
	return _pose.global_transform if _pose != null else global_transform


func _fill_echo() -> void:
	_echo_filled = true
	var pose := Node3D.new()
	pose.name = "Pose"
	pose.transform = _echo_frame()
	_echo_root.add_child(pose)
	var origin := _echo_origin().affine_inverse()
	for source in _draws:
		if not is_instance_valid(source) or source.mesh == null:
			continue
		var finish := (source.material_override if source.material_override != null 				else source.get_active_material(0)) as StandardMaterial3D
		var echo := MeshInstance3D.new()
		echo.mesh = source.mesh
		pose.add_child(echo)
		echo.transform = origin * source.global_transform
		# A finish drawn by the house surface shader has no plain copy: its
		# duplicate is a pale ghost of the shape alone.
		var ghost := StandardMaterial3D.new()
		if finish != null:
			ghost = finish.duplicate() as StandardMaterial3D
		else:
			ghost.albedo_color = Color(0.78, 0.80, 0.76)
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.albedo_color.a = 0.32
		echo.material_override = ghost
		echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## V1 drives one material's emission and albedo. The same two values are worn
## by per-prop copies of the real finishes while the prop is seized, and the
## shared finishes come back when the glow has died.
func _wear() -> void:
	var glow := _material.emission_energy_multiplier
	if _intensity <= 0.0 and glow < 0.01:
		if not _worn.is_empty():
			_restore_finishes()
		return
	if _worn.is_empty():
		_take_finishes()
	var drift := absf(_material.albedo_color.r - _base_color.r) + absf(_material.albedo_color.g - _base_color.g) \
			+ absf(_material.albedo_color.b - _base_color.b)
	var wrong := clampf(drift * 2.0, 0.0, 1.0) * WRONG_COLOR_SHARE
	for record: Dictionary in _worn:
		var finish: StandardMaterial3D = record.worn
		if int(record.surface) == OVERLAY:
			var lit := _material.emission * (glow * GLOW_SHARE * OVERLAY_SHARE)
			finish.albedo_color = Color(lit.r, lit.g, lit.b, 1.0)
			continue
		finish.emission_energy_multiplier = glow * GLOW_SHARE
		var base: Color = record.base
		var shifted := base.lerp(_material.albedo_color, wrong)
		shifted.a = base.a
		finish.albedo_color = shifted


func _take_finishes() -> void:
	for draw in _draws:
		if not is_instance_valid(draw) or draw.mesh == null:
			continue
		if draw.material_override != null:
			var whole := _worn_copy(draw.material_override)
			if whole != null:
				_worn.append({"draw": draw, "surface": -1, "was": draw.material_override, "worn": whole,
					"base": whole.albedo_color})
				draw.material_override = whole
				continue
		var plain := draw.material_override == null
		for surface in draw.mesh.get_surface_count():
			plain = plain and draw.get_active_material(surface) is StandardMaterial3D
		if not plain:
			# A finish the house surface shader draws cannot carry emission
			# itself; the glow is laid over it and lifted off again.
			var veil := StandardMaterial3D.new()
			veil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			veil.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			veil.albedo_color = Color.BLACK
			_worn.append({"draw": draw, "surface": OVERLAY, "was": draw.material_overlay, "worn": veil, "base": Color.BLACK})
			draw.material_overlay = veil
			continue
		for surface in draw.mesh.get_surface_count():
			var copy := _worn_copy(draw.get_active_material(surface))
			if copy != null:
				_worn.append({"draw": draw, "surface": surface, "was": draw.get_surface_override_material(surface),
					"worn": copy, "base": copy.albedo_color})
				draw.set_surface_override_material(surface, copy)


func _worn_copy(finish: Material) -> StandardMaterial3D:
	if finish is not StandardMaterial3D:
		return null
	var copy := finish.duplicate() as StandardMaterial3D
	copy.emission_enabled = true
	copy.emission = _material.emission
	copy.emission_energy_multiplier = 0.0
	return copy


func _restore_finishes() -> void:
	for record: Dictionary in _worn:
		var draw: MeshInstance3D = record.draw
		if not is_instance_valid(draw):
			continue
		var was: Material = record.was
		if int(record.surface) == OVERLAY:
			draw.material_overlay = was
		elif int(record.surface) < 0:
			draw.material_override = was
		else:
			draw.set_surface_override_material(int(record.surface), was)
	_worn.clear()


## The library's own tells: reels and cranks turn, plungers and stamps work,
## at the pace the rule sets. They rest where the model left them.
func _drive_parts(delta: float) -> void:
	if _parts.is_empty():
		return
	var agitation := _intensity * (1.0 + _recurrence * 0.35)
	if "freeze" in _verbs:
		agitation = 0.0
	_clock += delta * agitation
	for part: Dictionary in _parts:
		var draw: MeshInstance3D = part.draw
		var rest: Transform3D = part.rest
		match str(part.motion):
			"spin":
				draw.transform = rest * Transform3D(Basis(Vector3.UP, _clock * float(part.amount)), Vector3.ZERO)
			"bob":
				var dip := absf(sin(_clock * 6.0 + _phase)) * float(part.amount) * minf(1.0, agitation)
				draw.position = draw.position.lerp(rest.origin - rest.basis.y * dip, minf(1.0, delta * 18.0))
