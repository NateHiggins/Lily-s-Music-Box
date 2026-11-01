extends Node3D
## Small rendered lifecycle fixture, not production-world qualification or FPS.
const Preparation := preload("res://scripts/building/v2_entry_render_preparation.gd")
var checks := 0
var failures: Array[String] = []
var actor: Actor
var _paused_checked := false
var _interrupt_done := false

class Actor extends Node3D:
	var text_input_owner: Node
	var protected := false
	var mouse_released := false
	var pause_seen := 0
	func protected_input_active() -> bool:return protected
	func inspecting() -> bool:return false
	func acquire_text_input(owner: Node) -> bool:
		if protected or text_input_owner!=null or mouse_released:return false
		text_input_owner=owner;return true
	func release_text_input(owner: Node) -> void:
		if text_input_owner==owner:text_input_owner=null
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("pause_services") and not protected and text_input_owner==null:
			pause_seen+=1;get_tree().paused=true
			get_viewport().set_input_as_handled()

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error("ENTRY PREPARATION: "+label)

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _new_job() -> Node:
	var job:=Preparation.new();add_child(job);return job

func _green_center() -> bool:
	var image:=get_viewport().get_texture().get_image()
	var c:=image.get_pixel(image.get_width()/2,image.get_height()/2)
	return c.g>c.r*2.0 and c.g>c.b*2.0

func _pause_probe(job: Node) -> void:
	while job.active and job.render_calls<2:await get_tree().process_frame
	get_tree().paused=true
	var count: int=job.render_calls
	await get_tree().create_timer(.07,true).timeout
	_paused_checked=job.render_calls==count and job.active
	get_tree().paused=false

func _interrupt_probe() -> void:
	await get_tree().process_frame
	var event:=InputEventAction.new();event.action="pause_services";event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().create_timer(.04,true).timeout
	check(get_tree().paused and actor.pause_seen==1,"Pause reaches the normal input owner after our lease releases")
	get_tree().paused=false;_interrupt_done=true

func _foreign_probe(job: Node, camera: Camera3D, owner: Node) -> void:
	while job.active and job.render_calls<2:await get_tree().process_frame
	actor.text_input_owner=owner;actor.protected=true;camera.make_current()

func _remove_probe(job: Node) -> void:
	while job.active and job.render_calls<2:await get_tree().process_frame
	remove_child(job)

func _run() -> void:
	get_viewport().use_taa=false
	actor=Actor.new();add_child(actor)
	var camera:=Camera3D.new();actor.add_child(camera);camera.position=Vector3(0,0,5);camera.make_current()
	var block:=MeshInstance3D.new();block.mesh=BoxMesh.new();add_child(block)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.04,.8,.08);block.material_override=material
	await RenderingServer.frame_post_draw
	check(_green_center(),"baseline view faces the green subject")
	var pose:=camera.global_transform
	var mode:=Input.mouse_mode
	var job:=_new_job()
	var result: Dictionary=await job.run(actor,camera,Vector3(14,3,12))
	check(result.completed and result.render_calls==10 and result.steps_ms.size()==5,"complete preparation runs the measured ten unswapped draws")
	check(result.node_poses_unchanged and camera.global_transform.is_equal_approx(pose),"preparation never moves the camera Node")
	check(actor.text_input_owner==null and camera.is_current() and Input.mouse_mode==mode,"successful completion restores only its lease and preserves input/view ownership")
	await RenderingServer.frame_post_draw
	check(_green_center(),"normal rendered view is restored after displaced RID headings")
	job.free()
	var foreign:=Node.new();add_child(foreign);actor.text_input_owner=foreign
	job=_new_job();result=await job.run(actor,camera)
	check(not result.completed and result.render_calls==0 and actor.text_input_owner==foreign,"foreign text input is never acquired or released")
	job.free();actor.text_input_owner=null
	job=_new_job();call_deferred("_pause_probe",job);result=await job.run(actor,camera)
	check(_paused_checked and result.completed,"an external pause freezes preparation and resume completes it")
	job.free()
	job=_new_job();call_deferred("_interrupt_probe");result=await job.run(actor,camera)
	while not _interrupt_done:await get_tree().process_frame
	check(not result.completed and result.reason=="player_interrupted" and actor.text_input_owner==null,"Pause cancels our job without retaining input")
	job.free()
	var successor:=Camera3D.new();add_child(successor)
	job=_new_job();call_deferred("_foreign_probe",job,successor,foreign);result=await job.run(actor,camera)
	check(not result.completed and actor.text_input_owner==foreign and actor.protected and successor.is_current(),"foreign camera and protected successor survive cancellation")
	job.free();actor.text_input_owner=null;actor.protected=false;camera.make_current();successor.free()
	job=_new_job();call_deferred("_remove_probe",job);result=await job.run(actor,camera)
	check(not result.completed and result.reason=="owner_removed" and actor.text_input_owner==null and not job.is_inside_tree(),"owner removal cancels suspended work and releases its lease")
	job.free()
	await RenderingServer.frame_post_draw
	check(_green_center() and camera.global_transform.is_equal_approx(pose),"cancellation leaves the normal optical view and Node pose intact")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		get_viewport().get_texture().get_image().save_png(directory.path_join("restored_view.png"))
		FileAccess.open(directory.path_join("fixture_result.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Small rendered owner/pause/cancellation fixture; no composed-world or performance acceptance.","checks":checks,"failures":failures},"\t")+"\n")
	print("ENTRY RENDER PREPARATION: %s; %d checks; %d failures"%["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
