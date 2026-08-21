class_name ApartmentEncroachment
extends Node
## THE DREAM REACHING INTO A CASE'S FLAT (design/DREAM_ENCROACHMENT_BRIEF.md,
## decision 3). Presentation only: it owns no case state, no save key, no
## collision, no light and no new draw. It reads each case's state from
## RealityState and sets one `intensity` on the case unit's wall-finish
## surfaces and beachhead prop, so the flat feels the encroachment before the
## player ever sleeps and settles when the case resolves.
##
## What it touches, per case with shipped plates:
##   - every baked wall-finish quad on the unit's storey whose footprint meets
##     the unit rect takes `wall_encroachment.gdshader` carrying the SAME
##     finish maps plus the case's first three substance plates; the shader
##     clips the creep to the unit rect, so a perimeter quad shared with the
##     neighbour only changes inside this flat;
##   - the unit's authored anomaly prop (the case's beachhead) takes the first
##     plate on its body once intensity passes BEACHHEAD_AT.
##
## Intensity comes from the case's stage, lifted by manifestation_intensity
## and held to a residue once resolved. ENCROACH=0 disables the pass;
## ENCROACH_FORCE="mina:0.8,peter:0.3" pins intensities for frames and tests.

const SHADER := preload("res://shaders/wall_encroachment.gdshader")
const PROFILES_PATH := "res://data/dream_profiles.json"
const PLATE_ROOT := "res://assets/dream/incarnations"
const BEACHHEAD_AT := 0.3
const RESIDUE := 0.2
## Case -> unit and incarnation. The unit is where the resident lives; the
## incarnation names the plate bundle the dream already ships for the case.
const CASES := {
	"mina_caption_crisis": {"unit": "2A", "incarnation": "mina", "profile": "mina_release_print"},
	"peter_form_corridor": {"unit": "4A", "incarnation": "peter", "profile": "peter_release_print"},
	"juno_feedback_tetris": {"unit": "2C", "incarnation": "juno", "profile": "juno_release_print"},
	"mae_contradictory_antiques": {"unit": "6C", "incarnation": "mae", "profile": "mae_release_print"},
	"cal_memory_radio": {"unit": "5B", "incarnation": "cal", "profile": "cal_release_print"},
	"omar_unrepairable": {"unit": "3B", "incarnation": "omar", "profile": "omar_release_print"},
}
const STAGE_INTENSITY := {
	"unseen": 0.0, "active": 0.35, "recognized": 0.6, "integration_ready": 0.85,
	"stabilized": 0.45, "resolved": RESIDUE, "reopened": 0.9,
}

var enabled := true
## case_id -> Array of {"mesh": MeshInstance3D, "surface": int, "material": ShaderMaterial}
var surfaces: Dictionary = {}
## case_id -> {"node": Node, "originals": {MeshInstance3D: Material}}
var beachheads: Dictionary = {}
var intensities: Dictionary = {}
## case_id -> {"rect": Vector4, "floor_y": float, "floor_node": Node}
var units: Dictionary = {}
## case_id -> Array of {"mesh": MeshInstance3D, "material": ShaderMaterial, "shared": Material}
## The props inside the flat that wear the layered surface, each given its
## own copy with the case's states on it (owner ruling 2026-08-21: "it
## should reach the props").
var prop_rows: Dictionary = {}
var props_reached := 0
var _forced: Dictionary = {}
var _plates: Dictionary = {}
var _substance_keys: Dictionary = {}


