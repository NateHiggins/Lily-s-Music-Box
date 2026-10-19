extends RefCounted
## Real isolated save file and a fresh production root; never the player's save.
const Mail=preload("res://tests/v2_service_mail_operations.gd")
const Selector=preload("res://scripts/building/building_root_selector.gd")
var previous_path: String=""
var path: String=""

func write(root: Node,expected: Dictionary) -> bool:
	previous_path=RealityState.save_path
	path="user://tests/v2_service_mail_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json"
	var error: Error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	root._check(error==OK,"isolated mail save directory is writable")
	if error!=OK:return false
	RealityState.save_path=path
	var saved: bool=RealityState.save_game()
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if saved else null
	var household: Dictionary=document.get("v2_household_controls",{}) if document is Dictionary else {}
	var record: Dictionary=household.get("records",{}).get("LobbyMailBank",{})
	var ok: bool=saved and document is Dictionary and str(expected.taken) in document.get("mail_taken",[]) \
		and str(expected.remaining) not in document.get("mail_taken",[]) and str(record.get("kind",""))=="mechanism"
	root._check(ok,"real disk records collected mail and the existing household mechanism owner")
	var directory: String=OS.get_environment("SHOT_DIR")
	if saved and not directory.is_empty():
		root._check(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),directory.path_join("saved_mail.json"))==OK,"preserve the original mail disk snapshot for review")
	return ok

func rebuild(root: Node,expected: Dictionary) -> void:
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	root._check(RealityState.can_continue(),"fresh campaign state loads the real isolated disk save")
	Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	var reference: WeakRef=weakref(world)
	root.add_child(world)
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	root._check(not world.startup_failed,"fresh production world reconstructs from the disk save")
	if not world.startup_failed:
		root._check(Mail.new().restored(world,expected),"disk rebuild restores collected-mail absence and partial letter/leaf positions")
		var board: HouseSwitchboardProp=world.adapter.resolve("F01_HOUSE_TELEPHONE_BOARD") as HouseSwitchboardProp
		root._check(board!=null and board.native_switchboard_ready() and str(board.network.snapshot().state)=="IDLE","rebuilt telephone starts with its transient line idle and native controls intact")
	world.shutdown_for_tests();world.free()
	await root.get_tree().process_frame
	root._check(reference.get_ref()==null,"reconstructed production root retires")

func cleanup() -> void:
	RealityState.persistence_enabled=false
	if not previous_path.is_empty():RealityState.save_path=previous_path
	if path.is_empty():return
	# Only this randomly named test save and its transaction siblings are owned.
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var absolute: String=ProjectSettings.globalize_path(path+suffix)
		if FileAccess.file_exists(absolute):DirAccess.remove_absolute(absolute)
