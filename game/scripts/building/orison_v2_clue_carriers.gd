extends RefCounted
## The clues the world holds out to the hand. Jonah's composition books lie on his case, dated
## on their spines. The yard drain's clean-out comes through the boiler room wall, because the
## yard itself isn't built; the 7 August work order sends the player to it.

const Clue := preload("res://scripts/props/clue_draw_prop.gd")
const Fire := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const SHELF := "F06_6B_BOOKSHELF_01"
const SWITCH := "B1_BOILER_ROOM_SWITCH"
const JUNO_SHELF := "F02_2C_BOOKSHELF_01"
const KEY_BOOK_DESK := "4B_terminal_desk"
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
	var sheet := _boiler_sheet(world, switch)
	var juno_shelf: Node3D = adapter.resolve(JUNO_SHELF)
	if books == null or drain == null or sheet == null or juno_shelf == null:
		return {}
	# Measure the stock once, before mounting either movable carrier.
	var shelf_bounds := _shelf_bounds(juno_shelf)
	if not shelf_bounds.has_volume():
		return {}
	var disc := _disc_twelve(world, juno_shelf, shelf_bounds)
	if _trade_log(world, juno_shelf, shelf_bounds) == null:
		return {}
	var stock: Variant = books.get_meta("stock")
	var key_book := _desk_key_book(world, adapter.resolve(KEY_BOOK_DESK) as Node3D, stock)
	if key_book == null:
		return {}
	return {"notebooks": books, "drain": drain, "boiler_sheet": sheet, "disc_twelve": disc,
		"key_book": key_book, "book_stock": stock}


static func _desk_key_book(world: Node3D, desk: Node3D, stock: Variant) -> Node3D:
	if desk == null:
		return null
	var top := desk.find_child("4B_terminal_desk__oak_work_surface", true, false) as MeshInstance3D
	if top == null:
		return null
	var box := top.transform * top.get_aabb()
	var prop: Node3D = Clue.new()
	prop.name = "NightManKeyBook"
	world.add_child(prop)
	prop.global_transform = desk.global_transform * Transform3D(Basis.IDENTITY,
			Vector3(box.position.x + .10, box.end.y + .002, box.end.z - .15))
	prop.reach = .08
	prop.reader = Callable(world.temporal_loop, "read_key_book")
	var book := Node3D.new()
	book.name = "Ledger"
	prop.add_child(book)
	_closed_book(book, stock, Basis(Vector3.RIGHT, -PI * .5), Vector3(.5, 0, .5))
	_cover_title(book, stock, "KEY BOOK")
	prop.configure(book)
	return prop


static func _notebooks(world: Node3D, shelf: Node3D) -> Node3D:
	var stock: Variant = _book_stock(shelf)
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
		_closed_book(book, stock, Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.5, 0.0, 1.0))
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
	prop.set_meta("stock", stock)
	refresh_spines(prop)
	return prop


static func _book_stock(shelf: Node3D) -> Variant:
	for candidate: Node in [shelf] + shelf.get_children():
		var stock: Variant = candidate.get("native_stock")
		if stock != null:
			return stock
	return null


