extends Node
## One historical presentation of the existing private specimen. No clock,
## ecology, lamp-switch or save authority lives here.
const DURATION:=17.0
const WALK:=.40
const TURN:=.12
const STRIDE:=.085
const STORM:="res://assets/audio/freesound/processed/beds/ambient_roof_storm_city.ogg"
var active:=false
var age:=0.0
var scope:Node
var controller:DreamCritterController
var specimen:Dictionary
var original:Dictionary
var frame:Node3D
var lamp_air:Node3D
var light:SpotLight3D
var title:Label
var storm:AudioStreamPlayer
var shuffle:AudioStreamPlayer3D
var _camera:Camera3D
var _avatar_visible:=true
var _controller_visible:=true
var start_costs:Dictionary={}
var _lamp:SpotLight3D
var _origin:Vector3
var _facing:Vector3
var _done:Callable
var _campaign:Dictionary
var _population:Array
var _residue:ShaderMaterial
var _canvas:Array[Dictionary]=[]
var _extra_audio:Array[Dictionary]=[]
var failure:=""
var _quiet:=false
var _shuffled:=false
var _posed_travel:=INF
var _posed_lift:=INF
var _posed_eye:=Vector3.INF

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false);set_process_unhandled_input(false)

static func sample(seconds:float) -> Dictionary:
	var t:=clampf(seconds,0,DURATION)
	return {"travel":WALK*smoothstep(4.8,6.5,t)+TURN*smoothstep(10.5,11.2,t)+WALK*smoothstep(11.2,12.5,t),
		"lift":smoothstep(6.5,8.5,t)*(1.0-smoothstep(10.5,11.0,t)),
		"dolly":smoothstep(1.5,3.5,t),"flash":t>=4.5 and t<4.8,
		"black":t>=13.5,"title":t>=14.0,"finished":t>=DURATION}

func start(owner_scope:Node,completion:Callable) -> bool:
	if active or not is_instance_valid(owner_scope) or not owner_scope.holding or not completion.is_valid():return _fail("missing held presentation scope")
	var began:=Time.get_ticks_usec()
	var mark:=began
	scope=owner_scope;frame=scope.world.adapter.root
	# setup() assigns the controller's real node name. Bind the unique existing
	# private companion by its authority/player, not its earlier requested name.
	for candidate:Node in scope.world.get_children():
		if candidate is DreamCritterController and candidate.companion!=null and candidate.companion.player==scope.player:
			if controller!=null:return _fail("ambiguous existing companion owner")
			controller=candidate
	lamp_air=scope.world.get_node_or_null("LampAtmosphere")
	if controller==null:return _fail("missing existing companion owner")
	if lamp_air==null or lamp_air.field==null or not lamp_air.field.ready:return _fail("shared optical field is not ready")
	for c:Dictionary in controller.critters:
		if int(c.id)==int(controller.companion.specimen_id):specimen=c;break
	if specimen.is_empty() or int(specimen.morph.limbs)!=8 or controller.blender_visuals==null:return _fail("existing eight-legged specimen is unavailable")
	if scope.player.text_input_owner!=scope or scope.world.process_mode!=Node.PROCESS_MODE_DISABLED:return _fail("cinematic input or freeze ownership changed")
	var bed:Node3D=scope.world.adapter.resolve("4B_wake_bed")
	if bed==null:return _fail("missing installed bed")
	# Original bed placement, not the semantic wake anchor's nominal height.
	var bed_at:=frame.to_local(bed.global_position)
	_origin=frame.to_global(Vector3(bed_at.x+.20,bed_at.y,bed_at.z))
	var departure:=Vector3.INF
	for door:Dictionary in scope.world.layout.doors:
		if str(door.id)=="F04_B_BATH_DOOR":departure=frame.to_global(Vector3(float(door.center[0]),bed_at.y,float(door.center[1])))
	if not departure.is_finite():return _fail("missing original bathroom departure doorway")
	_facing=(departure-_origin).normalized()
	original=specimen.duplicate(true);_population=controller.critters;_campaign=RealityState.data;_done=completion
	start_costs.binding_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	_lamp=lamp_air.scene_shadow.lamp;active=true
	_controller_visible=controller.visible;controller.show()
	_camera=scope.player.camera;scope.player.camera=scope.camera
	_avatar_visible=scope.world.player_avatar.visible;scope.world.player_avatar.hide()
	for layer:CanvasLayer in scope._canvas_layers:
		if not is_instance_valid(layer):continue
		_canvas.append({"node":layer,"visible":layer.visible});layer.hide()
	_quiet=bool(GameBoot.settings.get("reduce_flashing",false))
	start_costs.visibility_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	scope.camera.fov=64
	# Reuse the shared instantaneous field and depth camera. This controlled
	# room-bounce source is transient; the absent bot's electrical state stays put.
	light=SpotLight3D.new();light.name="HistoricalStormBounce";add_child(light)
	light.spot_range=5;light.spot_angle=52;light.shadow_enabled=true
	light.light_size=.02
	light.shadow_caster_mask=scope.player.flashlight.shadow_caster_mask
	light.light_cull_mask=1|(1<<14)|lamp_air.ReceiverBinding.LAYER
	light.light_color=Color(.67,.74,.92)
	light.global_position=frame.to_global(Vector3(bed_at.x+1.5,bed_at.y+.60,bed_at.z-.2))
	light.look_at(_origin+Vector3.UP*.12)
	lamp_air.receivers.select_lamp(light);lamp_air.scene_shadow.lamp=light
	start_costs.optics_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	for record:Dictionary in scope._audio:
		if is_instance_valid(record.node):record.node.volume_db=-80
	# New clock-mounted sources were tracked by the scope's bounded listener.
	for node:Node in scope._late_audio:
		if is_instance_valid(node):
			_extra_audio.append({"node":node,"volume":node.volume_db});node.volume_db=-80
	start_costs.audio_scan_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	storm=AudioStreamPlayer.new();storm.name="HistoricalStormRoomTone"
	storm.process_mode=Node.PROCESS_MODE_PAUSABLE
	storm.stream=load(STORM);storm.volume_db=-25;add_child(storm);storm.play()
	shuffle=AudioStreamPlayer3D.new();shuffle.process_mode=Node.PROCESS_MODE_PAUSABLE;shuffle.stream=_rustle();shuffle.volume_db=-21;shuffle.max_distance=5;add_child(shuffle)
	start_costs.audio_setup_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	title=Label.new();title.text="PLEASE STAY ON THE LINE"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",roundi(60.0*get_viewport().get_visible_rect().size.y/1440.0))
	scope._veil.get_parent().add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.hide()
	_residue=ShaderMaterial.new();_residue.shader=preload("res://shaders/prologue_temporal_residue.gdshader")
	# Detached source rendering only. The authoritative clock is already present.
	var historical:=float(Time.get_unix_time_from_datetime_string("1928-11-10T23:00:00"))
	scope.view_clock.seek_utc(historical);scope.sampled_utc=historical
	start_costs.display_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	scope._publish()
	start_costs.historical_sky_ms=(Time.get_ticks_usec()-mark)/1000.0;mark=Time.get_ticks_usec()
	active=true;set_process(true);set_process_unhandled_input(true);seek(0)
	start_costs.first_pose_ms=(Time.get_ticks_usec()-mark)/1000.0
	start_costs.total_ms=(Time.get_ticks_usec()-began)/1000.0
	if scope.profile_samples:scope.finish_costs.cutaway_start=start_costs.duplicate()
	return true

