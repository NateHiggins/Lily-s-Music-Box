extends RefCounted
## Native cloth/ring skin along the authored rail; selection proxies are reused.
const LENGTH:=1.96
const TRAVEL:=1.78
const PHYSICAL:=1.72+PI*.06
var owner: Node3D
var cloth: Node3D
var area: Area3D
var hand: Node3D
var skeleton: Skeleton3D
var held:=false
var travel:=0.0
var hand_u:=.5
var hand_y:=1.2
var prepared:=false
var configured:=false
var indices:=PackedInt32Array()
var fractions:=PackedFloat64Array()
var rest: Array[Transform3D]=[]
var parent_inverse: Array[Transform3D]=[]
var proxies: Array[CollisionShape3D]=[]
var cloth_count:=0

func _init(fixture: Node3D) -> void:
	if not configure(fixture):push_error("Native curtain skin/rest frame contract refused")

func configure(fixture: Node3D) -> bool:
	if owner!=null:return false
	var root: Node3D=fixture._curtain_closed
	if root==null:return false
	var found:=root.find_children("*","Skeleton3D",true,false)
	if found.size()!=1:return false
	var rig:=found[0] as Skeleton3D
	var skin_draws:=0
	for draw: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if draw.skin==null or draw.get_node_or_null(draw.skeleton)!=rig:return false
		skin_draws+=1
	if skin_draws!=2:return false
	var into_fixture: Transform3D=fixture.global_transform.affine_inverse()*rig.global_transform
	var candidate_indices:=PackedInt32Array()
	var candidate_rest: Array[Transform3D]=[]
	var candidate_parents: Array[Transform3D]=[]
	var candidate_fractions:=PackedFloat64Array()
	for i in 116:
		var expected_name: String="CurtainCloth%03d"%i if i<97 else "CurtainRing%03d"%(i-97)
		var index:=rig.find_bone(expected_name)
		if index<0 or index in candidate_indices:return false
		var fraction:=float(i)/96.0 if i<97 else float(i-97)/18.0
		if fraction<0.0 or fraction>1.0:return false
		var pose: Transform3D=into_fixture*rig.get_bone_global_rest(index)
		if pose.origin.distance_to(rail_point(fraction*LENGTH))>.00001:return false
		if pose.basis.x.normalized().dot(rail_axis(fraction*LENGTH))<.9999:return false
		var parent:=rig.get_bone_parent(index)
		candidate_indices.append(index);candidate_rest.append(pose);candidate_fractions.append(fraction)
		candidate_parents.append(rig.get_bone_global_rest(parent).affine_inverse() if parent>=0 else Transform3D.IDENTITY)
	owner=fixture;cloth=root;area=fixture._curtain_area;skeleton=rig
	indices=candidate_indices;rest=candidate_rest;fractions=candidate_fractions;parent_inverse=candidate_parents;cloth_count=97
	area.monitoring=false;area.monitorable=false;area.collision_mask=0
	for child in area.get_children():child.free()
	# Allocate once. The proxies select cloth; they are not environment collision.
	for i in 36:
		var shape:=CollisionShape3D.new();shape.name="CurtainSelect%02d"%i
		shape.shape=BoxShape3D.new();area.add_child(shape);proxies.append(shape)
	hand=Node3D.new();hand.name="CurtainHandContact";owner.add_child(hand)
	for draw: MeshInstance3D in cloth.find_children("*","MeshInstance3D",true,false):
		# Full closed-to-gathered envelope, in this individual draw's local frame.
		var local: Transform3D=draw.global_transform.affine_inverse()*owner.global_transform
		draw.custom_aabb=local*AABB(Vector3(-.41,.14,-.40),Vector3(.82,1.94,.82))
	configured=true;set_travel(0.0)
	return true

