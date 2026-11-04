extends "res://tests/v2_nook_world_profile.gd"
## Played-world source-bound interaction proof; frame arrays remain INERT.
var _return_completed:=false
var _disk_completed:=false
const SOURCE_SNAPSHOT_CODE: String="""import json,sys
from pathlib import Path
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'tools'))
from v2_surface_evidence import file_hash,test_dependency_paths
from run_receipt import runtime_inputs_sha256
seeds=[root/'game/tests'/name for name in ['v2_book_inspection_return_world.gd','V2BookInspectionReturnWorld.tscn','native_debug_window.gd']]
seeds += [root/'tools/run_receipt.py',root/'tools/v2_surface_evidence.py']
paths=test_dependency_paths(root,seeds)
print(json.dumps({'runtime_inputs_sha256':runtime_inputs_sha256(root),'test_dependencies':{p.relative_to(root).as_posix():file_hash(p) for p in sorted(paths)}}))
"""

func _route() -> void:
	var test_hash: String=FileAccess.get_sha256(get_script().resource_path)
	var before: Dictionary=_source_snapshot()
	if _require(str(before.get("runtime_inputs_sha256","")).length()==64 and not before.get("test_dependencies",{}).is_empty(),"consumed production and transitive test sources are available"):
		await super._route()
	var after: Dictionary=_source_snapshot()
	_require(before==after and test_hash==FileAccess.get_sha256(get_script().resource_path),"executed sources remain fixed through installed nook interaction and reload")
	_require(_return_completed,"actual installed inspection-return-release programme completed")
	var disk_requested: bool=OS.get_environment("ORISON_NOOK_DISK_RELOAD")=="1"
	if disk_requested:_require(_disk_completed,"requested installed nook disk reconstruction completed")
	var passed: bool=failures.is_empty()
	var record: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Existing installed V2 nook from one nearby test placement: three local controller waypoints, actual pickup, Space inspection/return, next-primary release and optional isolated validated campaign disk reconstruction. No corridor-access, shelf-slot return, cold-start speedup, whole-game or artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_book_inspection_return_world.gd","test_sha256":test_hash,"scene_path":scene_file_path,"test_dependencies":before.get("test_dependencies",{}),"runtime_inputs_sha256":before.get("runtime_inputs_sha256","")},
		"programme":{"completed":_return_completed and (not disk_requested or _disk_completed),"trace":trace,"failures":failures,"disk_requested":disk_requested},
		"contracts":{"installed_book_return_release":{"executed":_return_completed,"passed":_return_completed and passed},"installed_nook_disk_reload":{"executed":_disk_completed,"passed":_disk_completed and passed}}}
	var directory: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess=FileAccess.open(directory.path_join("nook_return.runtime.json"),FileAccess.WRITE)
	if _require(file!=null,"installed nook runtime contract can be written"):
		file.store_string(JSON.stringify(record,"\t"));_require(file.get_error()==OK,"installed nook runtime contract is complete");file.close()

func _source_snapshot() -> Dictionary:
	var output: Array=[]
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",["-c",SOURCE_SNAPSHOT_CODE,root],output)!=0 or output.is_empty():return {}
	var parsed: Variant=JSON.parse_string(str(output[0]))
	return parsed if parsed is Dictionary else {}

func _play_route() -> void:
	await super._play_route()
	if failures.is_empty() and OS.get_environment("ORISON_NOOK_DISK_RELOAD")=="1":
		# Disk reconstruction is not part of this route's timing sample. Keep the
		# same installed collection, campaign validator and household save owner.
		profile_active=false
		await _disk_reload_review()

