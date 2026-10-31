extends "res://tests/carried_case_route_test.gd"
## Using goods with real input events in the V2 root: a stack carried off the front of
## the shelf is used and one is spent; the last one leaves the case; a thing with no use
## stays in the hand; earplugs lower the mix until they wear off; and a gift moves at a
## door only when its reply is chosen, once a day.

func _init() -> void:
	route_label = "ITEM USE ROUTE"

func _off_front(view: Node) -> Vector2:
	var cell := float(CarriedCase.data().cell)
	return view._camera.unproject_position(Vector3(0.0, 0.0, 0.15 + cell))

func _take_out(view: Node, item: String) -> void:
	var place: Dictionary = CarriedCase.place_of(item)
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	_require(view.held_item == item, "the hand has the " + item)
	await _motion(_off_front(view))
	await _capture_interaction("item_use_" + item)
	await _press(_off_front(view))

func _route() -> void:
	var view: Node = world.carried_case_view
	var uses: ItemUse = view.item_use
	if not _require(uses != null, "item use is mounted"): return
	for i in 2:
		PersonInventory.carry_goods("player", "bar_of_chocolate", "Bar of chocolate", "packet")
	PersonInventory.carry_goods("player", "earplugs_wax_pair", "Earplugs, wax, pair", "tin")
	PersonInventory.carry_goods("player", "padlock", "Padlock", "tin")
	RealityState.commit()
	await _key(KEY_TAB)
	await get_tree().create_timer(0.8).timeout
	_require(view.settled, "the case is open")

	await _take_out(view, "bar_of_chocolate")
	_require(PersonInventory.goods_count("player", "bar_of_chocolate") == 1, "one is eaten")
	_require(view.held_item == "", "the hand is empty after a use")
	_require(CarriedCase.place_of("bar_of_chocolate").size() > 0, "the rest stays on its square")
	await _take_out(view, "bar_of_chocolate")
	_require(PersonInventory.goods_count("player", "bar_of_chocolate") == 0, "the last is eaten")
	_require(CarriedCase.place_of("bar_of_chocolate").is_empty(), "and leaves the case")
	_require(not view._stacks.has("bar_of_chocolate"), "and leaves the shelf")

	await _take_out(view, "padlock")
	_require(view.held_item == "padlock", "a thing with no use stays in the hand")
	_require(PersonInventory.goods_count("player", "padlock") == 1, "and is not spent")
	var padlock: Dictionary = CarriedCase.place_of("padlock")
	await _press(_screen(view, float(padlock.x) + 0.5, float(padlock.y) + 0.5))
	_require(view.held_item == "", "it can go back on the shelf")

	var quiet_before: float = AudioPolicy.mix_snapshot().buses.get("World", 0.0)
	await _take_out(view, "earplugs_wax_pair")
	_require(uses.ears_stopped(), "the ears are stopped")
	var quiet_after: float = AudioPolicy.mix_snapshot().buses.get("World", 0.0)
	_require(quiet_after < quiet_before, "the world goes quieter: %s to %s" % [quiet_before, quiet_after])
	_require(str(view._card.text).contains("EARS STOPPED"), "the card says so")
	_require(ItemUse.valid(RealityState.data[ItemUse.KEY]), "the state stays valid")
	RealityState.data[ItemUse.KEY].ears_until = -1.0
	uses._refresh_ears()
	_require(AudioPolicy.mix_snapshot().buses.get("World", 0.0) >= quiet_before - 0.01, "and they wear off")
	await _capture_interaction("item_use_after")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.6).timeout

	# A gift at a door, through the tree a knock builds.
	var talk: ResidentConversations = world.conversations
	if _require(talk.gifts != null, "gifts are bound"):
		PersonInventory.carry_goods("player", "cigar_nickel", "Cigar, nickel", "box")
		var resident := "omar_bell"
		var door: Dictionary = talk.with_gifts(resident, talk.trees[resident])
		var gift_node := ResidentConversations.GIFT_PREFIX + "cigar_nickel"
		_require(door.nodes.has(gift_node), "the door offers the gift")
		_require(PersonInventory.goods_count("player", "cigar_nickel") == 1, "offering it spends nothing")
		talk._record(resident, gift_node, 0)
		_require(PersonInventory.goods_count("player", "cigar_nickel") == 0, "choosing it gives it")
		PersonInventory.carry_goods("player", "cigar_nickel", "Cigar, nickel", "box")
		_require(talk.gifts.offers(resident).is_empty(), "and only one a day")
		_require(not talk.gifts.offers("iris_bell").is_empty(), "another resident can still get one")
		_require(ResidentGifts.valid(RealityState.data[ResidentGifts.KEY]), "gifts stay valid")

func _run() -> void:
	if OS.get_environment("ORISON_CASE_RETIREMENT_ONLY")!="1":
		await super._run()
		return
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	player=PlayerController.new();add_child(player)
	player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	PersonInventory.carry_goods("player","bar_of_chocolate","Bar of chocolate","packet")
	var view:=preload("res://scripts/ui/carried_case_view.gd").new()
	view.player=player;add_child(view)
	var cycles: Array=[]
	for cycle in 2:
		await _key(KEY_TAB)
		await get_tree().create_timer(.6).timeout
		_require(view.opened and view.settled,"isolated case opens through its actual key input")
		var templates: Array[WeakRef]=[]
		var parented:=true
		for form: Array in view._forms.values():
			for draw: MeshInstance3D in form:
				templates.append(weakref(draw))
				parented=parented and draw.get_parent()!=null and draw.is_inside_tree()
		_require(not templates.is_empty() and parented,"native form templates retain a scene-tree lifetime owner")
		_require(view._stacks.has("bar_of_chocolate") and view._stacks["bar_of_chocolate"].is_visible_in_tree(),"real goods remain visible independently of hidden templates")
		if cycle==0:
			await RenderingServer.frame_post_draw
			var dir:=OS.get_environment("SHOT_DIR")
			if not dir.is_empty():
				DirAccess.make_dir_recursive_absolute(dir)
				get_viewport().get_texture().get_image().save_png(dir.path_join("case_open.png"))
			await _key(KEY_TAB)
			await get_tree().create_timer(.5).timeout
			_require(not view.opened and not player.call_locked,"actual close input releases player ownership")
		else:
			# Owner retirement while open must also reclaim its private geometry.
			view.free()
		for tick in 3:await get_tree().process_frame
		var survivors:=0
		for ref: WeakRef in templates:
			var draw: Node=ref.get_ref()
			if is_instance_valid(draw):
				survivors+=1
				# Cleanup only the demonstrated orphan on the failing control.
				if draw.get_parent()==null:draw.free()
		_require(survivors==0,"all form templates retire after close or owner destruction")
		cycles.append({"cycle":cycle,"templates":templates.size(),"parented":parented,"survivors":survivors})
	player.free()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("case_retirement.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated actual case key-open/close, visible seeded goods, and open-owner retirement. No composed-world,save or artistic acceptance.","cycles":cycles,"checks":interaction_checks,"failures":failures},"\t"))
	print("CASE RETIREMENT: ",interaction_checks.size()," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