static func rail_frame(distance: float) -> Transform3D:
	var s:=clampf(distance/LENGTH,0.0,1.0)*PHYSICAL
	var point: Vector3;var tangent: Vector3
	if s<.58:
		point=Vector3(-.34,0,.32-s);tangent=Vector3.FORWARD
	else:
		s-=.58
		if s<PI*.03:
			var a:=PI+s/.06
			point=Vector3(-.28+.06*cos(a),0,-.26+.06*sin(a));tangent=Vector3(-sin(a),0,cos(a))
		else:
			s-=PI*.03
			if s<.56:
				point=Vector3(-.28+s,0,-.32);tangent=Vector3.RIGHT
			else:
				s-=.56
				if s<PI*.03:
					var a:=PI*1.5+s/.06
					point=Vector3(.28+.06*cos(a),0,-.26+.06*sin(a));tangent=Vector3(-sin(a),0,cos(a))
				else:
					s-=PI*.03;point=Vector3(.34,0,-.26+s);tangent=Vector3.BACK
	return Transform3D(Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP)),point)

static func rail_point(distance: float) -> Vector3:return rail_frame(distance).origin
static func rail_axis(distance: float) -> Vector3:return rail_frame(distance).basis.x

static func rail_distance(at: Vector3) -> float:
	# Used only when grabbing, not per vertex or per mouse callback.
	var best:=0.0;var nearest:=INF
	for i in 193:
		var distance:=float(i)/192.0*LENGTH
		var point:=rail_point(distance)
		var error:=Vector2(point.x-at.x,point.z-at.z).length_squared()
		if error<nearest:nearest=error;best=distance
	return best

func mapped(distance: float) -> float:return travel+distance/LENGTH*(LENGTH-travel)

func set_travel(value: float) -> void:
	if not configured or not is_finite(value):return
	var next:=clampf(value,0.0,TRAVEL)
	if prepared and is_equal_approx(next,travel):return
	travel=next;prepared=true;cloth.visible=true;owner._curtain_gathered.visible=false
	owner._curtain_is_open=travel>TRAVEL*.8
	var to_skeleton: Transform3D=skeleton.global_transform.affine_inverse()*owner.global_transform
	for i in indices.size():
		var original:=rest[i]
		var target:=rail_frame(mapped(fractions[i]*LENGTH))
		var angle:=atan2(Vector3.UP.dot(original.basis.x.cross(target.basis.x)),original.basis.x.dot(target.basis.x))
		var transformed:=Transform3D(Basis(Vector3.UP,angle)*original.basis,target.origin)
		if i<cloth_count:transformed.basis=transformed.basis*Basis.from_scale(Vector3(1,1,lerpf(1.0,1.8,travel/TRAVEL)))
		var pose:=parent_inverse[i]*to_skeleton*transformed
		skeleton.set_bone_pose_position(indices[i],pose.origin)
		skeleton.set_bone_pose_rotation(indices[i],pose.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(indices[i],pose.basis.get_scale())
	var to_area: Transform3D=area.global_transform.affine_inverse()*owner.global_transform
	for i in proxies.size():
		var a:=mapped(float(i)/proxies.size()*LENGTH)
		var b:=mapped(float(i+1)/proxies.size()*LENGTH)
		var frame:=rail_frame((a+b)*.5)
		frame.origin.y=1.0675
		(proxies[i].shape as BoxShape3D).size=Vector3(maxf(.012,(b-a)*PHYSICAL/LENGTH+.030),1.855,.120)
		proxies[i].transform=to_area*frame
	_update_hand()

func _update_hand() -> void:hand.position=rail_point(mapped(hand_u*LENGTH))+Vector3.UP*hand_y

func grip(at: Vector3) -> Dictionary:
	if not configured:return {}
	var local:=owner.to_local(at)
	var fraction:=clampf((rail_distance(local)-travel)/maxf(.18,LENGTH-travel),0,1)
	return {"owner":owner,"part":hand,"frame":owner,"kind":"slide","gesture_travel_px":280.0,
		"axis":func():return rail_axis(mapped(hand_u*LENGTH)),"minimum":0.0,"maximum":TRAVEL,
		"read":func():return travel,
		"write":func(value: float):
			if held:set_travel(value),
		"owns":func():return held,
		"begin":func():
			if held or owner._held_valve!=-1:return false
			held=true;hand_u=fraction;hand_y=local.y;_update_hand();return true,
		"end":func():held=false;owner.manipulation_changed.emit()}
