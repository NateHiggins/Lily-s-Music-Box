extends "res://scripts/props/toaster_prop.gd"
## Preserve the shared cycle and maintenance tray; detach closes event delivery.

var native_ready := false

func _build_retrofit_tray() -> void:
	super._build_retrofit_tray()
	# The source appends its 18 deterministic crumbs last. Retain their nodes
	# through the source merger so the native pass can use the same RNG result.
	var children := _crumb_tray.get_children()
	for i in range(children.size() - 18, children.size()):
		children[i].set_meta("source_toaster_crumb", true)

func merge_static(under: Node3D, keep: Array = []) -> int:
	var retained := keep.duplicate()
	if under == _crumb_tray:
		for child: Node in under.get_children():
			if child.has_meta("source_toaster_crumb"): retained.append(child)
	return super.merge_static(under, retained)

func _build_visual() -> void:
	super._build_visual()
	if has_meta("native_toaster_factory"):
		native_ready = get_meta("native_toaster_factory").install_on(self)
		remove_meta("native_toaster_factory")

func _request_release() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		super._request_release()

func _exit_tree() -> void:
	state = PState.OFF
	_release_on_next_event = false
	for motion: Tween in [_tray_tween, _busy_tween]:
		if motion != null and motion.is_valid(): motion.kill()
	super._exit_tree()
