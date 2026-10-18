extends Node
var root: Window
var checks: Array=[]
var failed := false
func _ready() -> void:
 root=get_tree().root
 _run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks.append({"ok":ok,"label":label})
 if not ok: failed=true;push_error(label)
func _run() -> void:
 var directory := OS.get_environment("SHOT_DIR")
 if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
 DirAccess.make_dir_recursive_absolute(directory)
 RealityState.persistence_enabled=false
 RealityState.reset_campaign_for_tests()
 CampaignTime.set_frozen_for_tests(true)
 CampaignClock.new().configure_date(1928,10,15,750)
 GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
 var selector=load("res://scripts/building/building_root_selector.gd")
 selector.reset_for_tests("v2")
 var world=(load(selector.scene_path()) as PackedScene).instantiate()
 root.add_child(world)
 await get_tree().physics_frame
 await get_tree().physics_frame
 check(not world.startup_failed,"production V2 world starts for optical diagnosis")
 if failed:world.free();get_tree().quit(1);return
 var player=world.player
 player.set_physics_process(false)
 var camera: Camera3D=player.camera
 camera.make_current()
 var stations=[
  {"name":"roof_player_diffuse","eye":Vector3(14,1.65,46),"target":Vector3(14,11.2,51.6),"lamp":false},
  {"name":"roof_player_carried","eye":Vector3(14,1.65,46),"target":Vector3(14,11.2,51.6),"lamp":true},
  {"name":"roof_close_diffuse","eye":Vector3(12.2,10.1,50),"target":Vector3(11.35,11.098,51.6),"lamp":false},
  {"name":"roof_close_carried","eye":Vector3(12.2,10.1,50),"target":Vector3(11.35,11.098,51.6),"lamp":true}]
 var images: Array=[]
 for station: Dictionary in stations:
  camera.global_position=station.eye
  camera.look_at(station.target)
  player.set_lamp_enabled(station.lamp)
  var deadline := Time.get_ticks_msec()+8000
  while player.flashlight.visible!=station.lamp and Time.get_ticks_msec()<deadline:
   await get_tree().create_timer(.05).timeout
  await get_tree().create_timer(.4).timeout
  check(player.flashlight.visible==station.lamp,"actual lamp state settles: "+str(station.name))
  check(player.flashlight.global_position.distance_to(camera.global_position)<.8,"actual carried light follows camera: "+str(station.name))
  for i in 8:await RenderingServer.frame_post_draw
  check(player.flashlight.visible==station.lamp,"captured lamp state remains correct: "+str(station.name))
  var file: String=str(station.name)+".png"
  check(root.get_viewport().get_texture().get_image().save_png(directory.path_join(file))==OK,"capture "+file)
  images.append({"file":file,"eye":[station.eye.x,station.eye.y,station.eye.z],"target":[station.target.x,station.target.y,station.target.z],"lamp":station.lamp,"lamp_range_m":player.flashlight.spot_range,"scope":"Optical inspection rig; elevated close camera is not a played stance or navigation proof."})
 var lantern=world.passage_region.cell_nodes.passage.get_node("ArcadeLantern")
 var draw=lantern.find_children("*","MeshInstance3D",true,false)[0]
 var material: Material=draw.get_active_material(0)
 var finish: Dictionary={"type":material.get_class()}
 if material is ShaderMaterial:
  for key: String in ["albedo_tex","normal_tex","rough_tex"]:
   var value=material.get_shader_parameter(key)
   finish[key]=value.resource_path if value is Texture2D else ""
  finish["mesh_uv_scale"]=str(material.get_shader_parameter("mesh_uv_scale"))
  finish["normal_scale"]=material.get_shader_parameter("normal_scale")
  finish["metallic"]=material.get_shader_parameter("metallic")
 var output={"evidence_class":"INERT","scope":"Production materials and unchanged real carried lamp; optical review only, no gameplay, navigation or human acceptance.","checks":checks,"images":images,"finish":finish,"campaign_fixture":"1928-10-15 12:30"}
 FileAccess.open(directory.path_join("optical_review.json"),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
 world.shutdown_for_tests()
 root.remove_child(world)
 world.free()
 await get_tree().process_frame
 print("ROOF LIGHT PROBE ","FAIL" if failed else "PASS"," checks=",checks.size())
 get_tree().quit(1 if failed else 0)
