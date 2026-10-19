extends "res://tests/v2_fire_nozzle_coupling_bench.gd"
## Imported surface preflight before the complete retained hand programme.
func _run() -> void:
	var stock:=preload("res://scripts/props/fire_nozzle_detail_stock.gd").new()
	if not check(stock.load_stock(),"six native nozzle detail parts load"):get_tree().quit(1);return
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for key: String in stock.meshes:metrics._check_cap_mapping(stock.meshes[key],true)
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	for key: String in stock.finishes:
		var finish: StandardMaterial3D=stock.finishes[key]
		check(finish.normal_enabled and not finish.uv1_triplanar,"authored detailed nozzle normal mapping: "+key)
		for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:check(texture.get_image().get_mipmap_count()>0,"loaded detailed nozzle mip chain: "+key)
	if not failures.is_empty():get_tree().quit(1);return
	await super._run()
