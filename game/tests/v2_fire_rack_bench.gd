extends Node3D
## Loaded native rack/cloth contacts and original controls; no room or human grant.
const HandBench=preload("res://tests/v2_fire_hand_bench.gd")
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
var failures: Array[String]=[]
var face_cache: Dictionary={}
var millimetre_cache: Dictionary={}
var _miss_written:=false
var precise_fallbacks:=0
static func _ray_triangle_time(origin: Vector3,axis: Vector3,a: Vector3,b: Vector3,c: Vector3) -> float:
	# Scalar GDScript floats keep the arithmetic in64bits. Vector3 cross/dot
	# operations round to32bits in this build and can reject both sides of a
	# shared edge. Barycentric bounds remain strict: no expanded triangle.
	var ex: float=float(b.x)-float(a.x);var ey: float=float(b.y)-float(a.y);var ez: float=float(b.z)-float(a.z)
	var fx: float=float(c.x)-float(a.x);var fy: float=float(c.y)-float(a.y);var fz: float=float(c.z)-float(a.z)
	var px: float=float(axis.y)*fz-float(axis.z)*fy
	var py: float=float(axis.z)*fx-float(axis.x)*fz
	var pz: float=float(axis.x)*fy-float(axis.y)*fx
	var determinant: float=ex*px+ey*py+ez*pz
	if determinant==0.:return INF
	var sx: float=float(origin.x)-float(a.x);var sy: float=float(origin.y)-float(a.y);var sz: float=float(origin.z)-float(a.z)
	var u: float=(sx*px+sy*py+sz*pz)/determinant
	if u<0. or u>1.:return INF
	var qx: float=sy*ez-sz*ey;var qy: float=sz*ex-sx*ez;var qz: float=sx*ey-sy*ex
	var v: float=(float(axis.x)*qx+float(axis.y)*qy+float(axis.z)*qz)/determinant
	if v<0. or u+v>1.:return INF
	var t: float=(fx*qx+fy*qy+fz*qz)/determinant
	return t if t>0. else INF
func stock_ray(draw: MeshInstance3D, origin: Vector3, direction: Vector3) -> float:
	var local: Vector3=draw.to_local(origin)*1000.
	var axis: Vector3=draw.global_basis.inverse()*direction
	if not face_cache.has(draw.mesh):face_cache[draw.mesh]=preload("res://scripts/props/fire_hose_rack.gd").imported_faces(draw.mesh)
	var faces: PackedVector3Array=face_cache[draw.mesh]
	if not millimetre_cache.has(draw.mesh):
		var scaled:=PackedVector3Array()
		for point: Vector3 in faces:scaled.append(point*1000.)
		millimetre_cache[draw.mesh]=scaled
	var scaled: PackedVector3Array=millimetre_cache[draw.mesh]
	var distance: float=INF
	for i in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(local,axis,scaled[i],scaled[i+1],scaled[i+2])
		if hit is Vector3:distance=minf(distance,(draw.global_basis*((hit-local)/1000.)).length())
	if not is_finite(distance):
		precise_fallbacks+=1
		var nearest:=INF
		for i in range(0,scaled.size(),3):nearest=minf(nearest,_ray_triangle_time(local,axis,scaled[i],scaled[i+1],scaled[i+2]))
		distance=nearest*(draw.global_basis*axis).length()/1000.
	var diagnostic: String=OS.get_environment("ORISON_RACK_DIAGNOSTIC_DIR")
	if not is_finite(distance) and not _miss_written and not diagnostic.is_empty() and str(draw.get_meta("rack_stock",""))=="CarrierArm":
		DirAccess.make_dir_recursive_absolute(diagnostic)
		var triangles: Array=[]
		for point: Vector3 in faces:triangles.append([point.x*1000.,point.y*1000.,point.z*1000.])
		FileAccess.open(diagnostic.path_join("arm_ray_miss.json"),FileAccess.WRITE).store_string(JSON.stringify({"origin":[local.x,local.y,local.z],"direction":[axis.x,axis.y,axis.z],"triangles":triangles},"\t"))
		_miss_written=true
	return distance
func bearing_measure(arm: MeshInstance3D,crown: MeshInstance3D,point: Vector3,up: Vector3) -> Dictionary:
	# The tip datum is inside the 6mm curved bearing. Trace upward from
	# inside both nested profiles to compare arm top with cloth inner crown.
	# The reverse ray sees the underside of the arm, not its bearing face.
	var arm_distance: float=stock_ray(arm,point-up*.002,up)
	var cloth_distance: float=stock_ray(crown,point-up*.002,up)
	var gap: float=cloth_distance-arm_distance
	return {"ok":is_finite(arm_distance) and is_finite(cloth_distance) and absf(gap)<.0001,"gap":gap,"arm":arm_distance,"cloth":cloth_distance}
