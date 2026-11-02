extends "res://tests/v2_city_horizon_bench.gd"
@export var target_ids:PackedStringArray
@export var expected_partitions:int=0
@export var qualify_factory_clock:bool=false
var quit_after_family:bool=true
var view_direction:Vector3=Vector3(-1.,.12,.18).normalized()
var observations:Array[Dictionary]=[]
var transitions:Dictionary={}
var maps:Dictionary={}

func _ready()->void:call_deferred("run_family")

func _sources(owner:Node3D)->Dictionary:
    var result=_industrial_sources(owner)
    # The moving hands are an existing native asset outside the Horizon shard
    # roster. Bind its import policy too; the runtime digest excludes binaries.
    for path:String in ["res://assets/props/arcade_clock.glb","res://assets/props/arcade_clock.glb.import"]:result[path]=_profile_sha(path)
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
    for relative:String in fixture.source_bindings:
        var path="res://../"+relative
        result[path]=_profile_sha(path)
    for path:String in ["res://project.godot","res://../tools/run_receipt.py",get_script().resource_path,"res://tests/v2_city_individual_body_review.gd","res://tests/orison_v2_domestic_native_test.gd","res://scripts/building/v2_background_window_material.gd","res://shaders/v2_background_window_interior.gdshader","res://scripts/building/surface_pass.gd","res://shaders/orison_surface.gdshader","res://shaders/orison_surface.gdshaderinc","res://shaders/queens_surface_wetness.gdshaderinc","res://data/orison_v2/owner_finish_profiles.json"]:result[path]=_profile_sha(path)
    result[scene_file_path]=_profile_sha(scene_file_path)
    return result

