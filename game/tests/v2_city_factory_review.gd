extends RefCounted
## Opt-in factory access and composition in the canonical physical survey world.
const Optical = preload("res://tests/v2_window_city_night_review.gd")

func _dependencies() -> Dictionary:
    var result: Dictionary = {}
    for path: String in ["res://tests/v2_city_factory_review.gd","res://tests/v2_city_western_apartments_programme.gd","res://tests/v2_window_city_night_review.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_floor_surface_test.gd","res://tests/OrisonV2SurfaceInventory.tscn","res://tests/fixtures/orison_city_horizon.json"]:
        result["game/"+path.trim_prefix("res://")] = FileAccess.get_sha256(path)
    return result

func run(world: OrisonV2RuntimeRoot, host: Node) -> Dictionary:
    var root := ProjectSettings.globalize_path("res://..").simplify_path()
    var digest_output: Array = []
    host.check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest_output)==0,"factory composed production binding")
    var digest := str(digest_output[0]).strip_edges() if not digest_output.is_empty() else ""
    var dependencies := _dependencies()
    for hash: String in dependencies.values(): host.check(hash.length()==64,"factory consumed test source exists")
    host.check(digest.length()==64 and host.scene_file_path=="res://tests/OrisonV2SurfaceInventory.tscn","factory uses canonical entry and runtime digest")
    var programme: Dictionary = await FactoryProgramme.new().run(world,host)
    var optical := Optical.new()
    optical.externally_managed = true
    host.add_child(optical)
    var observations: Dictionary = await optical.run_composed(world,host)
    optical.free()
    var after: Array = []
    host.check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],after)==0 and not after.is_empty() and str(after[0]).strip_edges()==digest,"factory composed source remained fixed")
    host.check(dependencies==_dependencies(),"factory consumed test dependencies remained fixed")
    var passed := bool(programme.get("passed",false)) and bool(observations.get("completed",false)) and observations.get("failures",["missing"]).is_empty()
    var record := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
        "scope":"Single externally composed canonical physical-survey world. One validated nearby apron placement, eight connected normal-controller factory apron/open-end/lateral-gap/court/return legs. Three separately posed roof lighting comparisons are diagnostic observations, not performance or artistic acceptance. No second world, scenic door interaction or whole-world save/reload.",
        "execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
        "source":{"test_path":"game/tests/v2_city_factory_review.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"scene_path":host.scene_file_path,"test_dependencies":dependencies,"runtime_inputs_sha256":digest},
        "programme":programme,"optical_report":"night_review.json",
        "contracts":{"factory_access":{"executed":bool(programme.get("movement_attempted",false)),"passed":bool(programme.get("passed",false))}}}
    var file := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("factory_access.runtime.json"),FileAccess.WRITE)
    host.check(file!=null,"factory access receipt opened")
    if file!=null:
        file.store_string(JSON.stringify(record,"\t"));host.check(file.get_error()==OK,"factory access receipt written");file.close()
    return record

