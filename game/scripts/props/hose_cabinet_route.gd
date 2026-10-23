extends RefCounted
## Authored cabinet fairlead plus cheap external drape, never a cloth solver.
## The retained case is .61 m wide, .78 m tall and .24 m deep. Its deployed
## leaf rests slightly ajar; the linen exits around its free edge.
var model_to_actor:=Transform3D.IDENTITY
var limited:=false
var reach_m:=0.
var last_length_m:=0.
var _guide:=PackedVector3Array()
const CASE:=AABB(Vector3(-.36,-.05,-.04),Vector3(.72,.90,.34))
const AJAR:=.26

func _rounded(knots: PackedVector3Array) -> PackedVector3Array:
	var result:=PackedVector3Array([knots[0]])
	for i in range(1,knots.size()-1):
		var before: Vector3=knots[i]-knots[i-1];var after: Vector3=knots[i+1]-knots[i]
		var radius: float=minf(.055,minf(before.length(),after.length())*.30)
		if radius<.000001:continue
		var first: Vector3=knots[i]-before.normalized()*radius
		var last: Vector3=knots[i]+after.normalized()*radius
		result.append(first)
		for j in range(1,7):
			var t: float=float(j)/6.
			result.append(first.lerp(knots[i],t).lerp(knots[i].lerp(last,t),t))
	result.append(knots[-1]);return result

func _sample(knots: PackedVector3Array,count: int) -> PackedVector3Array:
	var lengths:=PackedFloat64Array();var total:=0.
	for i in range(1,knots.size()):total+=knots[i].distance_to(knots[i-1]);lengths.append(total)
	var result:=PackedVector3Array();var segment:=0
	for i in count:
		var distance: float=total*float(i)/float(count-1)
		while segment<lengths.size()-1 and distance>lengths[segment]:segment+=1
		var start: float=0. if segment==0 else lengths[segment-1]
		result.append(knots[segment].lerp(knots[segment+1],clampf((distance-start)/maxf(.000001,lengths[segment]-start),0.,1.)))
	return result

func build(tip: Vector3,back: Vector3,anchor: Vector3,count: int,stock_m: float,_up: Vector3,floor_height: float) -> PackedVector3Array:
	if count<32 or not tip.is_finite() or not back.is_finite() or back.length_squared()<.5:return PackedVector3Array()
	reach_m=stock_m-.15;limited=tip.distance_to(anchor)>=reach_m-.001
	var at: Vector3=model_to_actor*tip
	var direction: Vector3=(model_to_actor.basis*back).normalized()
	var source: Vector3=model_to_actor*anchor
	# Keep both socket and short barrel outside the case for a close FPS pose.
	if CASE.has_point(at) or CASE.intersects_segment(at,at-direction*.19)!=null:
		at.z=maxf(at.z,.51);limited=true
	var exit:=Vector3(-.50,.18,.50)
	var lead: Vector3=at+direction*.015
	var floor_y: float=floor_height+model_to_actor.origin.y
	var knots:=PackedVector3Array([lead])
	if CASE.intersects_segment(lead,exit)!=null:
		var side: float=.50 if lead.x>0. else -.50
		knots.append(Vector3(side,lead.y,lead.z))
		knots.append(Vector3(side,minf(lead.y,floor_y+.05),lead.z))
		knots.append(Vector3(side,floor_y+.05,exit.z))
	knots.append(exit)
	var points:=PackedVector3Array([at,at+direction*.005,at+direction*.010])
	var outer: PackedVector3Array=_sample(_rounded(knots),count-27)
	var slack: float=maxf(0.,stock_m-at.distance_to(source))
	for i in outer.size():
		var p: Vector3=outer[i]
		# Sag only where X/Z is already clear of the case. Other safe spans
		# retain their height above/below it. No world contact query is needed.
		if p.x<CASE.position.x or p.x>CASE.end.x or p.z<CASE.position.z or p.z>CASE.end.z:
			var dx: float=maxf(CASE.position.x-p.x,maxf(0.,p.x-CASE.end.x))
			var dz: float=maxf(CASE.position.z-p.z,maxf(0.,p.z-CASE.end.z))
			var free: float=smoothstep(.35,.65,Vector2(dx,dz).length())
			p.y-=minf(maxf(0.,p.y-floor_y),slack*.25)*sin(PI*float(i)/float(outer.size()-1))*free
		points.append(p)
	if _guide.is_empty():
		var guide:=PackedVector3Array([exit,Vector3(-.42,.18,.285),Vector3(-.22,.18,.285),Vector3(-.22,.24,.10),Vector3(.17,.32,.10),source-Vector3.UP*.015])
		_guide=_sample(_rounded(guide),22)
	for i in range(1,_guide.size()):points.append(_guide[i])
	points.append(source-Vector3.UP*.010);points.append(source-Vector3.UP*.005);points.append(source)
	if points.size()!=count:return PackedVector3Array()
	var inverse: Transform3D=model_to_actor.affine_inverse()
	last_length_m=0.
	for i in points.size():
		points[i]=inverse*points[i]
		if i>0:last_length_m+=points[i].distance_to(points[i-1])
	return points