func build(layout: Dictionary, floor_nodes: Dictionary, witnesses: Node = null) -> int:
	name = "ApartmentEncroachment"
	enabled = OS.get_environment("ENCROACH") != "0"
	_parse_forced(OS.get_environment("ENCROACH_FORCE"))
	if not enabled:
		print("[ENCROACH] disabled by ENCROACH=0")
		return 0
	_read_substance_keys()
	var total := 0
	for case_id in CASES:
		var spec: Dictionary = CASES[case_id]
		var unit := str(spec.unit)
		var inc := str(spec.incarnation)
		if not _substance_keys.has(inc):
			continue
		var rooms := _unit_rooms(layout, unit)
		if rooms.is_empty():
			continue
		var floor_id := str(rooms[0].floor)
		var floor_node: Node = floor_nodes.get(floor_id)
		if floor_node == null:
			continue
		var rect := _union_rect(rooms)
		var floor_y := float(rooms[0].z)
		var plates := _plates_for(inc)
		if plates.is_empty():
			continue
		units[case_id] = {"rect": rect, "floor_y": floor_y, "floor_node": floor_node}
		var rows: Array = []
		for node in floor_node.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.name.contains("_finish_"):
				continue
			var aabb := _world_aabb(mi)
			if aabb.size == Vector3.ZERO:
				continue
			if not _aabb_meets_rect(aabb, rect, 0.30):
				continue
			for s in mi.mesh.get_surface_count():
				var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if original == null or original.albedo_texture == null:
					continue
				var material := _material_for(original, plates, rect, floor_y)
				mi.set_surface_override_material(s, material)
				rows.append({"mesh": mi, "surface": s, "material": material})
		surfaces[case_id] = rows
		total += rows.size()
		var beachhead := _find_beachhead(witnesses, floor_node, case_id)
		if beachhead != null:
			beachheads[case_id] = {"node": beachhead, "originals": {}}
	if RealityState.has_signal("state_changed") and not RealityState.state_changed.is_connected(refresh):
		RealityState.state_changed.connect(refresh)
	refresh()
	print("[ENCROACH] %d finish surfaces across %d case flats, %d beachheads"
			% [total, surfaces.size(), beachheads.size()])
	return total


## Re-read every case's state and push intensities. Cheap; called on commit.
func refresh() -> void:
	for case_id in surfaces:
		var value := intensity_for(case_id)
		intensities[case_id] = value
		for row in surfaces[case_id]:
			(row.material as ShaderMaterial).set_shader_parameter("intensity", value)
		_apply_beachhead(case_id, value)
		_apply_prop_states(case_id, value)


## THE STATES REACH THE PROPS. Every script-built prop inside the flat whose
## draw wears the layered surface (SurfacePass, after its deferred sweep)
## takes its own copy of that material with the case's states on it:
## corruption (the dream's flesh) and gilding rising with the intensity,
## grime and moisture under them. Idempotent; called after the prop sweep
## and again whenever the governor's lever re-applies the tier. Props whose
## draw is not layered (colour-only standards, glass) are left alone.
func reach_props(root: Node) -> int:
	if not enabled:
		return 0
	props_reached = 0
	for case_id in units:
		var unit: Dictionary = units[case_id]
		var rect: Vector4 = unit.rect
		var floor_y: float = unit.floor_y
		var rows: Array = []
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not (mi.material_override is ShaderMaterial):
				continue
			var shader_path := ""
			if (mi.material_override as ShaderMaterial).shader != null:
				shader_path = (mi.material_override as ShaderMaterial).shader.resource_path
			if not shader_path.get_file().begins_with("orison_surface"):
				continue
			if (mi.material_override as ShaderMaterial).has_meta("encroachment_case"):
				if str(mi.material_override.get_meta("encroachment_case")) == case_id:
					rows.append({"mesh": mi, "material": mi.material_override,
							"shared": mi.material_override.get_meta("encroachment_shared")})
				continue
			var aabb := _world_aabb(mi)
			if aabb.size == Vector3.ZERO:
				continue
			if aabb.position.y > floor_y + 3.6 or aabb.end.y < floor_y - 0.2:
				continue
			if not _aabb_meets_rect(aabb, rect, 0.0):
				continue
			var shared: Material = mi.material_override
			var own := (shared as ShaderMaterial).duplicate() as ShaderMaterial
			own.set_meta("encroachment_case", case_id)
			own.set_meta("encroachment_shared", shared)
			own.set_shader_parameter("mask_proc_scale", 2.4)
			own.set_shader_parameter("mask2_threshold", Vector4(0.55, 0.58, 0.46, 0.55))
			own.set_shader_parameter("mask2_softness", Vector4(0.15, 0.14, 0.30, 0.15))
			own.set_shader_parameter("mask_threshold", Vector4(0.72, 0.50, 0.60, 0.50))
			own.set_shader_parameter("mask_softness", Vector4(0.08, 0.30, 0.22, 0.25))
			# A batched draw spans the storey: the states show only inside the flat.
			own.set_shader_parameter("state_rect", rect)
			own.set_shader_parameter("state_y", Vector2(floor_y - 0.2, floor_y + 3.6))
			mi.material_override = own
			rows.append({"mesh": mi, "material": own, "shared": shared})
			if OS.get_environment("ENCROACH_DEBUG") == "1" and rows.size() <= 12:
				print("[ENCROACH]   %s reaches %s (%s)" % [case_id, mi.get_path(), aabb])
		prop_rows[case_id] = rows
		props_reached += rows.size()
		if OS.get_environment("ENCROACH_DEBUG") == "1":
			print("[ENCROACH]   %s: %d prop draws" % [case_id, rows.size()])
		_apply_prop_states(case_id, intensities.get(case_id, intensity_for(case_id)))
	print("[ENCROACH] %d prop draws reached across %d case flats" % [props_reached, prop_rows.size()])
	return props_reached


