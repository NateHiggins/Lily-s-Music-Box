extends "res://tests/v2_nook_world_profile.gd"
## Played-world source-bound interaction proof; frame arrays remain INERT.
var _return_completed:=false
var _disk_completed:=false
var _park_executed:=false
var _park_completed:=false
var _original_books: Dictionary={}
var _original_library: Dictionary={}
var _park_trace: Array[Dictionary]=[]
const SOURCE_SNAPSHOT_CODE: String="""import json,sys
from pathlib import Path
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'tools'))
from v2_surface_evidence import file_hash,test_dependency_paths
from run_receipt import runtime_inputs_sha256
seeds=[root/sys.argv[2],root/sys.argv[3],root/'game/tests/native_debug_window.gd']
seeds += [root/'tools/run_receipt.py',root/'tools/v2_surface_evidence.py']
paths=test_dependency_paths(root,seeds)
print(json.dumps({'runtime_inputs_sha256':runtime_inputs_sha256(root),'test_dependencies':{p.relative_to(root).as_posix():file_hash(p) for p in sorted(paths)}}))
"""

func _route() -> void:
	var test_hash: String=_source_text_hash(get_script().resource_path)
	var executed_scene: String=get_tree().current_scene.scene_file_path
	var scene_hash: String=_source_text_hash(executed_scene)
	_require(get_viewport() is SubViewport and executed_scene=="res://tests/V2BookInspectionReturnWorld.tscn" and scene_hash.length()==64,"installed contract executes the bound root scene with detached input viewport")
	var before: Dictionary=_source_snapshot()
	if _require(str(before.get("runtime_inputs_sha256","")).length()==64 and not before.get("test_dependencies",{}).is_empty(),"consumed production and transitive test sources are available"):
		await super._route()
	var after: Dictionary=_source_snapshot()
	_require(before==after and test_hash==_source_text_hash(get_script().resource_path) and scene_hash==_source_text_hash(executed_scene),"executed sources remain fixed through installed nook interaction and reload")
	_require(_return_completed,"actual installed inspection-return-release programme completed")
	_require(_park_completed,"actual installed same-binding slot-release and normal Space exit completed")
	var disk_requested: bool=OS.get_environment("ORISON_NOOK_DISK_RELOAD")=="1"
	if disk_requested:_require(_disk_completed,"requested installed nook disk reconstruction completed")
	var passed: bool=failures.is_empty()
	var record: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Existing installed V2 nook from one nearby test placement: three local controller waypoints, actual pickup, Space inspection/return, next-primary release, same-binding slot parking/normal Space exit and optional isolated validated campaign disk reconstruction. No corridor-access, cold-start speedup, whole-game or artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_book_inspection_return_world.gd","test_sha256":test_hash,"scene_path":executed_scene,"scene_sha256":scene_hash,"script_node_path":str(get_path()),"test_dependencies":before.get("test_dependencies",{}),"runtime_inputs_sha256":before.get("runtime_inputs_sha256","")},
		"programme":{"completed":_return_completed and _park_completed and (not disk_requested or _disk_completed),"original_library":_original_library,"parked_trace":_park_trace,"trace":trace,"failures":failures,"disk_requested":disk_requested},
		"contracts":{"installed_book_parked_exit":{"executed":_park_executed,"passed":_park_completed and passed},"installed_book_return_release":{"executed":_return_completed,"passed":_return_completed and passed},"installed_nook_disk_reload":{"executed":_disk_completed,"passed":_disk_completed and passed}}}
	var directory: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess=FileAccess.open(directory.path_join("nook_return.runtime.json"),FileAccess.WRITE)
	if _require(file!=null,"installed nook runtime contract can be written"):
		file.store_string(JSON.stringify(record,"\t"));_require(file.get_error()==OK,"installed nook runtime contract is complete");file.close()

func _source_snapshot() -> Dictionary:
	var output: Array=[]
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",["-c",SOURCE_SNAPSHOT_CODE,root,"game/"+get_script().resource_path.trim_prefix("res://"),"game/"+get_tree().current_scene.scene_file_path.trim_prefix("res://")],output)!=0 or output.is_empty():return {}
	var parsed: Variant=JSON.parse_string(str(output[0]))
	return parsed if parsed is Dictionary else {}

func _source_text_hash(path: String) -> String:
	if not FileAccess.file_exists(path):return ""
	return FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()

