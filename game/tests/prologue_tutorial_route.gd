extends "res://tests/orison_v2_4b_door_route_test.gd"
## Actual waking/shower/mirror/cabinet/visitor slice; physical crossing and full opening remain unqualified.
const Director := preload("res://scripts/game/prologue_director.gd")
const BathCurtain := preload("res://scripts/props/clawfoot_curtain_motion.gd")
const Household := preload("res://scripts/building/orison_v2_household_state.gd")
var director: Node
var frame_trace:Node
var contact_optical:Array[Dictionary]=[]

class FrameTrace extends Node:
	var director:Node
	var rows:Array=[]
	var previous:=0
	var complete:=false
	var settings:Dictionary={}
	var film_rows:Array=[]
	var film_captures:Array=[]
	var sample_cap:=16384
	var total_frames:=0
	func _ready() -> void:
		if OS.get_environment("PROLOGUE_FULL_SEQUENCE")=="1":sample_cap=65536
		if OS.get_environment("PROLOGUE_FILM_CAPTURE")=="1":RenderingServer.frame_post_draw.connect(_capture_film)
	func _capture_film() -> void:
		if film_captures.size()>=40 or not is_instance_valid(director) or director.state.phase!="mirror_condensation" or not director._withdrawal_seen or director._phase_age<3 or director._phase_age>5:return
		var pane:MeshInstance3D=director.mirror.mirror_surface()
		var image:Image=get_viewport().get_texture().get_image()
		var box:AABB=pane.mesh.get_aabb()
		var pixels:=Rect2(director.player.camera.unproject_position(pane.to_global(box.position)),Vector2.ZERO)
		for i in 8:pixels=pixels.expand(director.player.camera.unproject_position(pane.to_global(box.get_endpoint(i))))
		var crop:=Rect2i(pixels.grow(16)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		var name_:String="film_frame_%03d.png"%film_captures.size()
		var result:=image.get_region(crop).save_png(OS.get_environment("SHOT_DIR").path_join(name_))
		film_captures.append({"file":name_,"age":director._phase_age,"progress":pane.get_meta("prologue_mirror_film"),"saved":result==OK})
	func _process(delta:float) -> void:
		var now:=Time.get_ticks_usec()
		total_frames+=1
		if previous>0 and rows.size()<sample_cap:
			var phase:String=str(director.state.phase) if is_instance_valid(director) else "retired"
			rows.append([phase,Engine.max_fps,delta*1000.0,float(now-previous)/1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		previous=now
		if is_instance_valid(director) and director.state.phase=="mirror_condensation" and director._withdrawal_seen and film_rows.size()<2048:
			var pane:MeshInstance3D=director.mirror.mirror_surface()
			var value:Vector2=pane.get_meta("prologue_mirror_film",Vector2(-1,0))
			var overlay:ShaderMaterial=director.world.bathroom_moisture._mirror_surfaces[pane.get_instance_id()].material
			var reflected:ShaderMaterial=director.world.mirror_renderer._material
			film_rows.append([director._phase_age,director._poll,value.y,
				value==overlay.get_shader_parameter("prologue_film") and value==reflected.get_shader_parameter("prologue_film"),
				get_tree().paused,director.player.call_locked])
	func _exit_tree() -> void:
		var out:=OS.get_environment("SHOT_DIR")
		if out.is_empty():return
		var file:=FileAccess.open(out.path_join("tutorial_frame_times.json"),FileAccess.WRITE)
		if file==null:return
		file.store_string(JSON.stringify({"evidence_class":"INERT","complete":complete,"sample_cap":sample_cap,"total_frames":total_frames,"truncated":maxi(0,total_frames-1)>rows.size(),
			"film_captures":film_captures,"film_columns":["phase_age","poll","progress","passes_identical","paused","call_locked"],"film_frames":film_rows,
			"settings":settings,"columns":["phase","fps_cap","process_delta_ms","wall_ms","process_monitor_ms","physics_monitor_ms","draw_calls"],"frames":rows,
			"limits":"Occupied route starts after world construction; process/physics monitors overlap and lag. GPU/render-thread, compilation, loading and streaming costs are not independently attributed. Capture stalls and cap changes are retained; compare matched phases/caps, not an aggregate FPS."},"\t",true,true))

func _init() -> void:
	route_label="V2 PROLOGUE TUTORIAL SLICE"

func _prepare_player_start() -> void:
	var anchor: Dictionary=world.core_loop.resolve_return_anchor()
	player.global_position=anchor.position;player.velocity=Vector3.ZERO

func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	if not _check_return_anchor_resolution():return
	if OS.get_environment("ORISON_BATH_REPAIR_REVIEW")=="1":
		await _review_installed_bath()
		return
	director=Director.new();world.add_child(director)
	if not _require(director.configure(world),"actual 4B fixture and wall supports bound: "+str(director.errors)): return
	frame_trace=FrameTrace.new();frame_trace.director=director
	frame_trace.process_priority=1000;frame_trace.process_mode=Node.PROCESS_MODE_ALWAYS
	frame_trace.settings={"viewport":str(get_viewport().size),"msaa_3d":get_viewport().msaa_3d,
		"engine":Engine.get_version_info(),"fixture_script":director.shower.get_script().resource_path,
		"weather":world.get_node("WeatherFX")._live_conditions.duplicate(true)}
	add_child(frame_trace)
	if OS.get_environment("PROLOGUE_WAKE_REVIEW")=="1":
		await _review_waking()
		return
	var carrier: Node=world.service_set_carrier
	var draft_before: String=carrier.session.draft
	var lamp_before: bool=player.lamp_is_enabled()
	var radio_before: bool=carrier.device.radio_powered
	var contact_source:=OS.get_environment("PROLOGUE_FIRST_CONTACT_SOURCE")
	if not contact_source.is_empty():
		await _review_first_contact(contact_source)
		return
	var crossing_source:=OS.get_environment("PROLOGUE_CROSSING_SOURCE")
	if not crossing_source.is_empty():
		await _review_crossing_snapshot(crossing_source)
		return
	carrier.session.draft="Unsubmitted draft survives the opening."
	if OS.get_environment("PROLOGUE_FULL_SEQUENCE")=="1":
		if not await _full_sequence_wake():return
	elif not _require(director.begin_waking_preview(),"explicit waking-only slice begins without fake dream acceptance"): return
	carrier.release_story_absence(world) # An unrelated caller cannot reveal it.
	carrier.set_capture_hidden(true)
	carrier.set_capture_hidden(false) # Review visibility cannot defeat story absence.
	var read_press := InputEventAction.new()
	read_press.action="teletype_read";read_press.pressed=true
	var reading_before: bool=carrier.reading
	Input.parse_input_event(read_press)
	await get_tree().process_frame
	read_press=InputEventAction.new();read_press.action="teletype_read";read_press.pressed=false
	Input.parse_input_event(read_press)
	if not _require(carrier.is_story_absent() and not carrier.rig.is_visible_in_tree()
			and carrier.reading==reading_before and not carrier.session.available()
			and not carrier.hand_is_enabled() and carrier.session.draft=="Unsubmitted draft survives the opening.","story absence retains draft, hides the single rig and rejects recall, typing and hand input"): return
	for area: Area3D in carrier.find_children("*","Area3D",true,false):
		if not _require(area.collision_layer==0,"absent companion has no query obstruction: "+str(area.name)): return
	if not _require(not player.flashlight.visible and player.flashlight.light_energy==0.0
			and player.lamp_is_enabled()==lamp_before and carrier.device.radio_powered==radio_before,
			"absent lamp emits nothing without changing switch or radio authority"): return
	player.face_world_point(director._bed_anchor.origin)
	await get_tree().create_timer(2.0).timeout
	await _shot("bedroom_writing.png")
	for at: Vector3 in [Vector3(-11.95,9.6,7.25),Vector3(-9.8,9.6,7.25),Vector3(-9.8,9.6,5.5),Vector3(-10.5,9.6,4.75)]:
		if not await _walk(at): return
	if not await _open_door("F04_B_BATH_DOOR"): return
	for at: Vector3 in [Vector3(-7.9,9.6,4.75),Vector3(-8.45,9.6,4.35)]:
		if not await _walk(at): return
	await get_tree().create_timer(.3).timeout
	if not _require(director.state.phase=="curtain_interaction","actual room entry selects curtain instruction"): return
	var shower: TapProp=director.shower
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(1.6).timeout
	await _shot("bathroom_writing.png")
	var plate: Node3D=world.adapter.resolve("F04_B_BATH_SWITCH")
	var fixture: Node=world.adapter.resolve("F04_B_BATH_LT_FLUSH_DOME")
	if not _require(plate!=null and fixture!=null,"bathroom switch and its existing fixture resolve"): return
	var lowest := INF
	for draw: MeshInstance3D in plate._model.find_children("*","MeshInstance3D",true,false):
		for corner in 8: lowest=minf(lowest,draw.to_global(draw.mesh.get_aabb().get_endpoint(corner)).y)
	var border_top: float=world.adapter.root.to_global(Vector3(0,9.6+1.2192+.03,0)).y
	if not _require(lowest>border_top,"whole switch plate clears tile and finishing border"): return
	if not await _drag_part(plate,plate._toggle.global_position,deg_to_rad(-22),"prologue_bath_light_off"): return
	if not _require(not fixture.powered,"raised switch still opens its authoritative bathroom circuit"): return
	if not await _drag_part(plate,plate._toggle.global_position,deg_to_rad(22),"prologue_bath_light_on"): return
	if not _require(fixture.powered,"raised switch restores the same fixture circuit"): return
	player.face_world_point(plate.global_position)
	await get_tree().create_timer(.8).timeout
	await _shot("bathroom_switch_above_tile.png")
	var window := world.adapter.root.get_node_or_null("F04_B_BATH_WINDOW_E/WindowTreatment") as Node3D
	if not _require(window!=null,"actual bathroom window curtain owner exists"): return
	# Household restore is not a witnessed player gesture and must not trigger
	# the joke. The physical opening below must leave the shower gate unfinished.
	var saved: Dictionary=window.settings_snapshot()
	window.set_settings(window.raised,window.tilt_degrees,.8,0.0)
	if not _require(director.message_id=="curtain_open","programmatic window change cannot invent wrong-curtain interaction"): return
	window.restore_settings(saved)
	if not await _walk(Vector3(-6.9,9.6,4.75)): return
	var extent: float=(window.width+.24)*.38
	if not await _drag_part(window,window.get_node("CurtainControl").global_position,extent,"prologue_wrong_curtain"): return
	if not _require(director.message_id=="wrong_curtain" and director.state.phase=="curtain_interaction"
			and "curtain_pulled" not in director.state.events,"actual window-curtain opening prompts correction without completing shower step"): return
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(1.6).timeout
	await _shot("wrong_curtain.png")
	if not await _walk(Vector3(-8.45,9.6,4.35)): return
	if not await _drag_part(shower,shower.to_global(Vector3(0,1.18,-.32)),1.78,"prologue_curtain"): return
	if not _require("curtain_pulled" in director.state.events and director.message_id=="cold_start","curtain release advances actual guidance"): return
	if not await _drag_part(shower,shower._handles[1].global_position,PI*.5,"prologue_cold"): return
	if not _require(director.state.phase=="shower_temperature" and shower.get_flow_state().temperature==0.0,"cold valve release begins temperature tutorial"): return
	if not await _drag_part(shower,shower._handles[0].global_position,PI*.5,"prologue_hot"): return
	await get_tree().create_timer(2.0).timeout
	if not _require(director.state.phase=="shower_complete" and "hot_water_adjusted" in director.state.events,"actual mixed valves reach forgiving comfort gate"): return
	await get_tree().create_timer(7.2).timeout
	if not _require(director.state.phase=="mirror_tapping","peace interval reaches shutoff guidance"): return
	if not await _drag_part(shower,shower._handles[0].global_position,0.0,"prologue_hot_off"): return
	if not _require(director.state.phase=="mirror_tapping" and director.message_id=="water_off","cold flow cannot falsely complete shutoff"): return
	if not await _drag_part(shower,shower._handles[1].global_position,0.0,"prologue_cold_off"): return
	if not _require(director.state.phase=="mirror_condensation" and director.is_processing(),"real shower shutoff starts the mirror withdrawal"): return
	if not await _review_mirror_reveal():return
	if not await _review_visitor():return
	if not await _review_crossing():return
	if OS.get_environment("PROLOGUE_FULL_SEQUENCE")=="1":
		await _full_sequence_ending()
		return
	var before: Dictionary=shower.mechanism_snapshot()
	director.shutdown()
	_require(before==shower.mechanism_snapshot(),"presentation retirement does not alter physical mechanisms")
	await get_tree().create_timer(.2).timeout
	_require(not director.mirror.mirror_surface().has_meta("prologue_mirror_film") and world.mirror_renderer._material.get_shader_parameter("prologue_film")==Vector2(-1,0),"shutdown restores ordinary mirror moisture without a stale reveal")
	_require(not carrier.is_story_absent() and carrier.rig.is_visible_in_tree()
			and carrier.session.draft=="Unsubmitted draft survives the opening."
			and player.lamp_is_enabled()==lamp_before and carrier.device.radio_powered==radio_before,
			"shutdown restores original companion while retaining draft and power")
	carrier.session.draft=draft_before
	var temporary := Node.new();world.add_child(temporary)
	_require(carrier.acquire_story_absence(temporary),"temporary staging owner obtains lease")
	temporary.queue_free()
	await get_tree().process_frame
	_require(not carrier.is_story_absent() and carrier.rig.is_visible_in_tree(),"owner removal releases absence without stale hidden rig")
	await _review_refit(carrier)
	var out := OS.get_environment("SHOT_DIR")
	var file := FileAccess.open(out.path_join("tutorial_slice.json"),FileAccess.WRITE)
	if not _require(file!=null,"diagnostic output is writable"): return
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual bed-to-bath walking, curtain/valves/shutoff, mirror withdrawal, drawn reflection, cabinet input and repeated reflection-only visitor observations/reload; no DREAM, physical crossing, first contact, typing-arm finale or production-entry acceptance.","state":director.state,"errors":director.errors,"failures":failures},"\t"))
	frame_trace.complete=failures.is_empty()

func _turn_at(point:Vector3) -> void:
	for i in 14:
		var toward:Vector3=(point-player.camera.global_position).normalized()
		var forward:Vector3=-player.camera.global_basis.z
		var flat:=Vector3(toward.x,0,toward.z).normalized()
		var yaw:=Vector3(forward.x,0,forward.z).normalized().signed_angle_to(flat,Vector3.UP)
		var pitch:=atan2(toward.y,Vector2(toward.x,toward.z).length())-player.camera.rotation.x
		var sensitivity:=player.MOUSE_SENS*clampf(float(GameBoot.settings.get("look_sensitivity",1.0)),.25,2)
		var motion:=InputEventMouseMotion.new()
		motion.relative=Vector2(-yaw,-pitch)/sensitivity/float(14-i)
		Input.parse_input_event(motion);Input.flush_buffered_events()
		await get_tree().process_frame

func _review_visitor() -> bool:
	var carrier:Node=world.service_set_carrier
	var device_id:int=carrier.device.get_instance_id()
	var rig_id:int=carrier.rig.get_instance_id()
	# Closing the leaf leaves the real camera aimed at its old open position.
	# Looking back is an actual input action, not an assumed consequence.
	await _turn_at(director.mirror.mirror_center())
	await get_tree().create_timer(1.2).timeout
	print("VISITOR_DIAGNOSTIC ",JSON.stringify({"age":director._phase_age,"events":director.state.events,"active":str(world.mirror_renderer.active_mirror()),"mirror_observed":director._mirror_observed(),"visitor_observed":director._visitor_observed(),"center":str(director._visitor_center),"camera":str(player.camera.global_transform),"rig":str(carrier.rig.global_transform)}))
	await _shot("reflection_visitor_first.png")
	if not _require("visitor_seen" in director.state.events and not ("looked_behind" in director.state.events),"mirror attention witnesses visitor without inventing a look behind"):return false
	var device_mask:=1<<(ServiceSetProp.DEVICE_LAYER-1)
	_require(player.camera.cull_mask&device_mask==0 and world.mirror_renderer.active_camera().cull_mask&device_mask!=0,"only reflected rays see the staged instrument layer")
	_require(carrier.is_story_absent() and carrier.is_capture_hidden() and carrier._story_reflection and carrier.rig.visible and carrier.screen_frame.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"one native rig is projected while ordinary compositor and input remain absent")
	var no_shadows:=true
	for draw:GeometryInstance3D in carrier.rig.find_children("*","GeometryInstance3D",true,false):no_shadows=no_shadows and draw.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var no_queries:=true
	for entry:Dictionary in carrier._pick_layers.values():
		var area:Area3D=entry.ref.get_ref()
		if area!=null:no_queries=no_queries and area.collision_layer==0
	_require(no_shadows and no_queries and carrier.motion.collision_layer==0,"reflection visitor has no physical shadows, controls or blocking body")
	carrier.set_capture_hidden(true)
	await get_tree().process_frame
	_require(not carrier.rig.visible,"capture suppression also hides the private reflection")
	carrier.set_capture_hidden(false)
	await get_tree().process_frame
	_require(carrier.rig.visible and carrier.is_story_absent(),"capture restoration cannot release narrative absence")
	var events_before:Array=director.state.events.duplicate()
	var other:=Camera3D.new();other.name="VisitorPrivacyObserver"
	other.cull_mask=player.camera.cull_mask|device_mask
	world.add_child(other);other.global_transform=player.camera.global_transform;other.make_current()
	await get_tree().process_frame;await get_tree().process_frame
	_require(not carrier.rig.visible and not director._mirror_observed() and director.state.events==events_before,"a different current camera cannot expose the private visitor or fabricate observations")
	player.camera.make_current();other.queue_free()
	await get_tree().process_frame;await get_tree().process_frame
	var visitor:Vector3=director._visitor_center
	await _turn_at(visitor)
	await get_tree().create_timer(.5).timeout
	if not _require("looked_behind" in director.state.events and not ("visitor_seen_again" in director.state.events) and not carrier.rig.visible,"real mouse turn finds no physical machine and records only the absence investigation"):return false
	await _shot("reflection_visitor_absent.png")
	await _turn_at(director.mirror.mirror_center())
	await get_tree().create_timer(1.2).timeout
	if not _require("visitor_seen_again" in director.state.events and director.state.phase=="reflection_visitor","mouse return rediscovers the same visitor without immediate crossing"):return false
	await _shot("reflection_visitor_return.png")
	# Repeat the experiment before permitting the authored crossing gate.
	await _turn_at(visitor)
	await get_tree().create_timer(.4).timeout
	_require(not carrier.rig.visible and carrier.is_story_absent(),"repeated look behind remains empty")
	await _turn_at(director.mirror.mirror_center())
	await get_tree().create_timer(1.1).timeout
	_require(carrier.rig.visible and carrier.device.get_instance_id()==device_id and carrier.rig.get_instance_id()==rig_id,"repeat experiment retains exactly the original companion authority and rig")
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("visitor_reload.json");RealityState.persistence_enabled=true
	var events:Array=director.state.events.duplicate()
	if not _require(RealityState.save_game(),"validated save records actual ordered visitor observations"):return false
	RealityState.load_game();await get_tree().process_frame
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	_require(director._visitor_active and director._phase_age<.5 and director.state.events==events and carrier.rig.get_instance_id()==rig_id,"reload restages private presentation without stale dwell, new observations or another bot")
	await get_tree().create_timer(18.7).timeout
	if not _require(director.state.phase=="companion_crossing" and not director.state.effects.companion_materialized and carrier.is_story_absent(),"only genuine observations and the generous dwell reach the pending crossing; no physical arrival is invented"):return false
	var held_observer:=Camera3D.new();held_observer.name="HeldVisitorPrivacyObserver"
	held_observer.cull_mask=player.camera.cull_mask|device_mask
	world.add_child(held_observer);held_observer.global_transform=player.camera.global_transform;held_observer.make_current()
	await get_tree().process_frame;await get_tree().process_frame
	_require(not carrier.rig.visible,"carrier independently protects observer privacy while the crossing implementation is pending")
	player.camera.make_current();held_observer.queue_free()
	await get_tree().process_frame;await get_tree().process_frame
	_require(carrier.rig.visible and carrier.device.get_instance_id()==device_id,"return to the player retains the same private machine at the handoff boundary")
	return true

func _crossing_age(target:float) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(director.mirror_crossing) and director.mirror_crossing.active and director.mirror_crossing.age>=target:return true
		await get_tree().process_frame
	return _require(false,"crossing reaches authored age "+str(target))

func _review_crossing() -> bool:
	var carrier:Node=world.service_set_carrier
	var rig_id:int=carrier.rig.get_instance_id()
	var draft:String=carrier.session.draft
	if not await _crossing_age(2.0):return false
	var clip:Node=director.mirror_crossing
	_require(player.text_input_owner==clip and carrier.is_story_absent() and not clip.world_stage,"private approach owns input without a physical arrival")
	await _shot("crossing_tunnel.png")
	var age:float=clip.age
	get_tree().paused=true
	await get_tree().create_timer(.25,true,false,true).timeout
	_require(clip.age==age,"pause holds the crossing and its optical time exactly")
	get_tree().paused=false
	if not await _crossing_age(4.8):return false
	var opaque_shadows:=0
	for draw:GeometryInstance3D in carrier.rig.find_children("*","GeometryInstance3D",true,false):
		_require(draw.layers==carrier.screen_frame.DEVICE_MASK,"arrival preserves native geometry layers: "+str(draw.name))
		if draw is MeshInstance3D and draw.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON:opaque_shadows+=1
	_require(clip.world_stage and opaque_shadows>0 and (player.camera.cull_mask&carrier.screen_frame.DEVICE_MASK)!=0 and not carrier.screen_frame.layer.visible and carrier.is_story_absent() and not director.state.effects.companion_materialized,"ordinary world camera and housing shadow carry arrival; foreground, controls and completion remain withheld")
	await _shot("crossing_emergence.png")
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("crossing_reload.json");RealityState.persistence_enabled=true
	if not _require(RealityState.save_game(),"validated disk save records an incomplete crossing without inventing arrival"):return false
	RealityState.load_game();await get_tree().process_frame;await get_tree().process_frame
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	_require(director.state.phase=="companion_crossing" and not director.state.effects.companion_materialized and carrier.rig.get_instance_id()==rig_id and carrier._world_story_draws.is_empty(),"reload retires transient world layers and restages the same unarrived machine")
	if not await _crossing_age(5.8):return false
	await _shot("crossing_emergence_reloaded.png")
	var handoff_deadline:=Time.get_ticks_msec()+20000
	while not director.mirror_crossing.handing_off and Time.get_ticks_msec()<handoff_deadline:await get_tree().process_frame
	var handoff_age:float=carrier.screen_frame._handoff_age
	var handoff_pose:Transform3D=carrier.rig.global_transform
	get_tree().paused=true
	await get_tree().create_timer(.25,true,false,true).timeout
	_require(carrier.screen_frame._handoff_age==handoff_age and carrier.rig.global_transform==handoff_pose,"pause holds the actual world-to-foreground flight without a pre-draw clock leak")
	get_tree().paused=false
	var deadline:=Time.get_ticks_msec()+20000
	while director.state.phase=="companion_crossing" and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	_require(director.state.phase=="first_contact" and director.state.effects.companion_materialized and not carrier.is_story_absent(),"completed physical and framing handoff acknowledges arrival through the existing reducer")
	_require(player.text_input_owner in [null,director] and carrier._world_story_draws.is_empty() and not carrier._story_reflection and carrier.rig.get_instance_id()==rig_id and carrier.session.draft==draft,"arrival releases crossing input to ordinary control or the following contact owner, restoring layers and original draft")
	_require(carrier._housing_shadow.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"physical housing keeps its world shadow after the temporary arrival lease ends")
	await _shot("crossing_arrived.png")
	var arrived_path:=OS.get_environment("SHOT_DIR").path_join("arrived_reload.json")
	RealityState.save_path=arrived_path;RealityState.persistence_enabled=true
	if not _require(RealityState.save_game(),"validated disk save records the acknowledged arrival"):return false
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("crossing_reload.json")
	RealityState.load_game();await get_tree().process_frame;await get_tree().process_frame
	_require(director.state.phase=="companion_crossing" and carrier.is_story_absent(),"loading the earlier incomplete crossing restores absence from saved facts")
	RealityState.save_path=arrived_path
	RealityState.load_game();await get_tree().process_frame;await get_tree().process_frame
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	_require(director.state.phase=="first_contact" and not carrier.is_story_absent() and carrier.rig.get_instance_id()==rig_id and player.text_input_owner in [null,director],"loading the later arrival retires crossing and permits only the following contact input owner")
	return failures.is_empty()

func _review_crossing_snapshot(source:String) -> void:
	# Reuse a test-written disk save from actual curtain/valve/cabinet input;
	# never synthesize earlier gates to shorten this focused reload diagnostic.
	var old_path:String=RealityState.save_path
	RealityState.save_path=source;RealityState.persistence_enabled=true
	RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	if not _require(director.state.phase=="companion_crossing" and not director.state.effects.companion_materialized,"focused source is an actual validated uncompleted crossing"):return
	var mirror:MedicineCabinetProp=director.mirror
	var at:=mirror.mirror_center()+mirror.mirror_normal()*1.1;at.y=mirror.global_position.y+.025
	var capsule:=CapsuleShape3D.new();capsule.radius=player.BODY_RADIUS;capsule.height=player.STANDING_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=player.collision_mask;query.exclude=[player.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*player.STANDING_HEIGHT*.5)
	if not _require(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"focused mirror stance clears actual full-size player collision"):return
	player.set_physics_process(false);player.global_position=at;player.velocity=Vector3.ZERO;player.face_world_point(mirror.mirror_center())
	for tick in 12:await RenderingServer.frame_post_draw
	if not _require(director.begin_waking_preview(),"validated crossing resumes through the actual opening owner"):return
	await _review_crossing()
	director.shutdown()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("crossing_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","source":source,"source_sha256":FileAccess.get_sha256(source),"state":director.state,"errors":director.errors,"failures":failures,"limits":"Focused actual-world crossing/reload diagnostic from a previously test-written actual-input save. No new bedroom-to-bath route, full prologue, performance or human acceptance."},"\t"))
	frame_trace.complete=failures.is_empty()

func _review_first_contact(source:String) -> void:
	var carrier:Node=world.service_set_carrier
	var old_path:String=RealityState.save_path
	var source_hash:=FileAccess.get_sha256(source)
	var input_copy:=OS.get_environment("SHOT_DIR").path_join("arrival_input.json")
	if not _require(DirAccess.copy_absolute(source,input_copy)==OK,"copy immutable actual-input source before any live save/reload"):return
	RealityState.save_path=input_copy;RealityState.persistence_enabled=true;RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	if not _require(director.state.phase=="first_contact" and director.state.effects.companion_materialized,"contact starts from a validated test-written physical-arrival save"):return
	var mirror:MedicineCabinetProp=director.mirror
	var at:Vector3=mirror.mirror_center()+mirror.mirror_normal()*1.1;at.y=mirror.global_position.y+.025
	player.global_position=at;player.velocity=Vector3.ZERO;player.face_world_point(mirror.mirror_center())
	var draft:String=carrier.session.draft
	var rig_id:int=carrier.rig.get_instance_id()
	if not _require(director.begin_waking_preview(),"actual director resumes acknowledged arrival without replaying crossing"):return
	var expected:Array[String]=["Sorry you died.","But if it makes you feel better, I can help you solve your murder!","First we need to solve a bigger mystery.","Who were you?","I am connecting you to the present, please stay on the line..."]
	var seen:Array[String]=[]
	var interrupted:=false
	var restored:=false
	var thinking_start:=-1.0
	var thinking_end:=-1.0
	var deadline:=Time.get_ticks_msec()+140000
	while Time.get_ticks_msec()<deadline and director.state.phase in ["first_contact","identity_mystery","temporal_command"]:
		await get_tree().process_frame
		var paper:Node=carrier.device.teletype
		if director._contact_thinking_age>0 and thinking_start<0:thinking_start=Time.get_ticks_usec()/1000000.0
		var copy:String=" ".join(str(paper.ink.text).replace("\n"," ").split(" ",false))
		if paper.copy_delivered() and expected.has(copy) and not seen.has(copy):
			seen.append(copy)
			if copy==expected[3]:thinking_end=Time.get_ticks_usec()/1000000.0
			var visible_pixels:int=await _contact_ink_pixels(paper)
			_require(visible_pixels>copy.length()*4,"rendered green glyphs are visible above the closed tile face: "+copy)
			await _shot("contact_%d.png"%seen.size())
		if seen.size()==1 and not interrupted:
			interrupted=true
			var ink_pose:Vector3=paper.ink.position
			paper.ink.position=paper._ink_home
			await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
			var hidden_pixels:int=await _contact_ink_pixels(paper)
			_require(hidden_pixels<=copy.length()*4,"the actual unfed impression datum remains an optical negative control behind the closed face")
			paper.ink.position=ink_pose
			await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
			_require(player.text_input_owner==director and not carrier.session.available(),"contact owns focus and suppresses autonomous chatter without overwriting correspondence")
			var age:float=director._contact_age
			get_tree().paused=true
			await get_tree().create_timer(.3,true,false,true).timeout
			_require(director._contact_age==age,"pause holds the actual printed-line reading interval")
			get_tree().paused=false
			carrier.device.set_radio_powered(false)
			await get_tree().create_timer(.3).timeout
			_require(director._contact_age==age and player.text_input_owner!=director,"power loss releases contact input and cannot acknowledge the unheard revelation")
			carrier.device.set_radio_powered(true)
			await get_tree().process_frame
			age=director._contact_age;player.call_locked=true
			await get_tree().create_timer(.3).timeout
			_require(director._contact_age==age and player.protected_input_active() and player.text_input_owner!=director,"protected conversation retains its own lock while contact yields")
			player.call_locked=false
			await get_tree().process_frame
			var press:=InputEventAction.new();press.action="companion_type";press.pressed=true;Input.parse_input_event(press)
			await get_tree().process_frame
			press=InputEventAction.new();press.action="companion_type";press.pressed=false;Input.parse_input_event(press)
			_require(not carrier.session.typing and carrier.session.draft==draft,"actual type input cannot steal contact focus or erase the existing draft")
		if seen.size()==2 and director.state.phase=="identity_mystery" and not restored:
			restored=true
			RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("identity_reload.json");RealityState.persistence_enabled=true
			_require(RealityState.save_game(),"validated disk save records completed murder disclosure")
			var identity_path:String=RealityState.save_path
			player.call_locked=true
			carrier.print_telegram_card({"title":"FIELD COPY","body":"Keep this unrelated report."})
			var foreign_serial:int=carrier.device.teletype._serial
			RealityState.save_path=input_copy;RealityState.load_game()
			await get_tree().process_frame;await get_tree().process_frame
			var stale:=false
			for report:Dictionary in carrier.device.teletype.reports:
				stale=stale or " ".join(report.pages).replace("\n"," ").contains("solve your murder")
			_require(not stale and director.state.phase=="first_contact" and "murder_presented" not in director.state.events,"older disk save retires only invalidated prologue copies and facts")
			_require(carrier.device.teletype._serial==foreign_serial and " ".join(carrier.device.teletype.pages).contains("Keep this unrelated report."),"backward reload preserves the unrelated current physical field copy")
			RealityState.save_path=identity_path;RealityState.load_game()
			await get_tree().process_frame;await get_tree().process_frame
			_require(carrier.device.teletype._serial==foreign_serial,"forward reload also preserves unrelated report ownership")
			RealityState.persistence_enabled=false;RealityState.save_path=old_path
			_require(director.state.phase=="identity_mystery" and "murder_presented" in director.state.events and director._contact_index==0,"reload resumes identity without replaying completed murder revelation")
			player.call_locked=false
	_require(seen==expected,"actual paper delivered all five exact lines in order: "+str(seen))
	_require(thinking_start>=0 and thinking_end-thinking_start>=2.0,"settled thoughtful tiles precede the identity question by at least two real unpaused seconds")
	_require(director.state.phase=="temporal_synchronization" and "identity_question_presented" in director.state.events and "destination_accepted" in director.state.events,"printed identity and real arm Return advance through existing acknowledged gates")
	_require(carrier.rig.get_instance_id()==rig_id and carrier.session.draft==draft and carrier.story_attitude==Vector3.ZERO and player.text_input_owner!=director,"handoff retains the original machine and draft, retiring contact pose and input")
	director.shutdown()
	_require(FileAccess.get_sha256(source)==source_hash,"original actual-input source stays byte-for-byte unchanged")
	_require(player.text_input_owner==null and carrier.story_attitude==Vector3.ZERO,"shutdown retires presentation and cinematic input without a stale owner")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("contact_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","source":source,"source_sha256":FileAccess.get_sha256(source),"lines":seen,"optical":contact_optical,"state":director.state,"errors":director.errors,"failures":failures,"limits":"Actual-world first contact and command diagnostic from a previous actual-input arrival save; not the full opening or human acceptance."},"\t"))
	frame_trace.complete=failures.is_empty()