func _ray_regression() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fire_rack_shared_edge_ray.json"))
	var at:=Vector3(data.origin_mm[0],data.origin_mm[1],data.origin_mm[2]);var direction:=Vector3(data.direction[0],data.direction[1],data.direction[2])
	var nearest:=INF;var native_hits:=0
	for row: Array in data.triangles_mm:
		var a:=Vector3(row[0][0],row[0][1],row[0][2]);var b:=Vector3(row[1][0],row[1][1],row[1][2]);var c:=Vector3(row[2][0],row[2][1],row[2][2])
		nearest=minf(nearest,_ray_triangle_time(at,direction,a,b,c))
		if Geometry3D.ray_intersects_triangle(at,direction,a,b,c) is Vector3:native_hits+=1
		check(not is_finite(_ray_triangle_time(at,-direction,a,b,c)),"captured triangle rejects reverse ray")
		check(not is_finite(_ray_triangle_time(at+Vector3(1000,0,0),direction,a,b,c)),"captured triangle rejects outside ray")
		check(not is_finite(_ray_triangle_time(at,Vector3.ZERO,a,b,c)),"captured triangle rejects zero direction")
	check(absf(nearest-float(data.nearest_forward_mm))<.000000001,"strict scalar64 captured shared-edge distance agrees within1pm")
	print("CAPTURED RAY REGRESSION: native_hits=",native_hits," scalar64_mm=",nearest)
func _rack_matrix(native: RefCounted,angle: float) -> void:
	var ordinal:=0
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref()
		actor.global_transform=Transform3D(Basis(Vector3.UP,angle),Vector3(-4.349999,-2.+ordinal*3.2,-7.87));ordinal+=1
		var rack: Node3D=actor.get_node("NativeHoseRack")
		var saved: Dictionary=actor.mechanism_snapshot()
		for fresh: bool in [false,true]:
			var facts: Dictionary=saved.facts.duplicate(true);facts.folds_fresh=fresh;actor.restore_maintenance_snapshot(facts)
			await get_tree().process_frame;await get_tree().process_frame
			for index in 10:
				var arm: MeshInstance3D=rack.arms[index];var crown: MeshInstance3D=actor._fold_leaves[index].get_node("NativeFoldCrown")
				var tip:=Vector3(rack.data.tip_local_m[0],rack.data.tip_local_m[1],rack.data.tip_local_m[2]);var ok:=true
				for offset: float in [-.002,-.001,0.,.001,.002]:
					var result: Dictionary=bearing_measure(arm,crown,arm.to_global(tip)+actor.global_basis.x*offset,actor.global_basis.y)
					if not result.ok:print("RACK MATRIX GAP: ",identity," ",fresh," ",index," ",offset," ",result)
					ok=ok and result.ok
				check(ok,identity+" five imported bearings within100um "+str([fresh,index]))
				var before: Vector3=crown.position;crown.position.y+=.001
				check(not bearing_measure(arm,crown,arm.to_global(tip),actor.global_basis.y).ok,identity+" displaced crown fails contact "+str([fresh,index]))
				crown.position=before
		actor.restore_mechanism(saved)
	print("RACK MATRIX ORIENTATION: ",angle," failures=",failures.size()," precise_fallbacks=",precise_fallbacks)
