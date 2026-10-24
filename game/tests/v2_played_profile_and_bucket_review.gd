extends "res://tests/v2_golden_repair_profile.gd"
## Same timed route, followed only AFTER sampling by a fixture camera/contact
## review of the previously cropped restroom bucket. No fixture access claim.
func _route() -> void:
 await super._route()
 if not failures.is_empty():return
 await _mop_contact()
func _mop_contact() -> void:
 var root: Node3D=world.adapter.root
 var actor:=root.find_child("F01_restroom_mop_bucket",true,false) as StaticBody3D
 if not _require(actor!=null,"retained native restroom mop/bucket actor exists"):return
 var metal: MeshInstance3D
 for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if str(draw.get_meta("material_key",""))=="metal":metal=draw
 if not _require(metal!=null,"bucket floor stock is the actual imported metal draw"):return
 var low:=INF;var bottom: Array[Vector3]=[]
 for surface in metal.mesh.get_surface_count():
  var vertices: PackedVector3Array=metal.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
  for vertex: Vector3 in vertices:
   var point: Vector3=metal.to_global(vertex)
   if point.y<low-.000001:low=point.y;bottom.clear()
   if absf(point.y-low)<.000001:bottom.append(point)
 var centre:=Vector3.ZERO
 for point: Vector3 in bottom:centre+=point
 centre/=float(maxi(1,bottom.size()))
 var ray:=PhysicsRayQueryParameters3D.create(centre+Vector3.UP*.5,centre-Vector3.UP*.5,1,[actor.get_rid(),player.get_rid()])
 var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
 if not _require(not hit.is_empty() and hit.normal.y>.99,"original floor is measured beneath the bucket without its self collision"):return
 var gap: float=low-float(hit.position.y)
 _require(absf(gap)<.00004,"actual imported bucket bottom meets floor within forty micrometres")
 var local:=root.to_local(actor.global_position)
 var chosen: Dictionary={};var smallest:=INF
 for room: Dictionary in world.layout.spaces:
  var base: float=root.level_y[str(room.level)]
  var rect: Array=room.rect
  if absf(base-local.y)>.2 or local.x<float(rect[0]) or local.x>float(rect[2]) or local.z<float(rect[1]) or local.z>float(rect[3]):continue
  var area: float=(float(rect[2])-float(rect[0]))*(float(rect[3])-float(rect[1]))
  if area<smallest:chosen=room;smallest=area
 if not _require(not chosen.is_empty(),"retained layout owns the bucket review room"):return
 var survey:=preload("res://tests/v2_area_survey.gd").new()
 var stance: Dictionary=survey._stance(world,root,chosen.rect,root.level_y[str(chosen.level)])
 survey.free()
 if not _require(not stance.is_empty(),"full-size supported capsule stance exists for uncropped prop review"):return
 var saved_pose:=player.global_transform;var saved_eye:=player.camera.transform
 var lamp_before:=player.lamp_is_enabled()
 player.cancel_manipulation();player.set_physics_process(false)
 player.global_position=Vector3(stance.feet[0],stance.feet[1],stance.feet[2]);player.velocity=Vector3.ZERO
 player.camera.position.y=PlayerController.CROUCH_EYE if stance.crouched else PlayerController.STANDING_EYE
 player.camera.look_at(actor.to_global(Vector3(0,.58,0)))
 var out:=OS.get_environment("SHOT_DIR")
 var images: Array[String]=[]
 for powered: bool in [false,true]:
  player.set_lamp_enabled(powered)
  var settled:=0;var previous:=-1.0
  for frame in 300:
   await RenderingServer.frame_post_draw
   var energy: float=player.flashlight.light_energy
   settled=settled+1 if absf(energy-previous)<.000001 else 0
   previous=energy
   if settled>=24:break
  _require(settled>=24,"actual carried-lamp output settles for bucket review")
  var name: String="mop_bucket_"+("lamp" if powered else "room")+".png"
  get_viewport().get_texture().get_image().save_png(out.path_join(name));images.append(name)
 FileAccess.open(out.path_join("mop_contact_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Post-profile camera fixture and exact native floor contact; no continuous access or human acceptance.","room":chosen.id,"stance":stance,"floor_owner":str(hit.collider.get_path()),"bottom_y":low,"floor_y":hit.position.y,"gap_m":gap,"images":images,"failures":failures},"\t"))
 player.set_lamp_enabled(lamp_before);player.global_transform=saved_pose;player.camera.transform=saved_eye;player.set_physics_process(true)
