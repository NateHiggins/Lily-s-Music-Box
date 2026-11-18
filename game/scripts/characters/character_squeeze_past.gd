extends RefCounted
## Character-only courtesy fallback. No collision masks, doors, routes or saves.
const WAIT := 0.8
const CUE_COOLDOWN := 12.0
var _contacts: Dictionary = {}
var _cue_until := -1
var cue_count := 0

func permits(mover: Node3D, peer: Node3D) -> bool:
	if not is_instance_valid(peer) or not peer.is_visible_in_tree(): return false
	if not (peer.is_in_group("player_controller") or peer.is_in_group("animated_residents")): return false
	var frame := Engine.get_physics_frames()
	for key in _contacts.keys():
		if frame - int(_contacts[key].frame) > 1: _contacts.erase(key)
	var id := peer.get_instance_id()
	var row: Dictionary = _contacts.get(id, {"frame": frame - 1, "seconds": 0.0})
	if int(row.frame) != frame:
		row.seconds = float(row.seconds) + mover.get_physics_process_delta_time()
		row.frame = frame
	_contacts[id] = row
	return float(row.seconds) >= WAIT

func cue(speaker: Node3D) -> void:
	var frame := Engine.get_physics_frames()
	if frame < _cue_until or not is_instance_valid(speaker): return
	# Peer-owned cooldown also prevents two movers speaking through one resident.
	if frame < int(speaker.get_meta("squeeze_cue_until", -1)): return
	_cue_until = frame + int(CUE_COOLDOWN * Engine.physics_ticks_per_second)
	speaker.set_meta("squeeze_cue_until", _cue_until)
	cue_count += 1
	var caption := Label3D.new()
	caption.name = "PassingCourtesy"
	caption.text = "Excuse me." if cue_count % 2 == 1 else "Just squeezing past."
	caption.font_size = 32
	caption.pixel_size = .0025
	caption.outline_size = 8
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = false
	speaker.add_child(caption)
	caption.position = Vector3(0, 1.95, 0)
	var tween := caption.create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(caption.queue_free)

func active() -> bool:
	var frame := Engine.get_physics_frames()
	for row: Dictionary in _contacts.values():
		if frame - int(row.frame) <= 1 and float(row.seconds) >= WAIT: return true
	return false