func _contact_ink_pixels(paper:Node) -> int:
	await get_tree().process_frame # Let the ready copy acquire its stable pose.
	var box:AABB=paper.ink.get_aabb()
	var rect:=Rect2(player.camera.unproject_position(paper.ink.to_global(box.position)),Vector2.ZERO)
	for corner in 8:rect=rect.expand(player.camera.unproject_position(paper.ink.to_global(box.get_endpoint(corner))))
	var image:Image=get_viewport().get_texture().get_image()
	var crop:=Rect2i(rect).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	# Isolate the ink contribution. Brass/writer reflections and heading text
	# can also be green; raw green counts falsely passed the obscured control.
	var paused_before:=get_tree().paused
	var visible_before:bool=paper.ink.visible
	get_tree().paused=true
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	paper.ink.visible=false
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var blank:Image=get_viewport().get_texture().get_image()
	paper.ink.visible=visible_before
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	get_tree().paused=paused_before
	var green:=0
	for y in range(crop.position.y,crop.end.y,2):
		for x in range(crop.position.x,crop.end.x,2):
			var pixel:Color=image.get_pixel(x,y)
			if pixel.g>.18 and pixel.g>pixel.r*1.3 and pixel.g>pixel.b*1.3 and pixel.g-blank.get_pixel(x,y).g>.15:green+=1
	contact_optical.append({"serial":paper._serial,"ink_local":str(paper.ink.position),"crop":str(crop),"visible_pixels":green,"camera_fov":player.camera.fov})
	return green

