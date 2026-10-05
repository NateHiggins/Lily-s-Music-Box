extends "res://tests/orison_v2_city_sweep.gd"
## Actual wall/backing contacts, catalogue/atlas bindings and retained verbs.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.bar_region.startup_failed,"native gallery composes in the connected V2 city")
	if world.startup_failed or world.bar_region.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var bar: OrisonV2BarRegion=world.bar_region;var cell:=bar.get_node("RetainedBarGeometry") as Node3D;var model:=cell.get_node("BarGallery") as Node3D
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_gallery.json"))
	check(FileAccess.get_sha256("res://assets/props/bar_gallery.glb")==fixture.asset_sha256,"delivered native matches the independently inspectable fixture")
	var owners: Dictionary=model.get_meta("original_owners");var originals: Dictionary=model.get_meta("original_meshes")
	for key: String in owners:
		check(not owners[key].visible and owners[key].mesh==originals[key],"original source partition remains intact and retired: "+key)
		for shape: CollisionShape3D in owners[key].find_children("*","CollisionShape3D",true,false):check(shape.disabled,"old frame collision has one replacement owner")
	var parts: Dictionary={};var excluded: Array[RID]=[world.player.get_rid()];var triangles:=0
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body is Area3D or model.is_ancestor_of(body) or (body is InspectableZone and str(body.name).begins_with("BAR_PIC_")):excluded.append(body.get_rid())
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name:=str(draw.get_meta("gallery_part"));var record: Dictionary=fixture.parts.filter(func(row):return str(row.name)==name)[0];parts[str(record.key)]=draw
		var faces:=draw.mesh.get_faces();triangles+=faces.size()/3
		check(faces.size()==int(record.triangles)*3,"native triangle count remains exact: "+name)
		var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(material!=null and not material.uv1_triplanar,"native charts have a local shipping material: "+name)
		check(material.uv1_scale.is_equal_approx(Vector3.ONE/float(record.tile)),"actual chart scale matches the catalogue: "+name)
		if str(record.key)=="art":
			var source:=originals.art.surface_get_material(0) as StandardMaterial3D
			check(material!=source and material.albedo_texture==source.albedo_texture and material.roughness_texture==source.roughness_texture and material.normal_texture==source.normal_texture,"original atlas and optical inputs reach every original artwork")
		else:
			_check_cap_mapping(draw.mesh,true)
			var source:=originals.wood_dark.surface_get_material(0) as StandardMaterial3D if str(record.key)=="wood_dark" else MatLib.get_mat(str(record.key))
			check(material!=source and material.albedo_texture==source.albedo_texture and material.roughness_texture==source.roughness_texture and material.normal_texture==source.normal_texture,"unchanged three-map family reaches the local chart: "+name)
		var shapes:=draw.find_children("*","CollisionShape3D",true,false)
		check(shapes.size()==(1 if bool(record.collision) else 0),"one intended physical owner per partition: "+name)
		if not shapes.is_empty():check((shapes[0].shape as ConcavePolygonShape3D).get_faces()==faces and shapes[0].global_transform.is_equal_approx(draw.global_transform),"visible and colliding native faces coincide: "+name)
	check(parts.size()==4,"all twenty-two works share four shipping partitions")
	var wood_faces: PackedVector3Array=parts.wood_dark.mesh.get_faces();var wall: MeshInstance3D
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		if str(draw.name).trim_suffix("-col")=="F01_OWN_SHOP_BAR_retail_bar_bar_wall":wall=draw
	check(wall!=null,"retained bar wall is the attachment authority")
	var wall_faces:=wall.mesh.get_faces();var samples:=0
	for contact: Dictionary in fixture.contacts:
		var at:=GameBoot.b2g(contact.bearing);var n:=GameBoot.b2g(contact.normal);var front:=GameBoot.b2g(contact.frame_back);var u:=Vector3.RIGHT if absf(n.z)>.9 else Vector3.BACK
		var packer:=BoxShape3D.new();packer.size=Vector3(float(contact.packer_width_m)-.0001,float(contact.packer_height_m)-.0001,float(contact.gap_m)-.0001)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=packer;query.exclude=excluded;query.collision_mask=1
		query.transform=Transform3D(bar.global_basis*Basis(Vector3.UP,0. if absf(n.z)>.9 else PI*.5),bar.to_global((at+front)*.5))
		var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hits.is_empty():print("GALLERY PACKER BLOCKER ",contact.picture," ",hits[0].collider.get_path())
		check(hits.is_empty(),"seated attachment packer clears other retained physical fabric: "+str(contact.picture))
		for du: float in [-.009,0.,.009]:
			for dz: float in [-.009,0.,.009]:
				var offset:=u*du+Vector3.UP*dz
				check(absf(_mesh_distance(wall_faces,at+n*.004+offset,-n)-.004)<.00003,"entire packer footprint bears on the actual retained wall")
				check(absf(_mesh_distance(wood_faces,at-n*.002+offset,n)-.002)<.00003,"native packer starts at the actual wall face")
				check(absf(_mesh_distance(wood_faces,front-n*.002+offset,n)-.002)<.00003,"native packer terminates against the frame backing")
				samples+=3
	var ctx:=preload("res://scripts/building/orison_v2_bar_gallery.gd").context(bar.source_layout)
	for picture: Dictionary in fixture.pictures:
		var r: Array=picture.source.rect;var width:=maxf(float(r[2])-float(r[0]),float(r[3])-float(r[1]));var height:=float(picture.source.h)
		var box:=BoxShape3D.new();box.size=Vector3(width,height,.0495);var basis:=Basis(Vector3.UP,float(picture.yaw))
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.exclude=excluded;query.collision_mask=1
		query.transform=Transform3D(bar.global_basis*basis,bar.to_global(GameBoot.b2g(picture.position)-basis.z*.02475))
		var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hits.is_empty():print("GALLERY FRAME BLOCKER ",picture.id," ",hits[0].collider.get_path())
		check(hits.is_empty(),"full installed frame clears retained physical fabric: "+str(picture.id))
		check(not WallArtLaw.nested_room_blocks(ctx.proxy,ctx.room,float(picture.position[0]),float(picture.position[1])),"picture belongs to the bar rather than its restroom")
	for record: Dictionary in fixture.original_inspectors:
		var zone:=bar.actors.get_node(str(record.zone)) as InspectableZone
		check(zone.title==str(record.original_title) and str(zone.get_meta("gallery_picture"))==str(record.picture),"original observation identity follows its own source frame")
		var first:=zone.interact(world.player);var second:=zone.interact(world.player)
		check(first.body==str(zone.lines[0]) and second.body==str(zone.lines[1]) and first.stamp=="OBSERVATION","original two readings remain functional")
		var normal:=zone.basis.z;var feet:=Vector3.ZERO;var clear:=false
		for distance: float in [1.1,1.4,1.7,2.,2.3,2.6]:
			for lateral: float in [0.,-.3,.3,-.6,.6,-.9,.9]:
				var candidate:=zone.position+normal*distance+zone.basis.x*lateral;candidate.y=float(ctx.datum)+.025
				if not _city_clear_station(world,bar.to_global(candidate)):continue
				var start:=bar.to_global(candidate)+Vector3.UP*1.6
				if start.distance_to(zone.global_position)>=3.:continue
				var ray:=PhysicsRayQueryParameters3D.create(start,zone.global_position,1,[world.player.get_rid()])
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.collider==zone:feet=candidate;clear=true;break
			if clear:break
		check(clear,"ordinary standing approach reaches the original picture observation")
		if clear:
			world.player.global_position=bar.to_global(feet);world.player.face_world_point(zone.global_position);world.player.set_lamp_enabled(true)
			await get_tree().physics_frame;await get_tree().physics_frame
			var start:=world.player.global_position+Vector3.UP*1.6
			var ray:=PhysicsRayQueryParameters3D.create(start,zone.global_position,1,[world.player.get_rid()])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider==zone and start.distance_to(zone.global_position)<3.,"real interaction ray reaches the fitted original observation")
			await _settled_optics();await shot(str(record.zone)+"_installed")
	await _gallery_views(world,bar)
	print("BAR GALLERY: checks=",checks," pictures=",fixture.pictures.size()," partitions=",parts.size()," triangles=",triangles," bearing_samples=",samples," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _gallery_views(world: OrisonV2RuntimeRoot,bar: OrisonV2BarRegion) -> void:
	for view: Array in [
		["west_south",Vector3(-10.2,-2.775,35.65),Vector3(-11.45,-1.05,35.5)],
		["west_darts",Vector3(-9.45,-2.775,32.65),Vector3(-11.45,-1.1,32.1)],
		["west_score",Vector3(-9.45,-2.775,30.65),Vector3(-11.45,-.95,31.15)],
		["north_east",Vector3(2.65,-2.775,31.0),Vector3(2.65,-.95,28.72)],
		["north_pool",Vector3(-8.7,-2.775,31.3),Vector3(-8.7,-.9,28.72)]]:
		var feet: Vector3=view[1];var clear:=false
		for offset: Vector3 in [Vector3.ZERO,Vector3(.5,0,0),Vector3(-.5,0,0),Vector3(0,0,.5),Vector3(0,0,-.5)]:
			if _city_clear_station(world,bar.to_global(feet+offset)):feet+=offset;clear=true;break
		check(clear,"ordinary-height gallery view has a clear capsule: "+str(view[0]))
		if clear:
			world.player.global_position=bar.to_global(feet);world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
			await _settled_optics();await shot(str(view[0])+"_installed")
