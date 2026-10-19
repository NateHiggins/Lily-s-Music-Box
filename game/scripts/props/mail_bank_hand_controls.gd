extends RefCounted
## The bank retains catalogue/custody; this owner moves its actual native stock.
const Reach=preload("res://scripts/props/manipulation_area.gd")
var bank: MailBankProp
var door_body: AnimatableBody3D
var door_shape: BoxShape3D
var held: String=""
var pulls: Dictionary={}
var articles: Dictionary={}

func bind(owner: MailBankProp) -> void:
	bank=owner
	# The old use-ray filled the whole pocket, including its open aperture.
	# Replace that proxy with the actual fixed casting and moving leaf.
	var legacy: CollisionObject3D=bank.get_node_or_null("PlayerBox") as CollisionObject3D
	if legacy!=null:legacy.collision_layer=0;legacy.collision_mask=0
	var fixed: StaticBody3D=StaticBody3D.new();fixed.name="NativePocketCollision";bank.add_child(fixed)
	for draw: MeshInstance3D in bank._fixed.find_children("*","MeshInstance3D",true,false):
		if draw.name in [&"FixedNameCards",&"HeaderLettering"]:continue
		var shape: CollisionShape3D=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();fixed.add_child(shape)
		shape.global_transform=draw.global_transform
	door_body=AnimatableBody3D.new();door_body.name="MovingMailLeaf"
	# The hinge is the retained native Node3D authority. Synchronizing a child
	# AnimatableBody independently pins its collision at the old closed pose.
	door_body.sync_to_physics=false;bank._hinge.add_child(door_body)
	door_shape=BoxShape3D.new();door_shape.size=Vector3(bank.LEAF_W,bank.LEAF_H,.008)
	var door_collision: CollisionShape3D=CollisionShape3D.new();door_collision.shape=door_shape
	door_collision.position=Vector3(bank.LEAF_W*.5,-.008,0);door_body.add_child(door_collision)
	Reach.install(bank._hinge,door_target)
	bank._refresh_contents()

func target_for_hit(hit: Dictionary) -> Dictionary:
	return door_target() if hit.get("collider")==door_body else {}

func _claim(identity: String) -> bool:
	if not held.is_empty():return false
	if identity=="door" and bank._door_tween!=null and bank._door_tween.is_valid():bank._door_tween.kill()
	held=identity;return true

func door_target() -> Dictionary:
	return {"owner":bank,"part":bank._hinge,"frame":bank,"kind":"hinge","axis":Vector3.UP,
		"minimum":0.,"maximum":deg_to_rad(95.),"read":func():return bank._hinge.rotation.y,
		"write":_move_door,"owns":func():return held=="door",
		"begin":func():return _claim("door"),"end":func():held="";bank.door_open=bank._hinge.rotation.y>.01;bank.manipulation_changed.emit()}

func _move_door(value: float) -> void:
	if held!="door":return
	var before: float=bank._hinge.rotation.y
	var steps: int=maxi(1,ceili(absf(value-before)/.02))
	for i in range(1,steps+1):
		var angle: float=clampf(lerpf(before,value,float(i)/steps),0.,deg_to_rad(95.))
		if angle<bank._hinge.rotation.y and _obstructed_by_mail(angle):break
		bank._hinge.rotation.y=angle
	bank.door_open=bank._hinge.rotation.y>.01

func _obstructed_by_mail(angle: float) -> bool:
	var displaced: bool=false
	for value: float in pulls.values():displaced=displaced or value>.015
	if not displaced:return false
	var pose: Transform3D=bank._hinge.global_transform
	pose.basis=bank.global_basis*Basis(Vector3.UP,angle)
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	query.shape=door_shape;query.transform=pose*Transform3D(Basis(),Vector3(bank.LEAF_W*.5,-.008,0))
	query.collision_mask=1;query.collide_with_areas=true;query.collide_with_bodies=false
	for hit: Dictionary in bank.get_world_3d().direct_space_state.intersect_shape(query,64):
		var area: Node=hit.collider as Node
		if area!=null and area.has_meta("mail_article"):return true
	return false

