extends RefCounted
## Split font/plate triangles at native page-profile knots, once per gathering.
## The opening warp then stays affine inside every rendered triangle.
const CHANNELS := [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_TANGENT]

static func fit(arrays: Array, to_book: Transform3D, cuts: PackedFloat64Array, scale: float=1.) -> Array:
	var streams: Dictionary={}
	for channel: int in CHANNELS:
		if arrays[channel]==null or arrays[channel].is_empty():continue
		var values: Array=[]
		if channel==Mesh.ARRAY_TANGENT:
			for index in range(0,arrays[channel].size(),4):values.append(Vector4(arrays[channel][index],arrays[channel][index+1],arrays[channel][index+2],arrays[channel][index+3]))
		else:values.assign(arrays[channel])
		streams[channel]=values
	var xs:=PackedFloat64Array()
	for point: Vector3 in streams[Mesh.ARRAY_VERTEX]:xs.append((to_book*Vector3(point.x*scale,point.y*scale,point.z)).x)
	var input: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if input.is_empty():for index in xs.size():input.append(index)
	var output:=PackedInt32Array()
	for index in range(0,input.size(),3):
		var polygon: Array[int]=[input[index],input[index+1],input[index+2]]
		var low:=minf(xs[polygon[0]],minf(xs[polygon[1]],xs[polygon[2]]))
		var high:=maxf(xs[polygon[0]],maxf(xs[polygon[1]],xs[polygon[2]]))
		for cut_index in range(cuts.bsearch(low+1e-8),cuts.bsearch(high-1e-8)):
			var cut:=float(cuts[cut_index]);var left: Array[int]=[];var right: Array[int]=[]
			for edge in polygon.size():
				var a:=polygon[edge];var b:=polygon[(edge+1)%polygon.size()]
				if xs[a]<=cut:left.append(a)
				if xs[a]>=cut:right.append(a)
				if (xs[a]<cut and xs[b]>cut) or (xs[a]>cut and xs[b]<cut):
					var fraction: float=(cut-xs[a])/(xs[b]-xs[a]);var added:=xs.size()
					for channel: int in streams:streams[channel].append(streams[channel][a].lerp(streams[channel][b],fraction))
					xs.append(cut);left.append(added);right.append(added)
			output.append_array(_fan(left));polygon=right
		output.append_array(_fan(polygon))
	var result:=arrays.duplicate(true)
	for channel: int in streams:
		match channel:
			Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL:result[channel]=PackedVector3Array(streams[channel])
			Mesh.ARRAY_COLOR:result[channel]=PackedColorArray(streams[channel])
			Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2:result[channel]=PackedVector2Array(streams[channel])
			Mesh.ARRAY_TANGENT:
				var tangents:=PackedFloat32Array()
				for value: Vector4 in streams[channel]:tangents.append_array(PackedFloat32Array([value.x,value.y,value.z,value.w]))
				result[channel]=tangents
	result[Mesh.ARRAY_INDEX]=output
	return result

static func stream(arrays: Array, to_book: Transform3D, cuts: PackedFloat64Array, scale: float=1.) -> Dictionary:
	var fitted:=fit(arrays,to_book,cuts,scale)
	var points: PackedVector3Array=fitted[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=fitted[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array=fitted[Mesh.ARRAY_TANGENT] if fitted[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
	var reference_points:=PackedVector3Array();var reference_normals:=PackedVector3Array();var reference_tangents:=PackedVector3Array();var sample_keys:=PackedInt32Array()
	for index in points.size():
		var local:=points[index];local.x*=scale;local.y*=scale
		var point:=to_book*local
		reference_points.append(point);sample_keys.append(roundi(point.x*100000000.))
		if normals.size()>index:reference_normals.append(to_book.basis*normals[index])
		if tangents.size()>index*4+2:reference_tangents.append(to_book.basis*Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2]))
	if scale!=1. and fitted[Mesh.ARRAY_TEX_UV]!=null:
		var uv: PackedVector2Array=fitted[Mesh.ARRAY_TEX_UV]
		for index in uv.size():uv[index]*=scale
		fitted[Mesh.ARRAY_TEX_UV]=uv
	return {"arrays":fitted,"reference_points":reference_points,"reference_normals":reference_normals,"reference_tangents":reference_tangents,"sample_keys":sample_keys,"inverse":to_book.affine_inverse()}

static func _fan(polygon: Array[int]) -> PackedInt32Array:
	var output:=PackedInt32Array()
	for index in range(1,polygon.size()-1):output.append_array(PackedInt32Array([polygon[0],polygon[index],polygon[index+1]]))
	return output
