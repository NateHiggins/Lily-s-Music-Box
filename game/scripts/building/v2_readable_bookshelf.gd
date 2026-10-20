extends "res://scripts/props/bookshelf_prop.gd"
## Resident library, physical arrangements and the original durable-save owner.
signal order_changed
const Book := preload("res://scripts/props/v2_readable_book.gd")
const Movable := preload("res://scripts/props/v2_library_movable.gd")
var native_stock: RefCounted
var _books: Dictionary = {}
var _ends: Dictionary = {}
var _library_ids: Array = []
var _hand_node: Node3D
var _hand_tag := ""
var _sashes: Array[Node3D] = []
var _case_record: Dictionary
var _restoring_library := false

func _build_visual() -> void:
	_derive()
	if owner_name.is_empty(): owner_name="Mae Kessler"
	if native_stock==null:
		native_stock=preload("res://scripts/building/v2_readable_library_stock.gd").new()
		if not native_stock.prepare(): push_error("Readable library stock refused");return
	if not sorter.load_library(): return
	sorter.begin(owner_name,.45,hash("shelf:"+owner_name))
	if not canonical_book.is_empty() and not sorter.order.has(canonical_book):
		if sorter.order.is_empty(): sorter.order.append(canonical_book)
		else: sorter.order[0]=canonical_book
	_library_ids=sorter.order.duplicate()
	_case_record=native_stock.data.cases[case_style]
	_fixed=Node3D.new();_fixed.name="FixedCase";add_child(_fixed)
	for identity: String in _case_record.parts:
		var draw: MeshInstance3D=native_stock.draw(_fixed,identity)
		var solid:=StaticBody3D.new();solid.name=identity+"_Body";_fixed.add_child(solid)
		native_stock.collision(solid,identity,Transform3D.IDENTITY)
		preload("res://scripts/props/manipulation_area.gd").install(draw,_case_grip)
	for record: Dictionary in _case_record.doors:
		var sash:=preload("res://scripts/building/v2_library_case_door.gd").new()
		sash.name="PocketCarriage%d"%_sashes.size();sash.shelf=self;sash.stock=native_stock;sash.record=record
		add_child(sash);_sashes.append(sash)
	_books_at=Node3D.new();_books_at.name="Books";add_child(_books_at)
	for identity: String in _library_ids:
		var book:=Book.new()
		book.name="Book_"+identity;book.stock_id=identity;book.shelf=self;book.stock=native_stock;book.entry=sorter.book(identity)
		_books[identity]=book;_books_at.add_child(book)
		book.settled.connect(library_stock_changed.bind(book))
	for side: String in ["left","right"]: _make_end(side)
	_arrange(sorter.order)
	_tap=make_emitter("tick",-26.)
	set_process(false)

func _build_primary_interaction() -> void: pass
func interact_prompt() -> String: return ""
func interact(_player: Node) -> void: pass
func rebuild_books() -> void: pass # A permutation never destroys physical stock.
func close_panel() -> void: pass
func panel_closed() -> void: pass

func _make_end(side: String) -> void:
	var body:=Movable.new()
	body.name="Bookend_"+side;body.stock_id="end_"+side;body.shelf=self
	_books_at.add_child(body)
	var style: String="brass" if unit in ["6C","4A"] else "pressed"
	body.mass=float(native_stock.data.bookends[style].mass_kg)
	for identity: String in native_stock.data.bookends[style].parts:
		var draw: MeshInstance3D=native_stock.draw(body,identity)
		var shape: CollisionShape3D=native_stock.collision(body,identity,Transform3D.IDENTITY)
		if shape!=null: body._solids.append(shape)
		if identity.ends_with("TopReturn"):
			preload("res://scripts/props/manipulation_area.gd").install(draw,func(): return body.turn_grip(Vector3.UP))
	body.set_meta("library_stock_id",body.stock_id)
	body.settled.connect(library_stock_changed.bind(body));_ends[side]=body