static func _closed_book(parent: Node3D, stock: Variant, facing: Basis, seat: Vector3) -> void:
	var inner := Node3D.new()
	inner.basis = facing
	parent.add_child(inner)
	var left := Node3D.new()
	left.transform = stock.left_pose(BOOK, 0.0)
	inner.add_child(left)
	for identity: String in stock.data.books[BOOK].parts:
		var spec: Dictionary = stock.data.parts[identity]
		if not spec.has("render_surface") or bool(spec.render_surface):
			stock.draw(left if str(spec.role) == "left" else inner, identity)
	_seat(inner, seat)


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
	prop.note = {"title": "YARD DRAIN, CLEAN-OUT", "body": "TRAP CLEARED. SCRAP OF WHITE KID, A PEARL BUTTON ON A SHANK. WET. KEPT. LOOK ON THE ASH CAN.",
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


## The boiler sheet (carriers.json m_boiler_sheet): the week's firing jobs pinned beside the boiler room
## switch, with the ash pit raked on Monday 23 Sept. Drawn off its nail from that day, it gives the lead
## "What's in the ash pit?" (Omar Bell, B21).
static func _boiler_sheet(world: Node3D, switch: Node3D) -> Node3D:
	var prop: Node3D = Clue.new()
	prop.name = "BoilerSheet"
	world.add_child(prop)
	# On the switch's wall at eye height, on the open side away from the column, facing the room (world -Z).
	prop.global_transform = Transform3D(Basis(Vector3.UP, PI), switch.global_position + Vector3(-0.42, 0.05, 0.0))
	prop.reach = 0.08
	prop.from_date = "1929-09-23"
	prop.flag = "m_boiler_sheet"
	prop.note = {"title": "BOILER ROOM, B1", "body": "FIRING SHEET. RAKE ASH PIT MON. 23 SEPT., 8 A.M. SOMEBODY HAS UNDERLINED IT.",
		"condition": "READ", "stamp": "SERVICE NOTE"}
	var sheet := Node3D.new()
	sheet.name = "Sheet"
	sheet.position = Vector3(0.0, 0.0, 0.004)
	prop.add_child(sheet)
	var paper := BoxMesh.new()
	paper.size = Vector3(0.21, 0.28, 0.0015)
	paper.material = MatLib.get_mat("paper", Color(0.90, 0.86, 0.76))
	var page := MeshInstance3D.new()
	page.name = "Page"
	page.mesh = paper
	sheet.add_child(page)
	var pin := MeshInstance3D.new()
	pin.name = "Nail"
	var head := CylinderMesh.new()
	head.top_radius = 0.004
	head.bottom_radius = 0.004
	head.height = 0.004
	head.radial_segments = 10
	head.material = MatLib.get_mat("brass_dull", Color(0.55, 0.50, 0.42))
	pin.mesh = head
	pin.rotation.x = PI * 0.5
	pin.position = Vector3(0.0, 0.125, 0.003)
	sheet.add_child(pin)
	var lines := [["FIRING SHEET", 30, 0.105], ["Bank fire nightly 11 p.m.", 22, 0.06], ["Blow down Thurs.", 22, 0.03],
		["Rake ash pit", 24, -0.01], ["Mon. 23 Sept., 8 a.m.", 24, -0.04]]
	for row: Array in lines:
		var label := Label3D.new()
		label.name = "Line"
		label.text = str(row[0])
		label.font = FONT
		label.font_size = int(row[1])
		# About 13 mm a capital: readable from a step back, as a pinned firing sheet is.
		label.pixel_size = 0.0006
		label.position = Vector3(0.0, float(row[2]), 0.0009)
		label.modulate = Color(.14, .12, .10)
		label.outline_size = 0
		sheet.add_child(label)
	var underline := MeshInstance3D.new()
	underline.name = "Underline"
	var stroke := BoxMesh.new()
	stroke.size = Vector3(0.15, 0.0025, 0.0005)
	stroke.material = MatLib.get_mat("enamel", Color(0.14, 0.12, 0.10))
	underline.mesh = stroke
	underline.position = Vector3(0.0, -0.056, 0.0011)
	sheet.add_child(underline)
	prop.configure(sheet)
	# The switch's origin is not the wall face: once the walls are in the physics world, seat the sheet on the face.
	prop.get_tree().physics_frame.connect(_seat_on_wall.bind(prop), CONNECT_ONE_SHOT)
	return prop


static func _shelf_bounds(shelf: Node3D) -> AABB:
	var first := true
	var box := AABB()
	for draw: Node in [shelf] + shelf.find_children("*", "MeshInstance3D", true, false):
		if draw is not MeshInstance3D:
			continue
		var part: AABB = (shelf.global_transform.affine_inverse() * (draw as MeshInstance3D).global_transform) * (draw as MeshInstance3D).get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## B19: Juno records the Saturday exchange in her own notebook. The separate
## sleeve still carries Cal's playback lead. Keep the two physical readers apart.
static func _trade_log(world: Node3D, shelf: Node3D, box: AABB) -> Node3D:
	var stock: Variant = _book_stock(shelf)
	if stock == null:
		return null
	var prop: Node3D = Clue.new()
	prop.name = "JunoTradeLog"
	world.add_child(prop)
	prop.global_transform = shelf.global_transform * Transform3D(Basis.IDENTITY,
		Vector3(box.position.x + 0.10, box.end.y + 0.002, box.end.z - 0.115))
	prop.reach = 0.08
	prop.from_date = "1929-08-24"
	prop.flag = "m_trade_log"
	prop.note = {"title": "2C, JUNO'S TRADE LOG",
		"body": "SAT. 24 AUG., 3 P.M., C.D.: WLBQ 12 AND 19 JULY.",
		"condition": "READ", "stamp": "SERVICE NOTE"}
	var book := Node3D.new()
	book.name = "Notebook"
	prop.add_child(book)
	_closed_book(book, stock, Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.5, 0, 0.5))
	_cover_title(book, stock, "TRADE LOG")
	prop.configure(book)
	return prop


