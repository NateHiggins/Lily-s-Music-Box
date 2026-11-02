extends RefCounted
## Externally supplied world only: no Node/_ready/add_child/world composition.
const Programme=preload("res://tests/v2_city_south_garden_programme.gd")
var checks:Array[Dictionary]=[]
var host:Node

func _check(ok:bool,label:String)->void:
    checks.append({"ok":ok,"label":label});host.call("check",ok,"south garden review: "+label)

func _dependencies()->Dictionary:
    var result:Dictionary={}
    var paths:Array[String]=[get_script().resource_path,"res://tests/v2_city_south_garden_programme.gd","res://tests/v2_city_western_apartments_programme.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_floor_surface_test.gd","res://tests/OrisonV2SurfaceInventory.tscn","res://tests/fixtures/orison_city_horizon.json","res://data/orison_v2/exterior/city_horizon.json","res://assets/props/city_horizon_near_3_3.glb","res://assets/props/city_horizon_near_3_3_lod1.glb","res://assets/props/city_streets.glb","res://assets/props/orison_ground.glb","res://assets/props/city_ground_apron.glb"]
    for path:String in paths:
        _check(FileAccess.file_exists(path),"actual consumed source exists "+path)
        result["game/"+path.trim_prefix("res://")]=FileAccess.get_sha256(path)
    return result

func _runtime()->String:
    var root:=ProjectSettings.globalize_path("res://..").simplify_path();var output:Array=[]
    _check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)==0,"bind actual production runtime inputs")
    return str(output[0]).strip_edges() if not output.is_empty() else ""

func run(world:OrisonV2RuntimeRoot,supplied_host:Node)->Dictionary:
    host=supplied_host
    var started:=Time.get_ticks_msec();var directory:=OS.get_environment("SHOT_DIR")
    _check(world!=null and world.player!=null and world.safety_net!=null,"externally composed production world/player/safety supplied")
    _check(not directory.is_empty() and DisplayServer.get_name()!="headless","graphical existing output supplied")
    _check(host.get_viewport().get_visible_rect().size==Vector2(3440,1440),"native graphical3440x1440")
    _check(host.scene_file_path=="res://tests/OrisonV2SurfaceInventory.tscn","actual canonical surface scene remains entry owner")
    var dependencies:=_dependencies();var runtime:=_runtime()
    var before_errors:=checks.filter(func(row:Dictionary)->bool:return not bool(row.ok)).size()
    if before_errors>0:return {"executed":false,"passed":false}
    _grade_discovery(world,runtime,dependencies,directory)
    var pose:=world.player.global_transform;var camera_pose:=world.player.camera.transform
    var velocity:=world.player.velocity;var physics:=world.player.is_physics_processing()
    var prior_camera:=host.get_viewport().get_camera_3d();var mouse:=Input.mouse_mode
    var programme:Dictionary=await Programme.new().run(world,host)
    var optical_views:Array=await _optical_views(world,directory)
    _check(world.player.global_transform.is_equal_approx(pose) and world.player.camera.transform.is_equal_approx(camera_pose),"player/camera poses restored after programme")
    _check(world.player.velocity.is_equal_approx(velocity) and world.player.is_physics_processing()==physics,"prior velocity/processing ownership restored")
    _check(host.get_viewport().get_camera_3d()==prior_camera and Input.mouse_mode==mouse,"prior view and mouse owner restored")
    _check(dependencies==_dependencies() and runtime==_runtime(),"all consumed inputs remain fixed")
    var failed:=checks.filter(func(row:Dictionary)->bool:return not bool(row.ok)).size()
    var passed:=failed==0 and bool(programme.get("passed",false))
    var elapsed_s:float=(Time.get_ticks_msec()-started)/1000.
    var record:Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"Actual south Western gardens in one externally supplied canonical surface world:one validated public-apron placement then14connected normal-controller street/portico/garden/vault/court legs. Original production capsule/step/support guards;separate surface contract covers physical inventory. Four separately posed source-bound whole-body optical views with actual unfiltered face witnesses and hidden-target pixel controls. No second world,scenic door interaction,save,continuous450mjourney,performance or artistic acceptance.","execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":elapsed_s},"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scene_path":host.scene_file_path,"test_dependencies":dependencies,"runtime_inputs_sha256":runtime},"checks":checks,"failures":failed+int(not bool(programme.get("passed",false))),"programme":programme,"optical_views":optical_views,"contracts":{"south_garden_access":{"executed":bool(programme.get("movement_attempted",false)),"passed":passed}}}
    var path:=directory.path_join("south_garden_access.runtime.json")
    var file:=FileAccess.open(path,FileAccess.WRITE)
    _check(file!=null,"write separate actual access contract")
    var written:=false
    if file!=null:
        file.store_string(JSON.stringify(record,"\t"));written=file.get_error()==OK;file.close()
        _check(written,"access contract bytes written")
    print("SOUTH GARDEN ACCESS: ","PASS" if passed and written else "FAIL"," checks=",int(programme.get("checks",0))+checks.size()," failures=",record.failures)
    return record

