extends RefCounted
## Exposed slab undersides; the existing floor/ceiling owners and bodies remain.

static func _subtract(rect: Rect2,cut: Rect2) -> Array[Rect2]:
	if not rect.intersects(cut):return [rect]
	var overlap:=rect.intersection(cut)
	var pieces: Array[Rect2]=[
		Rect2(rect.position,Vector2(overlap.position.x-rect.position.x,rect.size.y)),
		Rect2(Vector2(overlap.end.x,rect.position.y),Vector2(rect.end.x-overlap.end.x,rect.size.y)),
		Rect2(Vector2(overlap.position.x,rect.position.y),Vector2(overlap.size.x,overlap.position.y-rect.position.y)),
		Rect2(Vector2(overlap.position.x,overlap.end.y),Vector2(overlap.size.x,rect.end.y-overlap.end.y))]
	var result: Array[Rect2]=[]
	for piece: Rect2 in pieces:
		if piece.size.x>.00001 and piece.size.y>.00001:result.append(piece)
	return result

static func ceiling_owners(layout: Dictionary,level_y: Dictionary,excluded: Array[String],shown: bool) -> Array[Dictionary]:
	var owners: Array[Dictionary]=[]
	if not shown:return owners
	for space: Dictionary in layout.spaces:
		if bool(space.get("no_ceiling",false)) or excluded.has(str(space.id)):continue
		var r: Array=space.rect
		var pieces: Array[Rect2]=[Rect2(Vector2(r[0],r[1]),Vector2(r[2]-r[0],r[3]-r[1]))]
		for opening: Dictionary in layout.get("slab_openings",[]):
			if str(opening.space)!=str(space.id) or str(opening.surface)!="Ceiling":continue
			var cut: Array=opening.rect
			var next: Array[Rect2]=[]
			for piece: Rect2 in pieces:next.append_array(_subtract(piece,Rect2(Vector2(cut[0],cut[1]),Vector2(cut[2]-cut[0],cut[3]-cut[1]))))
			pieces=next
		for piece: Rect2 in pieces:
			owners.append({"rect":piece,"y":float(level_y[str(space.level)])+float(layout.dimensions.clear_height)})
	return owners

static func floor_owners(record: Dictionary,layout: Dictionary,level_y: Dictionary) -> Array[Dictionary]:
	var r: Array=record.rect
	var pieces: Array[Rect2]=[Rect2(Vector2(r[0],r[1]),Vector2(r[2]-r[0],r[3]-r[1]))]
	for opening: Dictionary in layout.get("slab_openings",[]):
		if str(opening.space)!=str(record.id) or str(opening.surface)!="Floor":continue
		var cut: Array=opening.rect
		var next: Array[Rect2]=[]
		for piece: Rect2 in pieces:next.append_array(_subtract(piece,Rect2(Vector2(cut[0],cut[1]),Vector2(cut[2]-cut[0],cut[3]-cut[1]))))
		pieces=next
	var result: Array[Dictionary]=[]
	for piece: Rect2 in pieces:
		result.append({"rect":piece,"y":float(level_y[str(record.level)])-float(layout.dimensions.slab_thickness)})
	return result

static func append(draw: MeshInstance3D,platform: Dictionary,layout: Dictionary,level_y: Dictionary,owners: Array[Dictionary],finish: Material,room_floor: bool=false) -> void:
	var r: Array=platform.rect
	var y:=float(level_y[str(platform.level)])-float(layout.dimensions.slab_thickness)
	var pieces: Array[Rect2]=[Rect2(Vector2(r[0],r[1]),Vector2(r[2]-r[0],r[3]-r[1]))]
	if room_floor:
		pieces.clear()
		for owner: Dictionary in floor_owners(platform,layout,level_y):pieces.append(owner.rect)
	for owner: Dictionary in owners:
		if absf(float(owner.y)-y)>.00001:continue
		var next: Array[Rect2]=[]
		for piece: Rect2 in pieces:next.append_array(_subtract(piece,owner.rect))
		pieces=next
	if pieces.is_empty():return
	# Keep every existing top/side triangle, UV and tangent. Only the uncovered
	# underside gets a second surface and the existing ceiling finish.
	var top:=SurfaceTool.new();top.begin(Mesh.PRIMITIVE_TRIANGLES)
	top.append_from(draw.mesh,0,Transform3D.IDENTITY)
	top.set_material(draw.material_override)
	var mesh:=top.commit()
	var soffit:=SurfaceTool.new();soffit.begin(Mesh.PRIMITIVE_TRIANGLES)
	soffit.set_material(finish)
	for piece: Rect2 in pieces:
		var corners: Array[Vector3]=[
			Vector3(piece.position.x,y,piece.position.y),Vector3(piece.position.x,y,piece.end.y),
			Vector3(piece.end.x,y,piece.end.y),Vector3(piece.end.x,y,piece.position.y)]
		for index: int in [0,1,2,0,2,3]:
			var at:=corners[index]-draw.position
			soffit.set_normal(Vector3.DOWN)
			soffit.set_tangent(Plane(Vector3.RIGHT,1.0))
			soffit.set_uv(Vector2(at.x,at.z))
			soffit.add_vertex(at)
	soffit.commit(mesh)
	draw.material_override=null
	draw.mesh=mesh
	draw.set_meta("soffit_material_key","trim")