func _apply_prop_states(case_id: String, value: float) -> void:
	if not prop_rows.has(case_id):
		return
	var rise := smoothstep(0.5, 1.0, value)
	for row in prop_rows[case_id]:
		var m := row.material as ShaderMaterial
		if not is_instance_valid(row.mesh) or (row.mesh as MeshInstance3D).material_override != m:
			continue
		m.set_shader_parameter("mask_amount", Vector4(0.0, 0.35 * value, 0.25 * value, 0.0))
		m.set_shader_parameter("mask2_amount", Vector4(0.0, 0.5 * rise, 0.85 * value, 0.0))


## The rule, in one place: stage sets the floor, manifestation lifts it,
## resolution leaves a residue. ENCROACH_FORCE wins for frames and tests.
func intensity_for(case_id: String) -> float:
	if _forced.has(case_id):
		return float(_forced[case_id])
	var state: Dictionary = RealityState.case_state(case_id)
	if state.is_empty():
		return 0.0
	var stage := str(state.get("stage", "unseen"))
	var base := float(STAGE_INTENSITY.get(stage, 0.0))
	var manifest := clampf(float(state.get("manifestation_intensity", 0.0)), 0.0, 1.0)
	var value := maxf(base, base * 0.5 + manifest * 0.5) if base > 0.0 else manifest * 0.3
	if bool(state.get("resolved", false)) and not bool(state.get("recurrence_pending", false)):
		value = minf(value, RESIDUE)
	return clampf(value, 0.0, 1.0)


func _parse_forced(spec: String) -> void:
	_forced.clear()
	for entry in spec.split(",", false):
		var bits := entry.strip_edges().split(":")
		if bits.size() != 2:
			continue
		for case_id in CASES:
			if str(CASES[case_id].incarnation) == bits[0] or case_id == bits[0]:
				_forced[case_id] = clampf(bits[1].to_float(), 0.0, 1.0)


func _read_substance_keys() -> void:
	var f := FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var profiles: Dictionary = parsed.get("profiles", {})
	for profile_id in profiles:
		var presentation: Dictionary = (profiles[profile_id] as Dictionary).get("presentation", {})
		var inc := str(presentation.get("incarnation_id", ""))
		var keys: Array = presentation.get("substance_keys", [])
		if not inc.is_empty() and keys.size() >= 3 and bool(presentation.get("production_enabled", false)):
			_substance_keys[inc] = keys


func _plates_for(inc: String) -> Dictionary:
	if _plates.has(inc):
		return _plates[inc]
	var keys: Array = _substance_keys.get(inc, [])
	var out := {}
	var slots := ["a", "b", "c"]
	for i in 3:
		var key := str(keys[i])
		var albedo := load("%s/%s/%s/albedo.png" % [PLATE_ROOT, inc, key]) as Texture2D
		var normal := load("%s/%s/%s/normal.png" % [PLATE_ROOT, inc, key]) as Texture2D
		if albedo == null:
			return {}
		out[slots[i] + "_albedo"] = albedo
		if normal != null:
			out[slots[i] + "_normal"] = normal
	_plates[inc] = out
	return out


