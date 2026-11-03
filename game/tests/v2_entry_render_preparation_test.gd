extends Node3D
## Small graphical lifecycle bench; no composed world or gameplay qualification.
const Preparation = preload("res://scripts/building/v2_entry_render_preparation.gd")
var failures: Array[String]=[]
var checks:=0
var colors: Array[Color]=[]
var guard_calls:=0
var camera: Camera3D
func check(ok: bool, message: String) -> void:
    checks+=1
    if not ok:failures.append(message);push_error(message)
func _ready() -> void:
    call_deferred("run")
func _sample() -> void:
    var pixels:=get_viewport().get_texture().get_image()
    colors.append(pixels.get_pixel(pixels.get_width()/2,pixels.get_height()/2))
func _cancel_after_first() -> bool:
    guard_calls+=1
    return guard_calls<3
func run() -> void:
    RealityState.persistence_enabled=false
    check(DisplayServer.get_name()!="headless","real frames required")
    if not failures.is_empty():get_tree().quit(1);return
    for side in [-1.,1.]:
        var draw:=MeshInstance3D.new();draw.mesh=BoxMesh.new();draw.mesh.size=Vector3(4,4,.2)
        draw.position.z=side*4
        var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        finish.albedo_color=Color.BLUE if side<0 else Color.RED
        draw.material_override=finish;add_child(draw)
    camera=Camera3D.new();add_child(camera);camera.make_current()
    await RenderingServer.frame_post_draw
    await get_tree().process_frame
    var pose:=camera.get_camera_transform();var node_pose:=camera.global_transform
    var footprint:=Rect2(-8.,-5.,16.,10.)
    var frame:=Transform3D(Basis(Vector3.UP,PI/2.),node_pose.origin+Vector3.ONE)
    var outside:=Preparation.exterior_views(frame,footprint,camera.position.y+1.,camera.near)
    check(outside.size()==4,"four footprint views keep the existing draw budget")
    for view: Transform3D in outside:
        var local:=frame.affine_inverse()*view.origin
        var ray:=frame.basis.inverse()*(-view.basis.z)
        check(not footprint.has_point(Vector2(local.x,local.z)) and ray.dot(Vector3(footprint.get_center().x,local.y,footprint.get_center().y)-local)<0.,"transformed view lies beyond the footprint and looks away from it")
    check(Preparation.exterior_views(frame,Rect2(),1.,.1).is_empty(),"empty footprint cannot publish renderer views")
    var half_fov:=PI/6.
    var building:=Preparation.building_views(frame,footprint,Vector2(0.,3.),1.,.1,half_fov,Vector3.BACK)
    check(building.size()==2,"two framed building views replace the screened side views")
    for view: Transform3D in building:
        for x: float in [footprint.position.x,footprint.end.x]:
            for y: float in [0.,3.]:
                for z: float in [footprint.position.y,footprint.end.y]:
                    var projected: Vector3=view.affine_inverse()*(frame*Vector3(x,y,z))
                    check(-projected.z>0. and absf(projected.x)<-projected.z*tan(half_fov) and absf(projected.y)<-projected.z*tan(half_fov),"all transformed building corners fit within the narrower field of view")
    check(Preparation.building_views(frame,footprint,Vector2(0.,3.),1.,.1,0.,Vector3.BACK).is_empty(),"invalid framing field cannot publish a view")
    check(camera.global_transform==node_pose,"footprint policy leaves the scene camera untouched")
    var views: Array[Transform3D]=[Transform3D(Basis(Vector3.UP,PI),pose.origin),pose]
    var declined:=Preparation.prepare(camera,views,func():return false)
    check(not declined.executed and declined.cancelled,"refused owner draws nothing")
    var invalid: Array[Transform3D]=[Transform3D(Basis.IDENTITY,Vector3.INF)]
    check(not Preparation.prepare(camera,invalid,func():return true).executed,"nonfinite view rejected")
    RenderingServer.frame_post_draw.connect(_sample)
    var process_before:=Engine.get_process_frames();var physics_before:=Engine.get_physics_frames()
    var actual:=Preparation.prepare(camera,views,func():return true)
    check(actual.completed and actual.render_calls==6,"bounded views and restoration executed")
    check(Engine.get_process_frames()==process_before and Engine.get_physics_frames()==physics_before,"preparation never advances simulation frames")
    check(camera.global_transform==node_pose and actual.node_pose_unchanged,"scene camera pose unchanged")
    check(colors.any(func(c: Color):return c.r>.7 and c.b<.2),"temporary view actually renders red target")
    check(colors.any(func(c: Color):return c.b>.7 and c.r<.2),"restored view actually renders blue target")
    check(not colors.is_empty() and colors[-1].b>.7 and colors[-1].r<.2,"final renderer pose restored optically")
    colors.clear();guard_calls=0
    var cancelled:=Preparation.prepare(camera,views,Callable(self,"_cancel_after_first"))
    check(cancelled.cancelled and not cancelled.completed and cancelled.render_calls==4,"ownership loss cancels remaining view and restores")
    check(not colors.is_empty() and colors[-1].b>.7 and camera.global_transform==node_pose,"cancelled preparation restores actual original view")
    RenderingServer.frame_post_draw.disconnect(_sample)
    var directory:=OS.get_environment("SHOT_DIR")
    var ready:=not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK
    check(ready,"capture directory created")
    if ready:
        check(get_viewport().get_texture().get_image().save_png(directory.path_join("restored_view.png"))==OK,"actual restored frame saved")
        var output:=FileAccess.open(directory.path_join("entry_preparation.json"),FileAccess.WRITE)
        check(output!=null,"diagnostic report opened")
        if output!=null:
            output.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Small rendered lifecycle bench; no composed entry, performance or gameplay acceptance","checks":checks,"failures":failures,"completed":actual,"cancelled":cancelled}))
            if output.get_error()!=OK:check(false,"diagnostic report written")
            output.close()
    print("ENTRY RENDER PREPARATION: ",checks," checks ",failures.size()," failures")
    get_tree().quit(0 if failures.is_empty() else 1)
