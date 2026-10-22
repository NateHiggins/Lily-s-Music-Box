extends Node3D
## Uninstalled native rack surface diagnostic. No runtime-contract acceptance.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 print("CAPACITY RACK CHECK: ",label," = ",ok)
 if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
 RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_fire_capacity_rack.json"))
 var packed:=load(str(data.asset)) as PackedScene
 check(packed!=null,"source-owned rack fixture loads")
 if packed==null:get_tree().quit(1);return
 var model:=packed.instantiate();add_child(model)
 var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
 var meshes: Dictionary={};var finishes: Dictionary={}
 for key: String in data.materials:
  var spec: Dictionary=data.materials[key];var tint: Array=spec.tint
  var finish: StandardMaterial3D=MatLib.get_mat(str(spec.catalog_key)).duplicate()
  finish.uv1_triplanar=false;finish.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]);finish.normal_scale=spec.normal;finish.roughness=spec.roughness;finish.metallic=spec.metallic
  check(finish.normal_enabled and not finish.uv1_triplanar,"registered finish uses authored UV and normal map: "+key)
  for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:check(texture!=null and texture.get_image().get_mipmap_count()>0,"actual loaded PBR map has mip chain: "+key)
  finishes[key]=finish
 for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  meshes[str(draw.name)]=draw.mesh;metrics._check_cap_mapping(draw.mesh,true)
 for failure: String in metrics.failures:check(false,failure)
 metrics.free();model.free()
 check(meshes.size()==5,"all five native fittings have loaded metre UVs and tangent derivatives")
 for key: String in meshes:
  var positions: Array=[]
  if key=="CarrierArm":
   for x: float in data.carrier_x_m:positions.append(Vector3(x,.666,.032))
  elif key=="MountBracket":
   for x: float in data.bracket_x_m:positions.append(Vector3(x,.666,.032))
  elif key=="MountScrew":
   for x: float in data.bracket_x_m:
    for dy: float in [-.021,.021]:positions.append(Vector3(x,.666+dy,.022))
  else:positions.append(Vector3(0,.666,.032))
  for at: Vector3 in positions:
   var draw:=MeshInstance3D.new();draw.mesh=meshes[key];draw.material_override=finishes[data.parts[key]];draw.position=at;add_child(draw)
 var cloth: Node3D=(load("res://tests/fixtures/v2_deployable_hose_candidate.glb") as PackedScene).instantiate();add_child(cloth)
 var linen: StandardMaterial3D=MatLib.get_mat("linen").duplicate();linen.uv1_triplanar=false;linen.albedo_color=Color(.75,.71,.59);linen.normal_scale=.08;linen.roughness=.9;linen.metallic=0.
 for draw: MeshInstance3D in cloth.find_children("*","MeshInstance3D",true,false):draw.material_override=linen
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.025,.03)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.45,.5,.6);environment.environment.ambient_light_energy=.06
 var player:=PlayerController.new();player.position=Vector3(0,-1.15,1.0);add_child(player);player.set_physics_process(false);player.camera.make_current();player.camera.look_at(Vector3(0,.38,.1))
 var atmosphere:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(atmosphere)
 check(atmosphere.setup(player,environment.environment),"production offset voxel lamp mounts");player.set_lamp_enabled(true)
 for frame in 60:await get_tree().process_frame
 check(atmosphere.field!=null and atmosphere.field.ready and atmosphere.field.failed.is_empty(),"actual carried voxel field initializes")
 var out:=OS.get_environment("SHOT_DIR");check(not out.is_empty(),"native surface capture directory provided")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  for view: String in ["full","crown","bare","diffuse_crown","diffuse_bare"]:
   cloth.visible=not view.ends_with("bare")
   if view.begins_with("diffuse"):
    # Explicit neutral fixture control, separate from production voxel views.
    player.set_lamp_enabled(false);environment.environment.ambient_light_energy=1.;environment.environment.ambient_light_color=Color(.75,.75,.75)
   var eye:=Vector3(0,.48,1.0) if view=="full" else Vector3(-.08,.72,.46)
   player.global_position+=eye-player.camera.global_position
   player.camera.look_at(Vector3(0,.38,.1) if view=="full" else Vector3(-.08,.68,.1))
   for frame in 12:await get_tree().process_frame
   await RenderingServer.frame_post_draw
   check(get_viewport().get_texture().get_image().save_png(out.path_join(view+".png"))==OK,"loaded native surface capture saved: "+view)
  FileAccess.open(out.path_join("surface_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Uninstalled native rack/cloth surface diagnostic only; no installed support or deployment acceptance.","failures":failures},"\t"))
 print("V2 CAPACITY RACK SURFACE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
 atmosphere.free();player.free();environment.free()
 get_tree().quit(0 if failures.is_empty() else 1)
