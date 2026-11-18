extends Node3D
## Isolated current native4A threshold, exact production placement recipe.
## Query diagnostic only: no actor, floor surrogate, collider edits or tolerance changes.
const Attendance := preload("res://tests/harukiya_attendance_test.gd")
const Objects := preload("res://scripts/building/orison_v2_native_domestic_objects.gd")
const Connection := preload("res://scripts/building/orison_v2_world_connection.gd")
const Resolver := preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")
const LAYOUT := "res://data/orison_v2_blockout.json"
const GEOMETRY := "res://data/orison_v2/exterior/exterior_geometry.json"
const FAILED := Vector3(-9.110999,9.623434,-8.400002)
const PREVIOUS_Y := 9.613001
const STEP := .0175
var errors: Array[String]=[]
var rows: Array[Dictionary]=[]
var control_rows: Array[Dictionary]=[]
var triangles: Array[Dictionary]=[]
var metadata: Dictionary={}
var inputs: Dictionary={}
var directory: String
var frame_root: Node3D
var body: StaticBody3D
var factory
var logger
func require(ok: bool, message: String) -> bool:
	if not ok: errors.append(message); push_error("PETER SUPPORT: "+message)
	return ok
func hashes() -> Dictionary:
	var paths: Array[String]=[get_script().resource_path,scene_file_path,LAYOUT,GEOMETRY,Connection.CONFIG_PATH,Resolver.DATA_PATH,
		"res://data/orison_v2_shared_frames.json",Objects.PATH,
		"res://scripts/building/orison_v2_native_domestic_objects.gd",
		"res://scripts/building/orison_v2_native_domestic_furniture.gd",
		"res://scripts/building/orison_v2_world_connection.gd",
		"res://scripts/building/orison_v2_exterior_spatial_resolver.gd",
		"res://scripts/building/orison_v2_frame_contract.gd",
		"res://scripts/building/orison_v2_anchor_adapter.gd",
		"res://scripts/building/orison_v2_name_index.gd",
		"res://scripts/building/orison_v2_blockout.gd",
		"res://scripts/building/orison_v2_domestic_furniture.gd",
		"res://scripts/characters/orison_v2_resident_route.gd",
		"res://tests/harukiya_attendance_test.gd"]
	var stock: Dictionary=Connection.read_object(Objects.PATH)
	paths.append(str(stock.get("asset","")))
	var result: Dictionary={}
	for path: String in paths: result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result
