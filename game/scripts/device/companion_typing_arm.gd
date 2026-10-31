extends Node3D
## Physical presentation only. The caller owns command meaning and printer text.
signal key_pressed(character:String)
signal finished(completed:bool)
const DEPLOY_END:=117.0/24.0
const RETURN_START:=319.0/24.0
const PREOPEN_END:=15.0/24.0
const STOWED:=415.0/24.0
var case_time:=0.0
var rig:Node3D
var player:PlayerController
var permitted:Callable
var native:Node3D
var animator:AnimationPlayer
var clip:StringName
var assembly:Node3D
var shoulder:Node3D
var elbow:Node3D
var wrist:Node3D
var finger:Node3D
var tip:Node3D
var targets:Dictionary={}
var baked_scale:=0.42
var phase:="idle"
var elapsed:=0.0
var index:=0
var program:Array[String]=[]
var _from:=Vector3.ZERO
var _to:=Vector3.ZERO
var _stroke:=0.0
var _emitted:=false
var _complete:=false
var _restore_keyboard:=false
var _phase_time:=0.0
var _limits:Array=[]

func configure(mechanism:Node3D,holder:PlayerController,permission:Callable) -> bool:
	rig=mechanism;player=holder;permitted=permission
	native=load("res://assets/props/companion_typing_arm.glb").instantiate() as Node3D
	add_child(native)
	assembly=native.find_child("TypingArmAssembly",true,false)
	if assembly==null:return false
	var assembly_extras:Dictionary=assembly.get_meta("extras",{})
	if not assembly_extras.has("baked_reference_scale"):return false
	baked_scale=float(assembly_extras.baked_reference_scale)
	if not is_equal_approx(baked_scale,.42):return false
	# This child lives in the original native rig frame. Undo only the asset's
	# baked reference conversion; the parent's presentation scale then applies
	# once to both assemblies. At phone scale the imported arm's net scale is1.
	scale=Vector3.ONE/baked_scale
	var finishes:={"TypingArm_steel":"fire_hardware_steel","TypingArm_brass":"brass_dull","TypingArm_pad":"leather_worn","TypingArm_flex":"fabric_warm"}
	var materials:Dictionary={}
	for key:String in finishes:
		var material:=MatLib.get_mat(finishes[key]).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;materials[key]=material
	for draw:MeshInstance3D in native.find_children("*","MeshInstance3D",true,false):
		draw.layers=1 << (ServiceSetProp.DEVICE_LAYER-1)
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		for surface in draw.mesh.get_surface_count():
			var source:=draw.mesh.surface_get_material(surface)
			if source==null or not materials.has(source.resource_name):return false
			draw.set_surface_override_material(surface,materials[source.resource_name])
	# Compact native exports retain marker identity in raw glTF names but omit
	# the older extras. Match their local positions once; punctuation names may
	# be sanitized/collide in Godot, so guessing the imported name is unsafe.
	var bytes:=FileAccess.get_file_as_bytes("res://assets/props/companion_typing_arm.glb")
	var length:=bytes.decode_u32(12)
	var document:Dictionary=JSON.parse_string(bytes.slice(20,20+length).get_string_from_utf8())
	var markers:=native.find_children("KeyTarget*","Node3D",true,false)
	for node:Dictionary in document.nodes:
		var raw:=str(node.get("name",""))
		if not raw.begins_with("KeyTarget_"):continue
		var key:=raw.trim_prefix("KeyTarget_")
		var xyz:Array=node.get("translation",[0,0,0])
		var point:=Vector3(xyz[0],xyz[1],xyz[2])
		var matches:Array=[]
		for marker:Node3D in markers:
			if marker.position.distance_to(point)<.000001:matches.append(marker)
		if matches.size()!=1:return false
		targets[key]=matches[0]
	for name:String in rig._key_names:
		if not targets.has(name):return false
	if targets.size()!=43:return false
	shoulder=native.find_child("Arm_ShoulderYaw",true,false)
	elbow=native.find_child("Arm_ElbowYaw",true,false)
	wrist=native.find_child("Arm_Wrist",true,false)
	finger=native.find_child("Arm_TypingFinger",true,false)
	tip=native.find_child("TypingFingerContact",true,false)
	var animations:=native.find_children("*","AnimationPlayer",true,false)
	if animations.size()==1:animator=animations[0]
	if shoulder==null or elbow==null or wrist==null or finger==null or tip==null or animator==null:return false
	for joint:Node3D in [shoulder,elbow,wrist]:
		var extras:Dictionary=joint.get_meta("extras",{})
		var spec:Variant=JSON.parse_string(str(extras.get("joint_limits_json","")))
		if spec is not Dictionary or spec.get("degrees") is not Array or spec.degrees.size()!=2:return false
		_limits.append(Vector2(deg_to_rad(float(spec.degrees[0])),deg_to_rad(float(spec.degrees[1]))))
	for name:StringName in animator.get_animation_list():
		if name!=&"RESET":clip=name;break
	if clip.is_empty():return false
	animator.play(clip);animator.pause();animator.seek(0,true)
	set_process(false)
	return true

