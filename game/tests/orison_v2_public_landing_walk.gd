extends "res://tests/orison_v2_vertical_route_test.gd"
## INERT diagnostic driver: one initial stance, real floor routes and stairs.
var _grid: AStarGrid2D
var _heights: Dictionary={}
var _minimum:=Vector2.ZERO
var _pitch:=.2
var _floor_y:=0.0
var _blocked: Dictionary={}

func _init() -> void:
	route_label="PUBLIC LANDING CIRCULATION"

func _run() -> void:
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	CampaignTime.set_frozen_for_tests(true)
	await super._run()

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(2.95,.025,-2.405))
	player.velocity=Vector3.ZERO

func _ground(point: Vector2) -> float:
	var at: Vector3=world.adapter.root.to_global(Vector3(point.x,_floor_y,point.y))
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.29,at-Vector3.UP*.05,1,[player.get_rid()])
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		# A ray exactly on a shared triangle edge can miss both adjacent slabs.
		for offset: Vector3 in [Vector3(.01,0,0),Vector3(-.01,0,0),Vector3(0,0,.01),Vector3(0,0,-.01)]:
			ray.from=at+offset+Vector3.UP*.29;ray.to=at+offset-Vector3.UP*.05
			hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():break
	if hit.is_empty() or hit.normal.y<.7:
		_blocked["no supporting floor"]=int(_blocked.get("no supporting floor",0))+1;return NAN
	var local: Vector3=world.adapter.root.to_local(hit.position)
	if local.y-_floor_y>.28 or local.y-_floor_y<-.04:return NAN
	var shape:=PhysicsShapeQueryParameters3D.new();shape.shape=player._capsule
	shape.collision_mask=1;shape.exclude=[player.get_rid()];shape.margin=.005
	shape.transform=Transform3D(world.adapter.root.global_basis,world.adapter.root.to_global(Vector3(point.x,local.y+player._capsule.height*.5+.025,point.y)))
	var contacts: Array[Dictionary]=world.get_world_3d().direct_space_state.intersect_shape(shape,1)
	if not contacts.is_empty():
		var collider:=contacts[0].collider as Node
		var label:=str(collider.get_path()) if collider!=null else "physical obstruction"
		_blocked[label]=int(_blocked.get(label,0))+1;return NAN
	return local.y

func _prepare(core: Dictionary,pitch: float) -> void:
	_pitch=pitch;_heights.clear();_blocked.clear()
	var rect: Array=core.rect;_minimum=Vector2(rect[0],rect[1])
	_grid=AStarGrid2D.new();_grid.region=Rect2i(Vector2i.ZERO,Vector2i(ceili((rect[2]-rect[0])/pitch)+1,ceili((rect[3]-rect[1])/pitch)+1))
	_grid.cell_size=Vector2.ONE*pitch;_grid.offset=_minimum;_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;_grid.update()
	for x in _grid.region.size.x:
		for z in _grid.region.size.y:
			var id:=Vector2i(x,z);var at:=_minimum+Vector2(id)*pitch
			var height:=_ground(at)
			_grid.set_point_solid(id,is_nan(height))
			if not is_nan(height):_heights[id]=height
		if x%8==0:await get_tree().process_frame

func _id(at: Vector3) -> Vector2i:
	return Vector2i(roundi((at.x-_minimum.x)/_pitch),roundi((at.z-_minimum.y)/_pitch))

func _free_id(at: Vector3) -> Vector2i:
	var centre:=_id(at);var chosen:=Vector2i(-1,-1);var distance:=.18
	var reach:=ceili(.18/_pitch)
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var id:=centre+Vector2i(x,z)
			if not _grid.region.has_point(id) or _grid.is_point_solid(id):continue
			var point:=_minimum+Vector2(id)*_pitch
			var delta:=point.distance_to(Vector2(at.x,at.z))
			if delta<distance:chosen=id;distance=delta
	return chosen

func _plan(core: Dictionary,target: Vector3) -> Array[Vector3]:
	for pitch: float in [.2,.1,.05]:
		await _prepare(core,pitch)
		var at: Vector3=world.adapter.root.to_local(player.global_position)
		# Contact can leave the real avatar just outside a blocked snapped cell.
		# Only connect to a physically clear cell within the ordinary arrival
		# tolerance; the connector itself still runs through the real controller.
		var first:=_free_id(at);var last:=_free_id(target)
		if not _grid.region.has_point(first) or not _grid.region.has_point(last) or _grid.is_point_solid(first) or _grid.is_point_solid(last):continue
		var path: Array[Vector2i]=_grid.get_id_path(first,last)
		if path.is_empty():continue
		var result: Array[Vector3]=[]
		var connector:=_minimum+Vector2(first)*pitch
		result.append(Vector3(connector.x,float(_heights[first]),connector.y))
		for i in range(1,path.size()):
			if i<path.size()-1 and path[i]-path[i-1]==path[i+1]-path[i] and absf(float(_heights[path[i-1]])-float(_heights[path[i]]))<.001 and absf(float(_heights[path[i+1]])-float(_heights[path[i]]))<.001:continue
			var p:=_minimum+Vector2(path[i])*pitch
			result.append(Vector3(p.x,float(_heights[path[i]]),p.y))
		result.append(target)
		return result
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var image:=Image.create(_grid.region.size.x,_grid.region.size.y,false,Image.FORMAT_RGB8)
		for x in _grid.region.size.x:
			for z in _grid.region.size.y:image.set_pixel(x,z,Color(.2,.65,.3) if not _grid.is_point_solid(Vector2i(x,z)) else Color(.08,.08,.1))
		image.resize(image.get_width()*4,image.get_height()*4,Image.INTERPOLATE_NEAREST)
		image.save_png(directory.path_join(str(core.level)+"_blocked_floor.png"))
		FileAccess.open(directory.path_join(str(core.level)+"_blocked_floor.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Real standing capsule and ground-ray diagnosis; not a played route.","pitch":_pitch,"clear_nodes":_heights.size(),"core":core.id,"target":target,"blocked":_blocked},"\t"))
	return []

func _floor_walk(core: Dictionary,target: Vector3) -> bool:
	var path:=await _plan(core,target)
	if path.is_empty():
		var message: String="no supported public route in "+str(core.id)+" from "+str(world.adapter.root.to_local(player.global_position))+" to "+str(target)
		failures.append(message);push_error(message);return false
	for point: Vector3 in path:
		if not await _walk(point):return false
	return true

func _route() -> void:
	for number in range(1,7):
		var floor: String="F%02d"%number;_floor_y=float(world.adapter.root.level_y[floor])
		var core: Dictionary={}
		for space: Dictionary in world.layout.spaces:
			if str(space.id)==floor+"_PUBLIC_CORE":core=space;break
		if not await _floor_walk(core,Vector3(3.4,_floor_y,2.75)):return
		if not await _floor_walk(core,Vector3(2.95,_floor_y,-2.405)):return
		if not await _floor_walk(core,Vector3(1.925,_floor_y,-3.4)):return
		if number==6:break
		for point: Vector3 in [Vector3(1.925,_floor_y+1.6,1.3),Vector3(3.975,_floor_y+1.6,1.3),Vector3(3.975,_floor_y+3.2,-2.4),Vector3(3.975,_floor_y+3.2,-3.4)]:
			if not await _walk(point):return
