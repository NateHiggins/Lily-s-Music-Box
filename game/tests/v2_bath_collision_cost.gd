extends Node
## INERT query attribution. Exclusions affect isolated diagnostic queries only.
var world: Node3D
var player: PlayerController
var directory: String

func _ready() -> void:
	run.call_deferred()

func measure(excluded: Array[RID],motion: Vector3) -> Dictionary:
	var query:=PhysicsTestMotionParameters3D.new()
	query.from=player.global_transform;query.motion=motion
	query.margin=player.safe_margin;query.exclude_bodies=excluded
	var timings: Array=[]
	var hit:=false
	for repeat in 5:
		var started:=Time.get_ticks_usec()
		hit=PhysicsServer3D.body_test_motion(player.get_rid(),query)
		timings.append((Time.get_ticks_usec()-started)/1000.)
	return {"ms":timings,"hit":hit}

func run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	if world.startup_failed:get_tree().quit(1);return
	player=world.player;player.set_physics_process(false)
	await get_tree().physics_frame
	# Exact overlap queries omit large concave bounds whose triangles do not
	# touch the capsule. Attribute those query candidates by global exclusion
	# bisection, without changing any body's production layers or exceptions.
	var global_bodies: Array[PhysicsBody3D]=[]
	for body: PhysicsBody3D in world.find_children("*","PhysicsBody3D",true,false):
		if body!=player and (body.collision_layer&player.collision_mask)!=0:global_bodies.append(body)
	player.global_position=Vector3(-14.325,6.400265,-.575)
	await get_tree().physics_frame
	var attribution_motion:=Vector3(.05,0,0)
	var baseline: Dictionary=measure([],attribution_motion)
	var remaining: Array[PhysicsBody3D]=global_bodies.duplicate()
	var attribution: Array=[]
	while remaining.size()>1:
		var half: int=remaining.size()/2
		var left: Array[RID]=[];var right: Array[RID]=[]
		for index in remaining.size():
			if index<half:left.append(remaining[index].get_rid())
			else:right.append(remaining[index].get_rid())
		var without_left:=measure(left,attribution_motion);var without_right:=measure(right,attribution_motion)
		attribution.append({"candidates":remaining.size(),"without_left":without_left,"without_right":without_right})
		remaining=remaining.slice(0,half) if median(without_left.ms)<median(without_right.ms) else remaining.slice(half)
		await get_tree().process_frame
	var expensive: PhysicsBody3D=remaining[0]
	FileAccess.open(directory.path_join("global_attribution.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","baseline":baseline,"body_count":global_bodies.size(),"steps":attribution,"suspect":str(expensive.get_path()),"suspect_excluded":measure([expensive.get_rid()],attribution_motion)},"\t"))
	var records: Array=[]
	for feet: Vector3 in [Vector3(-14.325,6.400265,-.575),Vector3(-14.684,6.700265,-.303697)]:
		player.global_position=feet
		await get_tree().physics_frame
		var box:=BoxShape3D.new();box.size=Vector3(3,3,3)
		var spatial:=PhysicsShapeQueryParameters3D.new();spatial.shape=box
		spatial.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*.8)
		spatial.collision_mask=player.collision_mask;spatial.exclude=[player.get_rid()]
		var hits:=player.get_world_3d().direct_space_state.intersect_shape(spatial,512)
		var bodies: Dictionary={}
		for hit: Dictionary in hits:
			if hit.collider is PhysicsBody3D:bodies[hit.collider.get_instance_id()]=hit.collider
		var all: Array[RID]=[]
		for body: PhysicsBody3D in bodies.values():all.append(body.get_rid())
		var motions: Array=[]
		for motion: Vector3 in [Vector3(.05,0,0),Vector3(0,-.01,0),Vector3(0,0,.05)]:
			var row: Dictionary={"motion":str(motion),"baseline":measure([],motion),"all_nearby_excluded":measure(all,motion),"owners":[]}
			for body: PhysicsBody3D in bodies.values():
				var geometry: Array=[]
				for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
					geometry.append({"type":shape.shape.get_class(),"triangles":shape.shape.get_faces().size()/3 if shape.shape is ConcavePolygonShape3D else 0})
				row.owners.append({"path":str(body.get_path()),"shapes":geometry,"excluded":measure([body.get_rid()],motion)})
			motions.append(row)
			await get_tree().process_frame
		records.append({"feet":str(feet),"query_hits":hits.size(),"unique_bodies":bodies.size(),"motions":motions})
	FileAccess.open(directory.path_join("collision_cost.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"limits":"Synchronous isolated body_test_motion queries at two observed production positions; no bypass installed and no runtime qualification."},"\t"))
	print("BATH COLLISION COST: PASS diagnostic only")
	get_tree().quit()

func median(values: Array) -> float:
	var sorted:=values.duplicate();sorted.sort();return float(sorted[sorted.size()/2])
