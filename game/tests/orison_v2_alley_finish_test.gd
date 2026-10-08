extends "res://tests/orison_v2_alley_groundworks_test.gd"
## Scoped optical review; inherited full alley/well walking and mapping checks.
var finish_draws: Array[MeshInstance3D] = []
var tuned: Array[Material] = []
var finish_checks := 0

func _init() -> void:
	route_label = "V2 ALLEY FINISH"

func verify(value: bool, label: String) -> void:
	finish_checks += 1
	if not value: failures.append(label)

func _route() -> void:
	var alley: Node3D = world.adapter.root.get_node("ServiceAlley")
	for draw: MeshInstance3D in alley.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("v2_alley_source"): continue
		finish_draws.append(draw);tuned.append(draw.material_override)
		var role := str(draw.name)
		if draw.get_parent().name == "Groundworks": role = "Iron" if role.contains("cast_iron") else "Paving"
		var recipe: Dictionary = alley.finish_recipes[role]
		var mat := draw.material_override as StandardMaterial3D
		verify(mat != null,"standard alley finish")
		if mat == null: continue
		var reference := MatLib.get_mat(str(recipe.catalog_key))
		verify(mat != reference and mat != draw.get_meta("v2_alley_source"),"local immutable finish copy")
		verify(mat.uv1_triplanar == (role in ["Brick","Coping"]) and mat.uv1_scale.is_equal_approx(reference.uv1_scale),"retained boundary projection and metric ground charts at catalogue scale")
		verify(is_equal_approx(mat.normal_scale,float(recipe.normal)) and is_equal_approx(mat.roughness,float(recipe.roughness)) and is_equal_approx(mat.metallic,float(recipe.metallic)),"exact finish response")
		var tint: Array = recipe.tint
		verify(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"exact local tint")
		for pair: Array in [[mat.albedo_texture,reference.albedo_texture],[mat.normal_texture,reference.normal_texture],[mat.roughness_texture,reference.roughness_texture]]:
			verify(pair[0] == pair[1] and pair[0].get_image().has_mipmaps(),"catalogue map and loaded mip chain")
	verify(finish_draws.size()==34,"two boundary and thirty-two groundwork finish groups")
	verify(MatLib.get_mat("cast_iron").uv1_triplanar and is_equal_approx(MatLib.get_mat("cast_iron").normal_scale,0.35),"shared original iron preserved")
	await super._route()
	var file := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("alley-finish.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","finish_checks":finish_checks,"finish_groups":finish_draws.size(),"mapping_checks":mapping_checks,"waypoints":trace.size(),"failures":failures},"\t")+"\n")
	print("ALLEY FINISH: ",finish_checks," checks; ",failures.size()," failures")

func _view(label: String, local_target: Vector3) -> void:
	if label not in ["out_4","out_6"] and not label.begins_with("well_crossing_"): return
	player.camera.look_at(world.adapter.root.to_global(local_target))
	player.set_lamp_enabled(true)
	var layers: Array[CanvasLayer] = []
	for layer: CanvasLayer in player.find_children("*","CanvasLayer",true,false):
		if layer.visible: layers.append(layer);layer.hide()
	for before: bool in [true,false]:
		for i in finish_draws.size(): finish_draws[i].material_override = finish_draws[i].get_meta("v2_alley_source") if before else tuned[i]
		await get_tree().create_timer(.15).timeout
		await super._capture(label+("_before" if before else "_after"))
	for layer in layers: layer.show()

func _capture(_label: String) -> void:
	pass # The paired views above are taken at actual walked stations.

func _inspection_views() -> void:
	pass # Keep the native below-grade plate separate from playable viewpoints.
