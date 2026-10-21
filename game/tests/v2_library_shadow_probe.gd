extends Node3D
## INERT optical diagnosis. Isolated copies and camera fixtures grant no world acceptance.
const Shelf := preload("res://scripts/building/v2_readable_bookshelf.gd")
var directory: String

func _ready() -> void:
    _run.call_deferred()

func _shot(label: String) -> Image:
    for frame in 6: await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var image: Image=get_viewport().get_texture().get_image()
    image.save_png(directory.path_join(label+".png"))
    return image

func _difference(a: Image,b: Image) -> Dictionary:
    var changed:=0
    var sampled:=0
    var peak:=0.0
    for y in range(0,a.get_height(),4):
        for x in range(0,a.get_width(),4):
            var ca: Color=a.get_pixel(x,y)
            var cb: Color=b.get_pixel(x,y)
            var difference: float=maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
            sampled+=1
            if difference>.1: changed+=1
            peak=maxf(peak,difference)
    return {"sampled_pixels":sampled,"changed_over_point_one":changed,"peak_channel_difference":peak}

func _run() -> void:
    RealityState.persistence_enabled=false
    directory=OS.get_environment("SHOT_DIR")
    if directory.is_empty(): get_tree().quit(2);return
    DirAccess.make_dir_recursive_absolute(directory)
    var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
    if not stock.prepare(): push_error("Shadow probe could not load original native stock");get_tree().quit(1);return
    var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color(.06,.07,.085)
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color(.44,.48,.55)
    environment.ambient_light_energy=.35
    var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
    var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name="Mina Vale";shelf.unit="2A";shelf.case_style="repaired";add_child(shelf)
    var poses: Dictionary={}
    var shadow_modes: Dictionary={}
    for item: RigidBody3D in shelf._books.values()+shelf._ends.values():
        item.freeze=true
        poses[str(item.name)]=item.transform
        for draw: GeometryInstance3D in item.find_children("*","GeometryInstance3D",true,false):
            shadow_modes[draw]=draw.cast_shadow
    var player:=PlayerController.new();player.position=Vector3(0,.02,1.6);add_child(player)
    player.set_physics_process(false);player.set_lamp_enabled(true)
    var center:=Vector3(.003,.61,.0075)
    player.camera.global_position=center+Vector3(0,.25,1.6)
    player.camera.look_at(center);player.camera.make_current()
    var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
    if not air.setup(player,environment): push_error("Shadow probe could not initialize production carried light");get_tree().quit(1);return
    await get_tree().create_timer(.5).timeout
    var baseline: Image=await _shot("native_book_shadows")
    for draw: GeometryInstance3D in shadow_modes:draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var without: Image=await _shot("diagnostic_book_casting_off")
    for draw: GeometryInstance3D in shadow_modes:draw.cast_shadow=shadow_modes[draw]
    var restored: Image=await _shot("native_book_shadows_restored")
    var same_poses:=true
    for item: RigidBody3D in shelf._books.values()+shelf._ends.values():
        same_poses=same_poses and item.transform==poses[str(item.name)]
    var report: Dictionary={"evidence_class":"INERT","scope":"Isolated original Mina library, fixed poses and production carried light. Shadow casting disabled only for a diagnostic comparison; no production change, manipulation proof or world acceptance.","book_ids":shelf._books.keys(),"fixed_stock_poses":same_poses,"caster_count":shadow_modes.size(),"baseline_vs_casting_off":_difference(baseline,without),"baseline_vs_restored":_difference(baseline,restored)}
    FileAccess.open(directory.path_join("shadow_diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
    print("V2 LIBRARY SHADOW PROBE: INERT completed; fixed_stock_poses=",same_poses)
    get_tree().quit(0 if same_poses else 1)
