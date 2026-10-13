extends Node3D
## Focused native bench: cabinet, main and removable fuse input proof.
## Installed disk reconstruction and continuous access have separate suites.
var player: PlayerController
var panel: FusePanelProp
var checks: Array[Dictionary] = []
var out := ""
var batch_mode := false

func _ready() -> void:
	if not batch_mode: _run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	print("FUSE HAND CHECK: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	player._unhandled_input(event)

func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative=relative
	player._unhandled_input(event)

func depth(distance: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_WHEEL_DOWN if distance>0 else MOUSE_BUTTON_WHEEL_UP
	event.factor=absf(distance)/.025
	event.pressed=true
	player._unhandled_input(event)

func aim(at: Vector3) -> void:
	if player.inspecting(): Input.warp_mouse(player.camera.unproject_position(at))
	else: player.camera.look_at(at)
	await get_tree().physics_frame
	await get_tree().physics_frame

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))

func _run() -> void:
	RealityState.persistence_enabled=false
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty(): out="user://fuse_hand_bench"
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.11,.12,.14)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.9,.94,1)
	env.environment.ambient_light_energy=.6
	add_child(env)
	var lamp := OmniLight3D.new()
	lamp.position=Vector3(.4,1.2,1)
	lamp.light_energy=2
	add_child(lamp)
	panel=FusePanelProp.new()
	panel.name="B1_FUSE_PANEL"
	# The production adapter creates this retained cabinet before actor _ready.
	var back := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=Vector3(.66,.90,.12)
	back.mesh=box
	back.position=Vector3(0,.5,-.06)
	panel.add_child(back)
	add_child(panel)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="B1_FUSE_PANEL")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var path := "user://fuse_hand_native_bench.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	var mounted := factory.mount(self,path)
	check(mounted,"actual native panel payload and owner bind")
	if not mounted:
		print("NATIVE BIND ERRORS: ",factory.errors)
		get_tree().quit(1)
		return
	player=PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.position=Vector3(.1,-1.05,1.2)
	player.camera.current=true
	player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	var original := panel.maintenance_snapshot()
	click()
	check(player._grab.active(),"primary click hits native knife handle")
	check(panel._service_panel==null,"handle does not open a minigame")
	check(is_zero_approx(panel._hand_controls.main_angle),"grab alone does not switch")
	var camera_before := player.camera.global_transform
	for i in 5:
		motion(Vector2(0,8))
		await get_tree().physics_frame
	check(panel._hand_controls.main_angle>.09 and panel.main_open,"mouse pulls blades clear of live jaws")
	check(player.camera.global_transform.is_equal_approx(camera_before),"hand motion leaves camera fixed")
	var partial: float=panel._hand_controls.main_angle
	click()
	check(not player._grab.active() and is_equal_approx(partial,panel._hand_controls.main_angle),"release retains intermediate blade travel")
	check(not panel.panel_safe and panel.fitted_rating==30,"switch cannot certify or change the overfused circuit")
	await capture("knife_open")
	var saved := panel.mechanism_snapshot()
	var closed := saved.duplicate(true)
	closed.door=-.4;closed.main=0.0
	panel.restore_mechanism(closed)
	check(not panel.main_open,"restored closed blades restore electrical contact")
	panel.restore_mechanism(saved)
	check(panel.mechanism_snapshot()==saved and panel.main_open,"partial blade and cabinet poses round-trip")
	for invalid in [{"door":NAN,"main":0.0},{"door":0.0,"main":2.0},{"door":0.0}, {"door":0.0,"main":0.0,"extra":1}]:
		check(not panel.valid_mechanism(invalid),"reject malformed or nonfinite mechanical state")
	# Aim at the leaf's real transformed centre, not its historical node origin.
	await aim(panel._door.to_global(panel._door.get_aabb().get_center()))
	click()
	check(player._grab.active() and player._grab.target.get("part")==panel._hand_controls.door_pivot,"native cabinet leaf acquires its actual hinge")
	var before: float=panel._hand_controls.door_angle
	for i in 4:
		motion(Vector2(8,0))
		await get_tree().physics_frame
	check(absf(panel._hand_controls.door_angle-before)>.01,"mouse swings cabinet leaf")
	click()
	var released: float=panel._hand_controls.door_angle
	panel._balk(.2)
	await get_tree().create_timer(.3).timeout
	check(is_equal_approx(released,panel._hand_controls.door_angle),"electrical refusal cannot reset released cabinet angle")
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click()
	var inspect := InputEventKey.new()
	inspect.keycode=KEY_SPACE;inspect.physical_keycode=KEY_SPACE;inspect.pressed=true
	player._unhandled_input(inspect)
	check(player.inspecting(),"grab then Space enters fixed cabinet inspection")
	await capture("inspection")
	player.end_inspection()
	panel.restore_maintenance_snapshot(original)
	await _repair_by_hand()
	var failures := checks.filter(func(row): return not row.ok)
	var result := FileAccess.open(out.path_join("hand-controls.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Native cabinet and fuse repair through actual player input; no spatial acceptance","checks":checks,"failures":failures.size()},"\t"))
	print("FUSE HAND RESULT: ",checks.size()," checks, ",failures.size()," failures")
	player.cancel_manipulation()
	player.queue_free();panel.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func turn_to(goal: float) -> bool:
	for step in 400:
		if not player._grab.active(): return false
		var target: Dictionary=player._grab.target
		if target.kind!="hinge": return false
		var value: float=target.read.call()
		if absf(value-goal)<.002: return true
		var part: Node3D=target.part
		var point: Vector3=part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*target.axis
		var tangent: Vector3=axis.cross(point-part.global_position)
		var screen_axis: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		# A foreshortened handle is pulled toward/pushed away from the eye by
		# vertical hand motion, as in the normal player control.
		if screen_axis.length()<24 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
			screen_axis=Vector2(0,tangent.dot(player.camera.global_basis.z)*180)
		var delta: Vector2=screen_axis*clampf(goal-value,-.20,.20)
		motion(delta)
		await get_tree().physics_frame
	print("TURN STOP goal ",goal," actual ",player._grab.target.read.call() if player._grab.active() else "released")
	return false

