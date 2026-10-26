extends RefCounted
## Static room-facing tile and narrow mortar joints on actual cut wall stock.
## Original wall meshes, collision owners, openings and door mechanisms remain.
const Millwork=preload("res://scripts/building/orison_v2_millwork.gd")
const WAINSCOT:=1.2192
const SHOWER_HEIGHT:=2.286
const SKIN:=.0045
const BEAD:=.003

static func build(shell: Node3D,layout: Dictionary,levels: Dictionary,materials: RefCounted,stock: Array[Dictionary]) -> void:
	var edging_material:=MatLib.get_mat("porcelain_fixture").duplicate() as StandardMaterial3D
	edging_material.albedo_color=Color(1.03,1.06,1.14)
	for record: Dictionary in layout.spaces:
		if record.get("class","")!="wet" or record.get("open_shell",false):continue
		var room:=shell.get_node_or_null(str(record.id)) as Node3D
		if room==null:continue
		var skirting:=room.get_node_or_null("HistoricMillwork")
		if skirting!=null:skirting.free()
		var floor_y: float=levels[str(record.level)]
		var casings:=Millwork._casing_boxes(record,layout.doors,floor_y,float(layout.dimensions.partition_wall))
		casings.append_array(preload("res://scripts/building/orison_v2_window_joinery.gd").clearance_boxes(shell,record))
		var faces:=Millwork._room_wall_faces(record,Millwork.wall_stock_for_band(stock,floor_y,floor_y+float(layout.dimensions.clear_height)),float(layout.dimensions.partition_wall))
		var shower_boxes: Array[AABB]=[]
		for anchor: Dictionary in layout.anchors:
			var rect: Array=record.rect
			var inside: bool=str(anchor.get("level",""))==str(record.level) and float(anchor.position[0])>float(rect[0]) and float(anchor.position[0])<float(rect[2]) and float(anchor.position[2])>float(rect[1]) and float(anchor.position[2])<float(rect[3])
			if inside and anchor.get("kind","")=="fixture" and "SHOWER" in str(anchor.id):
				var at:=Vector3(anchor.position[0],floor_y,anchor.position[2])+Basis(Vector3.UP,float(anchor.yaw))*preload("res://scripts/building/orison_v2_shower_placement.gd").local_offset(str(anchor.id))
				shower_boxes.append(AABB(at-Vector3(.46,0,.46),Vector3(.92,SHOWER_HEIGHT,.92)))
		var tiles:=SurfaceTool.new();tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
		var grout:=SurfaceTool.new();grout.begin(Mesh.PRIMITIVE_TRIANGLES)
		var patches: Array=[];var joints: Array=[];var corners: Dictionary={};var edges: Array=[]
		for face: Dictionary in faces:
			# End-grain/reveal faces stay plaster: tile belongs to room wall planes.
			var source_x: bool="WallNorth" in str(face.source) or "WallSouth" in str(face.source)
			if source_x!=bool(face.along_x):continue
			var low:=maxf(floor_y,float(face.low));var high:=minf(floor_y+WAINSCOT,float(face.high))
			var sections: Array[Rect2]=[]
			if high-low>.001:sections.append(Rect2(float(face.start),low,float(face.finish)-float(face.start),high-low))
			var tall: Array[Vector2]=[]
			for box: AABB in shower_boxes:
				var fixed_low: float=box.position.z if face.along_x else box.position.x
				var fixed_high: float=box.end.z if face.along_x else box.end.x
				if float(face.face)<fixed_low or float(face.face)>fixed_high:continue
				var start:=maxf(float(face.start),box.position.x if face.along_x else box.position.z)
				var finish:=minf(float(face.finish),box.end.x if face.along_x else box.end.z)
				var bottom:=maxf(floor_y+WAINSCOT,float(face.low));var top:=minf(floor_y+SHOWER_HEIGHT,float(face.high))
				if finish-start>.001 and top-bottom>.001:sections.append(Rect2(start,bottom,finish-start,top-bottom));tall.append(Vector2(start,finish))
			var normal:=Vector3(0,0,float(face.inward)) if face.along_x else Vector3(float(face.inward),0,0)
			for section: Rect2 in sections:
				var a:=_point(face,section.position.x,section.position.y)+normal*SKIN
				var b:=_point(face,section.end.x,section.position.y)+normal*SKIN
				var c:=_point(face,section.end.x,section.end.y)+normal*SKIN
				var d:=_point(face,section.position.x,section.end.y)+normal*SKIN
				_quad(tiles,a,b,c,d,normal,Vector3.UP.cross(normal).normalized())
				patches.append({"source":face.source,"along_x":face.along_x,"plane":face.face,"inward":face.inward,"rect":[section.position.x,section.position.y,section.end.x,section.end.y]})
				# Close exposed tile top; no cap crosses a tall shower continuation.
				var caps: Array[Vector2]=[Vector2(section.position.x,section.end.x)]
				if absf(section.end.y-floor_y-WAINSCOT)<.001:
					for cut: Vector2 in tall:caps=_subtract(caps,cut)
				for cap: Vector2 in caps:
					var left:=_point(face,cap.x,section.end.y);var right:=_point(face,cap.y,section.end.y)
					_quad(tiles,left,right,right+normal*SKIN,left+normal*SKIN,Vector3.UP)
					edges.append({"a":left,"b":right,"normal":normal,"outside":Vector3.UP})
			# Exposed union boundaries only. Shared field/shower seams and tiled
			# room corners receive their existing grout joint, not another cap.
			var along:=Vector3.RIGHT if face.along_x else Vector3.BACK
			for section: Rect2 in sections:
				for sign: float in [-1.0,1.0]:
					var x: float=section.position.x if sign<0.0 else section.end.x
					var spans: Array[Vector2]=[Vector2(section.position.y,section.end.y)]
					for other_section: Rect2 in sections:
						var filled: bool=other_section.position.x<x-.0001 and other_section.end.x>=x-.0001 if sign<0.0 else other_section.position.x<=x+.0001 and other_section.end.x>x+.0001
						if filled:spans=_subtract(spans,Vector2(other_section.position.y,other_section.end.y))
					for other: Dictionary in faces:
						if bool(face.along_x)==bool(other.along_x):continue
						var primary: bool=("WallNorth" in str(other.source) or "WallSouth" in str(other.source))==bool(other.along_x)
						if not primary or absf(float(other.face)-x)>.001 or float(face.face)<float(other.start)-.001 or float(face.face)>float(other.finish)+.001:continue
						var height:=floor_y+WAINSCOT
						var corner:=_point(face,x,floor_y+.01)
						for box: AABB in shower_boxes:
							if box.grow(.01).has_point(corner):height=floor_y+SHOWER_HEIGHT
						spans=_subtract(spans,Vector2(maxf(floor_y,float(other.low)),minf(height,float(other.high))))
					for span: Vector2 in spans:
						if span.y-span.x>.001:edges.append({"a":_point(face,x,span.x),"b":_point(face,x,span.y),"normal":normal,"outside":along*sign})
			if float(face.low)<=floor_y+.001 and float(face.high)>floor_y+.01:
				var a:=_point(face,float(face.start),floor_y)+normal*SKIN
				var b:=_point(face,float(face.finish),floor_y)+normal*SKIN
				_bead(grout,a,b,normal,Vector3.UP)
				joints.append({"kind":"floor","a":a,"b":b,"source":face.source})
			# Only actual perpendicular wall pairs create vertical room joints.
			for other: Dictionary in faces:
				if bool(face.along_x)==bool(other.along_x):continue
				var at: float=other.face
				if minf(absf(at-float(face.start)),absf(at-float(face.finish)))>.001:continue
				if float(face.face)<float(other.start)-.001 or float(face.face)>float(other.finish)+.001:continue
				var bottom:=maxf(floor_y,maxf(float(face.low),float(other.low)))
				var top:=minf(floor_y+WAINSCOT,minf(float(face.high),float(other.high)))
				var foot:=_point(face,at,floor_y)
				for box: AABB in shower_boxes:
					if box.grow(.01).has_point(foot+Vector3.UP*.01):top=minf(floor_y+SHOWER_HEIGHT,minf(float(face.high),float(other.high)))
				var key: String="%.4f:%.4f:%.4f:%.4f"%[foot.x,foot.z,bottom,top]
				if top-bottom<.001 or corners.has(key):continue
				corners[key]=true
				var second:=Vector3(0,0,float(other.inward)) if other.along_x else Vector3(float(other.inward),0,0)
				var a:=_point(face,at,bottom)+(normal+second)*SKIN
				var b:=Vector3(a.x,top,a.z)
				_bead(grout,a,b,normal,second);joints.append({"kind":"corner","a":a,"b":b,"source":face.source,"other":other.source})
		_emit(room,"BathroomTileWainscot",tiles,materials.material_for("BathroomTileWainscot","wet"),patches)
		_emit(room,"BathroomGroutJoints",grout,MatLib.get_mat("arcade_lime_mortar"),joints)
		_emit_edging(room,_clear_frames(edges,casings),edging_material)
		var edging:=room.get_node_or_null("BathroomTileEdging")
		if edging!=null:edging.set_meta("frame_clearance_boxes",casings)