func _review_mirror_reveal() -> bool:
	var cabinet:MedicineCabinetProp=director.mirror
	player.face_world_point(player.camera.global_position+Vector3.UP*3)
	await get_tree().create_timer(3.0).timeout
	if not _require(not director._withdrawal_seen and director._phase_age<=1.5 and not world.player_avatar.visible,"branching reveal waits for the player to notice the mirror"):return false
	var at:Vector3=cabinet.mirror_center()+cabinet.mirror_normal()*.85
	at.y=player.global_position.y
	if not await _walk_world(at):return false
	player.face_world_point(cabinet.mirror_center())
	await get_tree().create_timer(.4).timeout
	if not _require(not world.player_avatar.visible and cabinet.mirror_surface().get_meta("prologue_mirror_film").x==1,"body remains concealed behind the authored condensation"):return false
	await _shot("mirror_fully_obscured.png")
	get_tree().paused=true
	var age:float=director._phase_age
	await get_tree().create_timer(.3,true).timeout
	if not _require(director._phase_age==age,"pause holds branching withdrawal without another clock"):return false
	get_tree().paused=false
	await get_tree().create_timer(3.0).timeout
	await _shot("mirror_branching.png")
	var locked_before:bool=player.call_locked
	var protected_age:float=director._phase_age
	var protected_film:Vector2=cabinet.mirror_surface().get_meta("prologue_mirror_film")
	player.call_locked=true
	await get_tree().create_timer(.3).timeout
	_require(director._phase_age==protected_age and cabinet.mirror_surface().get_meta("prologue_mirror_film")==protected_film,"protected conversation freezes the shared film without fractional rewind")
	player.call_locked=locked_before
	var synchronized:=true
	var subperiod_changes:=0
	var samples:Array=frame_trace.film_rows
	for i in range(1,samples.size()):
		var previous:Array=samples[i-1];var current:Array=samples[i]
		synchronized=synchronized and bool(current[3])
		if float(current[0])>2.1 and float(current[0])>float(previous[0]) and float(current[1])>float(previous[1]) and float(current[2])>float(previous[2]):subperiod_changes+=1
	_require(synchronized and subperiod_changes>=8,"both optical passes share every frame and advance between story polls: "+str(subperiod_changes))
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("mirror_reload.json")
	RealityState.persistence_enabled=true
	if not _require(RealityState.save_game(),"validated save records the genuine mirror phase"):return false
	RealityState.load_game()
	await get_tree().process_frame
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	if not _require(director.state.phase=="mirror_condensation" and director._phase_age<.5 and not world.player_avatar.visible,"reload restages transient withdrawal without inventing reflection observations: phase=%s age=%s visible=%s"%[director.state.phase,director._phase_age,world.player_avatar.visible]):return false
	await get_tree().create_timer(6.5).timeout
	await _shot("mirror_branching_body.png")
	player.face_world_point(player.camera.global_position+Vector3.UP*3)
	await get_tree().create_timer(5.0).timeout
	if not _require(director.state.phase=="protagonist_reveal" and not ("reflection_observed" in director.state.events),"looking away cannot falsely witness the protagonist"):return false
	player.face_world_point(cabinet.mirror_center())
	await get_tree().create_timer(1.5).timeout
	await _shot("mirror_drawn_protagonist.png")
	if not _require(world.player_avatar.visible and world.player_avatar.reflected and world.mirror_renderer.active_mirror()==cabinet,"the supplied drawn rig is synchronized through the existing borrowed mirror"):return false
	await get_tree().create_timer(7.0).timeout
	if not _require(director.state.phase=="cabinet_inspection" and director.message_id=="cabinet_open","quiet actual reflection observation enables Open it guidance"):return false
	cabinet.restore_travel(1);cabinet.restore_travel(0)
	await get_tree().physics_frame;await get_tree().physics_frame
	_require(cabinet.get_node("CabinetReach").collision_layer==0 and cabinet._door.get_node("ManipulationTarget").collision_layer==1,"only the actual moving leaf receives cabinet queries")
	if not _require(not ("cabinet_opened" in director.state.events) and not ("cabinet_closed" in director.state.events),"restored cabinet travel cannot fabricate player investigation"):return false
	player.face_world_point(cabinet.mirror_center()+cabinet.mirror_normal()*.02)
	await get_tree().physics_frame
	var grip:Dictionary=player._grab.find_target()
	print("MIRROR_GRAB_DIAGNOSTIC ",JSON.stringify({"owner":str(grip.get("owner")),"hit":str(player._grab.last_hit),"camera":str(player.camera.global_position),"center":str(cabinet.mirror_center()),"leaf":str(cabinet._leaf_body.global_transform)}))
	if not await _drag_part(cabinet,cabinet.mirror_center()+cabinet.mirror_normal()*.02,cabinet.DOOR_ANGLE,"prologue_medicine_open"):return false
	if not _require("cabinet_opened" in director.state.events and not ("cabinet_closed" in director.state.events),"primary grab motion and release witnesses the real cabinet opening"):return false
	await _shot("mirror_cabinet_ordinary_contents.png")
	if not _require(cabinet.inventory_names()==["aspirin","iodine","razor"],"cabinet retains its ordinary authored personal effects"):return false
	if not await _drag_part(cabinet,cabinet.mirror_center()+cabinet.mirror_normal()*.02,0.0,"prologue_medicine_close"):return false
	return _require(director.state.phase=="reflection_visitor" and "cabinet_closed" in director.state.events and world.service_set_carrier.is_story_absent(),"actual cabinet closure reaches the next unfinished beat without revealing a world bot")


