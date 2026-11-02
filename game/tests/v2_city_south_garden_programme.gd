extends "res://tests/v2_city_western_apartments_programme.gd"
## New source-derived local route; retain the existing controller/support helpers.
const SOUTH_IDS=["HORIZON_NEAR_3_3_P1","HORIZON_NEAR_3_3_P2"]

func run_owners(actor:PlayerController,horizon:Node3D,_streets:Node3D,host:Node,safety:Variant=null)->Dictionary:
    _host=host;player=actor;_horizon=horizon;directory=OS.get_environment("SHOT_DIR")
    check(player!=null and _horizon!=null,"actual production player and new garden owner exist")
    if not failures.is_empty():return _record(false)
    check(not player.call_locked and not player.inspecting(),"protected input ownership remains available")
    check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"standing collision/gravity/step guards retained")
    check(is_equal_approx(player._capsule.height,1.524) and is_equal_approx(player._capsule.radius,.33) and is_equal_approx(player.camera.position.y,1.41),"unchanged standing capsule and eye")
    check(_horizon.global_basis.y.is_equal_approx(Vector3.UP) and _horizon.global_basis.get_scale().is_equal_approx(Vector3.ONE),"source frame is rigid and preserves vertical")
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
    var rows:Dictionary={}
    for profile:Dictionary in fixture.buildings:rows[str(profile.id)]=profile
    for identity:String in SOUTH_IDS:check(rows.has(identity) and rows[identity].has("architecture"),"installed individual profile "+identity)
    if not failures.is_empty():return _record(false)
    var hawthorne:Dictionary=rows[SOUTH_IDS[0]];var hayes:Dictionary=rows[SOUTH_IDS[1]]
    check(str(hawthorne.architecture.style)=="hawthorne_3513" and str(hayes.architecture.style)=="hayes_3353","actual two new constructions selected")
    var hx:float=float(hawthorne.rect[0])+.5
    var hz:float=(float(hawthorne.rect[1])+float(hawthorne.rect[3]))*.5
    var yz:float=(float(hayes.rect[1])+float(hayes.rect[3]))*.5
    var hd:=float(hawthorne.grade_datum_m);var yd:=float(hayes.grade_datum_m)
    var start:=_horizon.to_global(Vector3(hx,hd,hz))
    var query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*.15,start-Vector3.UP*.15,1)
    query.exclude=[player.get_rid()]
    var floor_hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
    check(not floor_hit.is_empty() and _seat_part(floor_hit)==SOUTH_IDS[0]+"__concrete","declared initial public apron has actual receiving stock")
    if not floor_hit.is_empty():start=floor_hit.position
    var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=player._capsule;capsule.collision_mask=1;capsule.margin=0.;capsule.exclude=[player.get_rid()]
    capsule.transform=Transform3D(player.global_basis,start+Vector3.UP*.04)*player._shape.transform
    check(player.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty(),"initial full-size capsule fits without excluding blockers")
    if not failures.is_empty():return _record(false)
    var old_pose:=player.global_transform;var old_camera:=player.camera.transform
    var old_velocity:=player.velocity;var old_physics:=player.is_physics_processing()
    var old_mouse:=Input.mouse_mode;var old_view:=player.get_viewport().get_camera_3d()
    var recoveries_before:int=int(safety.recoveries) if safety!=null else 0
    player.set_physics_process(false);player.global_position=start+Vector3.UP*.03;player.velocity=Vector3.ZERO
    player.camera.rotation=Vector3(-.08,0,0);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    player.set_physics_process(true)
    for frame in 30:await player.get_tree().physics_frame
    check(player.is_on_floor() and absf(player.global_position.y-start.y)<.002,"placed apron stance settles on its measured floor")
    var empty:=_capsule_support(Transform3D(player.global_basis,player.global_position+Vector3.UP*50.))
    check(not bool(empty.blocked),"empty-space support control rejects without repositioning player")
    var entrance:=_entry(hawthorne,int(hawthorne.architecture.entry_sides[0]),true);entrance.z+=.15
    var side_z:=float(hawthorne.rect[1])+.6
    var garden:Array=hawthorne.architecture.court_paving_m[0]
    var garden_x:=float(garden[0])+.6
    var court:Array=hayes.architecture.court_paving_m[0]
    var court_x:float=(float(court[0])+float(court[2]))*.5
    var portal:Dictionary={}
    for study:Dictionary in fixture.industrial_checks:
        if str(study.building)!=SOUTH_IDS[1]:continue
        for entry:Dictionary in study.entries:
            if str(entry.kind)=="open_public_arch" and float(entry.point[0])<float(court[0]):portal=entry
    check(not portal.is_empty(),"actual source-fitted public portal exists")
    if not portal.is_empty():
        var portal_x:=float(portal.point[0]);var vault_x:float=(portal_x+float(court[0]))*.5
        var route:Array[Dictionary]=[
            {"id":"public_street_join","point":Vector3(float(hawthorne.rect[0])-.95,hd,hz),"flat":false},
            {"id":"frontage_return","point":Vector3(hx,hd,hz),"flat":false},
            {"id":"hawthorne_landing","point":entrance+Vector3(-.38,0,0),"flat":false,"end":[SOUTH_IDS[0],"short_portico",entrance.y,"limestone",true]},
            {"id":"hawthorne_return","point":Vector3(hx,hd,entrance.z),"flat":false},
            {"id":"side_garden_turn","point":Vector3(hx,hd,side_z),"flat":true},
            {"id":"side_to_garden","point":Vector3(garden_x,hd,side_z),"flat":true},
            {"id":"garden_axis","point":Vector3(garden_x,hd,hz),"flat":true,"end":[SOUTH_IDS[0],"rear_garden",hd,"concrete",true]},
            {"id":"garden_side_return","point":Vector3(garden_x,hd,side_z),"flat":true},
            {"id":"side_to_frontage","point":Vector3(hx,hd,side_z),"flat":true},
            {"id":"hayes_apron","point":Vector3(hx,yd,yz),"flat":is_equal_approx(hd,yd)},
            {"id":"vault_middle","point":Vector3(vault_x,yd,yz),"flat":true,"end":[SOUTH_IDS[1],"vault_soffit_context",yd,"concrete",true]},
            {"id":"open_court","point":Vector3(court_x,yd,yz),"flat":true,"end":[SOUTH_IDS[1],"open_garden_court",yd,"concrete",true]},
            {"id":"vault_return_apron","point":Vector3(hx,yd,yz),"flat":true,"end":[SOUTH_IDS[1],"vault_return",yd,"concrete",true]},
            {"id":"full_frontage_return","point":Vector3(hx,hd,hz),"flat":is_equal_approx(hd,yd),"end":[SOUTH_IDS[0],"initial_apron_return",hd,"concrete",false]}]
        check(route.size()==14,"bounded connected fourteen-leg local programme")
        if failures.is_empty():
            for leg:Dictionary in route:
                if not await _walk(str(leg.id),leg.point,bool(leg.flat)):break
                if leg.has("end"):
                    var ending:Array=leg.end
                    await _endpoint(str(ending[0]),str(ending[1]),float(ending[2]),str(ending[3]),bool(ending[4]))
                if not failures.is_empty():break
    check(legs.size()==14 and endpoints.size()==6,"all local street/portico/garden/vault/court legs and endpoints finish")
    check(safety==null or int(safety.recoveries)==recoveries_before,"no safety-net rescue during route")
    check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"normal collision/gravity guards remain enabled")
    Input.action_release("move_forward")
    # Restore only after the programme ends, never as a leg continuation/rescue.
    player.set_physics_process(false);player.global_transform=old_pose;player.camera.transform=old_camera;player.velocity=old_velocity
    player.set_physics_process(old_physics);Input.mouse_mode=old_mouse
    if is_instance_valid(old_view):old_view.make_current()
    return _record(true)

func _record(attempted:bool)->Dictionary:
    return {"executed":true,"movement_attempted":attempted,"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":legs,"endpoints":endpoints,"initial_placements":1 if attempted else 0,"route_rescues":0,"scope":"One validated public-apron placement,then14connected normal-controller legs through actual street join,Hawthorne portico/side garden,Hayes vaulted passage/open court and return. Enclosing receipt declares isolated/composed scope. Unmodified full standing capsule,gravity,step guards and400mm support queries;flat/endpoint2mm checks retained. Post-programme stance restoration is outside route. No scenic-leaf operation,save,450mjourney,performance or artistic acceptance.","test_path":get_script().resource_path,"test_sha256":FileAccess.get_sha256(get_script().resource_path)}
