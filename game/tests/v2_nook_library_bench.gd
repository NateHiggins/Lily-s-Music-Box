extends "res://tests/v2_readable_library_bench.gd"
## Native nook controls/print/snapshot diagnostic; no room or route admission.
const Nook := preload("res://scripts/building/orison_v2_reading_nook.gd")
const Loose := preload("res://scripts/building/v2_loose_library.gd")

func _run() -> void:
	RealityState.persistence_enabled=false
	check(contact_precision.bind(get_world_3d()),"native contact precision binds")
	var fixture:=Node3D.new();fixture.name="NookFixture";add_child(fixture)
	var adapter:=OrisonV2AnchorAdapter.new(fixture)
	if not check(Nook.mount(adapter),"actual nook consumer mounts native loose collection"): get_tree().quit(1);return
	var collections: Array=[];var books: Array=[];var ends: Array=[]
	for owner: Node in get_tree().get_nodes_in_group("v2_library_collections"):
		if not fixture.is_ancestor_of(owner): continue
		collections.append(owner);books.append_array(owner._books.values());ends.append_array(owner._ends.values())
	check(collections.size()==3 and books.size()==61 and ends.size()==6,"three owners retain all 61 copies and six real ends")
	var stock: RefCounted=collections[0].native_stock
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Nook.COPIES))
	check(stock.valid_copy_records(metadata.copies,stock) and stock.valid_end_records(metadata.ends,stock),"complete physical-copy programme validates")
	var malformed: Array=metadata.copies.duplicate(true);malformed[1].id=malformed[0].id
	check(not stock.valid_copy_records(malformed,stock),"duplicate physical-copy identity refused")
	malformed=metadata.copies.duplicate(true)
	for index in 3: malformed[0].basis[0][index]*=2.
	check(not stock.valid_copy_records(malformed,stock),"scaled physical pose refused")
	malformed=metadata.copies.duplicate(true);malformed[0].position[0]=1e100
	check(not stock.valid_copy_records(malformed,stock),"overflowing copy position refused")
	var ids: Dictionary={};var titles: Dictionary={}
	for book: Node3D in books:
		check(not ids.has(book.stock_id),"physical copies have independent identities")
		ids[book.stock_id]=true;titles[book.title_id]=true
		check(book.entry==book.shelf.sorter.book(book.title_id),"display title and author resolve independently of copy ID")
		check(book.freeze and book.shelf_slot>=0 and not book.is_physics_processing(),"authored copy occupies a static placement spot: "+book.stock_id)
	check(titles.size()==26,"shared collection excludes rare pamphlets and singular minutes")
	var metrics:=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for identity: String in metadata.parts: metrics._check_cap_mapping(stock.meshes[identity],true)
	for identity: String in metadata.parts:
		check(stock.meshes[identity]==stock.meshes[str(metadata.parts[identity].native_part)],"physical copies share exact native edition buffers: "+identity)
	for failure: String in metrics.failures: check(false,failure)
	metrics.free()
	for key: String in stock.materials:
		var material: StandardMaterial3D=stock.materials[key]
		check(material.normal_enabled and not material.uv1_triplanar,"custom metric PBR remains enabled: "+key)
		for texture: Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
			if not check(texture!=null,"loaded custom map: "+key): continue
			var image:=texture.get_image();var levels:=int(round(log(float(maxi(texture.get_width(),texture.get_height())))/log(2.)))
			check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==levels,"complete loaded mip chain: "+key)
	var floor_body:=StaticBody3D.new();floor_body.position=Vector3(-.5,-3.3,2.4);add_child(floor_body)
	var shape:=CollisionShape3D.new();var slab:=BoxShape3D.new();slab.size=Vector3(8,.2,8);shape.shape=slab;floor_body.add_child(shape)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.045,.05,.06)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.45,.48,.55);environment.ambient_light_energy=.3
	var sky:=WorldEnvironment.new();sky.environment=environment;add_child(sky)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=.3;add_child(sun)
	player=PlayerController.new();player.position=Vector3(-1.6,-3.199,1.4);add_child(player)
	player.camera.make_current();player.set_mouse_released(false);player.set_lamp_enabled(true)
	var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
	check(air.setup(player,environment),"production carried voxel lamp initializes")
	for frame in 4: await get_tree().physics_frame
	for body: Node3D in books+ends:
		for solid: CollisionShape3D in body._solids:
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=solid.shape;query.transform=solid.global_transform;query.margin=0.;query.exclude=[body.get_rid()]
			var hits:=get_world_3d().direct_space_state.intersect_shape(query,8)
			check(hits.is_empty(),"native stock starts without overlap: "+body.stock_id+"/"+solid.name)
			for hit: Dictionary in hits: print("NOOK INITIAL CONTACT: ",body.stock_id," -> ",hit.collider.get_path())
	player.camera.look_at(Vector3(-.48,-2.35,3.0));await capture("nook_installed")
	for collection: Node3D in collections: legacy_save_review(collection)
	var owner: Node3D=adapter.resolve("nook_books_library")
	var original: Dictionary=owner.library_snapshot()
	for format: String in ["trade","pocket","pamphlet"]:
		var selected: Node3D
		for candidate: Node3D in owner._books.values():
			if str(candidate.construction.format)==format and absf(candidate.global_basis.y.dot(Vector3.UP))>.5:selected=candidate;break
		if not check(selected!=null,"representative native format exists: "+format):continue
		if await approach(selected): await manipulate_binding(owner,selected)
		else: check(false,"standing capsule and real cursor find the lending binding: "+format)
		owner.restore_order(original)
	var snapshots: Dictionary={}
	for collection: Node3D in collections:
		var saved: Dictionary=collection.library_snapshot();snapshots[str(collection.name)]=saved
		check(collection.valid_library(saved),"native copy/end snapshot valid: "+str(collection.name))
	var print_books: Array=[]
	var proofs:=Node3D.new();proofs.position=Vector3(0,10,50);proofs.hide();add_child(proofs)
	for record: Dictionary in metadata.copies:
		var book:=preload("res://scripts/props/v2_readable_book.gd").new()
		book.stock=stock;book.shelf=owner;book.stock_id=str(record.id);book.title_id=str(record.title_id);book.entry=owner.sorter.book(book.title_id)
		proofs.add_child(book);book.freeze=true;book._apply_opening(PI);print_books.append(book)
	for frame in 3: await RenderingServer.frame_post_draw
	for book: Node3D in print_books: check_pages(book)
	proofs.show();var represented: Dictionary={}
	# Render the smallest actual page area per title; all 61 have geometric QA.
	for book: Node3D in print_books:
		if not represented.has(book.title_id) or book.construction.width*book.construction.height<represented[book.title_id].construction.width*represented[book.title_id].construction.height: represented[book.title_id]=book
	for book: Node3D in represented.values():
		for other: Node3D in print_books: other.visible=other==book
		var point:=book.global_position+Vector3(0,float(book.construction.height)*.5,0)
		var distance:=maxf(float(book.construction.height)*.5,float(book.construction.width)/get_viewport().get_visible_rect().size.aspect())/tan(deg_to_rad(20.))/.88
		player.camera.global_position=point+Vector3(0,0,distance);player.camera.fov=40.;player.camera.look_at(point)
		await capture("copy_spread_"+book.title_id)
	proofs.free();fixture.free()
	var rebuilt:=Node3D.new();rebuilt.name="RebuiltNook";add_child(rebuilt)
	var fresh:=OrisonV2AnchorAdapter.new(rebuilt)
	check(Nook.mount(fresh),"new native nook owners reconstruct")
	for identity: String in snapshots:
		var collection: Node3D=fresh.resolve(identity)
		var encoded: Dictionary=JSON.parse_string(JSON.stringify(snapshots[identity],"",true,true))
		collection.restore_order(encoded)
		check(equivalent(collection.library_snapshot(),encoded),"copy pose/opening/end identities rebuild after JSON: "+identity)
	print("V2 NOOK LIBRARY BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func approach(book: Node3D) -> bool:
	var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
	for z: float in [2.2,2.0,2.4,1.8]:
		for x: float in [0.,-.5,.5,-1.,1.]:
			var floor_ray:=PhysicsRayQueryParameters3D.create(Vector3(x,-2.2,z),Vector3(x,-3.4,z));floor_ray.exclude=[player.get_rid()]
			var support:=get_world_3d().direct_space_state.intersect_ray(floor_ray)
			if support.is_empty() or support.normal.dot(Vector3.UP)<.9 or support.position.y> -3.18: continue
			player.global_position=Vector3(x,support.position.y+player.safe_margin,z)
			player.velocity=Vector3.ZERO
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*PlayerController.STANDING_HEIGHT*.5);query.exclude=[player.get_rid()];query.margin=0.
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
			player.camera.look_at(book.to_global(Vector3(-.0025,float(book.construction.height)*.5,0)))
			for frame in 2: await get_tree().physics_frame
			var target: Dictionary=player._grab.find_target()
			print("LENDING APPROACH: ",book.stock_id," stance=",player.global_position," target=",target.get("part")," kind=",target.get("kind"))
			if target.get("part")==book and target.get("kind")=="free": return true
	return false

