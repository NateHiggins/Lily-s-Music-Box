extends RefCounted
## Bounded main-thread render preparation while the entry owner hides the world.
## No process/physics yield, gameplay transform, clock, input or save mutation.
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
    var target:=Vector3(middle.x,eye_height,middle.y)
    # Frame a sphere containing the entire building about a horizontal eye-
    # height target. This exposes the cold returning-player facade without
    # borrowing that diagnostic's position or moving gameplay nodes.
    var radius:=Vector3(footprint.size.x*.5,maxf(absf(height_range.x-eye_height),absf(height_range.y-eye_height)),footprint.size.y*.5).length()
    var distance: float=(radius+padding)/sin(half_fov)
    var offset: float=(absf(side.x)*footprint.size.x+absf(side.z)*footprint.size.y)*.25
    var setback:=sqrt(maxf(distance*distance-offset*offset,0.))
    for sign_value in [-1.,1.]:
        var at:=target+back*setback+side*offset*sign_value
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
