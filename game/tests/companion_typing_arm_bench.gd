extends Node3D
## Imported contact/appearance diagnostic, not prologue or occupied-world proof.
var failures:Array[String]=[]
var contacts:Array=[]
var allowed:=true
var rig:Node3D
var arm:Node3D

func check(ok:bool,label:String) -> void:
	print("ARM CHECK ",label," = ",ok)
	if not ok:failures.append(label)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	get_tree().create_timer(90).timeout.connect(func():
		push_error("Typing arm diagnostic exceeded ninety seconds")
		get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	rig=preload("res://scripts/device/companion_mechanism.gd").new();add_child(rig)
	if not rig.build():get_tree().quit(1);return
	rig.scale=Vector3.ONE*.42;rig.set_process(false)
	arm=preload("res://scripts/device/companion_typing_arm.gd").new()
	rig.typing_arm=arm;rig.add_child(arm)
	if not arm.configure(rig,null,func():return allowed):
		check(false,"phone arm binds its43 key markers");get_tree().quit(1);return
	check(arm.native.global_basis.get_scale().distance_to(Vector3.ONE)<.00001,"baked phone arm receives no second0.42 scale")
	var audit:=preload("res://tests/clawfoot_bath_hand_bench.gd").new()
	for draw:MeshInstance3D in arm.native.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():audit.check_surface(draw,surface,draw.get_active_material(surface))
	check(audit.failures.is_empty(),"all loaded arm surfaces retain metric UVs, tangents and PBR mips")
	audit.free()
	var environment:=WorldEnvironment.new();var state:=Environment.new()
	state.background_mode=Environment.BG_COLOR;state.background_color=Color(.12,.14,.17)
	state.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;state.ambient_light_energy=.7
	environment.environment=state;add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=.8;add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.23
	add_child(camera);camera.position=Vector3(.14,.08,.27);camera.look_at(Vector3(.01,-.02,.02));camera.make_current()
	await shot("stowed")
	arm.key_pressed.connect(func(key:String):
		var point:Vector3=arm.tip.global_position
		var target:Vector3=arm.targets[key].global_position-Vector3.UP*rig.KEY_TRAVEL*arm.baked_scale
		var error:float=point.distance_to(target)
		contacts.append({"key":key,"error_m":error})
		check(error<.00002,"physical fingertip meets depressed "+key+" error="+str(error)))
	var keys:Array[String]=[];keys.assign(rig._key_names)
	check(arm.begin(keys),"all43 keys accepted as a bounded physical program")
	arm.set_process(false)
	for frame in 50:
		rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
	check(rig.keyboard_open==0 and arm.phase=="preopen","garage pre-opens before any keyboard travel")
	var captured:=false
	for frame in 12000:
		rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
		if not captured and contacts.size()>0:
			captured=true;await shot("first_contact")
		if not arm.active():break
	check(not arm.active() and contacts.size()==43,"full43-key cycle retracts without omitted or duplicate presses")
	check(not arm.is_processing(),"stowed arm has no idle processing")
	check(rig.keyboard_open<=.001 and arm.case_time==0,"keyboard withdraws before garage reseats")
	# Human keyboard uses the same mechanical interlock without starting typing.
	rig.request_keyboard(true)
	for frame in 50:rig._advance_mechanism(1.0/120)
	check(rig.keyboard_open==0 and not arm.active(),"ordinary typing waits for garage clearance")
	for frame in 70:rig._advance_mechanism(1.0/120)
	check(rig.typing_ready(),"ordinary keyboard opens after garage clears")
	rig.request_keyboard(false)
	for frame in 130:rig._advance_mechanism(1.0/120)
	check(rig.keyboard_open<=.001 and arm.case_time==0,"ordinary keyboard closes then garage reseats")
	await shot("retracted")
	allowed=false;check(not arm.begin(keys),"protected/power permission refusal has no cycle")
	allowed=true;check(arm.begin(keys),"next cycle can start after retraction")
	arm.set_process(false)
	for frame in 180:rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
	allowed=false
	var before:=contacts.size()
	for frame in 1800:
		rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
		if not arm.active():break
	check(not arm.active() and contacts.size()==before,"interrupted deployment retracts without invented key events")
	allowed=true;check(arm.begin(keys),"writing interruption starts from the settled stow")
	arm.set_process(false)
	for frame in 1800:
		rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
		if contacts.size()>before:break
	allowed=false;before=contacts.size()
	for frame in 1800:
		rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
		if not arm.active():break
	check(not arm.active() and contacts.size()==before,"interrupted writing withdraws without typing remaining characters")
	var out:=OS.get_environment("SHOT_DIR")
	FileAccess.open(out.path_join("arm.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","failures":failures,"contacts":contacts,"scope":"Loaded metric surfaces, phone-scale fit, all43 physical contacts, bounded program, permission refusal and interrupted deployment. No real-player focus lease, full date command, occupied-world performance or prologue acceptance."},"\t",true,true))
	rig.queue_free();await get_tree().process_frame
	print("ARM BENCH failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func shot(label:String) -> void:
	for frame in 3:await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label+".png"))==OK,"capture "+label)
