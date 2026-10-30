extends RefCounted
## Oval cloth: one GPU deformation, eighteen instanced rings and reused targets.
## TapProp retains curtain state, input ownership and household persistence.
const TRAVEL:=1.78
var owner:Node3D
var root:Node3D
var area:Area3D
var hand:Node3D
var material:ShaderMaterial
var rings:MultiMesh
var proxies:Array[CollisionShape3D]=[]
var held:=false
var travel:=0.0
var hand_u:=.5
var hand_y:=1.2
var prepared:=false
var into_area:=Transform3D.IDENTITY

func _init(fixture:Node3D,model:Node3D,cloth:MeshInstance3D,
		cloth_material:ShaderMaterial,ring_template:MeshInstance3D) -> void:
	owner=fixture;root=model;area=fixture._curtain_area;material=cloth_material
	area.monitoring=false;area.monitorable=false;area.collision_mask=0
	into_area=area.global_transform.affine_inverse()*root.global_transform
	for child in area.get_children():child.free()
	for i in 36:
		var proxy:=CollisionShape3D.new();proxy.name="CurtainSelect%02d"%i
		proxy.shape=BoxShape3D.new();area.add_child(proxy);proxies.append(proxy)
	hand=Node3D.new();hand.name="CurtainHandContact";root.add_child(hand)
	rings=MultiMesh.new();rings.transform_format=MultiMesh.TRANSFORM_3D
	rings.mesh=ring_template.mesh;rings.instance_count=18
	var draw:=MultiMeshInstance3D.new();draw.name="CurtainRings";draw.multimesh=rings
	draw.material_override=ring_template.get_surface_override_material(0)
	root.add_child(draw);ring_template.visible=false
	cloth.custom_aabb=AABB(Vector3(-.80,.33,-.40),Vector3(1.60,1.94,.80))
	set_travel(0.0)

static func angle(u:float,phase:float) -> float:
	return lerpf(-PI+.065+(TAU-.13)*u,-.21+.42*u,phase)

static func rail_frame(u:float,phase:float) -> Transform3D:
	var theta:=angle(u,phase)
	var tangent:=Vector3(-.745*sin(theta),0,-.355*cos(theta)).normalized()
	return Transform3D(Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP)),
		Vector3(.745*cos(theta),2.272,-.355*sin(theta)))

static func cloth_centerline(u:float,h:float,phase:float) -> Vector3:
	var theta:=angle(u,phase)
	return Vector3((.600+.145*h)*cos(theta),.345+1.9*h,-(.260+.095*h)*sin(theta))

func set_travel(value:float) -> void:
	if not is_finite(value):return
	var next:=clampf(value,0,TRAVEL)
	if prepared and is_equal_approx(next,travel):return
	travel=next;prepared=true
	var phase:=travel/TRAVEL
	material.set_shader_parameter("gather",phase)
	owner._curtain_is_open=phase>.8
	for i in 18:rings.set_instance_transform(i,rail_frame(float(i)/17,phase))
	for i in proxies.size():
		var a:=float(i)/proxies.size();var b:=float(i+1)/proxies.size()
		var middle:=(a+b)*.5
		var bottom:=cloth_centerline(middle,0,phase);var top:=cloth_centerline(middle,1,phase)
		var up:=(top-bottom).normalized()
		var across:=cloth_centerline(b,.5,phase)-cloth_centerline(a,.5,phase)
		across=(across-up*across.dot(up)).normalized()
		var pose:=Transform3D(Basis(across,up,across.cross(up)),(bottom+top)*.5)
		var length:=cloth_centerline(a,.5,phase).distance_to(cloth_centerline(b,.5,phase))
		(proxies[i].shape as BoxShape3D).size=Vector3(maxf(.014,length+.018),bottom.distance_to(top)+.02,.100)
		proxies[i].transform=into_area*pose
	_update_hand()

func _update_hand() -> void:
	hand.position=rail_frame(hand_u,travel/TRAVEL).origin
	hand.position.y=hand_y

func grip(at:Vector3) -> Dictionary:
	var local:=root.to_local(at)
	var fraction:=.5;var nearest:=INF
	# Once per grab; no extra ray scan, triangle rebuild or per-frame search.
	for i in 129:
		var u:=float(i)/128
		var p:=rail_frame(u,travel/TRAVEL).origin
		var distance:=Vector2(p.x-local.x,p.z-local.z).length_squared()
		if distance<nearest:nearest=distance;fraction=u
	return {"owner":owner,"part":hand,"frame":root,"kind":"slide",
		"gesture_travel_px":280.0,"minimum":0.0,"maximum":TRAVEL,
		"axis":func():return rail_frame(hand_u,travel/TRAVEL).basis.x*(-1.0 if angle(hand_u,1)<angle(hand_u,0) else 1.0),
		"read":func():return travel,
		"write":func(value:float):
			if held:set_travel(value),
		"owns":func():return held,
		"begin":func():
			if held or owner._held_valve!=-1 or (owner._plug_hand!=null and owner._plug_hand.held):return false
			held=true;hand_u=fraction;hand_y=clampf(local.y,.345,2.245);_update_hand();return true,
		"end":func():held=false;owner.manipulation_changed.emit()}
