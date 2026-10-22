extends "res://tests/v2_low_step_stair_profile.gd"
## Shipping V2 player contact stock; original / enabled / restored, same route.
func _init() -> void:route_label="V2 SHIPPING FIRE PLAYER CONTACT CONTROL"
func _control_cycles() -> Array[String]:return ["original_a_","player_hulls_b_","restored_a_"]
func _prepare_control() -> bool:
 return super._prepare_control() and player._native_contact_agent!=null and player._native_contact_agent.ready and player._native_contact_agent.pairs.size()==8
func _swap(enabled: bool) -> void:
 player._low_step_probe_enabled=true
 player._native_contact_agent.enabled=enabled;player._native_contact_agent.sync()
 _require(player._native_contact_agent.active==enabled and (player.collision_mask&1)==1,"shipping contact mode changes only the validated player-door pairs and retains world layer1")
 for frame in 30:await get_tree().process_frame
func _observe_initial_obstruction(actor: Node3D,hits: Array) -> void:
 _require(hits.any(func(hit: Dictionary):return hit.player) and actor._obstructed("door",.25),"authoritative door sweep still detects the actual walked player")
