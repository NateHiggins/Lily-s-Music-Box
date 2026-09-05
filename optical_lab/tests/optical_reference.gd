extends RefCounted
## Independent CPU reference for diagnostics, not an ordinary-frame voxel builder.
static func query(field: LampOpticalVoxelField, point: Vector3) -> Dictionary:
	var local := field.pose.affine_inverse()*point
	var depth := -local.z
	var zero := {"radiance":Vector3.ZERO,"visibility":0.0,"transmittance":0.0,"depth":depth}
	if not field.enabled or depth<field.NEAR or depth>field.grid_far:return zero
	if absf(local.x)>depth*field.outer or absf(local.y)>depth*field.outer:return zero
	var relative := point-field.pose.origin
	var distance := relative.length()
	var cosine := depth/maxf(distance,0.00001)
	var angular := smoothstep(field.outer_cos,field.inner_cos,cosine)
	var visibility := 0.0
	var transmittance := 0.0
	var transport := 0.0
	for tap in 4:
		var start := field.pose.origin+field.pose.basis.x*(-0.018 if tap&1==0 else 0.018)+field.pose.basis.y*(-0.018 if tap&2==0 else 0.018)
		var ray := point-start
		var v := 1.0
		var t := 1.0
		for i in field.blockers.size():
			var box := field.blockers[i]
			var enter := 0.0
			var leave := 1.0
			for axis in 3:
				var inverse := 1.0/(ray[axis] if absf(ray[axis])>0.00000001 else 0.00000001)
				var a := (box.position[axis]-start[axis])*inverse
				var b := (box.end[axis]-start[axis])*inverse
				enter=maxf(enter,minf(a,b));leave=minf(leave,maxf(a,b))
			if leave>enter:
				v*=1.0-field.opacity[i]
				t*=exp(-field.extinction[i]*(leave-enter)*ray.length())
		visibility+=v*.25;transmittance+=t*.25;transport+=v*t*.25
	var power := angular/(1.0+distance*distance)*(1.0-smoothstep(field.range_m*.88,field.range_m,distance))
	return {"radiance":Vector3(field.color.r,field.color.g,field.color.b)*field.energy*power*transport,
		"visibility":visibility,"transmittance":transmittance,"depth":depth}

static func cell_world(field: LampOpticalVoxelField, cell: Vector3i) -> Vector3:
	var uv := (Vector3(cell)+Vector3.ONE*.5)/Vector3(field.dimensions)
	var depth := field.NEAR+(field.grid_far-field.NEAR)*uv.z*uv.z
	return field.pose*Vector3((uv.x*2-1)*depth*field.outer,(uv.y*2-1)*depth*field.outer,-depth)

## CPU reconstruction of the documented trilinear texture contract, including
## the optional near-cascade blend. Separate from production shader execution.
static func filtered(field: LampOpticalVoxelField, point: Vector3) -> Dictionary:
	var local:=field.pose.affine_inverse()*point
	var depth:=-local.z
	var zero:={"radiance":Vector3.ZERO,"visibility":0.0,"transmittance":0.0}
	if not field.enabled or depth<field.NEAR or depth>field.grid_far:return zero
	if local.length()>field.range_m or depth/maxf(local.length(),.0000001)<field.outer_cos:return zero
	var xy:=Vector2(local.x,local.y)/(depth*field.outer)*.5+Vector2.ONE*.5
	if xy.x<0 or xy.y<0 or xy.x>1 or xy.y>1:return zero
	var uv:=Vector3(xy.x,xy.y,sqrt((depth-field.NEAR)/(field.grid_far-field.NEAR)))
	var index:=uv*Vector3(field.dimensions)-Vector3.ONE*.5
	var lo:=Vector3i(index.floor())
	var fraction:=index-index.floor()
	var result:=zero.duplicate()
	for tap in 8:
		var offset:=Vector3i(tap&1,(tap>>1)&1,(tap>>2)&1)
		var cell:=(lo+offset).clamp(Vector3i.ZERO,field.dimensions-Vector3i.ONE)
		var weight:=(fraction.x if offset.x else 1.0-fraction.x)*(fraction.y if offset.y else 1.0-fraction.y)*(fraction.z if offset.z else 1.0-fraction.z)
		var corner:=query(field,cell_world(field,cell))
		result.radiance+=corner.radiance*weight
		result.visibility+=corner.visibility*weight
		result.transmittance+=corner.transmittance*weight
	if field.near_cascade!=null and depth<field.near_cascade.grid_far:
		var near:=filtered(field.near_cascade,point)
		var blend:=1.0-smoothstep(field.near_cascade.grid_far*.8,field.near_cascade.grid_far,depth)
		result.radiance=result.radiance.lerp(near.radiance,blend)
		result.visibility=lerpf(result.visibility,near.visibility,blend)
		result.transmittance=lerpf(result.transmittance,near.transmittance,blend)
	return result
