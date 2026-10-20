extends Node
## Discovery from the composed collision world. Never access/route acceptance.
var space: PhysicsDirectSpaceState3D
var root: Node3D
var excluded: Array[RID]=[]
var capsule: Shape3D
var capsule_pose:=Transform3D.IDENTITY
const STEP:=.16

func clear_shape(shape: Shape3D,pose: Transform3D) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.transform=pose;query.collision_mask=1
	query.exclude=excluded;query.margin=.001
	return space.intersect_shape(query,1).is_empty()

func clear_feet(at: Vector3) -> bool:
	var pose:=root.global_transform*Transform3D(Basis.IDENTITY,at)*capsule_pose
	return clear_shape(capsule,pose)

func inside(point: Vector2,rect: Rect2) -> bool:
	return rect.has_point(point)

func flood(cells: Dictionary,seed: Vector2i,blocked: Rect2=Rect2()) -> Dictionary:
	var seen: Dictionary={}
	if not cells.has(seed) or blocked.has_point(cells[seed]):return seen
	var queue: Array[Vector2i]=[seed];seen[seed]=true;var cursor:=0
	while cursor<queue.size():
		var at: Vector2i=queue[cursor];cursor+=1
		for delta: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i=at+delta
			if not seen.has(next) and cells.has(next) and not blocked.has_point(cells[next]):seen[next]=true;queue.append(next)
	return seen

func nearest(cells: Dictionary,point: Vector2,max_distance: float=.28) -> Vector2i:
	var best:=Vector2i(-999,-999);var distance:=max_distance
	for cell: Vector2i in cells:
		var delta: float=point.distance_to(cells[cell])
		if delta<distance:distance=delta;best=cell
	return best

func door_sweep(world: OrisonV2RuntimeRoot,record: Dictionary) -> Array[AABB]:
	var boxes: Array[AABB]=[]
	var leaf:=world.adapter.resolve(str(record.id)+"_Leaf") as Node3D
	if leaf==null or not leaf.has_method("motion_target_angle"):return boxes
	var body:=leaf.get_node_or_null("HingedLeaf") as Node3D
	if body==null:return boxes
	for collision: CollisionShape3D in body.find_children("*","CollisionShape3D",false,false):
		if not collision.shape is BoxShape3D:continue
		var size: Vector3=(collision.shape as BoxShape3D).size
		var stop: float=float(leaf.motion_target_angle(true))
		var frame: Transform3D=root.global_transform.affine_inverse()*leaf.global_transform
		# Every corner travels at most this far between a sampled angle and
		# its nearest sample. Extra80mm includes the leaf's projecting knobs.
		var margin: float=(float(record.width)+.12)*absf(stop)/120.+.08
		for index in 61:
			var pose:=frame*Transform3D(Basis(Vector3.UP,stop*index/60.),body.position)*collision.transform
			boxes.append((pose*AABB(-size*.5,size)).grow(margin))
	return boxes

