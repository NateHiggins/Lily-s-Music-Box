extends Node3D
## Actual owners, all issued resident identities, copy authorization and storage.
const SAVE := "user://tests/resident_keys_test.json"
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL: "+label)

func _settle(door: DoorProp) -> void:
	for i in 120:
		await get_tree().physics_frame
		if not door._moving and not door._key_turning: return
	_check(false,"key and leaf settle within deadline")

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var schedules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_schedules.json"))
	var originals := DoorKeyring.book().originals.duplicate(true) as Dictionary
	_check(originals.size()==18,"all eighteen resident originals issued")
	_check(not DoorKeyring.make_copy("2A"),"copy without permission denied")
	for id: String in schedules.residents:
		var resident := AnimatedResident.new()
		resident.resident_id = id
		var door := DoorProp.new()
		door.name = "ResidentKeyFixture_"+id
		door.unit = str(schedules.residents[id].unit)
		door.door_kind = "apartment_entry"
		door.leaf_state = "locked"
		add_child(door)
		_check(DoorKeyring.resident_has_key(id,door),id+" owns original for own apartment")
		var other := "mina_vale" if id != "mina_vale" else "evelyn_marsh"
		_check(not DoorKeyring.resident_has_key(other,door),"unrelated resident cannot use original: "+id)
		_check(not DoorKeyring.player_has_key(door),"unapproved player spare absent: "+id)
		_check(door.interact_key(null).is_empty() and door.leaf_state=="locked","private lock refuses player before copy")
		door.npc_set_open(true,"unknown_resident")
		_check(not door.open and not door._moving,"unknown original refuses leaf")
		door.npc_set_open(true,id)
		_check(door.open and door._moving and not door.is_ready_for_passage(),"original unlock starts real tween: "+id)
		await _settle(door)
		_check(door.is_ready_for_passage(),"resident waits for real settled leaf: "+id)
		door.npc_set_open(false,id)
		await _settle(door)
		_check(not door.open and door.leaf_state=="locked","original restores lock behind resident: "+id)
		_check(not resident.interact_key(null).is_empty(),"actual resident authorizes copy: "+id)
		var unit: String = str(schedules.residents[id].unit)
		_check(DoorKeyring.book().permissions.has(unit) and not DoorKeyring.player_has_key(door),"permission alone grants no key")
		_check(DoorKeyring.make_copy(unit),"authorized spare made: "+id)
		_check(DoorKeyring.player_has_key(door) and not DoorKeyring.make_copy(unit),"spare works and cannot duplicate")
		_check(not door.interact_key(null).is_empty() and door.leaf_state=="closed","spare unlocks actual owner")
		await _settle(door)
		_check(DoorKeyring.book().originals==originals,"resident retains original after copying")
		# A shared apartment already has one spare; remove that fixture spare so
		# the second co-resident still independently exercises authorization.
		DoorKeyring.book().copies.erase(unit)
		DoorKeyring.book().permissions.erase(unit)
		door.free()
		resident.free()
	var factory := DoorProp.new()
	var index := 0
	for variant: Dictionary in factory.warehouse_variants():
		var door := DoorProp.new()
		door.name = "KeyKind_%d" % index
		for property: String in variant.properties: door.set(property,variant.properties[property])
		if not door.unit.is_empty(): door.unit = "4B"
		add_child(door)
		_check(not door.interact_key(null).is_empty() and door.leaf_state=="locked","kind locks: "+door.door_kind)
		_check(door.interact_key(null).is_empty(),"repeated key press waits for real turn")
		await _settle(door)
		door.interact(null)
		_check(not door.open,"locked kind refuses opening")
		_check(not door.interact_key(null).is_empty(),"kind unlocks: "+door.door_kind)
		await _settle(door)
		door.interact(null)
		_check(door.interact_key(null).is_empty(),"moving leaf cannot be locked")
		await _settle(door)
		_check(door.open and door.interact_key(null).is_empty(),"open leaf cannot be locked")
		door.interact(null)
		await _settle(door)
		_check(not door.interact_key(null).is_empty(),"closed kind locks again")
		await _settle(door)
		door.free()
		index += 1
	factory.free()
	var hero := LandmarkEntryDoor.new()
	add_child(hero)
	_check(not hero.interact_key(null).is_empty() and hero.leaf_state=="locked","landmark inherits lock owner")
	await _settle(hero)
	hero.free()
	var v2 := Node3D.new()
	v2.add_to_group("orison_v2_runtime")
	add_child(v2)
	var news := DoorProp.new()
	news.name = "SITE_SHOP_DOOR_NEWS_CIGARS"
	news.leaf_state = "locked"
	v2.add_child(news)
	_check(news.leaf_state=="closed","V2 News Cigars starts unlocked")
	_check(not news.interact_key(null).is_empty(),"News Cigars may be locked")
	await _settle(news)
	news.free()
	news = DoorProp.new()
	news.name = "SITE_SHOP_DOOR_NEWS_CIGARS"
	v2.add_child(news)
	_check(news.leaf_state=="locked","reconstructed News restores chosen lock")
	v2.free()
	DoorKeyring.book().locks.erase("SITE_SHOP_DOOR_NEWS_CIGARS")
	news = DoorProp.new()
	news.name = "SITE_SHOP_DOOR_NEWS_CIGARS"
	news.leaf_state = "locked"
	add_child(news)
	_check(news.leaf_state=="locked","V1 authored state survives V2 override")
	news.free()
	DoorKeyring.request_copy("mina_vale")
	DoorKeyring.make_copy("2A")
	var snapshot := RealityState.data.duplicate(true)
	_check(RealityState._validate_document(snapshot).ok,"key domain validates in existing save")
	for version in [null,true,"1",2,[],{}]:
		var invalid_version := snapshot.duplicate(true)
		invalid_version.door_keys.version = version
		_check(not RealityState._validate_document(invalid_version).ok,"invalid key-domain version protected")
	for field in ["originals","permissions","copies","locks"]:
		var malformed := snapshot.duplicate(true)
		malformed.door_keys[field] = []
		_check(not RealityState._validate_document(malformed).ok,"malformed field protected: "+field)
	var malformed := snapshot.duplicate(true)
	malformed.door_keys.copies["6D"] = "mina_vale"
	_check(not RealityState._validate_document(malformed).ok,"forged apartment spare protected")
	malformed = snapshot.duplicate(true)
	malformed.door_keys.originals.erase("mina_vale")
	_check(not RealityState._validate_document(malformed).ok,"lost original protected")
	var legacy := snapshot.duplicate(true)
	legacy.erase("door_keys")
	_check(RealityState._validate_document(legacy).ok,"compatible old save may omit key domain")
	RealityState.save_write_blocked = true
	var protected_keys := var_to_bytes(DoorKeyring.book())
	_check(DoorKeyring.request_copy("evelyn_marsh").is_empty() and not DoorKeyring.make_copy("1A"),"read-only state refuses copy changes")
	_check(var_to_bytes(DoorKeyring.book())==protected_keys,"refusal leaves saved keys intact")
	RealityState.save_write_blocked = false
	var previous_path := RealityState.save_path
	RealityState.save_path = SAVE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE).get_base_dir())
	for suffix in ["",".bak",".txn",".tmp"]:
		if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(SAVE+suffix)
	RealityState.persistence_enabled = true
	_check(RealityState.save_game(),"real save writes isolated key snapshot")
	RealityState.data = {}
	RealityState.load_game()
	var restored := DoorKeyring.book()
	for field in ["originals","permissions","copies","locks"]:
		_check(restored.get(field)==snapshot.door_keys[field],"actual storage reload retains "+field)
	_check(int(restored.get("version",0))==1 and int(RealityState.data.version)==RealityState.SAVE_VERSION,"compatible key save version retained")
	RealityState.persistence_enabled = false
	RealityState.save_path = previous_path
	for suffix in ["",".bak",".txn",".tmp"]:
		if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(SAVE+suffix)
	_check(GameBoot.ACTIONS.door_key==KEY_K and GameBoot.JOYPAD_ACTIONS.door_key==JOY_BUTTON_DPAD_UP,"key controls assigned")
	_check(GameBoot.ACTIONS.lamp_toggle==KEY_L and GameBoot.JOYPAD_ACTIONS.jump==JOY_BUTTON_Y,"existing lamp and jump controls retained")
	var asset := preload("res://assets/props/resident_key.glb").instantiate()
	for mesh: MeshInstance3D in asset.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			_check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"key metre UV exported")
			_check(arrays[Mesh.ARRAY_NORMAL].size()==arrays[Mesh.ARRAY_VERTEX].size(),"key normals exported")
			_check(arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"key tangents exported")
	asset.free()
	print("RESIDENT KEYS: %d checks; %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
