extends Node
## Slice 80: the source census of one procedural instrument in the service_instruments
## source-plan schema (how the signal register's M05 census was taken). Copy beside game/tests to run. CENSUS_SCRIPT names the prop script, CENSUS_TYPE its prop_type, CENSUS_OUT the JSON file written.
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor: Node3D = load(OS.get_environment("CENSUS_SCRIPT")).new()
	actor.set("prop_type", OS.get_environment("CENSUS_TYPE"))
	add_child(actor)
	for i in 3: await get_tree().process_frame
	var draws := actor.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh != null)
	var out: Array = []
	for i in draws.size():
		var d: MeshInstance3D = draws[i]
		var t: Transform3D = actor.global_transform.affine_inverse() * d.global_transform
		var b := t.basis
		var entry := {"basis": [[b.x.x, b.x.y, b.x.z], [b.y.x, b.y.y, b.y.z], [b.z.x, b.z.y, b.z.z]], "index": i,
			"materials": [], "name": str(d.name), "path": str(actor.get_path_to(d)),
			"position": [t.origin.x, t.origin.y, t.origin.z], "type": d.mesh.get_class(), "visible": d.visible}
		if d.mesh is BoxMesh:
			var size: Vector3 = (d.mesh as BoxMesh).size
			entry["size"] = [size.x, size.y, size.z]
		elif d.mesh is CylinderMesh:
			var c := d.mesh as CylinderMesh
			entry["bottom_radius"] = c.bottom_radius; entry["height"] = c.height
			entry["radial_segments"] = c.radial_segments; entry["top_radius"] = c.top_radius
		for s in d.mesh.get_surface_count():
			var m := d.get_active_material(s)
			var row := {"albedo": "", "class": m.get_class() if m else "", "color": [0, 0, 0, 1], "metallic": 0.0, "name": m.resource_name if m else "", "roughness": 1.0}
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				row["albedo"] = bm.albedo_texture.resource_path if bm.albedo_texture else ""
				row["color"] = [bm.albedo_color.r, bm.albedo_color.g, bm.albedo_color.b, bm.albedo_color.a]
				row["metallic"] = bm.metallic; row["roughness"] = bm.roughness
			entry["materials"].append(row)
		out.append(entry)
	var file := FileAccess.open(OS.get_environment("CENSUS_OUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	print("CENSUS: draws=%d" % out.size())
	get_tree().quit(0)
