extends Node
## INERT observer. Callback brackets are CPU wall intervals, not GPU completion,
## display latency or exhaustive engine-internal profiling. No scene scans.
class Early extends Node:
	var probe: Node
	func _process(_delta: float) -> void:probe.mark("process_begin")
	func _physics_process(_delta: float) -> void:probe.mark("physics_begin")
var host: Node
var enabled:=true
var timeline: Array=[]
var frames: Array=[]
var monitor_ids: Dictionary={}
var sample_cost_usec: Array=[]

func _ready() -> void:
	process_priority=1000000;process_physics_priority=1000000
	var early:=Early.new();early.probe=self;early.process_priority=-1000000;early.process_physics_priority=-1000000;add_child(early)
	for name: String in ClassDB.class_get_integer_constant_list("Performance"):
		if name.begins_with("PIPELINE_COMPILATIONS_") or name in ["MEMORY_STATIC","RENDER_VIDEO_MEM_USED","RENDER_TOTAL_DRAW_CALLS_IN_FRAME","RENDER_TOTAL_PRIMITIVES_IN_FRAME"]:monitor_ids[name]=ClassDB.class_get_integer_constant("Performance",name)
	RenderingServer.frame_pre_draw.connect(_pre)
	RenderingServer.frame_post_draw.connect(_post)

func active() -> bool:
	return enabled and is_instance_valid(host) and host.profile_active

func mark(stage: String) -> void:
	if not active() or timeline.size()>=60000:return
	timeline.append([Time.get_ticks_usec(),Engine.get_process_frames(),Engine.get_physics_frames(),Engine.get_frames_drawn(),stage,host.profile_phase])

func _process(_delta: float) -> void:mark("process_end")
func _physics_process(_delta: float) -> void:mark("physics_end")
func _pre() -> void:mark("render_pre")
func _post() -> void:
	if not active() or frames.size()>=10000:return
	var started:=Time.get_ticks_usec()
	mark("render_post")
	var counters: Dictionary={}
	for name: String in monitor_ids:counters[name]=Performance.get_monitor(monitor_ids[name])
	var reflections: Node=host.world.get_node_or_null("V2RoomReflections")
	frames.append({"usec":started,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"render_frame":Engine.get_frames_drawn(),"phase":host.profile_phase,"counters":counters,"room_refreshes":reflections.refresh_count if reflections!=null else 0,"residency":host.world.passage_region.residency.state})
	sample_cost_usec.append(Time.get_ticks_usec()-started)

func write(path: String) -> void:
	enabled=false
	var book_states: Array=[]
	# Outside active timing. Confirm which books actually prepared page streams.
	for node: Node in host.world.adapter.root.find_children("*","RigidBody3D",true,false):
		if node.get_script()!=preload("res://scripts/props/v2_readable_book.gd"):continue
		book_states.append({"id":node.stock_id,"pages_ready":node._pages_ready,"print_ready":node._print_ready,"preparation_ms":node.get_meta("print_preparation_ms",0.)})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Instrumented actual-input route. CPU callback brackets and render-signal submission interval; not GPU completion/display latency, not an uninstrumented optimization comparison. Household timings nest and must not be added together. No asset-loading cost measured when residency stays dormant.","columns":["usec","process_frame","physics_frame","render_frame","event","phase"],"timeline":timeline,"frames":frames,"probe_post_sample_usec":sample_cost_usec,"household":host.world.household_state.profile_records,"household_truncation_possible":host.world.household_state.profile_records.size()>=4096,"hand":host.player._grab.profile_records,"hand_truncation_possible":host.player._grab.profile_records.size()>=256,"book_states":book_states,"player_physics":host.player.physics_profile_records,"truncated":timeline.size()>=60000 or frames.size()>=10000},"\t"))

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pre):RenderingServer.frame_pre_draw.disconnect(_pre)
	if RenderingServer.frame_post_draw.is_connected(_post):RenderingServer.frame_post_draw.disconnect(_post)
