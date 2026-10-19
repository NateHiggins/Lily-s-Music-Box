extends Node3D
## Imported source charts/maps plus native-stock deformation. No room grant.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
const Hose=preload("res://scripts/props/native_flexible_hose.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("FIRE HOSE CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func bend_basis(mesh: Mesh) -> Dictionary:
	var a: Array=mesh.surface_get_arrays(0)
	var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL];var t: PackedFloat32Array=a[Mesh.ARRAY_TANGENT];var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	var worst: float=1.0;var bad: int=0
	for index in range(0,ids.size(),3):
		var i: int=ids[index];var j: int=ids[index+1];var k: int=ids[index+2]
		var u: Vector2=uv[j]-uv[i];var v: Vector2=uv[k]-uv[i];var det: float=u.x*v.y-v.x*u.y
		if absf(det)<1e-12:bad+=1;continue
		var du: Vector3=((p[j]-p[i])*v.y-(p[k]-p[i])*u.y)/det
		var dv: Vector3=((p[k]-p[i])*u.x-(p[j]-p[i])*v.x)/det
		for corner: int in [i,j,k]:
			var tangent:=Vector3(t[corner*4],t[corner*4+1],t[corner*4+2])
			var expected: Vector3=(du-n[corner]*du.dot(n[corner])).normalized()
			worst=minf(worst,expected.dot(tangent))
			if not n[corner].is_finite() or absf(n[corner].length()-1.)>.001 or absf(tangent.length()-1.)>.001 or n[corner].cross(tangent).dot(dv)*t[corner*4+3]<=0.:bad+=1
	return {"minimum_dot":worst,"bad":bad}
func _run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/fire_hose_stock.json"))
	check(int(data.schema_version)==1,"explicit native stock schema")
	var library: Node3D=(load(str(data.asset)) as PackedScene).instantiate()
	var finish: StandardMaterial3D=MatLib.get_mat(str(data.catalog_key)).duplicate() as StandardMaterial3D
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE;finish.normal_scale=.08
	finish.albedo_color=Color(.75,.71,.59);finish.roughness=.9
	for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
		check(texture!=null and texture.get_image()!=null and texture.get_image().get_mipmap_count()>0,"real loaded catalogue map retains mip chain")
	check(finish.normal_enabled,"normal mapping enabled on the actual finish")
	var metrics: Node=Metrics.new()
	var i: int=0
	for id: String in data.stocks:
		var stock: MeshInstance3D=library.find_child(id,true,false) as MeshInstance3D
		check(stock!=null,"declared native stock: "+id)
		if stock==null:continue
		metrics._check_cap_mapping(stock.mesh,true)
		var hose: MeshInstance3D=Hose.new();hose.name=id;add_child(hose)
		check(hose.bind(stock.mesh,finish,data.stocks[id]),"native tube binding: "+id)
		var first:=Vector3(i*.35,0,0)
		var last: Vector3=first+Vector3(.15 if i==0 else .20,.034 if i==0 else .03,0)
		var started: int=Time.get_ticks_usec()
		check(hose.pose(first,last),"fixed-length curved pose: "+id)
		print("FIRE HOSE POSE COST: ",id," ms=",(Time.get_ticks_usec()-started)/1000.)
		var original: Array=stock.mesh.surface_get_arrays(0);var bent: Array=hose.mesh.surface_get_arrays(0)
		check(original[Mesh.ARRAY_TEX_UV]==bent[Mesh.ARRAY_TEX_UV] and original[Mesh.ARRAY_INDEX]==bent[Mesh.ARRAY_INDEX],"deformation retains authored UVs and topology: "+id)
		var basis: Dictionary=bend_basis(hose.mesh)
		print("FIRE HOSE BENT BASIS: ",id," ",basis)
		check(basis.bad==0 and basis.minimum_dot>.999,"bent normals and tangent handedness agree with actual deformed UV derivatives: "+id)
		check(not hose.pose(first,first+Vector3(2,0,0)),"overreach refused without stretching: "+id)
		check(hose.bind(stock.mesh,finish,data.stocks[id]) and hose.pose(first,last) and hose.mesh!=stock.mesh,"rebinding regenerates the curved mesh even at cached endpoints: "+id)
		i+=1
	for failure: String in metrics.failures:check(false,failure)
	metrics.free();library.free()
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.13,.13,.13);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,20,0);sun.light_energy=1.3;add_child(sun)
	var camera:=Camera3D.new();camera.position=Vector3(.27,.32,.95);add_child(camera);camera.look_at(Vector3(.27,0,0));camera.make_current()
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);await get_tree().create_timer(.5).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("loaded_native_hoses.png"))
	print("V2 FIRE HOSE STOCK: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	if not failures.is_empty():get_tree().quit(1);return
	# Same engine launch, clean fixture: imported stock first, actual cabinet
	# input second. A failed stock import never pays for a composed world.
	for child: Node in get_children():child.free()
	await get_tree().physics_frame
	var hands: Node3D=load("res://tests/v2_fire_hand_bench.gd").new();add_child(hands)
