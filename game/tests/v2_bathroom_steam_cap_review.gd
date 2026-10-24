extends "res://tests/v2_bathroom_paper_review.gd"
## Focused actual hot/curtain input and independent installed paper checks.
## One initial fixture placement; no traversal or timing qualification.
func _init() -> void:route_label="V2 STEAM CAP AND PAPER REVIEW"
func _route() -> void:
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	_moisture=world.bathroom_moisture
	_tap=world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	if not _require(_tap!=null,"installed shower exists for actual thermal-cap input"):return
	player.global_position=_tap.to_global(Vector3(0,.02,-.9));player.velocity=Vector3.ZERO
	for frame in 3:await get_tree().physics_frame
	var room: Dictionary=_moisture._rooms[_source().room]
	var view:=_tap.to_global(Vector3(0,1.15,.08))
	await _shot("initial_dry_spray_room",view)
	if not await _drag_part(_tap,_tap.to_global(Vector3(0,1.18,-.32)),1.78,"cap_curtain_open"):return
	if not await _drag_part(_tap,_tap._handles[0].global_position,PI*.5,"cap_hot_on"):return
	await get_tree().create_timer(12.0).timeout
	_require(float(room.humidity)>.2 and room.steam.visible,"actual hot flow progressively fills the bathroom with local steam")
	await _shot("developing_spray_room_steam",view)
	await _verify_steam_cap(room,view)
	var before:=float(room.humidity)
	if not await _drag_part(_tap,_tap._handles[0].global_position,0.0,"cap_hot_off"):return
	await get_tree().create_timer(5.0).timeout
	_require(float(room.humidity)<before and float(room.humidity)>0.0,"actual shutoff clears room steam gradually")
	await _paper_review()
