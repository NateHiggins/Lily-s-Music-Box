extends Node3D
## Candidate presentation only. The printer owns text/character timing.
## No WorkOrders, inventory, paper history or case state is changed here.
const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:!?+-*/=()"
const TYPE_SHADER := preload("res://scripts/device/writer_type_decal.gdshader")
const PLATE := preload("res://assets/device/writer_type/reversed_type_emboss.png")
var selector: Node3D
var _face: ShaderMaterial
var phosphor_stock := false
var _excitation := 0.0
var _blur := 0.0
var _stroke_age := 1.0
var _sync_frame := -1
var _stamp_enabled := false
var _pending_contact := false
var _cooldown := 0.0
var _sound_left := 0.0
var _target_angle := 0.0
var _puff: GPUParticles3D
var _sound: AudioStreamPlayer
var _rows: Array[MeshInstance3D]=[]
var _bank := 0
var _hammer: Node3D
var _hammer_home := Vector3.ZERO
var _flexure: MeshInstance3D

func bind_model(model: Node3D) -> bool:
	selector=model.find_child("TypeSelector",true,false)
	var decal:=model.find_child("TypeSelector__TypeEmboss",true,false) as MeshInstance3D
	if selector==null or decal==null: return false
	_hammer=model.find_child("Type_hammer",true,false);_hammer_home=_hammer.position
	_flexure=model.find_child("Carriage__Steel",true,false) as MeshInstance3D
	for part in selector.get_children():
		if part is MeshInstance3D and part.find_blend_shape_by_name("LowerSeat")>=0:_rows.append(part)
	_face=ShaderMaterial.new();_face.shader=TYPE_SHADER
	_face.set_shader_parameter("type_plate",PLATE)
	_face.set_shader_parameter("radiance_color",Color(.24,1.0,.40) if phosphor_stock else Color(.85,.12,.012))
	_face.set_shader_parameter("idle_excitation",.08 if phosphor_stock else 0.)
	var steel:=MatLib.get_mat("fire_hardware_steel")
	_face.set_shader_parameter("steel_albedo",steel.albedo_texture)
	_face.set_shader_parameter("steel_roughness",steel.roughness_texture)
	_face.set_shader_parameter("steel_normal",steel.normal_texture)
	_face.set_shader_parameter("metres_per_tile",1.0/steel.uv1_scale.x)
	decal.set_surface_override_material(0,_face)
	_sound=AudioStreamPlayer.new();add_child(_sound);_sound.bus="UI"
	_sound.stream=PropAudio.get_stream("cellular_relay");_sound.volume_db=-34.;_sound.pitch_scale=1.8
	# Companion type exposes phosphorescent stock; no thermal plume is created.
	if not phosphor_stock: _build_legacy_smoke()
	set_process(false)
	return true

func _build_legacy_smoke() -> void:
	_puff=GPUParticles3D.new();add_child(_puff)
	_puff.amount=3;_puff.lifetime=.20;_puff.one_shot=true;_puff.explosiveness=1.;_puff.emitting=false
	_puff.layers=2
	_puff.local_coords=true;_puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=12.
	process.gravity=Vector3(0,.025,0);process.initial_velocity_min=.014;process.initial_velocity_max=.025
	process.scale_min=.55;process.scale_max=1.;process.color=Color(.36,.32,.28,.14)
	var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,.55));ramp.set_color(1,Color(1,1,1,0))
	var texture:=GradientTexture1D.new();texture.gradient=ramp;process.color_ramp=texture
	_puff.process_material=process
	var quad:=QuadMesh.new();quad.size=Vector2(.006,.006)
	var smoke:=ShaderMaterial.new();smoke.shader=preload("res://scripts/device/writer_smoke.gdshader")
	quad.material=smoke;_puff.draw_pass_1=quad

func strike(character: String) -> void:
	_stamp_enabled=not character.strip_edges().is_empty()
	if _face==null or not _stamp_enabled: return
	var index:=CHARS.find(character.to_upper())
	if index<0:index=CHARS.find("?")
	_target_angle=float(index%16)*TAU/16.
	_bank=floori(float(index)/16.)-1
	selector.position.y=-float(_bank)*.0045
	_face.set_shader_parameter("selected_cell",float(index))
	_excitation=.85;_blur=1.;_stroke_age=0.
	_pending_contact=true
	set_process(true)

func sync_phase(age: float) -> void:
	_stroke_age=age;_sync_frame=Engine.get_process_frames()

func stop() -> void:
	_blur=0.;_excitation=0.;_stroke_age=1.;_cooldown=0.;_sound_left=0.;set_process(false)
	_stamp_enabled=false;_pending_contact=false
	if _face:
		_face.set_shader_parameter("excitation",0.);_face.set_shader_parameter("spin_blur",0.)
	if _sound:_sound.stop()
	if _puff:_puff.emitting=false;_puff.visible=false
	if _hammer:_hammer.position=_hammer_home
	if _flexure:_flexure.set_blend_shape_value(_flexure.find_blend_shape_by_name("Impression"),0.)
	for row in _rows:
		row.set_blend_shape_value(row.find_blend_shape_by_name("LowerSeat"),0.)
		row.set_blend_shape_value(row.find_blend_shape_by_name("UpperSeat"),0.)

func _process(delta: float) -> void:
	_excitation=move_toward(_excitation,0.,delta*5.5);_cooldown=maxf(0.,_cooldown-delta)
	# Parent printer supplies residual character time after catch-up. Do not
	# advance it by an entire frame a second time in this child's callback.
	if _sync_frame!=Engine.get_process_frames():_stroke_age+=delta
	_blur=maxf(0.,1.-_stroke_age/.006)
	# Two visual turns collapse onto the selected seat. The local blur stands
	# in for sub-frame motion at print rates above the display's frame rate.
	selector.rotation.y=_target_angle+_blur*TAU*2.
	# Complete selection and impression inside the printer's 20.83ms character
	# interval. Afterglow may continue, but cannot delay the next impression.
	var seating: float=smoothstep(.006,.009,_stroke_age)*(1.-smoothstep(.012,.020,_stroke_age))
	if not _stamp_enabled:seating=0.
	if _pending_contact and seating>.5:
		_pending_contact=false
		if _cooldown<=0.:
			if _puff:
				_puff.position=to_local(_hammer.to_global(Vector3(0,0,-.014)))
				_puff.visible=true
				_puff.restart();_puff.emitting=true
			_sound.play();_sound_left=.045;_cooldown=.10
	_hammer.position=_hammer_home-Vector3(0,0,.00155*seating)
	if _flexure:_flexure.set_blend_shape_value(_flexure.find_blend_shape_by_name("Impression"),seating)
	for row in _rows:
		row.set_blend_shape_value(row.find_blend_shape_by_name("LowerSeat"),seating if _bank==-1 else 0.)
		row.set_blend_shape_value(row.find_blend_shape_by_name("UpperSeat"),seating if _bank==1 else 0.)
	_face.set_shader_parameter("excitation",_excitation);_face.set_shader_parameter("spin_blur",_blur)
	_sound_left=maxf(0.,_sound_left-delta)
	if _sound_left==0. and _sound.playing:_sound.stop()
	if _excitation<=0. and _cooldown<=0. and (_puff==null or not _puff.emitting):set_process(false)
