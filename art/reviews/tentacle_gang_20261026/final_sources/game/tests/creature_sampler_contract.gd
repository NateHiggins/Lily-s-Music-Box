extends Node
## Loaded-map and recursive sampler probe, not whole-world surface acceptance.
func _ready() -> void:
	var inspector := preload("res://tests/orison_v2_surface_inventory.gd").new()
	var failures: Array[String] = []
	var checks := 0
	var rows := {}
	for part in ["interior","membrane","vacuole"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/tardigrade_%s.gdshader" % part)
		for stock in ["membrane","organ","mineral"]:
			for channel in ["albedo","normal","roughness"]:
				var name := "micro_%s_%s" % [stock,channel]
				material.set_shader_parameter(name,load("res://assets/dream/microscopy/tardigrade_%s/%s.png" % [stock,channel]))
		var row: Dictionary = inspector._material(material)
		rows[part]=row
		for name: String in row.maps:
			checks+=1
			if not row.mip_filters.get(name,false): failures.append("missing nested mip filter: "+name)
			var texture: Dictionary=inspector.texture_rows[row.maps[name]]
			checks+=1
			if not texture.mips or texture.mip_levels<int(log(maxi(texture.width,texture.height))/log(2.0)): failures.append("incomplete loaded mips: "+name)
		checks+=1
		if row.maps.size()!=9: failures.append("expected nine actual PBR bindings: "+part)
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":false,
		"scope":"Loaded microscopy PBR maps and nested shader sampler observation; no composition or visual acceptance",
		"execution":{"completed":true,"timed_out":false,"exit_code":0 if failures.is_empty() else 1},
		"contracts":{"loaded_samplers":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
		"checks":checks,"failures":failures,"materials":rows,"textures":inspector.texture_rows}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	inspector.free()
	print("CREATURE SAMPLERS: ",checks," checks; ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
