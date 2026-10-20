extends Node3D
## Scoped native/print/save diagnostic; played-room acceptance remains separate.
const Shelf := preload("res://scripts/building/v2_readable_bookshelf.gd")
var failures: Array[String]=[]
var checks:=0
var player: PlayerController
var contact_precision:=preload("res://scripts/building/v2_contact_precision.gd").new()
func _exit_tree() -> void: contact_precision.release()
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok: failures.append(label);push_error("LIBRARY CHECK: "+label)
	return ok
func _ready() -> void: _run.call_deferred()
func click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func space() -> void:
	print("SPACE BEGIN inspecting=",player.inspecting())
	var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
	player._unhandled_input(event)
	for frame in 3: await get_tree().physics_frame
	print("SPACE END inspecting=",player.inspecting())
	event=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=false;player._unhandled_input(event)
	for frame in 3: await get_tree().physics_frame
	print("SPACE RETURN paused=",get_tree().paused," current=",get_tree().current_scene)
func cursor_at(point: Vector3) -> bool:
	var pixel:=player.camera.unproject_position(point).round()
	print("CURSOR REQUEST: ",pixel)
	for frame in 8:
		if not DisplayServer.window_is_focused(get_window().get_window_id()): DisplayServer.window_move_to_foreground(get_window().get_window_id())
		await RenderingServer.frame_post_draw;Input.warp_mouse(pixel);await get_tree().process_frame
		if get_viewport().get_mouse_position().distance_to(pixel)<.6: print("CURSOR DELIVERED: ",frame);return true
	return false
func grab_visible_stock(stock: Node3D) -> bool:
	var candidates: Array[Vector3]=[stock.to_global(Vector3(0,.050,.034))]
	for solid: CollisionShape3D in stock._solids:
		var points: PackedVector3Array=solid.shape.points
		var centre:=Vector3.ZERO
		for vertex: Vector3 in points: centre+=vertex
		centre/=maxi(1,points.size())
		candidates.append(solid.global_transform*centre)
		if "__Foot_" in str(solid.name):
			for index in range(0,points.size(),maxi(1,points.size()/8)):
				candidates.append(solid.global_transform*centre.lerp(points[index],.95))
	for point: Vector3 in candidates:
		if not player.inspecting(): player.camera.look_at(point)
		if player.camera.is_position_behind(point) or not get_viewport().get_visible_rect().has_point(player.camera.unproject_position(point)): continue
		if player.inspecting() and not await cursor_at(point): continue
		var target: Dictionary=player._grab.find_target()
		if target.get("part")==stock and target.get("kind")=="free":
			click();return player._grab.active() and player._grab.target.part==stock
	print("NO VISIBLE FREE STOCK GRIP: ",stock.get_path()," camera=",player.camera.global_transform)
	return false

func carry(goal: Vector3) -> bool:
	print("CARRY BEGIN: ",goal," target=",player._grab.target.get("part"))
	var stalled:=0
	for frame in 120:
		if not player._grab.active() or player._grab.target.kind!="free": return false
		var target: Dictionary=player._grab.target
		var before: Vector3=target.read.call()
		if before.distance_to(goal)<.0001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var delta: Vector3=target.frame.global_basis*(goal-before)
		var depth:=delta.dot((point-player.camera.global_position).normalized())
		if absf(depth)>.000002:
			var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0. else MOUSE_BUTTON_WHEEL_UP
			wheel.factor=minf(.025,absf(depth))/.025;player._unhandled_input(wheel)
		point=target.part.to_global(player._grab.contact);delta=target.frame.global_basis*(goal-target.read.call())
		var planar:=delta-player.camera.global_basis.z*delta.dot(player.camera.global_basis.z)
		var motion:=InputEventMouseMotion.new();motion.relative=(player.camera.unproject_position(point+planar)-player.camera.unproject_position(point)).limit_length(25.)
		if frame<3: print("CARRY MOTION: ",frame," before=",before," mouse=",motion.relative)
		player._unhandled_input(motion)
		if frame<3: print("CARRY MOTION RETURN: ",frame," contact=",target.part._last_motion)
		await get_tree().physics_frame
		stalled=stalled+1 if player._grab.active() and goal.distance_to(player._grab.target.read.call())>=goal.distance_to(before)-.000001 else 0
		if stalled>8:
			print("CARRY STOP: ",player._grab.target.part._last_motion," at=",player._grab.target.read.call()," goal=",goal);return false
	return false
