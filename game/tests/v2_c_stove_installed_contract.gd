extends "res://tests/v2_flue_airway_contract.gd"
## Installed physical construction and actual player input; no walked-route grant.
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand
const Survey=preload("res://tests/v2_c_stove_stack_survey.gd")

func _additional_scope() -> String:
	return "Also verifies installed C-stack airway, five furnished-room closures, standing service capsules, actual grab/motion/release and static cursor inspection, and retained structural roof coupling. Camera placements are diagnostics, not walked approaches or human acceptance."

func _additional_checks(world: OrisonV2RuntimeRoot) -> void:
	await super._additional_checks(world)
	var root: Node3D=world.adapter.root
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/acoustic_flue.json"))
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://..").path_join("art/data/c_stove_stack/source_plan.json")))
	var stock:=root.get_node_or_null("CStoveStack") as Node3D
	_check(stock!=null and stock.find_children("*","MeshInstance3D",true,false).size()==4,"qualified native four-material stack is installed")
	var proxy:=root.get_node("C_STOVE_FLUE") as Node3D
	_check(not proxy.visible,"rectangular reservation render retired")
	for body: CollisionObject3D in proxy.find_children("*","CollisionObject3D",true,false):_check(body.collision_layer==0,"native bore replaces generic reservation collision")
	var player: PlayerController=world.player
	player.set_physics_process(false);player.call_locked=false;player.mouse_released=false;player.camera.make_current();player.set_lamp_enabled(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var physical:=world.get_world_3d().direct_space_state
	var hand:=Hand.new();hand.player=player;add_child(hand)
	var room_count:=0
	var release_observations: Array=[]
	for row: Dictionary in data.nodes:
		if row.physical_role!="thimble":continue
		var prop:=world.adapter.resolve(str(row.id)) as FlueBreastProp
		_check(prop!=null and prop.visible_mesh_count()==13,"real original-authority native closure: "+str(row.id))
		if prop==null:continue
		var p: Vector3=root.to_local(prop.global_position)
		var feet:=Vector3(p.x-.78,p.y+.003,p.z-.12)
		var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(root.global_basis,root.to_global(feet+Vector3.UP*capsule.height*.5));query.collision_mask=1;query.exclude=[player.get_rid()]
		var obstructions: Array=[]
		for hit: Dictionary in physical.intersect_shape(query,32):obstructions.append(str(world.get_path_to(hit.collider)))
		_check(obstructions.is_empty(),"full actual standing service capsule: "+str(row.id)+" "+str(obstructions))
		# Start behind the sealed plate: this checks construction bores without
		# pretending the still-sealed room plate is an open smoke outlet.
		for offset: Vector2 in [Vector2.ZERO,Vector2(.06,0),Vector2(-.06,0),Vector2(0,.06),Vector2(0,-.06)]:
			var a:=Vector3(7.06,p.y+1.44+offset.y,p.z+offset.x);var b:=a;b.x=7.74
			var hit:=physical.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(b),1,[player.get_rid()]))
			_check(hit.is_empty(),"actual partition, outer leaf and native round sleeve bore: "+str(row.id)+str(offset)+" "+str(hit.get("collider","clear")))
		player.global_position=root.to_global(feet);player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
		var contact: Vector3=prop._cap.to_global(Vector3(0,-.01,-.023));player.camera.look_at(contact)
		await get_tree().physics_frame;await get_tree().physics_frame
		_check(player._grab.find_target().get("owner")==prop,"furnished-room cursor reaches installed closure: "+str(row.id))
		_check(await hand.operate(contact,Vector3(.002,-.001,-.003).length(),prop),"actual click, constrained mouse travel and release: "+str(row.id))
		var released_at:=Time.get_ticks_msec()/1000.
		var release_tween: Tween=prop._settle
		await get_tree().create_timer(.35).timeout
		# _last_action records receipt before FunctionalProp's delayed delivery.
		# Observe the actual motion owner instead: only a new conductor delivery
		# can replace this release tween while no further hand input is sent.
		var deadline:=Time.get_ticks_msec()+2000
		while is_same(prop._settle,release_tween) and release_tween!=null and release_tween.is_running() and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
		var later_motion: bool=not is_same(prop._settle,release_tween)
		release_observations.append({"id":row.id,"released_at_s":released_at,"last_received_event_s":prop._last_action,"release_tween_replaced":later_motion,"pose":prop._pose_amount,"held":prop._held})
		_check(not prop._held and prop._pose_amount>=0 and prop._pose_amount<=1 and (later_motion or is_zero_approx(prop._pose_amount)),"release reseats unless an observed later conductor tween replaces it: "+str(row.id))
		player.camera.look_at(prop._cap.to_global(Vector3(0,-.01,-.023)))
		await get_tree().physics_frame;hand.click();_check(player._grab.active(),"reacquire for actual inspection: "+str(row.id))
		var prior:=player.camera.global_transform;var space:=InputEventAction.new();space.action="jump";space.pressed=true;player._unhandled_input(space)
		_check(player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Space opens static cursor inspection: "+str(row.id))
		var anchor:=player.camera.global_transform;await get_tree().create_timer(.25).timeout
		_check(player.camera.global_transform.is_equal_approx(anchor),"inspection camera stays static: "+str(row.id))
		Input.warp_mouse(player.camera.unproject_position(prop._cap.to_global(Vector3(0,-.01,-.023))))
		await get_tree().process_frame;await get_tree().physics_frame;hand.click()
		_check(player._grab.active(),"visible inspection cursor acquires actual plate: "+str(row.id))
		_check(await hand.move_to(Vector3(.002,-.001,-.003).length()),"actual constrained manipulation inside inspection: "+str(row.id))
		hand.click();await _installed_shot(str(row.id)+"_inspection")
		player._unhandled_input(space)
		_check(not player.inspecting() and player.camera.global_transform.is_equal_approx(prior),"Space restores service eye: "+str(row.id))
		await _installed_shot(str(row.id));room_count+=1
	_check(room_count==5,"all five installed furnished-room programmes executed")
	hand.free()
	for x: float in [7.60,7.74,7.88]:
		for z: float in [9.85,10.05,10.25]:
			var a:=Vector3(x,-3.18,z);var b:=Vector3(x,21.5,z)
			var hit:=physical.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(b),1,[player.get_rid()]))
			_check(hit.is_empty(),"continuous installed shaft through ground, six levels and roof: "+str(Vector2(x,z))+" "+str(hit.get("collider","clear"))+" "+str(hit.get("position","none")))
	var control:=physical.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(Vector3(7.74,17.,10.05)),root.to_global(Vector3(7.4,17.,10.05)),1,[player.get_rid()]))
	_check(not control.is_empty() and str(root.get_path_to(control.collider)).begins_with("CStoveStack/"),"positive control hits actual native masonry beside airway")
	var helper:=Survey.new();var boxes: Array[CollisionShape3D]=[]
	for owner: String in plan.masonry_coupling.owners:
		var floor:=root.get_node_or_null(owner+"/Collision") as StaticBody3D
		_check(floor!=null,"real retained roof slab owner: "+owner)
		if floor!=null:
			for shape: CollisionShape3D in floor.get_children():
				if shape.shape is BoxShape3D and not shape.disabled:boxes.append(shape)
	var points: Array=plan.masonry_coupling.points_local_godot
	for segment in points.size()-1:
		var a:=Vector3(points[segment][0],points[segment][1],points[segment][2]);var b:=Vector3(points[segment+1][0],points[segment+1][1],points[segment+1][2]);var intervals: Array=[]
		for shape: CollisionShape3D in boxes:
			var frame: Transform3D=shape.global_transform.affine_inverse()*root.global_transform
			var interval: Array=helper._interval(frame*a,frame*b,(shape.shape as BoxShape3D).size)
			if not interval.is_empty():intervals.append(interval)
		intervals.sort_custom(func(one: Array,two: Array):return one[0]<two[0])
		var covered:=0.;var continuous:=not intervals.is_empty()
		for interval: Array in intervals:
			if float(interval[0])>covered+.00001/a.distance_to(b):continuous=false
			covered=maxf(covered,float(interval[1]))
		_check(continuous and covered>=1.-.000001,"entire vibration route is structural concrete, without stairwell shortcut: "+str(segment))
	helper.free()
	for view: Array in [["stack_alley",Vector3(9.3,2.,11.3),Vector3(7.74,1.6,10.05)],["stack_roof",Vector3(9.6,21.,12.1),Vector3(7.74,20.3,10.05)]]:
		var eye: Vector3=root.to_global(view[1]);player.global_position+=eye-player.camera.global_position;player.camera.look_at(root.to_global(view[2]));await _installed_shot(str(view[0]))
	additional_contracts.c_stove_installation={"executed":true,"status":"PENDING","furnished_room_hands":room_count,"release_observations":release_observations,"bore_rays":25,"vertical_airway_rays":9,"structural_segments":3,"walked_approach":false}

func _installed_shot(identity: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	for frame in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(identity+".png"))==OK,"installed voxel-light diagnostic: "+identity)
