extends Node
## Sink-local installation survey and combined plumbing/trim diagnostics.
var checks:=0
var installed_failures: Array[String]=[]
var stance_rows: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:installed_failures.append(label);push_error(label)

func run(world: OrisonV2RuntimeRoot,directory: String) -> Dictionary:
	var rows: Array=[];var failures: Array[String]=[]
	var photo_only:=OS.get_environment("V2_PLUMBING_PHOTO_ONLY")=="1"
	var prior: Dictionary={}
	var photo_units:=OS.get_environment("V2_PLUMBING_PHOTO_UNITS").split(",")
	if photo_only:prior=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("V2_PLUMBING_STANCES")))
	for fixture: String in ["bath_sink","shower"]:
		var legacy:=TapProp.new();legacy.fixture=fixture;legacy.set_boiler_temperature(.8);legacy.set_stopper(true)
		legacy.set_valve_opening(0,.5);legacy.set_valve_opening(1,.25);legacy._process(1.)
		check(is_equal_approx(legacy.get_flow_state().flow,.75) and is_equal_approx(legacy.get_flow_state().temperature,.8*.5/.75),"unmodified default water API retains supplied mixture: "+fixture)
		check(is_equal_approx(legacy.get_flow_state().water_level,.075*.75),"unmodified default water API retains basin integration: "+fixture)
		legacy.free()
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false);world.player.carried_device.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var baseboards:=0;var caps:=0;var eye_rails:=0
	for draw: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if draw.name not in ["HistoricMillwork","PublicWainscotCap"]:continue
		var room:=draw.get_parent() as Node3D
		var record: Dictionary={}
		for space: Dictionary in world.layout.spaces:
			if space.id==str(room.name):record=space;break
		if record.is_empty():continue
		var floor_y: float=world.adapter.root.level_y[str(record.level)]
		for index in draw.multimesh.instance_count:
			var at: Vector3=(world.adapter.root.global_transform.affine_inverse()*draw.global_transform*draw.multimesh.get_instance_transform(index)).origin
			if draw.name=="PublicWainscotCap":caps+=1
			elif absf(at.y-floor_y-.07)<.02:baseboards+=1
			elif absf(at.y-floor_y-1.65)<.025:eye_rails+=1
	if eye_rails!=0 or baseboards<200 or caps==0:failures.append("Eye rail removal/baseboard-panel-cap retention")
	# Keep only durable sink owners before awaiting input. Unrelated NPC
	# presentation children can legitimately be freed during the long review.
	var sinks: Array[TapProp]=[]
	for node: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if node is TapProp and node.fixture=="kitchen_sink":sinks.append(node)
	for tap: TapProp in sinks:
		var excluded: Array[RID]=[]
		for body: CollisionObject3D in tap.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
		var points: Array=[]
		for x: float in [-.095,0.,.095]:
			for y: float in [.22,.64,1.01]:
				var query:=PhysicsRayQueryParameters3D.create(tap.to_global(Vector3(x,y,.24)),tap.to_global(Vector3(x,y,1.24)),1,excluded)
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty():points.append({"x":x,"y":y,"missing":true});continue
				var local: Vector3=tap.to_local(hit.position)
				points.append({"x":x,"y":y,"z":local.z,"owner":str(world.get_path_to(hit.collider))})
		rows.append({"unit":tap.unit,"compact":tap.compact_kitchen,"drainboard":tap.has_drainboard,"sink_name":str(tap.name),"rim_y":tap.kitchen_rim_height(),"ports":points})
		if OS.get_environment("V2_PLUMBING_INSTALLED")=="1" and not photo_only:
			await installed(world,tap)
		if (photo_only and tap.unit in photo_units) or (not photo_only and (OS.get_environment("V2_PLUMBING_INSTALLED")=="1" or tap.unit in ["2A","4B","5B"])):
			camera.make_current()
			camera.global_position=tap.to_global(Vector3(.62,.70,-1.4));camera.look_at(tap.to_global(Vector3(.02,.53,.08)));camera.fov=56.
			if photo_only:
				var positioned:=false
				for stance: Dictionary in prior.get("stances",[]):
					if stance.unit!=tap.unit or not stance.found:continue
					var values: PackedStringArray=str(stance.feet).trim_prefix("(").trim_suffix(")").split(",")
					if values.size()!=3:continue
					camera.global_position=Vector3(values[0].to_float(),values[1].to_float()+world.player.CROUCH_EYE,values[2].to_float())
					camera.look_at(tap.to_global(Vector3(.12,.58,.08)));camera.fov=68.;positioned=true;break
				if not positioned:failures.append("Missing verified photo stance: "+tap.unit);continue
			for frame in 6:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("sink_"+tap.unit+".png"))
	failures.append_array(installed_failures)
	var result: Dictionary={"evidence_class":"INERT","scope":"Production sink ports, actual installed stop input, supplied flow, native clearance and household restoration; no continuous route/disk/acceptance proof","sinks":rows,"eye_rails":eye_rails,"baseboards":baseboards,"panel_caps":caps,"checks":checks,"stances":stance_rows,"failures":failures}
	if photo_only:result["scope"]="Photo renewal from previously verified crouch poses; mechanics not rerun and no runtime/route acceptance."
	FileAccess.open(directory.path_join("plumbing_review.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SINK PLUMBING REVIEW: sinks=",rows.size()," eye_rails=",eye_rails," retained_baseboards=",baseboards," panel_caps=",caps," failures=",failures.size())
	camera.free();return result

func installed(world: OrisonV2RuntimeRoot,sink: TapProp) -> void:
	var owner: Node3D=sink.get("supply_stops")
	check(is_instance_valid(owner),"installed native service owner: "+sink.unit)
	if not is_instance_valid(owner):return
	check(world.household_state._subjects.get(str(owner.name))==owner,"existing household domain discovers service stops: "+sink.unit)
	var before: Dictionary=world.household_state.snapshot()
	var template: Dictionary=owner.record
	var excluded: Array[RID]=[]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	# Test actual installed riser clearance, including the parent's bowl and
	# the independent stand/countertop. Only the new plumbing excludes itself.
	for x: float in [-.095,.095]:
		for i in 24:
			var y: float=lerpf(.27,float(template.rim_y)+.055,float(i)/23.)
			var shape:=SphereShape3D.new();shape.radius=.00904
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=excluded;query.transform=Transform3D(Basis.IDENTITY,sink.to_global(Vector3(x,y,float(template.riser_z))))
			var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,4)
			check(hits.is_empty(),"native riser clears existing bowl/stand/worktop: "+sink.unit+str([x,y])+str(hits))
	# Metre rays preserve determinant precision on small physical facets.
	# Test the new seat alone, separately from the original wall and from
	# unobstructed actual hand rays below. This is not access evidence.
	var other_bodies: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not owner.is_ancestor_of(body):other_bodies.append(body.get_rid())
	for port: Vector3 in [Vector3(.04,.64+float(template.rim_y)-.9,float(template.wall_z)),Vector3(-.076,.22,float(template.wall_z)),Vector3(.114,.22,float(template.wall_z))]:
		var wall_ray:=PhysicsRayQueryParameters3D.create(sink.to_global(port-Vector3.BACK*.08),sink.to_global(port+Vector3.BACK*.015))
		wall_ray.exclude=excluded
		var wall_hit:=world.get_world_3d().direct_space_state.intersect_ray(wall_ray)
		check(not wall_hit.is_empty() and "/Wall" in str(wall_hit.collider.get_path()) and sink.to_local(wall_hit.position).distance_to(port)<.00004,"actual wall meets service-seat datum: "+sink.unit+str(port))
		var behind:=PhysicsRayQueryParameters3D.create(sink.to_global(port+Vector3.BACK*.5),sink.to_global(port-Vector3.BACK*.5),1,other_bodies)
		var seat_hit:=world.get_world_3d().direct_space_state.intersect_ray(behind)
		check(not seat_hit.is_empty() and owner.is_ancestor_of(seat_hit.collider) and sink.to_local(seat_hit.position).distance_to(port)<.00004,"imported annular service seat bears on actual wall: "+sink.unit+str(port))
	var player: PlayerController=world.player;player.camera.make_current();player.end_inspection();player.cancel_manipulation();player.call_locked=false;player.mouse_released=false
	var hand:=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();add_child(hand);hand.player=player
	# Find a supported, collision-free crouching stance with a clear actual ray
	# to both handwheels. These placements are not continuous walked routes.
	var stance:=false
	var obstructions: Dictionary={}
	var offsets: Array[float]=[0.]
	for i in 10:offsets.append(-.08*(i+1));offsets.append(.08*(i+1))
	for row in 13:
		var z: float=-.55-.08*row
		if stance:break
		for x: float in offsets:
			var foot:=sink.to_global(Vector3(x,.025,z))
			var floor_ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.03,foot-Vector3.UP*.08,1,[player.get_rid()])
			var bearing:=world.get_world_3d().direct_space_state.intersect_ray(floor_ray)
			if bearing.is_empty() or bearing.normal.y<.99:obstructions["unsupported"]=int(obstructions.get("unsupported",0))+1;continue
			foot.y=bearing.position.y+.025
			var capsule:=CapsuleShape3D.new();capsule.radius=player._capsule.radius;capsule.height=player.CROUCH_HEIGHT
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.margin=.001;query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,foot+Vector3.UP*(player.CROUCH_HEIGHT*.5))
			var blockers:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
			if not blockers.is_empty():
				var label: String="body: "+str(blockers[0].collider.get_path());obstructions[label]=int(obstructions.get(label,0))+1;continue
			var eye:=foot+Vector3.UP*player.CROUCH_EYE;var visible:=true
			for wheel: Node3D in owner.wheels:
				for angle_index in 24:
					var angle:=TAU*angle_index/24.
					var point:=wheel.to_global(Vector3(.021*cos(angle),.021*sin(angle),-.004))
					var ray:=PhysicsRayQueryParameters3D.create(eye,eye+(point-eye).normalized()*2.1);ray.exclude=[player.get_rid()];ray.collide_with_areas=true
					var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
					if hit.is_empty() or not wheel.is_ancestor_of(hit.collider):
						var label: String="ray: "+str(hit.get("collider"));obstructions[label]=int(obstructions.get(label,0))+1;visible=false;break
				if not visible:break
			if not visible:continue
			player.global_position=foot;player._set_crouched(true);stance=true;break
	check(stance,"supported crouching stance reaches both actual stop wheels: "+sink.unit)
	stance_rows.append({"unit":sink.unit,"found":stance,"feet":str(player.global_position) if stance else "","obstructions":obstructions})
	if stance:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		sink.set_hot(true);sink.set_cold(true)
		for index in 2:
			check(await hand.operate(owner.wheels[index].to_global(Vector3(.021,0,-.004)),0.,sink),"installed actual grab/turn/release closes stop: "+sink.unit+str(index))
		check(hand.follows_cursor,"installed handwheel follows cursor: "+sink.unit)
		check(is_zero_approx(sink.get_flow_state().flow) and not sink._stream.visible,"installed stops isolate retained faucet flow: "+sink.unit)
		player.camera.look_at(sink.to_global(Vector3(0,.48+float(template.rim_y)-.9,.085)))
		await get_tree().physics_frame
		var pipe_ray:=PhysicsRayQueryParameters3D.create(player.camera.global_position,player.camera.global_position-player.camera.global_basis.z*2.1,1,[player.get_rid()]);pipe_ray.collide_with_areas=true
		var pipe_hit:=world.get_world_3d().direct_space_state.intersect_ray(pipe_ray)
		check(not pipe_hit.is_empty() and owner.is_ancestor_of(pipe_hit.collider),"actual pointer reaches native fixed waste pipe: "+sink.unit)
		hand.click()
		check(not player._grab.active() and sink._valve_openings==Vector2.ONE,"fixed pipe click cannot trigger ancestor faucet toggle: "+sink.unit)
		var saved: Dictionary=world.household_state.snapshot()
		check(world.household_state.validate(saved,world.household_state._kinds),"household save validates fitted stops: "+sink.unit)
		owner.restore_mechanism({"hot":1.,"cold":1.})
		world.household_state._restore(saved)
		var saved_stops: Dictionary=saved.records[str(owner.name)].value
		check(owner.openings==Vector2(float(saved_stops.hot),float(saved_stops.cold)) and sink._valve_openings==Vector2.ONE and is_zero_approx(sink.get_flow_state().flow),"household restore retains exact saved stop fractions and independent upper knobs: "+sink.unit+str(owner.openings)+str(sink._valve_openings)+str(saved_stops))
		if sink.unit=="2A":
			var old_save:=saved.duplicate(true)
			for identity: String in old_save.records.keys():
				if identity.begins_with("KitchenPlumbing_"):old_save.records.erase(identity)
			world.household_state._restore(old_save)
			check(owner.openings==Vector2.ONE,"older saves default new service stops open")
			player.camera.look_at(owner.wheels[0].to_global(Vector3(.021,0,-.004)));await get_tree().physics_frame;hand.click()
			check(player.begin_inspection(),"installed inspection camera has a clear approach")
			if player.inspecting():
				var anchor:=player.camera.global_transform
				Input.warp_mouse(player.camera.unproject_position(owner.wheels[0].to_global(Vector3(.021,0,-.004))))
				await get_tree().physics_frame;hand.click()
				check(player._grab.active() and player._grab.target.owner==sink,"static inspection cursor selects actual stop wheel in retained faucet context")
				if player._grab.active():check(await hand.move_to(owner.TRAVEL*.5),"inspection cursor turns service mechanism")
				hand.click();check(player.camera.global_transform.is_equal_approx(anchor),"service manipulation retains static inspection camera")
				player.end_inspection()
	player.cancel_manipulation();player.end_inspection();world.household_state._restore(before);hand.free()