func _material_for(original: BaseMaterial3D, plates: Dictionary, rect: Vector4,
		floor_y: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("finish_albedo", original.albedo_texture)
	if original.normal_texture != null:
		m.set_shader_parameter("finish_normal", original.normal_texture)
		m.set_shader_parameter("finish_normal_scale", original.normal_scale)
	else:
		m.set_shader_parameter("finish_normal_scale", 0.0)
	if original.roughness_texture != null:
		m.set_shader_parameter("finish_rough", original.roughness_texture)
	m.set_shader_parameter("alpha_cutoff", original.alpha_scissor_threshold
			if original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
	for key in plates:
		m.set_shader_parameter("plate_" + key, plates[key])
	m.set_shader_parameter("unit_rect", rect)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("intensity", 0.0)
	return m


## The case's authored anomaly prop: the beachhead takes the first plate.
func _find_beachhead(witnesses: Node, floor_node: Node, case_id: String) -> Node:
	var scopes: Array = []
	if witnesses != null:
		scopes.append(witnesses)
	scopes.append(floor_node)
	for scope in scopes:
		for node in (scope as Node).find_children("*", "", true, false):
			if not ("case_ids" in node):
				continue
			var ids: Variant = node.get("case_ids")
			if ids is Array and (ids as Array).has(case_id):
				return node
	return null


func _apply_beachhead(case_id: String, value: float) -> void:
	if not beachheads.has(case_id):
		return
	var entry: Dictionary = beachheads[case_id]
	var node: Node = entry.node
	if not is_instance_valid(node):
		return
	var originals: Dictionary = entry.originals
	var inc := str(CASES[case_id].incarnation)
	var plates := _plates_for(inc)
	var want := value >= BEACHHEAD_AT and plates.has("a_albedo")
	var body := _largest_mesh(node)
	if body == null:
		return
	if want and not originals.has(body):
		originals[body] = body.material_override
		var m := StandardMaterial3D.new()
		var base := body.material_override as BaseMaterial3D
		m.albedo_color = base.albedo_color if base != null else Color.WHITE
		m.albedo_texture = plates["a_albedo"]
		if plates.has("a_normal"):
			m.normal_enabled = true
			m.normal_texture = plates["a_normal"]
			m.normal_scale = 0.5
		m.roughness = 0.62
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3.0, 3.0, 3.0)
		body.material_override = m
	elif not want and originals.has(body):
		body.material_override = originals[body]
		originals.erase(body)


static func _largest_mesh(node: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_volume := -1.0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var v := mi.mesh.get_aabb().get_volume()
		if v > best_volume:
			best_volume = v
			best = mi
	return best


static func _unit_rooms(layout: Dictionary, unit: String) -> Array:
	var out: Array = []
	for fl in layout.get("floors", []):
		for room in fl.get("rooms", []):
			if str(room.get("unit", "")) == unit:
				out.append({"rect": room.rect, "floor": fl.id, "z": fl.z})
	return out


## Union of the unit's room rects, in Godot world axes: x0, z0, x1, z1.
static func _union_rect(rooms: Array) -> Vector4:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for room in rooms:
		var r: Array = room.rect
		x0 = minf(x0, float(r[0]))
		y0 = minf(y0, float(r[1]))
		x1 = maxf(x1, float(r[2]))
		y1 = maxf(y1, float(r[3]))
	# layout y is north; Godot z = -y.
	return Vector4(x0, -y1, x1, -y0)


static func _aabb_meets_rect(aabb: AABB, rect: Vector4, slack: float) -> bool:
	return aabb.end.x >= rect.x - slack and aabb.position.x <= rect.z + slack \
			and aabb.end.z >= rect.y - slack and aabb.position.z <= rect.w + slack


static func _world_aabb(mi: MeshInstance3D) -> AABB:
	var local := mi.get_aabb()
	var xf := mi.global_transform
	var result := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		result = result.expand(xf * local.get_endpoint(i))
	return result
