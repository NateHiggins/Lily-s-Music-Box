extends Node3D
## Instrument preflight only: source-derived real navigation/registered frame
## plus unchanged registry protocol with identity-only Node3D owners. No world
## composition, model, motor, body placement, collision or attendance proof.
const Observation := preload("res://tests/harukiya_passage_observation.gd")
const Registry := preload("res://scripts/building/orison_v2_bar_resident_places.gd")
const StreetFrame := preload("res://scripts/building/orison_v2_street_frame.gd")
const LAYOUT := "res://data/orison_v2/harukiya_destination_layout.json"
const FAILED_GUEST := Vector3(3.007965,-2.8,24.50278)
const INPUTS := ["res://tests/HarukiyaPassageObservationTest.tscn",
	"res://tests/harukiya_passage_observation_test.gd", "res://tests/harukiya_passage_observation.gd",
	"res://scripts/building/orison_v2_bar_resident_places.gd", "res://scripts/characters/orison_v2_bar_visit.gd",
	"res://scripts/characters/orison_v2_bar_route.gd", "res://scripts/building/orison_v2_bar_region.gd",
	"res://scripts/building/orison_v2_bar_destination.gd", "res://scripts/building/orison_v2_street_frame.gd",
	"res://data/orison_v2/exterior/street_frame.json", LAYOUT, "res://scripts/game_boot.gd",
	"res://tests/guide_bell_error_capture.gd", "res://data/building_layout.json"]
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var details: Dictionary = {"passages":{}, "owner_protocol":[], "geometry_controls":[]}
var sources: Dictionary = {}
var registry: Registry
var actor: Node3D
var other: Node3D
var frame: Node3D
var graph := AStar3D.new()
var names: Dictionary = {}
var markers: Dictionary = {}
var owner_initial: Array[Transform3D] = []
var directory := ""
var logger
var started := Time.get_ticks_msec()

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	return ok

func _hashes() -> Dictionary:
	var result := {}
	for path: String in INPUTS:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text() if FileAccess.file_exists(path) else ""
	return result

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK:
		get_tree().quit(2); return
	logger=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	sources=_hashes()
	for path: String in INPUTS: _check(not str(sources[path]).is_empty(),"bound input exists "+path)
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var registration:=StreetFrame.load_default()
	if not _check(source is Dictionary and not registration.is_empty(),"real layout and registered street frame load"):
		await _finish(); return
	frame=Node3D.new(); frame.name="SourceNavigationFrame"; add_child(frame)
	frame.position.z=-float(registration.source_threshold_z)
	# These are source navigation markers, not actors or collision geometry.
	for row: Dictionary in source.navigation.nodes:
		var name:=str(row.id)
		if not _check(not names.has(name),"source node is unique "+name): await _finish(); return
		var marker:=Marker3D.new(); marker.name=name; frame.add_child(marker); marker.position=GameBoot.b2g(row.at)
		var index:=graph.get_point_count(); names[name]=index; markers[name]=marker
		graph.add_point(index,marker.global_position)
	for edge: Array in source.navigation.edges:
		if not _check(edge.size()==2 and names.has(str(edge[0])) and names.has(str(edge[1])),"source edge has real endpoints"):
			await _finish(); return
		graph.connect_points(int(names[str(edge[0])]),int(names[str(edge[1])]))
	registry=Registry.new(); registry.name="RealAdmissionRegistry"; add_child(registry)
	# Admission only reads identity eligibility here. No synthetic seat is reserved.
	for id: String in ["transient_guests","rhea_sato"]:
		registry.places[id]={"seat_id":str(Registry.DESTINATION_PLACES[id])}
	actor=Node3D.new(); actor.name="GuestIdentityOnly"; add_child(actor)
	other=Node3D.new(); other.name="OtherIdentityOnly"; add_child(other)
	owner_initial.assign([actor.transform,other.transform])
	details.scope="source-derived geometry; real registry with declared identity eligibility and clearance=true; stationary identity nodes, not physical placed residents"
	details.registered_frame=frame.transform
	for passage: Dictionary in source.navigation.passages:
		if not _check_passage(passage): break
	_check(not Observation.classify(Vector3.ZERO,PackedVector3Array()).valid,"empty geometry fails closed")
	_check(not Observation.classify(Vector3.ZERO,PackedVector3Array([Vector3.ZERO,Vector3.ZERO])).valid,"degenerate source edge fails closed")
	_check(not Observation.classify(Vector3.INF,PackedVector3Array([Vector3.ZERO,Vector3.ONE])).valid,"nonfinite observed position fails closed")
	_check(actor.transform==owner_initial[0] and other.transform==owner_initial[1],"identity-only actors never repositioned")
	_check(registry.claims.is_empty(),"no seat claim or seat owner mutation")
	await _finish()