func refresh_contents() -> void:
	articles.clear()
	var draws: Array[MeshInstance3D]=[]
	for child: Node in bank._contents.get_children():
		if child is MeshInstance3D:draws.append(child as MeshInstance3D)
	var cursor: int=0
	for item: Dictionary in bank.pending():
		var count: int=2 if str(item.get("kind","letter"))=="package" else 1
		var stocks: Array[Dictionary]=[]
		for i in count:
			if cursor>=draws.size():break
			var draw: MeshInstance3D=draws[cursor];cursor+=1
			stocks.append({"part":draw,"rest":draw.position})
		if stocks.is_empty():continue
		var identity: String=str(item.id)
		articles[identity]={"item":item.duplicate(true),"stocks":stocks}
		for stock: Dictionary in stocks:
			var part: MeshInstance3D=stock.part
			part.position=stock.rest+Vector3.FORWARD*float(pulls.get(identity,0.))
			var area: Area3D=Reach.install(part,article_target.bind(identity))
			area.set_meta("mail_article",identity)

func article_target(identity: String) -> Dictionary:
	if not articles.has(identity) or bank._hinge.rotation.y<.6:return {}
	var first: Node3D=articles[identity].stocks[0].part
	return {"owner":bank,"part":first,"frame":bank._contents,"kind":"slide","axis":Vector3.FORWARD,"article_id":identity,
		"minimum":0.,"maximum":.35,"read":func():return float(pulls.get(identity,0.)),
		"write":func(value: float):_pull_article(identity,value),"owns":func():return held==identity,
		"begin":func():return _claim(identity),"end":func():_release_article(identity)}

func _pull_article(identity: String,value: float) -> void:
	if held!=identity or not articles.has(identity):return
	pulls[identity]=clampf(value,0.,.35)
	for stock: Dictionary in articles[identity].stocks:
		(stock.part as Node3D).position=stock.rest+Vector3.FORWARD*float(pulls[identity])

func _release_article(identity: String) -> void:
	held=""
	if float(pulls.get(identity,0.))>=.16 and articles.has(identity):
		var item: Dictionary=articles[identity].item.duplicate(true)
		# Only the existing bank authority grants an item or an upgrade. A grip
		# and a short/unmoved release never consume catalogue delivery state.
		pulls.erase(identity)
		bank._take(item,true)
		var player: PlayerController=bank.get_tree().get_first_node_in_group("player_controller") as PlayerController
		if player!=null:player._present_interaction_telegram(bank,{"title":str(item.get("title","MAIL")),"body":str(item.get("body","")),"condition":"BOX 4B / RECEIVED","stamp":"MAIL COPY"})
	bank.manipulation_changed.emit()

func snapshot() -> Dictionary:
	return {"door":bank._hinge.rotation.y,"pulls":pulls.duplicate(true)}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2 or typeof(value.get("door")) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value.door)) or float(value.door)<0 or float(value.door)>deg_to_rad(95.)+.00001 or value.get("pulls") is not Dictionary:return false
	var known: Dictionary={}
	for item: Dictionary in bank.deliveries:known[str(item.id)]=true
	for identity: Variant in value.pulls:
		var amount: Variant=value.pulls[identity]
		if identity is not String or not known.has(identity) or typeof(amount) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(amount)) or float(amount)<0. or float(amount)>.35:return false
	return true

func restore(value: Dictionary) -> void:
	if not valid(value):return
	if bank._door_tween!=null and bank._door_tween.is_valid():bank._door_tween.kill()
	held="";pulls=value.pulls.duplicate(true);bank._hinge.rotation.y=float(value.door)
	bank.door_open=bank._hinge.rotation.y>.01;bank._refresh_contents()
