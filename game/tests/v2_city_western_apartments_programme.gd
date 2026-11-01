extends RefCounted
## Actual Western apartment controller programme in the fresh discovery world.
## Derived source targets, one validated placement, unchanged production controller.
const IDS=["HORIZON_NEAR_3_2_P1","HORIZON_NEAR_3_2_P2"]
var _host:Node
var _horizon:Node3D
var player:PlayerController
var directory:String
var legs:Array[Dictionary]=[]
var endpoints:Array[Dictionary]=[]
var failures:Array[String]=[]
var checks:=0

func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures.append(message)
    _host.call("check",ok,"western apartments composed: "+message)

func _seat_part(hit:Dictionary)->String:
    if hit.is_empty():return ""
    var draw=hit.collider.get_parent() as MeshInstance3D
    return str(draw.name) if draw!=null else ""

func run(world:OrisonV2RuntimeRoot,host:Node)->Dictionary:
    _host=host
    check(world.safety_net!=null,"composed world retains its safety owner")
    if world.safety_net==null:return _record(false)
    return await run_owners(world.player,world.get_node_or_null("CityShells/CityHorizon") as Node3D,world.get_node_or_null("CityShells/ContinuousStreetBlock") as Node3D,host,world.safety_net)

func run_owners(actor:PlayerController,horizon:Node3D,streets:Node3D,host:Node,safety:Variant=null)->Dictionary:
    _host=host;player=actor;_horizon=horizon
    directory=OS.get_environment("SHOT_DIR")
    check(_horizon!=null and streets!=null and player!=null,"installed horizon,street and production player owners exist")
    if not failures.is_empty():return _record(false)
    check(not player.call_locked and not player.inspecting(),"no protected input owner is displaced")
    check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"normal standing collision/gravity/step guards retained")
    check(is_equal_approx(player._capsule.height,1.524) and is_equal_approx(player._capsule.radius,.33) and is_equal_approx(player.camera.position.y,1.41),"unchanged standing capsule and eye")
    check(_horizon.global_basis.y.is_equal_approx(Vector3.UP) and _horizon.global_basis.get_scale().is_equal_approx(Vector3.ONE),"actual owner frame is rigid and preserves vertical")
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
    var profiles:Dictionary={}
    for row:Dictionary in fixture.buildings:profiles[str(row.id)]=row
    for identity:String in IDS:check(profiles.has(identity),"source geometry profile exists "+identity)
    if not failures.is_empty():return _record(false)
    var row0:Dictionary=profiles[IDS[0]];var row2:Dictionary=profiles[IDS[1]]
    var lane_x:=float(row0.rect[0])+.5
    var lane_z:=float(row0.rect[1])+.5
    var start_local:=Vector3(149.05,float(row0.grade_datum_m),lane_z)
    var start:=_horizon.to_global(start_local)
    var floor_query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*.15,start-Vector3.UP*.15,1)
    floor_query.exclude=[player.get_rid()]
    var first:=player.get_world_3d().direct_space_state.intersect_ray(floor_query)
    check(not first.is_empty() and streets.is_ancestor_of(first.get("collider")),"initial real floor belongs to the existing public street")
    if not first.is_empty():start=first.position
    var body_query:=PhysicsShapeQueryParameters3D.new()
    body_query.shape=player._capsule;body_query.collision_mask=1;body_query.margin=0.;body_query.exclude=[player.get_rid()]
    body_query.transform=Transform3D(player.global_basis,start+Vector3.UP*.04)*player._shape.transform
    check(player.get_world_3d().direct_space_state.intersect_shape(body_query,1).is_empty(),"initial full standing capsule fits above the public floor")
    if not failures.is_empty():return _record(false)
    var old_pose:=player.global_transform;var old_camera:=player.camera.transform
    var old_physics:=player.is_physics_processing();var old_velocity:=player.velocity
    var old_mouse:=Input.mouse_mode;var old_view:=player.get_viewport().get_camera_3d()
    var recoveries_before:int=int(safety.recoveries) if safety!=null else 0
    player.set_physics_process(false);player.global_position=start+Vector3.UP*.03;player.velocity=Vector3.ZERO
    player.camera.rotation=Vector3(-.08,0,0);player.camera.make_current()
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;player.set_physics_process(true)
    for frame in 40:await player.get_tree().physics_frame
    check(player.is_on_floor() and absf(player.global_position.y-start.y)<.002,"single initial placement settles on the real public floor")
    var support:=_capsule_support(player.global_transform)
    check(bool(support.supported) and float(support.maximum_up_normal)>.99,"standing-capsule positive support control on actual street")
    var empty:=_capsule_support(Transform3D(player.global_basis,Vector3(10000,0,10000)))
    check(not bool(empty.blocked),"empty-space negative query fails without moving the player")
    var route:Array[Dictionary]=[]
    route.append({"id":"street_to_western_frontage","point":Vector3(lane_x,float(row0.grade_datum_m),lane_z),"flat":false})
    var previous_datum:=float(row0.grade_datum_m)
    for identity:String in IDS:
        var row:Dictionary=profiles[identity];var datum:=float(row.grade_datum_m)
        var opening:=_entry(row,int(row.architecture.entry_sides[0]),true);opening.z+=.15
        var lane:=Vector3(lane_x,datum,opening.z)
        route.append({"id":identity+"_lane","point":lane,"flat":is_equal_approx(datum,previous_datum)})
        route.append({"id":identity+"_landing","point":opening+Vector3(-.38,0,0),"flat":false,"end":[identity,"row_landing",opening.y,"limestone",true]})
        route.append({"id":identity+"_return","point":lane,"flat":false,"end":[identity,"row_return",datum,"concrete",false]})
        previous_datum=datum
    route.append({"id":"row_lane_end","point":Vector3(lane_x,float(row2.grade_datum_m),float(row2.rect[3])-.5),"flat":true,"end":[IDS[1],"lane_end",float(row2.grade_datum_m),"concrete",true]})
    var around_z:=float(row2.rect[3])+2.
    var rear_x:=float(row2.rect[2])+1.
    route.append({"id":"north_clearance","point":Vector3(lane_x,0,around_z),"flat":false})
    route.append({"id":"round_north_wing","point":Vector3(rear_x,0,around_z),"flat":false})
    for identity:String in [IDS[1],IDS[0]]:
        var row:Dictionary=profiles[identity];var paving:Array=row.architecture.court_paving_m[0]
        var court_z:float=(float(paving[1])+float(paving[3]))*.5
        var court_x:float=(float(paving[0])+float(paving[2]))*.5
        var datum:=float(row.grade_datum_m)
        route.append({"id":identity+"_rear_approach","point":Vector3(rear_x,0,court_z),"flat":false})
        route.append({"id":identity+"_court","point":Vector3(court_x,datum,court_z),"flat":false,"end":[identity,"rear_court",datum,"concrete",true]})
        route.append({"id":identity+"_court_return","point":Vector3(rear_x,0,court_z),"flat":false})
    route.append({"id":"rear_north_return","point":Vector3(rear_x,0,around_z),"flat":false})
    route.append({"id":"round_north_return","point":Vector3(lane_x,0,around_z),"flat":false})
    route.append({"id":"return_full_front_lane","point":Vector3(lane_x,float(row0.grade_datum_m),lane_z),"flat":false})
    check(route.size()==19,"19connected actual street,front landing,rear-court and return legs declared")
    if failures.is_empty():
        for leg:Dictionary in route:
            if not await _walk(str(leg.id),leg.point,bool(leg.flat)):break
            if leg.has("end"):
                var ending:Array=leg.end
                await _endpoint(str(ending[0]),str(ending[1]),float(ending[2]),str(ending[3]),bool(ending[4]))
            if not failures.is_empty():break
    check(legs.size()==19 and endpoints.size()==7,"all19 connected normal-input legs and7 endpoints finish")
    check(safety==null or int(safety.recoveries)==recoveries_before,"no safety-net rescue during the programme")
    check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"collision and standing guards remain enabled")
    Input.action_release("move_forward")
    # Restore only after the route ends; this is not a route rescue/continuation.
    player.set_physics_process(false);player.global_transform=old_pose;player.camera.transform=old_camera;player.velocity=old_velocity
    player.set_physics_process(old_physics);Input.mouse_mode=old_mouse
    if is_instance_valid(old_view):old_view.make_current()
    return _record(true)

