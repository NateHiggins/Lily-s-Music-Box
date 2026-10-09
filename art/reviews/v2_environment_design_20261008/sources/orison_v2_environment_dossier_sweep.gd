extends "res://tests/orison_v2_city_sweep.gd"
## Environment-design dossier capture. Teleported inspection stations only.
## Per semantic space: an overview (OV) from the clear station farthest from
## the room centre, a reverse view (RV) from the clear station farthest from
## the overview, a threshold view (TH) from just outside the principal door or
## opening, and up to DOSSIER_DETAILS detail views (DT) toward authored
## anchors, windows or doors. DOSSIER_CITY=1 adds the city sweep's shop, bar,
## floor-survey and street stations plus bodega, alley, facade and subway views.
## Production fixtures stay as authored, the player lamp is on, the carried set
## and HUD are hidden and campaign time is frozen at 20:00. Discovery only:
## a clear sample proves no route, lock, access or fabrication acceptance.
var dossier: Array[Dictionary]=[]
var _world: OrisonV2RuntimeRoot
var _dir: String
var _nodes_by_space: Dictionary={}
var _node_census: Array[Dictionary]=[]

const DETAIL_SCORES := {
	"story":12,"desk":10,"workbench":10,"bench":9,"din_t":9,"terminal":10,"table":8,
	"sofa":8,"couch":8,"bed0":8,"bed1":8,"abed":8,"bed":7,"shelf":7,"bookshelf":7,
	"toolboard":8,"pinboard":7,"crate":7,"radio":7,"stove":7,"sink":6,"fridge":6,
	"wardrobe":6,"deck":6,"projector":5,"cabinet":5,"cupboard":5,"lamp":5,"stool":4,
	"radiator":4,"mirror":4,"ns":3,"dc":2,"chair":2,"stand":3,"boiler":10,"washer":9,
	"airer":8,"tub":7,"panel":8,"register":7,"detector":8,"board":7,"dumbwaiter":8,
	"tank":8,"fan":6,"vent":4,"switch":-5,"lt_":-5,"light":-5}

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world);_world=world
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"dossier production world initializes")
	if world.player==null or world.startup_failed:world.free();get_tree().quit(1);return
	_dir=OS.get_environment("SHOT_DIR")
	check(not _dir.is_empty(),"dossier sweep requires SHOT_DIR")
	if _dir.is_empty():world.shutdown_for_tests();world.free();get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(_dir)
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(true)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	var levels:=Array(OS.get_environment("DOSSIER_LEVELS").split(",",false))
	var only:=Array(OS.get_environment("DOSSIER_SPACES").split(",",false))
	var details:=3
	if not OS.get_environment("DOSSIER_DETAILS").is_empty():details=int(OS.get_environment("DOSSIER_DETAILS"))
	await _settled_optics()
	_census()
	for record: Dictionary in world.layout.spaces:
		if not levels.is_empty() and not levels.has(str(record.level)):continue
		if not only.is_empty() and not only.has(str(record.id)):continue
		await _space(record,details)
		_write()
	if OS.get_environment("DOSSIER_CITY")=="1":
		await _city()
		_write()
	print("DOSSIER SWEEP COMPLETE: spaces=%d city=%d failures=%d" % [dossier.size(),discovery.size(),failures.size()])
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

## Runtime census: every scripted Node3D (props, zones, instruments, doors) with
## its root-local position and the semantic space whose rect contains it on
## its level. Public rooms furnish from scripts, not blockout anchors, so this
## is the only per-room inventory they have. Residents, lights, cameras and the
## player are excluded. INERT: it says what is instantiated, not what is right.
func _census() -> void:
	var root: Node3D=_world.adapter.root
	var levels: Array=_world.layout.levels
	for node: Node in _world.find_children("*","Node3D",true,false):
		if node.get_script()==null or node is AnimatedResident or node is PlayerController or node is LightFixtureProp or node is Camera3D or node is Light3D:continue
		var script_path:=str(node.get_script().resource_path)
		if not (script_path.contains("/props/") or script_path.contains("/building/") or script_path.contains("/activities/") or script_path.contains("/characters/")):continue
		if node is AnimatedResident:continue
		var local:=root.to_local((node as Node3D).global_position)
		var level:=""
		for entry: Dictionary in levels:
			# A ceiling fixture at y 2.9 on F01 belongs to F01 (y 0), not F02 (y 3.2):
			# the level is the highest datum at or below the node (the runs of
			# 2026-10-08 used a -0.3 tolerance and occasionally targeted a
			# lower floor's ceiling fixture from the floor above; captions name it).
			if float(entry.y)<=local.y+.05:level=str(entry.id)
		var space:=""
		for record: Dictionary in _world.layout.spaces:
			if str(record.level)!=level:continue
			var r: Array=record.rect
			if local.x>=float(r[0])-.05 and local.x<=float(r[2])+.05 and local.z>=float(r[1])-.05 and local.z<=float(r[3])+.05:space=str(record.id);break
		var row:={"name":str(node.name),"script":script_path.get_file(),"path":str(_world.get_path_to(node)),"position":[local.x,local.y,local.z],"level":level,"space":space}
		_node_census.append(row)
		if not space.is_empty():
			if not _nodes_by_space.has(space):_nodes_by_space[space]=[]
			(_nodes_by_space[space] as Array).append(row)
	var file:=FileAccess.open(_dir.path_join("node_census.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","interpretation":"Scripted Node3D instances by containing semantic space at capture time; residents, lights and the player excluded. Inventory, not acceptance.","nodes":_node_census},"\t"))
	print("DOSSIER CENSUS: nodes=",_node_census.size()," spaces_with_nodes=",_nodes_by_space.size())