func active() -> bool:return phase!="idle"

func begin(keys:Array[String]) -> bool:
	if active() or keys.is_empty() or keys.size()>256 or not permitted.is_valid() or not permitted.call():return false
	for key:String in keys:
		if not targets.has(key):return false
	if player!=null and not player.acquire_text_input(self):return false
	program.assign(keys);index=0;_complete=true;_restore_keyboard=rig.keyboard_requested
	phase="prepare";elapsed=0
	if not keyboard_case_clear():rig.automated_keyboard(self,false)
	set_process(true)
	return true

func cancel(restore_requested:=true) -> void:
	if not active():return
	_complete=false
	if not restore_requested:_restore_keyboard=false
	if player!=null:player.release_text_input(self)
	if phase in ["return","return_align","reverse","withdraw","case_close"]:return
	if phase in ["prepare","preopen","waiting"]:
		rig.automated_keyboard(self,false);phase="withdraw";elapsed=0;return
	if phase=="deploy":phase="reverse";return
	rig.automated_key(self,"",0);finger.position.y=0
	_move_to("ENTER","return_align")

func _process(delta:float) -> void:
	if get_tree().paused:return
	advance(delta)

func advance(delta:float) -> void:
	if not active() or get_tree().paused or not is_finite(delta) or delta<0:return
	if phase not in ["return","return_align","reverse","withdraw","case_close"] and (not permitted.call() or (player!=null and player.text_input_owner!=self)):
		cancel()
	if not active():return
	elapsed+=delta
	match phase:
		"prepare":
			if rig.keyboard_open<=.001 or keyboard_case_clear():phase="preopen";elapsed=case_time
		"preopen":
			case_time=minf(PREOPEN_END,elapsed);_seek(case_time)
			if case_time>=PREOPEN_END:
				rig.automated_keyboard(self,true);phase="waiting";elapsed=0
		"waiting":
			if rig.typing_ready():phase="deploy";elapsed=PREOPEN_END
			elif elapsed>8.0:cancel()
		"deploy":
			_seek(minf(elapsed,DEPLOY_END))
			if elapsed>=DEPLOY_END:_move_to(program[index],"move")
		"move","return_align":
			var weight:=smoothstep(0,1,minf(1,elapsed/_phase_time))
			_set_angles(_from.lerp(_to,weight))
			if elapsed>=_phase_time:
				if phase=="return_align":phase="return";elapsed=0
				else:phase="press";elapsed=0;_emitted=false
		"press":
			_stroke=sin(minf(1,elapsed/.12)*PI)
			# A short peak hold guarantees a contact event at varied frame rates.
			if elapsed>=.05 and elapsed<=.08:_stroke=1
			if elapsed>.08 and not _emitted:_stroke=1
			var key:String=program[index]
			var point:Vector3=native.to_local(targets[key].global_position)
			var home_y:float=native.to_local(wrist.global_position).y+tip.position.y
			var gap:=home_y-point.y
			var travel:float=rig.KEY_TRAVEL*baked_scale
			finger.position.y=-(gap+travel)*_stroke
			rig.automated_key(self,key,clampf((-finger.position.y-gap)/travel,0,1))
			if _stroke>=.999 and not _emitted:
				_emitted=true;rig.pulse_key(key);key_pressed.emit(key)
			if elapsed>=.12 and _emitted:
				finger.position.y=0;rig.automated_key(self,"",0);index+=1
				if index>=program.size():_move_to("ENTER","return_align")
				else:_move_to(program[index],"move")
		"return":
			_seek(minf(STOWED,RETURN_START+elapsed))
			if RETURN_START+elapsed>=STOWED:
				rig.automated_keyboard(self,false);phase="withdraw";elapsed=0
		"withdraw":
			if rig.keyboard_open<=.001:phase="case_close";elapsed=0
		"case_close":
			# A cancelled pre-open reverses only its actual garage travel.
			if case_time<PREOPEN_END:
				case_time=maxf(0,case_time-delta);_seek(case_time)
				if case_time<=0:_finish()
			else:
				var end:float=animator.get_animation(clip).length
				_seek(minf(end,STOWED+elapsed))
				if STOWED+elapsed>=end:case_time=0;_finish()
		"reverse":
			elapsed=maxf(PREOPEN_END,elapsed-delta*2)
			_seek(elapsed)
			if elapsed<=PREOPEN_END:
				rig.automated_keyboard(self,false);phase="withdraw";elapsed=0