func _record(attempted:bool)->Dictionary:
    return {"executed":true,"movement_attempted":attempted,"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":legs,"endpoints":endpoints,"initial_placements":1 if attempted else 0,"route_rescues":0,"scope":"One validated public-street placement in supplied production owners, then 19connected two-apartment controller legs through front landings and rear U-courts. The enclosing receipt declares isolated or composed scope. Normal input/full standing capsule/gravity/step guards; no rescue/noclip/new floor.400mm capsule queries prove geometric support,not continuous stair-floor contact. Flat/landing floor and2mm checks retained. Post-programme stance restoration excluded from route. No opening scenic doors/save/450m/performance or artistic acceptance.","test_path":get_script().resource_path,"test_sha256":FileAccess.get_sha256(get_script().resource_path)}

func _entry(row:Dictionary,side:int,residential:bool)->Vector3:
    var points:Array=row.architecture.outline_m;var p:Array=points[side];var q:Array=points[(side+1)%points.size()]
    var a=Vector3(float(p[0]),0,float(p[1]));var b=Vector3(float(q[0]),0,float(q[1]));var count=int(row.architecture.side_bays[side]);var bay=count/2
    var point=a+(b-a)*(float(bay)+.5)/float(count)
    # EasternRows.row_opening uses low=z0 for doors and passes that exact
    # height to entry_stoop. The25mm sill lift belongs to other house families.
    point.y=float(row.grade_datum_m)+float(row.architecture.floor_heights_m[0])
    return point

