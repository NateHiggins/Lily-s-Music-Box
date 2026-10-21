extends "res://tests/v2_played_profile_and_bucket_review.gd"
## Attribution-only pass. Same actual route; additional bounded read-only
## physics/hand diagnostics and global render-signal timestamps. No FPS gain.
var timeline: Array[Dictionary]=[]
func _process(delta: float) -> void:
 super._process(delta)
 _mark("sampler_process")
func _mark(stage: String) -> void:
 if not profile_active or timeline.size()>=60000:return
 timeline.append({"stage":stage,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"usec":Time.get_ticks_usec(),"phase":profile_phase})
func _pre_render() -> void:_mark("render_pre")
func _post_render() -> void:_mark("render_post")
func _route() -> void:
 player.profile_physics=true;player._grab.profiling=true
 RenderingServer.frame_pre_draw.connect(_pre_render)
 RenderingServer.frame_post_draw.connect(_post_render)
 await super._route()
 RenderingServer.frame_pre_draw.disconnect(_pre_render)
 RenderingServer.frame_post_draw.disconnect(_post_render)
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  FileAccess.open(out.path_join("attribution_timeline.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Read-only attribution, not an optimized/uninstrumented performance comparison. Sampler-to-render-pre includes downstream scene work; pre/post signals measure CPU submission interval, not GPU completion or display latency. Physics records have original order/positions but no individual timestamps. Existing 6000-physics/256-hand caps remain explicit.","physics_enabled":player.profile_physics,"physics_retained":player.physics_profile_records.size(),"physics_truncation_possible":player.physics_profile_records.size()>=6000,"step_guard_rejections":player.step_guard_rejections,"hand_costs":player._grab.profile_records,"hand_truncation_possible":player._grab.profile_records.size()>=256,"timeline_truncation_possible":timeline.size()>=60000,"timeline":timeline,"failures":failures},"\t"))
