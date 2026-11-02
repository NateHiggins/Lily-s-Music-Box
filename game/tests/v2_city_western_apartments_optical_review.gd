extends "res://tests/v2_grade_owner_survey.gd"
## Optical-only hook in one composed world. No controller route or new geometry.
const IDS=["HORIZON_NEAR_3_2_P1","HORIZON_NEAR_3_2_P2"]
var plan:Dictionary={}
var plan_path:String
var plan_sha:String
var output:String
var views:Array[Dictionary]=[]
var negative_controls:Array[Dictionary]=[]

func _run()->void:
    # Native debug-window setup yields twice; reject bad admission before startup.
    await get_tree().process_frame
    await get_tree().process_frame
    output=OS.get_environment("SHOT_DIR")
    plan_path=OS.get_environment("ORISON_CITY_OPTICAL_PLAN")
    _check(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output)==OK,"explicit writable optical output")
    _check(DisplayServer.get_name()!="headless" and get_viewport().get_visible_rect().size==Vector2(3440,1440),"native graphical3440x1440")
    _check(FileAccess.file_exists(plan_path),"external native-face proposal exists")
    if failures>0:get_tree().quit(1);return
    plan=JSON.parse_string(FileAccess.get_file_as_string(plan_path))
    plan_sha=FileAccess.get_sha256(plan_path)
    _check(plan.get("evidence_class")=="INERT" and plan.get("stations",[]).size()==4,"four proposed optical stations,not prior acceptance")
    for relative:String in plan.get("source_bindings",{}):
        _check(FileAccess.get_sha256("res://../"+relative)==str(plan.source_bindings[relative]),"actual native proposal input "+relative)
    var dependencies:=_dependencies()
    if failures>0 or dependencies.is_empty():get_tree().quit(1);return
    await super._run()

func _point(value:Array)->Vector3:
    return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _v(point:Vector3)->Array:
    return [point.x,point.y,point.z]

func _uv(point:Vector2)->Array:
    return [point.x,point.y]

func _first(world:OrisonV2RuntimeRoot,eye:Vector3,point:Vector3)->Dictionary:
    var ray:=PhysicsRayQueryParameters3D.create(eye,point+(point-eye).normalized()*.002,1)
    # No excluded blockers. Mesh visibility never disables collision.
    var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
    var draw:MeshInstance3D=null
    if not hit.is_empty():
        var parent:Node=hit.collider
        while parent!=null and not parent is MeshInstance3D:parent=parent.get_parent()
        draw=parent as MeshInstance3D
    return {"draw":str(draw.name) if draw!=null else "","hit":not hit.is_empty(),"error_m":hit.position.distance_to(point) if not hit.is_empty() else -1.}

func _inside(camera:Camera3D,point:Vector3,margin:float)->bool:
    var uv:=camera.unproject_position(point)/get_viewport().get_visible_rect().size
    return not camera.is_position_behind(point) and uv.x>=margin and uv.y>=margin and uv.x<=1.-margin and uv.y<=1.-margin

func _body(horizon:Node3D,identity:String)->Dictionary:
    var draws:Array[MeshInstance3D]=[]
    var names:Array[String]=[]
    var bounds:AABB
    var first:=true
    for draw:MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
        if str(draw.get_meta("v2_city_horizon_building",""))!=identity:continue
        draws.append(draw);names.append(str(draw.name))
        var body:=draw.get_node("HorizonCollision") as StaticBody3D
        var shape:=body.get_child(0) as CollisionShape3D
        _check(shape.shape is ConcavePolygonShape3D,"actual near-source collision stock "+str(draw.name))
        if not shape.shape is ConcavePolygonShape3D:continue
        var frame:=horizon.global_transform.affine_inverse()*draw.global_transform
        for vertex:Vector3 in (shape.shape as ConcavePolygonShape3D).get_faces():
            var point:=frame*vertex
            if first:bounds=AABB(point,Vector3.ZERO);first=false
            else:bounds=bounds.expand(point)
    names.sort()
    _check(draws.size()==11 and not first,"eleven complete source partitions "+identity)
    return {"draws":draws,"names":names,"bounds":bounds}

func _frames()->void:
    for frame in 4:await RenderingServer.frame_post_draw

func _save(image:Image,name:String)->Dictionary:
    var path:=output.path_join(name)
    _check(image.save_png(path)==OK,"actual optical capture "+name)
    return {"file":name,"sha256":FileAccess.get_sha256(path)}