func _open_leaf(portal_id: String) -> Dictionary:
	var leaf: DoorProp=null
	var anchor: Node=_world.adapter.resolve(portal_id)
	if anchor!=null:leaf=anchor.get_node_or_null(portal_id+"_Leaf") as DoorProp
	if leaf==null:leaf=_world.find_child(portal_id+"_Leaf",true,false) as DoorProp
	if leaf==null:return {"leaf":null,"opened":false,"state":"no leaf owner (opening or unresolved door)"}
	if leaf.leaf_state=="locked":return {"leaf":leaf,"opened":false,"state":"locked"}
	if leaf.open:return {"leaf":leaf,"opened":false,"state":"already open"}
	leaf.interact(null)
	for frame in 90:
		await get_tree().physics_frame
		if not leaf._moving:break
	return {"leaf":leaf,"opened":leaf.open,"state":"opened for the view" if leaf.open else "did not open"}

func _close_leaf(leaf: DoorProp) -> void:
	if leaf==null or not leaf.open:return
	leaf.interact(null)
	for frame in 90:
		await get_tree().physics_frame
		if not leaf._moving:break

func _write() -> void:
	var file:=FileAccess.open(_dir.path_join("dossier_sweep.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","schema":"orison.environment-dossier-sweep.v1","interpretation":"Teleported inspection stations under production lighting with the player lamp on, carried set hidden and campaign time frozen at 1928-11-10 20:00. Geometry, textures, routes and access require review; nothing here is acceptance.","spaces":dossier,"city":discovery,"failures":failures},"\t"))

func _space(record: Dictionary,details: int) -> void:
	var root: Node3D=_world.adapter.root
	var rect: Array=record.rect
	var level:=str(record.level)
	var floor_y: float=root.level_y[level]
	var cx:=(float(rect[0])+float(rect[2]))*.5;var cz:=(float(rect[1])+float(rect[3]))*.5
	var center:=Vector3(cx,floor_y+1.0,cz)
	var candidates: Array[Vector3]=[]
	for u in [.12,.3,.5,.7,.88]:
		for v in [.12,.3,.5,.7,.88]:
			var at:=Vector3(lerpf(float(rect[0]),float(rect[2]),u),floor_y+.03,lerpf(float(rect[1]),float(rect[3]),v))
			var fitted: Variant=_surface_station(at)
			if fitted!=null:candidates.append(fitted)
	var entry:={"id":str(record.id),"level":level,"class":str(record.get("class","")),"purpose":str(record.get("purpose","")),"rect":[float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])],"floor_y":floor_y,"clear_stations":candidates.size(),"captures":[],"status":"uninspected"}
	if candidates.is_empty():
		entry["status"]="no_clear_sampled_station_requires_review"
	else:
		var ov: Vector3=candidates[0]
		for c: Vector3 in candidates:
			if Vector2(c.x-cx,c.z-cz).length_squared()>Vector2(ov.x-cx,ov.z-cz).length_squared():ov=c
		var rv: Vector3=candidates[0]
		for c: Vector3 in candidates:
			if c.distance_squared_to(ov)>rv.distance_squared_to(ov):rv=c
		await _station(entry,ov,center,"OV","overview","room centre")
		if rv.distance_to(ov)>.5:await _station(entry,rv,center,"RV","reverse","room centre")
		var threshold:=_threshold(record,floor_y,Vector3(cx,floor_y,cz))
		if not threshold.is_empty():
			var leaf_state:=await _open_leaf(str(threshold.owner))
			await _station(entry,threshold.feet,Vector3(cx,floor_y+1.2,cz),"TH","threshold",str(threshold.owner))
			entry["threshold_outside"]=threshold.outside
			entry["threshold_door"]=str(leaf_state.state)
			if bool(leaf_state.opened):await _close_leaf(leaf_state.leaf as DoorProp)
		var index:=1
		for target: Dictionary in _detail_targets(record,floor_y,details):
			var feet:=_detail_station(candidates,target.position)
			if not feet.is_finite():
				entry.captures.append({"kind":"detail","owner":str(target.owner),"status":"no_clear_station_with_sight"})
				continue
			await _station(entry,feet,target.position,"DT"+str(index),"detail",str(target.owner))
			index+=1
		entry["status"]="captured_pending_visual_review"
	dossier.append(entry)
	print("DOSSIER SPACE: ",record.id," ",entry.status," captures=",entry.captures.size())