func _bath_click() -> void:
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _bath_valve(tap:TapProp,index:int,goal:float) -> bool:
	var part:Node3D=tap._handles[index]
	# Aim at the cap rather than its mounting pivot behind the wall finish.
	var cap:Vector3=part.to_global(Vector3(0,0,-.06))
	player.face_world_point(cap)
	await get_tree().physics_frame
	player.face_world_point(cap)
	if not _require(player._grab.find_target().get("part")==part,"ray selects the specific valve cap: "+str(index)):return false
	# The inherited room-route driver uses constant-size gestures to reach
	# endpoints. Use the existing adaptive hand for a deliberately partial turn.
	var hand:=preload("res://tests/fixed_gesture_patrol_hand.gd").new()
	add_child(hand);hand.player=player
	var moved:bool=await hand.operate(cap,goal,tap)
	hand.queue_free()
	return _require(moved and absf(tap._valve_openings[index]*PI*.5-goal)<.000001,"actual partial valve motion and release: "+str(index))

func _walk_bath_pose(tap:TapProp,local_target:Vector3) -> bool:
	# The ordinary room route stops 100mm short and checks immediately. The
	# bowl's fitted standing pose needs a centered capsule and time to settle
	# after stepping over its rim. Keep this precision local to this review.
	var target:Vector3=tap.model.to_global(local_target)
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		var delta:=target-player.global_position;delta.y=0
		if delta.length()<.006:break
		player.rotation.y=atan2(-delta.x,-delta.z);player.camera.rotation=Vector3.ZERO
		Input.action_press("move_forward",minf(1,delta.length()/.12))
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for frame in 60:await get_tree().physics_frame
	var actual:Vector3=tap.model.to_local(player.global_position)
	var ok:=actual.distance_to(local_target)<.035
	trace.append({"bath_target":str(local_target),"bath_actual":str(actual),"ok":ok})
	return _require(ok,"walked precise tub stance and settled through real collision: "+str(actual))

