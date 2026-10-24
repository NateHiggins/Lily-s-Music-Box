extends RefCounted
## Weak owner, static coroutine: retirement cannot resume a freed book instance.
## The book still owns every temporary RID immediately and releases it on exit.
const PrintMesh:=preload("res://scripts/props/book_print_mesh.gd")
static func prepare(reference: WeakRef) -> void:
	# Font atlas/material updates finish before retaining vertex streams.
	var preparation_requested:=Time.get_ticks_usec()
	for frame in 2: await RenderingServer.frame_post_draw
	var book: Node3D=reference.get_ref()
	if not is_instance_valid(book) or not book.is_inside_tree(): return
	var preparation_started:=Time.get_ticks_usec()
	var slice_started:=preparation_started;var preparation_cpu:=0;var maximum_slice:=0
	var targets: Array=[]
	var cuts: Dictionary={}
	for side: String in ["left","right"]:
		var values:=PackedFloat64Array()
		for point: Vector3 in book.stock.page_profile(book.stock_id,side,0.):values.append(point.x)
		cuts[side]=values
	if str(book.construction.get("opening_style","hardback"))!="hardback":
		var values:=PackedFloat64Array()
		for point: Vector3 in book.stock.surface_profile(book.stock_id+"__left_board",float(book.construction.thickness)*.5,0.):values.append(point.x)
		cuts.cover_left=values
	for sheet: Node3D in book._sheets:
		var side: String="left" if str(sheet.name).begins_with("Left") else "right"
		var face_z:=float(book.construction.left_page_z)+.00004 if side=="left" else float(book.construction.right_page_z)-.00004
		for node: Node3D in sheet.get_children(): targets.append({"node":node,"sheet":sheet,"frame":sheet.transform,"side":side,"face_z":face_z})
	if str(book.construction.get("opening_style","hardback"))!="hardback":
		for node: Node3D in book.left.get_children():
			if node is Label3D: targets.append({"node":node,"sheet":book.left,"frame":Transform3D.IDENTITY,"side":"cover_left","face_z":float(book.construction.thickness)*.5})
	for target: Dictionary in targets:
		var node: Node3D=target.node
		var source:=RID();var instance:=RID()
		if node is Label3D: source=node.get_base();instance=node.get_instance()
		elif node is MeshInstance3D: source=node.mesh.get_rid();instance=node.get_instance()
		else: continue
		var surfaces: Array=[]
		var native_width:=.102 if node.name=="type__running_rule" else 0.
		if node.has_meta("printed_illustration"):native_width=float(book.stock.data.illustrations[str(node.get_meta("printed_illustration"))].width)
		var factor:=float(node.get_meta("print_width",native_width))/native_width if native_width>0. else 1.
		for surface in RenderingServer.mesh_get_surface_count(source):
			var stream:=PrintMesh.stream(RenderingServer.mesh_surface_get_arrays(source,surface),target.frame*node.transform,cuts[str(target.side)],factor)
			stream.material=RenderingServer.mesh_surface_get_material(source,surface);surfaces.append(stream)
		if surfaces.is_empty(): continue
		target.merge({"surfaces":surfaces,"mesh":RenderingServer.mesh_create(),"instance":instance})
		# Own every RID immediately, including if this book is freed while
		# a later preparation slice is waiting for its next frame.
		book._print_surfaces.append(target)
		var elapsed:=Time.get_ticks_usec()-slice_started
		if elapsed>=2000:
			preparation_cpu+=elapsed;maximum_slice=maxi(maximum_slice,elapsed)
			await book.get_tree().process_frame
			if not is_instance_valid(book) or not book.is_inside_tree():return
			slice_started=Time.get_ticks_usec()
	book._print_ready=true
	book._print_angle=-1.;book._warp_print()
	var final_slice:=Time.get_ticks_usec()-slice_started
	preparation_cpu+=final_slice;maximum_slice=maxi(maximum_slice,final_slice)
	book.set_meta("print_preparation_ms",preparation_cpu/1000.)
	book.set_meta("print_preparation_max_slice_ms",maximum_slice/1000.)
	book.set_meta("print_preparation_latency_ms",(Time.get_ticks_usec()-preparation_requested)/1000.)
	for sheet: Node3D in book._sheets:sheet.visible=book.opening>.04
