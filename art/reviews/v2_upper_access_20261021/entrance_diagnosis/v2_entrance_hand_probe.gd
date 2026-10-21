extends "res://tests/orison_v2_golden_repair_route_test.gd"
## INERT diagnosis of actual collision refusal; no runtime acceptance.
var trials: Array[Dictionary]=[]

func _route() -> void:
    if not await _walk(Vector3(0,0,-13.15)):return
    var first: bool=await _open_front_entrance()
    _survey("original_stance",first)
    if not first:
        if not await _walk(Vector3(0,0,-13.55)):return
        var second: bool=await _open_front_entrance()
        _survey("stepped_back_through_controller",second)
    FileAccess.open(OS.get_environment("SHOT_DIR").path_join("entrance_sweep_diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Original arrival and player input; original failure is retained. Collision survey and real backward walking diagnose the refusal; no production source or geometry changes.","trials":trials},"\t"))

func _survey(label: String,reached: bool) -> void:
    var anchor: Node3D=world.adapter.resolve("F01_DOOR_06")
    var door: DoorProp=anchor.get_node("F01_DOOR_06_Leaf")
    var shape: CollisionShape3D=door._body.get_child(0)
    var angle: float=door._body.rotation.y
    var queries: Array[Dictionary]=[]
    for next: float in [angle,move_toward(angle,door.motion_target_angle(true),.025),door.motion_target_angle(true)]:
        var pose: Transform3D=door._body.transform
        pose.basis=Basis(Vector3.UP,next)
        var query:=PhysicsShapeQueryParameters3D.new()
        query.shape=shape.shape;query.transform=door.global_transform*pose*shape.transform
        query.collision_mask=door._body.collision_mask;query.exclude=[door._body.get_rid()];query.margin=.001
        var hits: Array[Dictionary]=[]
        for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,32):
            hits.append({"owner":str(hit.collider.get_path()),"class":hit.collider.get_class(),"shape":hit.shape})
        queries.append({"angle":next,"hits":hits})
    trials.append({"label":label,"reached_requested_stop":reached,"angle":angle,"player":str(world.adapter.root.to_local(player.global_position)),"queries":queries})
    print("ENTRANCE SWEEP DIAGNOSIS ",JSON.stringify(trials.back()))
