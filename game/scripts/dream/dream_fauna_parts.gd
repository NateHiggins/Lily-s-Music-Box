class_name DreamFaunaParts
extends RefCounted
## FA-V1: cached, deterministic, one-surface organic part kit.
##
## Every builder emits the ruled COLOR/CUSTOM0 contract. Logical region ids
## 0..7 are stored as id/7 in COLOR.r because Godot's GPU color stream is
## UNORM; the shader reconstructs the integer id. No UV, texture, skeleton,
## import surface or per-part material enters this path.

const REGION_SHELL := 0
const REGION_WINE := 1
const REGION_GOLD := 2
const REGION_JEWEL := 3
const REGION_SCLERA := 4
const REGION_IRIS := 5
const REGION_LID := 6
const REGION_MEMBRANE := 7
const TRIANGLE_CEILING := 4000

static var _cache: Dictionary = {}

static func buttons() -> ArrayMesh:
	if _cache.has("buttons"): return _cache.buttons
	var tool:=_tool(true)
	var profile:=PackedVector2Array([
		Vector2(0.02,0.0),Vector2(0.15,0.10),Vector2(0.18,0.34),
		Vector2(0.13,0.58),Vector2(0.035,0.72)])
	for record in [[Vector3(-0.16,0.0,0.03),0.92],
			[Vector3(0.14,0.0,0.08),1.03],[Vector3(0.0,0.0,-0.14),0.78]]:
		var offset:Vector3=record[0]; var scale:float=record[1]
		var scaled:=PackedVector2Array()
		for p in profile: scaled.append(p*scale)
		_append_lathe(tool,scaled,10,REGION_WINE,offset,0.0)
		_append_gem(tool,offset+Vector3(0.0,0.73*scale,0.0),0.055*scale,
				REGION_GOLD,0.0,2.0)
	var mesh:=tool.commit() as ArrayMesh; _cache.buttons=mesh; return mesh

static func tessellates() -> ArrayMesh:
	if _cache.has("tessellates"):
		return _cache.tessellates
	var tool := _tool(true)
	# A faceted, low dome keeps the approved cute tier: broad circular body,
	# four short symmetric feet, two anatomical eyes and one gilt mosaic plate.
	_append_mosaic_ellipsoid(tool, Vector3(0.0, 0.17, 0.0),
			Vector3(0.19, 0.15, 0.23), 5, 10, REGION_WINE, 0.28, 0.0)
	for x in [-0.115, 0.115]:
		for z in [-0.105, 0.105]:
			_append_box(tool, Vector3(x, 0.035, z), Vector3(0.065, 0.12, 0.065),
					REGION_SHELL, 0.82, 0.0)
	_append_ellipsoid(tool, Vector3(0.0, 0.19, -0.205),
			Vector3(0.145, 0.105, 0.075), 4, 9, REGION_LID, 0.16, 1.0)
	for x in [-0.058, 0.058]:
		_append_gem(tool, Vector3(x, 0.205, -0.271), 0.038,
				REGION_IRIS, 0.08, 1.0)
	_append_gem(tool, Vector3(0.0, 0.315, -0.01), 0.065,
			REGION_GOLD, 0.0, 2.0)
	var mesh := tool.commit() as ArrayMesh
	_cache.tessellates = mesh
	return mesh

static func anemones() -> ArrayMesh:
	if _cache.has("anemones"): return _cache.anemones
	var tool:=_tool(true)
	_append_ellipsoid(tool,Vector3(0.0,0.035,0.0),Vector3(0.13,0.05,0.13),
			3,10,REGION_SHELL,0.0,0.0)
	for arm in 7:
		var angle:=TAU*float(arm)/7.0
		var side:=Vector3(cos(angle),0.0,sin(angle))
		var tangent:=Vector3(-sin(angle),0.0,cos(angle))
		var points:=PackedVector3Array([
			Vector3.ZERO+side*0.035,
			side*0.075+Vector3.UP*0.10,
			side*0.12+tangent*(0.035 if arm%2==0 else -0.035)+Vector3.UP*0.21,
			side*0.07+tangent*(0.09 if arm%2==0 else -0.09)+Vector3.UP*0.31])
		var radii:=PackedFloat32Array([0.030,0.026,0.018,0.008])
		_append_sweep(tool,points,radii,7,REGION_WINE)
		_append_gem(tool,points[3],0.018,REGION_JEWEL,0.72,3.0)
	var mesh:=tool.commit() as ArrayMesh; _cache.anemones=mesh; return mesh