func _seek(seconds:float) -> void:
	animator.seek(seconds,true)
	if rig.temporal_register!=null:rig.temporal_register.follow_door()

func keyboard_case_clear() -> bool:
	return case_time>=PREOPEN_END

## The existing mechanism callback owns idle garage travel too: ordinary typing
## must not deploy the keyboard through the closed front. No idle arm callback.
func advance_idle_case(delta:float) -> void:
	if active():return
	var target:=PREOPEN_END if rig.keyboard_requested else 0.0
	if target==0 and rig.keyboard_open>.001:return
	var next:=move_toward(case_time,target,maxf(0,delta))
	if next!=case_time:case_time=next;_seek(case_time)

func _move_to(key:String,next:String) -> void:
	var point:Vector3=native.to_local(targets[key].global_position)
	var base:Vector3=native.to_local(shoulder.global_position)
	var x:=point.x-base.x-tip.position.x
	var y:=-(point.z-base.z-tip.position.z)
	var first:float=elbow.position.x;var second:float=wrist.position.x
	var cosine:float=(x*x+y*y-first*first-second*second)/(2*first*second)
	if absf(cosine)>=1:
		_complete=false;_restore_keyboard=true;_finish()
		push_error("Typing arm refuses unreachable key: "+key)
		return
	var b:float=-acos(cosine)
	var a:float=atan2(y,x)-atan2(second*sin(b),first+second*cos(b))
	while a<deg_to_rad(175):a+=TAU
	_from=Vector3(wrapf(shoulder.rotation.y,deg_to_rad(175),deg_to_rad(175)+TAU),elbow.rotation.y,wrist.rotation.y)
	if _from.z>0:_from.z-=TAU
	_to=Vector3(a,b,-a-b)
	for axis in 3:
		if _to[axis]<_limits[axis].x-.00001 or _to[axis]>_limits[axis].y+.00001:
			_complete=false;_restore_keyboard=true;_finish()
			push_error("Typing arm refuses joint limit for key: "+key)
			return
	_phase_time=maxf(.06,_from.distance_to(_to)/12.0)
	phase=next;elapsed=0

func _set_angles(angles:Vector3) -> void:
	shoulder.rotation=Vector3(0,angles.x,0)
	elbow.rotation=Vector3(0,angles.y,0)
	wrist.rotation=Vector3(0,angles.z,0)

func _finish() -> void:
	rig.automated_key(self,"",0)
	if player!=null:player.release_text_input(self)
	phase="idle";set_process(false)
	rig.request_keyboard(_restore_keyboard and rig.device.radio_powered and permitted.is_valid() and permitted.call())
	finished.emit(_complete)

func _exit_tree() -> void:
	if is_instance_valid(player):player.release_text_input(self)
