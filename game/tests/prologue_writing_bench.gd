extends Node3D
## Noncapturing optical/component bench. No actual-room or input acceptance.
const Writing := preload("res://scripts/game/signal_surface_writing.gd")
const Director := preload("res://scripts/game/prologue_director.gd")
var failures: Array[String]=[]
var checks := 0
var transcripts: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PROLOGUE WRITING ","PASS " if ok else "FAIL ",label)

func _ready() -> void:
	var camera := Camera3D.new();camera.position=Vector3(0,0,2.0);camera.fov=72
	add_child(camera);camera.current=true
	var environment := Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.035,.028,.022);environment.glow_enabled=true
	environment.glow_intensity=.35
	var owner := WorldEnvironment.new();owner.environment=environment;add_child(owner)
	var writing := Writing.new();add_child(writing)
	writing.transcription_changed.connect(func(text: String): transcripts.append(text))
	check(writing.show_message("You passed out again.",.8),"bounded message accepted")
	await get_tree().create_timer(.4).timeout
	check(writing.is_processing(),"progressive reveal active")
	await _shot("dark_reveal.png")
	await get_tree().create_timer(.8).timeout
	check(not writing.is_processing(),"completed writing sleeps")
	check(writing._words.size()==4 and writing._words.all(func(word: Dictionary): return word.label.text==word.text),"all final words retain exact text")
	check(transcripts.back()=="You passed out again.","accessible transcription carries full text")
	check(writing._words.all(func(word: Dictionary): return not word.label.no_depth_test and word.label.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"ordinary depth and no extra shadow work")
	await _shot("dark_complete.png")
	environment.background_color=Color(.78,.76,.69)
	check(writing.show_message("Too cold.\nTry the hot water.",.6),"multiline replacement accepted")
	await get_tree().create_timer(.9).timeout
	await _shot("light_complete.png")
	check(not writing.show_message("x".repeat(161)),"unbounded message refused")
	check(writing.current_text=="Too cold.\nTry the hot water.","refusal preserves existing writing")
	check(writing.show_message("There. That's better.",0,.1),"timed disappearance accepted")
	await get_tree().create_timer(.9).timeout
	check(writing.current_text.is_empty() and writing._words.is_empty() and not writing.is_processing(),"expired writing removes all live lettering and processing")
	check(transcripts.back().is_empty(),"expiration clears transcription")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"bench never captures pointer")
	var out := OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		FileAccess.open(out.path_join("writing_bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Noncapturing lettering component and contrast bench; not physical wall placement, actual gameplay or artistic acceptance."},"\t"))
	writing.queue_free();owner.queue_free();camera.queue_free()
	await get_tree().process_frame
	print("PROLOGUE WRITING BENCH: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _shot(name_: String) -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty(): return
	DirAccess.make_dir_recursive_absolute(out)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name_))