func _station(entry: Dictionary,feet: Vector3,target: Vector3,suffix: String,kind: String,owner: String) -> void:
	var root: Node3D=_world.adapter.root
	var at:=root.to_global(feet);var look:=root.to_global(target)
	if Vector2(look.x-at.x,look.z-at.z).length()<.25:look.z+=.7
	_world.player.global_position=at;_world.player.velocity=Vector3.ZERO
	_world.player.face_world_point(look)
	await get_tree().physics_frame
	await get_tree().create_timer(.6).timeout
	var label:=str(entry.id)+"_"+suffix
	await shot(label)
	var cam: Camera3D=_world.player.camera
	var forward:=-cam.global_basis.z
	entry.captures.append({"image":label+".png","kind":kind,"owner":owner,"feet":[feet.x,feet.y,feet.z],"target":[target.x,target.y,target.z],"eye":[cam.global_position.x,cam.global_position.y,cam.global_position.z],"forward":[forward.x,forward.y,forward.z],"device_hidden":true,"lamp":true,"status":"captured_pending_visual_review"})

func _surface_station(local: Vector3) -> Variant:
	var root: Node3D=_world.adapter.root
	var ray:=PhysicsRayQueryParameters3D.create(root.to_global(local+Vector3.UP*.35),root.to_global(local-Vector3.UP*.12),1,[_world.player.get_rid()])
	var hit: Dictionary=_world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(root.global_basis.y)<=.9:return null
	var feet: Vector3=root.to_local(hit.position)+Vector3.UP*.03
	var shape:=CapsuleShape3D.new()
	shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.collision_mask=1
	query.transform=Transform3D(root.global_basis,root.to_global(feet+Vector3.UP*(PlayerController.STANDING_HEIGHT*.5)))
	query.exclude=[_world.player.get_rid()]
	if not _world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return null
	return feet

func _threshold(record: Dictionary,floor_y: float,center: Vector3) -> Dictionary:
	var identity:=str(record.id)
	var portals: Array[Dictionary]=[]
	for door: Dictionary in _world.layout.doors:
		if not (door.connects as Array).has(identity):continue
		var yaw:=float(door.get("yaw",0.0))
		portals.append({"id":str(door.id),"center":door.center,"normal":Vector3(sin(yaw),0,cos(yaw)),"other":_other(door.connects,identity),"door":true})
	for opening: Dictionary in _world.layout.openings:
		if not (opening.connects as Array).has(identity):continue
		var normal:=Vector3(0,0,1) if str(opening.get("axis","x"))=="x" else Vector3(1,0,0)
		portals.append({"id":str(opening.id),"center":opening.center,"normal":normal,"other":_other(opening.connects,identity),"door":false})
	if portals.is_empty():return {}
	# Prefer the portal a player arrives through: a public or core neighbour,
	# then any hall, then a door before an opening.
	portals.sort_custom(func(a,b):return _portal_rank(a)>_portal_rank(b))
	for portal: Dictionary in portals:
		var c: Array=portal.center
		var at:=Vector3(float(c[0]),floor_y,float(c[1]))
		var normal: Vector3=portal.normal
		var outward:=normal*(1.0 if normal.dot(at-center)>=0.0 else -1.0)
		for distance: float in [1.0,.75,1.3,-.7]:
			var probe:=at+outward*distance+Vector3.UP*.03
			var fitted: Variant=_surface_station(probe)
			if fitted!=null:return {"feet":fitted,"owner":str(portal.id),"outside":distance>0.0}
	return {}