func _review_installed_bath() -> void:
	var tap:TapProp=world.adapter.resolve("F04_4B_SHOWER_01")
	if not _require(tap!=null and tap.has_method("mount_fixture_collision") and tap.native_ready,"actual 4B loader mounts the native bath actor"):return
	# One explicit initial review placement. Subsequent access is walked.
	player.global_position=tap.model.to_global(Vector3(0,0,-1.05));player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	player.face_world_point(tap.model.to_global(Vector3(0,1.25,0)))
	await _shot("installed_tub_closed")
	var point:Vector3=tap.model.to_global(BathCurtain.cloth_centerline(.75,.5,0))
	if not await _drag_part(tap,point,1.78,"installed_tub_curtain"):return
	if not await _walk_bath_pose(tap,Vector3(0,.239,0)):return
	for tick in 30:await get_tree().physics_frame
	if not _require(absf(tap.model.to_local(player.global_position).y-.239)<.045 and is_equal_approx(player._capsule.radius,PlayerController.BODY_RADIUS),"actual room admits the unshrunk standing capsule into the tub"):return
	for index in 2:
		if not await _bath_valve(tap,index,PI*.5*(.85 if index==0 else .5)):return
	var sources:Array=world.bathroom_moisture._sources.filter(func(source:Dictionary):return source.tap==tap)
	if not _require(sources.size()==1 and sources[0].spray.emitting,"one existing moisture owner emits the actual shower cone"):return
	player.face_world_point(tap._stream.global_position-Vector3.UP*.35)
	await get_tree().create_timer(.6).timeout
	await _shot("installed_tub_shower_cone")
	player.face_world_point(tap.model.to_global(Vector3(0,2.28,.44)))
	await _shot("installed_tub_wall_supports")
	if not await _drag_part(tap,tap.diverter.global_position,0.0,"installed_tub_filler"):return
	if not _require(not sources[0].spray.emitting and tap.filler.visible and tap.spray_flow_amount()==0,"filler diversion stops GPU shower emission through authoritative flow"):return
	player.face_world_point(tap._bath_plug.global_position)
	await get_tree().physics_frame
	var target:Dictionary=player._grab.find_target()
	if not _require(target.get("part")==tap._bath_plug,"occupied bowl leaves the specific stopper accessible"):return
	await _bath_click()
	if not _require(player._grab.active() and player._grab.target.part==tap._bath_plug,"primary grabs the installed stopper"):return
	var pixels:Vector2=player.camera.unproject_position(tap.model.to_global(tap.plug_seat))-player.camera.unproject_position(tap._bath_plug.global_position)
	for index in 12:
		var motion:=InputEventMouseMotion.new();motion.relative=pixels/12
		player._unhandled_input(motion);await get_tree().physics_frame
	await _bath_click()
	if not _require(not player._grab.active() and tap._stopper,"installed stopper snaps into the drain on release"):return
	await get_tree().create_timer(2.0).timeout
	if not _require(tap._water_level>.05,"actual occupied tub collects mixed supply behind its sealed drain"):return
	player.face_world_point(tap.model.to_global(Vector3(-.32,.90,.28)))
	await _shot("installed_tub_filler_and_chain")
	for index in 2:
		if not await _bath_valve(tap,index,0.0):return
	if not await _walk_bath_pose(tap,Vector3(0,0,-1.05)):return
	for tick in 30:await get_tree().physics_frame
	if not _require(absf(tap.model.to_local(player.global_position).y)<.045,"actual room permits return to its original floor"):return
	if OS.get_environment("ORISON_BATH_OPTICAL_ONLY")=="1":
		# An exterior view distinguishes the whole cone from the view while
		# standing within it. Restore flow through real controls, then shut off.
		for index in 2:
			if not await _bath_valve(tap,index,PI*.5*(.85 if index==0 else .5)):return
		if not await _drag_part(tap,tap.diverter.global_position,.012,"exterior_shower_diversion"):return
		player.face_world_point(tap._stream.global_position-Vector3.UP*.7)
		await get_tree().create_timer(.6).timeout
		await _shot("installed_tub_shower_exterior")
		for index in 2:
			if not await _bath_valve(tap,index,0.0):return
		print("BATH OPTICAL REVIEW: INERT input/capture review; disk reconstruction is not run in this mode.")
		return
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("validated_bath_campaign.json")
	await _save_rebuild_bath(tap)
	RealityState.flush_background_saves();RealityState.save_path=old_path
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bath_world.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":interaction_checks,"failures":failures,
		"scope":"Actual 4B actor, walked vessel access, native controls/spray and validated campaign disk save with world reconstruction. No complete prologue, whole-V2 surface qualification, global navigation, performance attribution or human acceptance."},"\t",true,true))

func _save_rebuild_bath(tap:TapProp) -> void:
	var wanted:Dictionary=tap.mechanism_snapshot()
	var complete_household:Dictionary=world.household_state.snapshot()
	if not _require(world.household_state.validate(complete_household,world.household_state._kinds),"existing household validator accepts the complete mixed fixture roster"):return
	if not _require(RealityState.save_game() and FileAccess.file_exists(RealityState.save_path),"existing campaign storage writes an isolated real save"):return
	var key:String=Household.KEY
	if not _require(RealityState.data[key].records["F04_4B_SHOWER_01"].value==wanted,"campaign snapshot contains the actual released tub controls"):return
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	var protected_domains:Dictionary={}
	for domain:String in ["cases","inventories","work_orders","resident_trust","newspapers_collected","discovered_documents","campaign_clock"]:
		if saved.has(domain):protected_domains[domain]=saved[domain]
	var previous:WeakRef=weakref(tap)
	world.shutdown_for_tests();remove_child(world);world.free()
	await get_tree().process_frame
	if not _require(previous.get_ref()==null,"retired world releases the original bath and its callbacks"):return
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	var loaded:=_require(RealityState.load_status().status=="loaded" and not RealityState.save_write_blocked,"existing validated campaign loader accepts the complete saved document")
	for domain:String in protected_domains:
		loaded=_require(RealityState.data.get(domain)==protected_domains[domain],"load preserves authoritative domain: "+domain) and loaded
	world=Runtime.instantiate();add_child(world)
	var deadline:=Time.get_ticks_msec()+240000
	while world.startup_ms<=0 and not world.startup_failed and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if not loaded:return
	if not _require(not world.startup_failed and world.startup_ms>0,"saved household reconstructs on a fresh occupied V2 world"):return
	player=world.player
	var restored:TapProp=world.adapter.resolve("F04_4B_SHOWER_01")
	if not _require(restored!=null and restored!=previous.get_ref(),"new 4B bath owner is resolved after rebuild"):return
	await get_tree().physics_frame;await get_tree().physics_frame
	var actual:Dictionary=restored.mechanism_snapshot()
	var exact:=Vector3(actual.plug[0],actual.plug[1],actual.plug[2])==Vector3(wanted.plug[0],wanted.plug[1],wanted.plug[2])
	var error:=0.0
	for field:String in ["hot","cold","curtain","water","diverter"]:error=maxf(error,absf(float(actual[field])-float(wanted[field])))
	_require(exact and error<1e-12,"fresh actor restores the released plug and every saved control/water value")
	_require(restored._held_valve==-1 and not restored._curtain_hand.held and not restored._plug_hand.held,"reload does not resurrect transient input ownership")
	_require(world.bathroom_moisture._rooms["F04_B_BATH"].humidity==0.0,"transient room steam does not reappear as stale saved observations")

func _review_refit(carrier: Node) -> void:
	player.face_world_point(director._bath_anchor.origin)
	var old_cap := Engine.max_fps
	var records: Array[Dictionary]=[]
	var min_up := 1.0
	var valid := true
	var drift_min := Vector2(INF,INF)
	var drift_max := Vector2(-INF,-INF)
	for cap in [30,60,144]:
		Engine.max_fps=cap
		var walls: Array[float]=[]
		var previous := Time.get_ticks_usec()
		for index in 100:
			if index in [10,35,65]:
				var turn := InputEventMouseMotion.new()
				turn.relative=Vector2(35 if index!=35 else -70,0)
				player._unhandled_input(turn)
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			walls.append(float(now-previous)/1000.0);previous=now
			valid=valid and carrier.motion.global_transform.is_finite() and carrier.rig.global_transform.is_finite()
			var up: Vector3=carrier.rig.global_basis.y.normalized()
			min_up=minf(min_up,up.dot(player.camera.global_basis.y.normalized()))
			var drift: Vector2=carrier.screen_frame._drift
			drift_min=drift_min.min(drift);drift_max=drift_max.max(drift)
			var rect: Rect2=carrier.screen_frame.safe_rect
			valid=valid and rect.position.x>=2.0/3.0 and rect.end.x<=1.0
		walls.sort()
		records.append({"cap":cap,"wall_ms_p50":walls[50],"wall_ms_p95":walls[95],"wall_ms_p99":walls[99],"wall_ms_max":walls[-1]})
	Engine.max_fps=old_cap
	_require(valid and min_up>.95,"phone refit remains finite, upright and in the contextual right third at 30/60/144 caps")
	_require((drift_max-drift_min).length()>.005,"accompanying bot follows a visible bounded flight path instead of a pinned pose")
	_require(carrier.rig.global_basis.get_scale().distance_to(Vector3.ONE*.42)<.0001,"single manufactured assembly retains uniform phone-sized scale")
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(.8).timeout
	await _shot("bathroom_phone_accompany.png")
	for pressed in [true,false]:
		var key := InputEventKey.new();key.keycode=KEY_E;key.physical_keycode=KEY_E;key.pressed=pressed
		Input.parse_input_event(key);Input.flush_buffered_events()
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	_require(carrier.reading and carrier.motion.steady_for_input(),"actual recall presents refitted physical interface")
	await _shot("bathroom_phone_reading.png")
	var out := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("phone_flight.json"),FileAccess.WRITE)
	if _require(out!=null,"flight diagnostic output writable"):
		out.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Occupied 4B capped-rate station-keeping and camera-turn diagnostic; no matched performance gain or artistic acceptance.","records":records,"minimum_upright_dot":min_up,"drift_span":str(drift_max-drift_min)},"\t"))

