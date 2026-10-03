extends "res://tests/orison_v2_service_alley_test.gd"
## INERT installed fit and normal-controller route; wider infrastructure is open.
const CONSTRUCTION := "res://tests/fixtures/orison_alley_groundworks_construction.json"
var groundworks_owner: Node3D
var groundworks_bodies: Array[RID]=[]
var native:=PackedVector3Array()
var mapping_checks:=0
var old_ground_count:=0

func _init() -> void:
	route_label="V2 ALLEY GROUNDWORKS"

func _prepare_player_start() -> void:
	var root: Node3D=world.adapter.root
	groundworks_owner=root.get_node("ServiceAlley/Groundworks")
	for draw: MeshInstance3D in groundworks_owner.find_children("*","MeshInstance3D",true,false):
		native.append_array((root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces())
		groundworks_bodies.append(draw.get_node("GroundworksCollision").get_rid())
	for old_name: String in ["Paving","Iron"]:
		if root.get_node("ServiceAlley").find_child(old_name,true,false)==null:old_ground_count+=1
	super._prepare_player_start()

func _route() -> void:
	await get_tree().physics_frame;await get_tree().physics_frame
	var root: Node3D=world.adapter.root
	var mapping=load("res://tests/orison_v2_ceiling_top_closures_test.gd").new()
	var triangles:=0
	for draw: MeshInstance3D in groundworks_owner.find_children("*","MeshInstance3D",true,false):
		mapping._check_planar_mapping(draw.mesh,true)
		var bounds: AABB=(root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_aabb()
		mapping.check(maxf(bounds.size.x,bounds.size.z)<=4.00001,"trial export keeps four-metre culling extents")
		triangles+=draw.mesh.get_faces().size()/3
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONSTRUCTION))
	var expected_triangles:=0
	for part: Dictionary in construction.parts:expected_triangles+=int(part.triangles)
	mapping.check(groundworks_bodies.size()==construction.parts.size() and triangles==expected_triangles,"all native alley export partitions are imported")
	mapping.check(FileAccess.get_sha256("res://assets/props/alley_groundworks.glb")==construction.asset_sha256,"live trial binds its exact native exported asset")
	mapping.check(old_ground_count==2,"both original paving and iron owners are absent from the installed alley")
	mapping_checks=mapping.checks
	for failure: String in mapping.failures:failures.append("mapping: "+failure)
	var probe:=Vector3(16.6,-1.3,3.2)
	var window_ray:=PhysicsRayQueryParameters3D.create(root.to_global(probe),root.to_global(Vector3(15.5,-1.3,3.2)),1,[player.get_rid()])
	var throat: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(window_ray)
	var window: Node3D=root.get_node("B1_BOILER_AIR_E/OperatingWindow")
	if throat.is_empty() or not window.is_ancestor_of(throat.collider):failures.append("closed operating boiler window has no fitted physical pane")
	var fitted: Array[RID]=window_ray.exclude
	for body: CollisionObject3D in window.find_children("*","CollisionObject3D",true,false):fitted.append(body.get_rid())
	window_ray.exclude=fitted
	throat=world.get_world_3d().direct_space_state.intersect_ray(window_ray)
	if not throat.is_empty():failures.append("original boiler-window throat obstructed beneath fitted window by "+str(root.get_path_to(throat.collider)))
	# Open catch bores and well floor are measured on the actual imported faces.
	for z: float in [-10.45,2.0,12.9,3.2]:
		var start:=Vector3(17.75,-.2 if z!=3.2 else -2.1,z)
		var depth: float=.40 if z==3.2 else 1.3
		var ray:=PhysicsRayQueryParameters3D.create(root.to_global(start),root.to_global(start-Vector3.UP*depth),1,[player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():failures.append("closed drain outlet at "+str(z))
	if construction.has("local_collector"):
		var drain: Dictionary=construction.local_collector
		var pipe_start:=Vector3(17.75,-2.60+.005*(13.0-3.2),13.0)
		var pipe_end:=Vector3(17.75,-2.60+.005*(float(drain.main_axis[0][2])+.05-3.2),float(drain.main_axis[0][2])+.05)
		var bore_ray:=PhysicsRayQueryParameters3D.create(root.to_global(pipe_start),root.to_global(pipe_end),1,[player.get_rid()])
		var bore_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(bore_ray)
		if not bore_hit.is_empty():failures.append("local collector axial bore obstructed by "+str(root.get_path_to(bore_hit.collider)))
	mapping.free()
	await super._route()
	if not failures.is_empty():return
	# Cross the real well grate in both directions with the normal controller.
	var rear_anchor:=world.adapter.resolve("F01_REAR_SERVICE_DOOR") as Node3D
	var rear_leaf:=rear_anchor.get_node("F01_REAR_SERVICE_DOOR_Leaf") as DoorProp
	if not await _use(rear_leaf,true):return
	for point: Vector3 in [Vector3(8.9,0,10.7),Vector3(16.8,0,10.7),Vector3(16.8,0,4.4),Vector3(16.8,0,3.2),Vector3(16.8,0,2.0),Vector3(16.8,0,3.2),Vector3(16.8,0,4.4)]:
		if not await _walk(point):return
		if is_equal_approx(point.z,3.2):await _view("well_crossing_"+str(trace.size()),Vector3(16.8,-.9,3.2))
	await _inspection_views()
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("alley-groundworks-inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","parts":groundworks_bodies.size(),"triangles":triangles,"mapping_checks":mapping_checks,"waypoints":trace.size(),"failures":failures,"note":"Installed fit, mapping and controller check. Downstream connection, joint-scale runoff and weather completion remain open."},"\t")+"\n");file.close()
	print("ALLEY GROUNDWORKS MAPPING: ",mapping_checks," checks; ",triangles," triangles")

func _inspection_views() -> void:
	var root: Node3D=world.adapter.root
	player.camera.make_current();player.camera.fov=65
	player.set_physics_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	for view: Array in [["well_aperture",Vector3(16.5,-1.1,2.7),Vector3(15.93,-1.3,3.2)],
		["well_drain",Vector3(16.25,-1.2,3.35),Vector3(17.75,-2.25,3.2)],
		["front_catch",Vector3(16.8,1.524,-10.9),Vector3(17.75,-.15,-10.45)],
		["rear_fall",Vector3(8.9,1.524,11.2),Vector3(17.75,0,12.9)]]:
		player.global_position=root.to_global(view[1])-Vector3.UP*player.STANDING_EYE
		player.face_world_point(root.to_global(view[2]))
		player.camera.basis=player.camera.basis.orthonormalized()
		player._hand.basis=player._hand.basis.orthonormalized()
		player.set_lamp_enabled(true)
		await get_tree().create_timer(.3).timeout;await _capture(str(view[0]))
