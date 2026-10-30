extends Node
## One borrowed rig and mirror feed. No second actor, clock or reflection view.
signal finished(completed:bool)
var director:Node
var carrier:Node
var player:PlayerController
var age:=0.0
var active:=false
var world_stage:=false
var handing_off:=false
var _document:Dictionary
var _normal:=Vector3.ZERO
var _opening:=Vector3.ZERO
var _start:=Vector3.ZERO
var _basis:=Basis.IDENTITY
var _home_motion:=Transform3D.IDENTITY
var _home_rig:=Transform3D.IDENTITY
var _motor:AudioStreamPlayer3D

func _init() -> void:set_process(false)

func start(owner:Node) -> bool:
	if active or owner.state.phase!="companion_crossing" or not owner._mirror_observed():return false
	director=owner;carrier=owner._carrier;player=owner.player
	if not carrier.is_story_absent() or not player.acquire_text_input(self):return false
	_document=RealityState.data
	_normal=owner.mirror.mirror_normal();_basis=owner._visitor_basis
	_start=owner._visitor_center
	var pane:MeshInstance3D=owner.mirror.mirror_surface()
	_opening=owner.mirror.mirror_center()+pane.global_basis.x.normalized()*.11+pane.global_basis.y.normalized()*.06
	_home_motion=carrier._story_motion_home;_home_rig=carrier._story_rig_home
	owner._visitor_active=false
	if is_instance_valid(owner._knock):owner._knock.stop()
	carrier.rig.play_reaction("clockwork_thought")
	_motor=AudioStreamPlayer3D.new();_motor.name="AcrossTheGlassMotor"
	_motor.stream=preload("res://assets/audio/freesound/processed/mechanical/mechanical_hum_loop.ogg")
	_motor.volume_db=-48;_motor.max_distance=3;_motor.unit_size=.5
	if AudioServer.get_bus_index("SFX")>=0:_motor.bus="SFX"
	add_child(_motor);_motor.global_position=_opening;_motor.play()
	active=true;set_process(true)
	return true

func _pose(center:Vector3,basis:Basis) -> Transform3D:
	var offset:Vector3=basis*(carrier.screen_frame.stock_bounds.get_center()*carrier.PRESENTATION_SCALE)
	return Transform3D(basis,center-offset)

func _process(delta:float) -> void:
	if not active:return
	if not is_same(_document,RealityState.data) or director.state.phase!="companion_crossing" or not player.camera.is_current() or player.text_input_owner!=self or RealityState.save_write_blocked:
		cancel();return
	if handing_off:return
	age+=maxf(delta,0)
	_motor.volume_db=lerpf(-48,-29,smoothstep(.8,4.0,age))
	_motor.pitch_scale=lerpf(.76,1.08,smoothstep(1.0,6.2,age))+.018*sin(age*3.1)
	var strength:=smoothstep(0,1.5,age)*(1.0-smoothstep(5.4,6.2,age))
	if bool(GameBoot.settings.get("reduce_camera_roll",false)):strength*=.3
	director.world.mirror_renderer.set_mirror_crossing(director.mirror.mirror_surface(),Vector2(strength,age))
	if age<4:
		var center:=_start.lerp(_opening+_normal*.16,smoothstep(1.5,4.0,age))
		carrier.pose_story_reflection(director,_pose(center,_basis),true)
		return
	if not world_stage:
		if not carrier.begin_story_world(director):cancel();return
		world_stage=true
	var fraction:=smoothstep(4.0,6.2,age)
	var center:=_opening+_normal*lerpf(-.16,.32,fraction)
	var lean:=sin(fraction*PI*2)*.10*(1.0-fraction)
	carrier.motion.global_transform=_pose(center,_basis*Basis(Vector3.FORWARD,lean))
	carrier.rig.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*carrier.PRESENTATION_SCALE),Vector3.ZERO)
	_motor.global_position=center
	if age>=6.2:
		director.world.mirror_renderer.set_mirror_crossing(director.mirror.mirror_surface(),Vector2.ZERO)
		handing_off=true
		carrier.screen_frame.world_handoff_finished.connect(_arrived,CONNECT_ONE_SHOT)
		carrier.screen_frame.begin_world_handoff(carrier.rig.global_transform)
		carrier.release_story_absence(director)

func _arrived() -> void:
	if not active:return
	carrier.end_story_world(director)
	_motor.stop()
	active=false;set_process(false)
	player.release_text_input(self)
	finished.emit(true)

func cancel() -> void:
	if not active:return
	active=false;set_process(false)
	if is_instance_valid(_motor):_motor.stop()
	carrier.screen_frame.cancel_world_handoff()
	if carrier.screen_frame.world_handoff_finished.is_connected(_arrived):carrier.screen_frame.world_handoff_finished.disconnect(_arrived)
	carrier.end_story_world(director)
	carrier.end_story_reflection(director)
	carrier.motion.global_transform=_home_motion;carrier.rig.transform=_home_rig
	player.release_text_input(self)
	director.world.mirror_renderer.set_mirror_crossing(director.mirror.mirror_surface(),Vector2.ZERO)
	if is_same(_document,RealityState.data) and director.state.phase=="companion_crossing":
		carrier.acquire_story_absence(director)
	finished.emit(false)

func _exit_tree() -> void:cancel()
