extends "res://scripts/props/toaster_prop.gd"
## Preserve the shared cycle and maintenance tray; detach closes event delivery.

func _request_release() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		super._request_release()

func _exit_tree() -> void:
	state = PState.OFF
	_release_on_next_event = false
	for motion: Tween in [_tray_tween, _busy_tween]:
		if motion != null and motion.is_valid(): motion.kill()
	super._exit_tree()
