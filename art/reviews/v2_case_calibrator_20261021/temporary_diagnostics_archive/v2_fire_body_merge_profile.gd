extends "res://tests/v2_floor_transition_profile.gd"
## Test-only original / merged native triangles / original / lower-cap step
## eligibility / original. No convex approximation, mask or motion exemptions.
const Controller=preload("res://tests/fire_step_sphere_control.gd")
var entries: Array=[]
var shape_records: Array=[]
var query_costs: Array=[]
func _init() -> void:route_label="V2 FIRE BODY MERGE AND FOOT PROBE"
func _ready() -> void:
	get_tree().node_added.connect(_install_controller);super._ready()
func _install_controller(node: Node) -> void:
	if node is PlayerController and node.get_script()!=Controller:node.set_script(Controller)
func _process(delta: float) -> void:
	if is_instance_valid(player):player.set("cost_phase",profile_phase)
	super._process(delta)
func _prepare() -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	for reference: WeakRef in native.stations.values():
		var actor: Node3D=reference.get_ref()
		for body: CollisionObject3D in actor._bodies.values():
			var faces:=PackedVector3Array();var sources: Array=[];var margin: float=-1.;var backface:=false;var consistent:=true
			for node: Node in body.get_children():
				if node is not CollisionShape3D or node.disabled or node.shape is not ConcavePolygonShape3D:continue
				if margin<0.:margin=node.shape.margin;backface=node.shape.backface_collision
				if margin!=node.shape.margin or backface!=node.shape.backface_collision:consistent=false
				sources.append(node)
				for vertex: Vector3 in node.shape.get_faces():faces.append(node.transform*vertex)
			if sources.size()<2 or not consistent:continue
			var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.margin=margin;shape.backface_collision=backface
			var merged:=CollisionShape3D.new();merged.name="DiagnosticMergedNativeFaces";merged.shape=shape;merged.disabled=true;body.add_child(merged)
			entries.append({"sources":sources,"merged":merged})
			shape_records.append({"body":str(body.get_path()),"original_shapes":sources.size(),"triangles":faces.size()/3,"margin":margin,"backface":backface})
func _swap(enabled: bool) -> void:
	for entry: Dictionary in entries:
		for source: CollisionShape3D in entry.sources:source.disabled=enabled
		entry.merged.disabled=not enabled
	for frame in 30:await get_tree().process_frame
func _query_breakdown(actor: Node3D) -> void:
	var groups: Dictionary={"none":[],"door":[actor._bodies.door.get_rid()],"lever":[actor._bodies.lever.get_rid()],"joint":[actor._bodies.joint.get_rid()],"nozzle":[actor._nozzle_joint.body.get_rid()],"gasket":[actor._gasket_body.get_rid()]}
	for label: String in groups:
		var excluded: Array[RID]=[];excluded.assign(groups[label])
		for motion: Vector3 in [Vector3.ZERO,Vector3(.06,0,0),Vector3(-.06,0,0),Vector3(0,0,.06),Vector3(0,0,-.06),Vector3.UP*.30]:
			for repeat in 3:
				var query:=PhysicsTestMotionParameters3D.new();query.from=player.global_transform;query.motion=motion;query.margin=.001;query.exclude_bodies=excluded
				var start:=Time.get_ticks_usec();var hit:=PhysicsServer3D.body_test_motion(player.get_rid(),query)
				query_costs.append({"excluded":label,"motion":str(motion),"repeat":repeat,"hit":hit,"ms":(Time.get_ticks_usec()-start)/1000.})
func _play_route() -> void:
	player.profile_physics=true;player._profile_disable_step_guard=false
	profile_phase="prepare_excluded";_prepare()
	var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new();helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
	for cycle: String in ["original_a_","merged_b_","restored_a_","foot_c_","restored_c_"]:
		profile_cycle=cycle;profile_phase=cycle+"switch_excluded"
		player.set("foot_step_candidate",cycle=="foot_c_");await _swap(cycle=="merged_b_")
		print("FIRE COST CYCLE: ",cycle)
		for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4)]:
			if not await _walk(target):await _swap(false);helper.free();return
		var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
		var actor: Node3D=native.stations["F02_FIRE_LINE_STAIR"].get_ref()
		profile_phase=cycle+"aim_excluded";await helper.aim(actor._door_pivot.to_global(Vector3(-.4,.1,.015)))
		if cycle=="original_a_":_query_breakdown(actor)
		for frame in 30:await get_tree().process_frame
		profile_phase=cycle+"near_turn"
		for frame in 240:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(1.5*cos(frame*TAU/120.),0)
			player._unhandled_input(motion);await get_tree().process_frame
		for target: Vector3 in [Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
			if not await _walk(target):await _swap(false);helper.free();return
	profile_phase="restore_excluded";player.set("foot_step_candidate",false);await _swap(false)
	for entry: Dictionary in entries:entry.merged.free()
	helper.free()
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("controls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Test-only original / merged triangles / restored / lower-cap eligibility / restored. Same source geometry and full capsule safety checks; no production integration or runtime grant. Merging bakes original shape-local matrices, so precision must be independently verified before integration. Query exclusions apply to dry, non-moving diagnostics only. Tick timing is not capped; earlier6000-row original ring buffer is drained each tick.","shapes":shape_records,"dry_query_costs":query_costs,"physics_ticks":player.get("measured_ticks"),"failures":failures},"\t"))
