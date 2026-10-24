extends "res://tests/v2_readable_library_bench.gd"
## INERT diagnostic: sample rendered triangle interiors against native paper.
func _run() -> void:
	RealityState.persistence_enabled=false
	var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
	if not check(stock.prepare(),"native stock prepares"):get_tree().quit(1);return
	var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name="Print diagnostic";add_child(shelf)
	player=PlayerController.new();player.position=Vector3(0,2,5);add_child(player);player.set_physics_process(false);player.camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-20,-20,0);sun.light_energy=.7;add_child(sun)
	var records: Array=[]
	var control:=OS.get_environment("PRINT_CONTROL")
	var titles: Array=stock.data.books.keys() if OS.get_environment("PRINT_ALL")=="1" else ["letters","missing","sorting"]
	for identity: String in titles:
		if not control.is_empty() and identity!="letters":continue
		var book:=preload("res://scripts/props/v2_readable_book.gd").new()
		book.stock=stock;book.shelf=shelf;book.stock_id=identity;book.entry=shelf.sorter.book(identity)
		book.position=Vector3(0,3,8);add_child(book);book.freeze=true
		var angles: Array=[PI*.35,PI*.65,PI]
		if OS.get_environment("PRINT_ALL")=="1":angles=[PI/8.,PI/4.,PI*3./8.,PI/2.,PI*5./8.,PI*3./4.,PI*7./8.,PI]
		for angle: float in angles:
			if not control.is_empty() and angle!=PI:continue
			book._apply_opening(angle)
			# Diagnostic render controls only; never a production visibility fix.
			for label: Label3D in book.printed_labels:
				if control=="no_aa":label.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_OFF
				if control=="unshaded":label.shaded=false
				if control=="no_depth":label.no_depth_test=true
				if control=="blend":label.alpha_cut=Label3D.ALPHA_CUT_DISABLED;label.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_OFF
				if control=="blend_matte":label.alpha_cut=Label3D.ALPHA_CUT_DISABLED;label.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_OFF
				if control=="prepass_matte":label.alpha_cut=Label3D.ALPHA_CUT_OPAQUE_PREPASS;label.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_OFF
				if control=="bitmap":
					var font:=FontFile.new();font.data=book.SERIF.data;font.generate_mipmaps=true;font.multichannel_signed_distance_field=false;label.font=font
			for frame in 4:await RenderingServer.frame_post_draw
			for frame in 120:
				if book._print_ready:break
				await RenderingServer.frame_post_draw
			check(book._print_ready,"bounded glyph preparation completes")
			if control.ends_with("_matte"):
				for label: Label3D in book.printed_labels:book._matte_letter(label)
			if control=="flat":
				for printed: Dictionary in book._print_surfaces:
					if printed.node is Label3D:
						RenderingServer.instance_set_base(printed.instance,printed.node.get_base());printed.node.position.z+=.03
			var worst:=INF;var below:=0;var samples:=0
			for printed: Dictionary in book._print_surfaces:
				if printed.node is not Label3D:continue
				var source: Array=stock.page_profile(identity,printed.side,angle) if printed.side!="cover_left" else stock.surface_profile(identity+"__left_board",float(book.construction.thickness)*.5,angle)
				var profile: Array=[]
				for point: Vector3 in source:profile.append(Vector3(point.y,point.y,point.z))
				profile.sort_custom(func(a: Vector3,b: Vector3):return a.x<b.x)
				var direction: float=-1. if printed.side=="left" else 1.
				var frame: Transform3D=printed.frame*printed.node.transform
				for surface in RenderingServer.mesh_get_surface_count(printed.mesh):
					var arrays:=RenderingServer.mesh_surface_get_arrays(printed.mesh,surface)
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					if indices.is_empty():for index in vertices.size():indices.append(index)
					for index in range(0,indices.size(),3):
						var a:=frame*vertices[indices[index]];var b:=frame*vertices[indices[index+1]];var c:=frame*vertices[indices[index+2]]
						for uv: Vector2 in [Vector2(0,0),Vector2(.25,.25),Vector2(.5,.25),Vector2(.25,.5),Vector2(1./3.,1./3.)]:
							var point:=a*(1.-uv.x-uv.y)+b*uv.x+c*uv.y
							var clearance:=direction*(point.z-stock.sample_page(profile,point.x).y)
							worst=minf(worst,clearance);samples+=1
							if clearance<0.:below+=1
			var row: Dictionary={"id":identity,"angle":angle,"minimum_clearance_m":worst,"buried_samples":below,"samples":samples}
			records.append(row);print("PRINT CONTACT: ",row)
			check(samples>0,"contact diagnostic samples rendered glyphs")
			check(below==0,"glyph interiors clear native paper: "+identity+"/"+str(angle))
			if angle==PI and (OS.get_environment("PRINT_ALL")!="1" or identity in ["letters","missing","sorting"]):
				player.camera.global_position=book.global_position+Vector3(-float(book.construction.thickness)*.5,float(book.construction.height)*.5,.23)
				player.camera.look_at(book.global_position+Vector3(-float(book.construction.thickness)*.5,float(book.construction.height)*.5,0));player.camera.fov=42.
				await capture(identity+"_spread")
		book.free()
	var out:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("contact.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"failures":failures},"\t"))
	print("BOOK PRINT CONTACT: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
