extends "res://tests/orison_v2_floor_surface_test.gd"
const Fit := preload("res://scripts/building/orison_v2_furnishing_clearance.gd")

static func refit_delta(root: Node3D,identity: String) -> Vector3:
	var result := Vector3.ZERO
	var report: Dictionary=root.get_meta("v2_furnishing_clearance",{})
	for row: Dictionary in report.get("items",[]):
		if str(row.id)==identity or identity in row.get("followers",[]):result+=Vector3(row.offset[0],row.offset[1],row.offset[2])
	return result

static func _triangle_box(a: Vector3,b: Vector3,c: Vector3,box: AABB) -> bool:
	var center := box.get_center();var half := box.size*.5
	a-=center;b-=center;c-=center
	var axes: Array[Vector3]=[Vector3.RIGHT,Vector3.UP,Vector3.BACK,(b-a).cross(c-a)]
	for edge: Vector3 in [b-a,c-b,a-c]:
		for unit: Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:axes.append(edge.cross(unit))
	for axis: Vector3 in axes:
		if axis.length_squared()<.000000000001:continue
		var radius := axis.abs().dot(half)
		var low := minf(a.dot(axis),minf(b.dot(axis),c.dot(axis)))
		var high := maxf(a.dot(axis),maxf(b.dot(axis),c.dot(axis)))
		if low>=radius-.00000001 or high<=-radius+.00000001:return false
	return true

func _leaning_tool_clear(root: Node3D,body: Node3D,stock: Array[Dictionary]) -> bool:
	var inverse := root.global_transform.affine_inverse()
	for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null:continue
		var pose := inverse*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb()
		var nearby: Array[AABB]=[]
		for finish: Dictionary in stock:
			if bounds.intersects(finish.bounds):nearby.append(finish.bounds)
		if nearby.is_empty():continue
		var faces := draw.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3=pose*faces[i];var b: Vector3=pose*faces[i+1];var c: Vector3=pose*faces[i+2]
			for box: AABB in nearby:
				if _triangle_box(a,b,c,box):return false
	return true

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production world composes for furnishing inspection")
	if not world.startup_failed and world.player!=null:await validate_in_world(world)
	world.free()
	await get_tree().physics_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> void:
	var trim: Array[Dictionary]=[{"bounds":AABB(Vector3(-1,0,0),Vector3(2,.17,.042)),"normal":Vector3.BACK}]
	var sample: Array[AABB]=[AABB(Vector3(-.3,0,.02),Vector3(.6,1,.5))]
	var fit := Fit.displacement(sample,trim,false)
	check(fit.resolved and is_equal_approx(fit.offset.z,.0341),"measured baseboard depth produces minimum furniture stand-off")
	var blocked: Array[AABB]=[AABB(Vector3(-.3,.1,.525),Vector3(.6,.8,.1))]
	check(not Fit.displacement(sample,trim,false,Vector2(-INF,INF),blocked).resolved,"neighbouring stock prevents a new overlap")
	check(Fit.displacement(sample,trim,true,Vector2(.18,.9)).resolved==false,"wall hanging cannot escape trim by crossing floor or ceiling limits")
	var camera_pose := world.player.camera.global_transform
	var lamp_on := world.player.lamp_is_enabled()
	var physics_on := world.player.is_physics_processing()
	world.player.set_physics_process(false)
	var report: Dictionary=world.adapter.root.get_meta("v2_furnishing_clearance",{})
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("furnishing_clearance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var stock := Fit.finish_stock(world.adapter.root)
	var ladder := world.adapter.resolve("B1_laundry_stepladder") as Node3D
	check(ladder!=null and _leaning_tool_clear(world.adapter.root,ladder,stock),"actual leaning ladder triangles clear trim while retaining floor and wall bearings")
	var moved := 0;var unresolved := 0
	var selected := ["EastRack","1A_wardrobe","1A_frame_a","4C_story_colorboard","3B_toolboard","5C_w0_wardrobe","6B_abed","F01_lobby_photo","F06_PUBLIC_LANDING_PIECE","2A_k_wall_cupboard","F02_2A_BOOKSHELF_01","3A_prop_shelf_n","2B_repair_rail","6A_prep_cabinet","2B_dress_form"]
	for row: Dictionary in report.items:
		if not row.resolved:unresolved+=1
		var offset := Vector3(row.offset[0],row.offset[1],row.offset[2])
		if offset!=Vector3.ZERO:moved+=1
		var body := world.adapter.root.get_node_or_null(str(row.path)) as Node3D
		check(body!=null,"furnishing retains identity: "+str(row.id))
		if body==null:continue
		var boxes := Fit.parts(world.adapter.root,body)
		check(Fit.overlaps(boxes,stock,Vector3.ZERO,Fit.HANGING_GAP if row.hanging else Fit.AIR_GAP).is_empty(),"installed furnishing clears real finish: "+str(row.id))
		var total := refit_delta(world.adapter.root,str(row.id))
		check(total.length()<=Fit.MAX_HANGING_MOVE if row.hanging else (is_zero_approx(total.y) and total.length()<=Fit.MAX_FLOOR_MOVE),"refit stays within its physical placement limits: "+str(row.id))
		var stance := world.adapter.resolve(str(row.id)+"_STANCE") as Node3D
		if stance!=null:
			for anchor: Dictionary in world.layout.anchors:
				if str(anchor.id)==str(stance.name):
					var at: Vector3=world.adapter.root.to_local(stance.global_position)
					check(is_equal_approx(at.y,float(world.adapter.root.level_y[str(anchor.level)])+float(anchor.position[1])),"approach stays at its original floor height: "+str(row.id))
		if str(row.id) in selected:
			var bounds := boxes[0]
			for box: AABB in boxes:bounds=bounds.merge(box)
			var center: Vector3=world.adapter.root.to_global(bounds.get_center())
			var local_center := bounds.get_center()
			var normal := Vector3.BACK
			var nearest := INF
			for finish: Dictionary in stock:
				var box: AABB=finish.bounds
				var distance := local_center.distance_squared_to(local_center.clamp(box.position,box.end))
				if distance<nearest:nearest=distance;normal=finish.normal
			var base_angle := atan2(normal.x,normal.z)
			var found := false
			for turn: float in [0.,PI,-PI/6.,PI/6.,-PI/3.,PI/3.,-2.*PI/3.,2.*PI/3.,-5.*PI/6.,5.*PI/6.,-PI/2.,PI/2.]:
				var angle: float=base_angle+turn
				var direction: Vector3=world.adapter.root.global_basis*Vector3(sin(angle),0,cos(angle))
				var eye := center+direction*1.6+Vector3.UP*.25
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,center,1,[world.player.get_rid()]))
				if hit.is_empty() or hit.collider==body or body.is_ancestor_of(hit.collider) or hit.position.distance_to(center)<.03:
					world.player.camera.global_position=eye;found=true;break
			check(found,"clear line of sight for furnishing review: "+str(row.id))
			if not found:continue
			world.player.camera.look_at(center)
			world.player.camera.make_current()
			world.player.set_lamp_enabled(true)
			await get_tree().create_timer(.15).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("clearance_%02d_%s.png" % [moved,row.id]))
	check(unresolved==0,"every selected furnishing has a safe finish-clear placement")
	print("FURNISHING CLEARANCE: inspected=%d moved=%d unresolved=%d failures=%d" % [report.items.size(),moved,unresolved,failures.size()])
	world.player.camera.global_transform=camera_pose
	world.player.set_lamp_enabled(lamp_on)
	world.player.set_physics_process(physics_on)