static func _cover_title(book: Node3D, stock: Variant, caption: String) -> void:
	var title := Label3D.new()
	title.name = "Title"
	title.text = caption
	title.font = FONT
	title.font_size = 30
	title.pixel_size = 0.0005
	title.rotation.x = -PI * 0.5
	title.position = Vector3(0, float(stock.data.books[BOOK].thickness) + 0.002, 0)
	title.modulate = Color(0.88, 0.81, 0.65)
	title.outline_size = 0
	book.add_child(title)


## Juno's twelfth disc (carriers.json m_drama_lead): the session she cut through the wall of 2C on Saturday 24 Aug.,
## in its paper sleeve on top of her bookcase, pencilled on the sleeve. Drawn off the case from that day, it gives
## the lead Cal Dwyer's "Play me the twelfth" needs, so the playback thread no longer waits on Juno's one line.
static func _disc_twelve(world: Node3D, shelf: Node3D, box: AABB) -> Node3D:
	var top := box.end.y
	var front := box.end.z
	var centre := box.get_center()
	var prop: Node3D = Clue.new()
	prop.name = "JunoDiscTwelve"
	world.add_child(prop)
	# Lying on the top of the case, a little over its front edge, so the hand can draw it out toward the room.
	prop.global_transform = shelf.global_transform * Transform3D(Basis(Vector3.UP, 0.35), Vector3(centre.x + 0.05, top + 0.002, front - 0.06))
	prop.axis = Vector3.BACK
	prop.reach = 0.10
	prop.from_date = "1929-08-24"
	prop.flag = "m_drama_lead"
	prop.note = {"title": "2C, ON THE BOOKCASE", "body": "DISC 12. THE WALL. SAT. 24 AUG., 3 P.M. IN PENCIL: THERE'S A CLOCK ON THIS. WHOSE? ASK CAL, 5B. HE WILL WANT A CHAIR.",
		"condition": "READ", "stamp": "SERVICE NOTE"}
	var sleeve := Node3D.new()
	sleeve.name = "Sleeve"
	prop.add_child(sleeve)
	var paper := BoxMesh.new()
	paper.size = Vector3(0.262, 0.0024, 0.262)
	paper.material = MatLib.get_mat("paper", Color(0.86, 0.80, 0.66))
	var cover := MeshInstance3D.new()
	cover.name = "Cover"
	cover.mesh = paper
	cover.position = Vector3(0.0, 0.0012, 0.0)
	sleeve.add_child(cover)
	# The disc half out of its sleeve, shellac black.
	var shellac := CylinderMesh.new()
	shellac.top_radius = 0.127
	shellac.bottom_radius = 0.127
	shellac.height = 0.0018
	shellac.radial_segments = 48
	shellac.material = MatLib.get_mat("bakelite_black")
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	disc.mesh = shellac
	disc.position = Vector3(-0.07, 0.0009, 0.0)
	sleeve.add_child(disc)
	var lines := [["DISC 12", 34, 0.07], ["the wall", 26, 0.035], ["Sat. 24 Aug.", 26, 0.0], ["3 p.m.", 26, -0.035], ["a CLOCK?", 30, -0.075]]
	for row: Array in lines:
		var label := Label3D.new()
		label.name = "Pencil"
		label.text = str(row[0])
		label.font = FONT
		label.font_size = int(row[1])
		label.pixel_size = 0.0006
		label.rotation.x = -PI * 0.5
		label.position = Vector3(0.03, 0.0026, -float(row[2]))
		label.modulate = Color(.22, .21, .22)
		label.outline_size = 0
		sleeve.add_child(label)
	prop.configure(sleeve)
	return prop


static func _seat_on_wall(prop: Node3D) -> void:
	if not is_instance_valid(prop) or not prop.is_inside_tree():
		return
	var out: Vector3 = prop.global_basis.z.normalized()
	var space := prop.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(prop.global_position + out * 0.3, prop.global_position - out * 0.3, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		prop.global_position = hit.position