func run(world: OrisonV2RuntimeRoot,directory: String) -> Dictionary:
	root=world.adapter.root;space=world.get_world_3d().direct_space_state
	for actor: CharacterBody3D in world.find_children("*","CharacterBody3D",true,false):excluded.append(actor.get_rid())
	for shape: CollisionShape3D in world.player.find_children("*","CollisionShape3D",false,false):
		if shape.get_parent()==world.player:capsule=shape.shape;capsule_pose=shape.transform;break
	assert(capsule!=null,"Player collision shape required for kitchen survey")
	var radius: float=capsule.radius if capsule is CapsuleShape3D else .28
	var finishes: Array[Dictionary]=preload("res://scripts/building/orison_v2_furnishing_clearance.gd").finish_stock(root)
	var rows: Array=[]
	for room: Dictionary in world.layout.spaces:
		if not str(room.id).ends_with("_KITCHEN"):continue
		var rect:=Rect2(float(room.rect[0]),float(room.rect[1]),float(room.rect[2])-float(room.rect[0]),float(room.rect[3])-float(room.rect[1]))
		var floor_y: float=float(root.level_y[str(room.level)])
		var room_bounds:=AABB(Vector3(rect.position.x,floor_y,rect.position.y),Vector3(rect.size.x,1.1,rect.size.y))
		var nearby: Array[AABB]=[]
		for finish: Dictionary in finishes:
			if room_bounds.intersects(finish.bounds):nearby.append(finish.bounds)
		var sweeps: Array[AABB]=[]
		var door_records: Array[Dictionary]=[]
		for record: Dictionary in world.layout.doors:
			if str(room.id) in record.connects:
				door_records.append(record);sweeps.append_array(door_sweep(world,record))
		var cells: Dictionary={}
		for x in range(1,int(rect.size.x/STEP)):
			for z in range(1,int(rect.size.y/STEP)):
				var point:=rect.position+Vector2(x,z)*STEP
				if clear_feet(Vector3(point.x,floor_y+.025,point.y)):cells[Vector2i(x,z)]=point
		var targets: Array[Vector2i]=[];var unresolved: Array[String]=[]
		var entry:=Vector2i(-999,-999)
		for door: Dictionary in door_records:
			var center:=Vector2(float(door.center[0]),float(door.center[1]))
			var normal:=Vector2(sin(float(door.yaw)),cos(float(door.yaw)))
			if normal.dot(rect.get_center()-center)<0:normal=-normal
			var cell:=nearest(cells,center+normal*(radius+.22))
			if cell.x==-999:unresolved.append(str(door.id)+":inside_approach")
			else:
				if entry.x==-999:entry=cell
				if cell not in targets:targets.append(cell)
		for anchor: Dictionary in world.layout.anchors:
			if str(anchor.get("space",""))!=str(room.id) or str(anchor.kind)!="clearance":continue
			var cell:=nearest(cells,Vector2(float(anchor.position[0]),float(anchor.position[2])))
			if cell.x==-999:unresolved.append(str(anchor.id))
			elif cell not in targets:targets.append(cell)
		var baseline: Dictionary={};var seed:=Vector2i(-999,-999)
		for cell: Vector2i in cells:
			if baseline.has(cell):continue
			var component:=flood(cells,cell)
			if component.size()>baseline.size():baseline=component;seed=cell
		if entry.x!=-999:baseline=flood(cells,entry);seed=entry
		var required: Array[Vector2i]=[]
		for target: Vector2i in targets:
			if baseline.has(target):required.append(target)
		var choices: Array=[]
		var rejections: Dictionary={"door":0,"finish":0,"collision":0,"approach":0,"route":0}
		for dimensions: Vector2 in [Vector2(1.2,.6),Vector2(1.0,.55),Vector2(.8,.5)]:
			for side in 4:
				var yaw: float=[PI,0.0,-PI*.5,PI*.5][side]
				var along_x: bool=side<2
				var length: float=rect.size.x if along_x else rect.size.y
				for index in range(ceili((length-dimensions.x-.24)/.10)+1):
					var along: float=.12+dimensions.x*.5+index*.10
					if along+dimensions.x*.5>length-.12:continue
					var at:=Vector3.ZERO;at.y=floor_y
					if along_x:
						at.x=rect.position.x+along;at.z=(rect.position.y+.13+dimensions.y*.5) if side==0 else (rect.end.y-.13-dimensions.y*.5)
					else:
						at.z=rect.position.y+along;at.x=(rect.position.x+.13+dimensions.y*.5) if side==2 else (rect.end.x-.13-dimensions.y*.5)
					var basis:=Basis(Vector3.UP,yaw)
					var bounds: AABB=Transform3D(basis,at)*AABB(Vector3(-dimensions.x*.5,.025,-dimensions.y*.5),Vector3(dimensions.x,.88,dimensions.y))
					var blocked:=Rect2(bounds.position.x-radius-.03,bounds.position.z-radius-.03,bounds.size.x+2*(radius+.03),bounds.size.z+2*(radius+.03))
					var bad:=false
					for sweep: AABB in sweeps:
						if bounds.intersects(sweep):bad=true;break
					if bad:rejections.door+=1;continue
					for finish: AABB in nearby:
						if bounds.grow(.012).intersects(finish):bad=true;break
					if bad:rejections.finish+=1;continue
					var box:=BoxShape3D.new();box.size=Vector3(dimensions.x+.03,.85,dimensions.y+.03)
					if not clear_shape(box,root.global_transform*Transform3D(basis,at+Vector3.UP*.465)):rejections.collision+=1;continue
					var stance: Vector3=at+basis*Vector3(0,.025,-dimensions.y*.5-.43)
					if not rect.has_point(Vector2(stance.x,stance.z)) or not clear_feet(stance):rejections.approach+=1;continue
					var front:=nearest(cells,Vector2(stance.x,stance.z))
					if front.x==-999:continue
					var connected:=flood(cells,front,blocked)
					if connected.is_empty():continue
					for target: Vector2i in required:
						if not connected.has(target):bad=true;break
					if bad:rejections.route+=1;continue
					choices.append({"position":[at.x,floor_y,at.z],"yaw":yaw,"width":dimensions.x,"depth":dimensions.y,"additional_top_m2":dimensions.x*dimensions.y,"side":side,"approach":[stance.x,stance.y,stance.z],"baseline_stances_retained":required.size(),"connected_grid_cells":connected.size()})
		choices.sort_custom(func(a,b):
			if not is_equal_approx(a.additional_top_m2,b.additional_top_m2):return a.additional_top_m2>b.additional_top_m2
			return int(a.connected_grid_cells)>int(b.connected_grid_cells))
		rows.append({"space":room.id,"level":room.level,"rect":room.rect,"candidate_count":choices.size(),"choices":choices.slice(0,12),"baseline_free_cells":cells.size(),"baseline_clearance_stances":required.size(),"unresolved_existing_stances":unresolved,"rejections":rejections,"door_sweep_boxes":sweeps.size()})
		print("KITCHEN PREP SURVEY: ",room.id," candidates=",choices.size()," unresolved_existing=",unresolved.size())
	var result: Dictionary={"evidence_class":"INERT","scope":"Composed collision/finished-trim discovery. Grid connectivity preserves currently reachable source stances and door-inside approaches; not a continuous swept-route, new geometry, hand or human acceptance proof. Actual retained leaf collision boxes sampled through their owned stop angles with a conservative between-sample/hardware envelope.","grid_step_m":STEP,"player_radius_m":radius,"rooms":rows}
	FileAccess.open(directory.path_join("prep_survey.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	return result
