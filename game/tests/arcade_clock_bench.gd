extends Node3D
## INERT imported-stock diagnosis. Production qualification remains separate.
const Factory=preload("res://scripts/building/orison_v2_arcade_clock.gd")
var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}
var review_suite: Node
var externally_managed:=false

func _ready() -> void:
	if not externally_managed:_run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if review_suite!=null:review_suite.check(value,label)
	if not value:failures.append(label);push_error(label)

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	var clock:=CampaignClock.new();check(clock.configure_date(1928,10,15,610),"fixture date")
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var packed:=load("res://assets/building/orison_v2/passage/passage.gltf") as PackedScene
	var cell:=packed.instantiate() as Node3D;cell.name="passage";add_child(cell)
	if not Factory.mount_cell(cell,layout):check(false,"exact five-boundary clock mounts");_finish();return
	await validate_cell(cell)
	check(clock.configure_date(1928,10,15,822),"second fixture date")
	var movement:=cell.get_node("ArcadeClock/ClockMovement")
	check(movement.refresh_from_campaign(),"refresh second shared time")
	_check_hands(cell.get_node("ArcadeClock"),822.)
	check(is_equal_approx(clock.minute_of_day(),822.),"display refresh does not alter shared clock")
	await _capture(cell)
	var retired: WeakRef=weakref(cell.get_node("ArcadeClock"));cell.free();await get_tree().process_frame
	check(retired.get_ref()==null,"clock retires with its cell")
	var rejected:=packed.instantiate() as Node3D;rejected.name="passage";add_child(rejected)
	var changed: Dictionary=layout.duplicate(true)
	for floor: Dictionary in changed.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:
			if str(row.id)=="site_passage_crossing_clock_body":row.h=float(row.h)+.01
	var originals: Dictionary={}
	for draw: MeshInstance3D in rejected.find_children("*","MeshInstance3D",true,false):originals[draw]=draw.mesh
	check(not Factory.mount_cell(rejected,changed),"changed authored clock boundary is refused")
	check(not rejected.has_node("ArcadeClock"),"refusal publishes no partial native clock")
	for draw: MeshInstance3D in originals:check(draw.mesh==originals[draw],"refusal retains original source mesh "+str(draw.name))
	rejected.free()
	_finish()

func validate_cell(cell: Node3D) -> void:
	var model:=cell.get_node("ArcadeClock") as Node3D
	var removed: Dictionary=model.get_meta("removed_triangles")
	check(removed.size()==5,"exactly five obsolete boxes retired")
	for key in removed:check(int(removed[key])==12,"complete source box retired: "+str(key))
	var draws:=model.find_children("*","MeshInstance3D",true,false)
	check(draws.size()==13,"thirteen native material draws")
	check(model.find_children("*","Label3D",true,false).size()==48,"four complete numbered dials")
	for label: Label3D in model.find_children("*","Label3D",true,false):
		check(label.shaded and not label.double_sided and not label.no_depth_test,"dial ink is shaded and depth tested: "+str(label.name))
	for draw: MeshInstance3D in draws:
		check(draw.is_visible_in_tree(),"native clock draw visible in mounted cell: "+str(draw.get_meta("arcade_clock_part")))
		_check_surface(draw)
	var glass:=model.get_meta("optical_material") as ShaderMaterial
	check(glass.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader","registered clear dielectric, no water proxy")
	for parameter in ["rough_tex","normal_tex"]:
		var texture:=glass.get_shader_parameter(parameter) as Texture2D
		if texture==null:check(false,"mapped clear-glass finish "+parameter);continue
		var image:=texture.get_image()
		check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.))),"complete loaded clear glass mips: "+parameter)
	var movement:=model.get_node("ClockMovement")
	_check_hands(model,float(movement.displayed_minute))
	await get_tree().physics_frame
	var excluded: Array[RID]=[]
	for body: CollisionObject3D in cell.find_children("*","CollisionObject3D",true,false):
		if not model.is_ancestor_of(body):excluded.append(body.get_rid())
	var origin:=Vector3(14,6.21,51.6)
	for direction: Vector3 in [Vector3.UP,Vector3.DOWN]:
		var query:=PhysicsRayQueryParameters3D.create(cell.to_global(origin+direction*.5),cell.to_global(origin));query.exclude=excluded
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(cell.to_local(hit.get("position",Vector3.ZERO)).distance_to(origin)-.37)<.00004,"native cap closes hanger/finial seat: "+str(direction))