func _arrange(order: Array) -> void:
	var tops: Array=_case_record.shelf_tops
	var row:=2 if case_style!="sectional" else 1
	var upright:=order.size() if unit in ["6C","4A"] else maxi(4,order.size()-3)
	var width:=0.0
	for index in upright: width+=float(native_stock.data.books[str(order[index])].thickness)+.003
	var start: float=-width*.5
	var cursor:=start
	var front:=float(_case_record.depth)*.5-.040
	for index in upright:
		var identity:=str(order[index]);var book: Node3D=_books[identity]
		var thickness:=float(native_stock.data.books[identity].thickness)
		book.freeze=true;book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		book.basis=Basis(Vector3.UP,PI*.5)
		book.position=Vector3(cursor+thickness*.5,float(tops[row])+.007,front)
		book._apply_opening(0.);book.freeze=false;book.sleeping=false
		cursor+=thickness+.003
	var height:=float(tops[0])+.001
	for index in range(order.size()-1,upright-1,-1):
		var identity:=str(order[index]);var book: Node3D=_books[identity]
		var dimensions: Dictionary=native_stock.data.books[identity]
		var thickness:=float(dimensions.thickness)
		book.freeze=true;book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		book.basis=Basis(Vector3.BACK,PI*.5)*Basis(Vector3.UP,PI*.5)
		book.position=Vector3(float(dimensions.height)*.5-.03,height+thickness*.5,front)
		book._apply_opening(0.);book.freeze=false;book.sleeping=false
		height+=thickness+.0005
	var style: String="brass" if unit in ["6C","4A"] else "pressed"
	var end_spec: Dictionary=native_stock.data.bookends[style]
	var end_y:=float(tops[row])-float(end_spec.support_y)+.0002
	for side: String in _ends:
		var end: Node3D=_ends[side]
		end.freeze=true;end.linear_velocity=Vector3.ZERO;end.angular_velocity=Vector3.ZERO
		var extra: float=.003 if side=="right" and width<.15 else 0.
		# The return on the hand grip projects 8.3 mm into the L. Keep that
		# folded stock clear of the first binding; place the raised foot edge
		# outside the book's footprint, rather than propping its middle on it.
		end.position=Vector3(start-.011 if side=="left" else cursor+.008,end_y+extra,front-.041 if side=="left" else front-.133)
		end.rotation=Vector3(0,0 if side=="left" else PI,0)
		end.freeze=false;end.sleeping=false

func limit_library_position(value: Vector3) -> Vector3:
	return Vector3(clampf(value.x,-float(_case_record.width)*.5-.16,float(_case_record.width)*.5+.16),
		clampf(value.y,.001,float(_case_record.height)+.35),
		clampf(value.z,-float(_case_record.depth)*.5+.015,.85))

func claim_library_hand(part: Node3D, tag: String) -> bool:
	if is_instance_valid(_hand_node): return false
	_hand_node=part;_hand_tag=tag;return true

func release_library_hand(part: Node3D, changed: bool) -> void:
	if _hand_node!=part: return
	_hand_node=null;_hand_tag=""
	if changed:
		if _tap: _tap.play()
		library_stock_changed(part)

func library_stock_changed(_part: Node3D) -> void:
	if _restoring_library or not is_inside_tree() or is_queued_for_deletion(): return
	var order:=sorter.order.duplicate()
	order.sort_custom(_reading_before)
	if order!=sorter.order: sorter.moves+=1;sorter.order=order
	order_changed.emit()

func _reading_before(first: Variant, second: Variant) -> bool:
	var a: Node3D=_books[str(first)];var b: Node3D=_books[str(second)]
	var row_a:=_nearest_row(a.position.y);var row_b:=_nearest_row(b.position.y)
	if row_a!=row_b: return row_a>row_b
	if absf(a.basis.y.dot(Vector3.UP))<.3 and absf(b.basis.y.dot(Vector3.UP))<.3 and absf(a.position.x-b.position.x)<.05:
		return a.position.y>b.position.y
	return a.position.x<b.position.x

func _nearest_row(y: float) -> int:
	var closest:=0;var distance:=INF
	for index in _case_record.shelf_tops.size():
		var delta:=absf(y-float(_case_record.shelf_tops[index]))
		if delta<distance: closest=index;distance=delta
	return closest

