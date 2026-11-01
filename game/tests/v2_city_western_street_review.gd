extends "res://tests/v2_grade_owner_survey.gd"
## Fresh discovery before a bounded actual-world controller programme.
var _street:Node3D
var _player:PlayerController
var _plan:Dictionary
var _district:Dictionary
var _route:Array[Dictionary]=[]
var _probes:Array[Dictionary]=[]
var _captures:Array[String]=[]
var _end_steps:Array[Dictionary]=[]
var _frames:Array[Dictionary]=[]
var _construction:Dictionary={}
var _material_bindings:Dictionary={}
var _texture_records:Dictionary={}

func _input_sha(path:String)->String:
    if path.ends_with(".glb") or path.ends_with(".png"):return FileAccess.get_sha256(path)
    return FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()

func _construction_inputs()->Dictionary:
    var result:Dictionary={}
    var repository:String=ProjectSettings.globalize_path("res://..").simplify_path()
    for relative:String in ["game/tests/orison_v2_roof_bulkhead_caps_test.gd","art/data/city_streets/source_plan.json","art/blender/scripts/build_city_streets.py","art/blender/scripts/build_orison_ground.py","art/blender/scripts/build_city_ground_apron.py","art/blender/scripts/city_ground_apron_geometry.py","game/assets/props/city_streets.glb","game/assets/props/city_streets_lod1.glb","game/assets/props/orison_ground.glb","game/assets/props/city_ground_apron.glb"]:
        result[relative]=_input_sha(repository.path_join(relative))
    return result

func _height(x:float)->float:
    var profile:Array=_plan.grade_profile_m if x>float(_plan.main_x_m[0]) else _district.walk_profile_m
    var index:int=profile.size()-2
    for i:int in profile.size()-1:
        if x<=float(profile[i+1][0]):index=i;break
    var a:Array=profile[index];var b:Array=profile[index+1]
    return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))

func _point(x:float,y:float)->Vector3:
    return _street.to_global(Vector3(x,_height(x),-y))

func _support(pose:Transform3D)->Dictionary:
    var hit:KinematicCollision3D=KinematicCollision3D.new()
    var blocked:bool=_player.test_move(pose,Vector3.DOWN*.4,hit,.001,false,8)
    var normal:float=0.
    for i:int in hit.get_collision_count():normal=maxf(normal,hit.get_normal(i).y)
    return {"supported":blocked and normal>.001,"blocked":blocked,"maximum_up_normal":normal}