func _review_waking() -> void:
	var load_started:=Time.get_ticks_usec()
	var scene:=load("res://assets/props/prologue_wake_cover.glb") as PackedScene
	var imported_load_ms:float=(Time.get_ticks_usec()-load_started)/1000.0
	if not _require(scene!=null,"imported native wake cover available"):return
	var carrier:Node=world.service_set_carrier
	var draft_before:String=carrier.session.draft
	carrier.session.draft="Unsubmitted waking draft."
	var avatar_before:bool=world.player_avatar.visible
	get_tree().paused=true
	var paused_refused:bool=not director.begin_opening(scene)
	get_tree().paused=false
	if not _require(paused_refused and director.errors.is_empty() and director.waking==null and player.text_input_owner==null,"paused startup refuses without poisoning later retry"):return
	player.call_locked=true
	var protected_refused:bool=not director.begin_opening(scene)
	var protected_retained:bool=player.protected_input_active()
	player.call_locked=false
	if not _require(protected_refused and protected_retained and director.errors.is_empty() and director.state.phase=="dream" and world.player_avatar.visible==avatar_before and not carrier.is_story_absent(),"protected startup refuses without changing visibility, facts or retryability"):return
	if not _require(player.acquire_text_input(self),"fixture editor holds startup input"):return
	var editor_refused:bool=not director.begin_opening(scene)
	var editor_retained:bool=player.text_input_owner==self
	player.release_text_input(self)
	if not _require(editor_refused and editor_retained and director.errors.is_empty() and director.shower.manipulation_changed.is_connected(Callable(director,"_released")),"busy editor refuses without closing input or disconnecting tutorial bindings"):return
	if not _require(director.state.phase=="dream" and director.resume_opening(scene),"public resume starts actual DREAM without preview advancement"):return
	var clip:Node=director.waking
	if not _require(director.resume_opening(scene) and director.waking==clip and clip.age<.01,"repeated resume retains the same active DREAM clip"):return
	var start_costs:Dictionary=clip.start_costs.duplicate(true)
	if not _require(clip.active and player.text_input_owner==clip and not world.player_avatar.visible and carrier.is_story_absent(),"camera/input/absence owners conceal body and bot"):return
	var material:=clip.cover.material_override as StandardMaterial3D
	if not _require(material!=null and not material.uv1_triplanar,"loaded opaque cover uses native UVs"):return
	for texture:Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
		if not _require(texture!=null and texture.get_image()!=null and texture.get_image().has_mipmaps(),"loaded cover PBR map has real mipmaps"):return
	_require(not player.acquire_text_input(self),"another editor cannot steal opening input")
	clip.set_process(false)
	for seconds:float in [0.0,4.5,6.4,9.9]:
		clip.seek(seconds)
		await _shot("wake_%03d.png"%roundi(seconds*10))
	var age_before:float=clip.age
	clip.set_process(true);get_tree().paused=true
	await get_tree().create_timer(.15,true).timeout
	get_tree().paused=false;clip.set_process(false)
	_require(is_equal_approx(age_before,clip.age),"pause preserves waking presentation age")
	director.shutdown()
	if not _require(player.text_input_owner==null and player.camera.is_current() and not carrier.is_story_absent(),"active-shot shutdown survives synchronous finish and releases its leases"):return
	director.queue_free();director=Director.new();world.add_child(director)
	if not _require(director.configure(world) and director.begin_opening(scene),"new director can rebind after active-shot shutdown"):return
	frame_trace.director=director
	clip=director.waking
	player.call_locked=true
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	var protection_preserved:bool=player.protected_input_active()
	player.call_locked=false
	if not _require(protection_preserved and director.waking==null and player.text_input_owner==null and director.state.phase=="dream","protected conversation cancels the shot without clearing its lock or advancing story"):return
	await get_tree().create_timer(.3).timeout
	if not _require(is_instance_valid(director.waking) and director.waking.active,"opening automatically resumes after protected conversation releases input"):return
	var foreign_camera:=Camera3D.new();add_child(foreign_camera)
	foreign_camera.global_transform=player.camera.global_transform;foreign_camera.make_current()
	if not _require(not director.resume_opening(scene) and foreign_camera.is_current(),"resume refuses a foreign camera even while its old shot still owns input"):return
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	var foreign_view_preserved:bool=foreign_camera.is_current()
	player.camera.make_current();foreign_camera.queue_free()
	if not _require(foreign_view_preserved and director.waking==null and player.text_input_owner==null and director.state.phase=="dream","camera takeover cancels without restoring over the new view"):return
	await get_tree().create_timer(.3).timeout
	if not _require(is_instance_valid(director.waking) and director.waking.active,"opening automatically resumes after camera takeover releases its view"):return
	clip=director.waking
	player.release_text_input(clip)
	if not _require(player.acquire_text_input(self),"fixture editor takes a legitimately released input lease"):return
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	var foreign_input_preserved:bool=player.text_input_owner==self
	player.release_text_input(self)
	if not _require(foreign_input_preserved and director.waking==null and director.state.phase=="dream","cancelled shot preserves a successor editor's lease"):return
	await get_tree().create_timer(.3).timeout
	if not _require(is_instance_valid(director.waking) and director.waking.active,"opening automatically resumes after successor editor releases input"):return
	clip=director.waking;clip.set_process(false);clip.seek(6.4)
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("waking_reload.json")
	RealityState.persistence_enabled=true
	var saved:=RealityState.save_game()
	RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	await get_tree().create_timer(.3).timeout
	if not _require(saved and director.state.phase=="dream" and is_instance_valid(director.waking) and player.text_input_owner==director.waking,"validated DREAM reload automatically restages without inventing awakening"):return
	if not _require(director.waking.active and director.waking.age<1.0,"automatic DREAM restaging starts at its saved phase"):return
	clip=director.waking;clip.set_process(false);clip.seek(11.2)
	if not _require(director.state.phase=="awakening","actual shot acknowledges awakening at its handoff"):return
	await _shot("wake_first_person.png")
	clip.seek(13.0)
	await _shot("wake_post_blink.png")
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("awakening_reload.json")
	RealityState.persistence_enabled=true;saved=RealityState.save_game();RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	await get_tree().create_timer(.3).timeout
	if not _require(saved and director.state.phase=="awakening" and is_instance_valid(director.waking) and director.waking.active and director.waking.age>=11.0 and director.waking.age<12.0,"validated awakening reload automatically resumes the first-person segment"):return
	# Let the real frame-driven handoff finish; seeking alone is not proof of
	# pause/lifecycle completion or actual camera/input restoration.
	await get_tree().create_timer(6.5).timeout
	_require(director.state.phase=="bedroom_exploration" and player.text_input_owner==null,"real-time completion releases movement at bedroom exploration")
	_require(player.camera.is_current() and player.global_position.distance_to(world.core_loop.resolve_return_anchor().position)<.10,"handoff uses actual standing anchor and player camera")
	_require(not world.player_avatar.visible and carrier.is_story_absent(),"true body and companion stay concealed after waking")
	await _shot("wake_control_restored.png")
	# A reconstructed opening must use its saved phase rather than the preview
	# which deliberately skips DREAM. Exercise this through real disk storage.
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("bedroom_resume.json")
	RealityState.persistence_enabled=true;saved=RealityState.save_game()
	director.shutdown();director.queue_free()
	RealityState.load_game();RealityState.persistence_enabled=false;RealityState.save_path=old_path
	await get_tree().process_frame
	director=Director.new();world.add_child(director);frame_trace.director=director
	if not _require(saved and director.configure(world),"new director binds the validated bedroom save"):return
	var resume_facts:Dictionary=director.state.duplicate(true)
	if not _require(player.acquire_text_input(self),"successor editor holds saved-opening startup"):return
	var resume_refused:bool=not director.resume_opening(scene)
	var editor_preserved:bool=player.text_input_owner==self
	player.release_text_input(self)
	if not _require(resume_refused and editor_preserved and director.state==resume_facts and not director._running,"saved-opening retry preserves a foreign editor and narrative facts"):return
	if not _require(director.resume_opening(scene) and director.state==resume_facts and director.waking==null,"saved bedroom resumes directly without replaying DREAM or advancing facts"):return
	director._phase_age=2.0
	if not _require(director.resume_opening(scene) and director._phase_age==2.0 and director.message_id=="wake_passed","repeated resume preserves live phase age and surface writing"):return
	_require(not world.player_avatar.visible and carrier.is_story_absent() and player.camera.is_current() and player.text_input_owner==null,"resumed bedroom preserves concealment and player-owned exploration")
	await _shot("wake_bedroom_resumed.png")
	if OS.get_environment("PROLOGUE_WAKE_START_PROFILE")=="1":
		if not await _profile_waking_start(scene):return
	# Replay the saved DREAM boundary once without seeking, screenshots or disk
	# work inside the interval. Keep every raw frame, including setup/handoff.
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("waking_reload.json")
	RealityState.persistence_enabled=true;RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	var continuous_begin:int=frame_trace.rows.size()
	var continuous_started:=Time.get_ticks_usec()
	var preceding_frame_tail_ms:float=(continuous_started-frame_trace.previous)/1000.0
	frame_trace.previous=continuous_started # Align this interval, retaining its preceding tail below.
	var transitions:Array[Dictionary]=[]
	var observe_phase:=func(phase:String):transitions.append({"phase":phase,"wall_s":(Time.get_ticks_usec()-continuous_started)/1000000.0})
	director.phase_changed.connect(observe_phase)
	if not _require(director.begin_opening(scene),"uninterrupted DREAM starts from the validated saved boundary"):return
	clip=director.waking
	var continuous_start_call_ms:float=(Time.get_ticks_usec()-continuous_started)/1000.0
	var continuous_start_costs:Dictionary=clip.start_costs.duplicate(true)
	var concealed:=true
	while is_instance_valid(clip) and clip.active and Time.get_ticks_usec()-continuous_started<26000000:
		concealed=concealed and not world.player_avatar.visible and carrier.is_story_absent() and player.text_input_owner==clip
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	director.phase_changed.disconnect(observe_phase)
	var continuous_end:int=frame_trace.rows.size()
	var continuous_wall_s:float=(Time.get_ticks_usec()-continuous_started)/1000000.0
	_require(concealed and director.state.phase=="bedroom_exploration" and player.camera.is_current() and player.text_input_owner==null,"uninterrupted DREAM conceals identities and completes the real camera/input handoff")
	var phases:Array[String]=[]
	for transition:Dictionary in transitions:phases.append(str(transition.phase))
	_require(phases==["awakening","bedroom_exploration"],"continuous playback acknowledges each phase once in order")
	var continuous_frames:Array=frame_trace.rows.slice(continuous_begin,continuous_end)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("waking_continuous_frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","columns":["phase","fps_cap","process_delta_ms","wall_ms","process_monitor_ms","physics_monitor_ms","draw_calls"],"frames":continuous_frames,"transitions":transitions,"wall_s":continuous_wall_s,"preceding_frame_tail_ms":preceding_frame_tail_ms,"start_call_sync_ms":continuous_start_call_ms,"same_clip_start_costs_ms":continuous_start_costs,"settings":frame_trace.settings,"limits":"One occupied, warmed DREAM playback including synchronous setup and handoff. Wall counter starts at the interval boundary; preceding_frame_tail_ms retains the excluded pre-boundary tail including reload. No screenshot readbacks, seeks, pause or disk operations inside the measured interval. CPU monitors overlap/lag; no separated GPU/compiler/loading attribution or matched optimization claim."},"\t"))
	# Synthetic completed-save boundary only: this does not claim the finale
	# was played, apply a clock jump, or fabricate earned gameplay observations.
	var completed:Dictionary=director.state.duplicate(true)
	completed.phase="prologue_complete";completed.skipped=true
	completed.effects={"companion_materialized":true,"clock_applied":true}
	completed.target={"utc_unix_seconds":preload("res://scripts/game/prologue_state.gd").LOOP_START_UTC+86400,"local_bias_minutes":-300,"local_zone":"Queens EST"}
	if not _require(preload("res://scripts/game/prologue_state.gd").valid(completed),"synthetic completed boundary satisfies the prologue validator"):return
	RealityState.data.prologue=completed
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("completed_boundary.json")
	RealityState.persistence_enabled=true;saved=RealityState.save_game();RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	if not _require(saved and director.state.phase=="prologue_complete" and not director.is_processing(),"validated completed boundary retires active presentation"):return
	director.shutdown();director.queue_free()
	await get_tree().process_frame
	director=Director.new();world.add_child(director);frame_trace.director=director
	if not _require(director.configure(world) and director.resume_opening(scene) and not director._running and director.waking==null,"fresh completed-save owner remains inert without replay"):return
	if not _require(player.acquire_text_input(self),"successor editor owns input across completed-to-earlier reload"):return
	var before_reload_position:Vector3=player.global_position
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("bedroom_resume.json")
	RealityState.persistence_enabled=true;RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	var restored_facts:Dictionary=director.state.duplicate(true)
	await get_tree().create_timer(.3).timeout
	if not _require(player.text_input_owner==self and not director._running and director.state==restored_facts and player.global_position.distance_to(before_reload_position)<.05,"earlier reload waits without stealing editor input, moving the player or advancing facts"):return
	player.release_text_input(self)
	get_tree().paused=true
	await get_tree().create_timer(.2,true).timeout
	var paused_reload_dormant:bool=not director._running and player.text_input_owner==null
	get_tree().paused=false
	if not _require(paused_reload_dormant,"pending completed-to-earlier resume remains dormant while paused"):return
	await get_tree().create_timer(.3).timeout
	if not _require(director._running and director.waking==null and director.message_id=="wake_passed" and director.state==restored_facts,"completed-to-earlier reload automatically resumes saved bedroom after input release"):return
	await get_tree().create_timer(1.5).timeout
	await _shot("wake_after_completed_reload.png")
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("completed_boundary.json")
	RealityState.persistence_enabled=true;RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	if not _require(director.state.phase=="prologue_complete" and not director.is_processing(),"forward reload retires the resumed opening again"):return
	var reload_camera:=Camera3D.new();reload_camera.cull_mask=player.camera.cull_mask;add_child(reload_camera)
	reload_camera.global_transform=player.camera.global_transform;reload_camera.make_current()
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("waking_reload.json")
	RealityState.persistence_enabled=true;RealityState.load_game()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	await get_tree().create_timer(.3).timeout
	if not _require(reload_camera.is_current() and not director._running and director.waking==null and director.state.phase=="dream","completed-to-DREAM reload preserves a foreign camera while waiting"):return
	player.camera.make_current();reload_camera.queue_free()
	await get_tree().create_timer(.3).timeout
	if not _require(is_instance_valid(director.waking) and director.waking.active and director.state.phase=="dream" and not world.player_avatar.visible and carrier.is_story_absent(),"completed-to-DREAM reload starts the saved shot after foreign view release"):return
	director.shutdown()
	await get_tree().create_timer(.3).timeout
	_require(carrier.session.draft=="Unsubmitted waking draft.","waking does not alter typed drafts")
	_require(player.text_input_owner==null and not carrier.is_story_absent() and director.waking==null and not director.is_processing(),"shutdown releases opening leases without an automatic restart")
	carrier.session.draft=draft_before
	frame_trace.complete=failures.is_empty()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("waking_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","failures":failures,"state":director.state,"imported_scene_load_ms":imported_load_ms,"start_costs_ms":start_costs,"limits":"Focused occupied DREAM/wake imported-cover, camera, pause, input and validated-reload diagnostic. Synchronous timings exclude deferred renderer/compiler work. Does not prove normal entry, full prologue, frame-time qualification or human artistic acceptance."},"\t"))

