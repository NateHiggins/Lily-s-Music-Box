extends "res://scripts/building/v2_readable_bookshelf.gd"
## Loose physical copies use the existing household book domain, never a new save.
var copy_records: Array = []
var end_records: Array = []

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
			var solid: CollisionShape3D=native_stock.collision(body,identity,Transform3D.IDENTITY)
			if solid!=null: body._solids.append(solid)
		body.set_meta("library_stock_id",body.stock_id)
		body.settled.connect(library_stock_changed.bind(body));_ends[str(record.id)]=body
	sorter.order=_library_ids.duplicate()
	_arrange(sorter.order)
	_tap=make_emitter("tick",-26.)
	add_to_group("v2_library_collections")

func _arrange(_order: Array) -> void:
	var previous:=_restoring_library;_restoring_library=true
	for record: Dictionary in end_records:
		_place(_ends[str(record.id)],record)
	for record: Dictionary in copy_records:
		var book: Node3D=_books[str(record.id)]
		_place(book,record)
		book._apply_opening(float(record.opening))
		book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
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
	var cursor:=part
	while cursor!=null and cursor!=self:
		var identity:=str(cursor.get_meta("library_stock_id",""))
		if _books.has(identity):
			var book: Node3D=_books[identity];_pending_inspection_stock=book
			if absf(book.global_basis.y.dot(Vector3.UP))>.5:
				var point:=book.to_global(Vector3(0,float(book.construction.height)*.5,0))
				return {"from":point-book.global_basis.x*.9,"at":point,"fov":40.}
			var camera:=get_viewport().get_camera_3d()
			return {"from":camera.global_position,"at":camera.global_position-camera.global_basis.z,"fov":camera.fov}
		cursor=cursor.get_parent() as Node3D
	return super.inspection_view_for(part)