func _after_discovery(world:OrisonV2RuntimeRoot)->void:
    _construction=_construction_inputs()
    _check(DisplayServer.get_name()!="headless" and get_viewport().get_visible_rect().size.is_equal_approx(Vector2(3440,1440)),"fullscreen native-resolution graphical viewport")
    var directory:String=OS.get_environment("SHOT_DIR")
    var repository:String=ProjectSettings.globalize_path("res://..").simplify_path()
    _plan=JSON.parse_string(FileAccess.get_file_as_string(repository.path_join("art/data/city_streets/source_plan.json")))
    for row:Dictionary in _plan.districts:
        if str(row.id)=="Western":_district=row
    _street=world.get_node_or_null("CityShells/ContinuousStreetBlock") as Node3D;_player=world.player
    _check(_street!=null and _player!=null and not _district.is_empty(),"installed west street, source profile and actual player exist")
    if failures>0:_write_western(world,false);return
    _check(not _player.call_locked and not _player.inspecting(),"no protected input owner displaced")
    _check(not _player.noclip and not _player.crouched and not _player._profile_disable_step_guard and not _player._profile_disable_step_up,"normal collision and both step guards")
    _check(is_equal_approx(_player._capsule.height,1.524) and is_equal_approx(_player._capsule.radius,.33) and is_equal_approx(_player.camera.position.y,1.41),"original standing capsule and eye")
    var old_pose:Transform3D=_player.global_transform;var old_camera:Transform3D=_player.camera.transform
    var old_view:Camera3D=_player.get_viewport().get_camera_3d();var old_mouse:int=Input.mouse_mode
    var old_physics:bool=_player.is_physics_processing();var old_velocity:Vector3=_player.velocity
    var old_recoveries:int=world.safety_net.recoveries
    _player.set_physics_process(false)
    var query:PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
    query.shape=_player._capsule;query.collision_mask=1;query.margin=0.;query.exclude=[_player.get_rid()]
    var blocked:int=0;var unsupported:int=0;var accounted_steps:int=0
    var stations:Array[Vector2]=[]
    # Two entire north/south footways and the avenue join, not a 450m played route.
    for x:float in [-148.8,-137.2]:
        for y:int in range(-128,129,2):stations.append(Vector2(x,float(y)))
    for x:int in range(-137,-89):stations.append(Vector2(float(x),-10.))
    for x:float in [-148.8,-137.2]:
        for y:float in [-136.,-134.,-132.,-130.,130.,132.,134.,136.]:stations.append(Vector2(x,y))
    for y:float in [-134.,-132.,-130.,-128.,128.,130.,132.,134.]:stations.append(Vector2(-142.868,y))
    for station:Vector2 in stations:
        var predicted:Vector3=_point(station.x,station.y)
        var ground_query:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(predicted+Vector3.UP*.25,predicted-Vector3.UP*.5,1,[_player.get_rid()])
        var ground_hit:Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(ground_query)
        var at:Vector3=(ground_hit.position as Vector3)+Vector3.UP*.03 if not ground_hit.is_empty() else predicted+Vector3.UP*.03
        var pose:Transform3D=Transform3D(_player.global_basis,at)
        query.transform=pose*_player._shape.transform
        var overlaps:Array[Dictionary]=_player.get_world_3d().direct_space_state.intersect_shape(query,8)
        var support:Dictionary=_support(pose)
        var step_seam:bool=absf(station.x+142.868)<.001 and absf(absf(station.y)-130.)<.001
        blocked+=int(not overlaps.is_empty());unsupported+=int(ground_hit.is_empty() or not bool(support.supported))
        accounted_steps+=int(step_seam and not overlaps.is_empty())
        var owners:Array[String]=[]
        for overlap:Dictionary in overlaps:
            var owner:Node=overlap.get("collider") as Node
            owners.append(str(owner.get_path()) if owner!=null else "non-node collider")
        _probes.append({"city_source":[station.x,station.y],"position":[at.x,at.y,at.z],"blocked":not overlaps.is_empty(),"authored_end_step":step_seam,"overlap_owners":owners,"support":support})
    _check(stations.size()==330 and blocked==2 and accounted_steps==2 and unsupported==0,"330 supported poses:328 clear static stations and two declared end-step seams requiring played crossing")
    _check(not bool(_support(Transform3D(_player.global_basis,Vector3(10000,0,10000))).blocked),"empty-space capsule negative control")
    var start:Vector3=_point(-90.5,-10.5)
    var ray:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(start+Vector3.UP*.1,start-Vector3.UP*.2,1,[_player.get_rid()])
    var floor_hit:Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(ray)
    _check(not floor_hit.is_empty() and _street.is_ancestor_of(floor_hit.get("collider")),"main initial placement is inside the existing street slab,away from its4mm joints")
    var material_parts:int=0;var maps:int=0;var lod_bodies:int=0
    var low:Node3D=(load("res://assets/props/city_streets_lod1.glb") as PackedScene).instantiate()
    var lows:Dictionary={}
    for draw:MeshInstance3D in low.find_children("*","MeshInstance3D",true,false):
        lows[str(draw.name).replace("_L1__","_L0__")]=draw
        if str(draw.name).begins_with("Street_Western"):_check_cap_mapping(draw.mesh,true,true)
    for draw:MeshInstance3D in _street.find_children("*","MeshInstance3D",true,false):
        if not str(draw.name).begins_with("Street_Western"):continue
        material_parts+=1
        _check_cap_mapping(draw.mesh,true,true)
        maps+=_loaded_maps(draw.material_override,str(draw.name),true)
        _check(lows.has(str(draw.name)),"actual complete replacement part "+str(draw.name))
        if lows.has(str(draw.name)):
            var far_draw:MeshInstance3D=lows[str(draw.name)]
            _check(draw.transform.is_equal_approx(far_draw.transform),"near/lower part registration "+str(draw.name))
            lod_bodies+=1
    low.free();_check(material_parts>0 and maps==material_parts*3 and lod_bodies==material_parts,"nonempty complete west material/LOD roster")
    var ground_owner:Node3D=world.adapter.root.get_node_or_null("Ground") as Node3D
    _check(ground_owner!=null,"actual retained/apron ground owner exists")
    var ground_meshes:int=0
    var soil_materials:Dictionary={}
    if ground_owner!=null:
        for draw:MeshInstance3D in ground_owner.find_children("*","MeshInstance3D",true,false):
            var identity:String=str(draw.name)
            if identity.begins_with("StreetCut_") or identity.begins_with("Court_soil_P34_") or identity.begins_with("GradeCut_soil_P34_") or (identity.begins_with("Horizon_") and (identity.ends_with("__soil") or identity.ends_with("__asphalt") or identity.ends_with("__concrete"))):
                _check_cap_mapping(draw.mesh,true,true);ground_meshes+=1
                if identity.contains("soil") and draw.material_override!=null and not soil_materials.has(draw.material_override.get_instance_id()):
                    soil_materials[draw.material_override.get_instance_id()]=_loaded_maps(draw.material_override,identity,false)
    _check(ground_meshes>0 and not soil_materials.is_empty(),"nonempty changed/cavity soil imported mapping and loaded-material roster")
    if failures==0:
        _player.global_position=start+Vector3.UP*.03;_player.velocity=Vector3.ZERO;_player.camera.rotation=Vector3(-.08,0,0);_player.camera.make_current()
        Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;_player.set_physics_process(true)
        for i:int in 40:await get_tree().physics_frame
        _check(_player.is_on_floor() and absf(_player.global_position.y-start.y)<.002,"initial public floor settles without rescue")
        for waypoint:Vector2 in [Vector2(-110,-10.5),Vector2(-137.2,-10.5),Vector2(-137.2,28),Vector2(-137.2,55)]:
            if not await _walk(waypoint):break
            await _capture("west_route_"+str(_route.size()),directory)
    Input.action_release("move_forward")
    _check(_route.size()==4 and world.safety_net.recoveries==old_recoveries,"four connected normal-input legs finish without safety-net rescue")
    if failures==0:
        for direction:float in [-1.,1.]:
            var city_start:Vector2=Vector2(-142.868,direction*128.)
            var predicted:Vector3=_point(city_start.x,city_start.y)
            var query_start:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(predicted+Vector3.UP*.25,predicted-Vector3.UP*.5,1,[_player.get_rid()])
            var first_hit:Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(query_start)
            _check(not first_hit.is_empty() and _street.is_ancestor_of(first_hit.get("collider")),"end-step fixture starts on the actual road")
            if first_hit.is_empty():break
            var start_pose:Transform3D=Transform3D(_player.global_basis,(first_hit.position as Vector3)+Vector3.UP*.03)
            query.transform=start_pose*_player._shape.transform
            _check(_player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"full standing capsule fits at the declared end fixture")
            if failures>0:break
            _player.set_physics_process(false);_player.global_transform=start_pose;_player.velocity=Vector3.ZERO;_player.set_physics_process(true)
            for i:int in 40:await get_tree().physics_frame
            _check(_player.is_on_floor(),"end-step initial placement settles on the road")
            var destination:Vector2=Vector2(city_start.x,direction*134.)
            var passed:bool=await _walk(destination,false,_height(city_start.x)-.02)
            _check(_player.is_on_floor() and absf(_street.to_local(_player.global_position).y-(_height(city_start.x)-.02))<.002,"end crossing settles on the actual retained soil beyond paving")
            _end_steps.append({"source_start":[city_start.x,city_start.y],"source_end":[destination.x,destination.y],"initial_placement":true,"passed":passed,"route_leg":_route.size()-1})
            await _capture("west_end_"+str(_end_steps.size()),directory)
            if failures>0:break
    _check(_route.size()==6 and _end_steps.size()==2 and world.safety_net.recoveries==old_recoveries,"four main legs plus two short normal-controller end crossings finish without rescue")
    _check(not _player.noclip and not _player.crouched and not _player._profile_disable_step_guard and not _player._profile_disable_step_up,"original standing collision and both step guards remain enabled")
    if failures==0:
        var viewport:Viewport=get_viewport();RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
        for i:int in 60:await get_tree().process_frame
        var previous:int=Time.get_ticks_usec()
        for i:int in 360:
            await get_tree().process_frame
            var now:int=Time.get_ticks_usec()
            _frames.append({"wall_ms":(now-previous)/1000.,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),"visible_draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"visible_primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})
            previous=now
    _player.set_physics_process(false);_player.global_transform=old_pose;_player.camera.transform=old_camera;_player.velocity=old_velocity
    _player.set_physics_process(old_physics);Input.mouse_mode=old_mouse
    if is_instance_valid(old_view):old_view.make_current()
    var material_after:Dictionary={}
    for path:String in _material_bindings:material_after[path]=_input_sha(path)
    _check(not _material_bindings.is_empty() and _material_bindings==material_after,"actual loaded map sources and import policies remain frozen")
    _check(_construction==_construction_inputs() and initial_inputs==_inputs() and bindings==_dependencies(),"all actually consumed runtime, test and construction inputs remain frozen")
    _write_western(world,not _route.is_empty())

