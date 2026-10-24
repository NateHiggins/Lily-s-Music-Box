extends "res://tests/orison_v2_vertical_route_test.gd"
func _init() -> void:route_label="V2 ALCOVE REVIEW"
func _route() -> void:
 var directory:=OS.get_environment("SHOT_DIR")
 DirAccess.make_dir_recursive_absolute(directory)
 player.set_lamp_enabled(true);player.carried_device.set_capture_hidden(true)
 for point: Vector3 in [Vector3(1.925,0,-5.25),Vector3(4.85,0,-5.25),Vector3(4.85,0,-4.22)]:
  if not await _walk(point):return
 var records: Array=[]
 for height: float in [.45,1.15,2.2]:
  var at: Vector3=world.adapter.root.to_global(Vector3(6.85,height,-4.225))
  player.face_world_point(at)
  for frame in 60:await RenderingServer.frame_post_draw
  var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,at,1,[player.get_rid()])
  var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
  var filename:="alcove_%0.2f.png"%height
  get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
  records.append({"height":height,"eye":str(player.camera.global_position),"at":str(at),"blocker":str(hit.get("collider","none")),"image":filename})
 FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual controller walk to west opening and three views into shallow recess; no interior capsule stance or human acceptance claim.","records":records,"failures":failures},"\t"))
