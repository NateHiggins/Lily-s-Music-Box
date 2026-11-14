extends "res://tests/bodega_approach_counterflow_test.gd"
## Bounded avoidance-only experiment; route targets/physics remain authoritative.
const RVO := preload("res://tests/public_rvo_proposal.gd")
class SteeredRoute extends "res://scripts/characters/orison_v2_resident_route.gd":
	var pilot: Node3D
	func _proposed_step(target: Vector3, delta: float) -> Vector3:
		return pilot.propose(self,target,delta) if pilot!=null else super._proposed_step(target,delta)
	func _route_step_allowed(next: Vector3) -> bool:
		if not super._route_step_allowed(next): return false
		return _bodega_route._people_clear(next) if pilot!=null and pilot.eligible(self) else true
class SnapshotTick extends Node:
	var pilot: Node3D
	func _physics_process(delta: float) -> void:
		pilot.snapshot(delta)
var rvo := RVO.new()
var proposals: Dictionary = {}
var submitted: Dictionary = {}
var poses: Dictionary = {}
var consumed := 0
var held := 0
var tick: Node

func _ready() -> void:
	rvo.open()
	tick=SnapshotTick.new(); tick.pilot=self; tick.process_physics_priority=-100; add_child(tick)
	super._ready()

func _new_route() -> Node3D:
	var route:=SteeredRoute.new(); route.pilot=self; return route

func _snapshot() -> Dictionary:
	var result:=super._snapshot()
	for source: String in ["res://tests/public_rvo_proposal.gd","res://tests/bodega_approach_counterflow_test.gd"]:
		result[source]={"sha256":FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	return result

func eligible(route: Node3D) -> bool:
	if not is_instance_valid(route.actor) or not route.actor.visible or route.path.is_empty(): return false
	var at: Vector3=route.actor.global_position
	if at.x < -2 or at.x>21 or at.z<2 or at.z>6.5 or absf(at.y)>.35: return false
	if route._bodega_route!=null and route._bodega_route._leg_kind in ["entry","transfer","exit"]: return false
	return true

func snapshot(delta: float) -> void:
	if not is_instance_valid(player): return
	var rows: Array[Dictionary]=[]; var next_targets: Dictionary={}
	proposals.clear()
	for route: Node3D in routes:
		if not is_instance_valid(route.actor) or not route.actor.visible: continue
		var id: int=route.actor.get_instance_id(); var at: Vector3=route.actor.global_position
		var steer:=eligible(route); var velocity:=Vector3.ZERO
		if steer:
			var target: Vector3=route.graph.get_point_position(route.path[0]); var toward:=Vector3(target.x-at.x,0,target.z-at.z)
			velocity=toward.limit_length(route.route_speed*delta)/delta
			next_targets[id]=target
		else: velocity=(at-Vector3(poses.get(id,at)))/delta
		var reply: Dictionary=rvo.take(id)
		if not reply.is_empty() and submitted.has(id): proposals[id]={"target":submitted[id],"velocity":reply.velocity,"age":reply.age}
		rows.append({"id":id,"feet":at,"preferred":velocity,"steer":steer,"player":false}); poses[id]=at
	var player_id: int=player.get_instance_id(); var player_at: Vector3=player.global_position
	rows.append({"id":player_id,"feet":player_at,"preferred":(player_at-Vector3(poses.get(player_id,player_at)))/delta,"steer":false,"player":true}); poses[player_id]=player_at
	# A small right-hand preference breaks symmetric head-on preferred velocities.
	# It is still only a speed-capped solver input; hard guards check executed steps.
	for row: Dictionary in rows:
		if not row.steer or row.preferred.length_squared()<.001: continue
		var bias:=false
		for peer: Dictionary in rows:
			if peer.id==row.id or not peer.steer or peer.preferred.length_squared()<.001: continue
			var offset: Vector3=peer.feet-row.feet
			if offset.length()<2.5 and offset.dot(row.preferred)>0 and row.preferred.normalized().dot(peer.preferred.normalized())<-.3: bias=true
		if bias: row.preferred=(row.preferred+Vector3(row.preferred.z,0,-row.preferred.x).normalized()*.12).limit_length(1.05)
	submitted=next_targets
	if not rvo.submit(rows): _check(false,"RVO accepts complete actual body snapshot")
	if not details.has("rvo_velocity_trace"): details.rvo_velocity_trace=[]
	if Engine.get_physics_frames()%30==0: details.rvo_velocity_trace.append({"frame":Engine.get_physics_frames(),"rows":rows.duplicate(true),"proposals":proposals.duplicate(true)})

func propose(route: Node3D, target: Vector3, delta: float) -> Vector3:
	var at: Vector3=route.actor.global_position
	if not eligible(route): return at+Vector3(target.x-at.x,0,target.z-at.z).limit_length(delta*route.route_speed)
	var reply: Dictionary=proposals.get(route.actor.get_instance_id(),{})
	if reply.is_empty() or Vector3(reply.target).distance_to(target)>.001: held+=1; return at
	consumed+=1
	return at+Vector3(reply.velocity).limit_length(route.route_speed)*delta

func _overflow_newcomer() -> void:
	await super._overflow_newcomer()
	if is_instance_valid(tick): tick.set_physics_process(false)
	_check(rvo.errors.is_empty(),"RVO server snapshot helper has no errors")
	details.rvo_scope="avoidance-only map pilot, changed velocity proposal with unchanged goals and final native/peer guards; template-floor mechanical experiment, not production integration"
	details.rvo_summary={"consumed":consumed,"held_for_missing_or_changed_target":held,"agent_count_before_close":rvo.agents.size()}
	rvo.close(); _check(not rvo.map.is_valid() and rvo.agents.is_empty(),"RVO owned map/agents closed before preview retirement")

func _exit_tree() -> void:
	rvo.close()