func _case_grip() -> Dictionary:
	return {"owner":self,"part":_fixed,"frame":self,"kind":"slider","axis":Vector3.UP,
		"minimum":0.,"maximum":0.,"read":func(): return 0.,"write":func(_value: float): pass,
		"begin":func(): return claim_library_hand(_fixed,"case"),
		"owns":func(): return _hand_node==_fixed and _hand_tag=="case",
		"end":func(): release_library_hand(_fixed,false)}

func manipulation_target(_hit: Dictionary) -> Dictionary: return _case_grip()

func inspection_view_for(part: Node3D) -> Dictionary:
	var cursor:=part
	while cursor!=null and cursor!=self:
		var identity:=str(cursor.get_meta("library_stock_id",""))
		if _books.has(identity):
			var book: Node3D=_books[identity]
			var spec: Dictionary=native_stock.data.books[identity]
			var point:=book.to_global(Vector3(0,float(spec.height)*.5,0))
			var aspect:=get_viewport().get_visible_rect().size.aspect()
			var distance:=maxf(float(spec.height)*.5,float(spec.width)/aspect)/tan(deg_to_rad(20.))/.88
			var from:=point+book.global_basis.z*distance
			var local:=to_local(from)
			local.z=maxf(local.z,float(_case_record.depth)*.5+.20)
			return {"from":to_global(local),"at":point,"fov":40.}
		cursor=cursor.get_parent() as Node3D
	return inspection_view()

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(0,float(_case_record.height)*.55,1.02)),
		"at":to_global(Vector3(0,float(_case_record.height)*.55,0)),"fov":65.}

func library_snapshot() -> Dictionary:
	var books: Dictionary={};var ends: Dictionary={};var doors: Array=[]
	for identity: String in _books: books[identity]=_books[identity].book_snapshot()
	for side: String in _ends: ends[side]=_ends[side].stock_snapshot()
	for sash: Node3D in _sashes: doors.append(sash.snapshot())
	return {"schema_version":2,"order":sorter.order.duplicate(),"books":books,"bookends":ends,"doors":doors,"moves":sorter.moves}

func valid_library(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=6 or value.get("schema_version")!=2 or value.get("order") is not Array \
		or value.get("books") is not Dictionary or value.get("bookends") is not Dictionary or value.get("doors") is not Array \
		or typeof(value.get("moves")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.moves)) \
		or float(value.moves)<0. or float(value.moves)!=floorf(float(value.moves)): return false
	if not _valid_order(value.order) or value.books.size()!=_books.size() or value.bookends.size()!=2 or value.doors.size()!=_sashes.size(): return false
	for identity: String in _library_ids:
		if not value.books.has(identity) or not Book.valid_book(value.books[identity]): return false
	for side: String in _ends:
		if not value.bookends.has(side) or not Movable.valid_stock(value.bookends[side]): return false
	for index in value.doors.size():
		if not _sashes[index].valid(value.doors[index]): return false
	return true

func _valid_order(value: Variant) -> bool:
	if value is not Array or value.size()!=_library_ids.size(): return false
	var seen: Dictionary={}
	for identity: Variant in value:
		if identity is not String or not _library_ids.has(identity) or seen.has(identity): return false
		seen[identity]=true
	return true

func restore_order(value: Variant) -> void:
	if not (valid_library(value) if value is Dictionary else _valid_order(value)): return
	_restoring_library=true
	_hand_node=null;_hand_tag="";sorter.held=-1
	if value is Array:
		sorter.order=value.duplicate();sorter.moves=0;_arrange(sorter.order)
		for sash: Node3D in _sashes: sash.restore({"angle":0.,"inset":0.})
	else:
		sorter.order=value.order.duplicate();sorter.moves=int(value.moves)
		for identity: String in _library_ids: _books[identity].restore_book(value.books[identity])
		for side: String in _ends: _ends[side].restore_stock(value.bookends[side])
		for index in _sashes.size(): _sashes[index].restore(value.doors[index])
	_restoring_library=false

func inspection_state() -> Dictionary:
	return {"style":case_style,"book_mesh_count":_books.size(),"door_count":_sashes.size(),
		"has_canonical_book":canonical_book.is_empty() or _books.has(canonical_book),
		"individual_books":true,"bookends":_ends.size(),"library_ids":_library_ids.duplicate()}
