extends Node3D
## Native pose/skin diagnostic; occupied mirror/input qualification is separate.
var holder:PlayerController
var avatar:Node3D
var checks:Array=[]
var samples:Array=[]
var drawn:Dictionary={}
var native:Dictionary={}
var body_ids:Array[int]=[]
var head:=-1
var front:=-1
var observer:Camera3D
var face_rectangle:=Rect2i()
var measure_face_bounds:=false
func check(ok:bool,label:String) -> void:
 checks.append({"name":label,"passed":ok});print("PLAYER RIG: ",label," = ",ok)
func _ready() -> void:run.call_deferred()
func _native_pose() -> void:
 var rig:Skeleton3D=avatar.skeleton
 native={"position":rig.get_bone_pose_position(head),"scale":rig.get_bone_pose_scale(head),"body":[]}
 for index:int in body_ids:native.body.append(rig.get_bone_global_pose(index))
func _drawn_pose() -> void:
 var rig:Skeleton3D=avatar.skeleton
 var origin:Vector3=rig.to_global(rig.get_bone_global_pose(head).origin)
 var forward:Vector3=(rig.to_global(rig.get_bone_global_pose(front).origin)-origin).normalized()
 var error:float=rad_to_deg(acos(clampf(forward.dot(-holder.camera.global_basis.z),-1,1)))
 var retained:bool=not native.is_empty() and rig.get_bone_pose_position(head).is_equal_approx(native.position) and rig.get_bone_pose_scale(head).is_equal_approx(native.scale)
 if not native.is_empty():
  for i in body_ids.size():retained=retained and rig.get_bone_global_pose(body_ids[i]).is_equal_approx(native.body[i])
 drawn={"error_degrees":error,"forward":forward,"camera_forward":-holder.camera.global_basis.z,"position":origin,"retained_body_position_scale":retained}
 if measure_face_bounds:
  measure_face_bounds=false
  var mesh:MeshInstance3D=avatar.find_children("*","MeshInstance3D",true,false)[0]
  var bind:int=mesh.material_override.get_shader_parameter("head_bind")
  var arrays:Array=mesh.mesh.surface_get_arrays(0)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var pose:Transform3D=rig.global_transform*rig.get_bone_global_pose(head)*mesh.skin.get_bind_pose(bind)
  var box:=Rect2();var first:=true
  for vertex in points.size():
   var weight:=0.0
   for slot in 4:
    if bones[vertex*4+slot]==bind:weight+=weights[vertex*4+slot]
   if weight<.99:continue
   var pixel:Vector2=observer.unproject_position(pose*points[vertex])
   if first:box=Rect2(pixel,Vector2.ZERO);first=false
   else:box=box.expand(pixel)
  face_rectangle=Rect2i(box.position+box.size*Vector2(.30,.25),box.size*Vector2(.40,.40))