func manipulate_binding(owner: Node3D,book: Node3D) -> void:
	click();check(player._grab.active() and player._grab.target.part==book,"primary grabs physical lending copy")
	for frame in 130: await get_tree().physics_frame
	var wanted: Vector3=player.camera.global_transform*Vector3(.17,-.16,-.48)
	check((book.global_transform*book.pickup_centre()).distance_to(wanted)<.003,"lending copy withdraws toward its real front and reaches FPS hand")
	await space();check(player.inspecting() and book.freeze,"Space supports the selected copy")
	for frame in 110: await get_tree().physics_frame
	var pose: Transform3D=book.global_transform
	check(not book.is_physics_processing(),"floating nook inspection settles without polling")
	await cursor_at(book.left.to_global(Vector3(float(book.construction.width)*.7,float(book.construction.height)*.7,float(book.construction.thickness)*.5)));click()
	if check(player._grab.active() and player._grab.target.part==book.left,"actual gathering supplies opening grip"):
		check(await hinge(PI),"mouse opens featured spread directly on lending copy");click()
	check(book.global_transform.is_equal_approx(pose),"operating the gathering keeps the floating binding static")
	await capture("nook_hand_opened_"+str(book.construction.format))
	var before_fov:=player.camera.fov
	var zoom:=InputEventMouseButton.new();zoom.pressed=true;zoom.button_index=MOUSE_BUTTON_WHEEL_UP;zoom.factor=12.
	player._unhandled_input(zoom)
	check(player.camera.fov<before_fov and book.global_transform.is_equal_approx(pose),"nook reading zoom preserves the static floating copy")
	await capture("nook_reading_"+str(book.construction.format))
	for duplicate: Node3D in owner._books.values():
		if duplicate!=book and duplicate.title_id==book.title_id:
			check(is_zero_approx(duplicate.opening),"same-title physical copy keeps an independent opening")
			for draw: MeshInstance3D in duplicate._native_draws:
				for key in draw.get_blend_shape_count():check(is_zero_approx(draw.get_blend_shape_value(key)),"shared mesh does not share instance opening weights")
	if player._grab.active(): player._grab.release()
	await space()

