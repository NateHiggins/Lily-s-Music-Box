extends "res://tests/orison_v2_city_sweep.gd"
## Read retained stage signal geometry without authoring a second signal owner.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"stage fitting reads the connected production city")
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var bar: OrisonV2BarRegion=world.bar_region
	var floor: Dictionary=bar.source_layout.floors.filter(func(row):return row.id=="F01")[0]
	var markers: Array=floor.markers.filter(func(row):return str(row.id).begins_with("F01_BAR_STAGE") or str(row.id).begins_with("F01_KARAOKE"))
	check(markers.size()==3,"original stage sign and both speaker markers are retained")
	var actor: Node3D=bar.actors.get_node("F01_BAR_STAGE_SIGN")
	var low:=Vector3(INF,INF,INF);var high:=-low
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for vertex: Vector3 in draw.mesh.get_faces():
			var at:=bar.to_local(draw.to_global(vertex));low=low.min(at);high=high.max(at)
	check(low.is_finite() and high.is_finite() and low.x<high.x,"retained signal geometry has measurable bounds")
	var result:={"evidence_class":"INERT","markers":markers,"sign_bounds":[[low.x,-high.z,low.y],[high.x,-low.z,high.y]],"checks":checks,"failures":failures}
	var output:=OS.get_environment("BAR_STAGE_FIT_OUT")
	if output.is_empty():output=ProjectSettings.globalize_path("res://../tmp/bar-stage/source-fit.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"stage fit output can be written")
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("BAR STAGE FIT: checks=",checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