func run_family()->void:
    RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
    check(target_ids.size() in [1,2] and (target_ids.size()==1 or target_ids[0]!=target_ids[1]) and expected_partitions>0,"explicit scene supplies one or two distinct targets and nonempty exact partition roster")
    if not failures.is_empty():get_tree().quit(1);return
    var directory=OS.get_environment("SHOT_DIR")
    check(not directory.is_empty() and DisplayServer.get_name()!="headless","graphical output directory")
    if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
    DirAccess.make_dir_recursive_absolute(directory)
    var production_inputs:=_production_inputs()
    if not failures.is_empty():get_tree().quit(1);return
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
    for asset:Dictionary in fixture.assets.values():check(FileAccess.get_sha256("res://"+str(asset.asset).trim_prefix("game/"))==str(asset.sha256),"actual export matches fixture")
    var horizon=Horizon.new();add_child(horizon)
    await get_tree().physics_frame;await get_tree().physics_frame
    var sources=_sources(horizon)
    for path:String in sources:check(not str(sources[path]).is_empty() and FileAccess.file_exists(path),"source input exists "+path)
    var metrics=preload("res://tests/orison_v2_domestic_native_test.gd").new()
    var low_counts:Dictionary={}
    for asset:Dictionary in fixture.assets.values():
        if str(asset.role)!="body_lod":continue
        var selected=false
        for identity:String in asset.buildings:
            if identity in target_ids:selected=true
        if not selected:continue
        var lower=(load("res://"+str(asset.asset).trim_prefix("game/")) as PackedScene).instantiate()
        for draw:MeshInstance3D in lower.find_children("*","MeshInstance3D",true,false):
            if str(draw.name).split("__")[0] not in target_ids:continue
            check(not low_counts.has(str(draw.name)),"unique imported lower part")
            low_counts[str(draw.name)]=draw.mesh.surface_get_array_index_len(0)/3
            metrics._check_cap_mapping(draw.mesh,true)
        lower.free()
    var draws:Array=horizon.find_children("*","MeshInstance3D",true,false)
    var bounds:Dictionary={};var selected=0
    for draw:MeshInstance3D in draws:
        var identity=str(draw.get_meta("v2_city_horizon_building",""));draw.visible=identity in target_ids
        if not draw.visible:continue
        selected+=1;metrics._check_cap_mapping(draw.mesh,true)
        check(draw.get_meta("v2_city_horizon_body_lod",false) and low_counts.has(str(draw.name)),"complete production replacement installed")
        var box=draw.global_transform*draw.get_aabb();bounds[identity]=(bounds[identity] as AABB).merge(box) if bounds.has(identity) else box
        var loaded:Material=draw.get_meta("v2_window_source_material",draw.get_meta("v2_city_roof_source",draw.material_override))
        var stock=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
        check(stock!=null and not stock.uv1_triplanar,"registered metric source material")
        var row:Dictionary={}
        if stock!=null:
            for channel:String in ["albedo","roughness","normal"]:
                var texture=stock.get(channel+"_texture") as Texture2D
                check(texture!=null,"actual PBR map exists")
                if texture==null:continue
                var pixels=texture.get_image();var required=int(floor(log(float(maxi(pixels.get_width(),pixels.get_height())))/log(2.)))
                check(pixels.has_mipmaps() and pixels.get_mipmap_count()==required,"actual complete loaded mip chain")
                row[channel]={"path":texture.resource_path,"size":[pixels.get_width(),pixels.get_height()],"mipmaps":pixels.get_mipmap_count()}
                sources[texture.resource_path]=_profile_sha(texture.resource_path);sources[texture.resource_path+".import"]=_profile_sha(texture.resource_path+".import")
            if draw.has_meta("v2_window_source_material"):
                var optical=draw.material_override as ShaderMaterial
                check(preload("res://scripts/building/v2_background_window_material.gd").glazing_is_bound(draw),"installed optical shader retains catalogue maps")
        maps[str(draw.name)]=row
    check(selected==expected_partitions and low_counts.size()==expected_partitions and bounds.size()==target_ids.size(),"exact requested near/lower body partition roster")
    check(metrics.failures.is_empty(),"strict imported near/lower metric UVs,normals,tangent derivatives")
    var mapping_failures=metrics.failures.duplicate();metrics.free()
    var space=horizon.get_world_3d().direct_space_state;var panes=0
    for window:Dictionary in fixture.window_rows:
        if str(window.building) not in target_ids:continue
        var p:Array=window.point;var n:Array=window.normal;var at=Vector3(p[0],p[2],-p[1]);var normal=Vector3(n[0],n[2],-n[1])
        var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.03,at-normal*.25,1))
        check(not hit.is_empty() and str(hit.collider.get_parent().name)==str(window.building)+"__mirror_aged" and hit.position.distance_to(at-normal*float(window.recess_m))<.0001,"actual first-hit pane")
        panes+=1
    var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.32,.38,.44);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.62,.72,.8);environment.environment.ambient_light_energy=.7;add_child(environment)
    var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.light_energy=2.8;sun.shadow_enabled=true;add_child(sun)
    var camera=Camera3D.new();camera.far=20000.;add_child(camera);camera.make_current()
    var viewport=get_viewport();var threshold=viewport.mesh_lod_threshold;var taa=viewport.use_taa;var vsync=DisplayServer.window_get_vsync_mode();var cap=Engine.max_fps
    check(viewport.get_visible_rect().size==Vector2(3440,1440),"native fullscreen3440x1440")
    viewport.use_taa=false;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    for profile:Dictionary in fixture.buildings:
        var identity=str(profile.id)
        if identity not in target_ids:continue
        for draw:MeshInstance3D in draws:draw.visible=str(draw.name).begins_with(identity+"__")
        var box:AABB=bounds[identity];var center=box.get_center();camera.fov=75.;camera.global_position=center+view_direction*box.size.length()*.5/sin(deg_to_rad(37.5))*1.25;camera.look_at(center)
        var rows:Array[Dictionary]=[]
        for spec:Dictionary in [{"id":"near","threshold":0.},{"id":"lower","threshold":10000.},{"id":"return","threshold":0.}]:
            viewport.mesh_lod_threshold=float(spec.threshold)
            var warm:Array[Dictionary]=[];var previous=Time.get_ticks_usec()
            for frame in 12:
                await RenderingServer.frame_post_draw
                var now=Time.get_ticks_usec();warm.append({"wall_ms":(now-previous)/1000.});previous=now
            var samples:Array[Dictionary]=[];previous=Time.get_ticks_usec()
            for frame in 90:
                await RenderingServer.frame_post_draw
                var now=Time.get_ticks_usec();samples.append({"wall_ms":(now-previous)/1000.,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())});previous=now
            var counters={"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
            var image=identity+"_"+str(spec.id)+".png";check(viewport.get_texture().get_image().save_png(directory.path_join(image))==OK,"actual full-body capture")
            var row={"building":identity,"case":spec.id,"counters":counters,"samples":samples,"transition_samples":warm,"image":image};rows.append(row);observations.append(row)
        check(int(rows[1].counters.triangles)<int(rows[0].counters.triangles) and rows[2].counters==rows[0].counters,"actual replacement reduction and return")
        viewport.mesh_lod_threshold=1.
        var actual_key="";var largest=0
        for draw:MeshInstance3D in draws:
            if str(draw.name).split("__")[0]!=identity:continue
            var count=draw.mesh.surface_get_array_index_len(0)
            if count<=int(low_counts[str(draw.name)])*3 or not _broad_available(draw,view_direction):continue
            if count>largest:largest=count;actual_key=str(draw.name).split("__")[-1]
        check(not actual_key.is_empty(),"natural witness selects an actually reducing broad material part")
        if not actual_key.is_empty():transitions[identity]=await _profile_natural(horizon,camera,draws,identity,actual_key,directory)
    viewport.mesh_lod_threshold=threshold;viewport.use_taa=taa;DisplayServer.window_set_vsync_mode(vsync);Engine.max_fps=cap
    var clock_review:Dictionary={}
    if qualify_factory_clock:clock_review=await _qualify_factory_clock(horizon,camera,fixture,directory)
    check(production_inputs==_production_inputs(),"production input digest remains fixed")
    for path:String in sources:check(_profile_sha(path)==sources[path],"frozen consumed source "+path)
    var retired=weakref(horizon);horizon.free();camera.free();sun.free();environment.free();await get_tree().physics_frame;check(retired.get_ref()==null,"production owner retires")
    var record={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"Explicit one-or-two isolated production horizon bodies with scene IDs/partition roster:near/lower metric UV/normal/tangent checks,loaded PBR maps with complete mips,first-hit panes,full-body forcedLOD/return and per-body natural material-part transitions. Fixed diagnostic lighting;no composed-world access,saves,wholecity performance or artistic acceptance.","execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":production_inputs,"isolated_sources_sha256":JSON.stringify(sources).sha256_text()},"source_hashes":sources,"checks":checks,"failures":failures,"settings":{"resolution":[int(viewport.get_visible_rect().size.x),int(viewport.get_visible_rect().size.y)],"msaa_3d":viewport.msaa_3d,"measured_taa":false,"measured_vsync":DisplayServer.VSYNC_DISABLED,"measured_max_fps":0,"restored_taa":taa,"restored_vsync":vsync,"restored_max_fps":cap,"fixed_diagnostic_lighting":true},"mapping_failures":mapping_failures,"pane_controls":panes,"loaded_materials":maps,"observations":observations,"natural_transitions":transitions,"contracts":{"loaded_mapping":{"executed":true,"passed":mapping_failures.is_empty()},"loaded_mipmaps":{"executed":maps.size()==expected_partitions,"passed":failures.is_empty()},"replacement_lods":{"executed":observations.size()==target_ids.size()*3,"passed":failures.is_empty()}}}
    if qualify_factory_clock:
        record["factory_clock"]=clock_review
        record.contracts["factory_clock"]={"executed":true,"passed":bool(clock_review.get("passed",false))}
        record.scope+=" Opt-in factory clock: four native hand instances, loaded maps/mips/metric repeat, physical dial first hits, transformed-owner poses, pause/resume, validated test-only disk save/load and fresh presentation reconstruction. No whole-world reload or artistic acceptance."
    var file=FileAccess.open(directory.path_join("individual_bodies.runtime.json"),FileAccess.WRITE);check(file!=null,"runtime contract writable")
    if file!=null:file.store_string(JSON.stringify(record,"\t"));file.close()
    print("INDIVIDUAL CITY BODY FAMILY ",checks," checks ",failures.size()," failures")
    if quit_after_family:get_tree().quit(0 if failures.is_empty() else 1)

