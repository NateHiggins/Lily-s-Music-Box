extends "res://tests/v2_street_optics_probe.gd"
## INERT loaded glazing/lamp and next-area visual review. Cameras are fixtures.
## No room, navigation, gameplay or acceptance grant.
func run(current: OrisonV2RuntimeRoot,suite: Node) -> void:
 world=current;directory=OS.get_environment("SHOT_DIR")
 var prior_camera := world.player.camera.global_transform
 var prior_physics := world.player.is_physics_processing()
 var prior_lamp := world.player.lamp_is_enabled()
 world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
 for canvas: CanvasLayer in world.find_children("*","CanvasLayer",true,false):canvas.hide()
 var deadline := Time.get_ticks_msec()+6000
 while world.player.flashlight.visible and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
 suite.check(not world.player.flashlight.visible,"carried lamp settled before finite-source reflection review")
 var camera := world.player.camera
 var lamps: RefCounted=world.adapter.root.get_meta("v2_native_service_work_lights")
 var rows: Array=[];var captured := {}
 for row: Dictionary in lamps.installed:
  var lamp: LightFixtureProp=row.lamp.get_ref()
  suite.check(lamp.light.light_specular>0 and lamp.light.light_size>0,"native work lamp retains finite, specular light")
  suite.check(is_equal_approx(lamp.light.light_size,row.aperture_radius),"native emitter aperture survives light rig initialization")
  rows.append({"name":str(lamp.name),"variant":row.variant,"former_size":row.source_size,"size":lamp.light.light_size,"specular":lamp.light.light_specular,"position":[lamp.light.global_position.x,lamp.light.global_position.y,lamp.light.global_position.z]})
  if captured.has(row.variant):continue
  captured[row.variant]=true
  var position: Vector3=lamp.position+Vector3(-.6 if row.variant=="AlleyEast" else .6,0,.65)
  position.y=1.6
  camera.global_position=(lamp.get_parent() as Node3D).to_global(position)
  camera.look_at(lamp.to_global(Vector3(0,-.49,0)))
  await _shot("work_aperture_"+str(row.variant))
 for x: float in [19.1,19.5,19.9]:
  camera.global_position=Vector3(x,1.65,3.1);camera.look_at(Vector3(24,1.8,1))
  await _shot("glazing_fitted_"+str(x).replace(".","_"))
 # Original imported passage geometry is a next-area observation, not proof
 # that absent region records or whole-world requirements have been completed.
 for station: Dictionary in [
  {"name":"arcade_portal_current","eye":Vector3(14,1.65,16.6),"target":Vector3(14,2.1,20)},
  {"name":"arcade_throat_current","eye":Vector3(14,1.65,21),"target":Vector3(14,2.1,30)},
  {"name":"arcade_hall_current","eye":Vector3(14,1.65,32),"target":Vector3(14,2.1,50)}]:
  camera.global_position=station.eye;camera.look_at(station.target)
  await _shot(str(station.name))
 var file := FileAccess.open(directory.path_join("glazing_aperture_review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Production optical review and next-area camera observations. No room/route/acceptance proof.","lamps":rows},"\t"));file.close()
 world.player.camera.global_transform=prior_camera
 world.player.set_physics_process(prior_physics);world.player.set_lamp_enabled(prior_lamp)
