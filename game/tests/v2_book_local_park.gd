extends "res://tests/v2_book_inspection_return_world.gd"
## INERT nearby actual-input Volume0 slot-return fixture.
const LocalNook := preload("res://scripts/building/orison_v2_reading_nook.gd")
const LocalPrecision := preload("res://scripts/building/v2_contact_precision.gd")
const STOCK_ID := "nook_books__Volume0"
const RECORDED_EYE := "Transform3D(0.8687908, 0.24290279, -0.4315099, 0, 0.8714215, 0.49053502, 0.49517933, -0.4261723, 0.757083, 0.4283762, -1.7810313, -13.789711)"
const OWNER_ORIGIN := Vector3(.48500133, -3.2, -14.9897995)
const RESULT_FILE := "local_volume0_park.json"
var local_precision := LocalPrecision.new()
var local_report: Dictionary = {"evidence_class": "INERT", "stock_id": STOCK_ID}
var local_output := ""
var local_book: Node3D
var watched_motion_phase := ""
var motion_at_phase_start: Dictionary = {}
var first_observed_sweeps: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 100
	_local_run.call_deferred()

func _exit_tree() -> void:
	local_precision.release()

func _local_run() -> void:
	local_output = OS.get_environment("SHOT_DIR")
	if not _require(not local_output.is_empty() and DirAccess.make_dir_recursive_absolute(local_output) == OK,"fresh local park output directory is writable"):
		local_output = ""
		_local_finish(); return
	for filename: String in [RESULT_FILE,"return.json","returned_world_book.png"]:
		if not _require(not FileAccess.file_exists(local_output.path_join(filename)),"local park output is fresh: "+filename):
			local_output = ""
			_local_finish(); return
	var viewport := get_viewport() as SubViewport
	if not _require(viewport != null and viewport.size == Vector2i(3440,1440),"detached native 3440x1440 input viewport is active"):
		_local_finish(); return
	local_report.source_lf = {"driver":_source_text_hash(get_script().resource_path),"parent":_source_text_hash("res://tests/v2_book_inspection_return_world.gd"),"scene":_source_text_hash(get_tree().current_scene.scene_file_path)}
	if not _require(local_precision.bind(get_viewport().find_world_3d()),"native V2 contact precision binds in the local nook"):
		_local_finish(); return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var fixture := Node3D.new()
	fixture.name = "NativeNookFixture"
	add_child(fixture)
	var adapter := OrisonV2AnchorAdapter.new(fixture)
	if not _require(LocalNook.mount(adapter),"production native nook mounts in nearby fixture"):
		_local_finish(); return
	var shelf: Node3D = adapter.resolve("nook_books_library")
	var copy_count := 0
	for collection: Node in fixture.find_children("*_library","Node3D",true,false):
		copy_count += (collection.get("_books") as Dictionary).size()
	if not _require(shelf != null and copy_count == 61,"actual nook library and all 61 authored copies load"):
		_local_finish(); return
	local_book = shelf._books.get(STOCK_ID)
	if not _require(local_book != null and local_book.title_id == "wiring" and is_zero_approx(local_book.opening),"original Volume0 wiring copy is present and closed"):
		_local_finish(); return
	# Place the whole native nook in the same frame as the proven Volume17 fixture.
	var installed_owner := Transform3D(Basis(Vector3.UP,PI),OWNER_ORIGIN)
	fixture.global_transform = installed_owner * shelf.global_transform.affine_inverse() * fixture.global_transform
	local_report.native_copy_count = copy_count
	local_report.owner_transform = var_to_str(shelf.global_transform)
	var eye: Transform3D = str_to_var(RECORDED_EYE)
	var foot := eye.origin - Vector3.UP * PlayerController.STANDING_EYE
	var floor_body := StaticBody3D.new()
	floor_body.name = "FixtureStandingFloor"
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(.8,.10,.8)
	floor_shape.shape = slab
	floor_body.add_child(floor_shape)
	var floor_y: float=float(JSON.parse_string(FileAccess.get_file_as_string(LocalNook.PATH)).floor_y)
	floor_body.position = Vector3(foot.x,floor_y-slab.size.y*.5,foot.z)
	add_child(floor_body)
	local_report.local_floor = {"top_y":floor_y,"size_m":str(slab.size),"body":_park_object(floor_body)}
	player = PlayerController.new()
	player.name = "StancePlayer"
	add_child(player)
	player.global_transform = Transform3D(Basis(Vector3.UP,atan2(.792624,.609711)),foot)
	player.camera.global_transform = eye
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in 12: await get_tree().physics_frame
	var eye_error := player.camera.global_position.distance_to(eye.origin)
	local_report.stance = {"player":var_to_str(player.global_transform),"eye":var_to_str(player.camera.global_transform),"error_m":eye_error,"on_floor":player.is_on_floor(),"collision_mask":player.collision_mask,"capsule_radius":player._capsule.radius}
	if not _require(player.is_on_floor() and player.collision_mask != 0 and is_equal_approx(player._capsule.radius,PlayerController.BODY_RADIUS) and eye_error <= .003,"full standing player settles at the proven nearby eye"):
		_local_finish(); return
	if not _snapshot_original_slots(shelf):
		_local_finish(); return
	var spine := local_book.to_global(Vector3(-.001,float(local_book.construction.height)*.65,0))
	player.camera.look_at(spine)
	for tick in 2: await get_tree().physics_frame
	var picked: Dictionary = player._grab.find_target()
	_park_ray_observe("initial_volume0_fps_spine",picked)
	_park_observe("initial_original_slot",local_book)
	if not _require(picked.get("part") == local_book and picked.get("kind") == "free","actual initial ray targets the original Volume0 spine"):
		_local_finish(); return
	var primary := InputEventMouseButton.new()
	primary.button_index = MOUSE_BUTTON_LEFT
	primary.pressed = true
	primary.position = Vector2(viewport.size) * .5
	primary.global_position = primary.position
	viewport.notify_mouse_entered()
	viewport.push_input(primary,true)
	if not _require(player.held_stock_body() == local_book and local_book.shelf_slot == -1,"actual primary picks up Volume0 and vacates its original slot"):
		_local_finish(); return
	for frame in 100: await get_tree().process_frame
	for frame in 32:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(2. if frame < 16 else -2.,0)
		player._unhandled_input(motion)
		await get_tree().process_frame
	_park_observe("initial_fps_pickup",local_book)
	await _park_space()
	if not _require(player.inspecting() and local_book.freeze,"normal first Space supports the actual selected Volume0"):
		_local_finish(); return
	for frame in 220: await get_tree().process_frame
	await _inspect_stock_review(local_book)
	_require(_return_completed and _park_attempted and _park_executed and _park_completed,"original local unplaced and parked Space-exit controls complete")
	_local_finish()

