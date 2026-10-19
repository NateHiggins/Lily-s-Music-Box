extends Node3D
## Isolated native-bank actual input/custody bench, not played-room proof.
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd")
var failures: Array[String]=[]
var checks: Array[Dictionary]=[]
var bank: MailBankProp
var player: PlayerController

func _ready() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> bool:
	checks.append({"ok":ok,"label":label});print("MAIL HAND CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
	return ok
func click() -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func aim(point: Vector3) -> void:
	player.camera.look_at(point);await get_tree().physics_frame;await get_tree().physics_frame;player.camera.look_at(point)
func shot(name: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	for identity: String in RealityCases.definitions:RealityState.ensure_case(identity,str(RealityCases.definitions[identity].get("resident_id","")))
	var floor: StaticBody3D=StaticBody3D.new();add_child(floor)
	var collision: CollisionShape3D=CollisionShape3D.new();var shape: BoxShape3D=BoxShape3D.new();shape.size=Vector3(4,.2,4);collision.shape=shape;collision.position.y=-.1;floor.add_child(collision)
	var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,150,0);sun.light_energy=1.2;add_child(sun)
	var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.12,.12);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.45;add_child(environment)
	bank=MailBankProp.new();bank.set_meta("v2_mail_bank_visuals",true);add_child(bank)
	player=PlayerController.new();player.position=Vector3(-.155,.025,-.9);add_child(player);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	var before: String=JSON.stringify(RealityState.data.get("mail_taken",[]))
	var door_point: Vector3=bank._hinge.to_global(Vector3(bank.LEAF_W*.5,-.008,0))
	await aim(door_point)
	check(player._grab.find_target().get("owner")==bank,"actual native leaf is ray selected")
	click();check(player._grab.active() and is_zero_approx(bank._hinge.rotation.y),"click holds leaf without opening or mail grant");click()
	check(JSON.stringify(RealityState.data.get("mail_taken",[]))==before,"unmoved leaf release grants no mail")
	check(await hand.operate(door_point,deg_to_rad(95.),bank),"mouse opens native leaf to its actual stop")
	await shot("opened_native_bank")
	var highest: MeshInstance3D=null
	for article: Dictionary in bank._hand_controls.articles.values():
		var part: MeshInstance3D=article.stocks[0].part
		if highest==null or part.global_position.y>highest.global_position.y:highest=part
	if check(highest!=null,"due catalogue deliveries have physical stock"):
		var bounds: AABB=highest.get_aabb()
		await aim(highest.to_global(bounds.get_center()))
		var candidate: Dictionary=player._grab.find_target()
		if not candidate.has("article_id"):
			var ray: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(player.camera.global_position,highest.to_global(bounds.get_center()),1,[player.get_rid()]);ray.collide_with_areas=true
			print("MAIL PICK DIAGNOSTIC: ",bank.get_world_3d().direct_space_state.intersect_ray(ray)," candidate=",candidate," bounds=",bounds," point=",highest.to_global(bounds.get_center())," camera=",player.camera.global_position)
		if check(candidate.get("owner")==bank and candidate.has("article_id"),"actual ray selects a due article"):
			var identity: String=str(candidate.article_id)
			click();check(player._grab.active() and JSON.stringify(RealityState.data.get("mail_taken",[]))==before,"article grab alone grants nothing");click()
			check(JSON.stringify(RealityState.data.get("mail_taken",[]))==before,"unmoved article release grants nothing")
			check(await hand.operate(highest.to_global(bounds.get_center()),.06,bank),"article can be pulled partway and released")
			check(JSON.stringify(RealityState.data.get("mail_taken",[]))==before,"short pull stays in physical custody")
			check(bank._hinge.rotation.y>1.6,"collecting never closes the held-open leaf")
			await shot("partly_withdrawn_mail")
			var closing_point: Vector3=bank._hinge.to_global(Vector3(bank.LEAF_W*.5,-.008,0))
			check(not await hand.operate(closing_point,0.,bank) and bank._hinge.rotation.y>.01,"actual closing hand motion stops on the protruding article")
			check(await hand.operate(bank._hinge.to_global(Vector3(bank.LEAF_W*.5,-.008,0)),deg_to_rad(95.),bank),"obstructed leaf can be reopened without collecting the article")
			check(JSON.stringify(RealityState.data.get("mail_taken",[]))==before,"obstructed closing never grants mail custody")
			check(await hand.operate(highest.to_global(bounds.get_center()),.25,bank),"mouse withdraws due article beyond the pocket and releases it")
			check(identity in RealityState.data.get("mail_taken",[]),"only actual withdrawn article reaches existing mail custody")
			check(not player.call_locked and not bank._panel.attention_active(),"physical mail creates no case dialogue overlay")
			check(bank._hinge.rotation.y>1.6,"taking mail does not automatically close leaf")
	var snapshot: Dictionary=bank.mechanism_snapshot()
	check(bank.valid_mechanism(snapshot),"source-bound physical mechanism snapshot validates")
	var bad: Dictionary=snapshot.duplicate(true);bad.pulls["invented_letter"]=.1
	check(not bank.valid_mechanism(bad),"invented catalogue identities cannot restore a letter")
	bank.restore_mechanism(snapshot)
	check(bank.mechanism_snapshot()==snapshot,"physical positions restore without custody changes")
	await shot("mail_after_collection")
	await aim(bank._hinge.to_global(Vector3(bank.LEAF_W*.5,-.008,0)))
	click()
	var space: InputEventKey=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	check(player.inspecting() and player.inspect_owner==bank,"grab and Space enter the bank's physical inspection view")
	if player.inspecting():
		var pose: Transform3D=player.camera.global_transform
		var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.relative=Vector2(80,10);player._unhandled_input(motion)
		await get_tree().physics_frame;await get_tree().physics_frame
		check(player.camera.global_transform.is_equal_approx(pose) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"inspection camera stays fixed while the selection cursor moves")
		await shot("mail_inspection")
		space.pressed=false;player._unhandled_input(space);space.pressed=true;player._unhandled_input(space)
		check(not player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Space backs out to the ordinary player view")
	hand.free();player.cancel_manipulation();player.free();bank.free();floor.free();sun.free();environment.free()
	print("V2 MAIL HAND BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