func acquire_fuse(index: int) -> bool:
	var body: RigidBody3D=panel._hand_controls.plugs.rows[index].body
	await aim(body.to_global(Vector3(.032,0,.024)))
	click()
	return player._grab.active() and player._grab.target.part==body

func carry_to(index: int,point: Vector3) -> bool:
	var body: RigidBody3D=panel._hand_controls.plugs.rows[index].body
	for step in 100:
		if not player._grab.active(): return false
		var difference := point-body.position
		if difference.length()<.008: return true
		var from := body.to_global(player._grab.contact)
		var to := from+panel.global_basis*difference
		var distance := (to-from).dot((from-player.camera.global_position).normalized())
		var fraction := minf(1,.012/difference.length())
		if absf(distance)>.0001: depth(distance*fraction)
		from=body.to_global(player._grab.contact)
		to=from+panel.global_basis*(point-body.position)
		motion((player.camera.unproject_position(to)-player.camera.unproject_position(from))*fraction)
		await get_tree().physics_frame
	print("CARRY STOP ",index," at ",body.position," rotation ",body.rotation," wanted ",point," blocking ",panel._hand_controls.plugs.last_block)
	return false

func _repair_by_hand(reset_fixture := true) -> void:
	var plugs: RefCounted=panel._hand_controls.plugs
	# This snapshot is only a fixture boundary. Every service action below is
	# actual hit acquisition, mouse travel and release, never a preview/submit.
	var start := panel.mechanism_snapshot()
	if reset_fixture:
		start.main=0.0
		panel.restore_mechanism(start)
	await aim(panel._door.to_global(panel._door.get_aabb().get_center()))
	click();check(await turn_to(-2.15),"cabinet opened by hand for unobstructed inspection");click()
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click()
	var inspect := InputEventKey.new()
	inspect.keycode=KEY_SPACE;inspect.physical_keycode=KEY_SPACE;inspect.pressed=true
	player._unhandled_input(inspect)
	check(player.inspecting(),"full repair uses static inspection and freely selected cursor targets")
	var fixed_camera := player.camera.global_transform
	check(await acquire_fuse(0),"actual original thirty-amp plug can be grabbed")
	motion(Vector2(0,-12))
	await get_tree().physics_frame
	check(plugs.rows[0].turn==0.0 and panel.balking(),"live holder refuses physical unscrewing with audible feedback")
	click()
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click();check(await turn_to(1.25),"physical main opens completely before fuse withdrawal");click()
	check(await acquire_fuse(0),"isolated original plug acquired")
	check(await turn_to(plugs.THREAD_END*.4),"counterclockwise drag backs out the real threaded plug")
	click()
	var partway := panel.mechanism_snapshot()
	check(panel.plug_out and partway.plugs.items[0].turn>0,"partly unscrewed plug is not a protected electrical contact")
	check(await acquire_fuse(0),"released threaded plug reacquired")
	panel.restore_mechanism(partway)
	player._grab.validate()
	check(not player._grab.active(),"save restoration revokes a stale fuse hand")
	check(await acquire_fuse(0),"restored partly threaded plug acquired")
	check(await turn_to(plugs.THREAD_END),"counterclockwise rotation clears final thread")
	click()
	check(plugs.active_index()==-1,"released withdrawn plug leaves a genuinely empty holder")
	check(await acquire_fuse(0),"removed plug becomes a free object")
	check(await carry_to(0,Vector3(.145,.46,.27)),"mouse wheel pulls loose plug clear of panel face")
	check(await carry_to(0,Vector3(-.055,.46,.27)),"removed fuse clears the rack across the face")
	check(await carry_to(0,Vector3(-.055,.175,.27)),"removed fuse carried down beside spare rack")
	check(await carry_to(0,Vector3(.065,.175,.27)),"removed fuse passes in front of rack lip")
	check(await carry_to(0,Vector3(.065,.175,.165)),"removed fuse pushed onto lower shelf above lip")
	check(await carry_to(0,plugs.PARKS[0]),"removed fuse brought to empty rack place")
	click()
	check(plugs.rows[0].station==1,"removed original rests in the physical spare rack")
	check(await acquire_fuse(3),"twenty-amp spare is a separate selectable object")
	check(await carry_to(3,Vector3(.185,.31,.165)),"spare raised above shelf retaining lip")
	check(await carry_to(3,Vector3(.185,.305,.27)),"spare lifted clear of shelf lip")
	check(await carry_to(3,plugs.HOME+Vector3(0,0,plugs.THREAD_TRAVEL)),"oversized spare offered at actual holder mouth")
	click()
	check(plugs.active_index()==-1 and panel.offered_rating==20 and panel.balking(),"oversized repair is refused by retained service authority")
	check(await acquire_fuse(3),"refused spare remains a real recoverable object")
	check(await carry_to(3,Vector3(.185,.305,.27)),"refused spare carried in front of rack")
	check(await carry_to(3,Vector3(.185,.305,.165)),"refused spare pushed above shelf lip")
	check(await carry_to(3,plugs.PARKS[3]),"refused spare returned to rack")
	click()
	check(await acquire_fuse(2),"marked fifteen-amp spare selected physically")
	check(await carry_to(2,Vector3(.065,.31,.165)),"correct spare raised above shelf retaining lip")
	check(await carry_to(2,Vector3(.065,.305,.27)),"correct spare lifted clear of shelf lip")
	check(await carry_to(2,plugs.HOME+Vector3(0,0,plugs.THREAD_TRAVEL)),"correct plug delivered to holder mouth")
	click()
	check(plugs.active_index()==2 and panel.plug_out,"thread caught, but loose replacement is not yet electrically seated")
	check(await acquire_fuse(2),"replacement thread acquired")
	check(await turn_to(0.0),"clockwise mouse motion screws correct plug home")
	click()
	check(panel.protects_conductor() and not panel.panel_safe,"correct seating alone does not claim load proof")
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click();check(await turn_to(0.0),"physical main restores load");click()
	check(not panel.panel_safe,"contact closure alone does not bypass load proving time")
	await get_tree().create_timer(1.9).timeout
	check(panel.panel_safe and panel.load_proved and panel.fitted_rating==15 and panel._service_panel==null,"full repair publishes through original authority without a minigame")
	var completed := panel.mechanism_snapshot()
	check(panel.valid_mechanism(completed),"completed physical state satisfies strict save schema")
	var serialized: Dictionary=JSON.parse_string(JSON.stringify(completed))
	panel.restore_mechanism(start);panel.restore_mechanism(serialized)
	check(panel.panel_safe and panel.protects_conductor() and plugs.active_index()==2,"serialized physical identities and protection reconstruct")
	check(player.camera.global_transform.is_equal_approx(fixed_camera),"inspection camera stays fixed through complete repair")
	await aim(panel.to_global(Vector3(0,.5,.1)))
	await capture("repaired_panel")
	player.end_inspection()
