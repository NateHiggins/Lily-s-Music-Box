extends "res://tests/v2_fire_rack_bench.gd"
## Exact native annular throat/S-ring contacts, then retained rack/hand checks.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var arena:=Node3D.new();add_child(arena)
	var adapter:=HandBench.FixtureAdapter.new();adapter.root=arena
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";arena.add_child(reserve)
	var native:=preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
	if not native.mount(adapter,{"levels":[{"y":0.}]}):push_error(str(native.errors));get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	var folds: Node3D=actor.get_node("NativeContinuousFolds")
	var metrics: Node=Metrics.new()
	for key: String in folds.meshes:metrics._check_cap_mapping(folds.meshes[key],true)
	for key: String in ["NozzleSocket","HoseTail00","HoseTail01","HoseTail10","HoseTail11"]:metrics._check_cap_mapping(native.meshes[key],true)
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	check(folds.meshes.size()==12 and folds.returns.size()==9,"twelve native templates make continuous folds and both end transitions")
	var finish: StandardMaterial3D=actor._fold_leaves.back().material_override
	check(finish.normal_enabled and not finish.uv1_triplanar,"continuous cloth uses authored UVs and active normal mapping")
	for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:check(texture.get_image().get_mipmap_count()>0,"actual folded cloth PBR mip chain")
	var facts: Dictionary=actor.maintenance_snapshot()
	for fresh: bool in [false,true]:
		var pose: Dictionary=facts.duplicate(true);pose.folds_fresh=fresh;actor.restore_maintenance_snapshot(pose)
		await get_tree().process_frame;await get_tree().process_frame
		var throat: MeshInstance3D=actor._fold_leaves.back().get_node("NativeFoldCrown")
		var hose: MeshInstance3D=actor.get_node("NativeHoseRuns")._live_lead
		var first: Vector3=actor.flexible_outlet_hose_points().first
		var bearing: bool=true
		for index in range(32):
			var angle: float=TAU*index/32.
			var point: Vector3=actor.to_global(first+Vector3(.020*cos(angle),.00002,.020*sin(angle)))
			var direction: Vector3=actor.global_basis*Vector3.DOWN
			var left: float=stock_ray(throat,point,direction);var right: float=stock_ray(hose,point,direction)
			if absf(left-.00002)>.0001 or absf(right-.00002)>.0001:print("FOLD THROAT BEARING ",fresh," ",index," ",left," ",right)
			bearing=bearing and absf(left-.00002)<.0001 and absf(right-.00002)<.0001
		check(bearing,"32 actual imported annular seams join throat to live S-curve within100um fresh="+str(fresh))
		var open: bool=true
		for radius: float in [0.,.005,.010,.015]:
			var point: Vector3=actor.to_global(first+Vector3(radius,.00002,0))
			for draw: MeshInstance3D in [throat,hose]:open=open and stock_ray(draw,point,actor.global_basis*Vector3.DOWN)>.00004
		check(open,"positive neighboring annular hits do not fill the actual seam bore")
		for index in range(1,10):
			var here: Node3D=actor._fold_leaves[index];var previous: Node3D=actor._fold_leaves[index-1]
			var turn: MeshInstance3D=folds.returns[index-1]
			var current: Vector3=here.to_global(Vector3(-.010,-.131,0))
			var prior: Vector3=previous.to_global(Vector3(.010,-.131,0))
			var bounds: AABB=turn.mesh.get_aabb()
			check(turn.to_local(current).distance_to(Vector3.ZERO)<.000001 and absf(turn.to_local(prior).x+.0095)<.000001 and absf(turn.to_local(prior).y-clampf(turn.to_local(prior).y,bounds.position.y,bounds.end.y))<.000001,"return connects successive retained fold endpoints "+str([fresh,index]))
			var seams: bool=true
			for pair: Array in [[current,here],[prior,previous]]:
				for sample in range(4):
					var angle: float=TAU*(sample+.5)/4.
					var point: Vector3=pair[0]+actor.global_basis*Vector3(.003025*cos(angle),.00002,.030525*sin(angle))
					for draw: MeshInstance3D in [turn,pair[1]]:
						var distance: float=stock_ray(draw,point,actor.global_basis*Vector3.DOWN)
						if absf(distance-.00002)>=.0001:print("FOLD RETURN BEARING ",fresh," ",index," ",sample," ",draw.name," ",distance)
						seams=seams and absf(distance-.00002)<.0001
			check(seams,"eight actual annular bearings join each return to both neighboring folds "+str([fresh,index]))
	for fresh: bool in [false,true]:
		for coupled: bool in [false,true]:
			var state: Dictionary=facts.duplicate(true);state.folds_fresh=fresh;state.nozzle_coupled=coupled;actor.restore_maintenance_snapshot(state)
			await get_tree().process_frame;await get_tree().process_frame
			var connection: Dictionary=folds.nozzle_connection()
			var axis: Vector3=connection.axis
			var radial: Vector3=axis.cross(actor.global_basis*Vector3.BACK).normalized()
			var side: Vector3=radial.cross(axis).normalized()
			var throat: MeshInstance3D=folds.nozzle_throat
			var hose: MeshInstance3D=actor.get_node("NativeHoseRuns").tail
			var bearing: bool=true
			for sample in range(32):
				var angle: float=TAU*sample/32.
				var origin: Vector3=connection.at+radial*.020*cos(angle)+side*.020*sin(angle)+axis*.00002
				for draw: MeshInstance3D in [throat,hose]:
					var distance: float=stock_ray(draw,origin,-axis)
					if absf(distance-.00002)>=.0001:print("NOZZLE MOUTH SAMPLE ",fresh," ",coupled," ",sample," ",draw.name," ",distance)
					bearing=bearing and absf(distance-.00002)<.0001
			check(bearing,"32 actual oblique annular bearings connect nozzle hose to round/flat throat "+str([fresh,coupled]))
			var flat: bool=true
			for sample in range(8):
				var angle: float=TAU*(sample+.5)/8.
				var point: Vector3=actor._fold_leaves[0].to_global(Vector3(-.010+.003025*cos(angle),-.091+.00002,.030525*sin(angle)))
				for draw: MeshInstance3D in [throat,actor._fold_leaves[0]]:flat=flat and absf(stock_ray(draw,point,actor.global_basis*Vector3.DOWN)-.00002)<.0001
			check(flat,"eight actual flattened annular bearings meet the shortened first strand "+str([fresh,coupled]))
			var open: bool=true
			for radius: float in [0.,.005,.010,.015]:
				var point: Vector3=connection.at+radial*radius+axis*.00002
				for draw: MeshInstance3D in [throat,hose]:open=open and stock_ray(draw,point,-axis)>.00004
			check(open,"nozzle transition retains its actual clear bore beside positive cloth hits")
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.5;arena.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.1,.1,.1);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;arena.add_child(env)
	var camera:=Camera3D.new();camera.fov=38.;arena.add_child(camera);camera.make_current()
	camera.global_position=actor.to_global(Vector3(.21,.63,.61));camera.look_at(actor.to_global(Vector3(.035,.455,.1)))
	var pose: Dictionary=facts.duplicate(true);pose.door_open=true;actor.restore_maintenance_snapshot(pose)
	await shot("connected_fold_throat")
	camera.global_position=actor.to_global(Vector3(.03,.26,.47));camera.look_at(actor.to_global(Vector3(-.23,.15,.10)))
	await get_tree().process_frame;await get_tree().process_frame
	await shot("connected_nozzle_transition")
	arena.free();face_cache.clear();await get_tree().process_frame
	print("V2 FIRE FOLD STOCK: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	if not failures.is_empty():get_tree().quit(1);return
	await super._run()
