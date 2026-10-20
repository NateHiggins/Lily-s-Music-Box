extends Node3D
## INERT installed-geometry diagnostic; no gameplay or ledger acceptance.
var adapter: Dictionary
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	var shell=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.production_materials=true;shell.show_clearance_anchors=false;shell.show_reservation_volumes=false;add_child(shell)
	adapter={"root":shell}
	var fitter=preload("res://scripts/building/orison_v2_front_trim_fittings.gd").new()
	var mounted: bool=fitter.mount(self)
	check(mounted,"production fitting adapter mounts without stale-source errors: "+str(fitter.errors))
	if not mounted:get_tree().quit(1);return
	check(fitter.changed_batches.size()==9 and fitter.installed.size()==66,"twenty-two three-piece cornice fittings installed; retired rail fittings absent")
	for row: Dictionary in fitter.changed_batches:
		var batch: MultiMeshInstance3D=row.batch.get_ref()
		check(batch.get_meta("wall_sources").size()==batch.multimesh.instance_count,"wall ownership retained on every split strip")
		var found:=0
		for i in batch.multimesh.instance_count:
			for j in row.before.instance_count:
				if batch.multimesh.get_instance_transform(i)==row.before.get_instance_transform(j):
					check(batch.multimesh.get_instance_custom_data(i)==row.before.get_instance_custom_data(j),"unaffected strip retains exact material-scale metadata");found+=1;break
		check(found==row.unchanged,"unaffected strip transforms preserved exactly")
	var validator=preload("res://tests/orison_v2_fixed_lighting_test.gd").new()
	var meshes: Dictionary={}
	for draw: MeshInstance3D in fitter.installed:
		if meshes.has(draw.mesh.get_instance_id()):continue
		meshes[draw.mesh.get_instance_id()]=true
		validator._check_cap_mapping(draw.mesh,true)
		var material:=draw.get_active_material(0) as StandardMaterial3D
		check(material!=null and not material.uv1_triplanar,"native wood samples authored UV charts")
		for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
			var image:=texture.get_image()
			check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.0))),"loaded wood map has a complete real mip chain")
	check(validator.failures.is_empty(),"all three retained cornice stocks pass unchanged strict UV/tangent validator")
	checks+=validator.batch_checks;validator.free()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/front_lighting_trim.json"))
	for fitting: Dictionary in data.fittings:
		var frame: Transform3D=fitter._pose(fitting.pose)
		var room:=shell.get_node(str(fitting.room)) as Node3D
		var batch:=room.get_node("HistoricMillwork") as MultiMeshInstance3D
		var parts: Array[MeshInstance3D]=[]
		for draw: MeshInstance3D in fitter.installed:
			if draw.get_meta("native_front_trim_fit")==str(fitting.owner):parts.append(draw)
		var clear:=true;var original_clear:=true
		for i in 32:
			var angle:=TAU*i/32
			var offset:=Vector3(cos(angle)*.0126,0,.020+sin(angle)*.0126) if fitting.variant=="rail" else Vector3(cos(angle)*.0126,sin(angle)*.0126,0)
			var a:=frame*(offset+Vector3.UP*.08 if fitting.variant=="rail" else offset+Vector3.BACK*.08)
			var b:=frame*(offset-Vector3.UP*.08 if fitting.variant=="rail" else offset-Vector3.BACK*.08)
			for draw: MeshInstance3D in parts:
				var first:=draw.transform.affine_inverse()*a;var second:=draw.transform.affine_inverse()*b
				var triangles:=draw.mesh.get_faces()
				for j in range(0,triangles.size(),3):
					if Geometry3D.segment_intersects_triangle(first,second,triangles[j],triangles[j+1],triangles[j+2])!=null:clear=false;break
			var center: Vector3=frame*offset
			for j in batch.multimesh.instance_count:
				var bounds: AABB=batch.multimesh.get_instance_transform(j)*batch.multimesh.mesh.get_aabb()
				if bounds.grow(.00001).has_point(center):original_clear=false;break
		check(clear,"actual imported stock has an open pipe passage: "+str(fitting.owner))
		check(original_clear,"no retained unbored original strip covers the passage: "+str(fitting.owner))
	await _capture(shell,fitter)
	await _capture_joint(shell)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Actual source-shell fitting, imported derivative and loaded mip checks; no composed gameplay/ledger acceptance."},"\t"))
	fitter.finish();shell.free()
	print("FRONT TRIM FITTINGS: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(shell: Node3D,fitter: RefCounted) -> void:
	var model:=load("res://assets/props/front_lighting_supply.glb").instantiate() as Node3D
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/front_lighting_supply.json"))
	var finishes: Dictionary={}
	for row: Dictionary in source.materials:finishes[str(row.mesh)]=str(row.catalog_key)
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		node.material_override=MatLib.get_mat(finishes[node.mesh.resource_name]);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(model)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.35;add_child(env)
	var camera:=Camera3D.new();camera.fov=55;add_child(camera);camera.make_current()
	var fill:=OmniLight3D.new();fill.light_energy=.15;fill.omni_range=3;camera.add_child(fill)
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var cornice_frame:=Transform3D.IDENTITY
	for fitting: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/front_lighting_trim.json")).fittings:
		if fitting.variant=="cornice" and fitting.room=="F02_FRONT_GALLERY":
			cornice_frame=fitter._pose(fitting.pose);break
	check(cornice_frame!=Transform3D.IDENTITY,"gallery cornice camera resolves an installed fitting")
	var target:=cornice_frame.origin
	var eye:=target+cornice_frame.basis.z*.55+cornice_frame.basis.x*.22+Vector3.DOWN*.16
	for view: Array in [["removed_rail",Vector3(4.9,1.82,-4.35),Vector3(5.55,1.65,-3.94)],["cornice",eye,target]]:
		camera.position=view[1];camera.look_at(view[2])
		await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(str(view[0])+".png"))==OK,"source-shell fitting capture saved")

func _capture_joint(shell: Node3D) -> void:
	# Source-shell diagnostic isolates wall/ceiling geometry from the city rig.
	var partitions:=0
	for wall: MeshInstance3D in shell.find_children("Wall*","MeshInstance3D",true,false):
		if wall.has_node("Collision"):
			partitions+=1
			check(wall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED,"solid partition occludes both shadow-culling directions")
	check(partitions>0,"joint diagnostic includes actual solid partitions")
	var camera:=Camera3D.new();camera.fov=55;add_child(camera);camera.make_current()
	camera.position=Vector3(5.7,1.65,-11.7);camera.look_at(Vector3(7.5,2.35,-10.3))
	var light:=OmniLight3D.new();light.position=Vector3(8.9,2.53,-10.8)
	light.light_color=Color(1,.76,.5);light.light_energy=1.8;light.omni_range=3;light.omni_attenuation=1.4
	light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE;light.shadow_enabled=true
	light.shadow_bias=.012;light.shadow_normal_bias=.08;light.light_size=.1;add_child(light)
	var directory:=OS.get_environment("SHOT_DIR")
	for view: Array in [["joint_reverse",true,.012,.08],["joint_front",false,.012,.08],["joint_tight",true,.001,.001],["joint_solidwalls",true,.012,.08]]:
		light.shadow_reverse_cull_face=view[1];light.shadow_bias=view[2];light.shadow_normal_bias=view[3]
		if view[0]=="joint_solidwalls":
			for wall: MeshInstance3D in shell.find_children("Wall*","MeshInstance3D",true,false):wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(str(view[0])+".png"))==OK,"wall/ceiling joint diagnostic saved")
	light.free();camera.free()