static func _point(face: Dictionary,along: float,y: float) -> Vector3:
	return Vector3(along,y,float(face.face)) if face.along_x else Vector3(float(face.face),y,along)

static func _subtract(spans: Array[Vector2],cut: Vector2) -> Array[Vector2]:
	var result: Array[Vector2]=[]
	for span: Vector2 in spans:
		if cut.y<=span.x or cut.x>=span.y:result.append(span);continue
		if cut.x>span.x:result.append(Vector2(span.x,cut.x))
		if cut.y<span.y:result.append(Vector2(cut.y,span.y))
	return result

static func _quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3,texture_axis: Vector3=Vector3.ZERO) -> void:
	var chart_u: Vector3=(b-a).normalized() if texture_axis==Vector3.ZERO else texture_axis
	_triangle(surface,a,b,c,normal,chart_u);_triangle(surface,a,c,d,normal,chart_u)

static func _triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,chart_u: Vector3=Vector3.ZERO) -> void:
	if (b-a).length()<.00005 or (c-a).length()<.00005 or (b-a).cross(c-a).length()<1e-10:return
	if (b-a).cross(c-a).dot(normal)>0.0:
		var swap:=b
		b=c;c=swap
	# Derive the final basis from the actual emitted triangle, including caps.
	normal=-(b-a).cross(c-a).normalized()
	var u: Vector3=(b-a).normalized() if chart_u==Vector3.ZERO else chart_u
	u=(u-normal*u.dot(normal)).normalized()
	var v:=normal.cross(u)
	for point: Vector3 in [a,b,c]:
		surface.set_normal(normal);surface.set_tangent(Plane(u,1.0));surface.set_uv(Vector2(point.dot(u),point.dot(v)));surface.add_vertex(point)

