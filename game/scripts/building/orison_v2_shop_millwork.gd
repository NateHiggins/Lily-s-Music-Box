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


static func mount_prepared(shell: Node3D, contract: Dictionary, frames: Array) -> bool:
	# Reuse the Blender-authored profile kit on actual expanded wall stocks.
	# Detached legacy trim/collisions remain in custody; this grants no disposal.
	if shell == null or shell.get_meta("arcade_shell_asset_sha256", "") != contract.get("asset_sha256"):
		return false
	if contract.get("shops", []).size() != 11 or contract.get("trade_floors", []).size() != 22:
		return false
	var origin: Array = contract.source_origin_blender_m
	var stock: Array[Dictionary] = []
	var openings: Array[AABB] = []
	for piece: Dictionary in contract.closed_stocks:
		if str(piece.material) not in ["wall", "frame", "glazing"]: continue
		var rect: Array = piece.plan_rect_m
		var low := Vector3(float(origin[0])+float(rect[0]),float(piece.bottom_m),-float(origin[1])+float(rect[1]))
		var size := Vector3(float(rect[2])-float(rect[0]),float(piece.top_m)-float(piece.bottom_m),float(rect[3])-float(rect[1]))
		if size.x <= 0 or size.y <= 0 or size.z <= 0: return false
		var bounds := AABB(low,size)
		if piece.material == "wall":
			stock.append({"owner":str(piece.owner),"source":str(piece.name),"label":str(piece.name),"along_x":size.x>size.z,"bounds":bounds})
		else:
			# Include real glazing and its complete casing/return envelope.
			openings.append(bounds.grow(.001))
	# Reserve the real native leaf/pull sweep, including the hinge setback.
	# Axis-aligned envelopes are deliberately conservative. Their growth encloses
	# the between-sample rotational chord, rather than trusting isolated poses.
	if frames.size() != 22: return false
	var leaf_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_door_leaves.json"))
	var helper := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd").new()
	var swing_boxes := 0
	var frame_names := {}
	var frame_roles := {}
	var shop_ids := {}
	for shop: Dictionary in contract.shops: shop_ids[str(shop.id)]=true
	for frame: Dictionary in frames:
		var identity := str(frame.get("id", ""))
		if identity.is_empty() or frame_names.has(identity): return false
		frame_names[identity]=true
		var cell := str(frame.get("cell",""))
		var role := "front_pair" if bool(frame.get("paired",false)) else "stock_single"
		var token := cell+"/"+role
		if not shop_ids.has(cell) or frame_roles.has(token) or str(frame.get("frame_kind","")) != role: return false
		if float(frame.get("opening_angle_deg",0)) != 90.0 or float(frame.get("height",0)) != float(leaf_spec.height_m) or float(frame.get("width",0)) != (2.0 if role=="front_pair" else 1.0): return false
		frame_roles[token]=true
		var pose: Transform3D = helper._matrix(frame.frame_transform)
		if not helper._rigid(pose): return false
		for collider: Dictionary in leaf_spec.collider_boxes:
			var right := str(collider.side) == "Right"
			if right and not bool(frame.paired): continue
			var low := helper._point(collider.low)
			var high := helper._point(collider.high)
			var pivot := Vector3(float(frame.width) if right else 0.0,0,-DoorProp.HINGE_SETBACK)
			var bounds := AABB()
			var first := true
			var radius := Vector2(maxf(absf(low.x),absf(high.x)),maxf(absf(low.z+DoorProp.HINGE_SETBACK),absf(high.z+DoorProp.HINGE_SETBACK))).length()
			for step: int in 361:
				var rotation := Basis(Vector3.UP,deg_to_rad(float(step)*.25)*(-1.0 if right else 1.0))
				for x: float in [low.x,high.x]:
					for y: float in [low.y,high.y]:
						for z: float in [low.z,high.z]:
							var point := pose*(pivot+rotation*(Vector3(x,y,z)+Vector3.BACK*DoorProp.HINGE_SETBACK))
							if first: bounds=AABB(point,Vector3.ZERO);first=false
							else: bounds=bounds.expand(point)
			openings.append(bounds.grow(.003+2.0*radius*sin(deg_to_rad(.25)*.25)))
			swing_boxes += 1
	var pending: Array[Dictionary] = []
	for shop: Dictionary in contract.shops:
		var cell := shell.get_node_or_null(NodePath(str(shop.id))) as Node3D
		if cell == null or cell.has_node("StandardWallMillwork"): return false
		var r: Array = shop.rect_m
		var cut: Array = shop.partition_rect_m
		var rear: Array = shop.stock_rect_m
		var depth := minf(float(cut[2])-float(cut[0]),float(cut[3])-float(cut[1]))
		var sales: Array
		match str(shop.front):
			"west": sales=[float(r[0])+depth,float(r[1])+depth,float(cut[0]),float(r[3])-depth]
			"east": sales=[float(cut[2]),float(r[1])+depth,float(r[2])-depth,float(r[3])-depth]
			"north": sales=[float(r[0])+depth,float(r[1])+depth,float(r[2])-depth,float(cut[1])]
			_: return false
		for room: Array in [sales,rear]:
			if float(room[2]) <= float(room[0]) or float(room[3]) <= float(room[1]): return false
		var own_stock: Array[Dictionary] = []
		var height := 0.0
		for wall: Dictionary in stock:
			if wall.owner == str(shop.id):
				own_stock.append(wall)
				height=maxf(height,wall.bounds.end.y)
		if own_stock.is_empty() or height <= 0: return false
		pending.append({"cell":cell,"shop":shop,"rooms":[sales,rear],"wall_depth":depth,"height":height,"stock":own_stock})
	# Validation completes before any node is attached.
	for entry: Dictionary in pending:
		var trim := Node3D.new()
		trim.name="StandardWallMillwork"
		entry.cell.add_child(trim)
		for index: int in 2:
			var r: Array = entry.rooms[index]
			var record := {"id":str(entry.shop.id)+("_sales" if index==0 else "_stock"),"rect":[float(origin[0])+float(r[0]),-float(origin[1])+float(r[1]),float(origin[0])+float(r[2]),-float(origin[1])+float(r[3])],"rect_is_inner":true,"class":"public","floor_y":0.0,"no_ceiling":true}
			var part := Node3D.new()
			part.name=str(record.id)
			trim.add_child(part)
			Millwork.build(part,record,0.0,float(entry.height),float(entry.wall_depth),null,null,[],openings,entry.stock)
		trim.set_meta("arcade_prepared_finish",true)
		trim.set_meta("arcade_swing_clearance_boxes",swing_boxes)
	return true
