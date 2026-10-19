extends RefCounted
## Physical contact drives the retained transient line; no click-state cycle.
const Reach=preload("res://scripts/props/manipulation_area.gd")
const Cord=preload("res://scripts/props/telephone_cord_stock.gd")
class PlugBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(_hit: Dictionary) -> Dictionary:return provider.call()
var board: HouseSwitchboardProp
var stock: RefCounted
var source: Dictionary={}
var plugs: Array[Node3D]=[]
var plug_bodies: Array[AnimatableBody3D]=[]
var cords: Array[MeshInstance3D]=[]
var anchors: Array[Vector3]=[]
var velocities: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var falling: Array[bool]=[false,false]
var held: String=""
var collision_stock: Array[Shape3D]=[]

func _vec(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])

func bind(owner: HouseSwitchboardProp,native: RefCounted) -> bool:
	board=owner;stock=native
	source=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/house_switchboard.json"))
	if source!=stock.data:return false
	if board.network==null:return false
	for connection: Dictionary in source.calling_ports:
		if not board.network.endpoints.has(str(connection.endpoint)):return false
	for identity: String in source.parts:
		if identity.begins_with("Plug"):
			var shape: ConvexPolygonShape3D=(stock.meshes[identity] as Mesh).create_convex_shape()
			shape.margin=.00001;collision_stock.append(shape)
	for i in 2:
		var part: Node3D=stock.plug(board,i);part.position=_vec(source.plug.rest[i]);plugs.append(part)
		var body: PlugBody=PlugBody.new();body.name="NativePlugCollision";body.sync_to_physics=false;body.collision_mask=0;body.provider=_plug_target.bind(i);part.add_child(body);plug_bodies.append(body)
		for native_shape: Shape3D in collision_stock:
			var collision: CollisionShape3D=CollisionShape3D.new();collision.shape=native_shape;body.add_child(collision)
		Reach.install(part,_plug_target.bind(i))
		var cord: MeshInstance3D=Cord.new();cord.name="AnswerCord" if i==0 else "TrunkCord";board._cord.add_child(cord)
		if not cord.bind(stock.meshes[str(source.cord.mesh)],stock.finishes["rubber_aged"],float(source.cord.length_m),float(source.cord.radius_m)):return false
		cords.append(cord);anchors.append(_vec(source.cord.anchors[i]))
		if not cord.pose(anchors[i],part.position+Vector3(0,0,float(source.plug.cord_outlet_z))):return false
	Reach.install(board._key,_key_target)
	present_line(board.network.snapshot())
	return true

func _claim(identity: String) -> bool:
	if not held.is_empty():return false
	held=identity
	if identity.begins_with("plug_"):
		var i: int=int(identity.trim_prefix("plug_"));velocities[i]=Vector3.ZERO;falling[i]=false
	return true

func _key_target() -> Dictionary:
	return {"owner":board,"part":board._key,"frame":board,"kind":"hinge","axis":Vector3.BACK,
		"minimum":float(source.key.minimum),"maximum":float(source.key.maximum),"read":func():return board._key.rotation.z,
		"write":func(value: float):
			if held=="key":board._key.rotation.z=clampf(value,float(source.key.minimum),float(source.key.maximum));_contacts(),
		"owns":func():return held=="key","begin":func():return _claim("key"),"end":func():held=""}

func _plug_target(index: int) -> Dictionary:
	var identity: String="plug_"+str(index)
	return {"owner":board,"part":plugs[index],"frame":board,"kind":"free","read":func():return plugs[index].position,
		"write":func(value: Vector3):
			if held==identity:_move(index,value),
		"owns":func():return held==identity,"begin":func():return _claim(identity),"end":func():held="";falling[index]=_seat(index).is_empty()}

func _seat(index: int) -> String:
	var at: Vector3=plugs[index].position
	for port: Dictionary in source.ports+source.parking:
		var center: Vector3=_vec(port.center)
		var margin: float=float(port.bore_m)*.5-float(source.plug.shaft_radius_m)
		var stop: float=center.z-float(source.plug.collar_z)-float(source.plug.skin_m)
		if Vector2(at.x-center.x,at.y-center.y).length()<=margin and absf(at.z-stop)<=.0001:return str(port.id)
	return ""

