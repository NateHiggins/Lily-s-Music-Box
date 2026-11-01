extends "res://tests/v2_grade_owner_survey.gd"
## One actual world for fresh discovery and the new frontage controller route.
const Programme=preload("res://tests/v2_city_western_frontage_programme.gd")
var captures:Array[String]=[]
var context_view:Dictionary={}
func _run()->void:
    # Reject an unbound scene/dependency before source snapshots or world startup.
    var preflight:Dictionary=_dependencies()
    if failures>0 or preflight.is_empty():
        get_tree().quit(1)
        return
    await super._run()
func check(ok:bool,label:String)->void:
    _check(ok,label)
func shot(label:String)->void:
    for frame in 4:await RenderingServer.frame_post_draw
    var path:=OS.get_environment("SHOT_DIR").path_join(label+".png")
    _check(get_viewport().get_texture().get_image().save_png(path)==OK,"actual standing capture "+label)
    captures.append(label+".png")
func _after_discovery(world:OrisonV2RuntimeRoot)->void:
    var directory:=OS.get_environment("SHOT_DIR")
    _check(not directory.is_empty() and DisplayServer.get_name()!="headless","graphical output")
    _check(get_viewport().get_visible_rect().size==Vector2(3440,1440),"native fullscreen3440x1440")
    if directory.is_empty():return
    var inputs:Dictionary={}
    for path:String in [get_script().resource_path,"res://tests/v2_city_western_frontage_programme.gd","res://data/orison_v2/exterior/city_horizon.json","res://tests/fixtures/orison_city_horizon.json","res://assets/props/city_horizon_near_3_2.glb","res://assets/props/city_horizon_near_3_2_lod1.glb","res://assets/props/city_streets.glb","res://assets/props/orison_ground.glb","res://assets/props/city_ground_apron.glb"]:inputs[path]=FileAccess.get_sha256(path)
    var programme:Dictionary=await Programme.new().run(world,self)
    if bool(programme.get("passed",false)):
        await _street_context(world)
    for path:String in inputs:_check(FileAccess.get_sha256(path)==inputs[path],"frozen frontage input "+path)
    var record:Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"Actual composed Western frontage:one validated street placement,12connected normal-controller legs,7strict receiving-stock endpoints;fresh actual grade discovery. Stairs/public street join use full-capsule400mm support;constant-grade legs and endpoints retain2mm floor checks. No new scenic entry programme,save,450m continuous journey,route-wide performance or artistic acceptance.","execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":initial_inputs.runtime,"test_dependencies":bindings},"checks":checks.size(),"check_results":checks,"failures":failures,"source_inputs":inputs,"programme":programme,"startup_ms":world.startup_ms,"captures":captures,"context_view":context_view,"contracts":{"western_frontage_access":{"executed":bool(programme.get("movement_attempted",false)),"passed":failures==0 and bool(programme.get("passed",false))}}}
    var file:=FileAccess.open(directory.path_join("western_frontage_composed.runtime.json"),FileAccess.WRITE)
    _check(file!=null,"write composed frontage contract")
    if file!=null:file.store_string(JSON.stringify(record,"\t"));file.close()

func _street_context(world:OrisonV2RuntimeRoot)->void:
    # A separate optical probe at an actual street floor; no player placement
    # or walking coverage is implied by this additional production-light view.
    var horizon:=world.get_node("CityShells/CityHorizon") as Node3D
    var street:=world.get_node("CityShells/ContinuousStreetBlock") as Node3D
    var source:=Vector3(145.5,0,22.8)
    var probe:=horizon.to_global(source)
    var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*3,probe-Vector3.UP*4,1)
    query.exclude=[world.player.get_rid()]
    var hit:=world.player.get_world_3d().direct_space_state.intersect_ray(query)
    _check(not hit.is_empty() and street.is_ancestor_of(hit.get("collider")),"context probe sits above actual public street")
    if hit.is_empty() or not street.is_ancestor_of(hit.get("collider")):return
    var prior:=get_viewport().get_camera_3d()
    var camera:=Camera3D.new();add_child(camera)
    camera.global_position=hit.position+Vector3.UP*1.41
    var target:=horizon.to_global(Vector3(154,1.7,22.8))
    camera.look_at(target,Vector3.UP);camera.make_current()
    context_view={"scope":"Separate static optical probe,not player travel or an additional route placement","eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"target":[target.x,target.y,target.z],"receiving_part":str(hit.collider.get_parent().name),"file":"western_row_public_context.png"}
    await shot("western_row_public_context")
    if is_instance_valid(prior):prior.make_current()
    camera.free()
