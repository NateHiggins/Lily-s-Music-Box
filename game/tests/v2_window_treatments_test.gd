extends "res://tests/orison_v2_surface_inventory.gd"
const Treatment := preload("res://scripts/building/orison_v2_window_treatment.gd")
const Review := preload("res://tests/v2_window_treatments_review.gd")
const Fitter := preload("res://scripts/building/orison_v2_window_treatments.gd")
func _run() -> void:
    RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
    var actor := Treatment.new();actor.name="Blind";actor.position.y=2.295;add_child(actor)
    actor.set_settings(0,75,1,0)
    var count: int=actor._count
    var last_y := 0.0
    for i in count:
        var t: Transform3D=actor._slats.multimesh.get_instance_transform(i)
        check(absf(t.basis.x.length()-1.41)<.001,"slat length stays fixed under tilt")
        if i>0:check(absf((last_y-t.origin.y)-actor._pitch)<.0001,"deployed ladder pitch stays fixed under tilt")
        check(absf(t.basis.get_euler().x-deg_to_rad(75))<.001,"deployed slat rotates around longitudinal axis")
        last_y=t.origin.y
    var bottom := actor._bottom.multimesh.get_instance_transform(0)
    check(absf(actor.position.y+bottom.origin.y-.012-.82)<.001,"fully lowered blind terminates at the real sill frame")
    actor.set_settings(1,-75,0,0)
    check(actor._count==count and actor._drop<.25,"fully raised blind retains all slats in compact stack")
    for i in range(1,count):
        var a: Transform3D=actor._slats.multimesh.get_instance_transform(i-1)
        var b: Transform3D=actor._slats.multimesh.get_instance_transform(i)
        check(absf(a.origin.y-b.origin.y-actor.PACKED)<.0001,"packed slats have physical thickness spacing")
    for i in count:
        check(absf(actor._slats.multimesh.get_instance_transform(i).basis.get_euler().x)<.001,"every packed slat lies flat")
    var saved := actor.settings_snapshot()
    actor.set_settings(.4,0,1,0);actor.restore_settings(saved)
    check(actor.settings_snapshot()==saved,"reconstruction restores all three independent settings")
    var owner := preload("res://scripts/building/orison_v2_household_state.gd").new()
    check(owner.validate({"schema_version":1,"records":{"test":{"kind":"blind","value":saved}}},{"test":"blind"}),"household owner admits durable blind settings")
    var bad := saved.duplicate();bad.raise=NAN
    check(not owner.validate({"schema_version":1,"records":{"test":{"kind":"blind","value":bad}}},{"test":"blind"}),"household owner rejects non-finite saved settings")
    owner.free()
    var unchanged := actor.settings_snapshot()
    var invalid := unchanged.duplicate();invalid.tilt_degrees=76
    actor.restore_settings(invalid)
    check(actor.settings_snapshot()==unchanged,"invalid reconstruction leaves all settings unchanged")
    actor.set_settings(.5,25,.8,.25)
    check(is_equal_approx(actor.settings_snapshot().raise,.5) and is_equal_approx(actor.settings_snapshot().tilt_degrees,25) and is_equal_approx(actor.settings_snapshot().curtain_open,.8),"in-flight snapshot stores destination")
    await get_tree().create_timer(.3).timeout
    check(is_equal_approx(actor.raised,.5) and is_equal_approx(actor.tilt_degrees,25),"height and tilt animation reach requested endpoints")
    await get_tree().physics_frame
    for id in ["LiftControl","TiltControl","CurtainControl"]:
        var area: Area3D=actor.get_node(id)
        var ray := PhysicsRayQueryParameters3D.create(area.global_position+Vector3.BACK*.3,area.global_position,1)
        ray.collide_with_areas=true;ray.collide_with_bodies=false
        var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
        check(not hit.is_empty() and hit.collider==area,"physical ray reaches separate "+id)
    var camera := Camera3D.new();camera.position=Vector3(.8,1.6,2.2);add_child(camera);camera.look_at(Vector3(0,1.5,0));camera.make_current()
    var fill := OmniLight3D.new();fill.position=Vector3(0,2,2);fill.light_energy=1.5;fill.omni_range=8;add_child(fill)
    var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.18,.20);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.5,.5,.5);env.environment.ambient_light_energy=.4;add_child(env)
    for pose: Array in [[0,0,1,"lowered_open_slats"],[0,75,1,"lowered_closed_slats"],[.5,30,1,"half_raised"],[1,75,1,"fully_raised"],[0,30,0,"curtains_closed"]]:
        actor.set_settings(pose[0],pose[1],pose[2],0);await shot(str(pose[3]))
    actor.set_settings(.5,20,1,0)
    for node: MultiMeshInstance3D in actor.find_children("*","MultiMeshInstance3D",true,false):
        var mesh: Mesh=node.multimesh.mesh;var mi:=str(mesh.get_instance_id());var mat: Material=node.material_override;var ma:=str(mat.get_instance_id())
        if not mesh_rows.has(mi):mesh_rows[mi]=_mesh(mesh)
        if not material_rows.has(ma):material_rows[ma]=_material(mat)
        draws.append({"path":str(node.name),"owner_script":actor.get_script().resource_path,"mesh":mi,"materials":[ma],"instances":node.multimesh.instance_count,"surface_role":"physical","visible":true})
    for mesh: Dictionary in mesh_rows.values():
        for surface: Dictionary in mesh.surfaces:
            check(not surface.missing_uv and not surface.nonfinite_uv and surface.degenerate_uv_triangles==0,"imported stock retains non-collapsed UV charts: "+str(mesh.source))
    for finish: Dictionary in material_rows.values():
        check(finish.maps.has("albedo_tex") and finish.maps.has("rough_tex") and finish.maps.has("normal_tex"),"stock has complete custom PBR triplet")
        for key: String in finish.maps:
            check(finish.mip_filters.get(key,false),"stock shader uses mipmapped sampler")
    for texture: Dictionary in texture_rows.values():
        check(texture.mips and texture.mip_levels>=int(log(maxf(texture.width,texture.height))/log(2.0)),"stock texture has full loaded mip chain")
    var dir := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(dir)
    FileAccess.open(dir.path_join("stock-review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"isolated mechanism and stock; no production composition claim","meshes":mesh_rows,"materials":material_rows,"textures":texture_rows,"failures":failures}))
    print("V2 WINDOW TREATMENTS: ","PASS" if failures.is_empty() else "FAIL","; failures=",failures.size())
    get_tree().quit(0 if failures.is_empty() else 1)
