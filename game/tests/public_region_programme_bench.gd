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
	# Exercise the retained source box after the same authored metre-UV
	# conversion used by the street. Its concrete mesh subclass is not authority.
	var paving := preload("res://tests/orison_v2_street_paving_details_test.gd").new()
	var primitive := BoxMesh.new();primitive.size=Vector3(2.,.12,3.)
	check(paving._retained_box(primitive,primitive.size),"retained primitive box has its source geometry")
	var converted := preload("res://scripts/building/v2_metre_box_uv.gd").chart(primitive)
	check(converted is ArrayMesh and paving._retained_box(converted,primitive.size),"authored UV ArrayMesh retains the exact source box")
	check(not paving._retained_box(converted,Vector3(2.,.13,3.)),"different physical box dimensions are refused")
	var arrays := converted.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];points[0]*=.9;arrays[Mesh.ARRAY_VERTEX]=points
	var deformed := ArrayMesh.new();deformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	check(not paving._retained_box(deformed,primitive.size),"a deformed corner is refused even with the same enclosing bounds")
	paving.free()
	var separate := ArrayMesh.new();var solid_faces := PackedVector3Array()
	for shift: Vector3 in [Vector3.LEFT*2.,Vector3.RIGHT*2.]:
		for vertex: Vector3 in primitive.get_faces():solid_faces.append(vertex+shift)
	var solid_arrays: Array=[];solid_arrays.resize(Mesh.ARRAY_MAX);solid_arrays[Mesh.ARRAY_VERTEX]=solid_faces
	separate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,solid_arrays)
	var components:=preload("res://scripts/building/orison_v2_furnishing_clearance.gd").component_bounds(separate)
	check(components.size()==2,"separate solid stocks retain two fitting envelopes after material batching")
	check(not components[0].has_point(Vector3.ZERO) and not components[1].has_point(Vector3.ZERO),"space between separate bearings is not filled by a combined envelope")
	var finish_box := AABB(Vector3.ZERO,Vector3.ONE)
	check(preload("res://tests/v2_furnishing_clearance_review.gd")._triangle_box(Vector3(-1,.5,.5),Vector3(2,.5,.5),Vector3(.5,2,.5),finish_box),"finish review detects a crossing triangle")
	check(not preload("res://tests/v2_furnishing_clearance_review.gd")._triangle_box(Vector3(-1,2,.5),Vector3(2,2,.5),Vector3(.5,3,.5),finish_box),"finish review retains clear space inside a leaning prop envelope")
	if not OS.get_environment("ORISON_FINISH_CANDIDATE_GLTF").is_empty():await _blanket_corner_bench()
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
		FileAccess.open(out.path_join("public_programme_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Public frames, routes, bounded ownership, retained box UV conversion and finish triangle predicates only; no actual route walk, loaded module binding or human acceptance."},"\t"))
	print("PUBLIC REGION PROGRAMME BENCH ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _blanket_corner_bench() -> void:
	var fit=preload("res://scripts/building/orison_v2_furnishing_clearance.gd")
	var review=preload("res://tests/v2_furnishing_clearance_review.gd").new()
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var path:=OS.get_environment("ORISON_FINISH_CANDIDATE_GLTF")
	check(document.append_from_file(path,state)==OK,"candidate native GLB decodes for bounded fitting")
	var fixture_path:=OS.get_environment("ORISON_FINISH_CANDIDATE_FIXTURE")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(FileAccess.get_sha256(path)==fixture.asset_sha256,"bounded candidate is the original exported native asset")
	var model:=document.generate_scene(state) as Node3D
	check(model!=null,"candidate native scene exists")
	if model==null:review.free();return
	var shell:=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.production_materials=true
	add_child(shell)
	await get_tree().physics_frame
	var stock: Array[Dictionary]=fit.finish_stock(shell)
	check(stock.size()>1000,"bounded shell contains actual production millwork")
	var walls: Array[Dictionary]=preload("res://scripts/building/orison_v2_millwork.gd").collect_wall_stock(shell)
	var bodies: Array[Node3D]=[]
	for identity: String in ["3D_blanket_a","3D_blanket_b"]:
		var body:=Node3D.new();body.name=identity+"_FitBench";body.set_meta("v2_furniture_kind","blanket");shell.add_child(body)
		for anchor: Dictionary in shell.layout.anchors:
			if str(anchor.id)==identity:
				body.position=Vector3(anchor.position[0],shell.level_y[str(anchor.level)]+float(anchor.position[1]),anchor.position[2]);body.rotation.y=float(anchor.yaw)
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if not str(draw.name).begins_with("DomesticObject139__"):continue
			var copy:=MeshInstance3D.new();copy.mesh=draw.mesh;copy.transform=draw.transform;body.add_child(copy)
		check(body.get_child_count()==4,"bounded blanket has every native material partition")
		bodies.append(body)
	var offsets: Array=[]
	for body: Node3D in bodies:
		var boxes: Array[AABB]=fit.parts(shell,body)
		var bounds:=boxes[0]
		for box: AABB in boxes:bounds=bounds.merge(box)
		var nearby: Array[Dictionary]=[];var obstacles: Array[AABB]=[]
		for finish: Dictionary in stock:
			if bounds.grow(1.).intersects(finish.bounds):nearby.append(finish)
		for wall: Dictionary in walls:
			if bounds.grow(1.).intersects(wall.bounds):obstacles.append(wall.bounds)
		for other: Node3D in bodies:
			if other!=body:obstacles.append_array(fit.parts(shell,other))
		var normal: Vector3=body.basis*Vector3.FORWARD
		var result: Dictionary=fit.displacement(boxes,nearby,true,Vector2(float(shell.level_y["F03"])+.18,float(shell.level_y["F03"])+float(shell.layout.dimensions.clear_height)-.10),obstacles)
		check(result.resolved,"actual study corner admits a supported fit: "+str(body.name))
		check(absf((result.offset as Vector3).dot(normal))<.000001,"sideways refit retains the original plaster plane")
		body.position+=result.offset
		check(fit.overlaps(fit.parts(shell,body),nearby,Vector3.ZERO,fit.HANGING_GAP).is_empty(),"individual native stocks clear all study finish bands")
		check(review._leaning_tool_clear(shell,body,nearby),"actual native triangles clear both adjoining walls' trim")
		for contact: Dictionary in fixture.contacts:
			if str(contact.assembly)!="DomesticObject139":continue
			var at:=body.to_global(Vector3(contact.point[0],contact.point[1],contact.point[2]))
			var direction: Vector3=body.global_basis*Vector3(contact.direction[0],contact.direction[1],contact.direction[2])
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+direction*.004,at-direction*.004,1))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.dot(direction)>.99,"each fitted blanket pad retains its actual wall bearing")
		offsets.append({"id":str(body.name),"offset":[result.offset.x,result.offset.y,result.offset.z]})
	print("BOUNDED BLANKET CORNER: ",JSON.stringify(offsets))
	shell.free();model.free();review.free()
	await get_tree().physics_frame