func hinge(goal: float) -> bool:
	var stalled:=0
	for frame in 160:
		if not player._grab.active(): return false
		var target: Dictionary=player._grab.target
		var before: float=target.read.call()
		if absf(goal-before)<.00001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var local_axis: Vector3=target.axis.call() if target.axis is Callable else target.axis
		var axis: Vector3=target.frame.global_basis*local_axis
		var tangent: Vector3=axis.cross(point-target.part.global_position) if target.kind=="hinge" else axis
		if target.kind=="hinge" and tangent.length()<float(target.get("minimum_lever",.025)): tangent=axis.cross(player.camera.global_basis.x)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24. and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5: screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.)
		var event:=InputEventMouseMotion.new();event.relative=screen*clampf(goal-before,-.12 if target.kind=="hinge" else -.02,.12 if target.kind=="hinge" else .02)
		player._unhandled_input(event);await get_tree().physics_frame
		stalled=stalled+1 if is_equal_approx(before,float(target.read.call())) else 0
		if stalled>8: print("HINGE STOP: ",target.part.name," wanted=",goal," actual=",target.read.call());return false
	return false
func hand_review(shelf: Node3D) -> void:
	player.set_mouse_released(false)
	player.position=Vector3(shelf.position.x,.02,1.2)
	var book: Node3D=shelf._books.values()[2]
	player.camera.look_at(book.to_global(Vector3(-.0025,float(book.construction.height)*.5,0)))
	for frame in 5: await get_tree().physics_frame
	print("INITIAL BINDING PICK: ",player._grab.find_target()," selected=",book.stock_id)
	click()
	if not check(player._grab.active() and player._grab.target.part==book,"primary grabs binding before inspection"): return
	await space()
	if not check(player.inspecting() and not player._grab.active() and book.freeze,"Space inspects and supports the selected book"): return
	var camera_pose:=player.camera.global_transform
	var point:=book.to_global(Vector3(-.0025,float(book.construction.height)*.5,0))
	check(await cursor_at(point),"native inspection cursor delivered");print("CURSOR TARGET: ",player._grab.find_target());click()
	if check(player._grab.active() and player._grab.target.part==book and player._grab.target.kind=="free","cursor grabs individual spine"):
		var goal:=book.position+Vector3(0,.025,.35)
		check(await carry(goal),"mouse and wheel extract book from real shelf")
		click()
		check(not player._grab.active() and book.freeze,"second click releases the manipulating hand while inspection supports the book")
		await cursor_at(book.to_global(Vector3(-.0043,float(book.construction.height)*.82,float(book.construction.thickness)*.5+.006)))
		click()
		if check(player._grab.active() and player._grab.target.part==book and player._grab.target.kind=="hinge","upper binding edge supplies turn grip"):
			var axis: Vector3=player._grab.target.frame.global_basis*player._grab.target.axis.call()
			var facing: Vector3=(player.camera.global_position-book.global_position).slide(axis).normalized()
			var angle: float=book.global_basis.z.slide(axis).normalized().signed_angle_to(facing,axis)
			check(await hinge(angle),"mouse turns extracted binding about its own spine to reveal its cover");click()
			await cursor_at(book.to_global(Vector3(float(book.construction.width)*.65,float(book.construction.height)*.5,float(book.construction.thickness)*.5+.001)))
			click()
			if check(player._grab.active() and player._grab.target.part==book.left,"cursor grabs the actual opening gathering"):
				check(await hinge(PI),"mouse opens binding to featured two page spread")
				await capture("hand_opened_spread")
				click();check(not player._grab.active(),"second click releases opened binding")
	check(player.camera.global_transform.is_equal_approx(camera_pose),"inspection camera stays fixed through hand motion")
	await capture("inspection_book_extracted")
	if player._grab.active(): player._grab.release()
	await space();check(not player.inspecting() and not book.freeze,"backing out releases the inspected book to gravity")

