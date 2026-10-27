extends "res://tests/orison_v2_roof_route_test.gd"
## INERT collider/standing-path measurement. No route or room admission.
var samples: Dictionary={}
var report: Dictionary={}
var standing: CapsuleShape3D
const PITCH:=.1
const CORNER:=Vector2(3.4,-4.2)

func _init() -> void: route_label="ROOF CLEARANCE DIAGNOSTIC"

func _route() -> void:
	if OS.get_environment("SKYWATCH_ROOF_SURVEY")=="1":
		await _survey_skywatch_roof()
		return
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	for point: Vector3 in [Vector3(1.925,17.6,1.3),Vector3(3.975,17.6,1.3),Vector3(3.975,19.2,-3.4)]:
		if not await _walk(point):return
	standing=CapsuleShape3D.new();standing.radius=PlayerController.BODY_RADIUS;standing.height=PlayerController.STANDING_HEIGHT
	report={"evidence_class":"INERT","root_frame":str(world.adapter.root.global_transform),
		"player_frame":str(player.global_transform),"radius":standing.radius,"height":standing.height,
		"arrival":str(world.adapter.root.to_local(player.global_position)),"lamp":_lamp_measurement()}
	var nearest:=Vector2i.ZERO;var distance:=INF
	for x in 23:
		for z in 21:
			var cell:=Vector2i(x,z);var at:=CORNER+Vector2(cell)*PITCH
			var sample:=_standing_sample(Vector3(at.x,19.2,at.y));samples[cell]=sample
			if not sample.clear:continue
			var gap: float=(sample.point-world.adapter.root.to_local(player.global_position)).length()
			if gap<distance:distance=gap;nearest=cell
	var queue: Array[Vector2i]=[];var previous: Dictionary={};var goal:=Vector2i(-1,-1)
	if distance<.20:queue.append(nearest);previous[nearest]=nearest
	var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor];cursor+=1
		var point: Vector3=samples[cell].point
		if point.x>=4.75 and point.z>=-2.6:goal=cell;break
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=cell+offset
			if previous.has(next) or not samples.has(next) or not samples[next].clear:continue
			if not _sweep_clear(point,samples[next].point):continue
			previous[next]=cell;queue.append(next)
	var path: Array[Vector3]=[]
	if goal.x>=0:
		var cell:=goal
		while true:
			path.push_front(samples[cell].point)
			if cell==nearest:break
			cell=previous[cell]
	report["nearest_clear_distance"]=distance;report["reachable_cells"]=previous.size()
	report["path_found"]=not path.is_empty();report["planned_path"]=path.map(func(p: Vector3):return [p.x,p.y,p.z])
	var rows: Array=[]
	for cell: Vector2i in samples:
		var row: Dictionary=samples[cell].duplicate();var p: Vector3=row.point
		row.point=[p.x,p.y,p.z];row.cell=[cell.x,cell.y];rows.append(row)
	report["standing_samples"]=rows
	# Exercise the production route helper's measured detour both ways.
	if not path.is_empty():
		report["executed_path"]=[]
		for point: Vector3 in [Vector3(5,19.2,-3.4),Vector3(5,19.2,2.5),Vector3(5,19.2,-3.4)]:
			var ok:=await _walk(point);report.executed_path.append({"target":str(point),"ok":ok})
			if not ok:break
	var lamp_check:=preload("res://tests/orison_v2_roof_program_contract_test.gd").new()
	lamp_check._check_light_rotation(player);report["lamp_checks"]=lamp_check.checks.duplicate(true)
	for check: Dictionary in lamp_check.checks:
		if not check.ok:failures.append(str(check.label))
	lamp_check.free()
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("clearance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=65.
	camera.global_position=world.adapter.root.to_global(Vector3(4.5,21.65,-3.1))
	camera.look_at(world.adapter.root.to_global(Vector3(4.5,19.2,-3.1)),world.adapter.root.global_basis.z)
	camera.make_current()
	for cell: Vector2i in samples:
		var sample: Dictionary=samples[cell];var draw:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.025,.008,.025)
		draw.mesh=mesh;draw.position=sample.point+Vector3.UP*.025
		var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		finish.albedo_color=Color(.1,.8,.2) if sample.clear else Color(.8,.08,.05);draw.material_override=finish
		world.adapter.root.add_child(draw)
	for frame in 4:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("clearance_overhead.png"))
	print("ROOF CLEARANCE: path=",report.path_found," nearest=",distance," reachable=",previous.size()," lamp=",report.lamp)

func _standing_sample(at: Vector3) -> Dictionary:
	var root: Node3D=world.adapter.root;var space:=world.get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.08),root.to_global(at-Vector3.UP*.10),1,[player.get_rid()])
	var floor: Dictionary=space.intersect_ray(ray)
	var row: Dictionary={"point":at,"clear":false,"floor":"","colliders":[]}
	if floor.is_empty():return row
	row.floor=str(root.get_path_to(floor.collider));var point: Vector3=root.to_local(floor.position)
	if absf(point.y-at.y)>.025 or floor.normal.dot(Vector3.UP)<.9:return row
	row.point=point
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=standing;query.collision_mask=1;query.margin=0.;query.exclude=[player.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,root.to_global(point)+Vector3.UP*(standing.height*.5+player.safe_margin))
	var hits:=space.intersect_shape(query,8)
	for hit: Dictionary in hits:row.colliders.append(str(root.get_path_to(hit.collider)))
	row.clear=hits.is_empty();return row