func _walk(point:Vector2,strict_footway:bool=true,endpoint_height:float=NAN)->bool:
    var target:Vector3=_point(point.x,point.y)
    if is_finite(endpoint_height):target=_street.to_global(Vector3(point.x,endpoint_height,-point.y))
    var direction:Vector3=target-_player.global_position;direction.y=0
    var distance:float=direction.length();direction=direction.normalized()
    _player.look_at(_player.global_position+direction,Vector3.UP)
    var samples:Array[Dictionary]=[];var unsupported:int=0;var bad_floor:int=0
    var deadline:int=int(ceil(distance/PlayerController.WALK*Engine.physics_ticks_per_second))+120
    Input.action_press("move_forward")
    for i:int in deadline:
        await get_tree().physics_frame
        var at:Vector3=_player.global_position;var local:Vector3=_street.to_local(at)
        var support:Dictionary=_support(_player.global_transform)
        unsupported+=int(not bool(support.supported));bad_floor+=int(strict_footway and (not _player.is_on_floor() or absf(local.y-_height(local.x))>.002))
        samples.append({"world":[at.x,at.y,at.z],"on_floor":_player.is_on_floor(),"capsule_support":support})
        if (target-at).dot(direction)<.025:break
    Input.action_release("move_forward")
    for i:int in (12 if strict_footway else 60):
        await get_tree().physics_frame
        if not strict_footway and _player.is_on_floor():break
    var error:Vector3=_player.global_position-target;error.y=0.
    var passed:bool=not samples.is_empty() and error.length()<.08 and unsupported==0 and bad_floor==0
    _check(passed,"connected normal-input west leg "+str(_route.size()))
    _route.append({"city_target":[point.x,point.y],"distance_m":distance,"strict_footway_floor_each_sample":strict_footway,"deadline_frames":deadline,"samples":samples,"unsupported":unsupported,"bad_floor":bad_floor,"endpoint_horizontal_error_m":error.length(),"passed":passed})
    return passed