func bookend_review(shelf: Node3D) -> void:
	player.set_mouse_released(false);player.global_position=shelf.global_position+Vector3(0,.02,1.2)
	var bookend: Node3D=shelf._ends.left
	var handle: MeshInstance3D=bookend.get_node("bookend_pressed__TopReturn")
	player.camera.look_at(handle.global_transform*handle.get_aabb().get_center())
	for frame in 3: await get_tree().physics_frame
	player.camera.look_at(handle.global_transform*handle.get_aabb().get_center())
	click()
	if not check(player._grab.active() and player._grab.target.part==bookend and player._grab.target.kind=="free","primary grabs the solid bookend carry handle without an invented hinge"): return
	await space()
	if not check(player.inspecting() and bookend.freeze,"Space inspects and supports the selected bookend"): return
	var camera_pose:=player.camera.global_transform
	await cursor_at(bookend.to_global(Vector3(0,.050,.034)));click()
	if check(player._grab.active() and player._grab.target.part==bookend and player._grab.target.kind=="free","cursor grabs physical bookend web"):
		check(await carry(bookend.position+Vector3(-.10,.008,0)),"mouse lifts and draws bookend out from under bindings")
		await bookend_obstructions(shelf,bookend)
		click()
	check(player.camera.global_transform.is_equal_approx(camera_pose),"bookend inspection camera stays fixed")
	await capture("hand_moved_bookend")
	await space();check(not player.inspecting() and not bookend.freeze,"Space exits inspection and releases the supported bookend")
func bookend_obstructions(shelf: Node3D, bookend: Node3D) -> void:
	# First retain the actual shelf bearing under downward input.
	var before: Vector3=bookend.position
	check(not await carry(before+Vector3(0,-.06,0)),"bookend cannot be dragged down through its shelf")
	var lowest: float=INF
	for solid: CollisionShape3D in bookend._solids:
		for point: Vector3 in solid.shape.points: lowest=minf(lowest,shelf.to_local(solid.global_transform*point).y)
	check(lowest>=float(shelf._case_record.shelf_tops[2])-.0001,"actual native foot stays above shelf after downward input")
	# Move clear of case walls before the independent wall control, so a real
	# side board or a falling neighbouring book cannot substitute for the wall.
	check(await carry(bookend.position+Vector3(0,.012,.25)),"mouse draws bookend into clear foreground")
	before=bookend.position
	var edge: float=INF
	for solid: CollisionShape3D in bookend._solids:
		for point: Vector3 in solid.shape.points: edge=minf(edge,shelf.to_local(solid.global_transform*point).x)
	var wall:=StaticBody3D.new();wall.name="DiagnosticBookendWall"
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(.01,.3,.35);box.margin=.00002;shape.shape=box
	wall.add_child(shape);shelf.add_child(wall)
	wall.position=Vector3(edge-.015,before.y+.07,before.z)
	for frame in 2: await get_tree().physics_frame
	check(not await carry(before+Vector3(-.04,0,0)),"bookend cannot pass a new wall during hand movement")
	check(bookend._contact_ids.has(wall.get_instance_id()),"new wall is an actual blocking contact")
	edge=INF
	for solid: CollisionShape3D in bookend._solids:
		for point: Vector3 in solid.shape.points: edge=minf(edge,shelf.to_local(solid.global_transform*point).x)
	check(edge>=wall.position.x+.005-.0001,"native bookend stock remains on near side of wall")
	wall.free()
	for frame in 2: await get_tree().physics_frame
	check(await carry(before+Vector3(-.04,0,0)),"removing the obstruction restores hand travel")

