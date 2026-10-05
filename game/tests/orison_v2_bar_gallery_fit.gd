extends "res://tests/orison_v2_city_sweep.gd"
## Reproducible source fit through the shared picture law and actual collision.
var fit_world: OrisonV2RuntimeRoot
var fit_bar: OrisonV2BarRegion
var excluded: Array[RID]=[]
var piece_half:=Vector2.ZERO
var datum:=0.
var active_picture:=""
var inspected_ids: Array=[]

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	fit_world=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(fit_world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not fit_world.startup_failed,"gallery fitting uses the actual composed bar")
	fit_bar=fit_world.bar_region
	fit_world.player.set_physics_process(false)
	var ctx:=preload("res://scripts/building/orison_v2_bar_gallery.gd").context(fit_bar.source_layout)
	check(not ctx.is_empty(),"gallery fit derives its datum and room from retained stocks")
	var floor: Dictionary=ctx.floor
	var pictures: Array=floor.furniture.filter(func(row):return str(row.id).begins_with("retail_bar_gal"))
	var room: Dictionary=ctx.room;var proxy: Dictionary=ctx.proxy
	var lowest: float=ctx.lowest;var highest: float=ctx.highest
	datum=ctx.datum
	for wall: String in ["north","west"]:WallArtLaw._reserved.erase(str(room.id)+":"+wall)
	var installed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/building/orison_v2_bar_gallery.gd").DATA))
	for record: Dictionary in installed.inspectors:inspected_ids.append(str(record.picture))
	for body: CollisionObject3D in fit_world.find_children("*","CollisionObject3D",true,false):
		if body is Area3D or body==fit_world.player or "furniture_wood_dark" in str(body.get_path()) or "/BarGallery/" in str(body.get_path()):excluded.append(body.get_rid())
		elif body is InspectableZone and str(body.name).begins_with("BAR_PIC_"):excluded.append(body.get_rid())
	pictures.sort_custom(func(a,b):
		var aw:=maxf(float(a.rect[2])-float(a.rect[0]),float(a.rect[3])-float(a.rect[1]))
		var bw:=maxf(float(b.rect[2])-float(b.rect[0]),float(b.rect[3])-float(b.rect[1]))
		if not is_equal_approx(aw,bw):return aw>bw
		return float(a.h)>float(b.h) if float(a.h)!=float(b.h) else str(a.id)<str(b.id))
	var poses: Array=[]
	for row: Dictionary in pictures:
		active_picture=str(row.id)
		var r: Array=row.rect;var north:=float(r[2])-float(r[0])>float(r[3])-float(r[1])
		var wall:="north" if north else "west"
		var centre:=(float(r[0])+float(r[2]))*.5 if north else (float(r[1])+float(r[3]))*.5
		var along:=(centre-float(room.rect[0]))/(float(room.rect[2])-float(room.rect[0])) if north else (centre-float(room.rect[1]))/(float(room.rect[3])-float(room.rect[1]))
		piece_half=Vector2((float(r[2])-float(r[0]))*.5 if north else (float(r[3])-float(r[1]))*.5,float(row.h)*.5)
		var wanted:=float(row.z0)+piece_half.y-datum
		var pose: Dictionary={}
		# Try the two clear edges of the existing dado-to-ceiling band first.
		# Mid-band greedy seats can deny the second row despite free wall area.
		var deltas: Array[float]=[highest-piece_half.y-wanted,lowest+piece_half.y-wanted,0.]
		if north:deltas=[0.,highest-piece_half.y-wanted,lowest+piece_half.y-wanted]
		for step in range(1,19):deltas.append(step*.04);deltas.append(-step*.04)
		for delta: float in deltas:
			var height:=wanted+delta
			if height-piece_half.y<lowest or height+piece_half.y>highest:continue
			# Keep each picture on its authored wall; the law can choose another
			# along position there, while real geometry supplies the blocker.
			var local_proxy:=proxy.duplicate(true)
			local_proxy.walls=proxy.walls.filter(func(w):return str(w.id).ends_with("_n" if north else "_w"))
			var alongs: Array[float]=[along]
			for step in range(1,51):
				alongs.append(clampf(along+step*.02,0.02,.98));alongs.append(clampf(along-step*.02,.02,.98))
			for position: float in alongs:
				pose=WallArtLaw.legal_spot(local_proxy,room,wall,position,height,_physical_blocker,piece_half.x,piece_half.y)
				if bool(pose.get("ok",false)):break
			if bool(pose.get("ok",false)):break
		if not bool(pose.get("ok",false)):print("GALLERY LAW NO FIT ",row.id);poses.append({"id":row.id,"ok":false});continue
		check(str(pose.wall)==wall,"law retains the authored gallery wall")
		pose["id"]=row.id;pose["source"]=row;pose["height"]+=datum
		poses.append(pose)
	var output:=OS.get_environment("BAR_GALLERY_FIT_OUT")
	if output.is_empty():output=ProjectSettings.globalize_path("res://../tmp/bar-gallery/law-probe.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"source fit output can be written")
	if file==null:fit_world.shutdown_for_tests();fit_world.free();get_tree().quit(1);return
	file.store_string(JSON.stringify({"evidence_class":"INERT","poses":poses,"checks":checks,"failures":failures},"\t"))
	file.close()
	var fitted:=poses.filter(func(row):return bool(row.get("ok",false))).size()
	check(fitted==22,"all original pictures obtain lawful positions outside the nested WC")
	print("BAR GALLERY FIT: fitted=",fitted," of ",poses.size()," failures=",failures.size())
	fit_world.shutdown_for_tests();fit_world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _physical_blocker(x: float,y: float,yaw: float,height: float) -> bool:
	var box:=BoxShape3D.new();box.size=Vector3(piece_half.x*2.,piece_half.y*2.,.0495)
	var basis:=Basis(Vector3.UP,yaw)
	var centre:=GameBoot.b2g([x,y,height+datum])-basis.z*.02475
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=1
	query.transform=Transform3D(fit_bar.global_basis*basis,fit_bar.to_global(centre));query.exclude=excluded
	if not fit_world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return true
	if active_picture not in inspected_ids:return false
	var target:=GameBoot.b2g([x,y,height+datum])+basis.z*.020
	for distance: float in [1.1,1.4,1.7,2.,2.3,2.6]:
		for lateral: float in [0.,-.3,.3,-.6,.6,-.9,.9]:
			var feet:=target+basis.z*distance+basis.x*lateral;feet.y=datum+.025
			if not _city_clear_station(fit_world,fit_bar.to_global(feet)):continue
			var start:=fit_bar.to_global(feet)+Vector3.UP*1.6;var end:=fit_bar.to_global(target)
			if start.distance_to(end)>=3.:continue
			var ray:=PhysicsRayQueryParameters3D.create(start,end,1,excluded)
			if fit_world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	return true
