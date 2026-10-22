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
var _inspection_stock: Node3D
var _pending_inspection_stock: Node3D
var book_slots: Array[Transform3D] = []

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
	_decorate()
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
		if identity.ends_with("__Foot") or identity.ends_with("__Felt"): continue
		var shape: CollisionShape3D=native_stock.collision(body,identity,Transform3D.IDENTITY)
		if shape!=null: body._solids.append(shape)
	var bearing: Dictionary=native_stock.bookend_bearing(style)
	var sole:=CollisionShape3D.new();sole.name="BondedFootBearing"
	sole.shape=bearing.shape;sole.transform=bearing.pose
	body.add_child(sole);body._solids.append(sole)
	body.set_meta("library_stock_id",body.stock_id)
	body.settled.connect(library_stock_changed.bind(body));_ends[side]=body

func _arrange(order: Array) -> void:
	var restoring_before:=_restoring_library
	_restoring_library=true
	book_slots.clear()
	var tops: Array=_case_record.shelf_tops
	var row:=2 if case_style!="sectional" else 1
	var upright:=order.size() if unit in ["6C","4A"] else maxi(4,order.size()-3)
	var width:=0.0

	for index in upright:
		var size: Dictionary=native_stock.data.books[str(order[index])]
		var lean:=.085 if index==upright-1 else 0.
		width+=float(size.thickness)*cos(lean)+float(size.height)*sin(lean)+.003
	var widest:=0.0
	for index in upright: widest=maxf(widest,float(native_stock.data.books[str(order[index])].width))
	var start: float=-width*.5
	var cursor:=start
	var front:=float(_case_record.depth)*.5-.012
	var style: String="brass" if unit in ["6C","4A"] else "pressed"
	var end_spec: Dictionary=native_stock.data.bookends[style]
	var end_y:=float(tops[row])-float(end_spec.support_y)+.00035
	var heel: AABB=native_stock._bounds(["bookend_"+style+"__FloorReturn"])
	for side: String in _ends:
		var end: Node3D=_ends[side]
		end.freeze=true;end.linear_velocity=Vector3.ZERO;end.angular_velocity=Vector3.ZERO
		# The return on the hand grip projects 8.3 mm into the L. Keep that
		# folded stock clear of the first binding. The broad foot carries
		# adjacent bindings; their authored bearings below include its height.
		end.position=Vector3(start-.011 if side=="left" else start+width+.008,end_y,front+.00155-heel.position.z if side=="left" else front-widest-.00335+heel.position.z)
		end.rotation=Vector3(0,0 if side=="left" else PI,0)
		# Author placed stock at rest. Real hand movement wakes the body.
		end.freeze=false;end.sleeping=true

	for index in upright:
		var identity:=str(order[index]);var book: Node3D=_books[identity]
		var thickness:=float(native_stock.data.books[identity].thickness)
		book.freeze=true;book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		var lean:=.085 if index==upright-1 else 0.
		book.basis=Basis(Vector3.BACK,lean)*Basis(Vector3.UP,PI*.5)
		book.position=Vector3(0,0,front-float(index%3)*.0015)
		var native_bounds: AABB=book.transform*native_stock._bounds(native_stock.data.books[identity].parts)
		book.position.x=cursor-native_bounds.position.x
		var bounds: AABB=book.transform*native_stock._bounds(native_stock.data.books[identity].parts)
		var bearing: float=tops[row]
		for end: Node3D in _ends.values():
			var foot: AABB=end.transform*native_stock._bounds(["bookend_"+style+"__Foot"])
			if minf(bounds.end.x,foot.end.x)-maxf(bounds.position.x,foot.position.x)>.000001 and minf(bounds.end.z,foot.end.z)-maxf(bounds.position.z,foot.position.z)>.000001:
				bearing=maxf(bearing,foot.end.y)
		book.position.y=bearing-bounds.position.y+.00035
		book._apply_opening(0.);book.freeze=false;book.sleeping=true
		cursor+=thickness*cos(lean)+float(native_stock.data.books[identity].height)*sin(lean)+.003
	var height:=float(tops[0])+.00035
	for index in range(order.size()-1,upright-1,-1):
		var identity:=str(order[index]);var book: Node3D=_books[identity]
		var dimensions: Dictionary=native_stock.data.books[identity]
		var thickness:=float(dimensions.thickness)
		book.freeze=true;book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		book.basis=Basis(Vector3.BACK,PI*.5)*Basis(Vector3.UP,PI*.5)
		book.position=Vector3(float(dimensions.height)*.5-.03,height+thickness*.5,front)
		book._apply_opening(0.);book.freeze=false;book.sleeping=true
		height+=thickness+.00035

	# Books occupy authored spots. They remain collision stock, but never
	# enter the rigid-body solver while parked on the shelf.
	for identity: String in order:
		var book: Node3D=_books[identity]
		book_slots.append(book.transform)
		book.park_in_slot(book_slots.size()-1,book.transform)
	# Moving later neighbours can wake an earlier placed body. Publish the
	# completed arrangement at rest only after every stock has its final pose.
	for body: RigidBody3D in _books.values()+_ends.values():
		body.force_update_transform()
	for body: RigidBody3D in _books.values()+_ends.values(): body.start_at_rest()
	_restoring_library=restoring_before