func _snapshot_original_slots(shelf: Node3D) -> bool:
	_original_library = shelf.library_snapshot().duplicate(true)
	if not _require(shelf.valid_library(_original_library),"original native collection snapshot validates before pickup"):
		return false
	var ids: Array = shelf._books.keys()
	for book: Node3D in shelf._books.values():
		var slot: int = book.shelf_slot
		if not _require(slot >= 0 and slot < shelf.book_slots.size(),"original copy has a valid slot: "+book.stock_id):
			return false
		_original_books[book.stock_id] = {"id":book.get_instance_id(),"owner_id":shelf.get_instance_id(),"frame_pose":shelf.global_transform,"ids":ids.duplicate(),"slot":slot,"pose":book.transform,"slot_pose":shelf.book_slots[slot],"withdrawal_world":shelf.pickup_withdrawal_for(book)}
	var original: Dictionary = _original_books[STOCK_ID]
	local_report.original = {"slot":original.slot,"instance_id":original.id,"owner_id":original.owner_id,"inventory_count":ids.size(),"book_pose":var_to_str(original.pose),"slot_pose":var_to_str(original.slot_pose),"withdrawal_world":str(original.withdrawal_world)}
	return true

func _park_observe(phase: String, book: Node3D) -> void:
	super._park_observe(phase,book)
	# Record at most one fresh native sweep per leg. The inherited final leg
	# observations and the ray's actual first hit remain in parked_trace.
	match phase:
		"spine_acquired": watched_motion_phase = "player_clearance"
		"rotated": watched_motion_phase = "approach_leg_0"
		"approach_leg_0": watched_motion_phase = "approach_leg_1"
		"approach_leg_1": watched_motion_phase = "approach_leg_2"
		_: watched_motion_phase = ""
	motion_at_phase_start = book._last_motion if not watched_motion_phase.is_empty() else {}

func _physics_process(_delta: float) -> void:
	if watched_motion_phase.is_empty() or first_observed_sweeps.has(watched_motion_phase) or not is_instance_valid(local_book):
		return
	var motion: Dictionary = local_book._last_motion
	if not motion.is_empty() and not is_same(motion,motion_at_phase_start):
		first_observed_sweeps[watched_motion_phase] = {"physics_frame":Engine.get_physics_frames(),"pose":var_to_str(local_book.global_transform),"contact":_park_hit_fields(motion)}

func _local_finish() -> void:
	watched_motion_phase = ""
	motion_at_phase_start = {}
	local_report.merge({"unplaced_return_completed":_return_completed,"park_attempted":_park_attempted,"park_exit_executed":_park_executed,"park_completed":_park_completed,"parked_trace":_park_trace,"first_observed_sweeps":first_observed_sweeps,"checks":interaction_checks,"failures":failures})
	if not local_output.is_empty():
		var file := FileAccess.open(local_output.path_join(RESULT_FILE),FileAccess.WRITE)
		if _require(file != null,"local park trace opens"):
			file.store_string(JSON.stringify(local_report,"\t"))
			_require(file.get_error() == OK,"local park trace writes")
			file.close()
	print("LOCAL VOLUME0 PARK: ","PASS" if failures.is_empty() else "FAIL"," checks=",interaction_checks.size()," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