func _capture(label:String,directory:String)->void:
    await get_tree().process_frame;await RenderingServer.frame_post_draw
    var image:Image=get_viewport().get_texture().get_image()
    var path:String=directory.path_join(label+".png")
    _check(image!=null and image.save_png(path)==OK,"standing view captured "+label)
    _captures.append(label+".png")

func _write_western(world:OrisonV2RuntimeRoot,attempted:bool)->void:
    var record:Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"Actual composed western street:330 full standing capsule stations,three declared initial placements,four connected normal-input footway legs and two short end-step crossings,imported metric UV/basis/derivative checks,loaded PBR/mips and complete near/lower registration. Warmed fixed-view cost only. No forced/natural LOD transition qualification,save,450m uninterrupted route,wholecity performance gain or artistic acceptance.","execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":initial_inputs.get("runtime",""),"test_dependencies":bindings},"construction_inputs":_construction,"loaded_map_inputs":_material_bindings,"shared_loaded_texture_checks":_texture_records,"observed_global_surface_inputs_sha256":initial_inputs.get("surface",""),"checks":checks,"failures":failures,"movement_attempted":attempted,"route":_route,"end_step_cases":_end_steps,"declared_initial_placements":3,"capsule_stations":_probes,"captures":_captures,"warm_frames":_frames,"startup_ms":world.startup_ms,"render_settings":{"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],"scaling_3d_scale":get_viewport().scaling_3d_scale,"taa":get_viewport().use_taa,"fov":_player.camera.fov if _player!=null else 0.,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()},"contracts":{"western_street_access":{"executed":attempted,"passed":failures==0 and _route.size()==6 and _end_steps.size()==2}}}
    var file:FileAccess=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("western_street.runtime.json"),FileAccess.WRITE)
    if file==null:_check(false,"runtime contract destination exists");return
    file.store_string(JSON.stringify(record,"\t"));file.close()

