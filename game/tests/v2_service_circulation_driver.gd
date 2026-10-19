extends "res://tests/orison_v2_public_landing_walk.gd"
## One basement fixture; live service halls, real thresholds and seven stairs.
const FirstSlice := preload("res://tests/orison_v2_first_slice_contract_test.gd")
var crossings: Array[Dictionary]=[]
var threshold_preflight: Array[Dictionary]=[]
var _allowed: Array[Array]=[]
var _last_door_input: Dictionary={}
var _floor_cache: Dictionary={}
var _grid_builds:=0
var _grid_reuses:=0

func _init() -> void:
	route_label="SERVICE CIRCULATION"

func _prepare_player_start() -> void:
	var y: float=world.adapter.root.level_y.B1
	player.global_position=world.adapter.root.to_global(Vector3(11.075,y+.025,4.3))
	player.velocity=Vector3.ZERO

func _ground(point: Vector2) -> float:
	var admitted:=false
	for rect: Array in _allowed:
		if point.x>=rect[0] and point.x<=rect[2] and point.y>=rect[1] and point.y<=rect[3]:admitted=true;break
	return super._ground(point) if admitted else NAN

func _prepare(core: Dictionary,pitch: float) -> void:
	# Reuse unchanged floor queries between targets. Actual controller movement
	# still checks every segment; operating a door invalidates this candidate grid.
	var key:=str(core.level)+":"+str(pitch)
	if _floor_cache.has(key):
		var saved: Dictionary=_floor_cache[key]
		_grid=saved.grid;_heights=saved.heights.duplicate();_minimum=saved.minimum;_pitch=pitch
		_blocked=saved.blocked.duplicate();_grid_reuses+=1
		return
	await super._prepare(core,pitch)
	_floor_cache[key]={"grid":_grid,"heights":_heights.duplicate(),"minimum":_minimum,"blocked":_blocked.duplicate()}
	_grid_builds+=1

func _require(ok: bool,label: String) -> bool:
	interaction_checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label);push_error(label)
	return ok

func _capture_standing(label: String,local_target: Vector3) -> bool:
	var directory:=OS.get_environment("SHOT_DIR")
	if not _require(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"standing capture destination: "+label):return false
	player.camera.look_at(world.adapter.root.to_global(local_target))
	await RenderingServer.frame_post_draw
	return _require(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"write standing passage capture: "+label)

func _door(record: Dictionary,want_open: bool=true) -> bool:
	var opening: Node3D=world.adapter.resolve(str(record.id))
	var leaf: DoorProp=opening.get_node_or_null(str(record.id)+"_Leaf") as DoorProp if opening!=null else null
	if not _require(leaf!=null,"actual controlled service leaf: "+str(record.id)):return false
	for frame in 180:
		if not leaf._moving:break
		await get_tree().physics_frame
	if not _require(not leaf._moving,"service leaf settles before acquiring it"):return false
	# Give a pull-side leaf its real swing space when a supported stance exists.
	# Reach it through ordinary movement; never move the camera/body by fixture.
	var closed_direction: Vector3=world.adapter.root.global_basis.inverse()*leaf.global_basis.x
	var pull_stance:=Vector3(float(record.center[0])+.525,_floor_y,float(record.center[1]))+closed_direction*(leaf.width*.5+PlayerController.BODY_RADIUS+.1)
	if not _require(not is_nan(_ground(Vector2(pull_stance.x,pull_stance.z))),"supported latch-side stance outside service leaf arc: "+str(record.id)):return false
	if not await _floor_walk(_domain(str(record.level)),pull_stance):return false
	player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
	var hand:=FirstSlice.PatrolHand.new();add_child(hand);hand.player=player
	var body:=leaf.get_node("HingedLeaf") as Node3D
	var ok:=true
	if want_open and leaf.open:ok=await hand.operate(body.to_global(Vector3(leaf.width*.5,1.1,0)),0.0,leaf)
	if ok:ok=await hand.operate(body.to_global(Vector3(leaf.width*.5,1.1,0)),leaf.motion_target_angle(want_open),leaf)
	ok=ok and leaf.open==want_open and hand.follows_cursor and not player._grab.active()
	_floor_cache.clear()
	_last_door_input={"owner":str(record.id),"kind":"grab_mouse_release","released":not player._grab.active(),"follows_cursor":hand.follows_cursor,"ready_for_passage":leaf.is_ready_for_passage(),"actual_angle":body.rotation.y,"stop_angle":leaf.motion_target_angle(true)}
	hand.free()
	var directory:=OS.get_environment("SHOT_DIR")
	if ok and not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		player.camera.look_at(body.to_global(Vector3(leaf.width*.5,1.1,0)))
		await RenderingServer.frame_post_draw
		ok=_require(get_viewport().get_texture().get_image().save_png(directory.path_join(str(record.id)+("_open.png" if want_open else "_closed.png")))==OK,"write actual service door capture: "+str(record.id)) and ok
	return _require(ok,"grab, motion and release "+("opens" if want_open else "closes")+" actual service leaf: "+str(record.id))