func _check_surface(draw: MeshInstance3D) -> void:
	var valid:=true;var worst:=0.;var smallest:=INF;var minimum_dot:=1.
	for surface in draw.mesh.get_surface_count():
		var arrays:=draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		valid=valid and uv.size()==vertices.size() and tangents.size()==vertices.size()*4 and normals.size()==vertices.size()
		if uv.size()!=vertices.size():continue
		for vertex in vertices.size():
			var tangent:=Vector3(tangents[vertex*4],tangents[vertex*4+1],tangents[vertex*4+2])
			valid=valid and normals[vertex].is_finite() and absf(normals[vertex].length()-1.)<.001 and tangent.is_finite() and absf(tangent.length()-1.)<.001 and absf(tangent.dot(normals[vertex]))<.001 and absf(absf(tangents[vertex*4+3])-1.)<.001
		for triangle in range(0,indices.size(),3):
			var a:=indices[triangle];var b:=indices[triangle+1];var c:=indices[triangle+2]
			var first:=draw.global_basis*(vertices[b]-vertices[a]);var second:=draw.global_basis*(vertices[c]-vertices[a])
			var du:=uv[b]-uv[a];var dv:=uv[c]-uv[a]
			var signed_determinant:=du.x*dv.y-du.y*dv.x
			var determinant:=absf(signed_determinant)
			smallest=minf(smallest,determinant)
			if determinant<=0.:valid=false;continue
			var local_first:=vertices[b]-vertices[a];var local_second:=vertices[c]-vertices[a]
			var derivative: Vector3=(local_first*dv.y-local_second*du.y)/signed_determinant
			var bitangent: Vector3=(local_second*du.x-local_first*dv.x)/signed_determinant
			for index: int in [a,b,c]:
				var expected: Vector3=(derivative-normals[index]*derivative.dot(normals[index])).normalized()
				var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
				minimum_dot=minf(minimum_dot,actual.dot(expected))
				valid=valid and actual.dot(expected)>.999 and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0.
			var ratio:=sqrt(first.cross(second).length()/determinant)
			worst=maxf(worst,absf(ratio-1.))
			valid=valid and is_finite(ratio) and absf(ratio-1.)<.003
	metrics[str(draw.get_meta("arcade_clock_part"))]={"worst_metric_error":worst,"minimum_uv_determinant":smallest,"minimum_tangent_derivative_dot":minimum_dot}
	check(valid,"imported metre UVs and tangent arrays: "+str(draw.get_meta("arcade_clock_part"))+" error="+str(worst))

func _check_hands(model: Node3D,minute: float) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Factory.DATA_PATH))
	for face: Dictionary in data.faces:
		var u:=Vector3(face.u[0],face.u[1],face.u[2]);var up:=Vector3(face.v[0],face.v[1],face.v[2])
		for kind: String in ["hour","minute"]:
			var identity:=str(face.id)+"_"+kind+"_hand";var hand: MeshInstance3D
			for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				if str(draw.get_meta("arcade_clock_part"))==identity:hand=draw
			check(hand!=null,"named native hand: "+identity)
			if hand==null:continue
			var vertices: PackedVector3Array=hand.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var tip:=Vector3.ZERO
			for vertex in vertices:
				if vertex.y>tip.y:tip=vertex
			var angle:=TAU*fposmod(minute,720. if kind=="hour" else 60.)/(720. if kind=="hour" else 60.)
			var actual: Vector3=(hand.basis*Vector3(0,tip.y,0)).normalized()
			check(actual.dot(u*sin(angle)+up*cos(angle))>.999,"clockwise shared time on "+identity)

func _capture(_cell: Node3D) -> void:
	var out:=OS.get_environment("SHOT_DIR")
	if out.is_empty():return
	DirAccess.make_dir_recursive_absolute(out)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.13,.15,.17)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.75,.82,.9);environment.environment.ambient_light_energy=.5;add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.4;light.shadow_enabled=true;add_child(light)
	var camera:=Camera3D.new();add_child(camera);camera.current=true;camera.fov=50
	for shot: Dictionary in [{"name":"detail","at":Vector3(14.85,6.45,50.5)},{"name":"player","at":Vector3(14,1.65,46)},{"name":"underside","at":Vector3(14.65,5.5,50.8)}]:
		camera.position=shot.at;camera.look_at(Vector3(14,6.21,51.6))
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(out.path_join(str(shot.name)+".png"))==OK,"saved "+str(shot.name))

func _finish() -> void:
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	if not out.is_empty():FileAccess.open(out.path_join("clock_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("ARCADE CLOCK BENCH ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
