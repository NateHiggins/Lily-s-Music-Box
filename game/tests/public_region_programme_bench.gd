extends Node3D
## INERT public frame/owner diagnosis; this is not a played spatial contract.
const Resolver=preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const Programme=preload("res://scripts/building/orison_v2_public_region_programmes.gd")
const Exterior=preload("res://scripts/building/orison_v2_exterior_cell.gd")
var checks:=0
var failures: Array[String]=[]

func _ready() -> void:_run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
	var resolver: Variant=Resolver.load_default()
	check(resolver.is_valid(),"all six public regions resolve")
	if not resolver.is_valid():print(resolver.errors);_finish();return
	var programmes:=Programme.new()
	check(programmes.configure(resolver),"all public instances have exactly one geometry provider")
	if programmes.bounded_instance_ids().is_empty():_finish();return
	check(programmes.body_transform("StreetBoundaries").is_equal_approx(Transform3D.IDENTITY),"retained construction keeps its physical frame")
	check(programmes.body_transform("VantryArcade").origin.distance_to(Vector3(0,0,-9.795))<.000004,"arcade keeps actual old source-to-world transform through public surfaces")
	check(resolver.instance_ids().size()==6 and programmes.bounded_instance_ids().size()==2,"four retained module instances are not duplicate bounded-cell geometry")
	for id: String in ["ROUTE_STREET_TO_ARCADE","ROUTE_ARCADE_TO_STREET","ROUTE_STREET_TO_CONSTRUCTION","ROUTE_CONSTRUCTION_TO_STREET"]:
		var route: Dictionary=programmes.route(id)
		check(not route.is_empty() and route.nodes.size()>=7,"named route resolves through source surfaces: "+id)
		for node: Dictionary in route.get("nodes",[]):check((node.placement.position as Vector3).is_finite(),"finite route point: "+str(node.id))
	var source: Dictionary=Programme.read_default()
	var invalid:=source.duplicate(true);invalid.modules[1].source_origin_m[0]+=1.
	check(not Programme.new().configure(resolver,invalid),"disagreeing portal/throat/hall source frames are refused")
	invalid=source.duplicate(true);invalid.bounded_instance_ids.append("ARCADE_PORTAL_01")
	check(not Programme.new().configure(resolver,invalid),"duplicate geometry ownership is refused")
	invalid=source.duplicate(true);invalid.modules.remove_at(0)
	check(not Programme.new().configure(resolver,invalid),"missing construction ownership is refused")
	var cell:=Exterior.new()
	check(not cell.configure_dependencies({"geometry_instance_ids":["STREET_ORISON_01",42]}),"invalid ownership list is refused without retaining its valid prefix")
	check(cell.configure_dependencies({"geometry_instance_ids":["STREET_ORISON_01","SHOP_BODEGA"],"spatial_resolver":resolver}),"valid ownership can be configured after refused partial input")
	add_child(cell)
	check(not cell.startup_failed,"bounded source composes with four independently owned public modules")
	check(cell.instance_node("STREET_ORISON_01")!=null and cell.instance_node("SHOP_BODEGA")!=null,"two existing bounded physical cells are built")
	check(cell.instance_node("ARCADE_PORTAL_01")==null,"bounded builder does not fabricate imported arcade stock")
	check(cell.player.global_position.distance_to(Vector3(0,.04,.58))<.01,"default player remains on existing street arrival")
	cell.teardown();cell.free();programmes.teardown()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("public_programme_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Public frames, routes and bounded geometry ownership only; no actual route walk, loaded module binding or human acceptance."},"\t"))
	print("PUBLIC REGION PROGRAMME BENCH ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