func _grade_discovery(world:OrisonV2RuntimeRoot,runtime:String,dependencies:Dictionary,directory:String)->void:
    # Same actual static-box classification as GradeOwnerSurvey, sampled in
    # this supplied world before the actor travels. No world or floor is added.
    var root:Node3D=world.adapter.root
    var records:Array=[];var skipped:Dictionary={};var poses:Dictionary={}
    for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
        if not shape.get_parent() is StaticBody3D or shape.disabled or shape.shape==null:continue
        if ((shape.get_parent() as StaticBody3D).collision_layer&1)==0:continue
        if not shape.shape is BoxShape3D:
            var kind:String=shape.shape.get_class();skipped[kind]=int(skipped.get(kind,0))+1;continue
        var pose:Transform3D=root.global_transform.affine_inverse()*shape.global_transform
        var box:AABB=pose*AABB(-shape.shape.size*.5,shape.shape.size)
        if box.position.y>=.050001 or box.end.y<=-4.:continue
        var aligned:=true
        for axis:Vector3 in [pose.basis.x,pose.basis.y,pose.basis.z]:
            var active:=0
            for component:float in [axis.x,axis.y,axis.z]:
                if absf(component)>.00003:active+=1
            aligned=aligned and active==1 and absf(axis.length()-1.)<.00003
        records.append({"owner":str(world.get_path_to(shape.get_parent())),"shape_owner":str(shape.name),"shape_type":"BoxShape3D","aligned":aligned,"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],"pose":_pose(pose)})
    var receiving:=world.get_node_or_null("BodegaReceiving") as Node3D
    _check(receiving!=null and receiving.get_child_count()>0 and receiving.get_child(0) is Node3D,"actual receiving registration exists for grade discovery")
    if receiving==null or receiving.get_child_count()==0:return
    var native_receiving:Node3D=receiving.get_child(0)
    poses.receiving=_pose(root.global_transform.affine_inverse()*native_receiving.global_transform)
    poses.city=_pose(root.global_transform.affine_inverse()*(world.get_node("CityShells") as Node3D).global_transform)
    _check(records.size()==571,"complete retained static-box cohort sampled before route")
    # GradeSourceSnapshot normalizes its declared text dependencies. Binary
    # geometry stays bound by the production runtime hash and access contract.
    var text_dependencies:Dictionary={}
    for relative:String in dependencies:
        if relative.get_extension() in ["gd","tscn","json"]:text_dependencies[relative]=dependencies[relative]
    var data:Dictionary={"evidence_class":"INERT","scope":"Fresh actual aligned static boxes in the one canonical surface/access world before movement. Non-box shapes remain skipped; no bounding-box solid substitution or runtime acceptance.","records":records,"skipped_shapes":skipped,"poses":poses,"source":{"runtime_inputs_sha256":runtime,"test_dependencies":text_dependencies},"failures":checks.filter(func(row:Dictionary)->bool:return not bool(row.ok)).size()}
    var file:=FileAccess.open(directory.path_join("grade_owners.json"),FileAccess.WRITE)
    _check(file!=null,"write actual same-world grade discovery")
    if file!=null:file.store_string(JSON.stringify(data,"\t"));file.close()

static func _pose(pose:Transform3D)->Dictionary:
    return {"origin":[pose.origin.x,pose.origin.y,pose.origin.z],"x_axis":[pose.basis.x.x,pose.basis.x.y,pose.basis.x.z],"y_axis":[pose.basis.y.x,pose.basis.y.y,pose.basis.y.z],"z_axis":[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z]}

func _point(value:Array)->Vector3:
    return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _first(world:OrisonV2RuntimeRoot,eye:Vector3,point:Vector3)->Dictionary:
    var query:=PhysicsRayQueryParameters3D.create(eye,point+(point-eye).normalized()*.002,1)
    var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
    var draw:Node=null
    if not hit.is_empty():
        draw=hit.collider
        while draw!=null and not draw is MeshInstance3D:draw=draw.get_parent()
    return {"draw":str(draw.name) if draw!=null else "","error_m":hit.position.distance_to(point) if not hit.is_empty() else -1.}

func _optical_views(world:OrisonV2RuntimeRoot,directory:String)->Array:
    var views:Array=[];var plan_path:=OS.get_environment("ORISON_SOUTH_GARDEN_OPTICAL_PLAN")
    _check(FileAccess.file_exists(plan_path),"explicit source-bound native optical proposal exists")
    if not FileAccess.file_exists(plan_path):return views
    var raw:=FileAccess.get_file_as_string(plan_path);var plan:Dictionary=JSON.parse_string(raw)
    var plan_sha:=FileAccess.get_sha256(plan_path)
    _check(plan.get("evidence_class")=="INERT" and plan.get("stations",[]).size()==4,"four diagnostic proposals,not prior acceptance")
    for relative:String in plan.get("source_bindings",{}):
        _check(FileAccess.get_sha256("res://../"+relative)==str(plan.source_bindings[relative]),"actual native optical source "+relative)
    var horizon:=world.get_node("CityShells/CityHorizon") as Node3D
    var prior:=host.get_viewport().get_camera_3d();var camera:=Camera3D.new()
    # This helper has no lifecycle. Its borrowed camera is attached to the supplied host.
    host.add_child(camera);camera.cull_mask=world.player.camera.cull_mask
    camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=.05;camera.far=20000.;camera.make_current()
    for station:Dictionary in plan.get("stations",[]):
        var identity:=str(station.building);var draws:Array[MeshInstance3D]=[];var names:Array[String]=[]
        var bounds:AABB;var first:=true
        _check(identity in Programme.SOUTH_IDS,"intended optical subject "+identity)
        for draw:MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
            if str(draw.get_meta("v2_city_horizon_building",""))!=identity:continue
            draws.append(draw);names.append(str(draw.name))
            var body:=draw.get_node("HorizonCollision") as StaticBody3D
            var shape:=body.get_child(0) as CollisionShape3D
            _check(shape.shape is ConcavePolygonShape3D,"actual source-bound physical stock "+str(draw.name))
            if not shape.shape is ConcavePolygonShape3D:continue
            var frame:=horizon.global_transform.affine_inverse()*draw.global_transform
            for vertex:Vector3 in (shape.shape as ConcavePolygonShape3D).get_faces():
                var point:=frame*vertex
                if first:bounds=AABB(point,Vector3.ZERO);first=false
                else:bounds=bounds.expand(point)
        names.sort()
        _check(not first and names==station.draws and draws.size()==(10 if identity.ends_with("P1") else 11),"complete intended near-source partitions "+str(station.id))
        var expected:Array=station.bounds_local
        _check(bounds.position.distance_to(_point(expected.slice(0,3)))<.0001 and bounds.end.distance_to(_point(expected.slice(3,6)))<.0001,"whole physical bounds match native proposal "+str(station.id))
        camera.fov=float(station.fov_vertical_deg);camera.global_position=horizon.to_global(_point(station.eye_local))
        camera.look_at(horizon.to_global(_point(station.target_local)),Vector3.UP)
        var low:=Vector2.ONE;var high:=Vector2.ZERO;var size:=host.get_viewport().get_visible_rect().size
        for corner in 8:
            var point:=horizon.to_global(bounds.get_endpoint(corner));var uv:=camera.unproject_position(point)/size
            low=low.min(uv);high=high.max(uv)
            _check(not camera.is_position_behind(point) and uv.x>=.06 and uv.y>=.06 and uv.x<=.94 and uv.y<=.94,"whole body framed "+str(station.id)+"/"+str(corner))
        var witnesses:Array=[]
        for witness:Dictionary in station.witnesses:
            var actual:=_first(world,camera.global_position,horizon.to_global(_point(witness.point)))
            _check(actual.draw==str(witness.draw) and float(actual.error_m)<.0001,"unfiltered actual first-hit optical stock "+str(station.id)+"/"+str(witness.draw))
            witnesses.append({"source":witness,"actual":actual})
        for frame in 4:await RenderingServer.frame_post_draw
        _check(host.get_viewport().get_camera_3d()==camera,"actual intended camera active")
        var visible:=host.get_viewport().get_texture().get_image();var filename:=str(station.id)+".png"
        _check(visible.save_png(directory.path_join(filename))==OK,"actual whole-body production capture "+filename)
        var old:Dictionary={};var pose:=camera.global_transform;var minute:=world.campaign_clock.minute_of_day()
        for draw:MeshInstance3D in draws:
            _check(draw.is_visible_in_tree(),"production optical subject initially visible "+str(draw.name));old[draw]=draw.visible;draw.visible=false
        for frame in 4:await RenderingServer.frame_post_draw
        var hidden:=host.get_viewport().get_texture().get_image();var hidden_name:=str(station.id)+"_hidden.png"
        _check(hidden.save_png(directory.path_join(hidden_name))==OK,"actual same-pose hidden capture")
        var hidden_hit:=_first(world,camera.global_position,horizon.to_global(_point(station.witnesses[0].point)))
        _check(hidden_hit.draw==str(station.witnesses[0].draw) and float(hidden_hit.error_m)<.0001,"hidden presentation retains physical stock")
        _check(camera.global_transform.is_equal_approx(pose) and is_equal_approx(minute,world.campaign_clock.minute_of_day()),"same pose and campaign time retained for hidden control")
        for draw:MeshInstance3D in old:draw.visible=bool(old[draw])
        for frame in 4:await RenderingServer.frame_post_draw
        var restored:=host.get_viewport().get_texture().get_image();var count:=0;var changed:=0;var delta_sum:=0.;var return_sum:=0.
        for y in range(int(ceil(low.y*size.y)),int(floor(high.y*size.y)),16):
            for x in range(int(ceil(low.x*size.x)),int(floor(high.x*size.x)),16):
                var a:=visible.get_pixel(x,y);var b:=hidden.get_pixel(x,y);var c:=restored.get_pixel(x,y)
                var delta:=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
                count+=1;delta_sum+=delta;return_sum+=Vector3(a.r-c.r,a.g-c.g,a.b-c.b).length()
                if delta>.02:changed+=1
        var changed_fraction:=float(changed)/maxi(count,1)
        _check(count>0 and changed_fraction>.1 and delta_sum/maxi(count,1)>return_sum/maxi(count,1)*2.+.002,"intended body dominates actual rendered difference "+str(station.id))
        views.append({"id":station.id,"building":identity,"eye_local":station.eye_local,"target_local":station.target_local,"fov":camera.fov,"bounds_uv_min":[low.x,low.y],"bounds_uv_max":[high.x,high.y],"witnesses":witnesses,"file":filename,"sha256":FileAccess.get_sha256(directory.path_join(filename)),"hidden_file":hidden_name,"hidden_sha256":FileAccess.get_sha256(directory.path_join(hidden_name)),"changed_fraction":changed_fraction,"samples":count,"played_support_claim":false,"proposal_sha256":plan_sha})
    if is_instance_valid(prior):prior.make_current()
    camera.free()
    _check(FileAccess.get_sha256(plan_path)==plan_sha and views.size()==4,"four frozen optical proposals executed")
    for relative:String in plan.get("source_bindings",{}):_check(FileAccess.get_sha256("res://../"+relative)==str(plan.source_bindings[relative]),"optical source stays frozen "+relative)
    return views