func _domain(floor: String) -> Dictionary:
	_allowed.clear()
	var core: Dictionary={}
	for space: Dictionary in world.layout.spaces:
		var identity:=str(space.id)
		if str(space.level)!=floor:continue
		if identity==floor+"_SERVICE_CORE":core=space.duplicate(true)
		if identity==floor+"_SERVICE_CORE" or identity in [floor+"_SERVICE_HALL",floor+"_SERVICE_HALL_SOUTH",floor+"_SERVICE_CROSSING",floor+"_SERVICE_RISER_BYPASS",floor+"_CORE_TO_SERVICE"]:_allowed.append(space.rect)
	if core.is_empty():return {}
	var bounds: Array=core.rect.duplicate()
	for rect: Array in _allowed:
		bounds=[minf(bounds[0],rect[0]),minf(bounds[1],rect[1]),maxf(bounds[2],rect[2]),maxf(bounds[3],rect[3])]
	core.rect=bounds
	return core

func _connection(floor: String) -> Dictionary:
	for section: String in ["doors","openings"]:
		for row: Dictionary in world.layout[section]:
			if str(row.level)==floor and floor+"_SERVICE_HALL" in row.get("connects",[]) and floor+"_SERVICE_CORE" in row.get("connects",[]):
				var result: Dictionary=row.duplicate(true);result["is_door"]=section=="doors";return result
	return {}

func _stair_points(stair: Dictionary) -> Array[Vector3]:
	var x:=float(stair.origin[0]);var z:=float(stair.origin[1]);var width:=float(stair.width)
	var half: MeshInstance3D=world.adapter.root.get_node(str(stair.id)+"/HalfLanding") as MeshInstance3D
	var box:=half.mesh.get_aabb()
	var turn_z:=half.position.z+box.end.z-PlayerController.BODY_RADIUS-.02
	var first:=x+width*.5;var second:=x+width*1.5+float(stair.gap)
	var base:=float(world.adapter.root.level_y[str(stair.from)])
	var middle:=base+float(stair.rise)*int(stair.risers_per_flight)
	var top:=float(world.adapter.root.level_y[str(stair.to)])
	return [Vector3(first,base,z-.7),Vector3(first,middle,turn_z),Vector3(second,middle,turn_z),Vector3(second,top,z+float(stair.landing_depth)-.4),Vector3(second,top,z-.7)]

func _probe_thresholds() -> void:
	# Diagnose the whole family before a first-floor failure can end the walk.
	# Remote physics queries do not reposition the avatar or grant played proof.
	for floor: String in ["F01","F02","F03","F04","F05","F06"]:
		_floor_y=float(world.adapter.root.level_y[floor]);_domain(floor)
		var edge:=_connection(floor)
		if edge.is_empty():threshold_preflight.append({"level":floor,"missing_edge":true});continue
		for side: float in [-.55,.55]:
			_blocked.clear()
			var point:=Vector2(float(edge.center[0])+side,float(edge.center[1]))
			var height:=_ground(point)
			threshold_preflight.append({"id":str(edge.id),"level":floor,"side":"hall" if side<0 else "core","position":[point.x,_floor_y,point.y],"supported_clear_capsule":not is_nan(height),"obstructions":_blocked.duplicate(true)})
		await get_tree().process_frame