func _check_return_anchor_resolution() -> bool:
	var fixture:=Node3D.new();add_child(fixture)
	fixture.position=Vector3(2,3,4);fixture.rotation.y=.7
	var stance:=Node3D.new();stance.name="F04_B_BEDSIDE_RETURN";fixture.add_child(stance)
	stance.position=Vector3(1,2,3)
	var bed:=Node3D.new();bed.name="F04_B_BED";fixture.add_child(bed)
	var adapter:=preload("res://scripts/building/orison_v2_anchor_adapter.gd").new(fixture)
	var resolved:Dictionary=adapter.resolve_return_anchor("F04_B_BED")
	var ok:=_require(resolved.position==stance.global_position and resolved.facing_position==bed.global_position+Vector3.UP*.2,"return anchor keeps actual transformed stance and bed facing")
	stance.position+=Vector3.ONE
	ok=_require(adapter.resolve_return_anchor("F04_B_BED").position==stance.global_position,"return anchor reads moved markers without stale caching") and ok
	var group:=Node3D.new();fixture.add_child(group)
	var duplicate_bed:=Node3D.new();duplicate_bed.name="F04_B_BED";group.add_child(duplicate_bed)
	resolved=adapter.resolve_return_anchor("F04_B_BED")
	ok=_require(resolved.position==stance.global_position and not resolved.has("facing_position"),"ambiguous bed preserves stance but supplies no invented facing") and ok
	var duplicate_stance:=Node3D.new();duplicate_stance.name="F04_B_BEDSIDE_RETURN";group.add_child(duplicate_stance)
	ok=_require(adapter.resolve_return_anchor("F04_B_BED").is_empty(),"ambiguous return stance refuses resolution") and ok
	group.free();stance.free()
	var wrong_kind:=Node.new();wrong_kind.name="F04_B_BEDSIDE_RETURN";fixture.add_child(wrong_kind)
	ok=_require(adapter.resolve_return_anchor("F04_B_BED").is_empty(),"nonspatial return stance refuses resolution") and ok
	ok=_require(adapter.resolve_return_anchor("unrelated").is_empty(),"return-anchor resolver does not adopt an unrelated identity") and ok
	fixture.free()
	return ok

func _check_plug_support_index() -> bool:
	var count:=0
	var points:=0
	for fixture:Node in world.household_state._subjects.values():
		if not fixture is TapProp:continue
		var plug:Variant=fixture.get("_plug_hand")
		if plug==null or plug.get_script()!=preload("res://scripts/props/basin_plug.gd"):continue
		count+=1
		# Include bin boundaries, the drain opening and disc-rim queries beyond
		# the manipulation envelope. Compare actual imported casting triangles.
		for x in [-.168,-.15,-.12,-.04,0.,.04,.12,.15,.168]:
			for z in [-.093,-.075,-.04,0.,.04,.075,.093]:
				var at:Vector3=plug.seat+Vector3(x,0,z)
				var expected:float=plug.seat.y
				for i in range(0,plug.triangles.size(),3):
					var a:Vector3=plug.triangles[i];var b:Vector3=plug.triangles[i+1];var c:Vector3=plug.triangles[i+2]
					var den:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
					var u:float=((b.z-c.z)*(at.x-c.x)+(c.x-b.x)*(at.z-c.z))/den
					var v:float=((c.z-a.z)*(at.x-c.x)+(a.x-c.x)*(at.z-c.z))/den
					if u<0 or v<0 or u+v>1:continue
					var y:float=u*a.y+v*b.y+(1-u-v)*c.y
					if y<=plug.ceiling:expected=maxf(expected,y+.006)
				if absf(plug._surface_height(at)-expected)>.0000001:
					return _require(false,"indexed basin support matches full casting scan: "+str(fixture.name))
				points+=1
	return _require(count>=24 and points>=1512,"indexed basin support matches original full scan across %d installed plugs and %d points"%[count,points])

