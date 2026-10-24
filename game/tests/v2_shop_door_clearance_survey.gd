extends "res://tests/orison_v2_vertical_route_test.gd"
## Proposed fit survey only. It never changes a production leaf or collision.
func _init() -> void: route_label="V2 SHOP DOOR CLEARANCE SURVEY"

func _prepare_player_start() -> void:
	# Keep the original resident passage from retiring during the survey.
	var first_z := INF
	for door: DoorProp in world.passage_region.doors.values(): first_z=minf(first_z,door.global_position.z)
	player.global_position=Vector3(12.4,.04,first_z-2.0)
	player.velocity=Vector3.ZERO

func _route() -> void:
	for i in 4: await get_tree().physics_frame
	var rows: Array = []
	for identity: String in world.passage_region.doors:
		var door: DoorProp=world.passage_region.doors[identity]
		var source: CollisionShape3D=door._body.get_child(0)
		var proposed := source.shape.duplicate() as BoxShape3D
		# Keep the original upper bearing. Raise the leaf's lower bound by 6 mm.
		proposed.size.y-=.006
		var samples: Array=[]
		for degree in range(0,101,2):
			var pose:=door._body.transform
			pose.basis=Basis(Vector3.UP,deg_to_rad(degree)*(-1.0 if door.swing_out else 1.0))
			var local:=source.transform;local.origin.y+=.003
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=proposed;query.transform=door.global_transform*pose*local
			query.collision_mask=door._body.collision_mask;query.exclude=[door._body.get_rid()];query.margin=.001
			var hits: Array=[]
			for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,32):
				hits.append({"owner":str(hit.collider.get_path()),"shape":hit.shape})
			samples.append({"degrees":degree,"hits":hits})
		rows.append({"id":identity,"locked":door.leaf_state=="locked","samples":samples})
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("proposed_clearance.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","kind":"proposed_collision_fit_survey","raised_bottom_mm":6,"sample_step_degrees":2,"doors":rows},"\t"))
	print("SHOP DOOR PROPOSED CLEARANCE: ",rows.size()," original actors sampled; no production changes")
