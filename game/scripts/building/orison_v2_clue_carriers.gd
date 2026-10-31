extends RefCounted
## The clues the world holds out to the hand. Jonah's composition books lie on his case, dated
## on their spines. The yard drain's clean-out comes through the boiler room wall, because the
## yard itself isn't built; the 7 August work order sends the player to it.

const Clue := preload("res://scripts/props/clue_draw_prop.gd")
const Fire := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const SHELF := "F06_6B_BOOKSHELF_01"
const SWITCH := "B1_BOILER_ROOM_SWITCH"
const BOOK := "minutes"
# Bottom to top, with the day each exists from.
const SPINES := [["3 March", ""], ["19 July", "1929-07-20"], ["6 Aug.", "1929-08-06"]]


static func mount(world: Node3D, adapter: Variant) -> Dictionary:
	var shelf: Node3D = adapter.resolve(SHELF)
	var switch: Node3D = adapter.resolve(SWITCH)
	if shelf == null or switch == null:
		return {}
	var books := _notebooks(world, shelf)
	var drain := _clean_out(world, switch)
	if books == null or drain == null:
		return {}
	return {"notebooks": books, "drain": drain}


static func _notebooks(world: Node3D, shelf: Node3D) -> Node3D:
	var stock: Variant = null
	for candidate: Node in [shelf] + shelf.get_children():
		if candidate.get("native_stock") != null:
			stock = candidate.get("native_stock")
	if stock == null:
		return null
	var prop: Node3D = Clue.new()
	prop.name = "JonahCompositionBooks"
	world.add_child(prop)
	prop.global_transform = shelf.global_transform * Transform3D(Basis(), Vector3(0.1, 1.3, 0.0))
	prop.reach = 0.08
	prop.from_date = "1929-07-20"
	prop.flag = "m_notebook_spine"
	prop.note = {"title": "6B, TOP OF THE CASE", "body": "COMPOSITION BOOK. SPINE: 19 JULY. HIS HAND. HE DATES THEM.",
		"condition": "READ", "stamp": "SERVICE NOTE"}
	var moving: Node3D = null
	for index in SPINES.size():
		var book := Node3D.new()
		book.name = "Book_" + str(index)
		book.position = Vector3(0.0, index * 0.0142, 0.12)
		book.set_meta("from_date", str(SPINES[index][1]))
		prop.add_child(book)
		# A closed book stands with its spine along Y. Laid flat, spine to the room.
		var inner := Node3D.new()
		inner.basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
		book.add_child(inner)
		var left := Node3D.new()
		left.transform = stock.left_pose(BOOK, 0.0)
		inner.add_child(left)
		for identity: String in stock.data.books[BOOK].parts:
			var spec: Dictionary = stock.data.parts[identity]
			if not spec.has("render_surface") or bool(spec.render_surface):
				stock.draw(left if str(spec.role) == "left" else inner, identity)
		_seat(inner, Vector3(0.5, 0.0, 1.0))
		var label := Label3D.new()
		label.name = "Spine"
		label.text = str(SPINES[index][0])
		label.font = FONT
		label.font_size = 28
		label.pixel_size = 0.01 / 28.0
		label.position = Vector3(0.0, 0.0066, 0.002)
		label.modulate = Color(.86, .82, .7)
		label.outline_size = 6
		label.outline_modulate = Color(.05, .04, .03)
		book.add_child(label)
		if index == 1:
			moving = book
	prop.configure(moving)
	refresh_spines(prop)
	return prop


## Moves a part so the given fraction of its drawn bounds sits at its parent's origin:
## 0.5 centres an axis, 0.0 puts the low face there and 1.0 the high face.
static func _seat(inner: Node3D, fraction: Vector3) -> void:
	var bounds := AABB()
	var first := true
	for draw: Node in inner.find_children("*", "MeshInstance3D", true, false):
		var from_parent := inner.transform * (inner.global_transform.affine_inverse() * (draw as Node3D).global_transform)
		var box := from_parent * (draw as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	inner.position -= bounds.position + bounds.size * fraction


## A book isn't on the stack before the day it was begun.
static func refresh_spines(prop: Node3D) -> void:
	var clock := CampaignClock.new()
	if not clock.bind_state():
		return
	var local := clock.local_datetime()
	if local.is_empty():
		return
	var today := "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]
	for book: Node in prop.get_children():
		if book.has_meta("from_date"):
			book.visible = str(book.get_meta("from_date")) <= today


static func _clean_out(world: Node3D, switch: Node3D) -> Node3D:
	var stock := Fire.new()
	if not stock.load_stock():
		return null
	var prop: Node3D = Clue.new()
	prop.name = "YardDrainCleanOut"
	world.add_child(prop)
	# Low on the switch's wall, facing the room, which lies to the world's -Z.
	prop.global_transform = Transform3D(Basis(Vector3.UP, PI), switch.global_position + Vector3(-0.3, -0.8, 0.0))
	prop.reach = 0.09
	prop.from_date = "1929-08-07"
	prop.flag = "m_glove_scrap"
	prop.goods = {"id": "glove_scrap", "name": "Glove scrap, wet", "form": "card"}
	prop.note = {"title": "YARD DRAIN, CLEAN-OUT", "body": "TRAP CLEARED. SCRAP OF WHITE KID, A PEARL BUTTON ON A SHANK. WET. KEPT.",
		"condition": "CLEARED", "stamp": "WORK ORDER"}
	var plug := Node3D.new()
	plug.name = "Plug"
	prop.add_child(plug)
	var inner := Node3D.new()
	inner.basis = Basis(Vector3.RIGHT, PI * 0.5)
	inner.scale = Vector3.ONE * 3.0
	plug.add_child(inner)
	stock.draw(inner, "Tin")
	stock.draw(inner, "Gasket")
	_seat(inner, Vector3(0.5, 0.5, 0.0))
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "YARD DRAIN"
	tag.font = FONT
	tag.font_size = 32
	tag.pixel_size = 0.024 / 32.0
	tag.position = Vector3(0.0, 0.13, 0.01)
	tag.modulate = Color(.8, .76, .64)
	tag.outline_size = 6
	tag.outline_modulate = Color(.04, .03, .02)
	prop.add_child(tag)
	prop.configure(plug)
	return prop