func _walk(label:String,target:Vector3,flat:bool)->bool:
    var source_target:=target
    target=_horizon.to_global(target)
    var origin=player.global_position;var direction=target-origin;direction.y=0;direction=direction.normalized()
    if direction.length()>.5:player.look_at(player.global_position+direction,Vector3.UP)
    var samples:Array=[];var bad_flat=0;var unsupported=0;var center_misses=0;var airborne=0;var max_gap=0.
    Input.action_press("move_forward")
    for frame in 900:
        await player.get_tree().physics_frame
        var at=player.global_position
        var query=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.05,at-Vector3.UP*.40,1);query.exclude=[player.get_rid()]
        var hit=player.get_world_3d().direct_space_state.intersect_ray(query)
        var gap=at.y-float(hit.position.y) if not hit.is_empty() else INF
        if not player.is_on_floor():airborne+=1
        if hit.is_empty():center_misses+=1
        else:max_gap=maxf(max_gap,gap)
        var support=_capsule_support(player.global_transform)
        if not bool(support.supported):unsupported+=1
        if flat and (not player.is_on_floor() or absf(at.y-target.y)>.002):bad_flat+=1
        samples.append({"position":[at.x,at.y,at.z],"on_floor":player.is_on_floor(),"noclip":player.noclip,"floor_gap_m":gap if is_finite(gap) else "no hit","capsule_support":support})
        if (target-at).dot(direction)<.025:break
    Input.action_release("move_forward")
    for frame in 12:await player.get_tree().physics_frame
    var delta=player.global_position-target;delta.y=0
    check(delta.length()<.08,"normal-input target reached "+label)
    check(not samples.is_empty() and unsupported==0,"actual upward support within400mm full-capsule sweep at every movement sample "+label)
    check(not flat or bad_flat==0,"flat leg retains actual floor and2mm height "+label)
    check(not player.noclip,"collision retained "+label)
    var reached:=delta.length()<.08 and not samples.is_empty() and unsupported==0 and (not flat or bad_flat==0)
    legs.append({"source_target":[source_target.x,source_target.y,source_target.z],"reached":reached,"id":label,"flat":flat,"target":[target.x,target.y,target.z],"samples":samples,"bad_flat_samples":bad_flat,"unsupported_samples":unsupported,"center_ray_misses":center_misses,"airborne_samples":airborne,"maximum_floor_gap_m":max_gap})

    return reached

func _endpoint(identity:String,label:String,height:float,key:String,capture:bool)->void:
    height=_horizon.to_global(Vector3(0,height,0)).y
    var at=player.global_position
    check(player.is_on_floor() and absf(at.y-height)<.002,"standing endpoint floor/height "+label)
    var query=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.08,at-Vector3.UP*.12,1);query.exclude=[player.get_rid()]
    var hit=player.get_world_3d().direct_space_state.intersect_ray(query)
    check(_seat_part(hit)==identity+"__"+key,"actual first receiving endpoint stock "+label)
    var image=""
    if capture:
        var capture_label="western_"+identity+"_"+label
        await _host.call("shot",capture_label)
        image=capture_label+".png"
        check(FileAccess.file_exists(directory.path_join(image)),"composed standing eye saved "+label)
    endpoints.append({"building":identity,"id":label,"position":[at.x,at.y,at.z],"expected_foot_m":height,"first_receiving_part":_seat_part(hit),"file":image})

func _capsule_support(from:Transform3D)->Dictionary:
    var collision=KinematicCollision3D.new()
    var blocked=player.test_move(from,Vector3.DOWN*.40,collision,.001,false,8)
    var maximum=0.;var normals:Array=[]
    for index in collision.get_collision_count():
        var normal=collision.get_normal(index);maximum=maxf(maximum,normal.y)
        normals.append([normal.x,normal.y,normal.z])
    return {"blocked":blocked,"supported":blocked and maximum>.001,"maximum_up_normal":maximum,"contact_normals":normals,"query_distance_m":.40,"safe_margin_m":.001}