func _disk_reload_review() -> void:
	var shelf: Node3D=world.adapter.resolve("nook_books_library")
	if not _require(shelf!=null,"installed nook exists before disk save"):return
	var identity:=str(shelf.name)
	var previous_owner_id:=shelf.get_instance_id()
	var wanted: Dictionary=shelf.library_snapshot()
	if not _require(shelf.valid_library(wanted),"played nook state validates before save"):return
	var previous_path: String=RealityState.save_path
	var test_path: String="user://tests/nook_reload_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_path).get_base_dir())
	RealityState.flush_background_saves()
	RealityState.save_path=test_path
	var saved: bool=RealityState.save_game()
	if _require(saved,"campaign storage writes the played nook state"):
		var disk: Variant=JSON.parse_string(FileAccess.get_file_as_string(test_path))
		var key: String=world.household_state.KEY
		var recorded: Dictionary=disk.get(key,{}).get("records",{}).get(identity,{}).get("value",{}) if disk is Dictionary else {}
		if _require(_same_payload(recorded,wanted),"disk contains the actual played library, not default placements"):
			world.shutdown_for_tests();world.free()
			RealityState.reset_campaign_for_tests();RealityState.load_game()
			_require(not RealityState.save_write_blocked and _same_payload(RealityState.data,disk),"validated campaign load preserves all saved domains")
			world=Runtime.instantiate();add_child(world)
			player=world.player
			if _require(not world.startup_failed and player!=null,"fresh production world reconstructs after nook disk load"):
				# Compare synchronously before advancing loose-stock simulation.
				var restored: Node3D=world.adapter.resolve("nook_books_library")
				_require(restored!=null and restored.get_instance_id()!=previous_owner_id and restored.valid_library(wanted) and _same_payload(restored.library_snapshot(),wanted),"fresh installed owner restores slot occupancy, book poses and opening")
				_require(not player.inspecting() and not player._grab.active(),"reload does not resurrect the previous hand or inspection")
				player.camera.make_current()
				await get_tree().physics_frame;await get_tree().physics_frame
				_disk_completed=failures.is_empty()
	RealityState.save_path=previous_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var output:=OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		FileAccess.open(output.path_join("nook_disk_reload.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","saved":saved,"owner":identity,"scope":"Actual installed pickup/inspection/release and validated campaign disk reconstruction. No shelf-slot return or corridor access acceptance.","failures":failures},"\t"))

func _same_payload(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_FLOAT,TYPE_INT] and typeof(b) in [TYPE_FLOAT,TYPE_INT]:return absf(float(a)-float(b))<.00001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key: Variant in a:
			if not b.has(key) or not _same_payload(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for index in a.size():
			if not _same_payload(a[index],b[index]):return false
		return true
	return a==b

func _inspect_stock_review(book: Node3D) -> void:
	# The parent just read back/compressed a PNG. Drain that interval while
	# still capture-excluded before delivering the measured Space event.
	for frame in 3:await get_tree().process_frame
	profile_phase="nook_return_hand"
	var space:=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	space=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=false;player._unhandled_input(space)
	if not _require(not player.inspecting() and player._grab.holding_pickup() and player._grab.target.part==book,"Space returns world binding to original hand"):return
	_require(book._held and book.freeze,"returned world binding retains owner hand permission")
	_require(player.get_collision_exceptions().has(book) and book.get_collision_exceptions().has(player),"returned world binding excludes only carrier")
	for frame in 110:await get_tree().process_frame
	var error: float=(book.global_transform*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48))
	_require(error<.01,"returned world binding reaches swept hand pose")
	_require(book.shelf.valid_library(book.shelf.library_snapshot()),"returned world binding retains valid durable snapshot")
	profile_phase="nook_return_capture_excluded"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("returned_world_book.png"))
	for frame in 3:await get_tree().process_frame
	profile_phase="nook_return_release"
	_click_library()
	_require(not player._grab.active() and not book._held and not book.freeze,"next primary releases returned world binding")
	_require(not player.get_collision_exceptions().has(book) and not book.get_collision_exceptions().has(player),"world primary release restores carrier collision")
	for frame in 40:await get_tree().process_frame
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("return.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","stock_id":book.stock_id,"held_error_m":error,"failures":failures},"\t"))
	_return_completed=true
