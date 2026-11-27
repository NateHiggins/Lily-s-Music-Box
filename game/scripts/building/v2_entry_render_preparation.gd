extends RefCounted
## Bounded main-thread render preparation while the entry owner hides the world.
## No process/physics yield, gameplay transform, clock, input or save mutation.
static var _reflection_prepared := false

static var _room_captions_prepared := false
signal room_caption_shapes_ready
var _caption_viewport: SubViewport
var _caption_shapes_ready := false

## Keep the real shaped glyph surfaces resident through world composition.
## Readiness belongs to this helper, not to an unrelated companion setup path.
func stage_room_captions(owner: Node) -> void:
    if is_instance_valid(_caption_viewport) or _room_captions_prepared or DisplayServer.get_name() == "headless":
        return
    if RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_rendering_device() == null:
        return
    _caption_shapes_ready = false
    _caption_viewport = SubViewport.new()
    _caption_viewport.name = "RoomCaptionPreparation"
    _caption_viewport.size = Vector2i(256, 128)
    var local_world := World3D.new()
    local_world.environment = Environment.new()
    local_world.environment.background_mode = Environment.BG_COLOR
    local_world.environment.background_color = Color.BLACK
    _caption_viewport.world_3d = local_world
    _caption_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    _caption_viewport.gui_disable_input = true
    owner.add_child(_caption_viewport)
    var camera := Camera3D.new()
    camera.far = 6.0
    _caption_viewport.add_child(camera)
    camera.make_current()
    # The first two captions are always the same glyphs for this act.
    var positions := [Vector3(-0.35, 0.0, -2.0), Vector3(0.35, 0.0, -2.2)]
    for index in positions.size():
        var label := Intrusions.make_room_caption(index)
        label.position = positions[index]
        _caption_viewport.add_child(label)
    # Each real Label3D queued its glyph build before this barrier. A framed
    # companion can initialize synchronously, so its setup supplies no wait.
    _mark_caption_shapes_ready.call_deferred()

func _mark_caption_shapes_ready() -> void:
    _caption_shapes_ready = true
    room_caption_shapes_ready.emit()

func finish_room_captions() -> bool:
    if not is_instance_valid(_caption_viewport):
        return true # Already prepared or this renderer does not use the path.
    if not _caption_shapes_ready:
        await room_caption_shapes_ready
    if not is_instance_valid(_caption_viewport):
        return false
    var labels := 0
    for child: Node in _caption_viewport.get_children():
        if child is Label3D:
            var bounds: AABB = (child as Label3D).get_aabb()
            if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length_squared() <= 0.0:
                _caption_viewport.free()
                _caption_viewport = null
                return false
            labels += 1
    if labels != 2:
        _caption_viewport.free()
        _caption_viewport = null
        return false
    # The deferred queue shaped CPU glyph bounds, but no process/physics
    # turn has delivered their Node3D transforms to the renderer yet.
    # Flush only this private camera and glyph nodes before the one draw.
    for private_node: Node in _caption_viewport.get_children():
        if private_node is Node3D:
            (private_node as Node3D).force_update_transform()
    # The draw now sees real glyph geometry. This path yields only to the
    # deferred queue above, never to a new process/physics frame or input.
    _caption_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    _caption_viewport.free()
    _caption_viewport = null
    _room_captions_prepared = true
    return true

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE and is_instance_valid(_caption_viewport):
        _caption_viewport.free() # A refused composition never reaches finish.

## Forward+ chooses reflection pipeline variants on its first probe capture.
## Do this before the building registers its surfaces. The temporary scenario
## has no connection to a gameplay camera, light, clock or input owner.
static func prepare_room_reflections() -> void:
    if _reflection_prepared or DisplayServer.get_name() == "headless":
        return
    if RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_rendering_device() == null:
        return
    _reflection_prepared = true
    var scenario := RenderingServer.scenario_create()
    var viewport := RenderingServer.viewport_create()
    var camera := RenderingServer.camera_create()
    var probe := RenderingServer.reflection_probe_create()
    RenderingServer.reflection_probe_set_update_mode(probe, RenderingServer.REFLECTION_PROBE_UPDATE_ALWAYS)
    var instance := RenderingServer.instance_create2(probe, scenario)
    RenderingServer.camera_set_perspective(camera, 70.0, 0.05, 8.0)
    RenderingServer.camera_set_transform(camera, Transform3D(Basis.IDENTITY, Vector3(0, 0, 2)))
    RenderingServer.viewport_set_size(viewport, 16, 16)
    RenderingServer.viewport_set_scenario(viewport, scenario)
    RenderingServer.viewport_attach_camera(viewport, camera)
    RenderingServer.viewport_set_update_mode(viewport, RenderingServer.VIEWPORT_UPDATE_ALWAYS)
    RenderingServer.viewport_set_active(viewport, true)
    # Culling queues the probe on the first draw. The following draw renders
    # its six faces and finishes filtering in the temporary atlas.
    RenderingServer.force_draw(false)
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    RenderingServer.free_rid(viewport)
    RenderingServer.free_rid(instance)
    RenderingServer.free_rid(probe)
    RenderingServer.free_rid(camera)
    RenderingServer.free_rid(scenario)