func _decorate() -> void:
	var tops: Array=_case_record.shelf_tops
	var roster: Array=[["cup",0,-.23],["letters",1,-.21],["inkwell",1,.23],["model_boat",2,.23]]
	for item: Array in roster:
		var record: Dictionary=native_stock.data.decorations[str(item[0])]
		var body:=StaticBody3D.new();body.name=str(item[0])
		body.position=Vector3(float(item[2]),float(tops[int(item[1])])+.00035,0.)
		_fixed.add_child(body)
		for part: String in record.parts:
			var draw: MeshInstance3D=native_stock.draw(body,part)
			var solid:=CollisionShape3D.new();solid.name=part
			# A hollow vessel retains its real opening. It is passive shelf
			# stock, so a native concave shape is appropriate here.
			solid.shape=draw.mesh.create_trimesh_shape() if bool(record.open_vessel) else native_stock.hulls[part]
			solid.transform=draw.transform if bool(record.open_vessel) else native_stock.hull_poses[part]
			body.add_child(solid)

func try_place_book(book: Node3D) -> bool:
	if book.opening>.04: return false
	for index in book_slots.size():
		var pose:=book_slots[index]
		if book.position.distance_to(pose.origin)>.065: continue
		if book.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion())>.20: continue
		var occupied:=false
		for other: Node3D in _books.values():
			if other!=book and other.shelf_slot==index: occupied=true;break
		if occupied: continue
		# Use the same swept carry as the hand. Existing resting contacts may
		# separate; an occupancy sample alone incorrectly rejects that escape.
		# The original world/contact authority still vetoes travel into stock.
		if not book._clear_pose(_books_at.global_transform*pose): continue
		book._carry(pose.origin)
		if book.position.distance_to(pose.origin)>.00001:
			# Lift over the bookend's fitted foot before lowering onto the spot.
			# Every leg retains native sweeps; a blocked leg stays blocked.
			book._carry(book.position+Vector3.UP*.004)
			book._carry(pose.origin+Vector3.UP*.004)
			book._carry(pose.origin)
		if book.position.distance_to(pose.origin)>.00001: return false
		var before: Transform3D=book.transform
		var angle:=before.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion())
		var steps:=maxi(1,ceili(angle/.01))
		for step in range(1,steps+1):
			var candidate:=before.interpolate_with(pose,float(step)/steps)
			if not book._clear_pose(_books_at.global_transform*candidate): return false
			book.transform=candidate
		book.park_in_slot(index,pose)
		return true
	return false

func claim_library_hand(part: Node3D, tag: String) -> bool:
	if is_instance_valid(_hand_node): return false
	_hand_node=part;_hand_tag=tag;return true

func release_library_hand(part: Node3D, changed: bool) -> void:
	if _hand_node!=part: return
	_hand_node=null;_hand_tag=""
	if changed:
		if _tap:
			_tap.global_position=part.global_position
			_tap.play()
		library_stock_changed(part)

func library_stock_changed(_part: Node3D) -> void:
	if _restoring_library or not is_inside_tree() or is_queued_for_deletion(): return
	var order:=_physical_reading_order()
	if order!=sorter.order: sorter.moves+=1;sorter.order=order
	order_changed.emit()

