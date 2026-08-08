class_name BookshelfProp
extends FunctionalProp
## Somebody's bookshelf, built from their actual books.
##
## Every spine here is a real entry in library.json: its height is the
## height in millimetres, its colour is the hue on the record, and its
## place on the shelf is where the owner's scheme puts it. So the shelf
## you look at IS the shelf you sort — walk past Iris's and you can see
## the gradient from the door, walk past Malcolm's and you can see that
## nobody has ever tried.
##
## The books are rebuilt whenever the order changes, which is what makes
## tidying one legible: you put a book back and the wall changes.

const SHELF_W := 0.055           # depth the spines sit proud of the back

var owner_name := ""
var sorter := ShelfSort.new()

var _panel: Node
var _books_at: Node3D
var _case_w := 0.36
var _tap: AudioStreamPlayer3D


func _build_visual() -> void:
	if owner_name == "":
		owner_name = "Mae Kessler"
	sorter.load_library()
	# Deterministic per owner, and left in the state neglect has got it
	# to — a shelf is the same shelf every time you walk past it.
	sorter.begin(owner_name, 0.45, hash("shelf:" + owner_name))
	_case_w = maxf(0.30, _run_width() + 0.05)

	var oak := Color(0.32, 0.21, 0.12)
	var h := 0.50
	var d := 0.22
	# Carcass: two sides, a top, a bottom, one shelf, a thin back.
	for s in [-1.0, 1.0]:
		make_box(Vector3(0.018, h, d),
				Vector3(s * (_case_w * 0.5 + 0.009), h * 0.5, 0.0), oak)
	make_box(Vector3(_case_w + 0.036, 0.018, d),
			Vector3(0, h - 0.009, 0), oak)
	make_box(Vector3(_case_w + 0.036, 0.018, d), Vector3(0, 0.009, 0), oak)
	make_box(Vector3(_case_w, 0.014, d), Vector3(0, 0.255, 0), oak)
	make_box(Vector3(_case_w + 0.036, h, 0.010),
			Vector3(0, h * 0.5, -d * 0.5), oak.darkened(0.25))
	# A brass card on the top rail, because everything in this building
	# is labelled by somebody who cared.
	var card := make_box(Vector3(0.09, 0.018, 0.004),
			Vector3(0, h + 0.014, d * 0.5 - 0.004),
			Color(0.66, 0.53, 0.26))
	var cm := card.material_override as StandardMaterial3D
	cm.metallic = 0.6
	cm.roughness = 0.4

	_books_at = Node3D.new()
	_books_at.name = "Books"
	add_child(_books_at)
	rebuild_books()
	_tap = make_emitter("tick", -18.0)


func _book_w(id: String) -> float:
	# A spine's thickness. Not in the data — it is the one dimension
	# nobody records about a book — so it is derived from the id, which
	# at least keeps it the same book every time.
	return 0.019 + float(absi(id.hash()) % 21) * 0.001


func _run_width() -> float:
	var w := 0.0
	for id in sorter.order:
		w += _book_w(str(id)) + 0.002
	return w


## Lay the spines out left to right in the order the shelf is currently
## in, with the one in your hand simply absent — which is the gap.
func rebuild_books() -> void:
	if _books_at == null:
		return
	for c in _books_at.get_children():
		c.queue_free()
	var x := -_run_width() * 0.5
	for i in sorter.order.size():
		var id := str(sorter.order[i])
		var b: Dictionary = sorter.book(id)
		var w := _book_w(id)
		if i == sorter.held:
			x += w + 0.002        # out of the shelf: leave the gap
			continue
		var hh: float = clampf(float(b.get("height", 200)) / 1000.0,
				0.10, 0.24)
		var hue: float = float(b.get("hue", 0)) / 360.0
		# Old cloth and board: desaturated, and darker the taller it is,
		# so a shelf reads as books rather than as a colour chart.
		var col := Color.from_hsv(hue, 0.42, 0.52 - hh * 0.4)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, hh, SHELF_W * 2.6)
		mi.mesh = bm
		mi.position = Vector3(x + w * 0.5, 0.018 + hh * 0.5, 0.02)
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.86
		mi.material_override = m
		_books_at.add_child(mi)
		# The last one leans into the space, the way the last one does.
		if i == sorter.order.size() - 1 and sorter.order.size() > 2:
			mi.rotation.z = deg_to_rad(7.5)
			mi.position.x -= 0.006
		x += w + 0.002


func interact_prompt() -> String:
	var sh := sorter.shelf_of(owner_name)
	if sorter.is_tidy():
		return "[E]  %s's books  —  in order" % owner_name.split(" ")[0]
	return "[E]  %s's books  —  wants tidying" % owner_name.split(" ")[0]


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _tap:
		_tap.play()
	var scr: GDScript = load("res://scripts/ui/bookshelf_panel.gd")
	_panel = scr.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null
	rebuild_books()
