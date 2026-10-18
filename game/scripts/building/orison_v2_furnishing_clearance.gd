extends RefCounted
## Refit furnishing assemblies against the actual installed finish, once at
## composition. Never translate only the visual or change a mechanical datum.
const FLOOR_KINDS := ["bed","nightstand","wardrobe","shelf","sofa","desk","workbench","chair","table_round","table_rect","coffee","hallstand","cardcabinet","canvasstack","hamper","crate","suitcase","easel","umbrellastand","verticalfile","plant","prep_cabinet","boottray","dressform","overflowtray","sewingmachine","ashcan","spittoon","foldedcot","softbox","tripod","wateringcan","trug"]
const HANGING_KINDS := ["artframe","pinboard","toolboard","noticeframe","quietsign","hookstrip","headsethook","coathook","tsquare","cupboard","bathshelf","garmentrail","lostshelves"]
const FINISH_NAMES := ["HistoricMillwork","PublicWainscot","PublicWainscotFrames","PublicWainscotCap"]
const AIR_GAP := .012
const HANGING_GAP := .004
const MAX_FLOOR_MOVE := .20
const MAX_HANGING_MOVE := 1.0

static func finish_stock(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var inverse := root.global_transform.affine_inverse()
	for draw: Node in root.find_children("*","MultiMeshInstance3D",true,false):
		if str(draw.name) not in FINISH_NAMES: continue
		var stock: MultiMesh=draw.multimesh
		if stock==null or stock.mesh==null:continue
		for i in stock.instance_count:
			var pose: Transform3D=inverse*draw.global_transform*stock.get_instance_transform(i)
			result.append({"bounds":pose*stock.mesh.get_aabb(),"normal":pose.basis.z.normalized(),"owner":str(draw.get_parent().name),"part":str(draw.name)})
	return result

static func parts(root: Node3D,body: Node3D) -> Array[AABB]:
	var result: Array[AABB]=[]
	var inverse := root.global_transform.affine_inverse()
	for draw: Node in body.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null or not draw.is_visible_in_tree():continue
		# Electrical leads and their floor receptacles follow the support, but
		# must not determine where its timber back/feet meet the baseboard.
		var parent: Node=draw
		var supply := false
		while parent!=body:
			if str(parent.name).begins_with("Supply_") or str(parent.name).begins_with("MediaAC_") or str(parent.name).begins_with("MediaBattery_"):supply=true
			parent=parent.get_parent()
		if supply:continue
		result.append(inverse*draw.global_transform*draw.mesh.get_aabb())
	return result

static func overlaps(boxes: Array[AABB],stock: Array[Dictionary],offset := Vector3.ZERO,gap := 0.0) -> Array[Dictionary]:
	var hits: Array[Dictionary]=[]
	for finish: Dictionary in stock:
		for box: AABB in boxes:
			box.position+=offset
			if box.grow(gap).intersects(finish.bounds):
				hits.append(finish);break
	return hits

static func new_overlap(boxes: Array[AABB],obstacles: Array[AABB],offset: Vector3) -> bool:
	for box: AABB in boxes:
		var moved := AABB(box.position+offset,box.size)
		for obstacle: AABB in obstacles:
			if not moved.intersects(obstacle):continue
			var after := moved.intersection(obstacle).get_volume()
			var before := box.intersection(obstacle).get_volume() if box.intersects(obstacle) else 0.0
			if after>before+.000001:return true
	return false

static func displacement(boxes: Array[AABB],stock: Array[Dictionary],hanging: bool,vertical_limits := Vector2(-INF,INF),obstacles: Array[AABB]=[]) -> Dictionary:
	var gap: float=HANGING_GAP if hanging else AIR_GAP
	var initial := overlaps(boxes,stock,Vector3.ZERO,gap)
	if initial.is_empty():return {"offset":Vector3.ZERO,"hits":0,"resolved":true}
	# Pictures/hooks stay seated on plaster: prefer a clear vertical interval
	# above/below a rail rather than floating the whole frame in front of it.
	if hanging:
		var candidates: Array[float]=[]
		for finish: Dictionary in stock:
			for box: AABB in boxes:
				if box.position.x>=finish.bounds.end.x or box.end.x<=finish.bounds.position.x or box.position.z>=finish.bounds.end.z or box.end.z<=finish.bounds.position.z:continue
				candidates.append(float(finish.bounds.end.y)-box.position.y+gap+.0001)
				candidates.append(float(finish.bounds.position.y)-box.end.y-gap-.0001)
		candidates.sort_custom(func(a: float,b: float) -> bool:return absf(a)<absf(b))
		for distance: float in candidates:
			if absf(distance)>MAX_HANGING_MOVE:continue
			var offset := Vector3.UP*distance
			var fits_height := true
			for box: AABB in boxes:
				if box.position.y+distance<vertical_limits.x or box.end.y+distance>vertical_limits.y:fits_height=false
			if not fits_height:continue
			if overlaps(boxes,stock,offset,gap).is_empty() and not new_overlap(boxes,obstacles,offset):return {"offset":offset,"hits":initial.size(),"resolved":true}
		return {"offset":Vector3.ZERO,"hits":initial.size(),"resolved":false}
	var offset := Vector3.ZERO
	for iteration in 4:
		var hits := overlaps(boxes,stock,offset,gap)
		if hits.is_empty():
			if not new_overlap(boxes,obstacles,offset):return {"offset":offset,"hits":initial.size(),"resolved":true}
			# A free case can slide slightly along its wall to keep adjoining
			# furniture clear. Retain the measured normal stand-off.
			var tangent := Vector3.FORWARD if absf(offset.x)>absf(offset.z) else Vector3.RIGHT
			for step in range(1,21):
				for side in [-1.0,1.0]:
					var candidate: Vector3=offset+tangent*step*.01*side
					if candidate.length()>MAX_FLOOR_MOVE:continue
					if overlaps(boxes,stock,candidate,gap).is_empty() and not new_overlap(boxes,obstacles,candidate):return {"offset":candidate,"hits":initial.size(),"resolved":true}
			break
		for finish: Dictionary in hits:
			var normal: Vector3=finish.normal
			var axis: int=0 if absf(normal.x)>.9 else 2
			var direction: float=signf(normal[axis])
			var plane: float=finish.bounds.end[axis] if direction>0 else finish.bounds.position[axis]
			var move := 0.0
			for box: AABB in boxes:
				var shifted := AABB(box.position+offset,box.size)
				if not shifted.grow(gap).intersects(finish.bounds):continue
				var back: float=shifted.position[axis] if direction>0 else shifted.end[axis]
				move=maxf(move,(plane-back)*direction+gap+.0001)
			offset[axis]+=move*direction
		if offset.length()>MAX_FLOOR_MOVE:break
	return {"offset":Vector3.ZERO,"hits":initial.size(),"resolved":false}

static func apply(world: Node3D) -> Dictionary:
	var root: Node3D=world.adapter.root
	if root.has_meta("v2_furnishing_clearance"):return root.get_meta("v2_furnishing_clearance")
	var stock := finish_stock(root)
	var fixed: Array[AABB]=[]
	for wall: Dictionary in preload("res://scripts/building/orison_v2_millwork.gd").collect_wall_stock(root):fixed.append(wall.bounds)
	for door: Dictionary in world.layout.doors:
		var pose := Transform3D(Basis(Vector3.UP,float(door.yaw)),Vector3(door.center[0],root.level_y[str(door.level)],door.center[1]))
		fixed.append(pose*AABB(Vector3(-float(door.width)*.5,0,-.10),Vector3(float(door.width),float(door.height),.20)))
	var candidates: Array[Node3D]=[]
	for node: Node in root.find_children("*","Node3D",true,false):
		var kind := str(node.get_meta("v2_furniture_kind",""))
		if kind in FLOOR_KINDS or kind in HANGING_KINDS or node is BookshelfProp:
			candidates.append(node)
		elif node is StaticBody3D and str(node.get_parent().name) in ["PublicFurnishings","ReadingFurniture"]:
			candidates.append(node)
	var rows: Array=[]
	var occupied: Dictionary={}
	for body: Node3D in candidates:occupied[body.get_instance_id()]=parts(root,body)
	# Fixed plumbing, counters and other domestic stock also constrain the move.
	for body: Node3D in root.find_children("*","Node3D",true,false):
		if body.has_meta("v2_furniture_kind") and not occupied.has(body.get_instance_id()):occupied[body.get_instance_id()]=parts(root,body)
	for body: Node3D in candidates:
		var boxes: Array[AABB]=occupied[body.get_instance_id()].duplicate()
		var followers := _followers(str(body.name))
		for follower: String in followers:
			var node := world.adapter.resolve(follower) as Node3D
			if node!=null and occupied.has(node.get_instance_id()) and not body.is_ancestor_of(node):boxes.append_array(occupied[node.get_instance_id()])
		var bounds := AABB()
		for i in boxes.size():bounds=boxes[i] if i==0 else bounds.merge(boxes[i])
		var nearby: Array[Dictionary]=[]
		for finish: Dictionary in stock:
			if bounds.grow(MAX_HANGING_MOVE).intersects(finish.bounds):nearby.append(finish)
		var hanging: bool=str(body.get_meta("v2_furniture_kind","")) in HANGING_KINDS
		var obstacles: Array[AABB]=[]
		for box: AABB in fixed:
			if bounds.grow(MAX_HANGING_MOVE).intersects(box):obstacles.append(box)
		for identity: int in occupied:
			if identity==body.get_instance_id():continue
			var other := instance_from_id(identity) as Node3D
			if other==null or str(other.name) in followers or body.is_ancestor_of(other):continue
			for box: AABB in occupied[identity]:
				if bounds.grow(MAX_HANGING_MOVE).intersects(box):obstacles.append(box)
		var mount_y: float=root.to_local(body.global_position).y
		var base_y := -INF
		for y: float in root.level_y.values():
			if y<=mount_y+.001:base_y=maxf(base_y,y)
		var limits := Vector2(base_y+.18,base_y+float(world.layout.dimensions.clear_height)-.10)
		for anchor: Dictionary in world.layout.anchors:
			if str(anchor.id)!=str(body.name):continue
			var floor_y: float=root.level_y[str(anchor.level)]
			limits=Vector2(floor_y+.18,floor_y+float(world.layout.dimensions.clear_height)-.10)
			break
		var fit := displacement(boxes,nearby,hanging,limits,obstacles)
		var offset: Vector3=fit.offset
		var row := {"id":str(body.name),"path":str(root.get_path_to(body)),"hanging":hanging,"hits":fit.hits,"resolved":fit.resolved,"offset":[offset.x,offset.y,offset.z],"parts":boxes.size(),"followers":followers}
		if not fit.resolved:
			var finish_rows: Array=[]
			for finish: Dictionary in nearby:finish_rows.append({"bounds":_pack([finish.bounds])[0],"normal":[finish.normal.x,finish.normal.y,finish.normal.z]})
			row["diagnostic"]={"boxes":_pack(boxes),"obstacles":_pack(obstacles),"finish":finish_rows,"vertical_limits":[limits.x,limits.y]}
		if offset!=Vector3.ZERO:
			var delta := root.global_basis*offset
			body.global_position+=delta
			var updated: Array[AABB]=[]
			for box: AABB in occupied[body.get_instance_id()]:updated.append(AABB(box.position+offset,box.size))
			occupied[body.get_instance_id()]=updated
			var semantic := root.find_child(str(body.name)+"_Semantic",true,false) as Node3D
			if semantic!=null:semantic.global_position+=delta
			# Independently mounted appliances are part of the same furniture
			# installation. Their native leads already belong to the support.
			for follower: String in _followers(str(body.name)):
				var node := world.adapter.resolve(follower) as Node3D
				if node!=null and not body.is_ancestor_of(node):
					node.global_position+=delta
					if occupied.has(node.get_instance_id()):
						var moved_parts: Array[AABB]=[]
						for box: AABB in occupied[node.get_instance_id()]:moved_parts.append(AABB(box.position+offset,box.size))
						occupied[node.get_instance_id()]=moved_parts
					var original := root.find_child(follower+"_Semantic",true,false) as Node3D
					if original!=null:original.global_position+=delta
					var approach := world.adapter.resolve(follower+"_STANCE") as Node3D
					if approach!=null:approach.global_position+=root.global_basis*Vector3(offset.x,0,offset.z)
			var stance := world.adapter.resolve(str(body.name)+"_STANCE") as Node3D
			if stance!=null:stance.global_position+=root.global_basis*Vector3(offset.x,0,offset.z)
			var identities: Array=[]
			for node: Node in [body]+body.find_children("*","Node3D",true,false):
				if AcousticGraphData.nodes.has(str(node.name)):identities.append(str(node.name))
			for follower: String in _followers(str(body.name)):
				if AcousticGraphData.nodes.has(follower):identities.append(follower)
			if not identities.is_empty():world.adapter.install_acoustic_overrides(identities)
		rows.append(row)
	var report := {"evidence_class":"INERT","scope":"Composition placement diagnostics; actual loaded geometry and bearings are checked separately by the composed suite.","stock":stock.size(),"items":rows}
	root.set_meta("v2_furnishing_clearance",report)
	return report

static func _pack(boxes: Array[AABB]) -> Array:
	var result: Array=[]
	for box: AABB in boxes:result.append([box.position.x,box.position.y,box.position.z,box.size.x,box.size.y,box.size.z])
	return result

static func _followers(identity: String) -> Array[String]:
	var result: Array[String]=[]
	if identity.ends_with("_din_t"):
		result.append(identity.trim_suffix("_t")+"_dc1")
		result.append(identity.trim_suffix("_t")+"_dc2")
	if identity=="1A_table":result.append("1A_chair")
	if identity=="2C_session_table":result.append("2C_session_chair")
	if identity=="4B_meal_table":result.append_array(["4B_meal_chair_01","4B_meal_chair_02"])
	# The specimen and neighbouring low case form Reed's potting display.
	if identity=="3A_prop_shelf_n":result.append("3A_story_specimen")
	if identity=="6A_prep_cabinet":result.append("6A_light_table")
	for path: String in ["res://data/orison_v2/media_ac_supply.json","res://data/orison_v2/media_battery_supply.json"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for row: Dictionary in data.installations:
			if str(row.support)==identity:result.append(str(row.id))
	var lamps: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/task_lamp_installations.json"))
	for row: Dictionary in lamps.lamps:
		if row.existing and str(row.support)==identity:result.append(str(row.id))
	if str(lamps.terminal_fit.support)==identity:result.append(str(lamps.terminal_fit.id))
	return result