class FactoryProgramme extends "res://tests/v2_city_western_apartments_programme.gd":
    const FACTORY := "HORIZON_NEAR_3_0_P1"

    func check(ok: bool, message: String) -> void:
        checks += 1
        if not ok: failures.append(message)
        _host.call("check",ok,"factory composed: "+message)

    func _record(attempted: bool) -> Dictionary:
        return {"executed":true,"movement_attempted":attempted,"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":legs,"endpoints":endpoints,"initial_placements":1 if attempted else 0,"route_rescues":0,
            "scope":"Eight connected normal-input legs from a single validated nearby public-apron fixture. Standing 1.524m/.33m capsule, original gravity/step guards and real floor; no noclip, added floor or rescue. Per-sample 400mm capsule queries establish geometric support, not continuous floor contact. Restore original stance only after route ends. No continuous journey from the Orison or scenic door access."}

    func run_owners(actor: PlayerController, horizon: Node3D, streets: Node3D, host: Node, safety: Variant = null) -> Dictionary:
        _host=host;player=actor;_horizon=horizon;directory=OS.get_environment("SHOT_DIR")
        check(player!=null and horizon!=null and streets!=null and safety!=null,"actual production player, streets, horizon and safety owners")
        if not failures.is_empty():return _record(false)
        check(not player.call_locked and not player.inspecting(),"protected input ownership available")
        check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"standing collision and step guards retained")
        check(is_equal_approx(player._capsule.height,1.524) and is_equal_approx(player._capsule.radius,.33) and is_equal_approx(player.camera.position.y,1.41),"production capsule and eye unchanged")
        check(horizon.global_basis.y.is_equal_approx(Vector3.UP) and horizon.global_basis.get_scale().is_equal_approx(Vector3.ONE),"installed source frame is rigid and vertical")
        var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
        var row: Dictionary={}
        for profile: Dictionary in fixture.buildings:
            if str(profile.id)==FACTORY:row=profile
        check(not row.is_empty(),"generated factory geometry profile exists")
        if not failures.is_empty():return _record(false)
        var datum:=float(row.grade_datum_m)
        var apron: Array=row.architecture.front_apron_rect_m
        var court: Array=row.architecture.court_paving_m[0]
        var apron_x: float=(float(apron[0])+float(apron[2]))*.5
        var end_z:=float(row.rect[3])+.6
        var outer_x:=float(row.rect[2])-.4
        var court_z: float=(float(court[1])+float(court[3]))*.5
        var court_x: float=(float(court[0])+float(court[2]))*.5
        var start:=horizon.to_global(Vector3(apron_x,datum,float(row.rect[1])+.6))
        var query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*.15,start-Vector3.UP*.15,1)
        query.exclude=[player.get_rid()]
        var floor_hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
        check(not floor_hit.is_empty() and absf(floor_hit.position.y-start.y)<.002,"initial apron fixture has real floor at declared grade")
        var body_query:=PhysicsShapeQueryParameters3D.new()
        body_query.shape=player._capsule;body_query.collision_mask=1;body_query.margin=0.;body_query.exclude=[player.get_rid()]
        body_query.transform=Transform3D(player.global_basis,start+Vector3.UP*.04)*player._shape.transform
        check(player.get_world_3d().direct_space_state.intersect_shape(body_query,1).is_empty(),"complete standing capsule fits initial fixture")
        if not failures.is_empty():return _record(false)
        var old_pose:=player.global_transform;var old_camera:=player.camera.transform
        var physics:=player.is_physics_processing();var velocity:=player.velocity
        var mouse:=Input.mouse_mode;var prior_camera:=host.get_viewport().get_camera_3d()
        var recoveries:=int(safety.recoveries)
        player.set_physics_process(false);player.global_position=start+Vector3.UP*.03;player.velocity=Vector3.ZERO
        player.camera.rotation=Vector3(-.08,0,0);player.camera.make_current()
        Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;player.set_physics_process(true)
        for tick in 40:await player.get_tree().physics_frame
        check(player.is_on_floor() and absf(player.global_position.y-start.y)<.002,"single placement settles on actual public apron")
        var points: Array[Dictionary]=[
            {"id":"public_apron","point":Vector3(apron_x,datum,float(row.rect[3])-.6),"flat":true},
            {"id":"open_end","point":Vector3(apron_x,0,end_z),"flat":false},
            {"id":"around_open_end","point":Vector3(outer_x,0,end_z),"flat":false},
            {"id":"lateral_gap","point":Vector3(outer_x,0,court_z),"flat":false},
            {"id":"delivery_court","point":Vector3(court_x,datum,court_z),"flat":false},
            {"id":"court_return","point":Vector3(outer_x,0,court_z),"flat":false},
            {"id":"gap_return","point":Vector3(outer_x,0,end_z),"flat":false},
            {"id":"apron_return","point":Vector3(apron_x,0,end_z),"flat":false}]
        if failures.is_empty():
            for leg: Dictionary in points:
                if not await _walk(str(leg.id),leg.point,bool(leg.flat)):break
                if str(leg.id)=="delivery_court":await _endpoint(FACTORY,"delivery_court",datum,"concrete",true)
                if not failures.is_empty():break
        check(legs.size()==8 and endpoints.size()==1,"all eight connected legs and court endpoint completed")
        check(int(safety.recoveries)==recoveries,"no safety rescue during route")
        check(not player.noclip and not player.crouched and not player._profile_disable_step_guard and not player._profile_disable_step_up,"production standing guards still enabled")
        Input.action_release("move_forward")
        player.set_physics_process(false);player.global_transform=old_pose;player.camera.transform=old_camera;player.velocity=velocity
        player.set_physics_process(physics);Input.mouse_mode=mouse
        if is_instance_valid(prior_camera):prior_camera.make_current()
        return _record(true)