func _check_passage(row: Dictionary) -> bool:
	var id:=str(row.id)
	var path:=graph.get_id_path(int(names[str(row.a)]),int(names[str(row.b)]))
	if not _check(path.size()>=2,"actual source path resolves "+id): return false
	var points:=PackedVector3Array(); var path_names: Array[String]=[]
	for index: int in path:
		points.append(graph.get_point_position(index)); path_names.append(str(names.find_key(index)))
	var holdings: Array[Node3D]=[]
	for key: String in ["a_holding","b_holding"]:
		for name: String in row[key]: holdings.append(markers[name])
	if not _check(registry.configure_passage(id,holdings),"real passage registry configures authored holdings "+id): return false
	details.passages[id]={"nodes":path_names,"points":points,"holdings":row.a_holding+row.b_holding}
	var allowed: Array[int]=[0]
	if not _check(registry.enqueue_passage(id,"transient_guests",actor,allowed)==holdings[0],"real exact identity queues "+id): return false
	if not _check(registry.try_admit(id,"transient_guests",actor,true),"real FIFO admits declared-clear identity "+id): return false
	var interior_count:=0; var turn_count:=0
	for i in points.size()-1:
		var at:=points[i].lerp(points[i+1],.5)
		var hit:=Observation.check_admission(at,points,registry,id,"transient_guests",actor)
		_check(bool(hit.valid),"source midpoint classifies "+id+"/"+str(i))
		if bool(hit.legacy_requires_admission):
			_check(bool(hit.requires_admission),"legacy-required midpoint remains protected "+id+"/"+str(i))
		if bool(hit.requires_admission):
			interior_count+=1; _check(bool(hit.ok),"real exact admission covers interior midpoint "+id+"/"+str(i))
	for i in range(1,points.size()-1):
		var hit:=Observation.check_admission(points[i],points,registry,id,"transient_guests",actor)
		if bool(hit.legacy_requires_admission):
			_check(bool(hit.requires_admission),"legacy-required internal turn remains protected "+id+"/"+str(i))
		if bool(hit.requires_admission):
			turn_count+=1; _check(bool(hit.ok),"internal source corner keeps exact admission check "+id+"/"+str(i))
	_check(interior_count>0 and turn_count>0,"nonempty real interior and turn controls "+id)
	var near_interior:=_from_end(points,.44)
	var positive:=Observation.check_admission(near_interior,points,registry,id,"transient_guests",actor)
	_check(bool(positive.requires_admission) and bool(positive.ok),"near-end real interior still requires exact admission "+id)
	var wrong_body:=Observation.check_admission(near_interior,points,registry,id,"transient_guests",other)
	var wrong_id:=Observation.check_admission(near_interior,points,registry,id,"rhea_sato",actor)
	_check(not bool(wrong_body.ok) and not bool(wrong_id.ok),"wrong body and wrong resident refused in real registry "+id)
	details.owner_protocol.append({"passage":id,"near_interior":near_interior,"positive":positive,"wrong_body":wrong_body,"wrong_id":wrong_id})
	_check(registry.leave_passage(id,"transient_guests",actor),"exact admitted identity releases via real registry "+id)
	var unleased:=Observation.check_admission(near_interior,points,registry,id,"transient_guests",actor)
	_check(bool(unleased.requires_admission) and not bool(unleased.ok),"unleased interior is detected after actual registry release "+id)
	details.owner_protocol.append({"passage":id,"unleased":unleased})
	var before:=points[0]-(points[1]-points[0]).normalized()*.425
	var after:=points[-1]+(points[-1]-points[-2]).normalized()*.425
	var reverse:=PackedVector3Array()
	for i in range(points.size()-1,-1,-1): reverse.append(points[i])
	for test: Dictionary in [{"label":"before_start","at":before,"points":points,"cap":"before_start"},
		{"label":"after_end","at":after,"points":points,"cap":"after_end"},
		{"label":"reversed_before","at":after,"points":reverse,"cap":"before_start"},
		{"label":"reversed_after","at":before,"points":reverse,"cap":"after_end"}]:
		var hit:=Observation.check_admission(test.at,test.points,registry,id,"transient_guests",actor)
		_check(bool(hit.legacy_requires_admission) and not bool(hit.requires_admission) and bool(hit.ok) and str(hit.endpoint_cap)==str(test.cap),"oriented exterior cap excluded without a lease "+id+"/"+str(test.label))
		details.geometry_controls.append({"passage":id,"label":test.label,"at":test.at,"observation":hit})
	if id=="entry_descent":
		var failed:=Observation.check_admission(FAILED_GUEST,points,registry,id,"transient_guests",actor)
		_check(points[-1].distance_to(Vector3(3.4,-2.8,24.605))<.00001,"actual registered endpoint matches preserved failure")
		_check(bool(failed.legacy_requires_admission) and bool(failed.ok) and not bool(failed.has_admission) and str(failed.endpoint_cap)=="after_end","preserved actual failed coordinate reproduces legacy annulus and excludes released cap")
		_check(float(failed.distance_b)>.4 and float(failed.distance_b)<.45 and float(failed.unclamped_t)>1.0,"preserved failure is beyond endpoint within unchanged annulus")
		details.original_failure={"at":FAILED_GUEST,"receipt":"natural_world_05/world/runtime_contract.json","observation":failed}
	_check_departure_context(id,path,points)
	return true

