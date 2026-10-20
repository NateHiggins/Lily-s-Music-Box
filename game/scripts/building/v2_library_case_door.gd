extends Node3D
## A sectional sash lifts outward, then runs back above its books on its tracks.
var shelf: Node3D
var stock: RefCounted
var record: Dictionary
var angle := 0.0
var inset := 0.0
var leaf: Node3D
var solid: AnimatableBody3D
var shapes: Array[CollisionShape3D] = []
var _before := Vector2.ZERO

func _ready() -> void:
	leaf=Node3D.new();leaf.name="LiftLeaf";add_child(leaf)
	leaf.position=Vector3(record.pivot[0],record.pivot[1],record.pivot[2])
	solid=AnimatableBody3D.new();solid.name="MovingLeafSolid";solid.sync_to_physics=false;leaf.add_child(solid)
	for identity: String in record.parts:
		var carriage: bool=str(stock.data.parts[identity].role)=="carriage"
		var mode: String="slide" if identity.contains("Rail1") or carriage else "hinge"
		var draw: MeshInstance3D=stock.draw(self if carriage else leaf,identity)
		if not carriage:
			draw.transform=Transform3D(Basis.IDENTITY,-leaf.position)*draw.transform
			var shape: CollisionShape3D=stock.collision(solid,identity,Transform3D(Basis.IDENTITY,-leaf.position))
			if shape!=null:
				shape.set_meta("sash_grip_mode",mode)
				shapes.append(shape)
		preload("res://scripts/props/manipulation_area.gd").install(draw,func(): return grip(mode))

func manipulation_target(hit: Dictionary) -> Dictionary:
	# Native solids and their target areas share a surface. Whichever wins the
	# ray must resolve to the same operable part, never to the fixed case.
	if hit.get("collider")==solid:
		var index:=solid.shape_find_owner(int(hit.shape))
		var shape:=solid.shape_owner_get_owner(index) as CollisionShape3D
		if shape!=null: return grip(str(shape.get_meta("sash_grip_mode","hinge")))
	return grip("hinge")

func grip(requested: String) -> Dictionary:
	var mode:=requested
	if inset>.00001: mode="slide"
	if mode=="slide" and angle<float(record.angle_limit)-.00001: mode="hinge"
	var part: Node3D=self if mode=="slide" else leaf
	return {"owner":shelf,"part":part,"frame":shelf,"kind":"slider" if mode=="slide" else "hinge",
		"axis":Vector3.FORWARD if mode=="slide" else Vector3.LEFT,
		"minimum":0.,"maximum":float(record.inset_limit) if mode=="slide" else float(record.angle_limit),
		"read":func(): return inset if mode=="slide" else angle,
		"write":func(value: float):
			if shelf._hand_node==part: _move(value,mode),
		"begin":func():
			if not shelf.claim_library_hand(part,"sash"): return false
			_before=Vector2(angle,inset);return true,
		"owns":func(): return shelf._hand_node==part and shelf._hand_tag=="sash",
		"end":func(): shelf.release_library_hand(part,not _before.is_equal_approx(Vector2(angle,inset)))}

func _move(proposed: float, mode: String) -> void:
	if not is_finite(proposed): return
	var before:=inset if mode=="slide" else angle
	var maximum:=float(record.inset_limit) if mode=="slide" else float(record.angle_limit)
	var target:=clampf(proposed,0.,maximum)
	var steps:=maxi(1,ceili(absf(target-before)/(.004 if mode=="slide" else .02)))
	for step in range(1,steps+1):
		var value:=lerpf(before,target,float(step)/steps)
		var candidate_angle:=angle if mode=="slide" else value
		var candidate_inset:=value if mode=="slide" else inset
		var pivot:=Vector3(record.pivot[0],record.pivot[1],record.pivot[2])
		var pose:=shelf.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-candidate_inset))*Transform3D(Basis(Vector3.LEFT,candidate_angle),pivot)
		var clear:=true
		for shape: CollisionShape3D in shapes:
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=shape.shape;query.transform=pose*shape.transform;query.margin=.00001
			query.exclude=[solid.get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): clear=false;break
		if not clear: break
		angle=candidate_angle;inset=candidate_inset;_apply()

func _apply() -> void:
	leaf.rotation.x=-angle
	position.z=-inset

func snapshot() -> Dictionary: return {"angle":angle,"inset":inset}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2: return false
	for key: String in ["angle","inset"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])): return false
	return float(value.angle)>=0. and float(value.angle)<=float(record.angle_limit) \
		and float(value.inset)>=0. and float(value.inset)<=float(record.inset_limit) \
		and (float(value.inset)<=.00001 or absf(float(value.angle)-float(record.angle_limit))<=.00001)

func restore(value: Dictionary) -> void:
	angle=float(value.angle);inset=float(value.inset);_apply()
