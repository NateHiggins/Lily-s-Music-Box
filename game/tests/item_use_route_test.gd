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