func _check_departure_context(id: String, path: PackedInt64Array, points: PackedVector3Array) -> void:
	if id == "balcony_stair":
		var failed := Vector3(-4.547699,0,21.77694)
		var end_id := int(names.stair_top)
		var next_id := int(names.gallery_rear)
		var hit := Observation.check_admission(failed,points,registry,id,"transient_guests",actor)
		_check(bool(hit.legacy_requires_admission) and bool(hit.requires_admission) and not bool(hit.ok),"natural06 lateral failure remains geometrically protected without context")
		_check(float(hit.arc_from_b)<.04 and float(hit.distance_b)>.4,"natural06 closest feature lies in reached endpoint zone")
		_check(Observation.is_released_departure(failed,end_id,next_id,path,graph),"natural06 actual reached endpoint and connected outgoing landing edge permit released body")
		details.geometry_controls.append({"passage":id,"label":"natural06_lateral_departure","at":failed,"current":end_id,"next":next_id,"observation":hit})
		var reversed_path := path.duplicate(); reversed_path.reverse()
		_check(Observation.is_released_departure(failed,end_id,next_id,reversed_path,graph),"same source departure works at configured first endpoint when path is reversed")
		var end := graph.get_point_position(end_id)
		var outgoing := graph.get_point_position(next_id)
		_check(not Observation.is_released_departure(failed,end_id,int(names.gallery_rear_e),path,graph),"nonconnected collinear next cannot obtain released exception")
		var wrong_current := outgoing.lerp(graph.get_point_position(int(names.gallery_rear_e)),.1)
		_check(not Observation.is_released_departure(wrong_current,next_id,int(names.gallery_rear_e),path,graph),"connected outgoing edge from wrong current vertex is refused")
		var protected_next := int(path[-2])
		_check(not Observation.is_released_departure(end.lerp(graph.get_point_position(protected_next),.5),end_id,protected_next,path,graph),"actual connected protected next cannot masquerade as departure")
		var nominal := end.lerp(outgoing,.4)
		_check(not Observation.is_released_departure(nominal+Vector3(0,0,.041),end_id,next_id,path,graph),"body farther than ordinary waypoint tolerance from outgoing edge is refused")
		_check(not Observation.is_released_departure(nominal+Vector3(0,.061,0),end_id,next_id,path,graph),"unsupported outgoing height is refused")
		_check(not Observation.is_released_departure(end-(outgoing-end)*.01,end_id,next_id,path,graph),"projection before reached endpoint is refused")
		_check(not Observation.is_released_departure(outgoing+(outgoing-end)*.01,end_id,next_id,path,graph),"projection beyond actual next vertex is refused")
		_check(not Observation.is_released_departure(failed,end_id,999999,path,graph),"missing graph point is refused")
		_check(not Observation.is_released_departure(Vector3.INF,end_id,next_id,path,graph),"nonfinite departure is refused")
		_check(not Observation.is_released_departure(failed,end_id,next_id,PackedInt64Array(),graph),"missing protected path is refused")
		# Synthetic topology negative only: an outgoing edge crosses the protected
		# route far inside. Valid endpoint/edge/projection alone must not suffice.
		var crossing := AStar3D.new()
		for row: Array in [[0,Vector3.ZERO],[1,Vector3(0,0,2)],[2,Vector3(2,0,2)],[3,Vector3(2,0,0)],[4,Vector3(0,0,4)]]:
			crossing.add_point(int(row[0]),row[1])
		for edge: Array in [[0,1],[1,2],[2,3],[0,4]]: crossing.connect_points(int(edge[0]),int(edge[1]))
		var crossing_path := PackedInt64Array([0,1,2,3])
		var crossing_points := PackedVector3Array([Vector3.ZERO,Vector3(0,0,2),Vector3(2,0,2),Vector3(2,0,0)])
		_check(bool(Observation.classify(Vector3(0,0,1),crossing_points).requires_admission),"synthetic far-interior crossing requires admission")
		_check(not Observation.is_released_departure(Vector3(0,0,1),0,4,crossing_path,crossing),"connected outgoing edge crossing far interior cannot bypass nearest endpoint-zone guard")
		crossing.disconnect_points(0,4); crossing.connect_points(4,0,false)
		_check(not Observation.is_released_departure(Vector3(0,0,.2),0,4,crossing_path,crossing),"reverse-only edge cannot authorize forward departure")
	if id == "entry_descent":
		_check(Observation.is_released_departure(FAILED_GUEST,int(names.entrance),int(names.main_aisle_e),path,graph),"natural05 released body follows actual connected aisle edge")
		var first_tread := Vector3(5.24,-.175,20.435)
		var building: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
		var tread: Dictionary={}
		if building is Dictionary:
			for floor: Dictionary in building.get("floors",[]):
				for item: Dictionary in floor.get("furniture",[]):
					if str(item.get("id",""))=="retail_bar_tread0": tread=item
		var supported:=false
		if not tread.is_empty():
			var source_y:=-(first_tread.z-frame.position.z)
			supported=(first_tread.x>=float(tread.rect[0]) and first_tread.x<=float(tread.rect[2])
				and source_y>=float(tread.rect[1]) and source_y<=float(tread.rect[3])
				and absf(first_tread.y-(float(tread.z0)+float(tread.h)))<.00001)
		_check(supported,"lateral first-tread counterexample is supported by exact retained native tread source")
		var hit := Observation.check_admission(first_tread,points,registry,id,"transient_guests",actor)
		_check(bool(hit.requires_admission) and not bool(hit.ok) and float(hit.arc_from_a)<.4,"actual lateral first tread remains an unleased interior despite short endpoint arclength")
		_check(not Observation.is_released_departure(first_tread,int(names.entry_outside),int(names.entry_crate_lower),path,graph),"actual first tread is not on connected outdoor departure edge")
		_check(not Observation.is_released_departure(first_tread,int(names.entry_outside),int(names.entry_sidewalk),path,graph),"actual first tread cannot use nonconnected sidewalk shortcut")
		var allowed: Array[int]=[0]
		_check(registry.enqueue_passage(id,"transient_guests",actor,allowed)!=null and registry.try_admit(id,"transient_guests",actor,true),"real registry admits first-tread exact owner under declared synthetic clearance")
		_check(bool(Observation.check_admission(first_tread,points,registry,id,"transient_guests",actor).ok),"first-tread exact admitted owner passes")
		_check(not bool(Observation.check_admission(first_tread,points,registry,id,"transient_guests",other).ok),"first-tread wrong body remains refused")
		_check(not bool(Observation.check_admission(first_tread,points,registry,id,"rhea_sato",actor).ok),"first-tread wrong resident remains refused")
		_check(registry.leave_passage(id,"transient_guests",actor),"first-tread control releases exact real admission")
		details.geometry_controls.append({"passage":id,"label":"real_first_tread_unleased_negative","at":first_tread,"observation":hit})
	# Lateral offsets of near-end real path samples remain covered and cannot use
	# their actual connected protected edge as a released departure at either end.
	var reverse_points := points.duplicate(); reverse_points.reverse()
	for case: Dictionary in [{"points":points,"end":int(path[-1]),"next":int(path[-2])},
		{"points":reverse_points,"end":int(path[0]),"next":int(path[1])}]:
		var near := _from_end(case.points,.44)+Vector3(.04,0,0)
		var hit := Observation.check_admission(near,points,registry,id,"transient_guests",actor)
		_check(bool(hit.requires_admission) and not bool(hit.ok),"lateral near-end real interior remains protected without owner "+id+"/"+str(case.end))
		_check(not Observation.is_released_departure(near,int(case.end),int(case.next),path,graph),"lateral near-end interior cannot use protected-next exception "+id+"/"+str(case.end))

