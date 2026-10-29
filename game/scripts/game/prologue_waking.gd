extends Node
## Temporary historical bedroom shot. The director retains narrative/save facts;
## this owner leases camera/input and acknowledges actual DREAM/wake completion.
signal finished(completed:bool)
const DURATION:=16.0
const AWAKENING:=11.0
var director:Node
var player:PlayerController
var camera:Camera3D
var cover:MeshInstance3D
var active:=false
var age:=0.0
var failure:=""
var _document:Dictionary
var _bed:Node3D
var _model:Node3D
var _old_camera:Camera3D
var _start:Transform3D
var _bed_eye:Transform3D
var _standing:Transform3D
var _anchor:Vector3
var _hidden:Array[Node3D]=[]
var _hud:CanvasLayer
var _hud_visible:=false
var _veil:ColorRect
var _light:SpotLight3D
var _breath:AudioStreamPlayer3D
var _storm:AudioStreamPlayer
var _thunder:AudioStreamPlayer
var _rustle:AudioStreamPlayer3D
var _quiet:=false
var _awake:=false

func _init() -> void:set_process(false)

func start(owner:Node,cover_scene:PackedScene) -> bool:
	if active or cover_scene==null or owner.state.phase not in ["dream","awakening"] or get_tree().paused:return false
	director=owner;player=owner.player
	_bed=owner.world.adapter.resolve("4B_wake_bed") as Node3D
	var anchor:Dictionary=owner.world.core_loop.resolve_return_anchor()
	if _bed==null or anchor.is_empty():return _refuse("missing actual bed/standing anchor")
	_model=cover_scene.instantiate()
	var meshes:=_model.find_children("*","MeshInstance3D",true,false)
	if meshes.size()!=1:
		_model.free();_model=null;return _refuse("expected one continuous opaque cover")
	cover=meshes[0]
	if cover.find_blend_shape_by_name("Breath")<0 or cover.find_blend_shape_by_name("Recoil")<0:
		_model.free();_model=null;return _refuse("missing authored cloth morphs")
	if not player.acquire_text_input(self):
		_model.free();_model=null;return _refuse("input already owned")
	_document=RealityState.data;_anchor=anchor.position
	_old_camera=get_viewport().get_camera_3d()
	# Native stock remains with its actual owner; hide only the thrown cover,
	# never its frame/mattress/pillows or collision protection.
	for node:Node in _bed.find_children("*","MeshInstance3D",true,false):
		if str(node.name).ends_with("_Blanket") and node.visible:
			_hidden.append(node);node.hide()
	if _hidden.size()!=1:
		_release();return _refuse("expected exactly one existing thrown blanket")
	add_child(_model);_model.global_transform=_bed.global_transform
	var material:=MatLib.get_mat("linen").duplicate() as StandardMaterial3D
	material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/.6
	cover.material_override=material
	camera=Camera3D.new();camera.name="OpeningBedroomCamera";add_child(camera)
	camera.fov=_old_camera.fov;camera.near=_old_camera.near;camera.far=_old_camera.far
	camera.environment=_old_camera.environment;camera.cull_mask=_old_camera.cull_mask
	camera.keep_aspect=_old_camera.keep_aspect
	var center:=_bed.to_global(Vector3(0,.80,0))
	var start_at:=_bed.to_global(Vector3(1.10,1.62,-.65))
	_start=Transform3D(Basis.looking_at(center-start_at,Vector3.UP),start_at)
	var eye_at:=_bed.to_global(Vector3(-.05,.94,.82))
	var eye_toward:=_bed.to_global(Vector3(0,.96,-.7))
	_bed_eye=Transform3D(Basis.looking_at(eye_toward-eye_at,Vector3.UP),eye_at)
	# Build the final view from the existing standing anchor and eye height.
	# Do not shrink the capsule, move its colliders onto the bed, or infer a
	# mattress datum from the nominal semantic wake marker.
	var standing_at:=_anchor+Vector3.UP*PlayerController.STANDING_EYE
	var target:=director._bed_anchor.origin
	_standing=Transform3D(Basis.looking_at(target-standing_at,Vector3.UP),standing_at)
	_hud=player._interaction_hud
	if is_instance_valid(_hud):_hud_visible=_hud.visible;_hud.hide()
	var layer:=CanvasLayer.new();layer.layer=80;add_child(layer)
	_veil=ColorRect.new();layer.add_child(_veil);_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_quiet=bool(GameBoot.settings.get("reduce_flashing",false))
	_light=SpotLight3D.new();_light.name="OpeningWindowBounce";add_child(_light)
	_light.spot_range=5;_light.spot_angle=65;_light.shadow_enabled=true
	_light.light_cull_mask=1;_light.shadow_caster_mask=1
	_light.light_color=Color(.65,.73,.91);_light.light_energy=0
	_light.global_position=_bed.to_global(Vector3(.9,2.0,.1));_light.look_at(center)
	_storm=AudioStreamPlayer.new();_storm.stream=preload("res://assets/audio/freesound/processed/beds/ambient_roof_storm_city.ogg")
	_storm.volume_db=-28;add_child(_storm);_storm.play()
	_thunder=AudioStreamPlayer.new();_thunder.stream=preload("res://scripts/building/deterministic_lightning_manager.gd")._thunder(19281110)
	_thunder.volume_db=-21;add_child(_thunder)
	_breath=AudioStreamPlayer3D.new();_breath.stream=preload("res://assets/audio/freesound/processed/mechanical/distant_breath.ogg")
	_breath.volume_db=-35;_breath.max_distance=4;add_child(_breath);_breath.global_position=center
	_breath.play()
	_rustle=AudioStreamPlayer3D.new();_rustle.stream=preload("res://scripts/game/prologue_tardi_stinger.gd")._rustle()
	_rustle.volume_db=-26;_rustle.max_distance=4;add_child(_rustle);_rustle.global_position=center
	active=true;_awake=owner.state.phase=="awakening"
	age=AWAKENING if _awake else 0
	seek(age);camera.make_current();set_process(true)
	return true