func check(ok: bool,label: String) -> void:
	print("FIRE RACK CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func shot(name: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory);await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))==OK,"actual rack frame saved: "+name)
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var arena:=Node3D.new();add_child(arena)
	var adapter:=HandBench.FixtureAdapter.new();adapter.root=arena
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";arena.add_child(reserve)
	var native:=preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
	if not native.mount(adapter,{"levels":[{"y":0.}]}):push_error(str(native.errors));get_tree().quit(1);return
	if OS.get_environment("ORISON_FIRE_RACK_WORLD_MATRIX")=="1":
		_ray_regression()
		for angle: float in [PI,-PI]:await _rack_matrix(native,angle)
		print("V2 FIRE RACK WORLD MATRIX: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size(),"; native geometry fixture only")
		get_tree().quit(0 if failures.is_empty() else 1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	var rack: Node3D=actor.get_node("NativeHoseRack")
	var metrics: Node=Metrics.new()
	check(rack.meshes.size()==5 and rack.arms.size()==10,"five imported templates form ten independently fitted carrier arms")
	for key: String in rack.meshes:
		metrics._check_cap_mapping(rack.meshes[key],true)
		var mat: StandardMaterial3D=rack.finishes[rack.data.parts[key]]
		check(mat.normal_enabled and not mat.uv1_triplanar,"authored UVs and active normal mapping: "+key)
		for texture: Texture2D in [mat.albedo_texture,mat.roughness_texture,mat.normal_texture]:check(texture!=null and texture.get_image().get_mipmap_count()>0,"real loaded rack PBR mip chain: "+key)
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	var wall: MeshInstance3D
	var retired: int=0
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		var id: String=str(draw.get_meta("native_fire_part",""))
		if id=="F007":wall=draw
		if id in ["F034","F035","F036"] and draw.mesh==null:retired+=1
	check(retired==3,"both old primitive pins and old bar are retired on retained nodes")
	var case_contacts: bool=wall!=null
	var case_samples: int=0
	for draw: MeshInstance3D in rack.get_children():
		if str(draw.get_meta("rack_stock",""))!="MountBracket":continue
		for y: float in [-.012,-.006,.006,.012]:
			var point: Vector3=actor.to_global(Vector3(draw.position.x,float(rack.data.pivot_y_m)+y,.019))
			var direction: Vector3=actor.global_basis*Vector3.FORWARD
			case_contacts=case_contacts and absf(stock_ray(draw,point,direction)-.001)<.0001 and absf(stock_ray(wall,point,direction)-.001)<.0001
			case_samples+=1
	check(case_contacts and case_samples==8,"eight loaded bracket bearings meet the actual cabinet back within100um")
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.5;arena.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.10,.10,.10);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;arena.add_child(env)
	env.environment.sky=Sky.new();env.environment.sky.sky_material=ProceduralSkyMaterial.new();env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var camera:=Camera3D.new();camera.fov=48.;arena.add_child(camera);camera.make_current()
	for arm: MeshInstance3D in rack.arms:
		var vertices: PackedVector3Array=arm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var maximum: float=-INF
		for vertex: Vector3 in vertices:maximum=maxf(maximum,vertex.y)
		var collider: CollisionShape3D=arm.get_node("NativeRackCollision").get_child(0)
		var collision_max: float=-INF
		for vertex: Vector3 in collider.shape.get_faces():collision_max=maxf(collision_max,vertex.y)
		check(absf(maximum-.01995)<.000001 and absf(collision_max-maximum)<.000001,"imported rounded bearing and physics retain native micrometre precision")
	var facts: Dictionary=actor.maintenance_snapshot()
	for fresh: bool in [false,true]:
		var pose: Dictionary=facts.duplicate(true);pose.door_open=true;pose.folds_fresh=fresh;actor.restore_maintenance_snapshot(pose)
		await get_tree().process_frame;await get_tree().process_frame
		for index in range(10):
			var arm: MeshInstance3D=rack.arms[index]
			var crown: MeshInstance3D=actor._fold_leaves[index].get_node("NativeFoldCrown")
			var tip:=Vector3(rack.data.tip_local_m[0],rack.data.tip_local_m[1],rack.data.tip_local_m[2])
			var contact: bool=true
			for offset: float in [-.002,-.001,0.,.001,.002]:
				var point: Vector3=arm.to_global(tip)+actor.global_basis*Vector3.RIGHT*offset
				var direction: Vector3=actor.global_basis*Vector3.UP
				var a: float=stock_ray(arm,point,direction);var c: float=stock_ray(crown,point,direction)
				if not is_finite(a) or not is_finite(c) or absf(a-c)>=.0001:print("RACK BEARING SAMPLE ",fresh," ",index," ",offset," arm=",a," cloth=",c)
				contact=contact and is_finite(a) and is_finite(c) and absf(a-c)<.0001
			check(contact,"five imported contact rays fit actual fold "+str(index)+" fresh="+str(fresh))
		camera.global_position=actor.to_global(Vector3(.12,.57,.72));camera.look_at(actor.to_global(Vector3(-.10,.32,.10)))
		await shot("rack_fresh" if fresh else "rack_original")
		if not fresh:
			camera.global_position=actor.to_global(Vector3(.06,.34,.52));camera.look_at(actor.to_global(Vector3(-.11,.405,.06)))
			await shot("rack_underside")
	arena.free();await get_tree().process_frame
	print("V2 FIRE RACK STOCK: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	if not failures.is_empty():get_tree().quit(1);return
	var hands: Node3D=HandBench.new();add_child(hands)