func _ready() -> void: run.call_deferred()
func run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if not require(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"writable SHOT_DIR"): get_tree().quit(2); return
	logger=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	inputs=hashes()
	if not require(not inputs.values().has("MISSING"),"all exact diagnostic inputs exist"): finish(); return
	var layout: Dictionary=Connection.read_object(LAYOUT)
	var source: Dictionary=Connection.unique_record(layout.anchors,"4A_threshold")
	var level: Dictionary=Connection.unique_record(layout.levels,str(source.get("level","")))
	if not require(not source.is_empty() and not level.is_empty(),"unique actual threshold anchor and level"): finish(); return
	var resolver: Variant=Resolver.load_default()
	var registration: Dictionary=Connection.prepare(layout,Connection.read_object(GEOMETRY),resolver,Connection.read_object(Connection.CONFIG_PATH))
	if not require(not registration.is_empty(),"same production world registration"): finish(); return
	frame_root=Node3D.new(); frame_root.name="OrisonV2ThresholdFrame"; frame_root.transform=registration.interior_transform; add_child(frame_root)
	# Exactly _build_anchors' source position/level/yaw; mount_consumer owns placement.
	var anchor:=Node3D.new(); anchor.name="4A_threshold"
	anchor.position=Vector3(float(source.position[0]),float(level.y)+float(source.position[1]),float(source.position[2]))
	anchor.rotation.y=float(source.get("yaw",0.0)); frame_root.add_child(anchor)
	factory=Objects.new()
	if not require(factory.prepare(),"unchanged actual native object factory prepares"): finish(); return
	body=StaticBody3D.new(); body.set_meta("v2_furniture_id","4A_threshold");body.set_meta("v2_furniture_kind","threshold")
	if not require(factory.mount_on(body,"4A_threshold"),"factory mounts original variant without collider rewrites"): body.free(); body=null; finish(); return
	var adapter:=Adapter.new(frame_root)
	if not require(adapter.mount_consumer("4A_threshold",body),"production adapter applies exact registered anchor transform"): body.free();body=null;finish();return
	metadata={"engine":Engine.get_version_info(),"physics_ticks_per_second":Engine.physics_ticks_per_second,"anchor_source":source,"level":level,"world_frame":frame_root.global_transform,"body_transform":body.global_transform,
		"failed_world":FAILED,"failed_threshold_local":body.to_local(FAILED),"previous_feet_y":PREVIOUS_Y,"step_m":STEP,"variant":body.get_meta("v2_native_domestic_variant","")}
	var shapes: Array[Dictionary]=[]
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			shapes.append({"node":str(child.get_path()),"type":child.shape.get_class(),"local_transform":child.transform,"global_transform":child.global_transform})
	metadata.shapes=shapes
	collect_triangles()
	await get_tree().physics_frame; await get_tree().physics_frame
	for frame in 8:
		for index in range(-2,3):
			# Peter advances in -X. Negative indices are preceding step positions.
			var point:=FAILED+Vector3(-float(index)*STEP,0,0)
			var space:=get_world_3d().direct_space_state
			var fixed_before: Dictionary=ray(space,point+Vector3.UP*.03,point-Vector3.UP*.03)
			var motor_origin:=Vector3(point.x,PREVIOUS_Y,point.z)
			var long_hit: Dictionary=ray(space,motor_origin+Vector3.UP*.34,motor_origin-Vector3.UP*.5)
			var observed_at:=point
			if not long_hit.is_empty(): observed_at.y=float(long_hit.position.y)
			var short_hit: Dictionary=ray(space,observed_at+Vector3.UP*.03,observed_at-Vector3.UP*.03)
			var fixed_after: Dictionary=ray(space,point+Vector3.UP*.03,point-Vector3.UP*.03)
			if index == 0 and not long_hit.is_empty():
				var before := Vector3(point.x+STEP,PREVIOUS_Y,point.z)
				var grounded: Vector3 = long_hit.position
				var positive := Attendance.motion_witness(space,before,grounded,1.0/60.0,false)
				var negative := Attendance.motion_witness(space,before,grounded+Vector3.UP*.01,1.0/60.0,false)
				control_rows.append({"frame":Engine.get_physics_frames(),"grounded":positive,"floating_10mm":negative})
				require(bool(positive.clear),"actual observer accepts native grounded threshold point")
				require(not bool(negative.clear),"actual observer rejects10mm unsupported lift")
			rows.append({"frame":Engine.get_physics_frames(),"sample_frame":frame,"step_index":index,"world_point":point,"threshold_local":body.to_local(point),
				"motor_long":long_hit,"observer_at_motor_hit":short_hit,"observer_at_recorded_feet_before":fixed_before,"observer_at_recorded_feet_after":fixed_after,
				"motor_observer_gap_m":absf(float(long_hit.position.y)-float(short_hit.position.y)) if not long_hit.is_empty() and not short_hit.is_empty() else -1.0,
				"original_observer_tolerance_m":.003,
				"independent_geometry":triangle_witness(observed_at+Vector3.UP*.03,observed_at-Vector3.UP*.03,long_hit,short_hit)})
		await get_tree().physics_frame
	finish()
func ray(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3) -> Dictionary:
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
	if hit.is_empty(): return {}
	var collider:=hit.collider as CollisionObject3D
	var shape_index: int=int(hit.get("shape",-1)); var shape_node: Object=null
	if collider!=null and shape_index>=0: shape_node=collider.shape_owner_get_owner(collider.shape_find_owner(shape_index))
	return {"from":start,"to":end,"position":hit.position,"normal":hit.normal,"shape_index":shape_index,"face_index":hit.get("face_index",-1),
		"collider":str(collider.get_path()) if collider!=null else str(hit.collider),"collider_id":collider.get_instance_id() if collider!=null else 0,
		"shape_node":str(shape_node.get_path()) if shape_node is Node else str(shape_node),"body_transform":collider.global_transform if collider!=null else Transform3D.IDENTITY}
## Extract actual physics faces, not render AABBs or authored proxy bounds.
func collect_triangles() -> void:
	var shape_rows: Array[Dictionary]=[]
	for owner_id: int in body.get_shape_owners():
		var pose: Transform3D=body.global_transform*body.shape_owner_get_transform(owner_id)
		for index in body.shape_owner_get_shape_count(owner_id):
			var shape: Shape3D=body.shape_owner_get_shape(owner_id,index)
			var shape_index: int=body.shape_owner_get_shape_index(owner_id,index)
			if not require(shape is ConcavePolygonShape3D,"native threshold shape is an actual concave triangle surface"): continue
			var faces: PackedVector3Array=(shape as ConcavePolygonShape3D).get_faces()
			if not require(faces.size()%3==0,"complete native triangle faces"): continue
			shape_rows.append({"shape_index":shape_index,"face_count":faces.size()/3,"world_pose":pose,"backface_collision":(shape as ConcavePolygonShape3D).backface_collision})
			for face in range(0,faces.size(),3):
				triangles.append({"shape_index":shape_index,"face_index":face/3,
					"a":pose*faces[face],"b":pose*faces[face+1],"c":pose*faces[face+2]})
	metadata.independent_triangle_shapes=shape_rows
	metadata.independent_triangle_count=triangles.size()