func _sweep_clear(from: Vector3,to: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=standing;query.collision_mask=1;query.margin=0.;query.exclude=[player.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,world.adapter.root.to_global(from)+Vector3.UP*(standing.height*.5+player.safe_margin))
	query.motion=world.adapter.root.global_basis*(to-from)
	var result:=world.get_world_3d().direct_space_state.cast_motion(query)
	return result[0]>=.99999

func _lamp_measurement() -> Dictionary:
	var original: Transform3D=player._hand.transform
	player._hand.basis=Basis(Vector3.UP,.7).scaled(Vector3(1.00012,1.00001,.9999))
	for frame in 240:player._carry_service_light(1./60.)
	var focus: Vector3=player.camera.global_position-player.camera.global_basis.z*player._carried_light_pose.last_focus
	var actual: Basis=player._hand.global_basis
	var data: Dictionary={"local_determinant":player._hand.basis.determinant(),"global_determinant":actual.determinant(),
		"player_determinant":player.global_basis.determinant(),"focus_distance":player._carried_light_pose.last_focus,
		"focus_alignment":(-actual.z).normalized().dot((focus-player._hand.global_position).normalized())}
	player._hand.transform=original;return data

func _survey_skywatch_roof() -> void:
	# Authoring survey only: initial diagnostic placement and posed cameras.
	# This mode does not execute or qualify the inherited roof route.
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	player.set_physics_process(false)
	player.global_position=world.adapter.root.to_global(Vector3(3.,19.25,-9.))
	player.velocity=Vector3.ZERO
	CampaignTime.set_frozen_for_tests(true)
	world.campaign_clock.configure_date(1928,11,10,720)
	world.day_night_director._apply(720.)
	standing=CapsuleShape3D.new()
	standing.radius=PlayerController.BODY_RADIUS;standing.height=PlayerController.STANDING_HEIGHT
	var rows: Array[Dictionary]=[]
	var root: Node3D=world.adapter.root
	var space := world.get_world_3d().direct_space_state
	for x in range(63):
		for z in range(47):
			var at := Vector3(-15.5+float(x)*.5,19.2,-12.+float(z)*.5)
			var ray := PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.45),root.to_global(at-Vector3.UP*.25),1,[player.get_rid()])
			var floor_hit := space.intersect_ray(ray)
			var row := {"xz":[at.x,at.z],"clear":false,"floor":"","colliders":[]}
			if not floor_hit.is_empty():
				var foot: Vector3=root.to_local(floor_hit.position)
				row["floor"]=str(root.get_path_to(floor_hit.collider));row["floor_y"]=foot.y
				if floor_hit.normal.dot(Vector3.UP)>.9:
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape=standing;query.collision_mask=player.collision_mask;query.margin=0.;query.exclude=[player.get_rid()]
					query.transform=Transform3D(root.global_basis.orthonormalized(),root.to_global(foot)+Vector3.UP*(standing.height*.5+player.safe_margin))
					var hits := space.intersect_shape(query,16)
					for hit: Dictionary in hits:row.colliders.append(str(root.get_path_to(hit.collider)))
					row.clear=hits.is_empty()
			rows.append(row)
		await get_tree().physics_frame
	var geometry: Array[Dictionary]=[]
	for draw: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null:continue
		var bounds := draw.get_aabb()
		var local := AABB(root.to_local(draw.to_global(bounds.position)),Vector3.ZERO)
		for corner in range(8):local=local.expand(root.to_local(draw.to_global(bounds.get_endpoint(corner))))
		if local.end.y<19.05 or local.position.y>25. or local.end.x< -15.7 or local.position.x>15.7 or local.end.z< -12.4 or local.position.z>11.7:continue
		geometry.append({"node":str(root.get_path_to(draw)),"minimum":[local.position.x,local.position.y,local.position.z],"maximum":[local.end.x,local.end.y,local.end.z],"visible":draw.is_visible_in_tree(),"mesh":draw.mesh.resource_path})
	var survey := {"evidence_class":"INERT","scope":"posed authoring survey, not played access or runtime qualification","root_transform":str(root.global_transform),"standing_radius":standing.radius,"standing_height":standing.height,"collision_mask":player.collision_mask,"grid_pitch":.5,"standing_samples":rows,"geometry":geometry,"script_sha256":FileAccess.get_sha256(get_script().resource_path)}
	FileAccess.open(directory.path_join("skywatch_roof_survey.json"),FileAccess.WRITE).store_string(JSON.stringify(survey,"\t")+"\n")
	var camera := Camera3D.new();world.add_child(camera);camera.make_current()
	for pose: Dictionary in [{"name":"roof_overhead","eye":Vector3(0,50,0),"target":Vector3(0,19.2,0),"ortho":true},{"name":"roof_southwest","eye":Vector3(-13,20.85,-10),"target":Vector3(2,20.5,2),"ortho":false},{"name":"roof_northwest","eye":Vector3(-13,20.85,9),"target":Vector3(1,20.5,-4),"ortho":false},{"name":"roof_south","eye":Vector3(3,20.85,-9),"target":Vector3(-6,20.5,-4),"ortho":false}]:
		camera.global_position=root.to_global(pose.eye)
		camera.look_at(root.to_global(pose.target),root.global_basis.z if pose.ortho else Vector3.UP)
		if pose.ortho:camera.set_orthogonal(40.,.05,100.)
		else:camera.set_perspective(78.,.05,2000.)
		for frame in range(20):await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(str(pose.name)+".png"))
	camera.queue_free()
	print("SKYWATCH ROOF SURVEY: ",rows.size()," standing samples; ",geometry.size()," bounded mesh records; posed diagnostic only")
