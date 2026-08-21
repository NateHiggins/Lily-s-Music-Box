extends Node
## MX-0 — SURFACE CENSUS. What every surface class in the booted building
## actually ships as a material: type, maps, UV law, cutout, state override.
##
##     godot --headless --path game res://tests/SurfaceCensus.tscn
##     CENSUS_OUT=<existing abs dir>    writes surface_census.md and .json
##
## It boots the production BuildingRoot (same discipline as WalkTest and the
## presentation audit) and walks every MeshInstance3D / MultiMeshInstance3D
## surface, classifying by the node's origin and name:
##   glTF geometry under a floor node  ->  class from the buffer name
##                                          (walls, floors_terrazzo, finish, trim, ...)
##   GDScript-built props              ->  class "prop:<Script>"
## and records the effective material (surface override first, then the
## mesh's own): StandardMaterial3D map slots (albedo, normal, roughness,
## metallic, AO, height, detail, emission), UV mode (explicit / triplanar),
## transparency mode, cull; or the ShaderMaterial's shader and bound samplers.
## Classes are aggregated into one table with counts and map coverage, which
## is the census MX-1's rollout order is read from. No opinion is computed
## here — only what is bound.

var root


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	var floor_ids: Array = root.floor_nodes.keys()
	var rows: Array = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		var mesh: Mesh = null
		var is_multi := false
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			is_multi = true
		if mesh == null:
			continue
		var origin := _origin(gi, floor_ids)
		var cls := _class_of(gi, origin)
		for s in mesh.get_surface_count():
			var material: Material = null
			if gi is MeshInstance3D:
				material = (gi as MeshInstance3D).get_surface_override_material(s)
			if material == null:
				material = gi.material_override
			if material == null:
				material = mesh.surface_get_material(s)
			rows.append(_describe(material, cls, origin, gi.name, is_multi))
	var classes := _aggregate(rows)
	var md := _markdown(classes, rows.size())
	print(md)
	var out := OS.get_environment("CENSUS_OUT")
	if not out.is_empty():
		var f := FileAccess.open(out.path_join("surface_census.md"), FileAccess.WRITE)
		if f:
			f.store_string(md)
		var j := FileAccess.open(out.path_join("surface_census.json"), FileAccess.WRITE)
		if j:
			j.store_string(JSON.stringify({"surfaces": rows.size(), "classes": classes}, "  "))
		print("[CENSUS] wrote %s" % out)
	get_tree().quit(0)


func _origin(gi: Node, _floor_ids: Array) -> String:
	# glTF geometry is OWNED by the instantiated import scene; anything a
	# script added under a floor node at runtime has no such owner.
	var cursor: Node = gi
	while cursor != null and cursor != root:
		var ext := cursor.scene_file_path.get_extension()
		if ext == "gltf" or ext == "glb":
			return "gltf" if gi.owner == cursor else "script"
		cursor = cursor.get_parent()
	return "script"


func _class_of(gi: Node, origin: String) -> String:
	var n := gi.name
	if origin == "gltf":
		# F04_floors_terrazzo -> floors_terrazzo ; F04_walls-col -> walls ;
		# F04_finish_f04_w03 -> finish ; F04_furnish_floor_oak -> furnish ;
		# F04_furniture_floor_oak-col -> furniture ; F04_wear_ceiling_fx_drip -> wear
		var parts := n.split("_", false, 1)
		var rest: String = parts[1] if parts.size() > 1 else n
		rest = rest.replace("-col", "")
		for prefix in ["finish", "furnish", "furniture", "wear", "wainscot", "trim",
				"stone_trim", "glazing", "sash", "ceiling", "slabs", "vent_register",
				"fx_ao_decal", "stairs", "passage", "retail", "transit"]:
			if rest.begins_with(prefix):
				return prefix
		if rest.begins_with("walls") or rest.begins_with("floors"):
			return rest
		return rest.get_slice("_", 0)
	# A GDScript-built prop: the nearest ancestor (itself included) carrying a
	# script names it; failing that the first authored (non-@) ancestor name.
	var cursor: Node = gi
	var named := ""
	while cursor != null and cursor != root:
		var script: Script = cursor.get_script()
		if script != null and not script.resource_path.is_empty():
			return "prop:" + script.resource_path.get_file().get_basename()
		if named.is_empty() and not cursor.name.begins_with("@"):
			named = cursor.name
		cursor = cursor.get_parent()
	return "node:" + (named.rstrip("0123456789") if not named.is_empty() else "unknown")