func legacy_save_review(collection: Node3D) -> void:
	var original: Dictionary=collection.library_snapshot()
	var legacy: Dictionary=original.duplicate(true);legacy.slots=[];legacy.geometry="previous native dimensions"
	for record: Dictionary in collection.copy_records:
		var saved: Dictionary=legacy.books[str(record.id)];var row: Array=record.legacy_pose
		saved.slot=-1;saved.opening=record.legacy_opening
		saved.body.position=row.slice(0,3);saved.body.rotation=row.slice(3,7)
		saved.body.sleeping=true;saved.body.velocity=[0.,0.,0.];saved.body.spin=[0.,0.,0.]
	for record: Dictionary in collection.end_records:
		var saved: Dictionary=legacy.bookends[str(record.id)];var row: Array=record.legacy_pose
		saved.position=row.slice(0,3);saved.rotation=row.slice(3,7);saved.sleeping=true
		saved.velocity=[0.,0.,0.];saved.spin=[0.,0.,0.]
	var moved_id: String=collection.copy_records[0].id
	legacy.books[moved_id].body.position[0]+=2.
	check(collection.valid_library(legacy),"empty-slot historical nook payload validates: "+str(collection.name))
	collection.restore_order(legacy)
	for identity: String in collection._books:
		var book: Node3D=collection._books[identity]
		if identity==moved_id:
			check(book.shelf_slot==-1 and equivalent(book.book_snapshot(),legacy.books[identity]),"migration preserves a previously moved loose copy")
		else:check(book.shelf_slot>=0 and book.transform.is_equal_approx(collection.book_slots[book.shelf_slot]),"untouched old copy refits its coherent native spot")
	collection.restore_order(original)
	check(equivalent(collection.library_snapshot(),original),"current nook placement JSON restores exactly")

func check_pages(book: Node3D) -> void:
	check(book._sheets.size()==2,"two printed sheets for copy: "+book.stock_id)
	for sheet: Node3D in book._sheets:
		var labels:=sheet.find_children("*","Label3D",false,false)
		for label: Label3D in labels:
			var bounds: AABB=label.transform*label.get_aabb()
			check(bounds.position.x>=-.0001 and bounds.end.x<=float(book.construction.width)+.0001 and bounds.position.y>=-.0001 and bounds.end.y<=float(book.construction.height)+.0001,"copy print remains inside leaf: "+book.stock_id+"/"+label.name)
		for a in labels.size():
			var left: AABB=labels[a].transform*labels[a].get_aabb()
			for b in range(a+1,labels.size()):
				var right: AABB=labels[b].transform*labels[b].get_aabb()
				check(left.end.x<=right.position.x or right.end.x<=left.position.x or left.end.y<=right.position.y or right.end.y<=left.position.y,"copy print fields separate: "+book.stock_id)