func _body_at(distance:float) -> Transform3D:
	var d:=clampf(distance,0,WALK*2+TURN)
	var outward:Vector3=(frame.global_basis*Vector3.RIGHT).normalized()
	var at:=_origin+outward*minf(d,WALK)
	var facing:=_facing
	if d>WALK:facing=facing.rotated(Vector3.UP,PI*clampf((d-WALK)/TURN,0,1))
	if d>WALK+TURN:at-=outward*(d-WALK-TURN)
	return Transform3D(Basis.looking_at(-facing,Vector3.UP),at)

func _pose(distance:float,lift:float) -> void:
	var body:=_body_at(distance)
	var f:Vector3=body.basis.z
	var m:Dictionary=specimen.morph
	specimen.pos=body.origin+Vector3.UP*float(m.tall)*.52
	specimen.up=Vector3.UP;specimen.fwd=f;specimen.moving=false
	specimen.gait=float(original.gait)+distance/STRIDE*TAU
	specimen.spin=float(original.spin)+lift*.12;specimen.tun=0;specimen.meal=Vector4.ZERO
	var legs:Array=[]
	for index in 8:
		var flank:float=-1.0 if index<4 else 1.0
		var row:=index%4;var fore:=lerpf(.40,-.40,float(row)/3)
		var offset:=float(index%2)*.5+float(row)/3*.20+float(m.limb_stagger)*index
		if row==3:offset+=.10
		var phase:=fposmod(distance/STRIDE+offset,1.0)
		var anchor:float=(floor(distance/STRIDE+offset)-offset+.365)*STRIDE
		var a:=_foot_at(anchor,fore,flank)
		var b:=_foot_at(anchor+STRIDE,fore,flank)
		var swing:=clampf((phase-.73)/.27,0,1)
		var foot:=a.lerp(b,smoothstep(0,1,swing))
		var motion:=sin(PI*clampf(distance/WALK,0,1)) if distance<=WALK else sin(PI*clampf((distance-WALK)/(WALK+TURN),0,1))
		foot+=Vector3.UP*sin(swing*PI)*float(m.tall)*.25*motion
		if index==0:foot+=(Vector3.UP*.075+f*.035)*lift
		legs.append({"foot":foot,"was_stance":phase<.73 and not (index==0 and lift>0),"phase":phase})
	specimen.leg_state=legs
	# Only the existing specimen is presented; no population membership or
	# lifecycle signal changes. Restore the actual array immediately after packing.
	var population:Array=controller.critters
	controller.critters=[specimen];controller._push();controller.critters=population
	shuffle.global_position=body.origin