static func ribbonettes() -> ArrayMesh:
	if _cache.has("ribbonettes"): return _cache.ribbonettes
	var tool:=_tool(true)
	for strand in 2:
		var points:=PackedVector3Array(); var phase:=float(strand)*PI
		for i in 13:
			var t:=float(i)/12.0
			points.append(Vector3((t-0.5)*0.64,
					sin(t*TAU*1.25+phase)*0.075,
					cos(t*TAU*1.25+phase)*0.055))
		_append_ribbon(tool,points,0.045,REGION_WINE,float(strand))
		_append_ribbon(tool,points,0.008,REGION_GOLD,2.0+float(strand))
	# One half-lidded anatomical eye per paired organism, not decorative skin.
	for x in [-0.28,0.28]:
		_append_gem(tool,Vector3(x,0.018,-0.065),0.025,REGION_IRIS,0.12,5.0)
	var mesh:=tool.commit() as ArrayMesh; _cache.ribbonettes=mesh; return mesh

static func loupe() -> ArrayMesh:
	if _cache.has("loupe"): return _cache.loupe
	var tool:=_tool(true)
	_append_ellipsoid(tool,Vector3(0.0,0.31,0.02),Vector3(0.22,0.20,0.34),
			6,12,REGION_WINE,0.18,0.0)
	for x in [-0.15,0.15]:
		for z in [-0.10,0.16]:
			_append_box(tool,Vector3(x,0.12,z),Vector3(0.065,0.28,0.065),
					REGION_SHELL,0.78,0.0)
	_append_ellipsoid(tool,Vector3(0.0,0.36,0.365),Vector3(0.19,0.135,0.035),
			5,14,REGION_SCLERA,0.04,4.0)
	_append_ellipsoid(tool,Vector3(0.0,0.36,0.403),Vector3(0.082,0.082,0.018),
			4,12,REGION_IRIS,0.08,5.0)
	_append_gem(tool,Vector3(0.0,0.36,0.422),0.035,REGION_LID,0.0,6.0)
	var eye_loop:=PackedVector3Array()
	for i in 20:
		var a:=TAU*float(i)/19.0
		eye_loop.append(Vector3(cos(a)*0.205,0.36+sin(a)*0.15,0.395))
	var eye_radii:=PackedFloat32Array()
	for _i in eye_loop.size(): eye_radii.append(0.012)
	_append_sweep(tool,eye_loop,eye_radii,6,REGION_GOLD)
	# Three upper lashes make the eye anatomical without borrowing hazard rings.
	for lash in [-1,0,1]:
		var x:=float(lash)*0.075
		_append_sweep(tool,PackedVector3Array([
			Vector3(x,0.47,0.40),Vector3(x*1.18,0.53,0.43)]),
			PackedFloat32Array([0.008,0.003]),5,REGION_GOLD)
	var mesh:=tool.commit() as ArrayMesh; _cache.loupe=mesh; return mesh

static func lathe(profile: PackedVector2Array, radial_segments := 12,
		region := REGION_WINE) -> ArrayMesh:
	var tool := _tool()
	_append_lathe(tool, profile, radial_segments, region, Vector3.ZERO, 0.0)
	return tool.commit()

static func sweep(points: PackedVector3Array, radii: PackedFloat32Array,
		sides := 8, region := REGION_WINE) -> ArrayMesh:
	var tool := _tool()
	_append_sweep(tool, points, radii, sides, region)
	return tool.commit()

static func ribbon(points: PackedVector3Array, half_width := 0.05,
		region := REGION_MEMBRANE) -> ArrayMesh:
	var tool := _tool()
	_append_ribbon(tool,points,half_width,region,0.0)
	return tool.commit()

static func bead_chain(points: PackedVector3Array, radius := 0.04,
		region := REGION_GOLD) -> ArrayMesh:
	var tool := _tool()
	for i in points.size():
		_append_ellipsoid(tool, points[i], Vector3.ONE*radius, 3, 7, region,
				float(i)/maxf(1.0,float(points.size()-1)), 3.0)
	return tool.commit()

static func aperture_sweep(loop: PackedVector3Array, radius := 0.025,
		region := REGION_GOLD) -> ArrayMesh:
	if loop.size() < 3: return _tool().commit()
	var closed := PackedVector3Array(loop)
	closed.append(loop[0])
	var radii := PackedFloat32Array()
	for _i in closed.size(): radii.append(radius)
	return sweep(closed, radii, 6, region)

