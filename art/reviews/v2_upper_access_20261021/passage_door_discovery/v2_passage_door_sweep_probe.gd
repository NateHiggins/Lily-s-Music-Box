extends "res://tests/orison_v2_vertical_route_test.gd"
## INERT discovery of original shop-door collision envelopes. No acceptance grant.
func _init() -> void:route_label="V2 PASSAGE DOOR SWEEP DISCOVERY"
func _prepare_player_start() -> void:pass

func _route() -> void:
    var region: Node3D=world.passage_region
    var hardware: DoorProp=region.doors.get("SITE_SHOP_DOOR_HARDWARE_PAINT")
    if hardware==null:failures.append("missing hardware door");return
    var center: Vector3=hardware.to_global(Vector3(hardware.width*.5,0,0))
    player.global_position=Vector3(12.4,.04,center.z)
    player.velocity=Vector3.ZERO
    for frame in 900:
        await get_tree().process_frame
        if region.residency.state=="RESIDENT":break
    if region.residency.state!="RESIDENT":failures.append("passage not resident");return
    for frame in 4:await get_tree().physics_frame
    var records: Array[Dictionary]=[]
    for identity: String in region.doors:
        var door: DoorProp=region.doors[identity]
        var shape: CollisionShape3D=door._body.get_child(0)
        var angles: Array[Dictionary]=[]
        for angle: float in [0.,.025,-.025,door.motion_target_angle(true)]:
            var pose: Transform3D=door._body.transform
            pose.basis=Basis(Vector3.UP,angle)
            var query:=PhysicsShapeQueryParameters3D.new()
            query.shape=shape.shape;query.transform=door.global_transform*pose*shape.transform
            query.collision_mask=door._body.collision_mask;query.exclude=[door._body.get_rid()];query.margin=.001
            var hits: Array[Dictionary]=[]
            for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,32):
                hits.append({"owner":str(hit.collider.get_path()),"class":hit.collider.get_class(),"shape":hit.shape})
            angles.append({"angle":angle,"hits":hits})
        records.append({"id":identity,"leaf_state":door.leaf_state,"transform":str(door.global_transform),"body_transform":str(door._body.transform),"shape_transform":str(shape.transform),"shape_bounds":str(shape.shape.size) if shape.shape is BoxShape3D else shape.shape.get_class(),"samples":angles})
        print("PASSAGE DOOR SWEEP ",JSON.stringify(records.back()))
    var directory: String=OS.get_environment("SHOT_DIR")
    DirAccess.make_dir_recursive_absolute(directory)
    FileAccess.open(directory.path_join("door_sweep_discovery.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual original resident passage actors and their current collision shapes sampled at declared angles. One diagnostic player placement; no door movement, continuous sweep, navigation, manipulation or geometry acceptance.","player":str(player.global_position),"resident_cells":region.cell_nodes.size(),"doors":records},"\t"))
    player.camera.look_at(hardware.to_global(Vector3(hardware.width*.5,1.1,0)))