func _describe(material: Material, cls: String, origin: String, node_name: String,
		is_multi: bool) -> Dictionary:
	var d := {"class": cls, "origin": origin, "node": node_name, "multimesh": is_multi,
			"kind": "none", "albedo": false, "normal": false, "roughness": false,
			"metallic": false, "ao": false, "height": false, "detail": false,
			"emission": false, "triplanar": false, "world_uv": origin == "gltf",
			"transparency": "opaque", "cull": "back", "shader": "", "samplers": 0,
			"state": ""}
	if material == null:
		return d
	if material is BaseMaterial3D:
		var m := material as BaseMaterial3D
		d.kind = "StandardMaterial3D"
		d.albedo = m.albedo_texture != null
		d.normal = m.normal_enabled and m.normal_texture != null
		d.roughness = m.roughness_texture != null
		d.metallic = m.metallic_texture != null
		d.ao = m.ao_enabled and m.ao_texture != null
		d.height = m.heightmap_enabled and m.heightmap_texture != null
		d.detail = m.detail_enabled
		d.emission = m.emission_enabled
		d.triplanar = m.uv1_triplanar
		d.transparency = {0: "opaque", 1: "alpha", 2: "scissor", 3: "hash", 4: "depth_pre"}.get(int(m.transparency), str(m.transparency))
		d.cull = {0: "back", 1: "front", 2: "off"}.get(int(m.cull_mode), str(m.cull_mode))
	elif material is ShaderMaterial:
		var sm := material as ShaderMaterial
		d.kind = "ShaderMaterial"
		d.shader = sm.shader.resource_path.get_file() if sm.shader else "NULL"
		var samplers := 0
		if sm.shader:
			for u in sm.shader.get_shader_uniform_list():
				if int(u.get("type", -1)) == TYPE_OBJECT:
					samplers += 1
					var bound: Variant = sm.get_shader_parameter(str(u.name))
					var uname := str(u.name)
					if bound != null:
						if uname.contains("albedo"): d.albedo = true
						if uname.contains("normal"): d.normal = true
						if uname.contains("rough"): d.roughness = true
						if uname.contains("height"): d.height = true
		d.samplers = samplers
		if d.shader == "floor_coverage.gdshader":
			d.state = "coverage (MC-P)"
		elif d.shader == "wall_encroachment.gdshader":
			d.state = "encroachment (WK-1)"
	else:
		d.kind = material.get_class()
	return d


func _aggregate(rows: Array) -> Dictionary:
	var classes := {}
	for r in rows:
		var key := "%s|%s" % [r.origin, r["class"]]
		if not classes.has(key):
			classes[key] = {"origin": r.origin, "class": r["class"], "surfaces": 0,
					"standard": 0, "shader": 0, "none": 0, "albedo": 0, "normal": 0,
					"roughness": 0, "metallic": 0, "ao": 0, "height": 0, "detail": 0,
					"emission": 0, "triplanar": 0, "scissor": 0, "alpha_blend": 0,
					"two_sided": 0, "shaders": {}, "states": {}, "multimesh": 0}
		var c: Dictionary = classes[key]
		c.surfaces += 1
		if r.kind == "StandardMaterial3D": c.standard += 1
		elif r.kind == "ShaderMaterial": c.shader += 1
		else: c.none += 1
		for k in ["albedo", "normal", "roughness", "metallic", "ao", "height", "detail",
				"emission", "triplanar", "multimesh"]:
			if bool(r[k]): c[k] += 1
		if r.transparency == "scissor": c.scissor += 1
		if r.transparency == "alpha": c.alpha_blend += 1
		if r.cull == "off": c.two_sided += 1
		if not str(r.shader).is_empty():
			c.shaders[r.shader] = int(c.shaders.get(r.shader, 0)) + 1
		if not str(r.state).is_empty():
			c.states[r.state] = int(c.states.get(r.state, 0)) + 1
	return classes


func _markdown(classes: Dictionary, total: int) -> String:
	var keys: Array = classes.keys()
	keys.sort_custom(func(a, b):
		var ca: Dictionary = classes[a]
		var cb: Dictionary = classes[b]
		if ca.origin != cb.origin:
			return ca.origin < cb.origin
		return int(ca.surfaces) > int(cb.surfaces))
	var lines: Array[String] = []
	lines.append("# Surface census — %d surfaces" % total)
	lines.append("")
	lines.append("| origin | class | surfaces | std | shader | albedo | normal | rough | metal | AO | height | detail | emis | triplanar | scissor | blend | 2-sided | shaders / states |")
	lines.append("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")
	var folded := {}
	for k in keys:
		var c: Dictionary = classes[k]
		if int(c.surfaces) < 3:
			var fk: String = c.origin
			if not folded.has(fk):
				folded[fk] = {"n": 0, "surfaces": 0, "names": []}
			folded[fk].n += 1
			folded[fk].surfaces += int(c.surfaces)
			folded[fk].names.append(str(c["class"]))
			continue
		var extra: Array[String] = []
		for s in c.shaders:
			extra.append("%s×%d" % [s, int(c.shaders[s])])
		for s in c.states:
			extra.append("%s×%d" % [s, int(c.states[s])])
		lines.append("| %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s |" % [
				c.origin, c["class"], c.surfaces, c.standard, c.shader, c.albedo, c.normal,
				c.roughness, c.metallic, c.ao, c.height, c.detail, c.emission, c.triplanar,
				c.scissor, c.alpha_blend, c.two_sided, ", ".join(extra)])
	return "\n".join(lines) + "\n"
