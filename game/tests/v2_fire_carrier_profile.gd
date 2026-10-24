extends "res://tests/v2_fire_player_contact_profile.gd"
## Native carrier-only A/B/A in the actual world. All route and hand guards stay.
var carrier_rows: Array[Dictionary]=[]
var candidate_mesh: Mesh
var candidate_shape: ConcavePolygonShape3D
func _init() -> void:route_label="V2 NATIVE CARRIER COMPLEXITY CONTROL"
func _control_cycles() -> Array[String]:return ["original_a_","reduced_carrier_b_","restored_a_"]
func _prepare_control() -> bool:
 if not super._prepare_control():return false
 var packed:=load("res://tests/fixtures/v2_fire_capacity_rack.glb") as PackedScene
 if packed==null:return false
 var model:=packed.instantiate()
 for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  if str(draw.name)=="CarrierArm":candidate_mesh=draw.mesh
 model.free()
 if candidate_mesh==null:return false
 candidate_shape=ConcavePolygonShape3D.new()
 candidate_shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(candidate_mesh))
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 for ref: WeakRef in native.stations.values():
  var actor: Node3D=ref.get_ref()
  for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if str(draw.get_meta("rack_stock",""))!="CarrierArm":continue
   var shape: CollisionShape3D=draw.get_node("NativeRackCollision").get_child(0)
   carrier_rows.append({"draw":draw,"shape":shape,"mesh":draw.mesh,"collision":shape.shape})
 return carrier_rows.size()==80
func _swap(enabled: bool) -> void:
 player._low_step_probe_enabled=true
 player._native_contact_agent.enabled=true;player._native_contact_agent.sync()
 for row: Dictionary in carrier_rows:
  row.draw.mesh=candidate_mesh if enabled else row.mesh
  row.shape.shape=candidate_shape if enabled else row.collision
 print("CARRIER CONTROL MODE: ",JSON.stringify({"reduced":enabled,"arms":carrier_rows.size(),"triangles_each":candidate_mesh.get_faces().size()/3 if enabled else carrier_rows[0].mesh.get_faces().size()/3,"original_contact_agent":player._native_contact_agent.active}))
 for frame in 30:await get_tree().process_frame
func _finish_control() -> void:
 await _swap(false)
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  FileAccess.open(out.path_join("inspection_observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","observations":inspection_observations,"physics_ticks":player.get("measured_ticks"),"prompt_costs":player.get("prompt_costs"),"failures":failures},"\t"))

func _monitor_values() -> Dictionary:
 var values: Dictionary=super._monitor_values()
 values["draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
 values["primitives"]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
 return values
