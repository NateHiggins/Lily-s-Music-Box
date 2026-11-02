extends RefCounted
## Bounded main-thread render preparation while the entry owner hides the world.
## No process/physics yield, gameplay transform, clock, input or save mutation.
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
