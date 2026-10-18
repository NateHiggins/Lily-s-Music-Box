extends "res://scripts/building/orison_v2_blockout.gd"

func _profile_mark(label: String) -> void:
	var events: Array=Engine.get_meta("v2_startup_profile",[])
	events.append({"label":label,"us":Time.get_ticks_usec()})
	Engine.set_meta("v2_startup_profile",events)
func _ready() -> void:
	_profile_mark("orison_v2_blockout._ready:enter")
	layout = _load_layout(layout_path)
	if layout.is_empty():
		return
	_validate_layout()
	for identity: String in space_geometry_exclusions:
		var matches := 0
		for space: Dictionary in layout.get("spaces", []):
			if str(space.id) == identity and bool(space.get("open_shell", false)):
				matches += 1
		if matches != 1:
			failures.append("geometry exclusion must name one open-shell space: " + identity)
	_profile_mark("orison_v2_blockout._ready:12 if not failures.is_empty():")
	if not failures.is_empty():
		for failure in failures:
			push_error("ORISON V2: " + failure)
		push_error("ORISON V2 BLOCKOUT REFUSED: %d validation failure(s) in %s;"
				% [failures.size(), layout_path]
				+ " no geometry was built and the selector group was not joined.")
		return
	_profile_mark("orison_v2_blockout._ready:19 _build_palette()")
	_build_palette()
	_profile_mark("orison_v2_blockout._ready:20 _build_spaces()")
	_build_spaces()
	_profile_mark("orison_v2_blockout._ready:21 _build_single_owner_opening_frames()")
	_build_single_owner_opening_frames()
	_profile_mark("orison_v2_blockout._ready:22 _build_doors()")
	_build_doors()
	_profile_mark("orison_v2_blockout._ready:23 _build_windows()")
	_build_windows()
	_profile_mark("orison_v2_blockout._ready:24 _build_envelopes()")
	_build_envelopes()
	_profile_mark("orison_v2_blockout._ready:25 _build_fixtures()")
	_build_fixtures()
	_profile_mark("orison_v2_blockout._ready:26 _build_platforms()")
	_build_platforms()
	_profile_mark("orison_v2_blockout._ready:27 _build_lift_landings()")
	_build_lift_landings()
	_profile_mark("orison_v2_blockout._ready:28 _build_stairs()")
	_build_stairs()
	_profile_mark("orison_v2_blockout._ready:29 _build_risers()")
	_build_risers()
	_profile_mark("orison_v2_blockout._ready:30 _build_anchors()")
	_build_anchors()
	add_to_group("orison_v2_blockout")
	print("ORISON V2 BLOCKOUT: %d spaces / %d doors / %d anchors" % [
		layout.spaces.size(), layout.doors.size(), layout.anchors.size()])

	_profile_mark("orison_v2_blockout._ready:end")