func _from_end(points: PackedVector3Array, distance: float) -> Vector3:
	var remaining:=distance
	for i in range(points.size()-1,0,-1):
		var length:=points[i].distance_to(points[i-1])
		if remaining<=length: return points[i].lerp(points[i-1],remaining/length)
		remaining-=length
	return points[0]

func _finish() -> void:
	_check(sources==_hashes(),"source bindings remain stable")
	for child: Node in get_children(): remove_child(child); child.free()
	await get_tree().process_frame
	var errors: Array=logger.errors.duplicate()
	_check(errors.is_empty(),"no engine errors"); OS.remove_logger(logger)
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"diagnostic","production_runtime":false,
		"suite":"HarukiyaPassageObservationTest","status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"source-derived navigation/registered-transform observer geometry plus real admission registry with synthetic identity-only owners; no actor movement, native collision, full-world, attendance, art or release-policy qualification",
		"source_hash_algorithm":"SHA256 of LF-normalized UTF8 text","source_hashes":sources,
		"checks":checks,"failures":failures,"engine_errors":errors,"details":details,
		"execution":{"completed":true,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"completion":"listed checks, source stability and transient owner teardown precede serialization"}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(receipt,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	print("PASSAGE OBSERVATION: ",receipt.status," checks=",checks.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() and written else 1)