func _difference(a:Image,b:Image,c:Image,rect:Rect2)->Dictionary:
    var samples:=0;var changed:=0;var hidden_mean:=0.;var return_mean:=0.
    var size:=Vector2(a.get_width(),a.get_height())
    var low:=Vector2i((rect.position*size).ceil());var high:=Vector2i((rect.end*size).floor())
    for y in range(low.y,high.y,16):
        for x in range(low.x,high.x,16):
            var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y);var restored:=c.get_pixel(x,y)
            var delta:=Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()
            hidden_mean+=delta;return_mean+=Vector3(first.r-restored.r,first.g-restored.g,first.b-restored.b).length();samples+=1
            if delta>.02:changed+=1
    return {"samples":samples,"changed_samples":changed,"changed_fraction":float(changed)/maxi(samples,1),"hidden_mean_rgb_distance":hidden_mean/maxi(samples,1),"return_mean_rgb_distance":return_mean/maxi(samples,1),"sampling_stride_px":16}

func _after_discovery(world:OrisonV2RuntimeRoot)->void:
    var horizon:=world.get_node("CityShells/CityHorizon") as Node3D
    var cache:Dictionary={}
    for identity:String in IDS:cache[identity]=_body(horizon,identity)
    var prior:=get_viewport().get_camera_3d()
    var camera:=Camera3D.new();add_child(camera)
    camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=.05;camera.far=20000.;camera.make_current()
    var minute:=world.campaign_clock.minute_of_day()
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
    for identity:String in IDS:
        var row:Dictionary={}
        for profile:Dictionary in fixture.buildings:
            if str(profile.id)==identity:row=profile
        _check(not row.is_empty(),"intended profile exists "+identity)
        var middle:float=(float(row.rect[1])+float(row.rect[3]))*.5
        # Reproduce the old double-converted rect pose as a rejecting control.
        camera.fov=110.;camera.global_position=horizon.to_global(Vector3(float(row.rect[2])+12.,1.62,-middle))
        camera.look_at(horizon.to_global(Vector3(float(row.rect[2])-5.,float(row.height_m)*.45,-middle)),Vector3.UP)
        var center:Vector3=horizon.to_global((cache[identity].bounds as AABB).get_center())
        var old_hit:=_first(world,camera.global_position,horizon.to_global(Vector3(float(row.rect[2])-5.,float(row.height_m)*.45,-middle)))
        var framed:=_inside(camera,center,0.)
        _check(not framed and not str(old_hit.draw).begins_with(identity+"__"),"legacy mirrored pose rejects intended subject "+identity)
        negative_controls.append({"building":identity,"legacy_center_inside":framed,"legacy_first_hit":old_hit,"legacy_eye_world":_v(camera.global_position)})
    for station:Dictionary in plan.stations:
        var identity:=str(station.building)
        _check(identity in IDS and cache.has(identity),"named station subject "+identity)
        var body:Dictionary=cache[identity];var expected:Array=station.bounds_local;var bounds:AABB=body.bounds
        _check(bounds.position.distance_to(_point(expected.slice(0,3)))<.0001 and bounds.end.distance_to(_point(expected.slice(3,6)))<.0001,"actual near-source bounds match native proposal "+str(station.id))
        _check(body.names==station.draws,"exact complete source draw roster "+str(station.id))
        camera.fov=float(station.fov_vertical_deg);camera.global_position=horizon.to_global(_point(station.eye_local));camera.look_at(horizon.to_global(_point(station.target_local)),Vector3.UP)
        var min_uv:=Vector2.ONE;var max_uv:=Vector2.ZERO
        for corner in 8:
            var point:=horizon.to_global(bounds.get_endpoint(corner));var uv:=camera.unproject_position(point)/get_viewport().get_visible_rect().size
            min_uv=min_uv.min(uv);max_uv=max_uv.max(uv)
            _check(_inside(camera,point,.06),"complete subject physical bounds framed "+str(station.id)+"/"+str(corner))
        var witness_rows:Array[Dictionary]=[]
        for witness:Dictionary in station.witnesses:
            var point:=horizon.to_global(_point(witness.point));var result:=_first(world,camera.global_position,point)
            _check(result.draw==str(witness.draw) and float(result.error_m)<.0001 and _inside(camera,point,.06),"unfiltered actual-world first-hit subject face "+str(station.id)+"/"+str(witness.draw))
            witness_rows.append({"source":witness,"actual":result})
        await _frames()
        _check(get_viewport().get_camera_3d()==camera,"intended optical camera remains active")
        var visible:=get_viewport().get_texture().get_image();var positive:=_save(visible,str(station.id)+".png")
        var pose:=camera.global_transform;var fov:=camera.fov;var old_visibility:Dictionary={}
        for draw:MeshInstance3D in body.draws:
            _check(draw.is_visible_in_tree(),"production subject initially visible "+str(draw.name));old_visibility[draw]=draw.visible;draw.visible=false
        await _frames()
        _check(get_viewport().get_camera_3d()==camera,"hidden control retains active optical camera")
        var hidden_physics:=_first(world,camera.global_position,horizon.to_global(_point(station.witnesses[0].point)))
        _check(hidden_physics.draw==str(station.witnesses[0].draw) and float(hidden_physics.error_m)<.0001,"hidden presentation leaves physical first-hit stock intact")
        var hidden:=get_viewport().get_texture().get_image();var control:=_save(hidden,str(station.id)+"_hidden.png")
        _check(camera.global_transform.is_equal_approx(pose) and is_equal_approx(camera.fov,fov) and is_equal_approx(minute,world.campaign_clock.minute_of_day()),"same-pose/FOV/clock hidden-target optical control")
        for draw:MeshInstance3D in old_visibility:draw.visible=bool(old_visibility[draw])
        await _frames()
        var restored:=get_viewport().get_texture().get_image()
        var difference:=_difference(visible,hidden,restored,Rect2(min_uv,max_uv-min_uv))
        _check(float(difference.changed_fraction)>.1 and float(difference.hidden_mean_rgb_distance)>float(difference.return_mean_rgb_distance)*2.+.002,"intended subject produces dominant rendered pixel difference "+str(station.id))
        if float(difference.changed_fraction)<=.1:_save(restored,str(station.id)+"_return_failure.png")
        views.append({"id":station.id,"building":identity,"scope":station.scope,"eye_local":station.eye_local,"target_local":station.target_local,"eye_world":_v(camera.global_position),"target_world":_v(horizon.to_global(_point(station.target_local))),"fov":camera.fov,"bounds_uv_min":_uv(min_uv),"bounds_uv_max":_uv(max_uv),"witnesses":witness_rows,"capture":positive,"hidden_control":control,"hidden_physics_control":hidden_physics,"pixel_difference":difference,"played_support_claim":false})
    if is_instance_valid(prior):prior.make_current()
    camera.free()
    _check(FileAccess.get_sha256(plan_path)==plan_sha,"proposal remains unchanged")
    for relative:String in plan.source_bindings:_check(FileAccess.get_sha256("res://../"+relative)==str(plan.source_bindings[relative]),"frozen native input "+relative)
    _check(initial_inputs==_inputs() and bindings==_dependencies(),"all runtime/rendering/test inputs stay fixed")
    _check(views.size()==4 and negative_controls.size()==2,"four technical views and two mirrored-pose negatives executed")
    var record:Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"Single actual composed-world optical diagnostic:four complete-bound views,32unfiltered face witnesses,mirrored-pose rejection and same-pose hidden/reveal pixel controls. No route/player placement,played support,performance,surface renewal or artistic acceptance.","execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"test_dependencies":bindings,"runtime_inputs_sha256":initial_inputs.runtime,"surface_inputs_sha256":initial_inputs.surface},"proposal_path":plan_path,"proposal_sha256":plan_sha,"source_bindings":plan.source_bindings,"checks":checks,"failures":failures,"views":views,"legacy_negative_controls":negative_controls,"startup_ms":world.startup_ms,"viewport":[3440,1440],"campaign_minute":minute,"contracts":{"subject_verified_optical_views":{"executed":views.size()==4,"passed":failures==0}}}
    var file:=FileAccess.open(output.path_join("optical.runtime.json"),FileAccess.WRITE)
    _check(file!=null,"write optical runtime contract")
    if file!=null:file.store_string(JSON.stringify(record,"\t"));file.close()
    print("WESTERN APARTMENTS OPTICAL: ",checks.size()," checks; ",failures," failures; ",views.size()," views")