func _clock_tips(model:Node3D,faces:Array,minute:float)->void:
    for face:Dictionary in faces:
        var center:=Vector3(face.center_godot[0],face.center_godot[1],face.center_godot[2])
        var right:=Vector3(face.right_godot[0],face.right_godot[1],face.right_godot[2])
        var up:=Vector3(face.up_godot[0],face.up_godot[1],face.up_godot[2])
        var normal:=Vector3(face.normal_godot[0],face.normal_godot[1],face.normal_godot[2])
        for kind:String in ["hour","minute"]:
            var hand:=model.get_node_or_null(str(face.id)+"_"+kind+"_hand") as MeshInstance3D
            check(hand!=null,"four explicit native factory hands")
            if hand==null:continue
            var angle:=TAU*fposmod(minute,720. if kind=="hour" else 60.)/(720. if kind=="hour" else 60.)
            var tip:=hand.mesh.get_aabb().end.y
            var expected:=center+normal*(.037 if kind=="minute" else .025)+(right*sin(angle)+up*cos(angle))*tip*3.6
            check((hand.global_transform*Vector3(0,tip,0)).distance_to(model.to_global(expected))<.0001,"actual transformed native tip follows shared fractional time")

func _qualify_factory_clock(horizon:Node3D,camera:Camera3D,fixture:Dictionary,directory:String)->Dictionary:
    var start_failures:=failures.size()
    var faces:Array=fixture.get("clock_faces",[])
    var movement:=horizon.get_node_or_null("FactoryClockMovement")
    check(faces.size()==2 and movement!=null,"factory clock configured from generated runtime faces")
    if faces.size()!=2 or movement==null:return {"passed":false}
    var profiles:Array=[]
    for row:Dictionary in fixture.buildings:profiles.append(str(row.id))
    check(Horizon.FactoryClock.face_failures(faces,profiles).is_empty(),"actual factory faces satisfy schema")
    var invalid:Array=faces.duplicate(true);invalid[1].id=invalid[0].id
    check(not Horizon.FactoryClock.face_failures(invalid,profiles).is_empty(),"duplicate dial identity rejected")
    invalid=faces.duplicate(true);invalid[0].right_godot=invalid[0].normal_godot
    check(not Horizon.FactoryClock.face_failures(invalid,profiles).is_empty(),"inward/nonorthogonal dial frame rejected")
    invalid=faces.duplicate(true);invalid[0].hand_scale=.42
    check(not Horizon.FactoryClock.face_failures(invalid,profiles).is_empty(),"accidental secondary shrink rejected")
    invalid=faces.duplicate(true);invalid[0].building="NOT_A_REGISTERED_BODY"
    check(not Horizon.FactoryClock.face_failures(invalid,profiles).is_empty(),"unknown clock building rejected")
    var original_transform:=horizon.transform
    # Match a nonidentity installed orientation/offset; local centers must be
    # transformed exactly once rather than interpreted as world coordinates.
    horizon.transform=Transform3D(Basis(Vector3.UP,PI),Vector3(12,4,-9))
    for draw:MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
        draw.visible=str(draw.get_meta("v2_city_horizon_building","")) in target_ids or str(draw.get_meta("city_clock_building","")) in target_ids
    await get_tree().physics_frame;await get_tree().physics_frame
    var stock:Node3D=Horizon.FactoryClock.HAND_STOCK.instantiate()
    var hand_count:=0
    for draw:MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
        if not draw.get_meta("city_clock_hand",false):continue
        hand_count+=1
        var source:=stock.find_child(str(draw.get_meta("city_clock_source_part")),true,false) as MeshInstance3D
        check(source!=null,"clock hand reuses a named native stock")
        if source!=null:
            var a:=source.mesh.surface_get_arrays(0);var b:=draw.mesh.surface_get_arrays(0)
            for channel:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:check(a[channel]==b[channel],"clock native physical arrays unchanged")
        var material:=draw.material_override as StandardMaterial3D
        check(material!=null and material.normal_enabled and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE*9.),"scaled native hands retain .4m metric material repeat")
        if material!=null:
            for texture:Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:check(texture!=null and texture.get_image().has_mipmaps(),"clock uses loaded mapped PBR mip chains")
    stock.free();check(hand_count==4,"two faces publish exactly four hands")
    for face:Dictionary in faces:
        var center:=Vector3(face.center_godot[0],face.center_godot[1],face.center_godot[2])
        var normal:=Vector3(face.normal_godot[0],face.normal_godot[1],face.normal_godot[2])
        var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(horizon.to_global(center+normal*.2),horizon.to_global(center-normal*.08),1))
        check(not hit.is_empty() and str(hit.collider.get_parent().name)==str(face.building)+"__limewash_plaster" and hit.position.distance_to(horizon.to_global(center))<.0001,"physical native dial proves generated frame and single grade datum")
    var clock:=CampaignClock.new();var captures:Array=[]
    for minute:float in [720.,195.,1110.,195.5]:
        check(clock.configure_date(1928,11,10,int(minute)),"clock fixture uses real campaign authority")
        if minute>floorf(minute):check(clock.advance_to(minute-floorf(minute)),"fractional time advances through the existing clock owner")
        var before:=var_to_bytes(RealityState.data)
        check(movement.refresh_from_campaign(),"native clock presentation refreshes")
        check(before==var_to_bytes(RealityState.data),"clock presentation writes no campaign facts")
        _clock_tips(horizon,faces,minute)
        if minute==195.5:continue
        for face:Dictionary in faces:
            var center:=Vector3(face.center_godot[0],face.center_godot[1],face.center_godot[2])
            var normal:=Vector3(face.normal_godot[0],face.normal_godot[1],face.normal_godot[2])
            camera.fov=35.;camera.global_position=horizon.to_global(center+normal*5.);camera.look_at(horizon.to_global(center))
            for frame in 8:await RenderingServer.frame_post_draw
            var name:="clock_%s_%04d.png"%[str(face.id),int(minute)]
            check(get_viewport().get_texture().get_image().save_png(directory.path_join(name))==OK,"actual dial/hand pose captured")
            captures.append({"file":name,"sha256":FileAccess.get_sha256(directory.path_join(name)),"minute":minute})
    var paused_before:=get_tree().paused;var displayed:float=movement.displayed_minute
    get_tree().paused=true
    check(clock.configure_date(1928,11,10,247),"paused test clock authority changes independently")
    await get_tree().create_timer(.35,true).timeout
    check(is_equal_approx(float(movement.displayed_minute),displayed),"paused owner does not animate hands")
    get_tree().paused=paused_before
    await get_tree().create_timer(.35).timeout
    check(is_equal_approx(float(movement.displayed_minute),247.),"resumed presentation catches up to authority")
    _clock_tips(horizon,faces,247.)
    var old_path:String=RealityState.save_path;var old_persistence:bool=RealityState.persistence_enabled
    var parent:=ProjectSettings.globalize_path("user://tests/factory_clock_runs")
    var save_dir:=parent.path_join("%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()])
    var made:=DirAccess.make_dir_recursive_absolute(parent)==OK and not DirAccess.dir_exists_absolute(save_dir) and DirAccess.make_dir_absolute(save_dir)==OK
    check(made,"new isolated save directory admitted")
    var save_sha:="";var load_status:Dictionary={}
    if made:
        RealityState.persistence_enabled=false;RealityState.save_path=save_dir.path_join("save.json")
        RealityState.persistence_enabled=true
        check(RealityState.save_game(),"existing validated save owner writes clock fixture")
        RealityState.persistence_enabled=false
        save_sha=FileAccess.get_sha256(RealityState.save_path)
        check(clock.configure_date(1928,11,10,600),"unsaved alternate time fixture")
        RealityState.load_game();load_status=RealityState.load_status()
        check(load_status.get("status")=="loaded" and is_equal_approx(clock.minute_of_day(),247.),"validated disk load restores shared time and existing reader rebinds")
        movement.free()
        for draw:MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
            if draw.get_meta("city_clock_hand",false):draw.free()
        var fresh:=Node3D.new();fresh.name="ReconstructedClock";horizon.add_child(fresh)
        var next:=Horizon.FactoryClock.new()
        check(next.configure_faces(fresh,faces,profiles),"new clock presentation reconstructs from loaded owner")
        fresh.add_child(next)
        check(fresh.find_children("*","MeshInstance3D",true,false).size()==4,"reconstruction has four hands without duplicates")
        _clock_tips(fresh,faces,247.);fresh.free()
        RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();RealityState.save_path=old_path;RealityState.persistence_enabled=old_persistence
        if failures.size()==start_failures:
            var cleaned:=true
            for suffix:String in ["",".bak",".txn",".tmp"]:
                var path:=save_dir.path_join("save.json"+suffix)
                if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:cleaned=false
            if DirAccess.get_files_at(save_dir).is_empty() and DirAccess.get_directories_at(save_dir).is_empty():cleaned=DirAccess.remove_absolute(save_dir)==OK and cleaned
            else:cleaned=false
            check(cleaned,"only successful test-owned save bundle cleaned")
    horizon.transform=original_transform
    return {"passed":failures.size()==start_failures,"images":captures,"save_fixture_directory":save_dir,"save_sha256":save_sha,"load_status":load_status,"scope":"Native arrays/PBR, actual dial contacts, transformed-frame dates/reversal, pause/resume, real validated disk load and fresh clock-only owner. Failed save artifacts preserved; no whole-world reload or artistic acceptance."}

func _profile_natural(_city: Node3D,camera: Camera3D,draws: Array,identity: String,key: String,directory: String) -> Dictionary:
    var focus: MeshInstance3D=null
    for draw: MeshInstance3D in draws:
        draw.visible=str(draw.name)==identity+"__"+key
        if draw.visible:focus=draw
    check(focus!=null,"industrial body material exists for natural LOD: "+identity)
    if focus==null:return {}
    var arrays: Array=focus.mesh.surface_get_arrays(0)
    var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var direction:=view_direction
    var bounds:=focus.get_aabb()
    var center:=focus.global_transform*bounds.get_center()
    var best:=INF
    for i in range(0,indices.size(),3):
        var a: int=indices[i];var b: int=indices[i+1];var c: int=indices[i+2]
        var area: float=(points[b]-points[a]).cross(points[c]-points[a]).length()*.5
        var normal: Vector3=(focus.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
        if area<.2 or normal.dot(direction)<.5:continue
        var local_point: Vector3=(points[a]+points[b]+points[c])/3.
        var distance_sq: float=local_point.distance_squared_to(bounds.get_center())
        if distance_sq<best:
            best=distance_sq
            center=focus.global_transform*local_point
    check(is_finite(best),"natural LOD aims at broad actual surface stock: "+identity)
    var radius:=0.
    for corner in 8:radius=maxf(radius,center.distance_to(focus.global_transform*bounds.get_endpoint(corner)))
    camera.fov=75.;get_viewport().mesh_lod_threshold=1.
    var start:=maxf(2.,radius/sin(deg_to_rad(camera.fov*.5))*1.25)
    var probes: Array[Dictionary]=[]
    var before: Dictionary={};var after: Dictionary={}
    for i in 12:
        var row:=await _profile_probe(camera,center,direction,start*pow(1.5,i))
        probes.append(row)
        check(int(row.draws)==1 and int(row.primitives)>0,"natural probe retains complete isolated body part: "+identity)
        if not before.is_empty() and int(row.primitives)<int(before.primitives):after=row;break
        before=row
    check(not after.is_empty(),"actual distance selects a replacement body LOD: "+identity)
    var images: Array[Dictionary]=[]
    var controls: Array[Dictionary]=[]
    if not after.is_empty():
        for i in 12:
            var row:=await _profile_probe(camera,center,direction,(float(before.distance_m)+float(after.distance_m))*.5)
            if int(row.primitives)==int(before.primitives):before=row
            else:after=row
        check(int(after.primitives)<int(before.primitives),"bisected natural bracket retains an actual index reduction: "+identity)
        for spec: Dictionary in [{"id":"before","distance":before.distance_m,"fov":75.,"minimum":before.primitives},{"id":"after","distance":after.distance_m,"fov":75.,"minimum":after.primitives},{"id":"narrow","distance":after.distance_m,"fov":5.,"minimum":before.primitives},{"id":"return","distance":before.distance_m,"fov":75.,"minimum":before.primitives}]:
            camera.fov=float(spec.fov)
            var row:=await _profile_probe(camera,center,direction,float(spec.distance))
            var expected:=int(row.primitives)>=int(spec.minimum) if str(spec.id)=="narrow" else int(row.primitives)==int(spec.minimum)
            check(int(row.draws)==1 and expected,"natural transition, narrow optical recovery and inward return: "+identity+"/"+str(spec.id))
            var frame:=get_viewport().get_texture().get_image()
            var pose:=camera.global_transform;var fov:=camera.fov;var optics:=_industrial_optics()
            focus.visible=false
            for tick in 4:await RenderingServer.frame_post_draw
            var negative:=get_viewport().get_texture().get_image()
            check(camera.global_transform.is_equal_approx(pose) and is_equal_approx(camera.fov,fov),"hidden-target optical control retains the same camera pose and FOV")
            check(optics==_industrial_optics(),"hidden-target optical control retains the same campaign clock and fixed bench lighting")
            var background:=negative.get_pixel(negative.get_width()/2,negative.get_height()/2)
            var corner:=negative.get_pixel(0,0)
            check(Vector3(background.r-corner.r,background.g-corner.g,background.b-corner.b).length()<.00001,"hidden-target optical control contains uniform fixed bench background")
            var control_file:=identity+"_natural_"+str(spec.id)+"_background.png"
            check(negative.save_png(directory.path_join(control_file))==OK,"same-pose hidden-target background control saved")
            controls.append({"id":spec.id,"file":control_file,"distance_m":spec.distance,"fov":fov,"background_rgb":[background.r,background.g,background.b],"optics":optics})
            focus.visible=true
            var pixel:=frame.get_pixel(frame.get_width()/2,frame.get_height()/2)
            var contrast:=Vector3(pixel.r-background.r,pixel.g-background.g,pixel.b-background.b).length()
            check(contrast>.02,"physical structural stock remains at image center: "+identity+"/"+str(spec.id))
            row["file"]=identity+"_natural_"+str(spec.id)+".png";row["fov"]=camera.fov;row["center_contrast"]=contrast
            check(frame.save_png(directory.path_join(str(row.file)))==OK,"natural industrial image saved")
            images.append(row)
    return {"part":str(focus.name),"scope":"One whole material body part, default pixel threshold1, bisected first observed distance reduction, narrow-FOV recovery and inward return. Same-pose hidden-target background controls use fixed bench lighting with no weather or campaign clock. Not a whole-building/world LOD or artistic acceptance.","before":before,"after":after,"probes":probes,"images":images,"hidden_target_controls":controls}


func _broad_available(draw:MeshInstance3D,direction:Vector3)->bool:
    var arrays:Array=draw.mesh.surface_get_arrays(0)
    var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    for i in range(0,indices.size(),3):
        var a:int=indices[i];var b:int=indices[i+1];var c:int=indices[i+2]
        var area=(points[b]-points[a]).cross(points[c]-points[a]).length()*.5
        var normal=(draw.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
        if area>=.2 and normal.dot(direction)>=.5:return true
    return false

func _production_inputs()->String:
    var root:=ProjectSettings.globalize_path("res://..").simplify_path();var output:Array=[]
    check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)==0,"bind production input digest")
    var value:=str(output[0]).strip_edges() if not output.is_empty() else ""
    check(value.length()==64,"production input digest emitted")
    return value