func seek(seconds:float) -> void:
	if not active or not is_finite(seconds):return
	var previous:=age;age=clampf(seconds,0,DURATION)
	cover.set_blend_shape_value(cover.find_blend_shape_by_name("Breath"),.5+.5*sin(age*1.4))
	var recoil:=exp(-pow((age-9.9)/.24,2))+.35*exp(-pow((age-6.4)/.35,2))
	cover.set_blend_shape_value(cover.find_blend_shape_by_name("Recoil"),clampf(recoil,0,1))
	var wake:=smoothstep(AWAKENING,13.0,age)
	var stand:=smoothstep(13.0,15.5,age)
	camera.global_transform=_start.interpolate_with(_bed_eye,wake).interpolate_with(_standing,stand)
	# Darkness conceals the cut from outside to first person; no exposed body
	# or screen blur. Reduced-flash uses a slow window glow, never a flash.
	var blink:=smoothstep(10.4,10.8,age)*(1-smoothstep(11.2,12.0,age))
	_veil.color=Color(0,0,0,maxf(1-smoothstep(1.8,4.0,age),blink))
	var flash:=exp(-pow((age-5.7)/.13,2))*.35+exp(-pow((age-9.8)/.20,2))*.7
	_light.light_energy=.14+.18*sin(PI*smoothstep(3,11,age)) if _quiet else .10+flash
	_storm.volume_db=lerpf(-28,-24,smoothstep(7,9.8,age))
	if age>=6.2 and previous<6.2:_rustle.play()
	if age>=9.8 and previous<9.8:_rustle.play();_thunder.play()
	if age>=AWAKENING and not _awake:
		_awake=true
		if not director._advance("awakening"):cancel();return
	if age>=DURATION:_complete()

func _process(delta:float) -> void:
	if not active:return
	if not is_same(_document,RealityState.data) or player.text_input_owner!=self or RealityState.save_write_blocked or director.state.phase not in ["dream","awakening"]:
		cancel();return
	seek(age+maxf(delta,0))

func _complete() -> void:
	# Move only to the already authored, physically qualified standing anchor.
	player.global_position=_anchor;player.velocity=Vector3.ZERO
	player.face_world_point(_standing.origin-_standing.basis.z*3)
	_release()
	if director._advance("bedroom_exploration"):finished.emit(true)
	else:finished.emit(false)

func cancel() -> void:
	if not active:return
	_release();finished.emit(false)

func _release() -> void:
	active=false;set_process(false)
	if is_instance_valid(camera) and camera.is_current() and is_instance_valid(_old_camera):_old_camera.make_current()
	if is_instance_valid(player):player.release_text_input(self)
	for node:Node3D in _hidden:
		if is_instance_valid(node):node.show()
	_hidden.clear()
	if is_instance_valid(_hud):_hud.visible=_hud_visible
	for node:Node in [_model,camera,_light,_breath,_storm,_thunder,_rustle]:
		if is_instance_valid(node):node.queue_free()
	if is_instance_valid(_veil):_veil.get_parent().queue_free()

func _exit_tree() -> void:
	if active:_release()

func _refuse(reason:String) -> bool:
	failure=reason;return false