static func exterior_views(frame: Transform3D, footprint: Rect2, eye_height: float, padding: float) -> Array[Transform3D]:
    var views: Array[Transform3D]=[]
    if not frame.origin.is_finite() or not frame.basis.is_finite() or frame.basis.determinant()<=.0001 \
            or not footprint.position.is_finite() or not footprint.size.is_finite() \
            or footprint.size.x<=0. or footprint.size.y<=0. \
            or not is_finite(eye_height) or not is_finite(padding) or padding<=0.:
        return views
    # One outward view beyond each existing building edge. Four turns at the
    # entrance can all remain screened by the building/canopy; these expose
    # nearby street materials without importing a diagnostic route's stations.
    var middle:=footprint.get_center()
    var edges: Array[Vector3]=[
        Vector3(middle.x,eye_height,footprint.position.y-padding),
        Vector3(footprint.end.x+padding,eye_height,middle.y),
        Vector3(middle.x,eye_height,footprint.end.y+padding),
        Vector3(footprint.position.x-padding,eye_height,middle.y)]
    var directions: Array[Vector3]=[Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]
    for index in edges.size():
        views.append(Transform3D(frame.basis.orthonormalized()*Basis.looking_at(directions[index]),frame*edges[index]))
    return views

static func building_views(frame: Transform3D, footprint: Rect2, height_range: Vector2, eye_height: float, padding: float, half_fov: float, rear_direction: Vector3) -> Array[Transform3D]:
    var views: Array[Transform3D]=[]
    if exterior_views(frame,footprint,eye_height,padding).size()!=4 \
            or not height_range.is_finite() or height_range.y<=height_range.x \
            or not is_finite(half_fov) or half_fov<=0. or half_fov>=PI*.5 \
            or not rear_direction.is_finite():return views
    var back:=Vector3(rear_direction.x,0.,rear_direction.z)
    if back.length_squared()<.0001:return views
    back=back.normalized()
    var side:=Vector3(back.z,0.,-back.x)
    var middle:=footprint.get_center()
    var target:=Vector3(middle.x,(height_range.x+height_range.y)*.5,middle.y)
    # Center the enclosing sphere on the building, then approach diagonally
    # from above. Eye-level rear cameras fell inside neighboring city stock;
    # fitting the field alone never established an exposed facade. These are
    # renderer-only views: gameplay nodes and the ten-draw budget stay intact.
    var radius:=Vector3(footprint.size.x*.5,(height_range.y-height_range.x)*.5,footprint.size.y*.5).length()
    var approach: Vector3=(back+Vector3.UP).normalized()
    var distance: float=(radius+padding)/sin(half_fov)
    var offset: float=(absf(side.x)*footprint.size.x+absf(side.z)*footprint.size.y)*.25
    var setback:=sqrt(maxf(distance*distance-offset*offset,0.))
    for sign_value: float in [-1.,1.]:
        var at: Vector3=target+approach*setback+side*offset*sign_value
        views.append(Transform3D(frame.basis.orthonormalized()*Basis.looking_at((target-at).normalized()),frame*at))
    return views

static func prepare(camera: Camera3D, views: Array[Transform3D], owns_entry: Callable) -> Dictionary:
    var result := {"executed":false,"completed":false,"cancelled":false,"render_calls":0,
        "node_pose_unchanged":true,"elapsed_ms":0.0,"reason":""}
    if not is_instance_valid(camera) or not camera.is_inside_tree() or not camera.is_current() or not owns_entry.is_valid():
        result.reason="invalid_owner";return result
    if views.is_empty() or views.size()>4:
        result.reason="invalid_view_count";return result
    for pose: Transform3D in views:
        if not pose.origin.is_finite() or not pose.basis.is_finite() or absf(pose.basis.determinant())<.0001:
            result.reason="invalid_view";return result
    if not owns_entry.call():
        result.cancelled=true;result.reason="ownership_unavailable";return result
    if not is_instance_valid(camera):
        result.reason="owner_retired";return result
    if DisplayServer.get_name()=="headless":
        result.completed=true;result.reason="headless_no_rendering";return result
    var node_pose := camera.global_transform
    var original := camera.get_camera_transform()
    var camera_rid := camera.get_camera_rid()
    var started := Time.get_ticks_usec()
    result.executed=true
    for pose: Transform3D in views:
        if not is_instance_valid(camera) or not owns_entry.is_valid() or not owns_entry.call() or not is_instance_valid(camera):
            result.cancelled=true;result.reason="ownership_changed";break
        RenderingServer.camera_set_transform(camera_rid,pose)
        for frame in 2:
            RenderingServer.force_draw(false)
            result.render_calls+=1
    # Restore even after a refused intermediate view. A retired camera has no RID
    # to restore and cannot publish an intermediate view to a replacement owner.
    if is_instance_valid(camera):
        RenderingServer.camera_set_transform(camera_rid,original)
        for frame in 2:
            RenderingServer.force_draw(false)
            result.render_calls+=1
        RenderingServer.force_sync()
        if is_instance_valid(camera):result.node_pose_unchanged=camera.global_transform==node_pose
        else:result.cancelled=true;result.reason="camera_retired"
    else:
        result.cancelled=true;result.reason="camera_retired"
    result.completed=not result.cancelled and result.node_pose_unchanged
    result.elapsed_ms=(Time.get_ticks_usec()-started)/1000.0
    return result