static func gem(center := Vector3.ZERO, radius := 0.08,
		region := REGION_JEWEL) -> ArrayMesh:
	var tool := _tool()
	_append_gem(tool, center, radius, region, 0.0, 4.0)
	return tool.commit()

static func assemble(parts: Array[Mesh]) -> ArrayMesh:
	var tool := _tool()
	for part in parts:
		if part != null and part.get_surface_count() > 0:
			tool.append_from(part, 0, Transform3D.IDENTITY)
	return tool.commit()

static func mesh_signature(mesh: ArrayMesh) -> String:
	if mesh == null or mesh.get_surface_count() != 1: return ""
	return var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text()

static func _tool(compact_custom := false) -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_HALF if compact_custom \
			else SurfaceTool.CUSTOM_RGBA_FLOAT)
	return tool

static func _append_lathe(tool: SurfaceTool, profile: PackedVector2Array,
		segments: int, region: int, offset: Vector3, accessory: float) -> void:
	if profile.size() < 2: return
	for row in profile.size()-1:
		for side in segments:
			var a0 := TAU*float(side)/float(segments)
			var a1 := TAU*float(side+1)/float(segments)
			var p00 := offset+Vector3(cos(a0)*profile[row].x,profile[row].y,sin(a0)*profile[row].x)
			var p01 := offset+Vector3(cos(a1)*profile[row].x,profile[row].y,sin(a1)*profile[row].x)
			var p10 := offset+Vector3(cos(a0)*profile[row+1].x,profile[row+1].y,sin(a0)*profile[row+1].x)
			var p11 := offset+Vector3(cos(a1)*profile[row+1].x,profile[row+1].y,sin(a1)*profile[row+1].x)
			_quad(tool,p00,p01,p11,p10,(p00-offset).normalized(),region,
					0.25,float(row)/float(profile.size()-1),float(row+1)/float(profile.size()-1),accessory)

static func _append_sweep(tool: SurfaceTool, points: PackedVector3Array,
		radii: PackedFloat32Array, sides: int, region: int) -> void:
	if points.size()<2 or radii.size()!=points.size(): return
	for row in points.size()-1:
		var tangent := (points[row+1]-points[row]).normalized()
		var side_axis := tangent.cross(Vector3.UP).normalized()
		if side_axis.length_squared()<0.1: side_axis=Vector3.RIGHT
		var up_axis := side_axis.cross(tangent).normalized()
		for side in sides:
			var a0:=TAU*float(side)/float(sides); var a1:=TAU*float(side+1)/float(sides)
			var n0:=side_axis*cos(a0)+up_axis*sin(a0); var n1:=side_axis*cos(a1)+up_axis*sin(a1)
			var p00:=points[row]+n0*radii[row]; var p01:=points[row]+n1*radii[row]
			var p10:=points[row+1]+n0*radii[row+1]; var p11:=points[row+1]+n1*radii[row+1]
			_quad(tool,p00,p01,p11,p10,(n0+n1).normalized(),region,0.35,
					float(row)/float(points.size()-1),float(row+1)/float(points.size()-1),0.0)

static func _append_ribbon(tool: SurfaceTool, points: PackedVector3Array,
		half_width: float, region: int, accessory: float) -> void:
	if points.size()<2: return
	for i in points.size()-1:
		var t0:=float(i)/float(points.size()-1); var t1:=float(i+1)/float(points.size()-1)
		var tangent:=(points[i+1]-points[i]).normalized()
		var side:=tangent.cross(Vector3.UP).normalized()
		if side.length_squared()<0.1: side=Vector3.RIGHT
		_quad(tool,points[i]-side*half_width,points[i]+side*half_width,
				points[i+1]+side*half_width,points[i+1]-side*half_width,
				Vector3.UP,region,0.2,t0,t1,accessory)