func _play_route() -> void:
	# Observe original owners/poses before the parent's first actual pickup.
	var shelf: Node3D=world.adapter.resolve("nook_books_library")
	if not _require(shelf!=null,"installed collection exists before first pickup"):return
	_original_library=shelf.library_snapshot().duplicate(true)
	if not _require(shelf.valid_library(_original_library),"original installed collection snapshot validates before pickup"):return
	var ids: Array=shelf._books.keys()
	for book: Node3D in shelf._books.values():
		var slot: int=book.shelf_slot
		if not _require(slot>=0 and slot<shelf.book_slots.size(),"original installed binding has a saved slot: "+book.stock_id):return
		_original_books[book.stock_id]={"id":book.get_instance_id(),"owner_id":shelf.get_instance_id(),"frame_pose":shelf.global_transform,"ids":ids.duplicate(),"slot":slot,"pose":book.transform,"slot_pose":shelf.book_slots[slot],"withdrawal_world":shelf.pickup_withdrawal_for(book)}
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
		FileAccess.open(output.path_join("nook_disk_reload.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","saved":saved,"owner":identity,"scope":"Actual installed pickup/inspection/release and validated campaign disk reconstruction. Includes same-binding slot release/normal Space exit; no corridor access acceptance.","failures":failures},"\t"))

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
	if failures.is_empty():await _park_installed_book(book)


func _park_space() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
	player._unhandled_input(event)
	for frame in 3:await get_tree().physics_frame
	event=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=false;player._unhandled_input(event)
	for frame in 3:await get_tree().physics_frame

func _park_cursor(point: Vector3) -> bool:
	var viewport:=get_viewport()
	if not viewport is SubViewport:return false
	var pixel:=player.camera.unproject_position(point).round()
	if player.camera.is_position_behind(point) or not viewport.get_visible_rect().has_point(pixel):return false
	var motion:=InputEventMouseMotion.new();motion.position=pixel;motion.global_position=pixel
	viewport.push_input(motion,true)
	await get_tree().process_frame
	return viewport.get_mouse_position().distance_to(pixel)<.6

func _park_observe(phase: String, book: Node3D) -> void:
	var hit: Variant=book._last_motion.get("collider")
	var row: Dictionary={"phase":phase,"stock_id":book.stock_id,"instance_id":book.get_instance_id(),"owner_id":book.shelf.get_instance_id(),"book_pose":var_to_str(book.transform),"world_pose":var_to_str(book.global_transform),"owner_pose":var_to_str(book.shelf.global_transform),"camera_pose":var_to_str(player.camera.global_transform),"local_contact":var_to_str(player._grab.contact),"world_contact":var_to_str(book.to_global(player._grab.contact)),"axis":player._grab.transform_axis,"rotating":player._grab.transform_rotating,"held":book._held,"frozen":book.freeze,"slot":book.shelf_slot,"inspection":player.inspecting(),"grab_active":player._grab.active(),"same_hand_book":player._grab.target.get("part")==book,"carrier_exceptions_clear":not player.get_collision_exceptions().has(book) and not book.get_collision_exceptions().has(player),"last_motion":var_to_str(book._last_motion),"blocker_path":str(hit.get_path()) if hit is Node else ""}
	_park_trace.append(row);print("INSTALLED BOOK PARK: ",JSON.stringify(row))

