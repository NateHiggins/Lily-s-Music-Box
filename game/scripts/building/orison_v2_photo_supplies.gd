extends RefCounted
## What the hand does in Adela's shop: rock the top tray, draw the negatives register across the
## counter, and read the window from the street.

const Clue := preload("res://scripts/props/clue_draw_prop.gd")
const Tray := preload("res://scripts/props/photo_tray.gd")
const PhotoWindow := preload("res://scripts/props/photo_window.gd")
const PICTURE := preload("res://assets/textures/photo/own_plate.png")
const DATA := "res://data/photo_window.json"
const CELL := "shop_photo_supplies"
const PROCESS_MODEL := "res://assets/props/photo_process.glb"
const TRAY_PARTS := {"storm_shop_photo_supplies_dev_tray3__enamel_finish": "enamel_appliance", "storm_shop_photo_supplies_dev_tray3__iron": "iron_blackened"}
const TRAY_LENGTH_SCALE := 0.42
const Carriers := preload("res://scripts/building/orison_v2_clue_carriers.gd")
const BOOK := "minutes"


static func mount(world: Node3D, stock: Variant) -> Dictionary:
	var passage: Node3D = world.passage_region
	var hours: Node = passage.finish.hours_director
	var tray := _tray(passage, hours)
	var register := _register(passage, stock, hours)
	var window := _window(passage)
	if tray == null or register == null or window == null:
		return {}
	return {"tray": tray, "register": register, "window": window}


## The cell's own trays come and go with residency, so the working tray is a separate one, set
## on top of the rack from the same model, and always there for the hand.
static func _tray(passage: Node3D, hours: Node) -> Node3D:
	var packed := ResourceLoader.load(PROCESS_MODEL) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate()
	var prop: Node3D = Tray.new()
	prop.name = "PhotoTray"
	passage.transaction_actor_root().add_child(prop)
	prop.global_transform = passage.global_transform * Transform3D(Basis(), GameBoot.b2g([20.83, -61.67, 0.425]))
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	prop.add_child(pivot)
	var inner := Node3D.new()
	inner.name = "Pan"
	pivot.add_child(inner)
	var drawn := 0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not TRAY_PARTS.has(str(draw.name)):
			continue
		var copy := MeshInstance3D.new()
		copy.name = str(draw.name)
		copy.mesh = draw.mesh
		copy.transform = draw.transform
		copy.material_override = MatLib.get_mat(str(TRAY_PARTS[str(draw.name)]))
		inner.add_child(copy)
		drawn += 1
	model.free()
	if drawn != TRAY_PARTS.size():
		prop.free()
		return null
	Carriers._seat(inner, Vector3(0.5, 0.0, 0.5))
	inner.scale = Vector3(1.0, 1.0, TRAY_LENGTH_SCALE)
	Carriers._seat(inner, Vector3(0.5, 0.0, 0.5))
	prop.configure(pivot, hours, PICTURE)
	return prop


static func _register(passage: Node3D, stock: Variant, hours: Node) -> Node3D:
	var prop: Node3D = Clue.new()
	prop.name = "NegativesRegister"
	passage.transaction_actor_root().add_child(prop)
	prop.global_transform = passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), GameBoot.b2g([18.58, -61.4, 1.45]))
	prop.reach = 0.09
	prop.open_check = func(): return not (hours != null and is_instance_valid(hours) and bool(hours.call("is_after_hours")))
	prop.reader = _read_register
	var moving := Node3D.new()
	moving.name = "Book"
	prop.add_child(moving)
	var inner := Node3D.new()
	inner.basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
	moving.add_child(inner)
	var left := Node3D.new()
	left.transform = stock.left_pose(BOOK, 0.0)
	inner.add_child(left)
	for identity: String in stock.data.books[BOOK].parts:
		var spec: Dictionary = stock.data.parts[identity]
		if not spec.has("render_surface") or bool(spec.render_surface):
			stock.draw(left if str(spec.role) == "left" else inner, identity)
	Carriers._seat(inner, Vector3(0.5, 0.0, 0.5))
	var label := Label3D.new()
	label.name = "Spine"
	label.text = "NEGATIVES"
	label.font = preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
	label.font_size = 28
	label.pixel_size = 0.011 / 28.0
	label.position = Vector3(0.0, 0.0066, 0.075)
	label.modulate = Color(.86, .82, .7)
	moving.add_child(label)
	prop.configure(moving)
	return prop


## The register as it stands today: every entry up to now, newest last. Reading it is
## what the threads wait on.
static func _read_register() -> Dictionary:
	var clock := CampaignClock.new()
	var today := ""
	if clock.bind_state():
		var local := clock.local_datetime()
		if not local.is_empty():
			today = "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var lines: Array[String] = []
	for entry: Dictionary in decoded.register:
		if str(entry.from) <= today:
			lines.append(str(entry.text).to_upper())
			if entry.has("flag"):
				RealityState.grant_knowledge(str(entry.flag))
	RealityState.grant_knowledge("m_register")
	RealityState.commit()
	return {"title": "NEGATIVES REGISTER", "body": "\n".join(lines) if not lines.is_empty() else "NOTHING ENTERED YET.",
		"condition": "READ, NOT SOLD", "stamp": "PHOTO SUPPLIES"}


static func _window(passage: Node3D) -> Node3D:
	var prop: Node3D = PhotoWindow.new()
	prop.name = "PhotoWindow"
	passage.transaction_actor_root().add_child(prop)
	prop.global_transform = passage.global_transform * Transform3D(Basis(Vector3.UP, -PI * 0.5), GameBoot.b2g([17.52, -60.68, 1.22]))
	if not prop.configure():
		prop.free()
		return null
	return prop
