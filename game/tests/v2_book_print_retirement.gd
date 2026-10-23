extends "res://tests/v2_readable_library_bench.gd"
## Actual native glyph jobs retired during initial wait and bounded slicing.
func make_book(stock: RefCounted,shelf: Node3D) -> Node3D:
	var book:=preload("res://scripts/props/v2_readable_book.gd").new()
	book.stock=stock;book.shelf=shelf;book.stock_id="letters";book.entry=shelf.sorter.book("letters")
	book.position=Vector3(0,3,8);add_child(book);book.freeze=true;book._apply_opening(PI)
	return book

func _run() -> void:
	RealityState.persistence_enabled=false
	var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
	if not check(stock.prepare(),"native readable stock prepares"):get_tree().quit(1);return
	var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name="Print diagnostic";add_child(shelf)
	player=PlayerController.new();player.position=Vector3(0,2,5);add_child(player);player.set_physics_process(false);player.camera.make_current()
	player.camera.look_at(Vector3(.1,3.2,8))
	var first:=make_book(stock,shelf);var first_ref: WeakRef=weakref(first)
	await get_tree().process_frame
	first.free()
	for frame in 4:await RenderingServer.frame_post_draw
	check(first_ref.get_ref()==null,"native book retires while its font-atlas frame wait is pending")
	var second:=make_book(stock,shelf);var second_ref: WeakRef=weakref(second)
	# Synthetic duplicate glyph load forces a bounded preparation slice. It
	# changes only this diagnostic fixture, never production book content.
	var longest: Label3D=second.printed_labels[0]
	for label: Label3D in second.printed_labels:
		if label.text.length()>longest.text.length():longest=label
	for i in 20:longest.get_parent().add_child(longest.duplicate())
	var sliced:=false
	for frame in 60:
		await get_tree().process_frame
		if not second._print_surfaces.is_empty() and not second._print_ready:sliced=true;break
		if second._print_ready:break
	check(sliced,"large native glyph job yields after owning its temporary meshes")
	second.free()
	for frame in 4:await RenderingServer.frame_post_draw
	check(second_ref.get_ref()==null,"native book retires during a bounded preparation slice")
	var third:=make_book(stock,shelf)
	for frame in 120:
		await RenderingServer.frame_post_draw
		if third._print_ready:break
	check(third._print_ready and not third._print_surfaces.is_empty(),"surviving native book completes its unchanged print preparation")
	third.free()
	for frame in 3:await RenderingServer.frame_post_draw
	print("BOOK PRINT RETIREMENT: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
