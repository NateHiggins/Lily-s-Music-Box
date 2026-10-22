extends "res://tests/v2_low_step_stair_profile.gd"
## Shipping V2 player contact stock; original / enabled / restored, same route.
func _init() -> void:route_label="V2 SHIPPING FIRE PLAYER CONTACT CONTROL"
func _control_cycles() -> Array[String]:return ["original_a_","player_hulls_b_","restored_a_"]
func _prepare_control() -> bool:
 return super._prepare_control() and player._native_contact_agent!=null and player._native_contact_agent.ready and player._native_contact_agent.pairs.size()==8
func _swap(enabled: bool) -> void:
 player._low_step_probe_enabled=true
 player._native_contact_agent.enabled=enabled;player._native_contact_agent.sync()
 var agent: RefCounted=player._native_contact_agent
 var rows: Array=[]
 for pair: Dictionary in agent.pairs:
  rows.append({"original_valid":is_instance_valid(pair.original),"proxy_valid":is_instance_valid(pair.proxy),"parent_correct":is_instance_valid(pair.proxy) and pair.proxy.get_parent()==pair.original,"children":pair.proxy.get_child_count() if is_instance_valid(pair.proxy) else -1,"already_excepted":pair.original in player.get_collision_exceptions()})
 print("SHIPPING CONTACT MODE: ",JSON.stringify({"requested":enabled,"ready":agent.ready,"active":agent.active,"supported":agent._supported(),"radius":player._capsule.radius,"shape_basis":str(player._shape.basis),"scale":str(player.global_basis.get_scale()),"up":player.global_basis.y.normalized().dot(Vector3.UP),"mask":player.collision_mask,"pairs":rows}))
 _require(player._native_contact_agent.active==enabled and (player.collision_mask&1)==1,"shipping contact mode changes only the validated player-door pairs and retains world layer1")
 for frame in 30:await get_tree().process_frame
func _observe_initial_obstruction(actor: Node3D,hits: Array) -> void:
 _require(hits.any(func(hit: Dictionary):return hit.player) and actor._obstructed("door",.25),"authoritative door sweep still detects the actual walked player")