func _profile_waking_start(scene:PackedScene) -> bool:
	# Diagnostic controls only. Keep reload/shot owners intact and never use
	# disabled presentation as a production optimization or acceptance route.
	if not _check_plug_support_index():return false
	var trials:Array=[]
	var old_path:String=RealityState.save_path
	var household_profile_before:bool=world.household_state.profiling
	var save_profile_before:bool=RealityState.background_save_profiling
	world.household_state.profiling=true
	RealityState.background_save_profiling=true
	var viewport:RID=get_viewport().get_viewport_rid()
	var measured_views:Array[Viewport]=[get_viewport()]
	for node:Node in get_tree().root.find_children("*","Viewport",true,false):
		if node!=get_viewport():measured_views.append(node as Viewport)
	for view:Viewport in measured_views:RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var compile_infos:Array[int]=[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]
	for presentation:bool in [false,true,true,false]:
		if is_instance_valid(director.waking):director.waking.cancel()
		director.set_process(false)
		await get_tree().process_frame;await get_tree().process_frame
		var began:=Time.get_ticks_usec()
		RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("waking_reload.json")
		RealityState.persistence_enabled=true;RealityState.load_game()
		RealityState.persistence_enabled=false;RealityState.save_path=old_path
		var loaded:=Time.get_ticks_usec()
		var trial:Dictionary={"presentation":presentation,"reload_sync_ms":(loaded-began)/1000.0,"reload_begin_usec":began,"reload_end_usec":loaded,"frames":[]}
		var start_began:=Time.get_ticks_usec()
		if presentation:
			if not _require(director.begin_opening(scene),"profile control starts the real waking owner"):return false
			trial.same_clip_start_costs_ms=director.waking.start_costs.duplicate(true)
		trial.start_call_sync_ms=(Time.get_ticks_usec()-start_began)/1000.0
		var previous_wall:=start_began
		var previous_physics:=Engine.get_physics_frames()
		for frame in 32:
			# The first draw belongs to this triggering iteration. Waiting for
			# another process_frame here would skip precisely the suspected work.
			if frame>0:await get_tree().process_frame
			var process_at:=Time.get_ticks_usec()
			await RenderingServer.frame_pre_draw
			var pre_at:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var post_at:=Time.get_ticks_usec()
			var probe_began:=post_at
			var counters:Array=[]
			for info:int in compile_infos:counters.append(RenderingServer.get_rendering_info(info))
			var view_times:Array=[]
			for view:Viewport in measured_views:
				if not is_instance_valid(view) or not view.is_inside_tree():continue
				var rid:=view.get_viewport_rid()
				view_times.append({"owner":str(view.get_path()),"update_mode":view.render_target_update_mode if view is SubViewport else -1,
					"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),
					"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)})
			var current_physics:=Engine.get_physics_frames()
			var sample:Dictionary={"index":frame,"engine_drawn":Engine.get_frames_drawn(),
				"process_usec":process_at,"pre_draw_usec":pre_at,"post_draw_usec":post_at,
				"wall_ms":(post_at-previous_wall)/1000.0,"process_to_post_draw_ms":(post_at-process_at)/1000.0,
				"process_to_pre_draw_ms":(pre_at-process_at)/1000.0,"pre_to_post_draw_ms":(post_at-pre_at)/1000.0,
				"physics_steps":current_physics-previous_physics,"viewports":view_times,
				"process_peak_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
				"physics_peak_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
				"render_setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),
				"main_viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),
				"main_viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),
				"pipeline_totals":counters}
			sample.probe_sync_ms=(Time.get_ticks_usec()-probe_began)/1000.0
			trial.frames.append(sample)
			previous_wall=post_at
			previous_physics=current_physics
		trial.phase_after=director.state.phase
		trial.household_events=world.household_state.profile_records.filter(func(row:Dictionary)->bool:return int(row.start_usec)>=began)
		trial.household_causes=world.household_state.profile_causes.filter(func(row:Dictionary)->bool:return int(row.start_usec)>=began)
		trial.save_events=RealityState.background_save_records.filter(func(row:Dictionary)->bool:return int(row.get("started_usec",row.get("adopted_usec",0)))>=began)
		trials.append(trial)
	if is_instance_valid(director.waking):director.waking.cancel()
	director.set_process(true)
	world.household_state.profiling=household_profile_before
	RealityState.background_save_profiling=save_profile_before
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("waking_start_controls.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","trials":trials,"settings":frame_trace.settings,
		"pipeline_columns":["canvas","mesh","surface","draw","specialization"],
		"limits":"ABBA reload-without-shot / reload-with-shot controls in one occupied world. The triggering draw is captured before waiting for another process_frame. Only automatic presentation is held in no-shot controls; real save/read, camera and renderer owners still run. Per-viewport last-frame metrics can lag or stay stale when inactive; do not sum them into a same-frame GPU total. Draw signal wall time is not GPU time; process/physics monitors are one-second peaks, not per-frame costs. Physics step counts show cadence only. Pipeline counters are cumulative correlation. probe_sync_ms records metric-read overhead, which can enter the following wall sample. Extra instrumentation affects these diagnostics; not runtime or artistic acceptance."},"\t"))
	return _require(trials.size()==4 and director.state.phase=="dream","ABBA controls retain the same saved DREAM without fabricated progression")

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var saved := get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name_))
	_require(saved==OK,"capture written "+name_)


func _full_sequence_wake() -> bool:
	# No reducer advancement, seek or skip: use the public production shot owner.
	if not _require(director.resume_opening(preload("res://assets/props/prologue_wake_cover.glb")),"full sequence begins actual DREAM through public resume"):return false
	var deadline:=Time.get_ticks_msec()+30000
	var captured:=false
	while director.state.phase in ["dream","awakening"] and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not captured and is_instance_valid(director.waking) and director.waking.age>=6:
			captured=true;await _shot("full_sequence_dream.png")
	return _require(captured and director.state.phase=="bedroom_exploration" and player.camera.is_current() and player.text_input_owner==null,"natural DREAM/wake hands camera and input to actual bedroom exploration")

func _full_sequence_ending() -> void:
	var carrier:Node=world.service_set_carrier
	var rig_id:int=carrier.rig.get_instance_id()
	var draft:String=carrier.session.draft
	var expected:Array[String]=["Sorry you died.","But if it makes you feel better, I can help you solve your murder!","First we need to solve a bigger mystery.","Who were you?","I am connecting you to the present, please stay on the line..."]
	var seen:Array[String]=[]
	var phase_trace:Array[Dictionary]=[]
	var last_phase:=""
	var captured_cutaway:Array[int]=[]
	var deadline:=Time.get_ticks_msec()+240000
	var start_clock:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	while director.state.phase!="prologue_complete" and Time.get_ticks_msec()<deadline and failures.is_empty():
		await get_tree().process_frame
		var phase:String=director.state.phase
		if phase!=last_phase:
			phase_trace.append({"phase":phase,"usec":Time.get_ticks_usec()});last_phase=phase
		var paper:Node=carrier.device.teletype
		var copy:String=" ".join(str(paper.ink.text).replace("\n"," ").split(" ",false))
		if paper.copy_delivered() and expected.has(copy) and not seen.has(copy):
			seen.append(copy)
			_require(await _contact_ink_pixels(paper)>copy.length()*4,"full sequence delivers visible physical copy: "+copy)
			await _shot("full_sequence_contact_%d.png"%seen.size())
		if phase=="title_reveal" and is_instance_valid(director.temporal_sky):
			var clip:Node=director.temporal_sky
			if is_instance_valid(clip.cutaway):
				for boundary:int in [45,85,140]:
					if clip.cutaway.age>=float(boundary)/10.0 and not captured_cutaway.has(boundary):
						captured_cutaway.append(boundary);await _shot("full_sequence_stinger_%03d.png"%boundary)
						if boundary==140:
							_require(clip._veil.is_visible_in_tree() and clip.cutaway.title.is_visible_in_tree(),"production-parented cinematic retains its own visible veil and title")
							_require(_full_sequence_title_pixels(),"actual title frame is black with centered white lettering")
	_require(seen==expected,"full sequence delivers the five exact lines in order without a staged first-contact save")
	_require(director.errors.is_empty() and director.state.phase=="prologue_complete" and not director.state.skipped,"real arm command, natural seasonal sky and unskipped17-second cutaway finish")
	_require(captured_cutaway==[45,85,140],"natural cutaway reaches silhouette, wait and title without seeking its clock")
	_require(director.state.effects.clock_applied and director.state.effects.companion_materialized and carrier.rig.get_instance_id()==rig_id and carrier.session.draft==draft,"one companion and its typed draft survive natural temporal completion")
	_require(player.camera.is_current() and player.text_input_owner==null and not director.is_processing(),"completed sequence releases cinematic camera, input and director polling")
	_require(world.shop_simulation.advance_current() and not world.shop_simulation.failed,"existing shop authority accepts the adopted clock without a future elapsed cursor")
	if failures.is_empty():await _reload_completed_sequence(carrier,rig_id)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("full_sequence_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"One occupied world, public DREAM/wake owner, actual bed-to-bath movement and gestures, existing witnessed-visitor/crossing reload controls, natural first-contact/arm/sky/stinger and completed validated reload. No title-button launch, uninterrupted no-reload run, complete save-boundary matrix or human acceptance.","phases":phase_trace,"lines":seen,"cutaway_samples":captured_cutaway,"initial_clock":start_clock,"final_clock":RealityState.data.campaign_clock,"state":director.state,"failures":failures},"\t"))
	frame_trace.complete=failures.is_empty()


func _reload_completed_sequence(carrier:Node,rig_id:int) -> void:
	# This is a real validated save/reload, independent of cinematic timing.
	var old_path:String=RealityState.save_path
	var old_enabled:bool=RealityState.persistence_enabled
	var facts:Dictionary=director.state.duplicate(true)
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("full_sequence_complete_save.json")
	RealityState.persistence_enabled=true
	if _require(RealityState.save_game(),"completed actual sequence writes a validated campaign save"):
		RealityState.load_game();await get_tree().process_frame;await get_tree().process_frame
		_require(director.state==facts and player.text_input_owner==null and player.camera.is_current() and carrier.rig.get_instance_id()==rig_id,"completed sequence reload is idempotent and retains its single machine")
		_require(world.shop_simulation.advance_current() and not world.shop_simulation.failed,"completed reload retains a usable shop simulation and cursor")
	RealityState.persistence_enabled=old_enabled;RealityState.save_path=old_path


func _full_sequence_title_pixels() -> bool:
	var path:=OS.get_environment("SHOT_DIR").path_join("full_sequence_stinger_140.png")
	var frame:=Image.load_from_file(path)
	if frame==null:return false
	var sampled:=0
	var dark:=0
	var white_center:=0
	for y in range(0,frame.get_height(),4):
		for x in range(0,frame.get_width(),4):
			var pixel:Color=frame.get_pixel(x,y)
			sampled+=1
			if maxf(pixel.r,maxf(pixel.g,pixel.b))<.025:dark+=1
			if x>frame.get_width()/4 and x<frame.get_width()*3/4 and y>frame.get_height()*2/5 and y<frame.get_height()*3/5 and minf(pixel.r,minf(pixel.g,pixel.b))>.7:white_center+=1
	return float(dark)/sampled>.98 and white_center>100