func _other(connects: Array,identity: String) -> String:
	for other in connects:
		if str(other)!=identity:return str(other)
	return ""

func _portal_rank(portal: Dictionary) -> int:
	var other:=str(portal.other)
	var rank:=0
	for space: Dictionary in _world.layout.spaces:
		if str(space.id)!=other:continue
		var cls:=str(space.get("class",""))
		if cls=="public":rank+=40
		elif cls=="core":rank+=30
		elif cls=="service":rank+=20
		elif cls=="private" and (other.contains("HALL") or other.contains("VESTIBULE")):rank+=15
		break
	if portal.door:rank+=5
	return rank

func _family(identity: String) -> String:
	var name:=identity.to_lower()
	var parts:=name.split("_",false)
	if parts.size()>1 and parts[0].length()<=3:parts.remove_at(0)
	var family:="_".join(parts)
	while family.length()>0 and family[family.length()-1].is_valid_int():family=family.left(family.length()-1)
	return family

func _detail_targets(record: Dictionary,floor_y: float,limit: int) -> Array[Dictionary]:
	var identity:=str(record.id)
	var scored: Array[Dictionary]=[]
	for anchor: Dictionary in _world.layout.anchors:
		if str(anchor.get("space",""))!=identity or str(anchor.get("kind",""))=="clearance":continue
		var name:=str(anchor.id).to_lower()
		var score:=0
		for key: String in DETAIL_SCORES:
			if name.contains(key):score=maxi(score,int(DETAIL_SCORES[key])) if int(DETAIL_SCORES[key])>0 else score+int(DETAIL_SCORES[key])
		if str(anchor.kind)=="interaction":score+=1
		var p: Array=anchor.position
		var lift:=0.9 if float(p[1])<.3 else 0.0
		scored.append({"owner":str(anchor.id),"family":_family(str(anchor.id)),"score":score,"position":Vector3(float(p[0]),floor_y+float(p[1])+lift,float(p[2]))})
	scored.sort_custom(func(a,b):return a.score>b.score)
	var chosen: Array[Dictionary]=[]
	var families: Array[String]=[]
	for candidate: Dictionary in scored:
		if chosen.size()>=limit:break
		if candidate.score<0 or families.has(candidate.family):continue
		families.append(candidate.family);chosen.append(candidate)
	if chosen.size()<limit and _nodes_by_space.has(identity):
		var seen: Array[String]=[]
		for row: Dictionary in _nodes_by_space[identity]:
			if chosen.size()>=limit:break
			var script:=str(row.script)
			if script.contains("door") or script.contains("switch") or script.contains("vantry_point") or seen.has(script):continue
			var already:=false
			for c: Dictionary in chosen:
				if str(c.owner)==str(row.name):already=true
			if already:continue
			seen.append(script)
			var p: Array=row.position
			chosen.append({"owner":str(row.name),"family":script,"score":2,"position":Vector3(float(p[0]),maxf(float(p[1]),floor_y+.6)+.3,float(p[2]))})
	if chosen.size()<limit:
		for window: Dictionary in _world.layout.windows:
			if chosen.size()>=limit:break
			if str(window.get("space",""))!=identity:continue
			var c: Array=window.center
			chosen.append({"owner":str(window.id),"family":"window","score":1,"position":Vector3(float(c[0]),floor_y+float(window.get("sill",.75))+float(window.get("height",1.5))*.5,float(c[1]))})
	if chosen.size()<limit:
		for door: Dictionary in _world.layout.doors:
			if chosen.size()>=limit:break
			if not (door.connects as Array).has(identity):continue
			var c: Array=door.center
			chosen.append({"owner":str(door.id),"family":"door","score":1,"position":Vector3(float(c[0]),floor_y+1.0,float(c[1]))})
	return chosen

func _detail_station(candidates: Array[Vector3],target: Vector3) -> Vector3:
	var root: Node3D=_world.adapter.root
	var best:=Vector3.INF;var best_cost:=INF
	for feet: Vector3 in candidates:
		var distance:=Vector2(feet.x-target.x,feet.z-target.z).length()
		if distance<.8 or distance>4.5:continue
		var eye:=root.to_global(feet+Vector3.UP*PlayerController.STANDING_EYE)
		var ray:=PhysicsRayQueryParameters3D.create(eye,root.to_global(target),1,[_world.player.get_rid()])
		var hit: Dictionary=_world.get_world_3d().direct_space_state.intersect_ray(ray)
		var blocked:=not hit.is_empty() and (hit.position as Vector3).distance_to(root.to_global(target))>.7
		var cost:=absf(distance-1.9)+(3.0 if blocked else 0.0)
		if cost<best_cost:best_cost=cost;best=feet
	return best

