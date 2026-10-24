extends "res://scripts/building/v2_readable_bookshelf.gd"
## Loose physical copies use the existing household book domain, never a new save.
var copy_records: Array = []
var end_records: Array = []
var decoration_records: Array = []

func _build_visual() -> void:
	sorter.load_library()
	owner_name="Orison lending collection"
	_case_record={"width":1.4,"height":1.8,"shelf_tops":[.582,1.002,1.422]}
	_fixed=Node3D.new();_fixed.name="Collection";add_child(_fixed)
	_books_at=Node3D.new();_books_at.name="Books";add_child(_books_at)
	for record: Dictionary in copy_records:
		var identity:=str(record.id)
		var book:=Book.new();book.name=identity;book.stock_id=identity
		book.title_id=str(record.title_id);book.entry=sorter.book(book.title_id)
		book.shelf=self;book.stock=native_stock
		_library_ids.append(identity);_books[identity]=book;_books_at.add_child(book)
		book.settled.connect(library_stock_changed.bind(book))
	for record: Dictionary in end_records:
		var body:=Movable.new();body.name=str(record.id);body.stock_id=str(record.id);body.shelf=self
		_books_at.add_child(body)
		var spec: Dictionary=native_stock.data.bookends[str(record.style)]
		body.mass=float(spec.mass_kg)
		for identity: String in spec.parts:
			native_stock.draw(body,identity)
			if identity.ends_with("__Foot") or identity.ends_with("__Felt"): continue
			var solid: CollisionShape3D=native_stock.collision(body,identity,Transform3D.IDENTITY)
			if solid!=null: body._solids.append(solid)
		var bearing: Dictionary=native_stock.bookend_bearing(str(record.style))
		var sole:=CollisionShape3D.new();sole.name="BondedFootBearing";sole.shape=bearing.shape;sole.transform=bearing.pose
		body.add_child(sole);body._solids.append(sole)
		body.set_meta("library_stock_id",body.stock_id)
		body.settled.connect(library_stock_changed.bind(body));_ends[str(record.id)]=body
	sorter.order=_library_ids.duplicate()
	_arrange(sorter.order)
	for record: Dictionary in decoration_records:
		var p: Array=record.position
		_mount_decoration(str(record.id),str(record.style),Vector3(p[0],p[1],p[2]),float(record.yaw))
	_tap=make_emitter("tick",-26.)
	add_to_group("v2_library_collections")

func _arrange(_order: Array) -> void:
	var previous:=_restoring_library;_restoring_library=true
	book_slots.clear()
	for record: Dictionary in end_records:
		_place(_ends[str(record.id)],record)
	for record: Dictionary in copy_records:
		var book: Node3D=_books[str(record.id)]
		_place(book,record)
		book._apply_opening(float(record.opening))
		book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		book_slots.append(book.transform)
		book.park_in_slot(book_slots.size()-1,book.transform)
		book.force_update_transform()
	for body: Node3D in _books.values()+_ends.values(): body.start_at_rest()
	_restoring_library=previous

func _place(body: Node3D,record: Dictionary) -> void:
	var p: Array=record.position;var axes: Array=record.basis
	body.position=Vector3(p[0],p[1],p[2])
	body.basis=Basis(Vector3(axes[0][0],axes[0][1],axes[0][2]),Vector3(axes[1][0],axes[1][1],axes[1][2]),Vector3(axes[2][0],axes[2][1],axes[2][2]))
	body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
	body.force_update_transform()

func inspection_view_for(part: Node3D) -> Dictionary:
	return super.inspection_view_for(part)

func pickup_withdrawal_for(body: Node3D) -> Vector3:
	# The nook rack faces opposite the household cases. Flat stacks and the
	# cushion reader lift out; each original native sweep may still refuse it.
	return -body.global_basis.x*.26 if absf(body.global_basis.y.dot(Vector3.UP))>.5 else Vector3.UP*.26

func _geometry_signature() -> String:
	# Parked copies follow authored furniture repairs. Loose poses remain in
	# the original stable collection frame, including books carried far away.
	var placements: Array=[]
	for record: Dictionary in copy_records:
		placements.append([record.id,record.position,record.basis,record.opening])
	return (super._geometry_signature()+JSON.stringify(placements)).sha256_text()

func valid_library(value: Variant) -> bool:
	return super.valid_library(_migrate_legacy(value))

func restore_order(value: Variant) -> void:
	super.restore_order(_migrate_legacy(value))

func _migrate_legacy(value: Variant) -> Variant:
	if value is not Dictionary or value.get("books") is not Dictionary or not (value.get("schema_version")==2 or value.get("schema_version")==3 or value.get("schema_version")==4): return value
	if value.get("slots") is Array and not value.slots.is_empty(): return value
	var migrated: Dictionary=value.duplicate(true)
	migrated.schema_version=4;migrated.geometry=_geometry_signature();migrated.slots=[]
	for pose: Transform3D in book_slots:
		var q:=pose.basis.get_rotation_quaternion().normalized()
		migrated.slots.append([pose.origin.x,pose.origin.y,pose.origin.z,q.x,q.y,q.z,q.w])
	for index in copy_records.size():
		var record: Dictionary=copy_records[index]
		var saved: Variant=migrated.books.get(str(record.id))
		if not Book.valid_book(saved) or not record.has("legacy_pose"): continue
		if not _at_legacy_pose(saved.body,record.legacy_pose) or absf(float(saved.opening)-float(record.legacy_opening))>.0001: continue
		var pose: Transform3D=book_slots[index];var q:=pose.basis.get_rotation_quaternion().normalized()
		saved.body.position=[pose.origin.x,pose.origin.y,pose.origin.z];saved.body.rotation=[q.x,q.y,q.z,q.w]
		saved.body.velocity=[0.,0.,0.];saved.body.spin=[0.,0.,0.];saved.body.sleeping=true
		saved.slot=index;saved.opening=float(record.opening)
	if migrated.get("bookends") is Dictionary:
		for record: Dictionary in end_records:
			var saved: Variant=migrated.bookends.get(str(record.id))
			if not Movable.valid_stock(saved) or not record.has("legacy_pose") or not _at_legacy_pose(saved,record.legacy_pose): continue
			var axes: Array=record.basis
			var q:=Basis(Vector3(axes[0][0],axes[0][1],axes[0][2]),Vector3(axes[1][0],axes[1][1],axes[1][2]),Vector3(axes[2][0],axes[2][1],axes[2][2])).get_rotation_quaternion().normalized()
			saved.position=record.position.duplicate();saved.rotation=[q.x,q.y,q.z,q.w]
			saved.velocity=[0.,0.,0.];saved.spin=[0.,0.,0.]
	return migrated

func _at_legacy_pose(body: Dictionary, reference: Array) -> bool:
	if not bool(body.sleeping): return false
	var point:=Vector3(body.position[0],body.position[1],body.position[2])
	var q:=Quaternion(body.rotation[0],body.rotation[1],body.rotation[2],body.rotation[3])
	return point.distance_to(Vector3(reference[0],reference[1],reference[2]))<.004 and absf(q.dot(Quaternion(reference[3],reference[4],reference[5],reference[6])))>.999999