func sash_review(shelf: Node3D) -> void:
	player.set_mouse_released(false);player.position=Vector3(shelf.position.x,.02,1.2)
	var sash: Node3D=shelf._sashes[1]
	var rail: MeshInstance3D=sash.leaf.get_node("sectional_sash1__Rail0")
	var point: Vector3=rail.global_transform*rail.get_aabb().get_center()
	player.camera.look_at(point)
	for frame in 4: await get_tree().physics_frame
	player.camera.look_at(point)
	click()
	if not check(player._grab.active() and player._grab.target.part==sash.leaf,"primary click grabs glazed lift sash"): return
	await space()
	if not check(player.inspecting(),"glazed library enters fixed inspection"): return
	await cursor_at(point);print("SASH LOWER PICK: ",player._grab.find_target());click()
	if check(player._grab.active() and player._grab.target.part==sash.leaf,"cursor grabs lower sash rail"):
		check(await hinge(PI*.5),"mouse lifts sectional leaf to its horizontal stop");click()
	var upper: MeshInstance3D=sash.leaf.get_node("sectional_sash1__Rail1")
	point=upper.global_transform*upper.get_aabb().get_center()
	await cursor_at(point);print("SASH UPPER PICK: ",player._grab.find_target());click()
	if check(player._grab.active() and player._grab.target.part==sash and player._grab.target.kind=="slider","raised upper rail supplies pocket track grip"):
		check(await hinge(float(sash.record.inset_limit)),"mouse pushes leaf along actual case tracks")
		await capture("sectional_pocket_stored")
		check(await hinge(0.),"mouse pulls stored leaf back out");click()
	point=rail.global_transform*rail.get_aabb().get_center();await cursor_at(point);click()
	if check(player._grab.active() and player._grab.target.part==sash.leaf,"extracted sash reacquires lift grip"):
		check(await hinge(0.),"mouse lowers the glazing without crossing stock");click()
	await space()
