extends Node3D
## Actual imported charts, maps and bore/sealing rays; no runtime room grant.
const Stock=preload("res://scripts/props/fire_joint_stock_library.gd")
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("FIRE JOINT CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func ray_distance(draw: MeshInstance3D,origin: Vector3,direction: Vector3) -> float:
	# Godot's general-purpose ray helper rejects tiny triangle determinants.
	# Query the same triangles in millimetres, then return metres; retain the
	# actual100um bearing requirement and prove positive hits beside each bore.
	var local: Vector3=draw.to_local(origin)*1000.
	var axis: Vector3=draw.global_basis.inverse()*direction
	var faces: PackedVector3Array=draw.mesh.get_faces();var nearest: float=INF
	for i in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(local,axis,faces[i]*1000.,faces[i+1]*1000.,faces[i+2]*1000.)
		if hit!=null:nearest=minf(nearest,origin.distance_to(draw.to_global(hit/1000.)))
	return nearest
func _run() -> void:
	var stock:=Stock.new()
	if not stock.load_stock():push_error("Native joint library rejected");get_tree().quit(1);return
	var metrics: Node=Metrics.new()
	var draws: Dictionary={}
	for key: String in stock.meshes:
		metrics._check_cap_mapping(stock.meshes[key],true)
		var draw: MeshInstance3D=stock.make_part(key);add_child(draw);draws[key]=draw
		var finish: StandardMaterial3D=draw.material_override
		check(finish.normal_enabled and not finish.uv1_triplanar,"actual native normal mapping: "+key)
		for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
			check(texture.get_image()!=null and texture.get_image().get_mipmap_count()>0,"actual loaded mip chain: "+key)
		var layout: Dictionary={"MaleOutlet":Vector3(-.16,float(stock.data.dimensions.male_origin_y_m),0),"FemaleUnion":Vector3(-.08,.513,0),"SwivelTail":Vector3(0,.513,0),"HoseNeck":Vector3(.08,.513,0),"HoseRetainer":Vector3(.16,.513,0),"UnionGasket":Vector3(.16,.57,0)}
		draw.position=layout[key]
		var clear: bool=true
		for i in range(17):
			var angle: float=TAU*i/16.;var radius: float=0. if i==16 else float(stock.data.dimensions.bore_radius_m)-.0001
			var local: Vector3=Vector3(radius*cos(angle),draw.mesh.get_aabb().position.y-.001,radius*sin(angle))
			clear=clear and is_inf(ray_distance(draw,draw.to_global(local),Vector3.UP))
		check(clear,"17 actual imported bore rays stay clear: "+key)
		var bounds: AABB=draw.mesh.get_aabb()
		var minimum_radius: float=INF;var maximum_radius: float=0.
		for vertex: Vector3 in draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var radial: float=Vector2(vertex.x,vertex.z).length()
			minimum_radius=minf(minimum_radius,radial);maximum_radius=maxf(maximum_radius,radial)
		var rim: float=(minimum_radius+maximum_radius)*.5
		var positive: Vector3=Vector3(rim,bounds.end.y+.001,0)
		check(is_finite(ray_distance(draw,draw.to_global(positive),Vector3.DOWN)),"positive control hits native annular stock beside the clear bore: "+key)
	var female: MeshInstance3D=draws.SwivelTail;var gasket: MeshInstance3D=draws.UnionGasket
	var original_union: Transform3D=female.transform;var original_gasket: Transform3D=gasket.transform
	var thickness: float=float(stock.data.dimensions.gasket_thickness_m)
	female.transform=stock.union_pose(thickness/float(stock.data.dimensions.pitch_m)*TAU)
	female.basis=Basis.IDENTITY
	gasket.position=Vector3(0,.533-thickness,0)
	var bearing: bool=true
	for i in range(16):
		var angle: float=TAU*i/16.;var radius: float=(float(stock.data.dimensions.bore_radius_m)+gasket.mesh.get_aabb().size.x*.5)*.5
		var origin:=Vector3(radius*cos(angle),.533+.0005,radius*sin(angle))
		var gasket_distance: float=ray_distance(gasket,origin,Vector3.DOWN)
		var seat_distance: float=ray_distance(female,origin,Vector3.DOWN)
		if absf(gasket_distance-.0005)>=.0001 or absf(seat_distance-(.0005+thickness))>=.0001:print("FIRE JOINT BEARING SAMPLE: ",i," gasket=",gasket_distance," seat=",seat_distance)
		bearing=bearing and absf(gasket_distance-.0005)<.0001 and absf(seat_distance-(.0005+thickness))<.0001
	check(bearing,"16 imported sealing rays meet actual gasket top and union shelf within100um")
	female.transform=original_union;gasket.transform=original_gasket
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.1,.1,.1);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;add_child(env)
	env.environment.sky=Sky.new();env.environment.sky.sky_material=ProceduralSkyMaterial.new();env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.light_energy=1.;add_child(sun)
	var camera:=Camera3D.new();camera.fov=40.;camera.position=Vector3(.13,.83,.46);add_child(camera);camera.look_at(Vector3(0,.53,0));camera.make_current()
	var dir: String=OS.get_environment("SHOT_DIR")
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir);await get_tree().create_timer(.5).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("loaded_native_joint.png"))
	print("V2 FIRE JOINT STOCK: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