static func _bead(surface: SurfaceTool,a: Vector3,b: Vector3,first: Vector3,second: Vector3) -> void:
	for index in 4:
		var angle:=float(index)*PI/8.0;var next:=float(index+1)*PI/8.0
		var p: Vector3=(first*cos(angle)+second*sin(angle))*BEAD
		var q: Vector3=(first*cos(next)+second*sin(next))*BEAD
		var normal: Vector3=(p+q).normalized()
		_quad(surface,a+p,b+p,b+q,a+q,normal)
	var direction: Vector3=(b-a).normalized()
	for end: Vector3 in [a,b]:
		for index in 4:
			var p: Vector3=(first*cos(float(index)*PI/8.0)+second*sin(float(index)*PI/8.0))*BEAD
			var q: Vector3=(first*cos(float(index+1)*PI/8.0)+second*sin(float(index+1)*PI/8.0))*BEAD
			_triangle(surface,end,end+p,end+q,-direction if end==a else direction)

static func _emit(room: Node3D,label: String,surface: SurfaceTool,material: Material,records: Array) -> void:
	if records.is_empty():return
	surface.index()
	var draw:=MeshInstance3D.new();draw.name=label;draw.mesh=surface.commit();draw.material_override=material
	if label=="BathroomTileWainscot":draw.set_meta("v2_material_key","bath_wall_tile")
	# This millimetre-scale ceramic lip receives room light and keeps its real
	# rounded specular silhouette. Its low-resolution point-light shadow caused
	# a conspicuous jagged line on the field tile; no other caster is changed.
	if label=="BathroomTileEdging":draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.set_meta("finish_records",records);room.add_child(draw)

# Architectural ceramic trim shares the static shell's metric mesh construction.
# It introduces no prop, simulation, physics owner, texture or per-frame scan.
static func _edge_profile() -> Array[Vector2]:
	var profile: Array[Vector2]=[Vector2(-.024,0),Vector2(.006,0),Vector2(.006,.0045)]
	for index in range(1,17):
		var angle:=float(index)*PI/32.0
		profile.append(Vector2(-.004+.010*cos(angle),.0045+.010*sin(angle)))
	profile.append(Vector2(-.018,.0145));profile.append(Vector2(-.024,.0045))
	return profile