func run() -> void:
 RealityState.persistence_enabled=false
 holder=PlayerController.new();add_child(holder);holder.set_physics_process(false)
 avatar=preload("res://scripts/player/doodle_player_avatar.gd").new();avatar.holder=holder;holder.add_child(avatar)
 check(avatar.native_ready and avatar.skeleton.get_bone_count()==52,"native owner rig and semantic head markers resolve")
 if not avatar.native_ready:get_tree().quit(1);return
 head=avatar.skeleton.find_bone("smartrig_Head");front=avatar.skeleton.find_bone("headfront")
 for bone:String in ["smartrig_Neck","smartrig_LeftHand","smartrig_RightHand","smartrig_LeftFoot"]:body_ids.append(avatar.skeleton.find_bone(bone))
 avatar.animator.mixer_applied.connect(_native_pose)
 avatar.skeleton.skeleton_updated.connect(_drawn_pose)
 avatar.set_reflection_active(true)
 observer=Camera3D.new();add_child(observer);observer.position=Vector3(0,1.1,-2.0);observer.look_at(Vector3(0,1.05,0));observer.make_current()
 var environment:=WorldEnvironment.new();var finish:=Environment.new();finish.background_mode=Environment.BG_COLOR;finish.background_color=Color(.3,.3,.3);finish.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;finish.ambient_light_color=Color.WHITE;finish.ambient_light_energy=.8;environment.environment=finish;add_child(environment)
 var light:=DirectionalLight3D.new();add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
 var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
 # The observer is deliberately not the authoritative aim camera.
 holder.camera.rotation.x=deg_to_rad(35)
 avatar.head_aim.active=false;avatar.animator.seek(8.4,true);avatar.animator.advance(0)
 for i in 3:await RenderingServer.frame_post_draw
 check(not drawn.is_empty() and drawn.error_degrees>5,"disabled correction reproduces the supplied idle looking away from camera aim")
 get_viewport().get_texture().get_image().save_png(directory.path_join("aim_uncorrected.png"))
 samples.append({"control":"uncorrected","drawn":drawn.duplicate(true)})
 avatar.head_aim.active=true
 var body_poses:Array=[]
 for pose:Vector3 in [Vector3(0,0,0),Vector3(0,35,4.8),Vector3(0,-35,8.4),Vector3(65,20,4.8),Vector3(-110,-55,8.4),Vector3(170,70,2.0)]:
  holder.rotation.y=deg_to_rad(pose.x);holder.camera.rotation.x=deg_to_rad(pose.y)
  avatar.animator.seek(pose.z,true);avatar.animator.advance(0)
  observer.global_position=holder.global_position-holder.global_basis.z*2.0+Vector3.UP*1.1
  observer.look_at(holder.global_position+Vector3.UP*1.05)
  for i in 3:await RenderingServer.frame_post_draw
  check(not drawn.is_empty() and drawn.error_degrees<.25,"face aligns with player camera across yaw/pitch/idle: "+str(pose))
  check(drawn.get("retained_body_position_scale",false),"head translation/scale and animated neck/hands/foot are preserved")
  body_poses.append(str(native.get("body",[])))
  samples.append({"yaw_pitch_idle":str(pose),"drawn":drawn.duplicate(true)})
  get_viewport().get_texture().get_image().save_png(directory.path_join("aim_%02d.png"%samples.size()))
 check(body_poses[0]!=body_poses[1] and body_poses[1]!=body_poses[2],"supplied body idle continues across sampled times")
 holder.velocity=Vector3(1,0,0);holder.camera.rotation.x=deg_to_rad(-20)
 for i in 4:await RenderingServer.frame_post_draw
 check(avatar._moving and drawn.error_degrees<.25,"moving-player resting pose still tracks aim")
 holder.velocity=Vector3.ZERO;holder.rotation=Vector3.ZERO;holder.camera.rotation=Vector3.ZERO
 avatar.set_process(false);avatar.animator.active=false;avatar.animator.seek(0,true);avatar.animator.advance(0)
 observer.position=Vector3(0,1.1,-2.0);observer.look_at(Vector3(0,1.05,0))
 measure_face_bounds=true
 for i in 3:await RenderingServer.frame_post_draw
 var face_ok:=face_rectangle.size.x>8 and face_rectangle.size.y>8 and Rect2i(Vector2i.ZERO,get_viewport().size).encloses(face_rectangle)
 check(face_ok,"native head-weighted geometry supplies a visible interior face sample")
 if face_ok:
  var lit:=get_viewport().get_texture().get_image();lit.save_png(directory.path_join("face_side_lit.png"))
  finish.ambient_light_energy=0;light.light_energy=0
  for i in 3:await RenderingServer.frame_post_draw
  var dark:=get_viewport().get_texture().get_image();dark.save_png(directory.path_join("face_dark.png"))
  var difference:=0.0;var brightest:=0.0;var darkest:=1.0
  for y in range(face_rectangle.position.y,face_rectangle.end.y):
   for x in range(face_rectangle.position.x,face_rectangle.end.x):
    var a:=lit.get_pixel(x,y);var b:=dark.get_pixel(x,y)
    difference+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
    var luma:=b.r*.2126+b.g*.7152+b.b*.0722
    brightest=maxf(brightest,luma);darkest=minf(darkest,luma)
  difference/=float(face_rectangle.get_area())
  check(difference<.02 and brightest>.4 and darkest<.2,"face stays evenly readable without ambient/key light and preserves black ink")
  var mesh:MeshInstance3D=avatar.find_children("*","MeshInstance3D",true,false)[0]
  var bind:int=mesh.material_override.get_shader_parameter("head_bind")
  mesh.material_override.set_shader_parameter("head_bind",-1)
  for i in 3:await RenderingServer.frame_post_draw
  var control:=get_viewport().get_texture().get_image();control.save_png(directory.path_join("face_dark_no_fill.png"))
  var control_peak:=0.0
  for y in range(face_rectangle.position.y,face_rectangle.end.y):
   for x in range(face_rectangle.position.x,face_rectangle.end.x):
    var pixel:=control.get_pixel(x,y);control_peak=maxf(control_peak,pixel.r*.2126+pixel.g*.7152+pixel.b*.0722)
  check(control_peak<brightest*.25,"disabled head fill reproduces the unreadable dark face")
  mesh.material_override.set_shader_parameter("head_bind",bind)
  samples.append({"control":"face_lighting","rectangle":str(face_rectangle),"mean_rgb_difference":difference,"dark_min":darkest,"dark_max":brightest,"no_fill_max":control_peak})
 holder.velocity=Vector3.ZERO;avatar.set_reflection_active(false)
 check(not avatar.animator.active and not avatar.head_aim.active,"animation and aim modifier sleep with unused reflection")
 var failed:Array=checks.filter(func(row):return not row.passed)
 FileAccess.open(directory.path_join("rig.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failed,"samples":samples,"animation_names":avatar.animator.get_animation_list(),"limits":"Native skinned render and post-modifier bone checks; not an occupied-world playtest, locomotion acceptance or performance qualification."},"\t"))
 print("PLAYER RIG BENCH: ","PASS" if failed.is_empty() else "FAIL")
 get_tree().quit(0 if failed.is_empty() else 1)
