extends "res://tests/v2_floor_transition_profile.gd"
## Destructive diagnostic isolation ONLY, restored before exit. Disabling a
## cabinet cost bucket is never a proposed production repair or route proof.
const Controller=preload("res://tests/fire_cabinet_cost_controller.gd")
var actors: Array[Node3D]=[]
var collision_rows: Array[Dictionary]=[]
var actor_rows: Array[Dictionary]=[]
var process_rows: Array[Dictionary]=[]
var controls: Array=[]
func _init() -> void:route_label="V2 FIRE CABINET COST ISOLATION"
func _ready() -> void:
	get_tree().node_added.connect(_install_controller)
	super._ready()
func _install_controller(node: Node) -> void:
	if node is PlayerController and node.get_script()!=Controller:node.set_script(Controller)
func _restore() -> void:
	for row: Dictionary in collision_rows:
		row.body.collision_layer=row.layer;row.body.collision_mask=row.mask
	for row: Dictionary in actor_rows:
		row.actor.visible=row.visible
	for row: Dictionary in process_rows:
		row.node.set_process(row.process);row.node.set_physics_process(row.physics)
func _play_route() -> void:
	player.profile_physics=true;player._profile_disable_step_guard=false
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	for reference: WeakRef in native.stations.values():
		var actor: Node3D=reference.get_ref();actors.append(actor)
		actor_rows.append({"actor":actor,"visible":actor.visible})
		var nodes: Array=actor.find_children("*","Node",true,false);nodes.push_front(actor)
		for node: Node in nodes:
			if node.get_script()!=null:process_rows.append({"node":node,"process":node.is_processing(),"physics":node.is_physics_processing()})
		for body: CollisionObject3D in actor.find_children("*","CollisionObject3D",true,false):
			collision_rows.append({"body":body,"layer":body.collision_layer,"mask":body.collision_mask})
	var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new()
	helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
	for cycle: String in ["original_a_","no_collision_b_","restored_a_","no_render_c_","restored_c_","no_scripts_d_","restored_d_"]:
		profile_cycle=cycle;profile_phase=cycle+"switch_excluded"
		_restore()
		if cycle=="no_collision_b_":
			for row: Dictionary in collision_rows:row.body.collision_layer=0;row.body.collision_mask=0
		elif cycle=="no_render_c_":
			for actor: Node3D in actors:actor.visible=false
		elif cycle=="no_scripts_d_":
			# Keep CollisionObject3D process_mode unchanged: disabling it can
			# remove the body from physics and conflate two cost buckets.
			for row: Dictionary in process_rows:row.node.set_process(false);row.node.set_physics_process(false)
		for frame in 30:await get_tree().process_frame
		var start: int=player.physics_profile_records.size()
		for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4)]:
			if not await _walk(target):_restore();helper.free();return
		profile_phase=cycle+"aim_excluded"
		var actor: Node3D=native.stations["F02_FIRE_LINE_STAIR"].get_ref()
		await helper.aim(actor._door_pivot.to_global(Vector3(-.4,.1,.015)))
		for frame in 30:await get_tree().process_frame
		var prompt_start: int=player.get("prompt_costs").size()
		profile_phase=cycle+"near_turn"
		for frame in 240:
			var motion:=InputEventMouseMotion.new()
			motion.relative=Vector2(1.5*cos(frame*TAU/120.),0)
			player._unhandled_input(motion);await get_tree().process_frame
		controls.append({"cycle":cycle,"prompt_ms":player.get("prompt_costs").slice(prompt_start),"position":str(player.global_position)})
		for target: Vector3 in [Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
			if not await _walk(target):_restore();helper.free();return
		for record: Dictionary in player.physics_profile_records.slice(start):record["cabinet_control"]=cycle
	_restore();helper.free()
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("controls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Diagnostic isolation of eight cabinets: original / collision disabled / restored / hidden render / restored / scripts disabled / restored. All original settings restored. Disabled buckets are NOT repairs or runtime qualification. Actual keyboard movement and mouse turning; fixed settings, no PNG capture. Prompt timer wraps the single original authoritative scan; no duplicate queries.","body_count":collision_rows.size(),"controls":controls,"failures":failures},"\t"))
