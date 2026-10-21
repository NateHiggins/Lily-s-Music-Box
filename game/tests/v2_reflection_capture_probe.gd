extends "res://tests/orison_v2_vertical_route_test.gd"
func _init() -> void:route_label="V2 REFLECTION CAPTURE DIAGNOSTIC"
func _route() -> void:
 var directory:=OS.get_environment("SHOT_DIR")
 DirAccess.make_dir_recursive_absolute(directory)
 var survey:=preload("res://tests/v2_area_survey.gd").new()
 var owner: Node=world.get_node("V2RoomReflections")
 player.set_physics_process(false);player.set_lamp_enabled(true);player.carried_device.set_capture_hidden(true)
 var records: Array=[]
 for identity: String in ["F03_B_BATH","F06_B_KITCHEN"]:
  var room: Dictionary={}
  for entry: Dictionary in world.layout.spaces:
   if str(entry.id)==identity:room=entry;break
  var stance: Dictionary=survey._stance(world,world.adapter.root,room.rect,world.adapter.root.level_y[room.level])
  if stance.is_empty():failures.append("no stance "+identity);continue
  player.global_position=Vector3(stance.feet[0],stance.feet[1],stance.feet[2]);player.global_rotation=Vector3(0,world.adapter.root.global_rotation.y,0);player.camera.rotation=Vector3(-.08,0,0)
  owner.set_physics_process(true)
  for frame in 90:await RenderingServer.frame_post_draw
  owner.set_physics_process(false)
  if not owner.probes.has(identity):failures.append("no room probe "+identity);continue
  var probe: ReflectionProbe=owner.probes[identity]
  for treatment: String in ["normal","ambient_disabled","interior","intensity_tenth","zero_intensity","restored"]:
   probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED if treatment=="ambient_disabled" else ReflectionProbe.AMBIENT_ENVIRONMENT
   probe.interior=treatment=="interior"
   probe.intensity=.1 if treatment=="intensity_tenth" else 0. if treatment=="zero_intensity" else 1.
   for frame in 90:await RenderingServer.frame_post_draw
   var filename:=identity+"_"+treatment+".png"
   get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
   records.append({"id":identity,"treatment":treatment,"image":filename,"origin":str(probe.global_position+probe.origin_offset),"ambient":probe.ambient_mode,"interior":probe.interior,"intensity":probe.intensity})
 survey.free();owner.set_physics_process(true)
 FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"failures":failures},"\t"))