static func _append_ellipsoid(tool: SurfaceTool, center: Vector3, radii: Vector3,
		rings: int, segments: int, region: int, joint: float, accessory: float) -> void:
	for ring in rings:
		var v0 := -PI*0.5+PI*float(ring)/float(rings)
		var v1 := -PI*0.5+PI*float(ring+1)/float(rings)
		for segment in segments:
			var u0:=TAU*float(segment)/float(segments); var u1:=TAU*float(segment+1)/float(segments)
			var n00:=Vector3(cos(v0)*cos(u0),sin(v0),cos(v0)*sin(u0))
			var n01:=Vector3(cos(v0)*cos(u1),sin(v0),cos(v0)*sin(u1))
			var n10:=Vector3(cos(v1)*cos(u0),sin(v1),cos(v1)*sin(u0))
			var n11:=Vector3(cos(v1)*cos(u1),sin(v1),cos(v1)*sin(u1))
			_quad(tool,center+n00*radii,center+n01*radii,center+n11*radii,
					center+n10*radii,(n00+n01+n10+n11).normalized(),region,
					joint,(sin(v0)+1.0)*0.5,(sin(v1)+1.0)*0.5,accessory)

static func _append_mosaic_ellipsoid(tool: SurfaceTool, center: Vector3,
		radii: Vector3, rings: int, segments: int, region: int, joint: float,
		accessory: float) -> void:
	for ring in rings:
		var v0 := -PI*0.5+PI*float(ring)/float(rings)
		var v1 := -PI*0.5+PI*float(ring+1)/float(rings)
		for segment in segments:
			var u0:=TAU*float(segment)/float(segments); var u1:=TAU*float(segment+1)/float(segments)
			var n00:=Vector3(cos(v0)*cos(u0),sin(v0),cos(v0)*sin(u0))
			var n01:=Vector3(cos(v0)*cos(u1),sin(v0),cos(v0)*sin(u1))
			var n10:=Vector3(cos(v1)*cos(u0),sin(v1),cos(v1)*sin(u0))
			var n11:=Vector3(cos(v1)*cos(u1),sin(v1),cos(v1)*sin(u1))
			var cell_region := REGION_GOLD if (ring*segments+segment)%11==0 else region
			_quad(tool,center+n00*radii,center+n01*radii,center+n11*radii,
					center+n10*radii,(n00+n01+n10+n11).normalized(),cell_region,
					joint,(sin(v0)+1.0)*0.5,(sin(v1)+1.0)*0.5,accessory)

static func _append_gem(tool: SurfaceTool, center: Vector3, radius: float,
		region: int, joint: float, accessory: float) -> void:
	var top:=center+Vector3.UP*radius; var bottom:=center-Vector3.UP*radius
	for side in 8:
		var a0:=TAU*float(side)/8.0; var a1:=TAU*float(side+1)/8.0
		var p0:=center+Vector3(cos(a0),0.0,sin(a0))*radius
		var p1:=center+Vector3(cos(a1),0.0,sin(a1))*radius
		_triangle(tool,top,p0,p1,(top-center+p0-center+p1-center).normalized(),
				region,joint,0.0,accessory)
		_triangle(tool,bottom,p1,p0,(bottom-center+p0-center+p1-center).normalized(),
				region,joint,1.0,accessory)

static func _append_box(tool: SurfaceTool, center: Vector3, size: Vector3,
		region: int, joint: float, accessory: float) -> void:
	var h:=size*0.5
	for face in [[Vector3.RIGHT,Vector3(h.x,-h.y,-h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(h.x,h.y,-h.z)],
			[-Vector3.RIGHT,Vector3(-h.x,-h.y,h.z),Vector3(-h.x,-h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,h.y,h.z)],
			[Vector3.UP,Vector3(-h.x,h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)],
			[-Vector3.UP,Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,-h.y,-h.z),Vector3(-h.x,-h.y,-h.z)],
			[Vector3.FORWARD,Vector3(-h.x,-h.y,h.z),Vector3(-h.x,h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(h.x,-h.y,h.z)],
			[-Vector3.FORWARD,Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,-h.y,-h.z)]]:
		_quad(tool,center+face[1],center+face[2],center+face[3],center+face[4],
				face[0],region,joint,0.0,1.0,accessory)

static func _quad(tool: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,d: Vector3,
		normal: Vector3,region: int,joint: float,t0: float,t1: float,
		accessory: float) -> void:
	_triangle(tool,a,b,c,normal,region,joint,t0,accessory)
	_triangle(tool,a,c,d,normal,region,joint,t1,accessory)

static func _triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		normal: Vector3,region: int,joint: float,body_t: float,
		accessory: float) -> void:
	for point in [a,b,c]:
		tool.set_normal(normal)
		tool.set_color(Color(float(region)/7.0,0.55,joint,1.0-joint))
		tool.set_custom(0,Color(body_t,atan2(point.z,point.x)/TAU+0.5,
				joint,accessory))
		tool.add_vertex(point)
