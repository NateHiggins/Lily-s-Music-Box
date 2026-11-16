extends RefCounted
## Finite independent native-ray witness only; no exhaustive support/fit claim.
var failures: Array[String] = []
var checks := 0
var rays: Array[Dictionary] = []

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	return validate_in_region(world.bar_region)

func validate_in_region(region: OrisonV2BarRegion) -> Dictionary:
	var before := JSON.stringify(RealityState.data).sha256_text()
	var cell := region.get_node_or_null("RetainedBarGeometry") as Node3D
	if cell == null: return _result(false, "actual retained cell missing")
	var pets := cell.get_node_or_null("HarukiyaPets") as Node3D
	if pets == null: return _result(false, "actual mounted pets missing")
	if pets.get_node_or_null("CounterRecess") == null: return _result(false,"actual counter root missing")
	var ids := {"judge":0,"lafitte":0}
	for node: Node in pets.find_children("*","Node",true,false):
		_check(node.get_script() == null, "owned native node has no new authority script: "+str(node.name))
		if node.has_meta("harukiya_pet_identity"):
			var identity := str(node.get_meta("harukiya_pet_identity"))
			_check(ids.has(identity),"only declared animal identity")
			if ids.has(identity): ids[identity] += 1
		if node is CollisionObject3D:
			_check(pets.get_node("CounterRecess").is_ancestor_of(node),"only native counter adds collision")
	_check(ids == {"judge":1,"lafitte":1},"exactly one Judge and Lafitte, no duplicate actors")
	for x: float in [-.45,-.05,.35]:
		for z: float in [-2.72,-2.55,-2.35]:
			_probe(region,cell,[x,-30.4,z],[x,-29.6,z],1,-29.78,"recess reaches actual rear",true)
	for x: float in [-.6,.5]:
		for z: float in [-2.72,-2.55,-2.35]:
			_probe(region,cell,[x,-30.4,z],[x,-29.6,z],1,-30.28,"flank still blocks at front",true)
	for x: float in [-.4,-.05,.3]:
		for y: float in [-30.20,-30.03,-29.85]:
			_probe(region,cell,[x,y,-2.6],[x,y,-2.9],2,-2.78,"board actual top",true)
	for x: float in [-.65,-.05,.55]:
		_probe(region,cell,[x,-29.9,-1.5],[x,-29.9,-1.9],2,-1.72,"unchanged counter actual top",false)
	_check(JSON.stringify(RealityState.data).sha256_text()==before,"read-only probes preserve campaign content")
	return _result()

func _probe(region: OrisonV2BarRegion, cell: Node3D, from_source: Array, to_source: Array,
		axis: int, expected: float, label: String, counter_owned: bool) -> void:
	var from := cell.to_global(GameBoot.b2g(from_source))
	var to := cell.to_global(GameBoot.b2g(to_source))
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	var hit := region.get_world_3d().direct_space_state.intersect_ray(query)
	var point := Vector3.INF
	var owner_path := ""
	var owns := false
	if not hit.is_empty():
		var local: Vector3=cell.to_local(hit.position)
		point=Vector3(local.x,-local.z,local.y) # actual source frame
		var collider := hit.collider as Node
		if collider != null:
			owner_path=str(collider.get_path())
			owns=cell.get_node("HarukiyaPets/CounterRecess").is_ancestor_of(collider) if counter_owned else cell.is_ancestor_of(collider)
	_check(point.is_finite() and absf(point[axis]-expected)<=.003 and owns,label+" "+str(from_source))
	rays.append({"label":label,"from_source":from_source,"to_source":to_source,
		"expected_axis":axis,"expected_value":expected,"actual_source":point,"collider":owner_path})

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _result(ok: bool=true, reason: String="") -> Dictionary:
	if not ok: _check(false,reason)
	return {"scope":"Finite layer1 native cavity/flank/board/top ray probes plus owned-node authority/identity checks; not exhaustive continuous support, animal contact-area fit, route or art proof.",
		"checks":checks,"failures":failures.duplicate(),"rays":rays.duplicate()}