func _physical_reading_order() -> Array:
	# A pairwise "within 5 cm" comparator is nontransitive: three overlapping
	# flat books can form A<B<C<A. Form connected piles first, then sort fixed
	# lexicographic keys. Input/save order cannot change the result.
	var entries: Array=[]
	for identity: String in sorter.order:
		var book: Node3D=_books[identity]
		entries.append([identity,_nearest_row(book.position.y),book.position.x,
			book.position.y,absf(book.basis.y.dot(Vector3.UP))<.3,book.position.z])
	entries.sort_custom(func(a: Array,b: Array):
		return a[2]<b[2] if a[2]!=b[2] else str(a[0])<str(b[0]))
	var keys: Dictionary={}
	for row in _case_record.shelf_tops.size():
		var anchor:=0.;var last:=0.;var has_pile:=false
		for entry: Array in entries:
			if entry[1]!=row: continue
			var x: float=entry[2]
			if entry[4]:
				if not has_pile or x-last>.05: anchor=x
				has_pile=true;last=x
			keys[entry[0]]=[-row,anchor if entry[4] else x,-float(entry[3]) if entry[4] else 0.,x,-float(entry[3]),entry[5],entry[0]]
	var order:=sorter.order.duplicate()
	order.sort_custom(func(a: Variant,b: Variant):
		var ka: Array=keys[a];var kb: Array=keys[b]
		for index in ka.size():
			if ka[index]!=kb[index]: return ka[index]<kb[index]
		return false)
	return order

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
	_pending_inspection_stock=null
	var cursor:=part
	while cursor!=null and cursor!=self:
		var identity:=str(cursor.get_meta("library_stock_id",""))
		if _books.has(identity):
			var book: Node3D=_books[identity]
			_pending_inspection_stock=book
			var camera:=get_viewport().get_camera_3d()
			return {"from":camera.global_position,"at":camera.global_position-camera.global_basis.z,"fov":40.}
		if cursor in _ends.values():
			_pending_inspection_stock=cursor
			# The current view has just acquired this loose stock through the
			# unfiltered cursor ray. Preserve that approach: a canned front view
			# can put books/glazing between the camera and an exposed side grip.
			var camera:=get_viewport().get_camera_3d()
			return {"from":camera.global_position,"at":camera.global_position-camera.global_basis.z,"fov":camera.fov}
		cursor=cursor.get_parent() as Node3D
	return inspection_view()

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(0,float(_case_record.height)*.55,1.02)),
		"at":to_global(Vector3(0,float(_case_record.height)*.55,0)),"fov":65.}

func inspection_started() -> void:
	_inspection_stock=_pending_inspection_stock;_pending_inspection_stock=null
	if is_instance_valid(_inspection_stock):
		_inspection_stock.freeze=true
		_inspection_stock.linear_velocity=Vector3.ZERO;_inspection_stock.angular_velocity=Vector3.ZERO
		if _inspection_stock is Book:
			_inspection_stock.begin_floating_view(get_viewport().get_camera_3d().global_transform)

func inspection_ended() -> void:
	if is_instance_valid(_inspection_stock):
		if _inspection_stock is Book: _inspection_stock.end_floating_view()
		var parked: bool=_inspection_stock is Book and _inspection_stock.shelf_slot>=0
		_inspection_stock.freeze=parked;_inspection_stock.sleeping=parked
	_inspection_stock=null;_pending_inspection_stock=null

func reading_view_active() -> bool: return is_instance_valid(_inspection_stock) and _inspection_stock is Book

func supports_inspected_stock(body: Node3D) -> bool:
	return is_instance_valid(_inspection_stock) and _inspection_stock==body

func library_snapshot() -> Dictionary:
	var books: Dictionary={};var ends: Dictionary={};var doors: Array=[]
	var slots: Array=[]
	for pose: Transform3D in book_slots:
		var q:=pose.basis.get_rotation_quaternion().normalized()
		slots.append([pose.origin.x,pose.origin.y,pose.origin.z,q.x,q.y,q.z,q.w])
	for identity: String in _books: books[identity]=_books[identity].book_snapshot()
	for side: String in _ends: ends[side]=_ends[side].stock_snapshot()
	for sash: Node3D in _sashes: doors.append(sash.snapshot())
	return {"schema_version":4,"geometry":_geometry_signature(),"order":sorter.order.duplicate(),"books":books,"bookends":ends,"doors":doors,"moves":sorter.moves,"slots":slots}

