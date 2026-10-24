extends "res://tests/v2_nook_world_profile.gd"
## INERT exact-world floor/capsule survey and actual-input entry route.
func _init() -> void: route_label="V2 NOOK ACCESS SURVEY"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(-1.7,-3.159,-1.8));player.velocity=Vector3.ZERO

func _play_route() -> void:
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var records: Array=[]
	var capsule:=CapsuleShape3D.new();capsule.radius=.33;capsule.height=1.524
	for ix in range(17):
		for iz in range(31):
			var local:=Vector3(-2.+ix*.2,-3.2,-2.2+iz*.2)
			var at: Vector3=world.adapter.root.to_global(local)
			var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.08,at-Vector3.UP*.5,1,[player.get_rid()]))
			var row: Dictionary={"local":str(local)}
			if not floor_hit.is_empty():
				row.floor_y=world.adapter.root.to_local(floor_hit.position).y;row.floor=str(floor_hit.collider.get_path())
				var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.margin=0.;q.exclude=[player.get_rid()]
				q.transform=Transform3D(Basis.IDENTITY,floor_hit.position+Vector3.UP*(.762+.002))
				row.obstructions=[]
				for hit: Dictionary in space.intersect_shape(q,24):row.obstructions.append(str(hit.collider.get_path()))
			records.append(row)
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("clearance.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","capsule_radius":.33,"capsule_height":1.524,"samples":records},"\t"))
	var nook: Node=world.adapter.root.get_node("V2ReadingNook")
	var specifications: Dictionary={}
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/reading_nook.json"))
	for row: Dictionary in native.assemblies:
		for part: Dictionary in row.parts:specifications[str(part.name)]=part
	for body: Node in nook.get_children():
		for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",false,false):
			var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			if not _require(material!=null and not material.uv1_triplanar and material.normal_enabled,"nook part samples authored UV/PBR: "+str(draw.name)):return
			var specification: Dictionary=specifications[str(draw.name)]
			if specification.has("tint"):
				var tint: Array=specification.tint
				if not _require(material.albedo_color.srgb_to_linear().is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"runtime tint matches native linear pigment: "+str(draw.name)):return
			for texture: Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
				# The registered clear dielectric legitimately has no albedo map.
				if texture==null and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
				if not _require(texture!=null,"nook opaque physical map loaded: "+str(draw.name)):return
				var image:=texture.get_image()
				if not _require(image!=null and image.get_mipmap_count()==int(round(log(float(maxi(image.get_width(),image.get_height())))/log(2.))),"nook complete loaded mip chain: "+str(draw.name)):return
	player.profile_physics=true
	# Follow the west corridor past the retained transfer beam, then cross
	# the actual table/bench aisle. The baseline's premature turn is archived.
	for target: Vector3 in [Vector3(-1.7,-3.2,-1.4),Vector3(-1.7,-3.2,-.5),Vector3(-1.7,-3.191,1.5),Vector3(-.48,-3.191,1.5),Vector3(-.48,-3.191,2.2),Vector3(-.48,-3.191,1.5),Vector3(-1.7,-3.191,1.5),Vector3(-1.7,-3.2,-.5)]:
		if not await _walk(target):return
		if target==Vector3(-.48,-3.191,2.2):
			profile_phase="nook_context_capture_excluded"
			player.camera.look_at(world.adapter.root.to_global(Vector3(-.85,-2.4,3.1)))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("inside_nook.png"))
			await super._play_route()
			if not failures.is_empty():return
			_click_library()
	player.camera.look_at(world.adapter.root.to_global(Vector3(-.48,-2.3,3.0)))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("outside_approach.png"))
