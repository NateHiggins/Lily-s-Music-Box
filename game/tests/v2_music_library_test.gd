extends Node
## The earned music library in V2 (v1r_music_director_20261109): a resident's
## records join the library when their case settles, their favourite goes out
## on the house broadcast as a dedication, a library record is a request every
## switched-on set plays from its first bar, and the resident talks about the
## favourite while it can be heard.
const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")
const RadioProp := preload("res://scripts/building/orison_v2_radio_prop.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	Broadcast.reset_for_test()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var library: Node = world.get("music_library")
	_check(library != null and library.is_in_group("music_director"), "V2 composes the earned library")
	if library == null:
		_finish(world)
		return
	_check(library.library() == ["am_maintenance"], "a new campaign holds the one first record (%s)" % [library.library()])
	_check(world.conversations.music == library, "resident conversations know the library")

	# A resident with records still to share, and the player's own set.
	var catalog: Dictionary = library.catalog
	var case_id := ""
	var resident_id := ""
	for candidate: String in RealityCases.definitions:
		var who := str(RealityCases.definition(candidate).get("resident_id", ""))
		var likes: Array = catalog.get("residents", {}).get(who, {}).get("likes", [])
		if likes.size() > 1 and world.conversations.has_tree(who):
			case_id = candidate
			resident_id = who
			break
	_check(case_id != "", "a case resident has records to share and a V2 conversation tree")
	var radio: Node = null
	for node in world.find_children("*", "", true, false):
		if node.get_script() == RadioProp and str(node.get("unit")) == "4B":
			radio = node
	_check(radio != null, "the player's flat has a household set")
	if case_id == "" or radio == null:
		_finish(world)
		return
	var resident: Dictionary = catalog.residents[resident_id]
	var favorite := str(resident.favorite)
	var favorite_track: Dictionary = catalog.tracks[favorite]

	_check(not library.play_track(favorite), "a record nobody has shared is refused")
	if radio.powered:
		radio.interact()
	radio.interact()
	_check(radio.powered and Broadcast.listeners().size() == 1, "one set is on the air")
	_check(library.on_air_track() == "pull_up_a_chair", "the station opens its own running order (%s)" % library.on_air_track())
	_check(library.conversation_topic(resident_id).is_empty(), "no favourite on the air, nothing to say about it")

	# The case settles through the case manager's own lifecycle.
	_check(_resolve(case_id), "%s's case resolves through RealityCases" % resident_id)
	var held: Array = library.library()
	var all_shared := true
	for track_id in resident.likes:
		all_shared = all_shared and track_id in held
	_check(all_shared, "%s's records join the library (%s)" % [resident_id, held])
	_check(str(Broadcast.now_playing().get("id", "")) == favorite, "the favourite goes out as a dedication")
	var programme: AudioStreamPlayer3D = radio._programme
	_check(programme.stream == load(str(favorite_track.path)) and programme.playing,
		"the switched-on set plays the dedication")
	_check(programme.get_playback_position() < 1.0, "from its first bar (%.2f s)" % programme.get_playback_position())
	_check(Broadcast.on_air(programme) == str(favorite_track.title), "the set reports the record (%s)" % Broadcast.on_air(programme))

	# The resident talks about it while it can be heard, in their own tree.
	var topic: Dictionary = library.conversation_topic(resident_id)
	_check(not topic.is_empty() and str(topic.get("line", "")).contains(str(resident.anecdote)), "the favourite on the air is a topic")
	_check(str(topic.get("line", "")).contains(str(resident.gift_line)), "a settled case adds what they gave")
	var tree: Dictionary = world.conversations.with_music(resident_id, world.conversations.trees[resident_id])
	var node_id := "music:" + favorite
	_check(tree.nodes.has(node_id), "their conversation tree offers the record")
	var offered := false
	for entry: Variant in tree.entries.values():
		for choice: Dictionary in tree.nodes.get(str(entry), {}).get("choices", []):
			offered = offered or str(choice.get("goto", "")) == node_id
	_check(offered, "a door of the tree leads to it")
	world.conversations._record(resident_id, node_id, 0)
	_check("%s:%s" % [resident_id, favorite] in RealityState.data.heard_music_anecdotes, "hearing it is remembered")
	_check(not RealityState.has_knowledge(node_id), "and is not filed as case knowledge")
	radio.interact()
	_check(not radio.powered and library.conversation_topic(resident_id).is_empty(), "with no set on there is nothing to talk about")
	radio.interact()

	# A request from the library, through the player's own panel and action.
	var other := ""
	for track_id in held:
		if str(track_id) != favorite:
			other = str(track_id)
	_check(library._available(), "the player can open the library with free hands")
	var press := InputEventAction.new()
	press.action = "music_player"
	press.pressed = true
	Input.parse_input_event(press)
	for i in 3: await get_tree().process_frame
	_check(library.opened and world.player.call_locked, "the music-player action opens it and holds the player")
	var button := library._track_list.get_node_or_null("Record_" + other) as Button
	_check(button != null and library._track_list.get_child_count() == held.size(), "it lists every record held (%d)" % library._track_list.get_child_count())
	if button != null:
		button.pressed.emit()
	_check(str(Broadcast.now_playing().get("id", "")) == other, "choosing a record asks the station for it")
	_check(programme.stream == load(str(catalog.tracks[other].path)) and programme.get_playback_position() < 1.0,
		"and the set plays it from its first bar")
	Input.parse_input_event(press)
	for i in 3: await get_tree().process_frame
	_check(not library.opened and not world.player.call_locked, "the same action closes it and frees the player")
	_check(RealityState.data.music_library == held, "the library is campaign state")
	radio.interact()
	_finish(world)


func _resolve(case_id: String) -> bool:
	var def := RealityCases.definition(case_id)
	if not RealityCases.activate_case(case_id):
		return false
	for repair in int(def.get("repairs_required", 2)):
		if repair > 0 and not RealityCases.reopen_case(case_id):
			return false
		if not RealityCases.stabilize_case(case_id):
			return false
	var flags: Array = def.get("resolution_flags", [])
	if flags.is_empty():
		flags = ["heard"]
	for flag in flags:
		RealityCases.record_conversation(case_id, str(flag))
	return RealityCases.resolve_case(case_id)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 MUSIC LIBRARY] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
