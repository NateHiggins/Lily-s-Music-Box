extends "res://tests/stool_foot_fit_test.gd"
## Fast isolated source-asset/production-seating bench, not composed gameplay.
func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	var isolated: String=OS.get_environment("STOOL_FOOT_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	if not isolated.begins_with("C:/ov/reports/stool_fit_20261116/") or OS.get_user_data_dir().replace("\\","/").simplify_path()!=isolated.path_join("PleaseRemainOnTheLine"):get_tree().quit(2);return
	if output.is_empty() or FileAccess.file_exists(output.path_join("measurements.json")):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	inputs=_signature()
	native_identity=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_IDENTITY))
	error_logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(error_logger)
	if not await _synthetic_order_check():_finish();return
	var environment:=WorldEnvironment.new()
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.17,.18,.20)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.65
	environment.environment=env;add_child(environment)
	var lamp:=DirectionalLight3D.new();add_child(lamp);lamp.rotation_degrees=Vector3(-45,-35,0);lamp.light_energy=1.5
	var model: Node3D=load("res://assets/props/shop_seating.glb").instantiate();add_child(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part: String=str(draw.name)
		if not part.begins_with("storm_shop_luncheonette_stool"):draw.visible=false;continue
		draw.set_meta("seating_part",part);draw.create_trimesh_collision()
		# Neutral diagnostic material. Final PBR is judged in the composed diner.
		var material:=StandardMaterial3D.new();material.albedo_color=Color(.6,.6,.62) if part.ends_with("chrome") else Color(.32,.08,.06)
		draw.material_override=material
	_capture_native(model)
	fitting_root=Node3D.new();add_child(fitting_root)
	fitting_world=FittingWorld.new();add_child(fitting_world)
	var view:=PassageView.new();fitting_world.add_child(view);view.fitting_root=fitting_root
	var ledger:=SeatLedger.new();fitting_world.add_child(ledger)
	fitting_world.passage_region=view;fitting_world.seat_gestures=ledger
	fitting_counter=CounterSource.new();fitting_counter.set_process(false);fitting_counter.world=fitting_world
	fitting_world.add_child(fitting_counter);fitting_counter.set_process(false)
	var requested: String=OS.get_environment("STOOL_FOOT_RESIDENTS")
	var order: Array[String]=[]
	if requested.is_empty():
		for row: Dictionary in ResidentSource.roster():order.append(str(row.id))
	else:
		for who: String in requested.split(","):order.append(who)
	for who: String in order:
		if not failures.is_empty():break
		await _fit_resident(who)
	_check(completed_residents.size()==order.size(),"all declared bench residents measured")
	_finish()