func capture(label: String) -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 8: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
func equivalent(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_FLOAT,TYPE_INT] and typeof(b) in [TYPE_FLOAT,TYPE_INT]: return absf(float(a)-float(b))<.000002
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for k: Variant in a:
			if not b.has(k) or not equivalent(a[k],b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b
func print_review(stock: RefCounted,shelf: Node3D) -> void:
	var proofs:=Node3D.new();proofs.position=Vector3(0,4,12);proofs.hide();add_child(proofs)
	for identity: String in stock.data.books:
		var book:=preload("res://scripts/props/v2_readable_book.gd").new()
		book.stock=stock;book.shelf=shelf;book.stock_id=identity;book.entry=shelf.sorter.book(identity)
		proofs.add_child(book);book.freeze=true;book._apply_opening(PI)
	for frame in 3: await RenderingServer.frame_post_draw
	for book: Node3D in proofs.get_children():
		check(book._sheets.size()==2,"two physical printed sheets: "+book.stock_id)
		for sheet: Node3D in book._sheets:
			for label: Label3D in sheet.find_children("*","Label3D",false,false):
				var bounds: AABB=label.transform*label.get_aabb()
				check(bounds.position.x>=-.0001 and bounds.end.x<=float(book.construction.width)+.0001 and bounds.position.y>=-.0001 and bounds.end.y<=float(book.construction.height)+.0001,"printed field stays on its sheet: "+book.stock_id+"/"+label.name)
				if label.name=="BodyText":
					var illustration: MeshInstance3D=sheet.find_child("plate__*",false,false)
					if illustration!=null:
						var plate: AABB=illustration.transform*illustration.get_aabb()
						check(bounds.position.y>plate.end.y+.004,"ink plate clears prose: "+book.stock_id)
			var labels:=sheet.find_children("*","Label3D",false,false)
			for a_index in labels.size():
				var a: Label3D=labels[a_index]
				var ab: AABB=a.transform*a.get_aabb()
				for b_index in range(a_index+1,labels.size()):
					var b: Label3D=labels[b_index]
					var bb: AABB=b.transform*b.get_aabb()
					check(ab.end.x<=bb.position.x or bb.end.x<=ab.position.x or ab.end.y<=bb.position.y or bb.end.y<=ab.position.y,"printed fields do not overlap: "+book.stock_id+"/"+a.name+"/"+b.name)
	# Render every featured gathering using the production lamp and physical pages.
	proofs.show()
	for book: Node3D in proofs.get_children():
		for other: Node3D in proofs.get_children(): other.visible=other==book
		var point:=book.global_position+Vector3(0,float(book.construction.height)*.5,0)
		var distance:=maxf(float(book.construction.height)*.5,float(book.construction.width)/get_viewport().get_visible_rect().size.aspect())/tan(deg_to_rad(20.))/.88
		player.camera.global_position=point+Vector3(0,0,distance)
		player.camera.fov=40.;player.camera.look_at(point)
		await capture("spread_"+book.stock_id)
	proofs.queue_free()
func carried_stock_review(stock: RefCounted) -> void:
	# A separate copy keeps the native hand/sash fixtures unchanged. This
	# corridor is diagnostic, not an authored world location or a save owner.
	# A visible metric floor makes distant captures legible without changing
	# the carried lamp. This is a diagnostic plane, not an exported V2 prop.
	var floor_draw:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new()
	floor_mesh.size=Vector2(80,12);floor_draw.mesh=floor_mesh;floor_draw.position.y=.0001
	var floor_finish: StandardMaterial3D=stock.materials.oak_work_surface.duplicate()
	floor_finish.uv1_scale*=Vector3(80,12,1)
	floor_draw.material_override=floor_finish;add_child(floor_draw)
	var library:=Shelf.new();library.native_stock=stock;library.owner_name="Iris Bell";library.unit="5C";library.case_style="plain"
	library.position=Vector3(2.4,0,-2.);add_child(library)
	player.global_position=library.global_position+Vector3(0,.02,1.2)
	player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
	player.set_mouse_released(false)
	var book: Node3D=library._books.values()[2]
	for frame in 4: await get_tree().physics_frame
	player.camera.look_at(book.to_global(Vector3(-.0025,float(book.construction.height)*.5,0)))
	click()
	if not check(player._grab.active() and player._grab.target.part==book,"primary acquires travel binding without entering inspection"): library.free();return
	if not check(await carry(book.position+Vector3(0,.10,.45)),"mouse extracts travel binding into clear space"):
		player.cancel_manipulation();library.free();return
	var start:=player.global_position
	var relative:=book.global_position-player.global_position
	Input.action_press("move_right")
	for frame in 650:
		await get_tree().physics_frame
		if player.global_position.x-start.x>=24.: break
		if not player._grab.active(): break
	Input.action_release("move_right")
	check(player.global_position.x-start.x>=24.,"ordinary walking input carries stock 24 metres on a real capsule and floor")
	check(player._grab.active() and player._grab.target.part==book,"stock remains grabbed beyond the former shelf workspace")
	check((book.global_position-player.global_position).distance_to(relative)<.01,"holder motion preserves the hand's relative position")
	check(book.position.length()>20.,"actual carried position exceeds the former save radius")
	check(book.shelf==library and library._books[book.stock_id]==book,"moving rooms retains the original library owner and identity")
	print("CARRIED STOCK: walked=",player.global_position.distance_to(start)," local_pose=",book.transform," hand_offset_error=",(book.global_position-player.global_position).distance_to(relative))
	await capture("carried_book_24m")
	var changes: Array[Vector3]=[]
	var observe:=func(where: Vector3,_what: String): changes.append(where)
	player.world_modified.connect(observe)
	click()
	player.world_modified.disconnect(observe)
	check(changes.size()==1 and changes[0].distance_to(book.global_position)<.001,"world-change signal follows the distant book while retaining its semantic owner")
	check(library._tap.global_position.distance_to(book.global_position)<.001,"handling sound originates at the distant stock")
	check(not player._grab.active() and not book.freeze,"primary releases travelling stock to ordinary gravity")
	for frame in 180:
		await get_tree().physics_frame
		if book.sleeping: break
	check(book.sleeping,"released travelling binding settles on the distant floor")
	var saved: Dictionary=library.library_snapshot()
	check(library.valid_library(saved),"original library accepts the real distant physical snapshot")
	var encoded: Dictionary=JSON.parse_string(JSON.stringify(saved,"",true,true))
	var bad: Dictionary=encoded.duplicate(true)
	bad.books[book.stock_id].body.position[0]=1e100
	check(not library.valid_library(bad),"finite JSON coordinates that overflow native Vector3 are refused")
	var identity: String=book.stock_id
	library.free()
	var restored:=Shelf.new();restored.native_stock=stock;restored.owner_name="Iris Bell";restored.unit="5C";restored.case_style="plain"
	restored.position=Vector3(2.4,0,-2.);add_child(restored)
	restored.restore_order(encoded)
	for frame in 4: await get_tree().physics_frame
	check(equivalent(restored._books[identity].book_snapshot(),encoded.books[identity]),"new native owner rebuilds the distant binding pose/opening/velocity after JSON round trip")
	check(restored.valid_library(restored.library_snapshot()),"reconstructed distant stock remains a valid household payload")
	var rebuilt: Node3D=restored._books[identity]
	player.camera.look_at(rebuilt.to_global(Vector3(float(rebuilt.construction.width)*.5,float(rebuilt.construction.height)*.5,0)))
	await capture("rebuilt_book_24m")
	restored.free();floor_draw.free()

func reading_order_review() -> void:
	var fixture:=Shelf.new()
	fixture._case_record={"shelf_tops":[.3,.6,.9]}
	for index in 3:
		var book:=Node3D.new();fixture.add_child(book)
		book.position=Vector3(index*.04,.89+index*.01,0)
		book.basis=Basis(Vector3.FORWARD,PI*.5)
		fixture._books[str(index)]=book
	fixture.sorter.order=["0","1","2"]
	check(fixture._physical_reading_order()==["2","1","0"],"connected flat pile reads top down without comparator cycle")
	for permutation: Array in [["2","0","1"],["1","2","0"],["2","1","0"],["1","0","2"],["0","2","1"]]:
		fixture.sorter.order=permutation
		check(fixture._physical_reading_order()==["2","1","0"],"physical order independent of previous array order")
	fixture._books["1"].position=fixture._books["0"].position
	fixture._books["2"].position=fixture._books["0"].position
	check(fixture._physical_reading_order()==["0","1","2"],"coincident books have stable identity tie break")
	fixture.free()

func _run() -> void:
	reading_order_review()
	print("LIBRARY ENGINE: ",ProjectSettings.get_setting_with_override("physics/3d/physics_engine")," contact allowance=",PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION))
	check(contact_precision.bind(get_world_3d()),"production native contact precision binds")
	preload("res://tests/v2_control_finish_review.gd").new().validate_material_contract(self)
	RealityState.persistence_enabled=false
	var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
	if not check(stock.prepare(),"native library prepares"): get_tree().quit(1);return
	for key: String in stock.materials:
		var material: StandardMaterial3D=stock.materials[key]
		check(not material.uv1_triplanar,"authored native UV material: "+key)
		for texture: Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
			if not check(texture!=null,"custom loaded PBR map: "+key): continue
			var image:=texture.get_image()
			var levels:=int(round(log(float(maxi(texture.get_width(),texture.get_height())))/log(2.)))
			check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==levels,"complete loaded mip chain: "+key)
	for identity: String in stock.printed_materials:
		var material: StandardMaterial3D=stock.printed_materials[identity]
		var texture: Texture2D=material.detail_albedo
		var image:=texture.get_image()
		var levels:=int(round(log(float(maxi(texture.get_width(),texture.get_height())))/log(2.)))
		check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==levels,"illustration loaded full mip chain: "+identity)
		var arrays: Array=stock.meshes[identity].surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_TEX_UV2]!=null and arrays[Mesh.ARRAY_TEX_UV2].size()==arrays[Mesh.ARRAY_VERTEX].size(),"independent artwork UV2: "+identity)
	var metrics:=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for identity: String in stock.meshes: metrics._check_cap_mapping(stock.meshes[identity],true)
	for failure: String in metrics.failures: check(false,failure)
	metrics.free()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=.35;add_child(sun)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.06,.07,.085);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.44,.48,.55);environment.ambient_light_energy=.35
	var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
	var floor_body:=StaticBody3D.new();floor_body.position.y=-.1;add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,.2,12);shape.shape=box;floor_body.add_child(shape)
	var shelves: Array[Node3D]=[]
	for row: Array in [["Iris Bell","5C","plain"],["Mina Vale","2A","repaired"],["Mae Kessler","6C","sectional"]]:
		var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name=row[0];shelf.unit=row[1];shelf.case_style=row[2]
		shelf.position.x=(shelves.size()-1)*1.2;add_child(shelf);shelves.append(shelf)
		check(shelf._books.size()>0,"resident books mount: "+str(row[0]))
	player=PlayerController.new();player.position=Vector3(0,.02,1.65);add_child(player);player.set_lamp_enabled(true);player.camera.make_current()
	var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
	check(air.setup(player,environment),"production carried voxel light initializes")
	for frame in 3: await get_tree().physics_frame
	player.camera.look_at(Vector3(0,.7,0));await capture("initial_authored_layout")
	for shelf: Node3D in shelves:
		for book: Node3D in shelf._books.values():
			print("INITIAL POSE: ",shelf.unit," ",book.stock_id," ",book.transform)
			for solid: CollisionShape3D in book._solids:
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=solid.shape;query.transform=solid.global_transform;query.margin=0.;query.exclude=[book.get_rid()]
				var contacts:=get_world_3d().direct_space_state.intersect_shape(query,8)
				check(contacts.is_empty(),"authored stock begins without overlap: "+shelf.unit+"/"+book.stock_id+"/"+solid.name)
				for hit: Dictionary in contacts:
					print("INITIAL OVERLAP: ",shelf.unit," ",book.stock_id," ",solid.name," with ",hit.collider.get_path())
	for frame in 180:
		await get_tree().physics_frame
		if frame in [0,1,2,5,10,30,60]:
			var diagnostic: Node3D=shelves[0]._books["standards"]
			print("FLAT STEP: ",frame," pose=",diagnostic.transform," speed=",diagnostic.linear_velocity," spin=",diagnostic.angular_velocity)
	player.camera.look_at(Vector3(0,.7,0));await capture("resident_libraries")
	for shelf: Node3D in shelves:
		var saved: Dictionary=shelf.library_snapshot()
		check(shelf.valid_library(saved),"physical snapshot validates: "+shelf.unit)
		var encoded: Dictionary=JSON.parse_string(JSON.stringify(saved))
		check(shelf.valid_library(encoded),"JSON save retains valid physical state: "+shelf.unit)
		shelf.restore_order(encoded)
		var restored: Dictionary=shelf.library_snapshot()
		for identity: String in saved.books:
			var a: Dictionary=saved.books[identity];var b: Dictionary=restored.books[identity]
			if not equivalent(a,b): print("RESTORE DELTA: ",identity," before=",a," after=",b)
		check(equivalent(restored,saved),"physical snapshot round trip at float32 precision: "+shelf.unit)
		var bad: Dictionary=encoded.duplicate(true)
		bad.order[0]=bad.order[1]
		check(not shelf.valid_library(bad),"duplicate library identity rejected: "+shelf.unit)
		bad=encoded.duplicate(true);bad.books[bad.order[0]].body.rotation=[0.,0.,0.,0.]
		check(not shelf.valid_library(bad),"invalid orientation rejected: "+shelf.unit)
		bad=encoded.duplicate(true);bad.books[bad.order[0]].body.position[0]=NAN
		check(not shelf.valid_library(bad),"nonfinite body position rejected: "+shelf.unit)
		bad=encoded.duplicate(true);bad.moves=.25
		check(not shelf.valid_library(bad),"fractional operation count rejected: "+shelf.unit)
		for book: Node3D in shelf._books.values():
			check(book.position.is_finite() and book.position.y>0.,"book remains supported: "+book.stock_id)
	if OS.get_environment("LIBRARY_PRINT_ONLY")!="1":
		await hand_review(shelves[0])
		await bookend_review(shelves[1])
	if OS.get_environment("LIBRARY_PRINT_ONLY")!="1": await sash_review(shelves[2])
	if OS.get_environment("LIBRARY_HAND_ONLY")!="1": await print_review(stock,shelves[0])
	if OS.get_environment("LIBRARY_PRINT_ONLY")!="1": await carried_stock_review(stock)
	# Print review uses a separate isolated featured gathering; this is not hand proof.
	var shelf: Node3D=shelves[0]
	var book: Node3D=shelf._books.values()[0]
	book.freeze=true;book.transform=Transform3D(Basis.IDENTITY,Vector3(0,1.3,.7));book._apply_opening(PI)
	player.position=Vector3(-1.2,.02,1.15)
	var reading_point:=book.global_position+Vector3(0,float(book.construction.height)*.5,0)
	player.camera.global_position=reading_point+Vector3(0,0,.43);player.camera.fov=40.;player.camera.look_at(reading_point)
	await capture("featured_spread")
	check(book.printed_labels.size()>=11,"featured gathering prints directly on physical sheets")
	print("V2 READABLE LIBRARY BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
