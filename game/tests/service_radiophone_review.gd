extends Node3D
## INERT actual production printer/state diagnostic, no campaign acceptance.
var failures: Array[String]=[]
var checks := 0
var directory := ""
var device: ServiceSetProp
var observations: Dictionary={}
var stderr_stages: Array=[]

func observe_errors(stage: String) -> void:
	var path:=directory+".log.stderr"
	if FileAccess.file_exists(path):stderr_stages.append({"stage":stage,"stderr":FileAccess.get_file_as_string(path)})

func check(ok: bool,label: String) -> void:
	checks+=1;print("RADIOPHONE REVIEW: ",label," = ",ok)
	if not ok:failures.append(label)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"captured "+label)
	observe_errors(label)

func _ready() -> void:_run.call_deferred()

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	Engine.max_fps=120
	var environment:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("242426")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.6
	environment.environment=settings;add_child(environment)
	var light:=DirectionalLight3D.new();light.light_cull_mask=2;light.rotation_degrees=Vector3(-25,-20,0);light.light_energy=1.4;add_child(light)
	var camera:=Camera3D.new();camera.cull_mask=2;camera.near=.005;camera.fov=32.;add_child(camera)
	camera.look_at_from_position(Vector3(.10,.06,.43),Vector3(0,.01,.04));camera.make_current()
	device=ServiceSetProp.new();add_child(device)
	var printer: Node3D=device.teletype
	check(printer._hot_writer!=null,"production printer binds heated native head")
	check(device.find_children("*","MeshInstance3D",true,false).size()==29,"single native instrument replaces duplicate stock")
	var body: String="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123\n456789.,:!?+-*/=()\n"+"A complete report survives.\n".repeat(18)
	check(device.print_telegram_card({"title":"FIELD COPY / 41","body":body}),"complete multi-page report accepted")
	var frame_home: Vector3=printer._hammer_home
	var peak:=0.;var banks: Dictionary={}
	for frame in 180:
		await get_tree().process_frame
		peak=maxf(peak,frame_home.z-printer.hammer.position.z)
		banks[printer._hot_writer._bank]=true
	check(peak>.0014 and peak<=.00156,"actual print loop reaches bounded impression stroke")
	check(banks.size()==3,"actual character flow selects all three banks")
	check(printer.pages.size()>1 and "survives" in " ".join(printer.pages),"report retains all pages and copy")
	await shot("01_printing")
	var deadline:=Time.get_ticks_msec()+12000
	while printer.printing and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	check(not printer.printing and printer.ink.text==printer.pages[0],"first page prints complete copy")
	await get_tree().create_timer(.4).timeout
	check(not printer._hot_writer.is_processing(),"writer sleeps after actual final character")
	check(printer.hammer.position.is_equal_approx(frame_home),"actual print leaves hammer at rest")
	var bounds: AABB=printer.ink.get_aabb()
	var frame: Transform3D=printer.global_transform.affine_inverse()*printer.ink.global_transform
	var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
	for corner in 8:
		var p: Vector3=frame*bounds.get_endpoint(corner);low=low.min(p);high=high.max(p)
	check(low.x>=-.0701 and high.x<=.0701 and low.y>=-.0291 and high.y<=.0851,"actual shaped full-page text fits physical stock")
	observations={"peak_impression_m":peak,"banks":banks.keys(),"text_low":str(low),"text_high":str(high),"pages":printer.pages.size()}
	await shot("02_full_page")
	var count:=device.printed_count
	device.set_radio_powered(false,false)
	check(not device.print_telegram_card("POWER OFF"),"radio authority suppresses new output")
	await get_tree().process_frame;await get_tree().process_frame
	check(not printer._hot_writer._puff.emitting and not printer._hot_writer._puff.visible and not printer._hot_writer._sound.playing,"power off stops visible smoke and singe")
	printer.browse_report(-1);printer.turn_page(1)
	check(not printer.printing and printer.ink.text==printer.pages[1],"unpowered history page is retained and does not reprint")
	check(device.printed_count==count,"history does not change receipt authority")
	device.set_radio_powered(true,false);device.set_lamp_enabled(false,false)
	await get_tree().create_timer(.35).timeout
	check(printer.radio_switch.rotation.z<0 and printer.lamp_switch.rotation.z>0,"independent physical circuit indicators")
	check(printer._aerial.scale.y>.99,"radio aerial extends with its circuit")
	printer.toggle_service_cover();await get_tree().create_timer(.4).timeout
	await shot("03_service")
	camera.look_at_from_position(Vector3(-.16,.08,-.42),Vector3(0,.01,-.025))
	await shot("04_radio_back")
	printer._hot_writer.stop()
	device.queue_free()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	observe_errors("freed_device")
	check(stderr_stages.all(func(row):return str(row.stderr).is_empty()),"normal construction printing and unmount have no renderer errors")
	FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Production printer in an isolated render fixture; direct service-cover input, composed save and whole-world performance are not qualified","checks":checks,"failures":failures,"observations":observations,"stderr_stages":stderr_stages},"\t"))
	print("RADIOPHONE REVIEW: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if failures.is_empty() else 1)