# Established imported chart/basis criteria from the canonical roof-cap check.
func _check_cap_mapping(mesh: Mesh, check_derivatives: bool=false, triangle_surfaces: bool=false) -> void:
    for surface in mesh.get_surface_count():
        var arrays:=mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
        var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
        var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
        # Clipped terrain partitions may be a single real triangle. Roof-cap
        # callers retain the quad minimum unless they explicitly opt in.
        _check(vertices.size()>=(3 if triangle_surfaces else 4) and normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4,"planar surface has active UV, normal and tangent on every imported vertex")
        var valid:=true
        for i in vertices.size():
            valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
            if tangents.size()==vertices.size()*4:
                var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
                valid=valid and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
        _check(valid,"finite unit normals and orthogonal tangent handedness")
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        _check(indices.size()>=(3 if triangle_surfaces else 6) and indices.size()%3==0,"planar surface has complete native indexed triangles")
        var mapped:=true
        var widest:=0.0
        var excess:=0.0
        var derivatives:=true
        var bad_derivatives:=0
        var min_determinant:=INF
        var worst_dot:=1.0
        for triangle in range(0,indices.size(),3):
            if check_derivatives:
                var a:=indices[triangle]
                var b:=indices[triangle+1]
                var c:=indices[triangle+2]
                # Scalar doubles match the native GLB validator. Vector3/2
                # subtraction/multiplication rounds these thin faces to float32.
                var x1:float=float(vertices[b].x)-float(vertices[a].x)
                var y1:float=float(vertices[b].y)-float(vertices[a].y)
                var z1:float=float(vertices[b].z)-float(vertices[a].z)
                var x2:float=float(vertices[c].x)-float(vertices[a].x)
                var y2:float=float(vertices[c].y)-float(vertices[a].y)
                var z2:float=float(vertices[c].z)-float(vertices[a].z)
                var u1:float=float(uv[b].x)-float(uv[a].x)
                var v1:float=float(uv[b].y)-float(uv[a].y)
                var u2:float=float(uv[c].x)-float(uv[a].x)
                var v2:float=float(uv[c].y)-float(uv[a].y)
                var determinant:float=u1*v2-u2*v1
                min_determinant=minf(min_determinant,absf(determinant))
                derivatives=derivatives and absf(determinant)>1e-12
                if absf(determinant)>1e-12:
                    var expected:Vector3=Vector3((x1*v2-x2*v1)/determinant,(y1*v2-y2*v1)/determinant,(z1*v2-z2*v1)/determinant)
                    var bitangent:Vector3=Vector3((x2*u1-x1*u2)/determinant,(y2*u1-y1*u2)/determinant,(z2*u1-z1*u2)/determinant)
                    for index: int in [a,b,c]:
                        var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
                        var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
                        worst_dot=minf(worst_dot,projected.dot(actual))
                        if projected.dot(actual)<=.999 or normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]<=0:
                            bad_derivatives+=1
                            if bad_derivatives<4:print("UV DERIVATIVE DIAGNOSTIC: ",mesh.resource_name," tri=",triangle," n=",normals[index]," actual=",actual," expected=",projected," bitangent=",bitangent," determinant=",determinant)
                        derivatives=derivatives and projected.dot(actual)>.999
                        derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
            for edge in 3:
                var a:=indices[triangle+edge]
                var b:=indices[triangle+(edge+1)%3]
                var length:=vertices[a].distance_to(vertices[b])
                var texture:=uv[a].distance_to(uv[b])
                mapped=mapped and texture<=length+.00005
                excess=maxf(excess,texture-length)
                if length>.00005: widest=maxf(widest,texture/length)
        _check(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
        if check_derivatives: _check(derivatives,"tangent direction and handedness match actual imported UV derivatives")
        print("CAP MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest," vertices=",vertices.size()," derivatives=",derivatives," bad_derivatives=",bad_derivatives," min_determinant=",min_determinant," worst_dot=",worst_dot)


func _loaded_maps(loaded:Material,label:String,weather_required:bool)->int:
    var stock:StandardMaterial3D=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D if loaded!=null else null
    var shader:ShaderMaterial=loaded as ShaderMaterial
    _check(stock!=null and not stock.uv1_triplanar,"registered metric material "+label)
    if weather_required:_check(shader!=null,"installed weather surface "+label)
    if stock==null:return 0
    if weather_required:_check(stock.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"registered anisotropic mip sampler "+label)
    if shader!=null:
        _check(shader.shader.resource_path=="res://shaders/orison_surface.gdshader" and int(shader.get_shader_parameter("uv_mode"))==0,"actual opaque surface uses mesh UVs "+label)
        _check(shader.get_shader_parameter("albedo_tex")==stock.albedo_texture and shader.get_shader_parameter("rough_tex")==stock.roughness_texture and shader.get_shader_parameter("normal_tex")==stock.normal_texture,"actual shader retains registered PBR samplers "+label)
        _check(bool(shader.get_shader_parameter("has_normal_tex")) and bool(shader.get_shader_parameter("has_rough_tex")),"actual shader enables bound normal and roughness maps "+label)
        _material_bindings[shader.shader.resource_path]=_input_sha(shader.shader.resource_path)
    var maps:int=0
    for texture:Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
        _check(texture!=null,"bound PBR map "+label)
        if texture==null:continue
        var identity:int=texture.get_instance_id()
        if _texture_records.has(identity):
            _check(str(_texture_records[identity].path)==texture.resource_path,"shared loaded texture identity remains bound "+label)
            maps+=int(bool(_texture_records[identity].loaded))
            continue
        var image:Image=texture.get_image()
        _check(image!=null,"loaded PBR image exists "+texture.resource_path)
        if image==null:
            _texture_records[identity]={"path":texture.resource_path,"loaded":false}
            continue
        var expected:int=int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.)))
        _check(image.has_mipmaps() and image.get_mipmap_count()==expected,"complete loaded mip chain "+texture.resource_path)
        _texture_records[identity]={"path":texture.resource_path,"loaded":true,"width":image.get_width(),"height":image.get_height(),"mipmap_count":image.get_mipmap_count(),"required_mipmaps":expected,"complete":image.has_mipmaps() and image.get_mipmap_count()==expected}
        for path:String in [texture.resource_path,texture.resource_path+".import"]:
            _check(FileAccess.file_exists(path),"actual map source exists "+path)
            _material_bindings[path]=_input_sha(path)
        maps+=1
    return maps