func _park_installed_book(book: Node3D) -> void:
	_park_executed=true
	profile_active=false # Additional manipulation, queries/captures are not parent timings.
	var shelf: Node3D=book.shelf
	var original: Dictionary=_original_books.get(book.stock_id,{})
	if not _require(not original.is_empty() and book.get_instance_id()==original.id and shelf.get_instance_id()==original.owner_id and shelf._books.keys()==original.ids,"installed return keeps original binding, collection and inventory"):return
	var wanted: Transform3D=original.slot_pose
	if not _require(wanted.is_equal_approx(original.pose) and shelf.book_slots[original.slot].is_equal_approx(wanted) and shelf.global_transform.is_equal_approx(original.frame_pose),"original installed slot and pre-pickup pose agree unchanged"):return
	if not _require(book.opening<=.04,"existing installed programme leaves the binding closed for slot return"):return
	# Reacquire the released SAME body by its actual exposed spine ray.
	var spine:=book.get_node("ManipulateSpine").get_child(0) as CollisionShape3D
	player.camera.look_at(spine.global_position)
	await get_tree().physics_frame
	var picked: Dictionary=player._grab.find_target()
	print("INSTALLED BOOK REACQUIRE RAY: ",picked)
	_park_observe("before_reacquire",book)
	if not _require(picked.get("part")==book and picked.get("kind")=="free","released installed binding exposes a real reachable spine ray"):return
	_click_library()
	if not _require(player._grab.holding_pickup() and player._grab.target.part==book,"actual primary reacquires the same released installed binding"):return
	for frame in 100:await get_tree().physics_frame
	await _park_space()
	if not _require(player.inspecting(),"normal Space opens installed return inspection"):return
	for frame in 180:await get_tree().physics_frame
	if not _require(await _park_cursor(spine.global_position),"detached pointer reaches actual installed spine"):return
	picked=player._grab.find_target();print("INSTALLED BOOK FREE SPINE RAY: ",picked)
	if not _require(picked.get("part")==book and picked.get("kind")=="free","actual free cursor targets the same installed binding"):return
	_click_library()
	if not _require(player._grab.active() and player._grab.target.part==book,"actual primary latches the installed floating spine"):return
	_park_observe("spine_acquired",book)
	var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;player._unhandled_input(right)
	var aligned:=false
	for step in 100:
		if not player._grab.active() or player._grab.target.part!=book:break
		var error:=Quaternion(wanted.basis*book.basis.inverse()).normalized()
		var angle:=error.get_angle()
		if angle>PI:angle-=TAU
		if absf(angle)<.003:aligned=true;break
		var turn:=error.get_axis()*angle
		_park_axis(turn.abs().max_axis_index())
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(clampf(turn[player._grab.transform_axis]/.008,-20.,20.),0.)
		player._unhandled_input(motion);await get_tree().physics_frame
	right.pressed=false;player._unhandled_input(right);_park_axis(-1)
	_park_observe("rotated",book)
	if not _require(aligned,"actual precision input restores original installed slot orientation"):return
	# Reverse the OWNER'S original withdrawal, not household-case +Z.
	var outward: Vector3=(original.frame_pose.basis.inverse()*original.withdrawal_world).normalized()
	if not _require(outward.is_finite() and outward.length()>.99,"original installed withdrawal supplies a finite approach direction"):return
	var lift: Vector3=(original.frame_pose.basis.inverse()*Vector3.UP).slide(outward)
	if lift.length()>.001:lift=lift.normalized()
	else:lift=Vector3.ZERO
	var approach: Vector3=wanted.origin+outward*.12+lift*.008
	var depth: float=(book.position-wanted.origin).dot(outward)
	if not _require(depth>.12,"actual floating binding lies outside original installed withdrawal corridor"):return
	var goals: Array[Vector3]=[approach+outward*(depth-.12),approach,wanted.origin+outward*.015+lift*.004]
	for index in goals.size():
		var moved: bool=await _park_carry(goals[index])
		_park_observe("approach_leg_%d"%index,book)
		if not _require(moved,"actual installed mouse/depth approach reaches bounded leg %d"%index):return
	_click_library()
	_park_observe("primary_slot_release",book)
	if not _require(not player._grab.active() and not book._held and book.freeze and book.shelf_slot==original.slot and book.transform.is_equal_approx(wanted),"actual primary release parks the SAME installed binding in its exact original slot"):return
	await _park_space()
	for frame in 8:await get_tree().physics_frame
	_park_observe("parked_after_normal_space",book)
	var clean: bool=not player.get_collision_exceptions().has(book) and not book.get_collision_exceptions().has(player)
	if not _require(not player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not player._grab.active() and not book._held and book.freeze and shelf._hand_node!=book and clean,"normal Space leaves installed parked binding frozen, hand free and carrier contacts restored"):return
	if not _require(book.get_instance_id()==original.id and shelf.get_instance_id()==original.owner_id and shelf._books.get(book.stock_id)==book and shelf._books.keys()==original.ids and book.shelf_slot==original.slot and book.transform.is_equal_approx(wanted) and shelf.valid_library(shelf.library_snapshot()),"installed parked exit preserves original identity, inventory, exact slot pose and valid save owner before disk save"):return
	_park_completed=true

func _park_carry(goal: Vector3) -> bool:
	print("CARRY BEGIN: ",goal," target=",player._grab.target.get("part"))
	var stalled:=0
	for frame in 120:
		if not player._grab.active() or player._grab.target.kind!="free": return false
		var target: Dictionary=player._grab.target
		var before: Vector3=target.read.call()
		if before.distance_to(goal)<.0001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var delta: Vector3=target.frame.global_basis*(goal-before)
		var depth:=delta.dot((point-player.camera.global_position).normalized())
		if absf(depth)>.000002:
			var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0. else MOUSE_BUTTON_WHEEL_UP
			wheel.factor=minf(.025,absf(depth))/.025;player._unhandled_input(wheel)
		point=target.part.to_global(player._grab.contact);delta=target.frame.global_basis*(goal-target.read.call())
		var planar:=delta-player.camera.global_basis.z*delta.dot(player.camera.global_basis.z)
		var motion:=InputEventMouseMotion.new();motion.relative=(player.camera.unproject_position(point+planar)-player.camera.unproject_position(point)).limit_length(25.)
		if frame<3: print("CARRY MOTION: ",frame," before=",before," mouse=",motion.relative)
		player._unhandled_input(motion)
		if frame<3: print("CARRY MOTION RETURN: ",frame," contact=",target.part._last_motion)
		await get_tree().physics_frame
		stalled=stalled+1 if player._grab.active() and goal.distance_to(player._grab.target.read.call())>=goal.distance_to(before)-.000001 else 0
		if stalled>8:
			print("CARRY STOP: ",player._grab.target.part._last_motion," at=",player._grab.target.read.call()," goal=",goal);return false
	return false

func _park_axis(axis: int) -> void:
	var current: int=player._grab.transform_axis
	if current==axis:return
	if axis<0:axis=current
	if axis<0:return
	var key:=InputEventKey.new();key.keycode=[KEY_X,KEY_Y,KEY_Z][axis];key.physical_keycode=key.keycode;key.pressed=true
	player._unhandled_input(key)
	key.pressed=false;player._unhandled_input(key)