func _geometry_signature() -> String:
	var dimensions: Array=[]
	for identity: String in _library_ids:
		var book: Dictionary=native_stock.data.books[identity]
		dimensions.append([identity,book.width,book.height,book.thickness])
	return JSON.stringify(dimensions).sha256_text()

func _saved_slots(value: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D]=[]
	if value.get("schema_version")==2: return book_slots
	if value.get("slots") is not Array or value.slots.size()!=_library_ids.size(): return result
	for row: Variant in value.slots:
		if row is not Array or row.size()!=7: return []
		for number: Variant in row:
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return []
		var point:=Vector3(row[0],row[1],row[2])
		var rotation:=Quaternion(row[3],row[4],row[5],row[6])
		if not point.is_finite() or absf(rotation.length_squared()-1.)>.0001: return []
		result.append(Transform3D(Basis(rotation),point))
	return result

func valid_library(value: Variant) -> bool:
	if value is not Dictionary or not ((value.size()==6 and value.get("schema_version")==2) or (value.size()==7 and value.get("schema_version")==3) or (value.size()==8 and value.get("schema_version")==4 and value.get("geometry") is String)) or value.get("order") is not Array \
		or value.get("books") is not Dictionary or value.get("bookends") is not Dictionary or value.get("doors") is not Array \
		or typeof(value.get("moves")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.moves)) \
		or float(value.moves)<0. or float(value.moves)!=floorf(float(value.moves)): return false
	if not _valid_order(value.order) or value.books.size()!=_books.size() or value.bookends.size()!=_ends.size() or value.doors.size()!=_sashes.size(): return false
	var slots:=_saved_slots(value)
	if slots.size()!=_library_ids.size(): return false
	var occupied: Dictionary={}
	for identity: String in _library_ids:
		if not value.books.has(identity) or not Book.valid_book(value.books[identity]): return false
		var slot:=int(value.books[identity].get("slot",-1))
		if slot>=slots.size() or (slot>=0 and occupied.has(slot)): return false
		if slot>=0:
			occupied[slot]=true
			# The saved body and placement reference must describe one pose.
			var body: Dictionary=value.books[identity].body
			var position:=Vector3(body.position[0],body.position[1],body.position[2])
			var rotation:=Quaternion(body.rotation[0],body.rotation[1],body.rotation[2],body.rotation[3])
			if position.distance_to(slots[slot].origin)>.0001 or absf(rotation.dot(slots[slot].basis.get_rotation_quaternion()))<.999999: return false
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
		var refit: bool=value.get("schema_version",2)<4 or str(value.get("geometry",""))!=_geometry_signature()
		sorter.order=value.order.duplicate();sorter.moves=int(value.moves)
		var authored: Dictionary={}
		if refit:
			_arrange(sorter.order)
			for identity: String in _library_ids: authored[identity]=_books[identity].book_snapshot()
		else: book_slots=_saved_slots(value)
		for identity: String in _library_ids:
			var saved: Dictionary=value.books[identity]
			var parked: bool=int(saved.get("slot",-1))>=0
			if int(value.schema_version)==2:
				# Legacy closed resting copies were the old shelf arrangement.
				parked=bool(saved.body.get("sleeping",false)) and float(saved.opening)<.04
			_books[identity].restore_book(authored[identity] if refit and parked else saved)
		if not refit:
			for side: String in _ends: _ends[side].restore_stock(value.bookends[side])
		for index in _sashes.size(): _sashes[index].restore(value.doors[index])
	_restoring_library=false

func inspection_state() -> Dictionary:
	return {"style":case_style,"book_mesh_count":_books.size(),"door_count":_sashes.size(),
		"has_canonical_book":canonical_book.is_empty() or _books.has(canonical_book),
		"individual_books":true,"bookends":_ends.size(),"library_ids":_library_ids.duplicate()}