func _route() -> void:
	await _probe_thresholds()
	var floors: Array[String]=["B1","F01","F02","F03","F04","F05","F06","ROOF"]
	var stairs: Array[Dictionary]=[]
	for index in floors.size():
		var floor: String=floors[index];_floor_y=float(world.adapter.root.level_y[floor])
		print("SERVICE WALK FLOOR: ",floor," actual=",world.adapter.root.to_local(player.global_position))
		var domain:=_domain(floor)
		if not _require(not domain.is_empty(),"authored service core: "+floor):return
		if index>0 and index<floors.size()-1:
			var edge:=_connection(floor)
			if not _require(not edge.is_empty(),"actual direct hall/core threshold: "+floor):return
			var centre: Array=edge.center
			var core_stance:=Vector3(float(centre[0])+.55,_floor_y,float(centre[1]))
			var hall_stance:=Vector3(float(centre[0])-.55,_floor_y,float(centre[1]))
			if not await _floor_walk(domain,core_stance):return
			if edge.is_door and not await _door(edge):return
			if not await _floor_walk(domain,core_stance):return
			var before:=trace.size()-1
			if not await _floor_walk(domain,hall_stance):return
			crossings.append({"id":str(edge.id),"level":floor,"from":floor+"_SERVICE_CORE","to":floor+"_SERVICE_HALL","before_index":before,"after_index":trace.size()-1,"door_input":_last_door_input.duplicate(true) if edge.is_door else {}})
			if not await _floor_walk(domain,Vector3(8.9,_floor_y,8.3)):return
			if floor in ["F01","F02"]:
				if not await _floor_walk(domain,Vector3(7.7,_floor_y,1.5 if floor=="F01" else 1.45)):return
				if not await _capture_standing(floor+"_riser_bypass",Vector3(8.9,_floor_y+1.2,1.5)):return
				if floor=="F02":
					for port: Dictionary in world.layout.wall_service_openings:
						if str(port.id)!="F02_SERVICE_BYPASS_HEAT_INNER_PORT":continue
						var b: Array=port.bounds
						if not await _capture_standing("F02_retained_pipe_port",Vector3((b[0]+b[3])*.5,(b[1]+b[4])*.5,(b[2]+b[5])*.5)):return
			for point: Vector3 in [Vector3(8.9,_floor_y,-3.25),Vector3(8.9,_floor_y,-8.3),hall_stance,core_stance]:
				if not await _floor_walk(domain,point):return
			# These narrow old stair approaches require returning the leaf to its
			# jamb before taking the first flight. Close it with the same hand input.
			if edge.is_door and not await _door(edge,false):return
		if index==floors.size()-1:break
		var stair: Dictionary={}
		for row: Dictionary in world.layout.stairs:
			if str(row.id)=="SERVICE_"+floor+"_"+floors[index+1]:stair=row;break
		if not _require(not stair.is_empty(),"actual service stair: "+floor):return
		var points:=_stair_points(stair)
		if not await _floor_walk(domain,points[0]):return
		for point: Vector3 in points.slice(1):
			if not await _walk(point):return
		stairs.append(stair)
	# Reverse the same physical flights; do not replace descent with a fixture.
	stairs.reverse()
	for stair: Dictionary in stairs:
		_floor_y=float(world.adapter.root.level_y[str(stair.to)])
		var domain:=_domain(str(stair.to));var points:=_stair_points(stair)
		if not await _floor_walk(domain,points[-1]):return
		points.reverse()
		for point: Vector3 in points.slice(1):
			if not await _walk(point):return
	print("SERVICE FLOOR QUERIES: ",_grid_builds," built, ",_grid_reuses," reused; all segments walked")
