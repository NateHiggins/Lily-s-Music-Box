extends Node3D
func _ready() -> void:
 RealityState.persistence_enabled=false
 var env=WorldEnvironment.new(); env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.06,.07,.08)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color(.3,.3,.3); env.environment.ambient_light_energy=.15
 add_child(env)
 var camera=Camera3D.new(); add_child(camera); camera.position=Vector3(-4,1.7,2); camera.look_at(Vector3(1,2.8,-1)); camera.make_current()
 var box=BoxMesh.new(); box.size=Vector3(14,.2,8)
 var draw=MeshInstance3D.new(); draw.mesh=preload("res://scripts/building/v2_metre_box_uv.gd").chart(box); draw.position=Vector3(0,3.1,0); add_child(draw)
 var light=OmniLight3D.new(); light.position=Vector3(0,2.83,0); light.light_energy=2.1; light.omni_range=5.5; light.omni_attenuation=1.4
 light.light_color=Color(1,.86,.66);light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE;light.shadow_bias=.012;light.shadow_normal_bias=.08;light.light_size=.1;light.shadow_enabled=true;add_child(light)
 var material=preload("res://scripts/building/orison_v2_architectural_materials.gd").new().material_for("Ceiling","public")
 material.set_shader_parameter("uv_mode",0)
 var plain=StandardMaterial3D.new();plain.albedo_color=Color(.7,.7,.65);plain.roughness=.8
 var directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
 for kind in ["shader","catalogue","plain","shader_no_shadow","shader_no_normal","bias04","bias08","bias16","point","small","reverse","bias32","bias64"]:
  light.shadow_enabled=kind!="shader_no_shadow"
  light.shadow_bias=.012; light.shadow_normal_bias=.08; light.light_size=.1; light.shadow_reverse_cull_face=false
  if kind=="reverse":light.shadow_reverse_cull_face=true
  if kind=="bias32":light.shadow_bias=.32;light.shadow_normal_bias=.3
  if kind=="bias64":light.shadow_bias=.64;light.shadow_normal_bias=.4
  if kind=="point":light.light_size=0
  if kind=="small":light.light_size=.025
  if kind=="bias04":light.shadow_bias=.04;light.shadow_normal_bias=.12
  if kind=="bias08":light.shadow_bias=.08;light.shadow_normal_bias=.16
  if kind=="bias16":light.shadow_bias=.16;light.shadow_normal_bias=.2
  material.set_shader_parameter("normal_scale",.10);material.set_shader_parameter("detail_normal_strength",.10)
  draw.material_override=MatLib.get_mat("trim") if kind=="catalogue" else plain if kind=="plain" else material
  if kind=="shader_no_normal":material.set_shader_parameter("normal_scale",0.0);material.set_shader_parameter("detail_normal_strength",0.0)
  await get_tree().create_timer(.4).timeout
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(directory.path_join(kind+".png"))
  print("CEILING DIAGNOSTIC: ",kind)
 get_tree().quit()