func _solid(index: int,position: Vector3) -> bool:
	var excluded: Array[RID]=[plug_bodies[index].get_rid()]
	for player: Node in board.get_tree().get_nodes_in_group("player_controller"):
		if player is CollisionObject3D:excluded.append((player as CollisionObject3D).get_rid())
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	query.transform=board.global_transform*Transform3D(Basis(),position);query.collision_mask=1;query.exclude=excluded;query.margin=.00001
	for shape: Shape3D in collision_stock:
		query.shape=shape
		if not board.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return true
	return false

func _move(index: int,proposal: Vector3) -> bool:
	if not proposal.is_finite():return false
	var before: Vector3=plugs[index].position
	var pieces: int=maxi(1,ceili(before.distance_to(proposal)/.0005))
	var accepted: Vector3=before
	for step in range(1,pieces+1):
		var at: Vector3=before.lerp(proposal,float(step)/pieces)
		# The real collar meets the source jack face; no target matching or
		# teleport seats a plug. The operator still supplies every movement.
		for port: Dictionary in source.ports+source.parking:
			var center: Vector3=_vec(port.center)
			var margin: float=float(port.bore_m)*.5-float(source.plug.shaft_radius_m)
			# Once the actual shaft has entered a real bore, its sidewalls
			# constrain lateral travel. Keep the entry offset; never snap to
			# the centre or move the plug forward without mouse travel.
			if accepted.z+float(source.plug.tip_z)>center.z and Vector2(accepted.x-center.x,accepted.y-center.y).length()<=margin:
				at.x=accepted.x;at.y=accepted.y
			if Vector2(at.x-center.x,at.y-center.y).length()<=margin:
				at.z=minf(at.z,center.z-float(source.plug.collar_z)-float(source.plug.skin_m))
		if not cords[index].can_reach(anchors[index],at+Vector3(0,0,float(source.plug.cord_outlet_z))) or _solid(index,at):break
		accepted=at
	if before.is_equal_approx(accepted):return false
	plugs[index].position=accepted
	cords[index].pose(anchors[index],accepted+Vector3(0,0,float(source.plug.cord_outlet_z)))
	_contacts()
	return true

func physics_tick(delta: float) -> void:
	for i in 2:
		if not falling[i] or held=="plug_"+str(i):continue
		velocities[i]+=Vector3.DOWN*9.8*minf(delta,.05)
		if not _move(i,plugs[i].position+velocities[i]*minf(delta,.05)):
			velocities[i]=Vector3.ZERO;falling[i]=false

func _contacts() -> void:
	var line: Dictionary=board.network.snapshot()
	var caller: String=_seat(0);var trunk: String=_seat(1)
	var expected: String=""
	for connection: Dictionary in source.calling_ports:
		if str(connection.endpoint)==str(line.asking):expected=str(connection.port);break
	if str(line.state)=="ASKING" and not expected.is_empty() and caller==expected and board._key.rotation.z<=float(source.key.answer_stop):
		board.network.answer("house_board")
		line=board.network.snapshot()
	if str(line.state)=="ANSWERED" and trunk==str(source.trunk.port):board.network.carry(str(source.trunk.id))
	elif str(line.state) in ["ANSWERED","CARRYING"]:
		if caller!=expected or (str(line.state)=="CARRYING" and trunk!=str(source.trunk.port)):board.network.release("house_board")

func present_line(line: Dictionary) -> void:
	var tint: Color=Color(1.,.28,.035) if str(line.state)=="ASKING" else Color(.18,.06,.02)
	var current: Material=board._asking_lamp.get_active_material(0)
	if current is StandardMaterial3D:
		var material: StandardMaterial3D=current.duplicate() as StandardMaterial3D;material.albedo_color=tint
		board._asking_lamp.material_override=material
	elif current is ShaderMaterial:
		var material: ShaderMaterial=current.duplicate() as ShaderMaterial;material.set_shader_parameter("albedo_color",tint)
		board._asking_lamp.material_override=material