## Scalar float arithmetic avoids Vector3's intermediate float32 cross-product
## rounding. Barycentric epsilon flags ambiguous edges; it NEVER widens support.
func triangle_witness(start: Vector3, end: Vector3, motor: Dictionary, observer: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary]=[]
	var near_edges: Array[Dictionary]=[]
	for triangle: Dictionary in triangles:
		var a: Vector3=triangle.a;var b: Vector3=triangle.b;var c: Vector3=triangle.c
		var bx: float=float(b.x)-float(a.x);var bz: float=float(b.z)-float(a.z)
		var cx: float=float(c.x)-float(a.x);var cz: float=float(c.z)-float(a.z)
		var px: float=float(start.x)-float(a.x);var pz: float=float(start.z)-float(a.z)
		var determinant: float=bx*cz-bz*cx
		if absf(determinant)<1e-14: continue # Vertical or degenerate projection.
		var u: float=(px*cz-pz*cx)/determinant
		var v: float=(bx*pz-bz*px)/determinant
		var w: float=1.0-u-v
		var margin: float=minf(w,minf(u,v))
		if margin < -1e-7: continue
		var height: float=w*float(a.y)+u*float(b.y)+v*float(c.y)
		if height<float(end.y)-1e-7 or height>float(start.y)+1e-7: continue
		var by: float=float(b.y)-float(a.y);var cy: float=float(c.y)-float(a.y)
		var normal:=Vector3(by*cz-bz*cy,bz*cx-bx*cz,bx*cy-by*cx).normalized()
		var row: Dictionary={"shape_index":triangle.shape_index,"face_index":triangle.face_index,
			"world_vertices":[a,b,c],"barycentric_w_u_v":[w,u,v],"minimum_barycentric":margin,
			"world_y":height,"normal":normal,"distance_from_ray_start":float(start.y)-height,"strict_interior":margin>1e-7}
		if margin>1e-7: candidates.append(row)
		else: near_edges.append(row)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.world_y)>float(b.world_y))
	near_edges.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.world_y)>float(b.world_y))
	var result: Dictionary={"observer_segment_from":start,"observer_segment_to":end,
		"intersections_strict_interior":candidates,"ambiguous_edge_intersections":near_edges,
		"barycentric_edge_epsilon":1e-7,"height_match_epsilon_m":.00001,
		"long_matches_geometric_top":false,"short_misses_geometric_top":false}
	if candidates.is_empty() or motor.is_empty() or observer.is_empty(): return result
	var top: Dictionary=candidates[0]
	# Any higher/tied ambiguous face prevents a decisive nearest-surface claim.
	if not near_edges.is_empty() and float(near_edges[0].world_y)>=float(top.world_y)-.00001:
		result.inconclusive="highest intersection is on or numerically near a triangle edge";return result
	var matches: bool=int(top.shape_index)==int(motor.shape_index) and int(top.face_index)==int(motor.face_index) and absf(float(top.world_y)-float(motor.position.y))<=.00001
	result.long_normal_alignment_abs=absf((top.normal as Vector3).dot(motor.normal as Vector3))
	# Winding normal sign is recorded, not assumed; physics reports the facing normal.
	matches=matches and float(result.long_normal_alignment_abs)>.999
	result.long_matches_geometric_top=matches
	result.short_misses_geometric_top=matches and float(top.world_y)-float(observer.position.y)>.003
	result.top=top
	result.geometric_short_gap_m=float(top.world_y)-float(observer.position.y)
	return result

func finish() -> void:
	require(inputs==hashes(),"source and native asset hashes unchanged")
	if is_instance_valid(frame_root): frame_root.free()
	if factory!=null: factory.finish()
	var unexpected: Array[String]=[]
	for message: String in logger.errors:
		if not message.contains("PETER SUPPORT:"): unexpected.append(message)
	OS.remove_logger(logger)
	var result: Dictionary={"schema_version":2,"evidence_kind":"diagnostic","suite":"PeterThresholdSupportDiagnostic","production_runtime":false,
		"status":"CAPTURED" if errors.is_empty() and unexpected.is_empty() else "FAIL","scope":"Exact current native4A threshold and registered source transform; paired motor/observer rays at failed worldXZ and neighboring17.5mm samples across8physicsframes. Independent actual concave-face scalar barycentric/plane intersections verify ray results. No actor, surrounding floor/door, full-world composition, movement qualification or tolerance change.",
		"source_hashes":inputs,"metadata":metadata,"samples":rows,"controls":control_rows,"failures":errors,"engine_errors":unexpected}
	var file:=FileAccess.open(directory.path_join("support_query_diagnostic.json"),FileAccess.WRITE)
	if file==null:get_tree().quit(2);return
	file.store_string(JSON.stringify(result,"\t"));file.flush();var written: bool=file.get_error()==OK;file.close()
	get_tree().quit(0 if errors.is_empty() and unexpected.is_empty() and written else 1)
