extends RefCounted
## Source-owned shop floors and structural massing, fitted on every reload.
const Millwork := preload("res://scripts/building/orison_v2_millwork.gd")
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if not str(cell.name).begins_with("shop_") and str(cell.name)!="passage": return true
	var identity := str(cell.name).trim_prefix("shop_")
	if identity=="otis_son": identity="otis___son"
	var owner_batch := "passage_shell" if identity=="passage" else "shop_"+identity
	var records: Array[Dictionary] = []
	var stock: Array[Dictionary] = []
	for floor: Dictionary in layout.floors:
		if floor.id != "F01": continue
		for item: Dictionary in floor.furniture:
			var batch := str(item.get("batch",""))
			var label := str(item.id)
			if identity!="passage" and batch != owner_batch and batch != "passage_shell": continue
			if identity=="passage" and batch!="passage_shell" and not batch.begins_with("shop_"): continue
			if item.get("rect") is not Array or item.rect.size()!=4 or not item.has("z0") or not item.has("h"): continue
			var rect: Array = item.rect
			var low := Vector3(float(rect[0]),float(item.z0),-float(rect[3]))
			var size := Vector3(float(rect[2])-float(rect[0]),float(item.h),float(rect[3])-float(rect[1]))
			if label.ends_with("_floor") and batch==owner_batch:
				records.append({"id":label,"rect":[low.x,low.z,low.x+size.x,low.z+size.z],"rect_is_inner":true,"class":"public","floor_y":low.y+size.y,"no_ceiling":true})
			elif float(item.h)>=1.8 and str(item.mat) in ["plaster","plaster_stained","common_brick"] and minf(size.x,size.z)<.65:
				stock.append({"owner":identity,"source":label,"label":label,"along_x":size.x>size.z,"bounds":AABB(low,size)})
	if records.is_empty(): return false
	# Only original wall-attached trim/wainscot faces retire. Other stock and
	# every original collision remain intact, using the established triangle fitter.
	var boxes: Array[Dictionary] = []
	for record: Dictionary in records:
		for face: Dictionary in Millwork._room_wall_faces(record,stock,.12):
			var along_x: bool = face.along_x
			var normal_a: float = face.face
			var normal_b: float = normal_a+float(face.inward)*.065
			for band: Vector2 in [Vector2(float(record.floor_y)-.01,float(record.floor_y)+1.41),Vector2(float(record.floor_y)+2.12,float(record.floor_y)+2.25)]:
				var low := Vector3(float(face.start),band.x,minf(normal_a,normal_b)-.002) if along_x else Vector3(minf(normal_a,normal_b)-.002,band.x,float(face.start))
				var high := Vector3(float(face.finish),band.y,maxf(normal_a,normal_b)+.002) if along_x else Vector3(maxf(normal_a,normal_b)+.002,band.y,float(face.finish))
				boxes.append({"id":str(face.source)+":"+str(boxes.size()),"low":[low.x,low.y,low.z],"high":[high.x,high.y,high.z]})
	var counts := {}
	for box: Dictionary in boxes: counts[box.id]=0
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		if not (str(draw.name).ends_with("_trim-col") or str(draw.name).ends_with("_wainscot-col")): continue
		var result := Seating._without_boxes(draw,boxes,.003,counts,false)
		if result == null: return false
		draw.mesh=result
	var trim := Node3D.new(); trim.name="StandardWallMillwork"; cell.add_child(trim)
	for record: Dictionary in records:
		var part := Node3D.new(); part.name=str(record.id); trim.add_child(part)
		Millwork.build(part,record,float(record.floor_y),3.1,.12,null,null,[],[],stock)
	trim.set_meta("retired_wall_triangles",counts)
	return true