func _foot_at(distance:float,fore:float,flank:float) -> Vector3:
	var body:=_body_at(distance);var f:Vector3=body.basis.z
	var side:=Vector3.UP.cross(f).normalized();var m:Dictionary=specimen.morph
	return body.origin+f*fore*float(m.length)+side*flank*float(m.wide)*.70

func seek(seconds:float) -> void:
	if not active or not is_finite(seconds):return
	var previous:=age;age=clampf(seconds,0,DURATION)
	var beat:=sample(age)
	var bed_at:=frame.to_local(_origin)
	var at:=Vector3(bed_at.x+1.6,bed_at.y+.85,bed_at.z)
	at=at.lerp(Vector3(bed_at.x+1.30,bed_at.y+.32,bed_at.z-.05),float(beat.dolly))
	scope.camera.global_position=frame.to_global(at)
	scope.camera.look_at(frame.to_global(Vector3(bed_at.x+.20,bed_at.y+.18,bed_at.z-.12)))
	scope._veil.color=Color(0,0,0,1.0 if beat.black else .08*(1-smoothstep(0,1,age)))
	scope._veil.material=_residue if age<1.0 and not _quiet else null
	if age<1.0:_residue.set_shader_parameter("age",age)
	title.visible=bool(beat.title)
	# Camera and authoring state are unchanged during the patient hold. Keep
	# biological shader motion, but do not repack the identical anatomy each frame.
	if _posed_travel!=float(beat.travel) or _posed_lift!=float(beat.lift) or _posed_eye!=scope.camera.global_position:
		_pose(float(beat.travel),float(beat.lift))
		_posed_travel=float(beat.travel);_posed_lift=float(beat.lift);_posed_eye=scope.camera.global_position
	light.light_energy=0.0 if age<4.5 or age>=12.5 else (.55 if _quiet else (2.6 if beat.flash else .35))
	lamp_air.observation.observe_light(light,light.light_energy>0,maxf(age-previous,.00001))
	lamp_air.field.observe(lamp_air.observation)
	lamp_air.scene_shadow._process(0)
	if age>=3.5 and not _shuffled and previous<3.5:
		_shuffled=true;shuffle.play()
	if bool(beat.black):storm.stop();shuffle.stop()
	if bool(beat.finished):
		var accepted:bool=_done.call(false)
		scope.finish_cutaway(accepted)

func _process(delta:float) -> void:
	if not active or get_tree().paused:return
	if not scope.holding or not is_same(_campaign,RealityState.data) or RealityState.save_write_blocked or scope.player.protected_input_active() or scope.player.text_input_owner!=scope:
		scope.cancel();return
	seek(age+delta)

func _unhandled_input(event:InputEvent) -> void:
	if not active or get_tree().paused or event.is_echo():return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var accepted:bool=_done.call(true);scope.finish_cutaway(accepted)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();scope.cancel()

func release() -> void:
	if not active:return
	active=false;set_process(false);set_process_unhandled_input(false)
	if is_instance_valid(storm):storm.stop()
	if is_instance_valid(shuffle):shuffle.stop()
	if is_instance_valid(scope.player):scope.player.camera=_camera
	if is_instance_valid(scope.world) and is_instance_valid(scope.world.player_avatar):scope.world.player_avatar.visible=_avatar_visible
	for record:Dictionary in _canvas:
		if is_instance_valid(record.node):record.node.visible=record.visible
	_canvas.clear()
	for record:Dictionary in _extra_audio:
		if is_instance_valid(record.node):record.node.volume_db=record.volume
	_extra_audio.clear()
	if is_instance_valid(controller):
		specimen.clear();specimen.merge(original,true);controller.critters=_population;controller._push()
		controller.visible=_controller_visible;controller.refresh_temporal_presence()
	if is_instance_valid(lamp_air) and lamp_air.field!=null:
		lamp_air.receivers.select_lamp(_lamp);lamp_air.scene_shadow.lamp=_lamp
		lamp_air._update_volume(0);lamp_air.scene_shadow._process(0)
	if is_instance_valid(light):light.queue_free()
	if is_instance_valid(title):title.queue_free()

static func _rustle() -> AudioStreamWAV:
	var bytes:=PackedByteArray();bytes.resize(11025*2)
	var value:=17;var low:=0.0
	for index in 11025:
		value=(value*1664525+1013904223)&0x7fffffff
		low=lerpf(low,float(value%65536)/32768.0-1.0,.12)
		var envelope:=sin(PI*float(index)/11025.0)
		bytes.encode_s16(index*2,roundi(low*envelope*2600))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050;wav.data=bytes
	return wav

func _exit_tree() -> void:
	if active:release()

func _fail(reason:String) -> bool:
	failure=reason
	return false