static func _edge_join(edge: Dictionary,at: Vector3,edges: Array) -> Dictionary:
	var t: Vector3=(edge.b-edge.a).normalized()
	for other: Dictionary in edges:
		if other==edge or minf(at.distance_to(other.a),at.distance_to(other.b))>.0001:continue
		if absf(t.dot((other.b-other.a).normalized()))>.001:continue
		if (edge.normal as Vector3).dot(other.normal)>.999 and absf(t.dot(other.outside))>.999:
			return {"kind":"plane","coefficient":1.0/t.dot(other.outside)}
		if absf((edge.normal as Vector3).dot(other.normal))<.001 and (edge.outside as Vector3).dot(other.outside)>.999 and absf(t.dot(other.normal))>.999:
			return {"kind":"wall","coefficient":1.0/t.dot(other.normal)}
	return {}

static func _edge_ring(edge: Dictionary,at: Vector3,join: Dictionary,profile: Array[Vector2]) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var t: Vector3=(edge.b-edge.a).normalized()
	for p: Vector2 in profile:
		var shift:=0.0
		if not join.is_empty():shift=(p.x if join.kind=="plane" else p.y)*float(join.coefficient)
		points.append(at+t*shift+(edge.outside as Vector3)*p.x+(edge.normal as Vector3)*p.y)
	return points

static func _emit_edging(room: Node3D,edges: Array,material: Material) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile:=_edge_profile()
	for edge: Dictionary in edges:
		var t: Vector3=(edge.b-edge.a).normalized()
		var first:=_edge_join(edge,edge.a,edges);var last:=_edge_join(edge,edge.b,edges)
		var a:=_edge_ring(edge,edge.a,first,profile);var b:=_edge_ring(edge,edge.b,last,profile)
		edge["start_join"]=first;edge["end_join"]=last
		for index in profile.size():
			var next: int=(index+1)%profile.size()
			var delta:=profile[next]-profile[index]
			var n: Vector3=((edge.outside as Vector3)*delta.y-(edge.normal as Vector3)*delta.x).normalized()
			_quad(surface,a[index],b[index],b[next],a[next],n,t)
		for end in 2:
			var ring: Array[Vector3]=a if end==0 else b
			var center:=Vector3.ZERO
			for point: Vector3 in ring:center+=point/float(ring.size())
			for index in ring.size():_triangle(surface,center,ring[index],ring[(index+1)%ring.size()],-t if end==0 else t)
	_emit(room,"BathroomTileEdging",surface,material,edges)

# Clip the complete profile envelope, rather than only its wall centreline.
# Door/window joinery owns the boundary; the ceramic receives a flat glazed end.
static func _clear_frames(edges: Array,frames: Array[AABB]) -> Array:
	var result: Array=[]
	for edge: Dictionary in edges:
		var minimum:=Vector3(INF,INF,INF);var maximum:=Vector3(-INF,-INF,-INF)
		for p: Vector2 in _edge_profile():
			var offset: Vector3=edge.outside*p.x+edge.normal*p.y
			minimum=minimum.min(offset);maximum=maximum.max(offset)
		var direction: Vector3=edge.b-edge.a
		var spans: Array[Vector2]=[Vector2(0,1)]
		for frame: AABB in frames:
			var low: Vector3=frame.position-maximum-Vector3.ONE*.0002
			var high: Vector3=frame.end-minimum+Vector3.ONE*.0002
			var enter:=0.0;var leave:=1.0;var intersects:=true
			for axis in 3:
				if absf(direction[axis])<.000001:
					if edge.a[axis]<low[axis] or edge.a[axis]>high[axis]:intersects=false;break
				else:
					var first: float=(low[axis]-edge.a[axis])/direction[axis]
					var last: float=(high[axis]-edge.a[axis])/direction[axis]
					enter=maxf(enter,minf(first,last));leave=minf(leave,maxf(first,last))
					if enter>=leave:intersects=false;break
			if intersects:spans=_subtract(spans,Vector2(enter,leave))
		for span: Vector2 in spans:
			if (span.y-span.x)*direction.length()<.001:continue
			var clipped:=edge.duplicate()
			clipped.a=edge.a+direction*span.x;clipped.b=edge.a+direction*span.y
			result.append(clipped)
	return result
