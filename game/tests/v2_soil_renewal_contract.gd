extends "res://tests/v2_c_stove_installed_contract.gd"
const GradeInspector=preload("res://tests/v2_grade_stock_inspector.gd")
const GradeWorld=preload("res://tests/orison_v2_city_foundations_test.gd")

func _additional_scope() -> String:
	return super._additional_scope()+" Also verifies current native ground/foundation/apron surfaces, original fixed terrain probes and city underside contacts. No soil capacity, drainage, waterproofing, walked access or whole-building acceptance."

func _additional_checks(world: OrisonV2RuntimeRoot) -> void:
	await super._additional_checks(world)
	var root: Node3D=world.adapter.root
	var inspector:=GradeInspector.new()
	var report: Dictionary=inspector.inspect(root,root.get_node("Ground"),root.get_node("CityFoundations"))
	_check(inspector.failures.is_empty(),"all installed grade stock UV/normal/mip/phase checks pass: "+str(inspector.failures))
	var directory: String=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(directory.path_join("grade_surface_fragment.json"),FileAccess.WRITE)
	_check(file!=null,"open actual installed grade surface fragment")
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.flush()
	var validator:=GradeWorld.new()
	# The inherited validator already supports shared-world validation. Do not
	# let its ordinary ready path create a second full game world.
	validator.set_meta("shared_world_validation",true);add_child(validator)
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	await validator.validate_world(world)
	_check(validator.failures.is_empty(),"original fixed terrain/underside checks pass: "+str(validator.failures))
	var field: Dictionary={}
	var path:=directory.path_join("ground-inspection.json")
	if FileAccess.file_exists(path):field=JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(field.get("terrain_contacts",0))==43 and int(field.get("embedded_stations",0))==2 and int(field.get("original_reproduced",0))==45 and int(field.get("source_qualified_revisions",0))==3,"all 48 original probe positions retain explicit current ownership; 45 historical results and three verified storage-roof contacts")
	additional_contracts.soil_foundations={"executed":true,"status":"PENDING","stock_checks":inspector.checks,"original_world_checks":validator.checks,"families":report.families,"terrain_contacts":field.get("terrain_contacts",0),"embedded_stations":field.get("embedded_stations",0),"original_discovery_reproduced":field.get("original_reproduced",0),"source_qualified_roof_contacts":field.get("source_qualified_revisions",0),"fixed_stations":48,"city_underside_profiles":23,"human_acceptance":false}
	validator.free()
