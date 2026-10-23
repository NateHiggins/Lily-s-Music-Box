extends Node
## Run inside an already composed V2 world; no extra world startup.
var failures: Array[String]=[]
var observations: Array=[]
var checks := 0
var grabs := 0

func check(ok: bool,label: String) -> void:
	checks+=1;print("VANTRY CEILING: ",label," = ",ok)
	if not ok:failures.append(label)

func click(player: PlayerController) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)

func space(player: PlayerController) -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.keycode=KEY_SPACE;event.pressed=true
	player._unhandled_input(event)

func drag(player: PlayerController,goal: float) -> void:
	for step in 40:
		if not player._grab.active():return
		var target: Dictionary=player._grab.target
		var before: float=target.read.call()
		if absf(before-goal)<.0001:return
		var point: Vector3=target.part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*target.axis
		var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24. and absf(axis.dot(player.camera.global_basis.z))>.5:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
		var pixels: float=minf(16.,absf(goal-before)/.05*160.)
		var event:=InputEventMouseMotion.new();event.relative=screen.normalized()*pixels*signf(goal-before)
		player._unhandled_input(event)
		await get_tree().physics_frame

func run(world: Node3D,directory: String) -> Dictionary:
	var heads: Array=world.find_children("*","",true,false).filter(func(node):return node is VantryPointProp)
	check(heads.size()==1,"survey covers the one existing composed V2 listening head")
	var point: VantryPointProp=world.vantry_points.active_owner
	check(is_instance_valid(point),"network retains original active owner")
	if not is_instance_valid(point):return {"checks":checks,"failures":failures}
	var original_repaired:=point.is_repaired()
	var mount: Vector3=point.global_position
	var maximum_gap:=0.
	for offset in [Vector3.ZERO,Vector3(.075,0,0),Vector3(-.075,0,0),Vector3(0,0,.075),Vector3(0,0,-.075)]:
		var query:=PhysicsRayQueryParameters3D.create(mount+offset-Vector3.UP*.15,mount+offset+Vector3.UP*.25,1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"original ceiling exists above mounting plate: "+str(offset))
		if not hit.is_empty():
			var gap: float=hit.position.y-mount.y;maximum_gap=maxf(maximum_gap,absf(gap))
			check(absf(gap)<.001,"backplate is flush within 1mm: "+str(offset))
	var player: PlayerController=world.player
	player.global_position=world.adapter.root.to_global(Vector3(-9.2,3.2,1.4));player.velocity=Vector3.ZERO
	player.set_mouse_released(false)
	var contact:=point._grille.to_global(Vector3(0,-.066,0))
	player.camera.look_at(contact)
	await get_tree().physics_frame;await get_tree().physics_frame
	var available: Dictionary=player._grab.find_target()
	check(available.get("part")==point._grille,"standing worker targets specific ceiling grille within reach")
	click(player)
	check(player._grab.active() and player._grab.target.get("part")==point._grille,"primary click grabs actual grille")
	if player._grab.active():
		grabs+=1;await drag(player,.05)
		check(point._grille_open>.999,"mouse pull reaches captive travel limit")
		space(player)
		check(player.inspecting() and player.inspect_owner==point,"Space enters supported ceiling inspection")
	if player.inspecting():
		var cursor: Vector2=player.camera.unproject_position(point._grille.to_global(Vector3(0,-.066,0)))
		Input.warp_mouse(cursor)
		for frame in 12:
			await get_tree().process_frame
			if get_viewport().get_mouse_position().distance_to(cursor)<2.:break
		await get_tree().physics_frame
		var aimed: Dictionary=player._grab.find_target()
		check(aimed.get("part")==point._grille,"inspection free cursor identifies movable grille")
		click(player)
		check(player._grab.active(),"free cursor click reacquires grille")
		if player._grab.active():
			grabs+=1;await drag(player,0.)
			check(point._grille_open<.001,"mouse push closes captive grille")
			click(player)
			check(not player._grab.active(),"next click releases at closed limit")
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("vantry_inspection.png"))==OK,"captured mounted inspection")
		space(player)
	check(not player.inspecting(),"Space restores worker camera")
	check(point.is_repaired()==original_repaired,"grille gesture cannot invent capsule repair")
	player.camera.look_at(point.global_position)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join("vantry_ceiling.png"))==OK,"captured flush ceiling mount")
	observations.append({"point_id":point.point_id,"mount":str(mount),"maximum_plate_gap_m":maximum_gap,"heads":heads.size(),"grabs":grabs})
	return {"checks":checks,"failures":failures,"observations":observations,"grabs":grabs}