func _city() -> void:
	var world:=_world
	var vestibule: Dictionary=world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var r: Array=vestibule.rect
	world.player.global_position=world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,0.,(r[1]+r[3])*.5))
	await get_tree().physics_frame;await get_tree().physics_frame
	var passage: OrisonV2PassageRegion=world.passage_region
	for frame in 600:
		if passage.residency.state=="RESIDENT":break
		await get_tree().process_frame
	check(passage.residency.state=="RESIDENT","normal prefetch exposes the actual arcade geometry")
	var floor: Dictionary=passage.source_layout.floors.filter(func(row):return row.id=="F01")[0]
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/floor_01_cell_registry.json"))
	for identity: String in passage.CELLS:
		if identity=="passage":continue
		var cell: Dictionary=registry.cells.filter(func(row):return str(row.resource_path).get_file()==identity+".gltf")[0]
		var sources: Array[Dictionary]=[]
		for marker: Dictionary in floor.markers:
			if marker.id in cell.semantic_owners and str(marker.id).begins_with("SITE_SHOP_IN"):sources.append(marker)
		for source: Dictionary in sources:
			var local:=GameBoot.b2g(source.pos);local.y=.03
			var target:=GameBoot.b2g(sources[-1].pos);target.y=.8
			if Vector2(local.x-target.x,local.z-target.z).length()<.25:target=GameBoot.b2g(sources[0].pos);target.y=.8
			await _city_inspect(world,passage,local,target,identity+"_"+str(source.id),"arcade shop",str(source.id))
	var bar_floor: float=floor.markers.filter(func(row):return row.id=="F01_BAR_WC_DOOR")[0].pos[2]
	for marker: Dictionary in floor.markers:
		if not str(marker.id).begins_with("F01_BAR_LT_") and marker.id!="F01_BAR_WC_SINK_01":continue
		var local:=GameBoot.b2g(marker.pos);local.y=bar_floor+.03
		var target:=GameBoot.b2g(floor.markers.filter(func(row):return row.id=="F01_BAR_POOL")[0].pos);target.y=bar_floor+.8
		if Vector2(local.x-target.x,local.z-target.z).length()<.25:target.x+=1.
		await _city_inspect(world,world.bar_region,local,target,"bar_"+str(marker.id),"bar",str(marker.id))
	for record: Dictionary in floor.furniture:
		if not str(record.id).ends_with("_floor"):continue
		var identity: String=str(record.get("batch",""))
		if identity=="shop_otis___son":identity="shop_otis_son"
		var frame: Node3D=passage if identity in passage.CELLS else null
		if str(record.id).begins_with("retail_bar_"):frame=world.bar_region
		if frame==null:continue
		var rect: Array=record.rect
		var height: float=float(record.z0)+float(record.h)
		var candidates: Array[Vector3]=[]
		for u in [.16,.33,.5,.67,.84]:
			for v in [.16,.33,.5,.67,.84]:
				var point:=GameBoot.b2g([lerpf(rect[0],rect[2],u),lerpf(rect[1],rect[3],v),height+.03])
				if _city_clear_station(world,frame.to_global(point)):candidates.append(point)
		if candidates.is_empty():
			discovery.append({"id":record.id,"owner":record.id,"bucket":"floor survey","status":"no_clear_sampled_station_requires_review"});continue
		var first: Vector3=candidates[0];var last:=first
		for point: Vector3 in candidates:
			if point.distance_squared_to(first)>last.distance_squared_to(first):last=point
		var center:=GameBoot.b2g([(rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,height+.8])
		var station:=0
		for point: Vector3 in [first,last]:
			var target:=center
			if Vector2(point.x-target.x,point.z-target.z).length()<.25:target.z+=.7
			await _city_capture(world,frame.to_global(point),frame.to_global(target),str(record.id)+"_"+str(station),"floor survey",str(record.id));station+=1
	for route_id: String in ["ROUTE_ORISON_TO_SHOP_BODEGA","ROUTE_SHOP_BODEGA_TO_ORISON"]:
		var route: Dictionary=world.exterior_cell.route(route_id)
		if route.is_empty():continue
		for index in route.nodes.size()-1:
			var node: Dictionary=route.nodes[index];var at: Vector3=node.placement.position
			var target: Vector3=route.nodes[index+1].placement.position
			await _city_capture(world,at,target+Vector3.UP*.8,route_id.to_lower()+"_"+str(index),"street",str(node.id))
	var shop: Node3D=world.exterior_cell.instance_node("SHOP_BODEGA")
	if shop!=null:
		for view: Array in [["aisles",Vector3(0,0,-3.6),Vector3(0,1,-6)],["stock",Vector3(-.12,0,-5),Vector3(-.75,1.15,-5.8)],["counter",Vector3(.2,0,-1),Vector3(-1.25,.63,-1.8)],["cooler",Vector3(.3,0,-7),Vector3(1.25,1,-8.1)],["window_stock",Vector3(0,0,-1.8),Vector3(-1.3,1.02,-.33)],["delivery",Vector3(.5,0,-8.7),Vector3(-.75,.7,-9.4)],["door_back",Vector3(0,0,-6.5),Vector3(0,1.2,0)]]:
			var at:=shop.to_global(view[1]+Vector3.UP*.02)
			if not _city_clear_station(world,at):
				discovery.append({"id":"bodega_"+str(view[0]),"bucket":"bodega","owner":"SHOP_BODEGA","status":"no_clear_sampled_station_requires_review"});continue
			await _city_capture(world,at,shop.to_global(view[2]),"bodega_"+str(view[0]),"bodega","SHOP_BODEGA")
	else:check(false,"bodega instance node exists for dossier views")
	var root: Node3D=world.adapter.root
	var index:=0
	for point: Vector3 in [Vector3(8.9,0,10.7),Vector3(8.9,0,13),Vector3(16.8,0,13),Vector3(16.8,0,8),Vector3(16.8,0,2),Vector3(16.8,0,-5),Vector3(16.8,0,-10.8),Vector3(16.8,0,-13.8)]:
		var at:=root.to_global(point+Vector3.UP*.03)
		var label:="alley_"+str(index);index+=1
		if not _city_clear_station(world,at):
			discovery.append({"id":label,"bucket":"alley","owner":"F01_REAR_SERVICE_DOOR route","status":"no_clear_sampled_station_requires_review"});continue
		await _city_capture(world,at,root.to_global(point+Vector3(0,1.3,-3)),label,"alley","service alley walk")
		if index==2 or index==5:
			await _city_capture(world,at,root.to_global(point+Vector3(0,1.3,3)),label+"_back","alley","service alley walk (reverse)")
	var blade: Node3D=world.find_child("F01_NEON_BLADE",true,false) as Node3D
	for view: Array in [["front",Vector3(0,1.43,6),Vector3(0,2.7,0)],["approach",Vector3(3,1.43,4),Vector3(0,2.7,0)],["door",Vector3(.45,1.43,1.55),Vector3(0,1.6,0)],["canopy",Vector3(1.5,1.43,2.8),Vector3(0,3.1,.4)],["front_wide",Vector3(0,1.43,11),Vector3(0,6,0)],["street_west",Vector3(-6,1.43,5),Vector3(6,2.5,0)],["street_east",Vector3(7,1.43,5),Vector3(-6,2.5,0)]]:
		var feet: Vector3=view[1]-Vector3.UP*PlayerController.STANDING_EYE
		var ground:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.35,feet-Vector3.UP*.4,1,[world.player.get_rid()])
		var support: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ground)
		if support.is_empty():
			discovery.append({"id":"facade_"+str(view[0]),"bucket":"facade","owner":"front pavement","status":"no_clear_sampled_station_requires_review"});continue
		feet=support.position+Vector3.UP*.02
		if not _city_clear_station(world,feet):
			discovery.append({"id":"facade_"+str(view[0]),"bucket":"facade","owner":"front pavement","status":"no_clear_sampled_station_requires_review"});continue
		await _city_capture(world,feet,view[2],"facade_"+str(view[0]),"facade","front pavement")
	if blade!=null:
		var feet:=Vector3(9,.02,4)
		if _city_clear_station(world,feet):await _city_capture(world,feet,blade.global_position+Vector3(0,0,.65),"facade_blade","facade","F01_NEON_BLADE")
	for probe: Vector3 in [Vector3(8,.03,9),Vector3(9,.03,10),Vector3(7,.03,11),Vector3(10,.03,8)]:
		if _city_clear_station(world,probe):
			await _city_capture(world,probe,Vector3(7.5,1.7,17.5),"subway_approach","subway","subway/arcade relationship");break
